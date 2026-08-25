// ============================================================
// PlayerScreen — YouTube-style watch page
// ============================================================
// 16:9 player on top with an auto-hiding control overlay, then the
// title/action row, channel row, description and suggestions below.
// ============================================================

import 'dart:async';

// Narrowed: the package also re-exports flutter_cache_manager's
// DownloadProgress, which collides with this app's own class of that
// name in services/download_manager.dart.
import 'package:cached_network_image/cached_network_image.dart'
    show CachedNetworkImageProvider;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/duration_formatter.dart';
import '../../../data/local/preferences/settings_repository_impl.dart';
import '../../../domain/entities/chapter_item.dart';
import '../../../domain/entities/media_item.dart';
import '../../../domain/entities/sponsor_segment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/pip_manager.dart';
import '../../l10n/enum_labels.dart';
import '../../providers/content_providers.dart';
import '../../providers/downloads_providers.dart';
import '../../providers/local_library_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/video_card.dart';
import '../comments/comments_screen.dart';
import 'widgets/player_settings_sheet.dart';
import 'widgets/live_chat_sheet.dart';
import 'widgets/cast_device_sheet.dart';

/// How mpv gets frames onto the screen, per platform.
///
/// Android: mpv's default `vo=gpu` needs its own EGL context, which
/// fails on the emulator ("Could not create EGL context for GLES 2.x").
/// `mediacodec_embed` decodes straight onto the Android Surface — no
/// mpv-side GL — and works on devices and emulators alike.
///
/// iOS/macOS: neither of those exists. VideoToolbox is the hardware
/// decoder there, and media_kit's default video output already renders
/// through Metal, so only the decoder is named.
///
/// Anything else keeps media_kit's defaults.
VideoControllerConfiguration get _videoOutputConfiguration =>
    switch (defaultTargetPlatform) {
      TargetPlatform.android => const VideoControllerConfiguration(
          vo: 'mediacodec_embed',
          hwdec: 'mediacodec',
        ),
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        const VideoControllerConfiguration(hwdec: 'videotoolbox'),
      _ => const VideoControllerConfiguration(),
    };

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.videoId,
    this.offline = false,
    this.heroTag,
  });

  final String videoId;

  /// Play the downloaded copy instead of streaming.
  final bool offline;

  /// Tag of the thumbnail this player was opened from, so the image
  /// carries through instead of the card vanishing and a new surface
  /// appearing. Null when the caller has no matching Hero.
  final String? heroTag;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final VideoController _videoController;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _descriptionExpanded = false;

  /// Transient HUD shown while dragging for brightness/volume.
  double? _gestureValue;
  IconData? _gestureIcon;
  double _brightness = 0.5;

  /// How far the sheet has been dragged toward the mini player, in
  /// logical pixels. Zero is fully expanded.
  double _dragOffset = 0;

  /// Runs 0→1 to spring an abandoned drag back to zero. It stays a unit
  /// controller and the pixel distance is interpolated from
  /// [_settleFrom]; an AnimationController clamps to its bounds, so
  /// feeding it raw pixels would pin every release at one.
  late final AnimationController _settle;
  double _settleFrom = 0;

  /// Riverpod's container, captured while the element is still mounted
  /// so dispose can hand the route flag back without touching context.
  late final ProviderContainer _container;

  /// Distance past which releasing collapses instead of springing back.
  static const double _collapseThreshold = 110;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(
      ref.read(mediaPlayerProvider),
      configuration: _videoOutputConfiguration,
    );

    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (mounted) {
          setState(() => _dragOffset = _settleFrom * (1 - _settle.value));
        }
      });

    // The mini player describes the same playback and shares Hero tags
    // with this screen, so it stands down while this route is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playerRouteActiveProvider.notifier).state = true;
      }
    });

    PiPManager.install(
      onModeChanged: (active) {
        if (!mounted) return;
        ref.read(playerControllerProvider.notifier).setPiPActive(active);
        setState(() => _showControls = !active);
      },
      // Home/Recents while a video is playing: shrink into PiP like the
      // official app, when the setting allows it.
      onUserLeaveHint: () {
        if (!mounted) return;
        final settings = ref.read(settingsControllerProvider);
        final state = ref.read(playerControllerProvider);
        if (!settings.pictureInPictureEnabled ||
            !PiPManager.isAvailableOnThisPlatform ||
            state.isPiPActive ||
            !state.isPlaying ||
            state.currentItem == null) {
          return;
        }
        unawaited(PiPManager.enterPiP());
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(playerControllerProvider.notifier);
      if (widget.offline && await controller.loadOffline(widget.videoId)) {
        return;
      }
      await controller.loadVideo(widget.videoId);
    });
    _restartHideTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _settle.dispose();
    // Writing to a provider during a dependent's dispose is not allowed,
    // so hand the flag back on the next frame, through the container
    // captured while this element was still mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _container.read(playerRouteActiveProvider.notifier).state = false;
    });
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _restartHideTimer();
  }

  // ============================================================
  // Collapse-to-mini drag
  // ============================================================

  void _onCollapseDragUpdate(double delta) {
    _settle.stop();
    setState(() => _dragOffset = (_dragOffset + delta).clamp(0.0, 10000.0));
  }

  void _onCollapseDragEnd(double velocity) {
    if (_dragOffset > _collapseThreshold || velocity > 700) {
      HapticFeedback.lightImpact();
      context.pop();
      return;
    }
    // Spring back to fully expanded.
    _settleFrom = _dragOffset;
    _settle.forward(from: 0);
  }

  Future<void> _toggleFullscreen() async {
    final controller = ref.read(playerControllerProvider.notifier);
    final next = !ref.read(playerControllerProvider).isFullscreen;
    HapticFeedback.selectionClick();
    controller.setFullscreen(next);
    if (next) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Not immersiveSticky: that mode installs a system reveal gesture
      // and swallows the first touch to show the bars again, which is
      // exactly why one tap did nothing in fullscreen and only the
      // second reached the controls. Hiding the overlays outright leaves
      // every touch to the player.
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Portrait stays pinned while the watch page is showing.
      //
      // Handing rotation straight back was the bug: if the phone is
      // physically sideways — which it is, you turned it to watch — iOS
      // rotates right back to landscape the moment it is allowed to,
      // and the exit looked like nothing happened. Fullscreen is
      // gesture- and button-driven now, so nothing needs the device's
      // orientation and nothing has to be unlocked.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  Widget _gestureHud() {
    final value = _gestureValue;
    if (value == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_gestureIcon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustBrightness(double delta) async {
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    try {
      await ScreenBrightness.instance
          .setApplicationScreenBrightness(_brightness);
    } on Exception {
      // Some devices refuse programmatic brightness; the HUD still
      // reflects the intent so the gesture does not feel broken.
    }
    setState(() {
      _gestureValue = _brightness;
      _gestureIcon = _brightness < 0.35
          ? Icons.brightness_low
          : _brightness < 0.7
              ? Icons.brightness_medium
              : Icons.brightness_high;
    });
  }

  void _adjustVolume(double delta) {
    final controller = ref.read(playerControllerProvider.notifier);
    final current = ref.read(playerControllerProvider).volume;
    // Drag covers 0–100%; boosting past that stays in the menu.
    final next = (current + delta * 100).clamp(0.0, 100.0);
    controller.setVolume(next);
    setState(() {
      _gestureValue = next / 100;
      _gestureIcon = next == 0
          ? Icons.volume_off
          : next < 50
              ? Icons.volume_down
              : Icons.volume_up;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final isFullscreen = state.isFullscreen;

    // One tree for every mode: the Video element must keep its identity
    // or its native surface is torn down and re-created, which leaves a
    // black window when entering PiP or fullscreen.
    final expanded = isFullscreen || state.isPiPActive;

    Widget player = _PlayerSurface(
      state: state,
      videoController: _videoController,
      showControls: _showControls,
      onToggleControls: _toggleControls,
      onInteract: _restartHideTimer,
      onToggleFullscreen: _toggleFullscreen,
      onRetry: () =>
          ref.read(playerControllerProvider.notifier).loadVideo(widget.videoId),
      onGestureStart: () => _hideTimer?.cancel(),
      onGestureEnd: () {
        _restartHideTimer();
        // Let the reading linger a moment before fading out.
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _gestureValue = null);
        });
      },
      onBrightnessDelta: _adjustBrightness,
      onVolumeDelta: _adjustVolume,
      // Portrait belongs to the collapse gesture — it is the one every
      // YouTube user reaches for first. Brightness and volume take over
      // the vertical drag only in fullscreen, where nothing can collapse.
      collapsible: !expanded,
      onCollapseDragUpdate: _onCollapseDragUpdate,
      onCollapseDragEnd: _onCollapseDragEnd,
    );

    final heroTag = widget.heroTag;
    if (heroTag != null && !expanded) {
      player = Hero(
        tag: heroTag,
        // The card's still thumbnail and this live surface are different
        // widgets; cross-fading them beats scaling one into the other.
        flightShuttleBuilder: (_, animation, __, ___, toHero) =>
            FadeTransition(opacity: animation, child: toHero.widget),
        child: player,
      );
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final collapseProgress =
        (_dragOffset / (screenHeight * 0.45)).clamp(0.0, 1.0);

    final scaffold = Scaffold(
      backgroundColor:
          expanded ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: PopScope(
        canPop: !isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        // Fullscreen means edge to edge on every side. Leaving left and
        // right on — SafeArea's default — inset the video by the notch
        // in landscape, which is what made it sit short of the screen.
        child: SafeArea(
          top: !expanded,
          bottom: !expanded,
          left: !expanded,
          right: !expanded,
          child: Column(
            children: [
              if (expanded)
                Expanded(
                  child: Stack(
                    children: [player, _gestureHud()],
                  ),
                )
              else
                // Loose so the video gives way rather than overflowing
                // if this layout ever renders in a viewport too short
                // for a full 16:9 — mid-rotation, or a split view.
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [player, _gestureHud()],
                    ),
                  ),
                ),
              if (!expanded)
                Expanded(
                  child: state.currentItem == null
                      ? const SizedBox.shrink()
                      // The page below the video fades out as the sheet
                      // is dragged down, so what lands on the bar is the
                      // video alone.
                      : Opacity(
                          opacity: 1 - collapseProgress,
                          child: _WatchDetails(
                            item: state.currentItem!,
                            descriptionExpanded: _descriptionExpanded,
                            onToggleDescription: () => setState(
                              () =>
                                  _descriptionExpanded = !_descriptionExpanded,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );

    // Shrinking toward the top keeps the video under the finger while
    // the page narrows toward the mini player's footprint.
    //
    // These wrappers are unconditional even at rest. Introducing them
    // only once the drag starts changes the shape of the tree, which
    // remounts everything below — including the GestureDetector whose
    // drag is in flight. The recognizer is then disposed mid-gesture and
    // neither onVerticalDragEnd nor onVerticalDragCancel ever fires, so
    // the player sticks halfway down with no way back.
    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Transform.scale(
        scale: 1 - collapseProgress * 0.22,
        alignment: Alignment.topCenter,
        child: scaffold,
      ),
    );
  }
}

// ============================================================
// Video surface + overlay
// ============================================================

/// What the finger currently on the player surface is doing.
enum PlayerVerticalDragMode {
  none,
  collapseOrExpand,
  leaveFullscreen,
  brightness,
  volume,
}

/// Maps the start point of a vertical player gesture to its action.
/// Extracted so fullscreen navigation remains covered by unit tests.
PlayerVerticalDragMode playerVerticalDragMode({
  required bool collapsible,
  required Offset start,
  required Size surfaceSize,
}) {
  if (collapsible) return PlayerVerticalDragMode.collapseOrExpand;

  // A top-to-bottom swipe is the inverse of portrait's upward fullscreen
  // gesture, regardless of where it starts horizontally. The broad centre
  // remains an exit zone; the lower outer edges keep brightness and volume.
  final startsNearTop = start.dy < surfaceSize.height * 0.35;
  final inExitColumn =
      start.dx > surfaceSize.width * 0.2 && start.dx < surfaceSize.width * 0.8;
  if (startsNearTop || inExitColumn) {
    return PlayerVerticalDragMode.leaveFullscreen;
  }
  return start.dx < surfaceSize.width / 2
      ? PlayerVerticalDragMode.brightness
      : PlayerVerticalDragMode.volume;
}

class _PlayerSurface extends ConsumerStatefulWidget {
  const _PlayerSurface({
    required this.state,
    required this.videoController,
    required this.showControls,
    required this.onToggleControls,
    required this.onInteract,
    required this.onToggleFullscreen,
    required this.onRetry,
    required this.onBrightnessDelta,
    required this.onVolumeDelta,
    required this.onGestureStart,
    required this.onGestureEnd,
    required this.collapsible,
    required this.onCollapseDragUpdate,
    required this.onCollapseDragEnd,
  });

  final PlayerStateData state;
  final VideoController videoController;
  final bool showControls;
  final VoidCallback onToggleControls;
  final VoidCallback onInteract;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onRetry;
  final ValueChanged<double> onBrightnessDelta;
  final ValueChanged<double> onVolumeDelta;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;

  /// Whether a downward drag collapses the player toward the mini bar.
  /// False in fullscreen, where the vertical drag means brightness and
  /// volume instead.
  final bool collapsible;
  final ValueChanged<double> onCollapseDragUpdate;
  final ValueChanged<double> onCollapseDragEnd;

  @override
  ConsumerState<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends ConsumerState<_PlayerSurface> {
  /// Which half the seek ripple is showing on, and how much has piled
  /// up. YouTube counts repeated taps rather than restarting at ten, so
  /// three quick taps read as thirty seconds.
  int? _seekSide;
  int _seekAccumulated = 0;
  Timer? _seekBadgeTimer;

  /// Speed before a press-and-hold, restored on release.
  double? _speedBeforeHold;

  @override
  void dispose() {
    _seekBadgeTimer?.cancel();
    super.dispose();
  }

  BoxFit get _fit => switch (widget.state.videoFit) {
        VideoFit.fit => BoxFit.contain,
        VideoFit.fitWidth => BoxFit.fitWidth,
        VideoFit.fitHeight => BoxFit.fitHeight,
        VideoFit.stretch => BoxFit.fill,
        VideoFit.zoom => BoxFit.cover,
      };

  void _onDoubleTap(Offset globalPosition) {
    if (!ref.read(settingsControllerProvider).doubleTapToSeek) {
      // With the gesture off, a double tap is just two taps.
      widget.onToggleControls();
      return;
    }
    final controller = ref.read(playerControllerProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final isBack = globalPosition.dx < width / 2;
    final side = isBack ? -1 : 1;
    final step = widget.state.seekInterval.inSeconds;

    if (isBack) {
      controller.seekBackward();
    } else {
      controller.seekForward();
    }
    HapticFeedback.lightImpact();

    setState(() {
      // Switching sides mid-run starts the count over rather than
      // netting off against the other direction.
      _seekAccumulated = _seekSide == side ? _seekAccumulated + step : step;
      _seekSide = side;
    });

    _seekBadgeTimer?.cancel();
    _seekBadgeTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekSide = null);
    });
    widget.onInteract();
  }

  void _startSpeedHold() {
    if (_speedBeforeHold != null) return;
    final controller = ref.read(playerControllerProvider.notifier);
    _speedBeforeHold = widget.state.playbackSpeed;
    controller.setSpeed(2);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _endSpeedHold() {
    final previous = _speedBeforeHold;
    if (previous == null) return;
    ref.read(playerControllerProvider.notifier).setSpeed(previous);
    _speedBeforeHold = null;
    setState(() {});
  }

  // ============================================================
  // Vertical drag
  // ============================================================
  //
  // What a downward drag means depends on where the player already is,
  // so the meaning is decided once when the finger lands rather than
  // re-derived on every frame:
  //
  //   portrait, down  → collapse toward the mini player
  //   portrait, up    → go fullscreen
  //   fullscreen, top or centre, down → leave fullscreen
  //   fullscreen, lower outer edges   → brightness (leading) / volume
  //
  // The starting region keeps the last two apart. A swipe from the top is
  // always navigation; lower side gestures remain brightness and volume.
  PlayerVerticalDragMode _dragMode = PlayerVerticalDragMode.none;
  double _dragTotal = 0;

  void _beginVerticalDrag(DragStartDetails details) {
    _dragTotal = 0;
    _dragMode = playerVerticalDragMode(
      collapsible: widget.collapsible,
      start: details.globalPosition,
      surfaceSize: MediaQuery.sizeOf(context),
    );
    if (_dragMode == PlayerVerticalDragMode.leaveFullscreen ||
        _dragMode == PlayerVerticalDragMode.collapseOrExpand) {
      return;
    }
    // The policy keeps exit navigation and media adjustments from fighting
    // over the same drag.
    widget.onGestureStart();
  }

  void _updateVerticalDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _dragTotal += delta;
    switch (_dragMode) {
      case PlayerVerticalDragMode.collapseOrExpand:
        // Only downward moves the sheet; an upward drag is read on
        // release instead, so it cannot fight the page scrolling below.
        if (delta > 0 || _dragTotal > 0) widget.onCollapseDragUpdate(delta);
      case PlayerVerticalDragMode.brightness:
        widget.onBrightnessDelta(-delta / MediaQuery.sizeOf(context).height);
      case PlayerVerticalDragMode.volume:
        widget.onVolumeDelta(-delta / MediaQuery.sizeOf(context).height);
      case PlayerVerticalDragMode.leaveFullscreen:
      case PlayerVerticalDragMode.none:
        break;
    }
  }

  void _endVerticalDrag(double velocity) {
    final mode = _dragMode;
    final total = _dragTotal;
    _dragMode = PlayerVerticalDragMode.none;
    _dragTotal = 0;

    switch (mode) {
      case PlayerVerticalDragMode.collapseOrExpand:
        if (total < -60 || velocity < -700) {
          widget.onCollapseDragEnd(0); // let the sheet settle back first
          widget.onToggleFullscreen();
        } else {
          widget.onCollapseDragEnd(velocity);
        }
      case PlayerVerticalDragMode.leaveFullscreen:
        if (total > 60 || velocity > 700) widget.onToggleFullscreen();
      case PlayerVerticalDragMode.brightness:
      case PlayerVerticalDragMode.volume:
        widget.onGestureEnd();
      case PlayerVerticalDragMode.none:
        break;
    }
  }

  Widget _gestureRegion({required Widget child, Key? key}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleControls,
      onDoubleTapDown: (details) => _onDoubleTap(details.globalPosition),
      onLongPressStart: (_) => _startSpeedHold(),
      onLongPressEnd: (_) => _endSpeedHold(),
      onLongPressCancel: _endSpeedHold,
      onVerticalDragStart: _beginVerticalDrag,
      onVerticalDragUpdate: _updateVerticalDrag,
      onVerticalDragEnd: (details) =>
          _endVerticalDrag(details.primaryVelocity ?? 0),
      onVerticalDragCancel: () => _endVerticalDrag(0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return ColoredBox(
      color: Colors.black,
      child: _gestureRegion(
        key: const ValueKey('player-surface-interactions'),
        // Handles blank areas whenever visible controls do not claim the
        // gesture for a button or the progress slider.
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (state.error != null)
              ErrorView(
                // The relay reports a mid-stream cutoff with a sentinel
                // rather than a message, so it can be translated here.
                // Sentinels are translated here; anything else is
                // handed over intact so ErrorView can tell an outage
                // from a pulled video from a rate limit.
                error: switch (state.error) {
                  'stream-capped' => AppLocalizations.of(context).streamCapped,
                  final String e when e.contains('live-unavailable') =>
                    AppLocalizations.of(context).liveUnavailable,
                  final e => e!,
                },
                onRetry: widget.onRetry,
              )
            else
              // controls: null hides media_kit's controls, but its video
              // surface can still join the gesture arena on a real iOS or
              // Android texture. The app owns every player gesture, so the
              // renderer must be display-only; otherwise taps and vertical
              // drags intermittently disappear before reaching the parent.
              IgnorePointer(
                child: Video(
                  controller: widget.videoController,
                  controls: null,
                  fit: _fit,
                  fill: Colors.black,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(
                      height: 1.35,
                      fontSize: 28 * state.subtitleScale,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      backgroundColor: Colors.black.withValues(
                        alpha: state.subtitleBackgroundOpacity,
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      state.subtitleOffset,
                    ),
                  ),
                  // media_kit_video defaults this to true and calls
                  // player.pause() the moment the app backgrounds. That is
                  // the right default for a widget that assumes you are
                  // watching, and it is what silently defeated background
                  // playback here: the process stayed alive and the audio
                  // session stayed active, but mpv had been paused out
                  // from under us. This app wants audio to keep going, and
                  // PlayerController drops the video track on background
                  // itself so nothing decodes off-screen.
                  pauseUponEnteringBackgroundMode: false,
                ),
              ),

            // A physical iPhone may keep the texture as the active hit-test
            // target. While controls are hidden, this plane sits directly
            // above it and guarantees that a tap or vertical swipe reaches
            // BoodTube. It disappears when controls are visible so buttons
            // and the progress slider remain directly interactive.
            if (!widget.showControls && state.error == null)
              Positioned.fill(
                child: _gestureRegion(
                  key: const ValueKey(
                    'player-hidden-controls-gesture-layer',
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

            if (state.isLoading || (state.isBuffering && state.error == null))
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    // A quality switch re-resolves the stream, which takes
                    // a few seconds; say what is happening so it does not
                    // read as the menu having ignored the tap.
                    if (state.pendingHeight != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).switchingQuality(
                          qualityLabelFor(state.pendingHeight!),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Seek ripple — the half of the screen that was tapped,
            // carrying the running total.
            if (_seekSide != null)
              Align(
                alignment: _seekSide == -1
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: _SeekBadge(
                  seconds: _seekAccumulated,
                  backward: _seekSide == -1,
                ),
              ),

            if (_speedBeforeHold != null)
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _SpeedBadge(),
                ),
              ),

            if (state.showSponsorSkipButton && state.upcomingSegment != null)
              PositionedDirectional(
                end: 12,
                bottom: 64,
                child: _SponsorSkipButton(
                  segment: state.upcomingSegment!,
                  onSkip: ref
                      .read(playerControllerProvider.notifier)
                      .skipSponsorSegment,
                ),
              ),

            if (state.error == null)
              // Fading rather than snapping: the controls appearing and
              // vanishing between frames is what made every tap feel
              // like a redraw instead of a response.
              IgnorePointer(
                ignoring: !widget.showControls,
                child: AnimatedOpacity(
                  opacity: widget.showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _ControlsOverlay(
                    state: state,
                    onInteract: widget.onInteract,
                    onToggleFullscreen: widget.onToggleFullscreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "+30 seconds" bubble YouTube flashes on a double tap.
class _SeekBadge extends StatelessWidget {
  const _SeekBadge({required this.seconds, required this.backward});

  final int seconds;
  final bool backward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 116,
      height: 116,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            backward ? Icons.fast_rewind : Icons.fast_forward,
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.seekSeconds(seconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while the screen is held down for double speed.
class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '2×',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.fast_forward, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends ConsumerWidget {
  const _ControlsOverlay({
    required this.state,
    required this.onInteract,
    required this.onToggleFullscreen,
  });

  final PlayerStateData state;
  final VoidCallback onInteract;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);
    final quickActions = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.playerQuickActions,
      ),
    );

    // Slider and IconButton both require a Material ancestor, and this
    // overlay cannot rely on the Scaffold's: the player surface is
    // wrapped in a Hero, and a Hero in flight is lifted into the
    // Navigator's overlay, outside the Scaffold entirely. Supplying a
    // transparent Material here keeps the controls valid wherever the
    // subtree is mounted.
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent, Colors.black87],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    if (state.isFullscreen) {
                      onToggleFullscreen();
                    } else {
                      context.pop();
                    }
                  },
                ),
                const Spacer(),
                // Only where the platform can actually do it. On iOS PiP
                // needs an AVPlayerLayer the system owns, and mpv renders
                // into a texture — so the button would never do anything
                // but show an apology.
                for (final action in quickActions)
                  if (action != PlayerQuickAction.pictureInPicture ||
                      (PiPManager.isAvailableOnThisPlatform &&
                          ref.watch(settingsControllerProvider
                              .select((s) => s.pictureInPictureEnabled))))
                    _QuickActionButton(
                      action: action,
                      item: state.currentItem,
                      hasSubtitles:
                          state.currentItem?.subtitles.isNotEmpty ?? false,
                      onInteract: onInteract,
                    ),
              ],
            ),

            // Center transport
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundControl(
                    icon: Icons.replay_10,
                    onTap: () {
                      controller.seekBackward();
                      onInteract();
                    },
                  ),
                  const SizedBox(width: 28),
                  _RoundControl(
                    icon: state.isPlaying
                        ? Icons.pause
                        : (state.position >= state.duration &&
                                state.duration > Duration.zero)
                            ? Icons.replay
                            : Icons.play_arrow,
                    size: 44,
                    onTap: () {
                      controller.togglePlayPause();
                      onInteract();
                    },
                  ),
                  const SizedBox(width: 28),
                  _RoundControl(
                    icon: Icons.forward_10,
                    onTap: () {
                      controller.seekForward();
                      onInteract();
                    },
                  ),
                ],
              ),
            ),

            // Current chapter, the way YouTube labels the scrubber.
            if (_currentChapter(state) != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _currentChapter(state)!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Bottom bar
            _ScrubBar(
              state: state,
              onInteract: onInteract,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.action,
    required this.item,
    required this.hasSubtitles,
    required this.onInteract,
  });

  final PlayerQuickAction action;
  final MediaItem? item;
  final bool hasSubtitles;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = switch (action) {
      PlayerQuickAction.cast => item != null,
      PlayerQuickAction.subtitles => hasSubtitles,
      _ => true,
    };
    if (action == PlayerQuickAction.cast) {
      return IconButton(
        tooltip: l10n.castToTv,
        icon: Icon(Icons.cast, color: enabled ? Colors.white : Colors.white38),
        onPressed: !enabled
            ? null
            : () async {
                onInteract();
                await showCastDeviceSheet(context, item!);
              },
      );
    }
    if (action == PlayerQuickAction.pictureInPicture) {
      return IconButton(
        tooltip: l10n.pictureInPicture,
        icon: const Icon(
          Icons.picture_in_picture_alt_outlined,
          color: Colors.white,
        ),
        onPressed: () async {
          onInteract();
          final ok = await PiPManager.enterPiP();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.pipUnavailable)),
            );
          }
        },
      );
    }
    final (icon, tooltip, page) = switch (action) {
      PlayerQuickAction.cast => (Icons.cast, l10n.castToTv, null),
      PlayerQuickAction.pictureInPicture => (
          Icons.picture_in_picture_alt_outlined,
          l10n.pictureInPicture,
          null,
        ),
      PlayerQuickAction.subtitles => (
          Icons.closed_caption_outlined,
          l10n.subtitles,
          PlayerSettingsPage.subtitles,
        ),
      PlayerQuickAction.quality => (
          Icons.high_quality_outlined,
          l10n.quality,
          PlayerSettingsPage.quality,
        ),
      PlayerQuickAction.speed => (
          Icons.speed,
          l10n.playbackSpeed,
          PlayerSettingsPage.speed,
        ),
      PlayerQuickAction.videoFit => (
          Icons.aspect_ratio,
          l10n.videoZoom,
          PlayerSettingsPage.videoFit,
        ),
      PlayerQuickAction.stats => (
          Icons.info_outline,
          l10n.statsForNerds,
          PlayerSettingsPage.stats,
        ),
      PlayerQuickAction.settings => (
          Icons.settings,
          l10n.settingsTab,
          PlayerSettingsPage.root,
        ),
    };

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: enabled ? Colors.white : Colors.white38),
      onPressed: !enabled
          ? null
          : () async {
              onInteract();
              if (context.mounted && page != null) {
                await showPlayerSettings(context, initialPage: page);
              }
            },
    );
  }
}

/// Elapsed time, the scrubber and the fullscreen toggle.
///
/// Owns the drag itself: the old slider seeked on every drag frame,
/// which fired dozens of seeks for one sweep and stuttered the whole
/// way. Here the thumb follows the finger locally and exactly one seek
/// is issued on release.
class _ScrubBar extends ConsumerStatefulWidget {
  const _ScrubBar({
    required this.state,
    required this.onInteract,
    required this.onToggleFullscreen,
  });

  final PlayerStateData state;
  final VoidCallback onInteract;
  final VoidCallback onToggleFullscreen;

  @override
  ConsumerState<_ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends ConsumerState<_ScrubBar> {
  /// Position under the finger while dragging, in milliseconds. Null
  /// when not dragging, so playback drives the thumb.
  double? _scrubMs;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final duration = state.duration.inMilliseconds
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();
    final value = (_scrubMs ?? state.position.inMilliseconds.toDouble())
        .clamp(0, duration)
        .toDouble();
    final chapters = state.currentItem?.chapters ?? const <ChapterItem>[];

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 6),
      child: Row(
        children: [
          Text(
            DurationFormatter.format(Duration(milliseconds: value.toInt())),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // How much is safe to watch without waiting, and where
                // the chapters break — both drawn under the thumb.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CustomPaint(
                      painter: _TrackPainter(
                        chapters: chapters,
                        duration: state.duration,
                        buffered: state.buffered,
                      ),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: YouTubeColors.red,
                    // Transparent so the buffered range painted beneath
                    // shows through instead of being covered by it.
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: YouTubeColors.red,
                  ),
                  child: Slider(
                    value: value,
                    max: duration,
                    label: DurationFormatter.format(
                      Duration(milliseconds: value.toInt()),
                    ),
                    onChangeStart: (_) {
                      HapticFeedback.selectionClick();
                      widget.onInteract();
                    },
                    onChanged: (next) {
                      setState(() => _scrubMs = next);
                      widget.onInteract();
                    },
                    onChangeEnd: (next) {
                      controller.seek(Duration(milliseconds: next.toInt()));
                      setState(() => _scrubMs = null);
                      widget.onInteract();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Total duration, or the time left — tapping flips between the
          // two, and the choice sticks (the "remaining time" setting).
          Builder(builder: (context) {
            final showRemaining = ref.watch(
              settingsControllerProvider.select((s) => s.showRemainingTime),
            );
            final remaining =
                state.duration - Duration(milliseconds: value.toInt());
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onInteract();
                ref
                    .read(settingsControllerProvider.notifier)
                    .setShowRemainingTime(!showRemaining);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  showRemaining
                      ? '-${DurationFormatter.format(remaining)}'
                      : DurationFormatter.format(state.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            );
          }),
          IconButton(
            tooltip: state.isFullscreen ? l10n.exitFullscreen : l10n.fullscreen,
            icon: Icon(
              state.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: widget.onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

/// The chapter containing the playhead, or null when there are none.
ChapterItem? _currentChapter(PlayerStateData state) {
  final chapters = state.currentItem?.chapters ?? const <ChapterItem>[];
  if (chapters.isEmpty) return null;
  ChapterItem? current;
  for (final chapter in chapters) {
    if (chapter.start <= state.position) {
      current = chapter;
    } else {
      break;
    }
  }
  return current;
}

/// The unplayed track, the buffered stretch on top of it, and a tick at
/// every chapter boundary.
///
/// The buffered range was already being tracked and only ever surfaced
/// as a number in the stats menu. Drawn here it answers the question a
/// stalled video actually raises: wait, or drop the quality?
class _TrackPainter extends CustomPainter {
  const _TrackPainter({
    required this.chapters,
    required this.duration,
    required this.buffered,
  });

  final List<ChapterItem> chapters;
  final Duration duration;
  final Duration buffered;

  @override
  void paint(Canvas canvas, Size size) {
    final total = duration.inMilliseconds;
    if (total <= 0) return;

    const trackHeight = 3.0;
    final centerY = size.height / 2;
    final top = centerY - trackHeight / 2;

    // Unplayed track.
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, trackHeight),
      Paint()..color = Colors.white24,
    );

    // Buffered ahead of the playhead.
    final bufferedFraction = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
    if (bufferedFraction > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, top, size.width * bufferedFraction, trackHeight),
        Paint()..color = Colors.white54,
      );
    }

    // Chapter boundaries. Ticks scale with the video: 0.4% of the
    // width, floor 2px.
    final markPaint = Paint()..color = Colors.black87;
    final markWidth = (size.width * 0.004).clamp(2.0, 4.0);
    for (final chapter in chapters) {
      final startMs = chapter.start.inMilliseconds;
      if (startMs <= 0 || startMs >= total) continue;
      final x = size.width * (startMs / total);
      canvas.drawRect(
        Rect.fromLTWH(x - markWidth / 2, top, markWidth, trackHeight),
        markPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.chapters != chapters ||
      oldDelegate.duration != duration ||
      oldDelegate.buffered != buffered;
}

class _RoundControl extends StatelessWidget {
  const _RoundControl(
      {required this.icon, required this.onTap, this.size = 34});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onTap,
    );
  }
}

class _SponsorSkipButton extends StatelessWidget {
  const _SponsorSkipButton({required this.segment, required this.onSkip});
  final SponsorSegment segment;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onSkip,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.skip_next, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                l10n.skipCategory(segment.category.label(l10n)),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Below-the-player watch page
// ============================================================

class _WatchDetails extends ConsumerWidget {
  const _WatchDetails({
    required this.item,
    required this.descriptionExpanded,
    required this.onToggleDescription,
  });

  final MediaItem item;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isFavorite = ref.watch(isFavoriteProvider(item.videoId));
    final isSaved = ref.watch(isWatchLaterProvider(item.videoId));
    final isSubscribed = ref.watch(isSubscribedProvider(item.channelId));
    final download = ref.watch(downloadForVideoProvider(item.videoId));
    // YouTube's own related list. This used to be a text search for the
    // video's own title, which mostly returned the same channel's back
    // catalogue instead of anything new.
    final related = ref.watch(relatedVideosProvider(item.videoId));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Title + metadata
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: descriptionExpanded ? null : 2,
                overflow: descriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                <String>[
                  if (item.viewCount != null)
                    l10n.viewsCount(compactCount(item.viewCount!)),
                  relativeDate(l10n, item.publishedAt),
                ].where((p) => p.isNotEmpty).join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // Action pills — YouTube's row under the title
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _LikeDislikePill(item: item, liked: isFavorite.value ?? false),
              _ActionPill(
                icon: Icons.reply,
                label: l10n.share,
                flipIcon: true,
                // The system sheet, not a clipboard copy — sharing a
                // video means picking who to send it to.
                onTap: () => Share.share(
                  'https://youtu.be/${item.videoId}',
                  subject: item.title,
                ),
              ),
              _DownloadPill(item: item, download: download),
              _ActionPill(
                icon: isSaved.value ?? false
                    ? Icons.playlist_add_check
                    : Icons.playlist_add,
                label: l10n.save,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(libraryActionsProvider).toggleWatchLater(item);
                },
              ),
              _ActionPill(
                icon: Icons.comment_outlined,
                label: l10n.comments,
                // A sheet, so the video keeps playing above it instead
                // of being replaced by a page.
                onTap: () => showCommentsSheet(context, item.videoId),
              ),
              if (item.isLive)
                _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.liveChat,
                  onTap: () => showLiveChatSheet(context, item.videoId),
                ),
            ],
          ),
        ),

        const Divider(height: 20),

        // Channel row
        ListTile(
          onTap: () => context.push('/channel/${item.channelId}'),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: item.channelAvatarUrl != null
                ? CachedNetworkImageProvider(item.channelAvatarUrl!)
                : null,
            child: item.channelAvatarUrl == null
                ? Text(
                    item.author.isNotEmpty
                        ? item.author.characters.first.toUpperCase()
                        : '?',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  )
                : null,
          ),
          title: Text(
            item.author,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Subscriber count is the other half of the decision to
          // subscribe; the name alone says nothing about reach.
          subtitle: item.subscriberCount != null
              ? Text(
                  l10n.subscriberCount(compactCount(item.subscriberCount!)),
                  style: theme.textTheme.bodySmall,
                )
              : null,
          trailing: FilledButton.tonal(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref
                  .read(libraryActionsProvider)
                  .toggleSubscription(item.channelId, item.author);
            },
            child: Text(
              (isSubscribed.value ?? false) ? l10n.subscribed : l10n.subscribe,
            ),
          ),
        ),

        // Description
        if (item.description != null && item.description!.isNotEmpty)
          _DescriptionBlock(
            description: item.description!,
            expanded: descriptionExpanded,
            onToggle: onToggleDescription,
          ),

        const Divider(height: 20),

        // Chapters — tap to jump, like YouTube's chapter list.
        if (item.chapters.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(l10n.chapters, style: theme.textTheme.titleSmall),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: item.chapters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chapter = item.chapters[index];
                return ActionChip(
                  label: Text(
                    '${DurationFormatter.format(chapter.start)}  '
                    '${chapter.title}',
                  ),
                  onPressed: () => ref
                      .read(playerControllerProvider.notifier)
                      .seek(chapter.start),
                );
              },
            ),
          ),
          const Divider(height: 20),
        ],

        // Suggestions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.upNext, style: theme.textTheme.titleSmall),
        ),
        related.when(
          data: (videos) {
            final items = videos
                .where((MediaItem v) => v.videoId != item.videoId)
                .take(15)
                .toList();
            return Column(
              children: [
                for (final video in items)
                  SizedBox(
                    // Fits the 90px thumbnail plus the three-line text
                    // column the horizontal card lays out beside it.
                    height: 122,
                    child: VideoCard(
                      item: video,
                      isHorizontal: true,
                      onTap: () => context.pushReplacement(
                        '/player/${video.videoId}',
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The description, with its timestamps turned into jump links.
///
/// Long uploads carry their own chapter list in the description — a
/// plain text block makes the reader scrub for a mark they can already
/// see written down.
class _DescriptionBlock extends ConsumerStatefulWidget {
  const _DescriptionBlock({
    required this.description,
    required this.expanded,
    required this.onToggle,
  });

  final String description;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<_DescriptionBlock> createState() => _DescriptionBlockState();
}

class _DescriptionBlockState extends ConsumerState<_DescriptionBlock> {
  /// `1:23` or `01:02:03`, not preceded or followed by another digit.
  static final _timestamp =
      RegExp(r'(?<!\d)(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?!\d)');

  /// Held for the widget's lifetime rather than rebuilt per frame —
  /// gesture recognizers have to be disposed, and one created inside
  /// build never is.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  static Duration _parse(RegExpMatch match) {
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.description;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final baseStyle = theme.textTheme.bodySmall;
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _timestamp.allMatches(description)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: description.substring(cursor, match.start)));
      }
      final target = _parse(match);
      final recognizer = TapGestureRecognizer()
        ..onTap =
            () => ref.read(playerControllerProvider.notifier).seek(target);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: match[0], style: linkStyle, recognizer: recognizer),
      );
      cursor = match.end;
    }
    if (cursor < description.length) {
      spans.add(TextSpan(text: description.substring(cursor)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(style: baseStyle, children: spans),
            maxLines: widget.expanded ? null : 3,
            overflow:
                widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                widget.expanded ? l10n.showLess : l10n.showMore,
                style: baseStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pill in the row under the video (Share, Save, Comments...).
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.flipIcon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Share uses a mirrored reply arrow, like YouTube does.
  final bool flipIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconWidget = Icon(icon, size: 20, color: theme.colorScheme.onSurface);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: theme.yt.actionPillBackground,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flipIcon)
                  Transform.flip(flipX: true, child: iconWidget)
                else
                  iconWidget,
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Like and dislike share one pill with a divider, as on YouTube.
/// The like count comes from Return YouTube Dislike when available.
class _LikeDislikePill extends ConsumerWidget {
  const _LikeDislikePill({required this.item, required this.liked});

  final MediaItem item;
  final bool liked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final votes = ref.watch(videoVotesProvider(item.videoId)).value;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: theme.yt.actionPillBackground,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () =>
                  ref.read(libraryActionsProvider).toggleFavorite(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      votes == null
                          ? AppLocalizations.of(context).like
                          : _compact(votes.likes),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 24, color: theme.dividerColor),
            InkWell(
              onTap: () =>
                  ref.read(libraryActionsProvider).dislike(item.videoId),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thumb_down_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    if (votes != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _compact(votes.dislikes),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _DownloadPill extends ConsumerWidget {
  const _DownloadPill({required this.item, required this.download});

  final MediaItem item;
  final AsyncValue<DownloadProgress?> download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = download.value;
    final label = switch (progress?.status) {
      DownloadStatus.downloading =>
        l10n.percentValue(((progress?.progress ?? 0) * 100).round()),
      DownloadStatus.completed => l10n.downloaded,
      DownloadStatus.failed => l10n.retry,
      _ => l10n.download,
    };
    final icon = switch (progress?.status) {
      DownloadStatus.downloading => Icons.downloading,
      DownloadStatus.completed => Icons.download_done,
      DownloadStatus.failed => Icons.error_outline,
      _ => Icons.download_outlined,
    };

    return _ActionPill(
      icon: icon,
      label: label,
      onTap: () async {
        if (progress?.status == DownloadStatus.completed) {
          context.push('/downloads');
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(downloadsControllerProvider.notifier).download(item);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.downloadStarted)),
        );
      },
    );
  }
}
