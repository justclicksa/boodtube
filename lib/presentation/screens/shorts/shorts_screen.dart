// ============================================================
// ShortsScreen — full-screen vertical pager (YouTube Shorts)
// ============================================================
// One shared mpv Player drives the whole pager. The page that is on
// screen owns playback; every other page is just a poster frame. That
// ownership moves in `onPageChanged` and nowhere else — the old code
// gave every page its own VideoController over the same singleton and
// called `open()` from `initState`, so the page being built ahead of
// the user clobbered the one they were watching, and a `dispose()` that
// deliberately did nothing meant swiping away never stopped the audio.
//
// Every open is stamped with a token: a resolve that finishes after the
// user has already swiped past its page drops its result instead of
// taking the player over.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/youtube/mappers/media_item_mapper.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/media_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/local_library_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/loading_view.dart';

/// Shorts have no dedicated endpoint in youtube_explode, so this
/// searches for them and keeps only genuinely short videos.
final shortsProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final client = ref.watch(innerTubeClientProvider);

  // One query for "#shorts" returned a page of mostly full-length
  // videos, of which a single clip survived the duration filter — a
  // one-item feed. Several queries merged give the rail something to
  // actually scroll.
  const queries = ['#shorts', 'shorts', '#shortsfeed', 'short video'];
  final pages = await Future.wait(
    queries.map((q) async {
      try {
        final videos = await client.search(q);
        return videos.map(MediaItemMapper.fromVideo).toList();
      } on Exception {
        // One dead query must not empty the whole rail.
        return const <MediaItem>[];
      }
    }),
  );

  final seen = <String>{};
  final shorts = <MediaItem>[];
  for (final item in pages.expand((page) => page)) {
    if (!_looksLikeAShort(item)) continue;
    if (!seen.add(item.videoId)) continue;
    // The mapper cannot tell a short from any other video, so the flag
    // is set here — the home feed relies on it to keep shorts out of
    // the 16:9 card list.
    shorts.add(item.copyWith(isShorts: true));
    if (shorts.length >= 30) break;
  }
  return shorts;
});

/// Same rule the content filter uses: under 90 seconds, or under three
/// minutes with a hashtag in the title.
bool _looksLikeAShort(MediaItem item) {
  final ms = item.duration.inMilliseconds;
  if (ms <= 0) return false;
  if (ms <= 90 * 1000) return true;
  return ms <= 180 * 1000 && item.title.contains('#');
}

/// How mpv gets frames onto the screen, per platform. Mirrors the
/// player screen: mpv's default `vo=gpu` cannot create an EGL context on
/// the Android emulator, and VideoToolbox is the hardware decoder on
/// Apple platforms.
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

class ShortsScreen extends ConsumerWidget {
  const ShortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shortsAsync = ref.watch(shortsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: shortsAsync.when(
        data: (shorts) {
          if (shorts.isEmpty) {
            return _ShortsMessage(
              icon: Icons.video_library_outlined,
              message: l10n.shortsEmpty,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(shortsProvider),
            );
          }
          return _ShortsPager(shorts: shorts);
        },
        loading: () => const LoadingView(),
        error: (e, st) => _ShortsMessage(
          icon: Icons.error_outline,
          message: l10n.shortsLoadFailed,
          detail: e.toString(),
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(shortsProvider),
        ),
      ),
    );
  }
}

/// Empty / failure state. Both need the same dark treatment and both
/// need a way out, which the error state previously did not have.
class _ShortsMessage extends StatelessWidget {
  const _ShortsMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// The pager — the single owner of playback on this screen
// ============================================================

class _ShortsPager extends ConsumerStatefulWidget {
  const _ShortsPager({required this.shorts});

  final List<MediaItem> shorts;

  @override
  ConsumerState<_ShortsPager> createState() => _ShortsPagerState();
}

class _ShortsPagerState extends ConsumerState<_ShortsPager> {
  late final PageController _pageController;
  late final VideoController _videoController;

  /// Captured up front so `dispose()` never has to touch `ref`.
  late final Player _player;
  late final PlayerController _playerController;

  StreamSubscription<bool>? _completedSub;

  int _index = 0;

  /// Bumped on every playback request. An `open()` still resolving when
  /// a newer request starts sees a stale token and bows out, so the last
  /// swipe always wins rather than whichever network call returns last.
  int _openToken = 0;

  bool _resolving = false;
  Object? _resolveError;

  /// The tab this screen lives in is kept mounted inside an IndexedStack,
  /// so `dispose()` never runs when the user switches tabs. TickerMode is
  /// how go_router signals that the branch went off-screen.
  bool _visible = true;

  /// What the rest of the app had its repeat mode set to before Shorts
  /// forced looping on, so leaving does not strand the player on loop.
  RepeatMode? _previousRepeatMode;

  bool _showHeart = false;
  Timer? _heartTimer;

  MediaItem get _current => widget.shorts[_index];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _player = ref.read(mediaPlayerProvider);
    _playerController = ref.read(playerControllerProvider.notifier);
    _videoController = VideoController(
      _player,
      configuration: _videoOutputConfiguration,
    );

    // Belt to the repeat-mode braces below: if anything else resets the
    // shared repeat mode while Shorts is on screen, the clip still loops
    // instead of freezing on its last frame.
    _completedSub = _player.stream.completed.listen((completed) {
      if (!completed || !mounted || !_visible) return;
      if (ref.read(playerControllerProvider).repeatMode == RepeatMode.one) {
        return;
      }
      unawaited(_player.seek(Duration.zero));
      unawaited(_player.play());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enableLooping();
      unawaited(_playIndex(0));
    });
  }

  @override
  void didUpdateWidget(covariant _ShortsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed feed can be shorter than the one being paged through.
    if (_index >= widget.shorts.length) {
      _index = widget.shorts.length - 1;
      _pageController.jumpToPage(_index);
      unawaited(_playIndex(_index));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;

    // Both branches set the player's repeat mode, and this runs inside
    // the build pass. Writing a provider there throws, and the failed
    // notification aborts the rest of that rebuild — which quietly left
    // other widgets (the home Shorts shelf among them) stuck dirty and
    // never repainted. Deferring one frame keeps the write legal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (visible) {
        _enableLooping();
        // The player may well have been handed to a full watch page
        // while this tab was in the background, so re-take it rather
        // than resuming whatever happens to be loaded.
        unawaited(_playIndex(_index));
      } else {
        _openToken++; // strand any resolve still in flight
        _restoreLooping();
        unawaited(_player.pause());
      }
    });

    // Pausing is safe to do immediately and should not wait a frame —
    // audio from a tab you just left is the one thing that cannot lag.
    if (!visible) {
      _openToken++;
      unawaited(_player.pause());
    }
  }

  @override
  void dispose() {
    _openToken++;
    _completedSub?.cancel();
    _heartTimer?.cancel();
    unawaited(_player.pause());
    // Same rule as didChangeDependencies: a provider may not be written
    // during dispose. The controller outlives this screen, so handing
    // the repeat mode back a frame later is safe.
    final previous = _previousRepeatMode;
    _previousRepeatMode = null;
    if (previous != null) {
      final controller = _playerController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setRepeatMode(previous);
      });
    }
    _pageController.dispose();
    super.dispose();
  }

  // ---------- looping ----------

  void _enableLooping() {
    _previousRepeatMode ??= ref.read(playerControllerProvider).repeatMode;
    _playerController.setRepeatMode(RepeatMode.one);
  }

  void _restoreLooping() {
    final previous = _previousRepeatMode;
    if (previous == null) return;
    _previousRepeatMode = null;
    _playerController.setRepeatMode(previous);
  }

  // ---------- playback ----------

  /// Takes the shared player over for [index]. Everything before the
  /// final `open()` is cancellable, and the pause up front means the
  /// outgoing clip stops the instant the user swipes, not whenever the
  /// next one happens to finish resolving.
  Future<void> _playIndex(int index) async {
    final token = ++_openToken;
    await _player.pause();
    if (!mounted || token != _openToken) return;

    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    try {
      final item = widget.shorts[index];
      final proxy = ref.read(streamProxyProvider);
      await proxy.start();
      final resolved = await ref
          .read(streamResolverProvider)
          .getBestStream(
            item.videoId,
            quality: MediaFormatQuality.medium,
            probe: proxy.probe,
          )
          .timeout(const Duration(seconds: 45));
      if (!mounted || token != _openToken) return;

      // Relay through the loopback proxy for the same reason the watch
      // page does: mpv's bundled TLS cannot reach googlevideo reliably.
      final videoUrl = proxy.register(Uri.parse(resolved.videoUrl));
      String? audioUrl;
      if (resolved.audioUrl != null && resolved.audioUrl!.isNotEmpty) {
        audioUrl = proxy.register(Uri.parse(resolved.audioUrl!));
      }
      proxy.retainOnly([videoUrl, if (audioUrl != null) audioUrl]);
      if (!mounted || token != _openToken) return;

      await _player.open(Media(videoUrl), play: _visible);
      if (audioUrl != null) {
        await _player.setAudioTrack(AudioTrack.uri(audioUrl));
      }

      // One last check: a swipe during `open()` means this clip is
      // already stale by the time it starts.
      if (token != _openToken || !_visible) {
        await _player.pause();
        return;
      }
      if (mounted) setState(() => _resolving = false);
    } catch (e) {
      if (!mounted || token != _openToken) return;
      setState(() {
        _resolving = false;
        _resolveError = e;
      });
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.lightImpact();
    setState(() => _index = index);
    unawaited(_playIndex(index));
  }

  void _togglePlayPause() {
    if (_player.state.playing) {
      unawaited(_player.pause());
    } else {
      unawaited(_player.play());
    }
  }

  // ---------- actions ----------

  Future<void> _toggleLike(MediaItem item) async {
    unawaited(HapticFeedback.lightImpact());
    await ref.read(libraryActionsProvider).toggleFavorite(item);
  }

  Future<void> _doubleTapLike() async {
    final item = _current;
    final liked =
        ref.read(isFavoriteProvider(item.videoId)).valueOrNull ?? false;
    unawaited(HapticFeedback.lightImpact());
    _heartTimer?.cancel();
    setState(() => _showHeart = true);
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
    // Double tap only ever likes, the way it does on YouTube — it must
    // not silently undo a like the user already gave.
    if (!liked) {
      await ref.read(libraryActionsProvider).toggleFavorite(item);
    }
  }

  Future<void> _openComments(MediaItem item) async {
    // The clip keeps running behind a full-screen route otherwise: this
    // screen only hears about tab changes, not pushes on top of it.
    await _player.pause();
    if (!mounted) return;
    await context.push('/comments/${item.videoId}');
    if (!mounted || !_visible) return;
    await _player.play();
  }

  Future<void> _share(MediaItem item) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'https://youtu.be/${item.videoId}',
      subject: item.title,
      // iPad anchors the sheet to a rect rather than showing it modally.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _doubleTapLike,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.shorts.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = widget.shorts[index];
              final isCurrent = index == _index;
              return _ShortPage(
                item: item,
                // Exactly one page ever mounts the video surface; the
                // rest show the poster frame they were listed with.
                surface: isCurrent
                    ? Video(
                        controller: _videoController,
                        controls: null,
                        // Shorts are vertical: fill the screen the way
                        // YouTube does rather than letterboxing.
                        fit: BoxFit.cover,
                        // media_kit_video otherwise pauses mpv the moment
                        // the app backgrounds, which this app deliberately
                        // does not want — see the watch page.
                        pauseUponEnteringBackgroundMode: false,
                      )
                    : null,
                loading: isCurrent && _resolving,
                error: isCurrent ? _resolveError : null,
                onRetry: () => _playIndex(index),
                onLike: () => _toggleLike(item),
                onDislike: () =>
                    ref.read(libraryActionsProvider).dislike(item.videoId),
                onComments: () => _openComments(item),
                onShare: () => _share(item),
              );
            },
          ),

          // Paused indicator, pinned to the screen rather than to a page
          // so it does not slide around mid-swipe.
          Positioned.fill(
            child: IgnorePointer(
              child: StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: _player.state.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return AnimatedOpacity(
                    opacity: playing || _resolving ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 84,
                        color: Colors.white70,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Double-tap-to-like burst.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showHeart ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: _showHeart ? 1 : 0.6,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: const Center(
                    child: Icon(
                      Icons.favorite,
                      size: 110,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Progress along the bottom of whatever is playing.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: _player.state.position,
                  builder: (context, snapshot) {
                    final total = _player.state.duration.inMilliseconds;
                    final position =
                        (snapshot.data ?? Duration.zero).inMilliseconds;
                    return LinearProgressIndicator(
                      value: total > 0 ? (position / total).clamp(0.0, 1.0) : 0,
                      minHeight: 2.5,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// One page: video (or poster), scrim, caption, action rail
// ============================================================

class _ShortPage extends ConsumerWidget {
  const _ShortPage({
    required this.item,
    required this.surface,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onLike,
    required this.onDislike,
    required this.onComments,
    required this.onShare,
  });

  final MediaItem item;
  final Widget? surface;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComments;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final liked = ref.watch(isFavoriteProvider(item.videoId)).valueOrNull;
    final subscribed =
        ref.watch(isSubscribedProvider(item.channelId)).valueOrNull;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster frame under everything, so a page that has not been
        // handed the player still shows the video rather than a hole.
        if (item.thumbnailUrl != null)
          Image.network(
            item.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
        if (surface != null) surface!,

        // Legibility scrim. White captions on a bright clip were
        // unreadable without it.
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
          ),
        ),

        if (loading)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ),

        if (error != null)
          Center(
            child: _ShortsMessage(
              icon: Icons.error_outline,
              message: l10n.shortsLoadFailed,
              actionLabel: l10n.retry,
              onAction: onRetry,
            ),
          ),

        // Chrome. SafeArea keeps the rail clear of the display cutout and
        // the home indicator; the shell's navigation bar already sits
        // below this screen rather than over it.
        Positioned.fill(
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: Stack(
              children: [
                // Caption. The reserve for the rail is directional, so in
                // Arabic it is carved out of the leading edge instead of
                // stranding the text under the rail.
                PositionedDirectional(
                  start: 12,
                  end: 76,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '@${item.author}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action rail on the trailing edge — `right: 8` used to
                // hang the share icon half off the screen in LTR and put
                // the whole rail on the wrong side in RTL.
                PositionedDirectional(
                  end: 4,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(
                        icon: (liked ?? false)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: l10n.like,
                        semanticLabel: l10n.like,
                        color: (liked ?? false) ? Colors.red : Colors.white,
                        onTap: onLike,
                      ),
                      _ActionButton(
                        icon: Icons.thumb_down_outlined,
                        label: l10n.shortsDislike,
                        semanticLabel: l10n.shortsDislike,
                        onTap: onDislike,
                      ),
                      _ActionButton(
                        icon: Icons.comment_outlined,
                        label: l10n.comments,
                        semanticLabel: l10n.comments,
                        onTap: onComments,
                      ),
                      _ActionButton(
                        icon: Icons.reply,
                        flipIcon: true,
                        label: l10n.share,
                        semanticLabel: l10n.share,
                        onTap: onShare,
                      ),
                      _ChannelButton(
                        item: item,
                        subscribed: subscribed ?? false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar with a subscribe badge, as at the foot of YouTube's rail:
/// the avatar opens the channel, the badge subscribes.
class _ChannelButton extends ConsumerWidget {
  const _ChannelButton({required this.item, required this.subscribed});

  final MediaItem item;
  final bool subscribed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SizedBox(
        width: 56,
        height: 60,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Semantics(
              button: true,
              label: l10n.shortsOpenChannel,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/channel/${item.channelId}'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.author.isNotEmpty ? item.author[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Semantics(
                button: true,
                label: subscribed ? l10n.subscribed : l10n.subscribe,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(libraryActionsProvider).toggleSubscription(
                          item.channelId,
                          item.author,
                        );
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: subscribed ? Colors.white : Colors.red,
                    ),
                    child: Icon(
                      subscribed ? Icons.check : Icons.add,
                      size: 16,
                      color: subscribed ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One icon + caption in the rail. Sized to a 48x48 minimum and given an
/// opaque hit test so the gaps between icon and label are tappable too.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.color = Colors.white,
    this.flipIcon = false,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;

  /// Share uses a mirrored reply arrow, as it does on the watch page.
  final bool flipIcon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: color,
      size: 30,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flipIcon)
                  Transform.flip(flipX: true, child: iconWidget)
                else
                  iconWidget,
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
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
