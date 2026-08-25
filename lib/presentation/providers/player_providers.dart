// ============================================================
// PlayerController — owns playback state for the player screen
// ============================================================

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/youtube/stream_resolver.dart';
import '../../data/local/preferences/settings_repository_impl.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_subtitle.dart';
import '../../domain/entities/sponsor_segment.dart';
import '../../domain/repositories/local_library_repository.dart';
import '../../services/audio_player_handler.dart';
import '../../services/history_sync.dart';
import '../screens/player/subtitle_styles.dart';
import '../screens/player/video_transform.dart';
import 'auth_providers.dart';
import 'content_providers.dart' show cachedMediaItem, relatedVideosProvider;
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Overridden in main() once audio_service is initialised.
final audioHandlerProvider = Provider<SmartTubeAudioHandler>(
  (ref) => throw UnimplementedError('audioHandlerProvider not initialised'),
);

/// What happens when the video reaches the end. Mirrors SmartTube's
/// "Playback mode" list, minus the playlist-only modes this app has no
/// queue for yet.
/// Display strings for both enums live in
/// presentation/l10n/enum_labels.dart so they can be translated.
enum RepeatMode { none, one, pause }

/// How the video fills the player surface — SmartTube's "Video zoom".
enum VideoFit { fit, fitWidth, fitHeight, stretch, zoom }

/// Retries short-lived network and signed-URL failures while opening a
/// video. Each attempt resolves fresh URLs instead of replaying a stale one.
Future<T> retryPlaybackOperation<T>(
  Future<T> Function() operation, {
  int maxAttempts = 2,
  Duration delay = const Duration(milliseconds: 500),
  bool Function(Object error)? shouldRetry,
}) async {
  Object? lastError;
  StackTrace? lastStack;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
      if (attempt == maxAttempts || !(shouldRetry?.call(error) ?? true)) {
        Error.throwWithStackTrace(error, stack);
      }
      await Future<void>.delayed(delay * attempt);
    }
  }
  Error.throwWithStackTrace(lastError!, lastStack!);
}

bool isRetryablePlaybackError(Object error) {
  if (error is AppException) {
    return switch (error) {
      NetworkException() || RateLimitException() || UnknownException() => true,
      NotFoundException() ||
      AuthException() ||
      ParseException() ||
      DatabaseException() ||
      YouTubeException() =>
        false,
    };
  }
  if (error is Failure) {
    return switch (error.type) {
      FailureType.network ||
      FailureType.rateLimited ||
      FailureType.unknown =>
        true,
      FailureType.notFound ||
      FailureType.unauthorized ||
      FailureType.parse ||
      FailureType.database =>
        false,
    };
  }
  if (error is TimeoutException) return true;
  final message = error.toString().toLowerCase();
  const permanent = [
    'unavailable',
    'private video',
    'members-only',
    'age-restricted',
    'copyright',
  ];
  return !permanent.any(message.contains);
}

class PlayerStateData {
  const PlayerStateData({
    this.currentItem,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isBuffering = false,
    this.playbackSpeed = 1.0,
    this.isLoading = false,
    this.error,
    this.currentVideoUrl,
    this.currentAudioUrl,
    this.currentQualityLabel,
    this.availableHeights = const [],
    this.sponsorSegments = const [],
    this.upcomingSegment,
    this.showSponsorSkipButton = false,
    this.repeatMode = RepeatMode.none,
    this.sleepTimerEnd,
    this.selectedSubtitle,
    this.isPiPActive = false,
    this.isFullscreen = false,
    this.videoFit = VideoFit.fit,
    this.seekInterval = const Duration(seconds: 10),
    this.volume = 100,
    this.queue = const [],
    this.pendingHeight,
    this.sourceClient,
    this.failedClients = const [],
    this.fallbackReason,
    this.recoveryCount = 0,
    this.networkMbps = 0,
    this.audioTracks = const [],
    this.selectedAudioTrackId,
    this.subtitleScale = 1,
    this.subtitleOffset = 24,
    this.subtitleBackgroundOpacity = 0.67,
    this.videoAspect = VideoAspect.auto,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.zoomPercent = 100,
  });

  final MediaItem? currentItem;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isBuffering;
  final double playbackSpeed;
  final bool isLoading;
  final Object? error;
  final String? currentVideoUrl;
  final String? currentAudioUrl;
  final String? currentQualityLabel;
  final List<int> availableHeights;
  final List<SponsorSegment> sponsorSegments;
  final SponsorSegment? upcomingSegment;
  final bool showSponsorSkipButton;
  final RepeatMode repeatMode;
  final DateTime? sleepTimerEnd;
  final MediaSubtitle? selectedSubtitle;
  final bool isPiPActive;
  final bool isFullscreen;
  final VideoFit videoFit;
  final Duration seekInterval;

  /// 0–300%. Above 100% mpv amplifies, which can clip loud sources.
  final double volume;

  /// Videos queued to play after this one.
  final List<MediaItem> queue;

  /// The resolution a quality switch is currently reaching for. Set the
  /// moment the user taps, so the menu and the loading label reflect the
  /// choice instead of appearing to have ignored it.
  final int? pendingHeight;
  final String? sourceClient;
  final List<String> failedClients;
  final String? fallbackReason;
  final int recoveryCount;
  final double networkMbps;
  final List<ResolvedAudioTrack> audioTracks;
  final String? selectedAudioTrackId;
  final double subtitleScale;
  final double subtitleOffset;
  final double subtitleBackgroundOpacity;

  /// Forced display ratio - SmartTube's "Video aspect". Remembered per
  /// channel alongside [videoFit].
  final VideoAspect videoAspect;

  /// 0/90/180/270. Deliberately not persisted: a sideways upload is a
  /// property of one video, not of the channel that posted it, so the
  /// angle resets on every load.
  final int rotationDegrees;

  /// Mirror the picture left-to-right. Session-only, like
  /// [rotationDegrees].
  final bool flipHorizontal;

  /// 100-300. SmartTube's "zoom percents", on top of [videoFit].
  final double zoomPercent;

  PlayerStateData copyWith({
    MediaItem? currentItem,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isBuffering,
    double? playbackSpeed,
    bool? isLoading,
    Object? error,
    String? currentVideoUrl,
    String? currentAudioUrl,
    String? currentQualityLabel,
    List<int>? availableHeights,
    List<SponsorSegment>? sponsorSegments,
    SponsorSegment? upcomingSegment,
    bool? showSponsorSkipButton,
    RepeatMode? repeatMode,
    DateTime? sleepTimerEnd,
    MediaSubtitle? selectedSubtitle,
    bool? isPiPActive,
    bool? isFullscreen,
    VideoFit? videoFit,
    Duration? seekInterval,
    double? volume,
    List<MediaItem>? queue,
    int? pendingHeight,
    String? sourceClient,
    List<String>? failedClients,
    String? fallbackReason,
    int? recoveryCount,
    double? networkMbps,
    List<ResolvedAudioTrack>? audioTracks,
    String? selectedAudioTrackId,
    double? subtitleScale,
    double? subtitleOffset,
    double? subtitleBackgroundOpacity,
    VideoAspect? videoAspect,
    int? rotationDegrees,
    bool? flipHorizontal,
    double? zoomPercent,
    bool clearError = false,
    bool clearItem = false,
    bool clearSleepTimer = false,
    bool clearSubtitle = false,
    bool clearPendingHeight = false,
    bool clearFallbackReason = false,
    bool clearDiagnostics = false,
    bool clearAudioTrack = false,
  }) {
    return PlayerStateData(
      currentItem: clearItem ? null : (currentItem ?? this.currentItem),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isBuffering: isBuffering ?? this.isBuffering,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentVideoUrl: currentVideoUrl ?? this.currentVideoUrl,
      currentAudioUrl: currentAudioUrl ?? this.currentAudioUrl,
      currentQualityLabel: currentQualityLabel ?? this.currentQualityLabel,
      availableHeights: availableHeights ?? this.availableHeights,
      sponsorSegments: sponsorSegments ?? this.sponsorSegments,
      upcomingSegment: upcomingSegment ?? this.upcomingSegment,
      showSponsorSkipButton:
          showSponsorSkipButton ?? this.showSponsorSkipButton,
      repeatMode: repeatMode ?? this.repeatMode,
      sleepTimerEnd:
          clearSleepTimer ? null : (sleepTimerEnd ?? this.sleepTimerEnd),
      selectedSubtitle:
          clearSubtitle ? null : (selectedSubtitle ?? this.selectedSubtitle),
      isPiPActive: isPiPActive ?? this.isPiPActive,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      videoFit: videoFit ?? this.videoFit,
      seekInterval: seekInterval ?? this.seekInterval,
      volume: volume ?? this.volume,
      queue: queue ?? this.queue,
      pendingHeight:
          clearPendingHeight ? null : (pendingHeight ?? this.pendingHeight),
      sourceClient:
          clearDiagnostics ? null : (sourceClient ?? this.sourceClient),
      failedClients:
          clearDiagnostics ? const [] : (failedClients ?? this.failedClients),
      fallbackReason: clearFallbackReason
          ? null
          : (clearDiagnostics ? null : (fallbackReason ?? this.fallbackReason)),
      recoveryCount:
          clearDiagnostics ? 0 : (recoveryCount ?? this.recoveryCount),
      networkMbps: clearDiagnostics ? 0 : (networkMbps ?? this.networkMbps),
      audioTracks: audioTracks ?? this.audioTracks,
      selectedAudioTrackId: clearAudioTrack
          ? null
          : (selectedAudioTrackId ?? this.selectedAudioTrackId),
      subtitleScale: subtitleScale ?? this.subtitleScale,
      subtitleOffset: subtitleOffset ?? this.subtitleOffset,
      subtitleBackgroundOpacity:
          subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
      videoAspect: videoAspect ?? this.videoAspect,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      zoomPercent: zoomPercent ?? this.zoomPercent,
    );
  }
}

class PlayerController extends StateNotifier<PlayerStateData>
    with WidgetsBindingObserver {
  PlayerController(this._ref) : super(const PlayerStateData()) {
    _player = _ref.read(mediaPlayerProvider);
    WidgetsBinding.instance.addObserver(this);
    // Resolved here, not on demand: dispose() runs while the
    // ProviderContainer is already being torn down, so a _ref.read()
    // from there throws "provider ... already disposed" and the
    // exit-time position save was silently lost.
    _libraryRepo = _ref.read(localLibraryRepositoryProvider);
    _historySync = _ref.read(historySyncProvider);

    // Surface mpv logs/errors — mpv does not write to logcat by itself,
    // so without these listeners playback failures are invisible.
    _subscriptions
      ..add(_player.stream.log.listen((event) {
        debugPrint('mpv[${event.level}] ${event.prefix}: ${event.text}');
      }))
      ..add(_player.stream.error.listen((message) {
        debugPrint('mpv ERROR: $message');
        // mpv reports plenty that is not fatal — a live stream is not
        // seekable, ffmpeg grumbles when a CDN redirect moves it to
        // another host, sockets hiccup. Turning each of those into an
        // error screen made live broadcasts look broken while they were
        // in fact about to play.
        if (_isBenignPlaybackError(message)) return;
        unawaited(_recoverPlayback('player-error: $message'));
      }))
      ..add(_player.stream.position.listen((pos) {
        state = state.copyWith(position: pos);
        _checkSponsorSegment(pos);
      }))
      ..add(_player.stream.duration.listen((dur) {
        state = state.copyWith(duration: dur);
      }))
      ..add(_player.stream.buffer.listen((buf) {
        state = state.copyWith(
          buffered: buf,
          networkMbps: _ref.read(streamProxyProvider).transferMbps,
        );
      }))
      ..add(_player.stream.buffering.listen((buffering) {
        state = state.copyWith(isBuffering: buffering);
        _bufferRecoveryTimer?.cancel();
        if (buffering && state.currentItem?.isLive != true) {
          final position = state.position;
          _bufferRecoveryTimer = Timer(const Duration(seconds: 18), () {
            if (state.isBuffering && state.position <= position) {
              unawaited(_recoverPlayback('buffer-stalled'));
            }
          });
        }
      }))
      ..add(_player.stream.playing.listen((playing) {
        // Frames are arriving, so whatever was reported earlier did not
        // stop playback.
        state = playing
            ? state.copyWith(isPlaying: true, clearError: true)
            : state.copyWith(isPlaying: false);
        if (playing) unawaited(_claimAudioSession());
      }))
      ..add(_player.stream.completed.listen(_onCompleted));
  }

  final Ref _ref;
  late final Player _player;
  late final LocalLibraryRepository _libraryRepo;
  late final HistorySync _historySync;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Whether the video track was dropped because the app went to the
  /// background, so it is only restored if we were the ones who took it.
  bool _videoSuspended = false;

  Timer? _savePositionTimer;
  Timer? _sleepTimer;
  Timer? _bufferRecoveryTimer;
  bool _recoveringPlayback = false;

  /// Guards against a second quality switch starting while the first is
  /// still resolving — two concurrent `Player.open` calls race.
  bool _switchingQuality = false;

  /// mpv messages that do not mean playback failed.
  static const _benignErrors = [
    'cannot seek in this stream',
    'force-seekable',
    'cannot reuse http connection',
    'failed to create file cache',
    // No audio output is a degraded playback, not a failed one — the
    // video keeps decoding. Treating it as fatal replaced the whole
    // player with an error screen. libmpv's simulator slices are built
    // with every audio output disabled (`-Daudiounit=disabled`), so on
    // the simulator this fires on every single video.
    'could not open/initialize audio device',
    'ffurl_read returned',
    'invalid nal unit size',
    'missing picture in access unit',
  ];

  static bool _isBenignPlaybackError(String message) {
    final lower = message.toLowerCase();
    return _benignErrors.any(lower.contains);
  }

  /// Client playback nonce for the current video. YouTube ties the
  /// positions reported during one playback session to it.
  String? _cpn;

  Player get player => _player;

  Future<void> _onCompleted(bool completed) async {
    if (!completed) return;
    switch (state.repeatMode) {
      case RepeatMode.one:
        await _player.seek(Duration.zero);
        await _player.play();
      case RepeatMode.none:
        await _saveCurrentPosition();
        // Continue with whatever the user queued up, then with YouTube's
        // own "Up next" when the queue is empty and autoplay is on.
        if (await playNextInQueue()) return;
        await _playRelatedIfEnabled();
      case RepeatMode.pause:
        await _saveCurrentPosition();
    }
  }

  /// Plays a previously downloaded copy straight from disk. Falls back to
  /// streaming when the files are gone.
  Future<bool> loadOffline(String videoId) async {
    final db = _ref.read(appDatabaseProvider);
    final row = await db.getDownload(videoId);
    if (row == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _player.open(Media('file://${row.videoPath}'));
      if (row.audioPath != null) {
        await _player.setAudioTrack(AudioTrack.uri('file://${row.audioPath}'));
      }
      state = state.copyWith(
        isLoading: false,
        currentItem: MediaItem(
          videoId: row.videoId,
          title: row.title,
          author: row.author,
          channelId: row.channelId,
          thumbnailUrl: row.thumbnailUrl,
          duration: Duration(milliseconds: row.durationMs),
          publishedAt: row.downloadedAt,
          formats: const [],
          subtitles: const [],
          chapters: const [],
        ),
        currentQualityLabel: row.qualityLabel,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Loads a video: metadata, streams, then hands the URLs to mpv through
  /// the local proxy.
  Future<void> loadVideo(String videoId) async {
    // Re-opening the player for the video already loaded — coming back
    // from the mini player — must not tear down a running stream and
    // re-fetch metadata for it. mpv is already sitting on the right
    // position. A failed load is still retried: the retry button and
    // the error path both leave `error` set.
    if (state.currentItem?.videoId == videoId &&
        state.currentVideoUrl != null &&
        state.error == null) {
      return;
    }

    // Draw the page from what the tapped card already knew — title,
    // thumbnail, channel, duration — so only the video is waited on
    // rather than the whole screen. Replaced by the full item below.
    final seed = cachedMediaItem(videoId);
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearDiagnostics: true,
      currentItem: seed ?? state.currentItem,
    );
    _cpn = HistorySync.newCpn();
    // Caps are recorded per video; a new one starts with a clean slate.
    _cappedHeights.clear();

    try {
      final sw = Stopwatch()..start();
      debugPrint('loadVideo[$videoId]: fetching metadata...');
      final repo = _ref.read(mediaItemRepositoryProvider);
      final item = await retryPlaybackOperation(
        () async {
          final result = await repo
              .getMediaItem(videoId)
              .timeout(const Duration(seconds: 25));
          return result.when(
            success: (item) => item,
            failure: (message, type, cause) =>
                throw Failure(message, type: type, cause: cause),
          );
        },
        shouldRetry: isRetryablePlaybackError,
      );

      // Carry the cause, not a sentence about it. Stringifying here left
      // the watch page with nothing to classify, so every failure —
      // offline, rate limited, video pulled — surfaced as the same
      // "something went wrong".
      debugPrint('loadVideo: metadata done in ${sw.elapsedMilliseconds}ms');

      final channelPreferences = _ref
          .read(settingsRepositoryProvider)
          .channelPlaybackPreferences(item.channelId);
      final rememberedFit = VideoFit.values.firstWhere(
        (fit) => fit.name == channelPreferences?.videoFit,
        orElse: () => state.videoFit,
      );
      final rememberedSpeed = channelPreferences?.speed ??
          _ref.read(settingsControllerProvider).defaultSpeed;
      state = state.copyWith(
        currentItem: item,
        playbackSpeed: rememberedSpeed,
        videoFit: rememberedFit,
        subtitleScale: channelPreferences?.subtitleScale ?? 1,
        subtitleOffset: channelPreferences?.subtitleOffset ?? 24,
        subtitleBackgroundOpacity:
            channelPreferences?.subtitleBackgroundOpacity ?? 0.67,
        videoAspect: videoAspectFromName(channelPreferences?.videoAspect),
        zoomPercent:
            normalizeZoomPercent(channelPreferences?.zoomPercent ?? 100),
        // Rotation and flip are per-video, so a previous fix for a
        // sideways clip does not follow the viewer into the next one.
        rotationDegrees: 0,
        flipHorizontal: false,
      );

      // A live broadcast is a rolling HLS playlist, not a file that can
      // be walked by byte range, so it takes a different path entirely.
      if (item.isLive) {
        final opened = await _openLiveStream(videoId);
        if (!opened) {
          throw Exception('live-unavailable');
        }
        state = state.copyWith(
          currentItem: item,
          isLoading: false,
          clearError: true,
          currentQualityLabel: 'LIVE',
          availableHeights: const [],
          sponsorSegments: const [],
        );
        await _ref.read(audioHandlerProvider).setMediaItem(item);
        return;
      }

      final resolved = await retryPlaybackOperation(
        () => _openStreams(
          videoId,
          exactHeight: channelPreferences?.qualityHeight ?? _autoHeight(),
          audioTrackId: channelPreferences?.audioTrackId,
        ),
        shouldRetry: isRetryablePlaybackError,
      );

      state = state.copyWith(
        currentItem: item,
        isLoading: false,
        clearError: true,
        currentVideoUrl: resolved.videoUrl,
        currentAudioUrl: resolved.audioUrl,
        currentQualityLabel: resolved.qualityLabel,
        availableHeights: resolved.availableHeights,
        sponsorSegments: item.sponsorSegments,
        sourceClient: resolved.sourceClient,
        failedClients: resolved.failedClients,
        fallbackReason:
            resolved.failedClients.isEmpty ? null : 'client-fallback',
        audioTracks: resolved.audioTracks,
        selectedAudioTrackId: resolved.selectedAudioTrackId,
      );

      final subtitleCode = channelPreferences?.subtitleCode;
      if (subtitleCode != null) {
        final subtitle = item.subtitles
            .where((candidate) => candidate.code == subtitleCode)
            .firstOrNull;
        if (subtitle != null) await selectSubtitle(subtitle);
      } else if (channelPreferences?.subtitlesDisabled != true) {
        // Nothing remembered for this channel, and captions were not
        // deliberately switched off for it: fall back to the viewer's
        // default caption language. Not remembered afterwards - that
        // would turn a global default into a per-channel decision the
        // viewer never made.
        final preferred = pickPreferredSubtitle(
          item.subtitles,
          _preferredSubtitleLanguage(),
        );
        if (preferred != null) {
          await selectSubtitle(preferred, remember: false);
        }
      }

      // Publish metadata so the notification / lock screen shows the
      // video and playback survives going to the background.
      await _ref.read(audioHandlerProvider).setMediaItem(item);

      // Restore where the user left off — on this device or on any
      // other one signed into the same account.
      final libraryRepo = _ref.read(localLibraryRepositoryProvider);
      final posResult = await libraryRepo.getPlayPosition(videoId);
      final saved = posResult.dataOrNull;
      if (saved != null && saved > Duration.zero) {
        await _player.seek(saved);
      }

      _savePositionTimer?.cancel();
      _savePositionTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _saveCurrentPosition(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Opens a live broadcast. Returns false when YouTube offers no
  /// playlist for it (ended, or members-only).
  ///
  /// The HLS URL goes to mpv as-is rather than through the loopback
  /// relay: the relay walks a fixed-size file by byte range, which a
  /// rolling playlist has no equivalent of, and ffmpeg handles the
  /// playlist and its segments itself.
  Future<bool> _openLiveStream(String videoId) async {
    final url =
        await _ref.read(authenticatedClientProvider).getLiveStreamUrl(videoId);
    if (url == null) return false;
    debugPrint('openLive[$videoId]: opening HLS playlist');
    await _player.open(Media(url));
    await _player.setRate(1);
    return true;
  }

  /// Resolves the streams for [videoId] and hands them to mpv. Shared by
  /// first play and by quality switching, which must not pay for the
  /// metadata round-trip a second time.
  Future<ResolvedStream> _openStreams(
    String videoId, {
    int? exactHeight,
    String? audioTrackId,
  }) async {
    final sw = Stopwatch()..start();
    // Probe candidates so we never hand mpv a URL googlevideo will 403.
    final proxy = _ref.read(streamProxyProvider);
    await proxy.start();
    // Some videos are served for only the first few MiB whatever client
    // asked for them. mpv just stalls when that happens, so turn it into
    // something the user can read.
    proxy.onUpstreamRefused = (served, total) {
      if (served >= total) return;
      // A cap is quality-specific, not video-specific: probing the video
      // that raised this (tool/client_probe.dart) showed googlevideo
      // serving 720p in full while refusing 1080p a few MiB in. So drop
      // a rung and keep playing rather than stopping on an error screen
      // — dying at the top quality when a lower one would have played
      // is the worst of the options.
      if (_stepDownAfterCap()) return;
      state = state.copyWith(
        error: 'stream-capped',
        isLoading: false,
        clearPendingHeight: true,
      );
    };
    final settings = _ref.read(settingsControllerProvider);
    final streamResolver = _ref.read(streamResolverProvider);
    final resolved = await streamResolver
        .getBestStream(
          videoId,
          quality: settings.defaultQuality,
          probe: proxy.probe,
          exactHeight: exactHeight,
          audioTrackId: audioTrackId,
        )
        .timeout(const Duration(seconds: 60));
    debugPrint('openStreams: resolved in ${sw.elapsedMilliseconds}ms '
        '(${resolved.qualityLabel}, audio: ${resolved.audioUrl != null})');
    if (resolved.availableHeights.isNotEmpty) {
      _lastAvailableHeights = resolved.availableHeights;
    }

    // Relay through the loopback proxy: mpv's bundled TLS cannot reach
    // googlevideo reliably, Dart's HTTP stack can.
    final localVideoUrl = proxy.register(Uri.parse(resolved.videoUrl));
    String? localAudioUrl;
    if (resolved.audioUrl != null && resolved.audioUrl!.isNotEmpty) {
      final audioStatus = await proxy.probe(Uri.parse(resolved.audioUrl!));
      if (audioStatus >= 200 && audioStatus < 300) {
        localAudioUrl = proxy.register(Uri.parse(resolved.audioUrl!));
      } else {
        debugPrint('openStreams: audio URL refused ($audioStatus), '
            'continuing without external audio');
      }
    }

    // Retire the routes of whatever was playing before: the previous
    // relay would otherwise keep downloading and compete for bandwidth
    // with the stream that replaced it.
    proxy.retainOnly([localVideoUrl, if (localAudioUrl != null) localAudioUrl]);

    await _player.open(Media(localVideoUrl));
    await _player.setRate(state.playbackSpeed);
    if (localAudioUrl != null) {
      await _player.setAudioTrack(AudioTrack.uri(localAudioUrl));
    }
    return resolved;
  }

  /// Refreshes expired URLs and progressively lowers quality without
  /// losing the playhead. SmartTube treats a transport failure as a
  /// recovery event; the user sees an error only after every viable rung
  /// has been attempted.
  Future<void> _recoverPlayback(String reason) async {
    final item = state.currentItem;
    if (_recoveringPlayback || item == null || item.isLive) {
      if (item?.isLive == true) {
        state = state.copyWith(error: reason, isLoading: false);
      }
      return;
    }
    _recoveringPlayback = true;
    _bufferRecoveryTimer?.cancel();
    final resumeFrom = state.position;
    final wasPlaying = state.isPlaying;
    final currentHeight = _currentHeight();
    final candidates = <int?>[
      currentHeight,
      ...state.availableHeights.where(
        (height) => currentHeight == null || height < currentHeight,
      ),
    ];
    Object? lastError;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      fallbackReason: reason,
      recoveryCount: state.recoveryCount + 1,
    );
    try {
      for (final height in candidates) {
        try {
          final resolved = await _openStreams(
            item.videoId,
            exactHeight: height,
            audioTrackId: state.selectedAudioTrackId,
          );
          if (resumeFrom > Duration.zero) await _player.seek(resumeFrom);
          if (wasPlaying) await _player.play();
          state = state.copyWith(
            isLoading: false,
            clearError: true,
            currentVideoUrl: resolved.videoUrl,
            currentAudioUrl: resolved.audioUrl,
            currentQualityLabel: resolved.qualityLabel,
            availableHeights: resolved.availableHeights,
            sourceClient: resolved.sourceClient,
            failedClients: resolved.failedClients,
            audioTracks: resolved.audioTracks,
            selectedAudioTrackId: resolved.selectedAudioTrackId,
          );
          return;
        } catch (error) {
          lastError = error;
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: lastError ?? reason,
      );
    } finally {
      _recoveringPlayback = false;
    }
  }

  /// Re-opens the current video at a different resolution, keeping the
  /// playback position, speed and play/pause state. Metadata is reused —
  /// only the stream URLs change — so this is a couple of seconds rather
  /// than a full reload.
  /// Heights already refused for the video being played, so a downgrade
  /// never walks back into one.
  final Set<int> _cappedHeights = {};

  /// Re-opens one quality rung down after googlevideo cut a stream off.
  /// Returns false when there is nothing lower left to fall back to.
  bool _stepDownAfterCap() {
    if (_switchingQuality || _recoveringPlayback) {
      return true; // a downgrade/recovery is already running
    }
    final heights = state.availableHeights;
    if (heights.isEmpty) return false;

    final current = _currentHeight();
    if (current != null) _cappedHeights.add(current);

    final next = heights
        .where((h) =>
            (current == null || h < current) && !_cappedHeights.contains(h))
        .firstOrNull;
    if (next == null) return false;

    debugPrint(
        'stream capped at ${current ?? "?"}p, stepping down to ${next}p');
    unawaited(switchQuality(next));
    return true;
  }

  /// The resolution currently playing, read back from its label.
  int? _currentHeight() {
    final label = state.currentQualityLabel;
    if (label == null) return null;
    return int.tryParse(RegExp(r'(\d+)').firstMatch(label)?.group(1) ?? '');
  }

  /// Hands resolution back to the throughput heuristic. Re-opens at the
  /// rung it would pick now when that differs from what is playing.
  Future<void> selectAutoQuality() async {
    await _ref.read(settingsControllerProvider.notifier).setAutoQuality(true);
    unawaited(_rememberChannel(clearQualityHeight: true));
    final target = _autoHeight();
    if (target != null && target != _currentHeight()) {
      await switchQuality(target, manual: false);
    }
  }

  Future<void> switchQuality(int height, {bool manual = true}) async {
    final item = state.currentItem;
    if (item == null || _switchingQuality) return;
    _switchingQuality = true;
    if (manual) {
      // An explicit pick is a statement: stop second-guessing it.
      unawaited(
        _ref.read(settingsControllerProvider.notifier).setAutoQuality(false),
      );
    }

    final resumeFrom = state.position;
    final wasPlaying = state.isPlaying;
    // Reflect the choice immediately: the resolve + probe round-trips can
    // take seconds, and without this the menu looks like it did nothing.
    state = state.copyWith(
      pendingHeight: height,
      isLoading: true,
      clearError: true,
    );

    try {
      final resolved = await _openStreams(
        item.videoId,
        exactHeight: height,
        audioTrackId: state.selectedAudioTrackId,
      );
      if (resumeFrom > Duration.zero) await _player.seek(resumeFrom);
      if (wasPlaying) {
        await _player.play();
      } else {
        await _player.pause();
      }
      state = state.copyWith(
        isLoading: false,
        currentVideoUrl: resolved.videoUrl,
        currentAudioUrl: resolved.audioUrl,
        currentQualityLabel: resolved.qualityLabel,
        availableHeights: resolved.availableHeights,
        sourceClient: resolved.sourceClient,
        failedClients: resolved.failedClients,
        audioTracks: resolved.audioTracks,
        selectedAudioTrackId: resolved.selectedAudioTrackId,
        fallbackReason: resolved.failedClients.isEmpty
            ? state.fallbackReason
            : 'client-fallback',
        clearPendingHeight: true,
      );
      unawaited(_rememberChannel(qualityHeight: resolved.videoHeight));
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        clearPendingHeight: true,
      );
    } finally {
      _switchingQuality = false;
    }
  }

  Future<void> _saveCurrentPosition() async {
    // Everything this needs is read up front. dispose() starts this
    // without awaiting it, so by the time the first write returns the
    // notifier is already disposed and touching `state` again throws
    // "Tried to use PlayerController after dispose was called" — which
    // aborted the save half-done, before the account ever heard about it.
    final item = state.currentItem;
    final position = state.position;
    final duration = state.duration;

    // A live broadcast has no position worth remembering — "where you
    // left off" is always "now".
    if (item == null || item.isLive) return;
    await _libraryRepo.savePlayPosition(item.videoId, position);
    await _libraryRepo.addToHistory(item, position: position);

    // Report to the account too, so the same video resumes here on the
    // phone, on the web and in the official apps.
    final cpn = _cpn;
    if (cpn != null) {
      await _historySync.push(
        videoId: item.videoId,
        position: position,
        duration: duration,
        cpn: cpn,
      );
    }
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seek(Duration position) {
    _player.seek(position);
    state = state.copyWith(position: position);
  }

  void seekForward([Duration? delta]) {
    final newPos = state.position + (delta ?? state.seekInterval);
    seek(newPos > state.duration ? state.duration : newPos);
  }

  void seekBackward([Duration? delta]) {
    final newPos = state.position - (delta ?? state.seekInterval);
    seek(newPos.isNegative ? Duration.zero : newPos);
  }

  void setVideoFit(VideoFit fit) {
    state = state.copyWith(videoFit: fit);
    unawaited(_rememberChannel(videoFit: fit.name));
  }

  /// Forces a display aspect ratio - SmartTube's "Video aspect".
  void setVideoAspect(VideoAspect aspect) {
    state = state.copyWith(videoAspect: aspect);
    unawaited(_rememberChannel(videoAspect: aspect.name));
  }

  /// Zoom on top of the fit preset, 100-300%.
  void setZoomPercent(double percent) {
    final clamped = normalizeZoomPercent(percent);
    state = state.copyWith(zoomPercent: clamped);
    unawaited(_rememberChannel(zoomPercent: clamped));
  }

  /// Rotates the picture by 0/90/180/270 degrees, for this video only.
  void setRotation(int degrees) {
    state = state.copyWith(rotationDegrees: normalizeRotation(degrees));
  }

  /// Mirrors the picture left-to-right, for this video only.
  void setFlipHorizontal(bool flipped) {
    state = state.copyWith(flipHorizontal: flipped);
  }

  /// Volume as a percentage. SmartTube allows boosting past 100%, which
  /// mpv supports natively (with clipping risk, hence the warning in the
  /// menu).
  Future<void> setVolume(double percent) async {
    final clamped = percent.clamp(0.0, 300.0);
    await _player.setVolume(clamped);
    state = state.copyWith(volume: clamped);
  }

  /// Queue management — "play next"/"add to queue" from a video's menu.
  void enqueue(MediaItem item) {
    if (state.queue.any((q) => q.videoId == item.videoId)) return;
    _setQueue([...state.queue, item]);
  }

  void playNext(MediaItem item) {
    final rest = state.queue.where((q) => q.videoId != item.videoId).toList();
    _setQueue([item, ...rest]);
  }

  void removeFromQueue(String videoId) {
    _setQueue(state.queue.where((q) => q.videoId != videoId).toList());
  }

  void clearQueue() => _setQueue(const []);

  /// Every queue change goes through here so the notification's "next"
  /// button appears and disappears with it.
  void _setQueue(List<MediaItem> queue) {
    state = state.copyWith(queue: queue);
    _syncSkipControls();
  }

  void _syncSkipControls() {
    final handler = _ref.read(audioHandlerProvider);
    handler.onSkipNext = state.queue.isEmpty ? null : playNextInQueue;
    handler.refreshControls();
  }

  /// Starts the next queued video, removing it from the queue.
  Future<bool> playNextInQueue() async {
    if (state.queue.isEmpty) return false;
    final next = state.queue.first;
    _setQueue(state.queue.skip(1).toList());
    await loadVideo(next.videoId);
    return true;
  }

  /// Autoplay: continues with the first related video that is not the
  /// one just finished. Silent when the setting is off, the video was
  /// live, or the related list failed to load.
  Future<void> _playRelatedIfEnabled() async {
    final item = state.currentItem;
    if (item == null || item.isLive) return;
    if (!_ref.read(settingsControllerProvider).autoplayNext) return;
    try {
      final related =
          await _ref.read(relatedVideosProvider(item.videoId).future);
      final next = related
          .where((v) => v.videoId != item.videoId && !v.isLive)
          .firstOrNull;
      if (next == null) return;
      debugPrint('autoplay: continuing with ${next.videoId}');
      await loadVideo(next.videoId);
    } catch (e) {
      debugPrint('autoplay: related list unavailable: $e');
    }
  }

  /// Rungs used by auto quality. Anything below the floor plays 360p;
  /// the ladder is deliberately conservative because the loopback relay
  /// adds overhead a direct connection would not.
  static const _autoQualityLadder = <(double, int)>[
    (25, 2160),
    (12, 1440),
    (6, 1080),
    (3, 720),
    (1.5, 480),
  ];

  static int? autoHeightForMbps(double mbps, List<int> available) {
    if (mbps <= 0 || available.isEmpty) return null;
    var target = 360;
    for (final (minMbps, height) in _autoQualityLadder) {
      if (mbps >= minMbps) {
        target = height;
        break;
      }
    }
    // Highest offered rung that does not exceed the target.
    final sorted = [...available]..sort((a, b) => b.compareTo(a));
    return sorted.where((h) => h <= target).firstOrNull ?? sorted.last;
  }

  /// Auto quality only has something to go on once bytes have flowed, so
  /// the first video of a session opens at the fixed preference and the
  /// next ones use what the relay measured.
  int? _autoHeight() {
    if (!_ref.read(settingsControllerProvider).autoQuality) return null;
    final mbps = _ref.read(streamProxyProvider).transferMbps;
    return autoHeightForMbps(mbps, _lastAvailableHeights);
  }

  /// Heights offered by the previous resolve, kept across videos as the
  /// best available guess for what the next one will offer.
  List<int> _lastAvailableHeights = const [];

  void setSeekInterval(Duration interval) {
    state = state.copyWith(seekInterval: interval);
  }

  void setSpeed(double speed) {
    _player.setRate(speed);
    state = state.copyWith(playbackSpeed: speed);
    unawaited(_rememberChannel(speed: speed));
  }

  void setRepeatMode(RepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
  }

  void setFullscreen(bool value) {
    state = state.copyWith(isFullscreen: value);
  }

  void setPiPActive(bool value) {
    state = state.copyWith(isPiPActive: value);
  }

  /// Selects an external subtitle track, or clears it when [subtitle] is
  /// null. Tracks come from the video's caption list.
  Future<void> selectSubtitle(
    MediaSubtitle? subtitle, {
    bool remember = true,
  }) async {
    if (subtitle == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      state = state.copyWith(clearSubtitle: true);
      if (remember) await _rememberChannel(clearSubtitle: true);
      return;
    }
    // Route captions through the proxy too: the same TLS limitation
    // applies to timedtext URLs.
    final proxy = _ref.read(streamProxyProvider);
    await proxy.start();
    final local = proxy.register(Uri.parse(subtitle.url));
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(local, title: subtitle.name, language: subtitle.code),
    );
    state = state.copyWith(selectedSubtitle: subtitle);
    if (remember) await _rememberChannel(subtitleCode: subtitle.code);
  }

  /// The caption language to switch on by default, or null when the
  /// viewer has turned automatic selection off.
  String? _preferredSubtitleLanguage() {
    final settings = _ref.read(settingsControllerProvider);
    return resolvePreferredSubtitleLanguage(
      settings.preferredSubtitleLanguage,
      appLanguage: settings.language,
      deviceLanguage:
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
  }

  Future<void> selectAudioTrack(ResolvedAudioTrack track) async {
    final item = state.currentItem;
    if (item == null || _switchingQuality) return;
    _switchingQuality = true;
    final resumeFrom = state.position;
    final wasPlaying = state.isPlaying;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resolved = await _openStreams(
        item.videoId,
        exactHeight: _currentHeight(),
        audioTrackId: track.id,
      );
      if (resumeFrom > Duration.zero) await _player.seek(resumeFrom);
      if (wasPlaying) await _player.play();
      state = state.copyWith(
        isLoading: false,
        currentVideoUrl: resolved.videoUrl,
        currentAudioUrl: resolved.audioUrl,
        currentQualityLabel: resolved.qualityLabel,
        availableHeights: resolved.availableHeights,
        audioTracks: resolved.audioTracks,
        selectedAudioTrackId: resolved.selectedAudioTrackId,
        sourceClient: resolved.sourceClient,
        failedClients: resolved.failedClients,
      );
      await _rememberChannel(audioTrackId: track.id);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    } finally {
      _switchingQuality = false;
    }
  }

  void setSubtitleStyle({
    double? scale,
    double? offset,
    double? backgroundOpacity,
  }) {
    state = state.copyWith(
      subtitleScale: scale,
      subtitleOffset: offset,
      subtitleBackgroundOpacity: backgroundOpacity,
    );
    unawaited(
      _rememberChannel(
        subtitleScale: scale,
        subtitleOffset: offset,
        subtitleBackgroundOpacity: backgroundOpacity,
      ),
    );
  }

  Future<void> _rememberChannel({
    double? speed,
    int? qualityHeight,
    String? subtitleCode,
    String? audioTrackId,
    double? subtitleScale,
    double? subtitleOffset,
    double? subtitleBackgroundOpacity,
    String? videoFit,
    String? videoAspect,
    double? zoomPercent,
    bool clearSubtitle = false,
    bool clearQualityHeight = false,
  }) async {
    final channelId = state.currentItem?.channelId;
    if (channelId == null || channelId.isEmpty) return;
    final repository = _ref.read(settingsRepositoryProvider);
    final current = repository.channelPlaybackPreferences(channelId) ??
        const ChannelPlaybackPreferences();
    await repository.saveChannelPlaybackPreferences(
      channelId,
      current.copyWith(
        speed: speed,
        qualityHeight: qualityHeight,
        subtitleCode: subtitleCode,
        audioTrackId: audioTrackId,
        subtitleScale: subtitleScale,
        subtitleOffset: subtitleOffset,
        subtitleBackgroundOpacity: subtitleBackgroundOpacity,
        videoFit: videoFit,
        videoAspect: videoAspect,
        zoomPercent: zoomPercent,
        clearSubtitle: clearSubtitle,
        clearQualityHeight: clearQualityHeight,
      ),
    );
  }

  /// Pauses playback after [duration]. Pass null to cancel.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }
    _sleepTimer = Timer(duration, () {
      _player.pause();
      state = state.copyWith(clearSleepTimer: true);
    });
    state = state.copyWith(sleepTimerEnd: DateTime.now().add(duration));
  }

  void _checkSponsorSegment(Duration position) {
    final settings = _ref.read(settingsControllerProvider);
    if (state.sponsorSegments.isEmpty || !settings.sponsorBlockEnabled) {
      if (state.showSponsorSkipButton) {
        state = state.copyWith(showSponsorSkipButton: false);
      }
      return;
    }

    SponsorSegment? active;
    for (final segment in state.sponsorSegments) {
      if (segment.isActiveAt(position)) {
        active = segment;
        break;
      }
    }

    if (active != null) {
      if (settings.autoSkipSponsors) {
        seek(active.end);
      } else {
        state = state.copyWith(
          upcomingSegment: active,
          showSponsorSkipButton: true,
        );
      }
    } else if (state.showSponsorSkipButton) {
      state = state.copyWith(showSponsorSkipButton: false);
    }
  }

  void skipSponsorSegment() {
    final segment = state.upcomingSegment;
    if (segment == null) return;
    seek(segment.end);
    state = state.copyWith(showSponsorSkipButton: false);
  }

  /// Stops playback and persists progress.
  Future<void> stop() async {
    await _saveCurrentPosition();
    await _player.stop();
    state = const PlayerStateData();
  }

  /// iOS suspends the whole process on background unless it holds an
  /// *active* `playback` session. Configuring the category is only half
  /// of it — without `setActive(true)` the system does not count us as
  /// playing, which is why playback stopped dead on background and came
  /// back paused rather than continuing.
  ///
  /// Re-asserted on every play instead of once at startup because mpv
  /// opens its own audio unit when playback begins and can leave the
  /// category somewhere else.
  Future<void> _claimAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // setActive returns false when the system refuses the session,
      // which is otherwise silent and indistinguishable from success.
      if (!await session.setActive(true)) {
        debugPrint('audiosession: system refused to activate');
      }
    } catch (e) {
      debugPrint('audio session claim failed: $e');
    }
  }

  /// iOS reclaims the VideoToolbox decode session the moment the app
  /// leaves the foreground. mpv does not find out — it keeps feeding the
  /// dead session and every frame fails with
  /// `kVTInvalidSessionErr (-12903)`, which is what audio-only playback
  /// in the background actually looked like on the device.
  ///
  /// Dropping the video track on the way out is also what we want
  /// regardless: nobody is watching, and decoding costs battery. Audio
  /// keeps the clock running, so the position never stalls.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (state.currentItem == null) return;
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // PiP keeps the surface on screen, so nothing is suspended.
        if (state.isPiPActive) return;
        if (!_ref.read(settingsControllerProvider).backgroundPlayback) {
          // Same as the official app with background play off: stop at
          // the door, resume where it left off when the user comes back.
          if (state.isPlaying) unawaited(_player.pause());
          return;
        }
        if (_videoSuspended) return;
        _videoSuspended = true;
        unawaited(_player.setVideoTrack(VideoTrack.no()));
      case AppLifecycleState.resumed:
        if (!_videoSuspended) return;
        _videoSuspended = false;
        unawaited(_player.setVideoTrack(VideoTrack.auto()));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savePositionTimer?.cancel();
    _sleepTimer?.cancel();
    _bufferRecoveryTimer?.cancel();
    _saveCurrentPosition();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// Kept alive across screens so audio continues in the background; the
/// player screen stops it explicitly when the user leaves.
final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerStateData>(
  PlayerController.new,
);
