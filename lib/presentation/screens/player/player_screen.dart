// ============================================================
// PlayerScreen — YouTube-style watch page
// ============================================================
// 16:9 player on top with an auto-hiding control overlay, then the
// title/action row, channel row, description and suggestions below.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/utils/duration_formatter.dart';
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
import '../../theme/app_theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/video_card.dart';
import 'widgets/player_settings_sheet.dart';

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
      TargetPlatform.iOS || TargetPlatform.macOS =>
        const VideoControllerConfiguration(hwdec: 'videotoolbox'),
      _ => const VideoControllerConfiguration(),
    };

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.videoId,
    this.offline = false,
  });

  final String videoId;

  /// Play the downloaded copy instead of streaming.
  final bool offline;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final VideoController _videoController;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _descriptionExpanded = false;

  /// Transient HUD shown while dragging for brightness/volume.
  double? _gestureValue;
  IconData? _gestureIcon;
  double _brightness = 0.5;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(
      ref.read(mediaPlayerProvider),
      configuration: _videoOutputConfiguration,
    );

    PiPManager.install(
      onModeChanged: (active) {
        if (!mounted) return;
        ref.read(playerControllerProvider.notifier).setPiPActive(active);
        setState(() => _showControls = !active);
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
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _restartHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    final controller = ref.read(playerControllerProvider.notifier);
    final next = !ref.read(playerControllerProvider).isFullscreen;
    controller.setFullscreen(next);
    if (next) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    final player = _PlayerSurface(
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
    );

    // One tree for every mode: the Video element must keep its identity
    // or its native surface is torn down and re-created, which leaves a
    // black window when entering PiP or fullscreen.
    final expanded = isFullscreen || state.isPiPActive;

    return Scaffold(
      backgroundColor:
          expanded ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: PopScope(
        canPop: !isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        child: SafeArea(
          top: !expanded,
          bottom: !expanded,
          child: Column(
            children: [
              if (expanded)
                Expanded(
                  child: Stack(
                    children: [player, _gestureHud()],
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [player, _gestureHud()],
                  ),
                ),
              if (!expanded)
                Expanded(
                  child: state.currentItem == null
                      ? const SizedBox.shrink()
                      : _WatchDetails(
                          item: state.currentItem!,
                          descriptionExpanded: _descriptionExpanded,
                          onToggleDescription: () => setState(
                            () => _descriptionExpanded = !_descriptionExpanded,
                          ),
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
// Video surface + overlay
// ============================================================

class _PlayerSurface extends ConsumerWidget {
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

  BoxFit get _fit => switch (state.videoFit) {
        VideoFit.fit => BoxFit.contain,
        VideoFit.fitWidth => BoxFit.fitWidth,
        VideoFit.fitHeight => BoxFit.fitHeight,
        VideoFit.stretch => BoxFit.fill,
        VideoFit.zoom => BoxFit.cover,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        onTap: onToggleControls,
        onDoubleTapDown: (details) {
          final width = MediaQuery.sizeOf(context).width;
          if (details.globalPosition.dx < width / 2) {
            controller.seekBackward();
          } else {
            controller.seekForward();
          }
          onInteract();
        },
        // Vertical drag: brightness on the left half, volume on the
        // right — the gesture every mobile video app uses.
        onVerticalDragStart: (_) => onGestureStart(),
        onVerticalDragUpdate: (details) {
          final size = MediaQuery.sizeOf(context);
          // Full height of the surface ≈ a full sweep of the range.
          final delta = -details.primaryDelta! / size.height;
          if (details.globalPosition.dx < size.width / 2) {
            onBrightnessDelta(delta);
          } else {
            onVolumeDelta(delta);
          }
        },
        onVerticalDragEnd: (_) => onGestureEnd(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (state.error != null)
              ErrorView(
                // The relay reports a mid-stream cutoff with a sentinel
                // rather than a message, so it can be translated here.
                error: switch (state.error) {
                  'stream-capped' =>
                    AppLocalizations.of(context).streamCapped,
                  final e when e != null && e.contains('live-unavailable') =>
                    AppLocalizations.of(context).liveUnavailable,
                  _ => state.error!,
                },
                onRetry: onRetry,
              )
            else
              Video(
                controller: videoController,
                controls: null,
                fit: _fit,
                fill: Colors.black,
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

            if (state.showSponsorSkipButton && state.upcomingSegment != null)
              Positioned(
                right: 12,
                bottom: 64,
                child: _SponsorSkipButton(
                  segment: state.upcomingSegment!,
                  onSkip: controller.skipSponsorSegment,
                ),
              ),

            if (showControls && state.error == null)
              _ControlsOverlay(
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
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final duration = state.duration.inMilliseconds
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();

    return DecoratedBox(
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
              if (PiPManager.isAvailableOnThisPlatform)
                IconButton(
                  tooltip: l10n.pictureInPicture,
                  icon: const Icon(Icons.picture_in_picture_alt_outlined,
                      color: Colors.white),
                  onPressed: () async {
                    final ok = await PiPManager.enterPiP();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.pipUnavailable)),
                      );
                    }
                  },
                ),
              IconButton(
                tooltip: l10n.settingsTab,
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  onInteract();
                  showPlayerSettings(context);
                },
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Text(
                  DurationFormatter.format(state.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Chapter boundaries, drawn under the slider.
                      if (state.currentItem != null &&
                          state.currentItem!.chapters.isNotEmpty &&
                          state.duration > Duration.zero)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: CustomPaint(
                              painter: _ChapterMarkersPainter(
                                chapters: state.currentItem!.chapters,
                                duration: state.duration,
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
                          inactiveTrackColor: Colors.white24,
                          thumbColor: YouTubeColors.red,
                        ),
                        child: Slider(
                          value: state.position.inMilliseconds
                              .toDouble()
                              .clamp(0, duration),
                          max: duration,
                          onChanged: (value) {
                            controller
                                .seek(Duration(milliseconds: value.toInt()));
                            onInteract();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DurationFormatter.format(state.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                IconButton(
                  icon: Icon(
                    state.isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
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

/// Thin ticks on the progress bar at each chapter boundary.
class _ChapterMarkersPainter extends CustomPainter {
  const _ChapterMarkersPainter({
    required this.chapters,
    required this.duration,
  });

  final List<ChapterItem> chapters;
  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    final total = duration.inMilliseconds;
    if (total <= 0) return;
    final paint = Paint()..color = Colors.black87;
    // Ticks scale with the video: 0.4% of the width, floor 2px.
    final markWidth = (size.width * 0.004).clamp(2.0, 4.0);
    final centerY = size.height / 2;

    for (final chapter in chapters) {
      final startMs = chapter.start.inMilliseconds;
      if (startMs <= 0 || startMs >= total) continue;
      final x = size.width * (startMs / total);
      canvas.drawRect(
        Rect.fromLTWH(x - markWidth / 2, centerY - 1.5, markWidth, 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChapterMarkersPainter oldDelegate) =>
      oldDelegate.chapters != chapters || oldDelegate.duration != duration;
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.onTap, this.size = 34});
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
    final related = ref.watch(searchResultsProvider(item.title));

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
                    l10n.viewsCount(_compactCount(item.viewCount!)),
                  _relativeDate(l10n, item.publishedAt),
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
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: 'https://youtu.be/${item.videoId}'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.linkCopied)),
                    );
                  }
                },
              ),
              _DownloadPill(item: item, download: download),
              _ActionPill(
                icon: isSaved.value ?? false
                    ? Icons.playlist_add_check
                    : Icons.playlist_add,
                label: l10n.save,
                onTap: () =>
                    ref.read(libraryActionsProvider).toggleWatchLater(item),
              ),
              _ActionPill(
                icon: Icons.comment_outlined,
                label: l10n.comments,
                onTap: () => context.push('/comments/${item.videoId}'),
              ),
            ],
          ),
        ),

        const Divider(height: 20),

        // Channel row
        ListTile(
          onTap: () => context.push('/channel/${item.channelId}'),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              item.author.isNotEmpty ? item.author[0].toUpperCase() : '?',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          title: Text(
            item.author,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: FilledButton.tonal(
            onPressed: () => ref
                .read(libraryActionsProvider)
                .toggleSubscription(item.channelId, item.author),
            child: Text(
              (isSubscribed.value ?? false) ? l10n.subscribed : l10n.subscribe,
            ),
          ),
        ),

        // Description
        if (item.description != null && item.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: InkWell(
              onTap: onToggleDescription,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description!,
                    maxLines: descriptionExpanded ? null : 3,
                    overflow: descriptionExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    descriptionExpanded ? l10n.showLess : l10n.showMore,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
          data: (groups) {
            final items = groups.mediaItems
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

  static String _compactCount(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  static String _relativeDate(AppLocalizations l10n, DateTime date) {
    if (date.isBefore(DateTime.utc(2005))) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return l10n.yearsAgo(diff.inDays ~/ 365);
    if (diff.inDays >= 30) return l10n.monthsAgo(diff.inDays ~/ 30);
    if (diff.inDays >= 7) return l10n.weeksAgo(diff.inDays ~/ 7);
    if (diff.inDays >= 1) return l10n.daysAgo(diff.inDays);
    if (diff.inHours >= 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inMinutes >= 1) return l10n.minutesAgo(diff.inMinutes);
    return l10n.justNow;
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
      padding: const EdgeInsets.only(right: 8),
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
      padding: const EdgeInsets.only(right: 8),
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
              onTap: () => ref
                  .read(libraryActionsProvider)
                  .dislike(item.videoId),
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
