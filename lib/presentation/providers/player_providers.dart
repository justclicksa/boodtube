// ============================================================
// PlayerController — owns playback state for the player screen
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/youtube/mpd_builder.dart';
import '../../data/youtube/stream_resolver.dart';
import '../../data/local/preferences/settings_repository_impl.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/content_filter.dart';
import '../../core/network/stream_proxy.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_subtitle.dart';
import '../../domain/entities/sponsor_segment.dart';
import '../../domain/repositories/local_library_repository.dart';
import '../../services/audio_player_handler.dart';
import '../../services/history_sync.dart';
import '../../services/player_tuning.dart';
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
/// "Playback mode" list (VideoLoaderController's PLAYBACK_MODE_*).
///
/// * [none] — play the queue through, then YouTube's "Up next".
/// * [one] — repeat the video that just finished.
/// * [all] — loop the queue: the finished video goes back on the end.
/// * [shuffle] — like [all], but the next video is drawn at random.
/// * [pause] — stop at the end of every video.
///
/// Display strings for both enums live in
/// presentation/l10n/enum_labels.dart so they can be translated.
enum RepeatMode { none, one, all, shuffle, pause }

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

/// The segment under [position] that playback should act on, together
/// with the action configured for its category — or null when there is
/// nothing to do there.
///
/// Pure so the resolution can be tested without a running player.
/// Segments that cannot be skipped (a highlight is a single instant,
/// exclusive access covers the whole video), categories set to
/// [SegmentAction.none], and segments the user undid a skip on
/// ([doNotSkip]) are all passed over.
({SponsorSegment segment, SegmentAction action})? resolveSponsorSegmentAt({
  required List<SponsorSegment> segments,
  required Duration position,
  required SegmentAction Function(SponsorCategory) actionFor,
  Set<String> doNotSkip = const {},
}) {
  for (final segment in segments) {
    if (!segment.category.isSkippable) continue;
    if (!segment.isActiveAt(position)) continue;
    if (doNotSkip.contains(segment.key)) continue;
    final action = actionFor(segment.category);
    if (action == SegmentAction.none) continue;
    return (segment: segment, action: action);
  }
  return null;
}

/// A segment that was just skipped, offered back to the user.
///
/// [id] separates two notices for the same segment (a re-watch after an
/// undo), so the toast restarts its timer instead of being treated as
/// the one already on screen.
class SponsorSkipNotice {
  const SponsorSkipNotice({required this.segment, required this.id});

  final SponsorSegment segment;
  final int id;
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
    this.sponsorNotice,
    this.doNotSkipSegments = const {},
    this.showPaidPromotionNotice = false,
    this.repeatMode = RepeatMode.none,
    this.sleepTimerEnd,
    this.selectedSubtitle,
    this.isPiPActive = false,
    this.isFullscreen = false,
    this.videoFit = VideoFit.fit,
    this.seekInterval = const Duration(seconds: 10),
    this.volume = 100,
    this.queue = const [],
    this.upNext,
    this.upNextCountdown,
    this.showReplay = false,
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
    this.audioDelayMs = 0,
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

  /// The transient "Skipped sponsor · Undo" toast, or null.
  final SponsorSkipNotice? sponsorNotice;

  /// Segments the user undid a skip on. Held for this video only —
  /// SmartTube's "don't skip this segment again".
  final Set<String> doNotSkipSegments;

  /// The video is a paid placement end to end (`exclusive_access`).
  final bool showPaidPromotionNotice;

  /// The single point the video is about, when one was submitted.
  SponsorSegment? get highlightSegment {
    for (final segment in sponsorSegments) {
      if (segment.category == SponsorCategory.highlight) return segment;
    }
    return null;
  }
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

  /// The video autoplay is about to continue with, while the "Up next"
  /// card counts down. Null whenever no such offer is on screen.
  final MediaItem? upNext;

  /// Seconds left before [upNext] loads. Null when no countdown is
  /// running; zero for the tick that fires it.
  final int? upNextCountdown;

  /// Playback finished and nothing followed it — either autoplay is off,
  /// nothing eligible was suggested, or the user cancelled the countdown.
  /// The surface answers with a replay button.
  final bool showReplay;

  /// Whether the "Up next" card should be on screen.
  bool get isUpNextPending => upNext != null && (upNextCountdown ?? 0) > 0;

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

  /// SmartTube's audio shift: negative pulls the audio ahead of the
  /// picture, positive pushes it back. Remembered per channel.
  final int audioDelayMs;
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
    SponsorSkipNotice? sponsorNotice,
    Set<String>? doNotSkipSegments,
    bool? showPaidPromotionNotice,
    RepeatMode? repeatMode,
    DateTime? sleepTimerEnd,
    MediaSubtitle? selectedSubtitle,
    bool? isPiPActive,
    bool? isFullscreen,
    VideoFit? videoFit,
    Duration? seekInterval,
    double? volume,
    List<MediaItem>? queue,
    MediaItem? upNext,
    int? upNextCountdown,
    bool? showReplay,
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
    int? audioDelayMs,
    VideoAspect? videoAspect,
    int? rotationDegrees,
    bool? flipHorizontal,
    double? zoomPercent,
    bool clearError = false,
    bool clearItem = false,
    bool clearSleepTimer = false,
    bool clearSubtitle = false,
    bool clearPendingHeight = false,
    bool clearUpNext = false,
    bool clearFallbackReason = false,
    bool clearDiagnostics = false,
    bool clearAudioTrack = false,
    bool clearSponsorNotice = false,
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
      sponsorNotice:
          clearSponsorNotice ? null : (sponsorNotice ?? this.sponsorNotice),
      doNotSkipSegments: doNotSkipSegments ?? this.doNotSkipSegments,
      showPaidPromotionNotice:
          showPaidPromotionNotice ?? this.showPaidPromotionNotice,
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
      upNext: clearUpNext ? null : (upNext ?? this.upNext),
      upNextCountdown:
          clearUpNext ? null : (upNextCountdown ?? this.upNextCountdown),
      showReplay: showReplay ?? this.showReplay,
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
      audioDelayMs: audioDelayMs ?? this.audioDelayMs,
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
        _maybePreloadNext(pos);
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
            ? state.copyWith(
                isPlaying: true,
                clearError: true,
                showReplay: false,
              )
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

  /// The segment auto-skipped last, so an imprecise seek back into its
  /// tail does not skip it over and over.
  String? _lastSkippedKey;
  Timer? _sponsorNoticeTimer;
  Timer? _paidPromotionTimer;
  int _sponsorNoticeId = 0;

  /// Whether the video track was dropped because the app went to the
  /// background, so it is only restored if we were the ones who took it.
  bool _videoSuspended = false;

  Timer? _savePositionTimer;
  Timer? _sleepTimer;
  Timer? _bufferRecoveryTimer;
  Timer? _upNextTimer;

  /// Videos played before this one, most recent last. Drives "previous".
  final List<MediaItem> _history = [];

  /// Metadata fetched ahead of time for the video that is going to play
  /// next, so `loadVideo` can skip the round-trip. Consumed once.
  MediaItem? _preloadedItem;

  /// The video whose tail already triggered a prefetch, so the position
  /// stream does not fire one per frame.
  String? _preloadedFor;

  /// Related lists already fetched, so the autoplay candidate and the
  /// "Up next" card do not each pay for the request.
  final Map<String, List<MediaItem>> _relatedCache = {};

  /// Held open so `relatedVideosProvider` — which is autoDispose — stays
  /// warm for the suggestions list while the video plays.
  ProviderSubscription<AsyncValue<List<MediaItem>>>? _relatedWarm;

  final Random _random = Random();
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
    final finished = state.currentItem;
    switch (state.repeatMode) {
      case RepeatMode.one:
        await _player.seek(Duration.zero);
        await _player.play();
      case RepeatMode.all:
      case RepeatMode.shuffle:
        await _saveCurrentPosition();
        // The pick is made against the queue as it stands, and only then
        // does the finished video go back on the end — otherwise shuffle
        // could draw the video that just played.
        final choice = selectNext(
          state.queue,
          mode: state.repeatMode,
          skipShorts: _skipShorts,
          pickRandom: _random.nextInt,
        );
        if (choice != null) {
          _setQueue([
            ...choice.rest.where((q) => q.videoId != finished?.videoId),
            if (finished != null) finished,
          ]);
          await loadVideo(choice.next.videoId);
          return;
        }
        // Nothing else is queued, so looping means this one video again.
        if (finished != null) {
          await _player.seek(Duration.zero);
          await _player.play();
          return;
        }
        await _offerRelated();
      case RepeatMode.none:
        await _saveCurrentPosition();
        // Continue with whatever the user queued up, then with YouTube's
        // own "Up next" when the queue is empty and autoplay is on.
        if (await playNextInQueue(autoplay: true)) return;
        await _offerRelated();
      case RepeatMode.pause:
        await _saveCurrentPosition();
        state = state.copyWith(showReplay: true);
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
  Future<void> loadVideo(String videoId, {bool recordHistory = true}) async {
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

    // Whatever was on screen — an "Up next" offer, the ended card —
    // belongs to the video being replaced.
    _cancelUpNextTimer();

    final leaving = state.currentItem;
    if (recordHistory && leaving != null && leaving.videoId != videoId) {
      _pushHistory(leaving);
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
      clearUpNext: true,
      showReplay: false,
    );
    _cpn = HistorySync.newCpn();
    // Caps are recorded per video; a new one starts with a clean slate.
    _cappedHeights.clear();
    _preloadedFor = null;

    try {
      final sw = Stopwatch()..start();
      // Prefetched during the tail of the previous video, so the usual
      // couple of seconds of metadata round-trip is already paid for.
      final preloaded =
          _preloadedItem?.videoId == videoId ? _preloadedItem : null;
      _preloadedItem = null;
      if (preloaded != null) {
        debugPrint('loadVideo[$videoId]: metadata came from the prefetch');
      } else {
        debugPrint('loadVideo[$videoId]: fetching metadata...');
      }
      final repo = _ref.read(mediaItemRepositoryProvider);
      final item = preloaded ??
          await retryPlaybackOperation<MediaItem>(
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

      // Suggestions are wanted by the watch page and by autoplay alike;
      // starting it here means neither waits for it later.
      _warmRelated(videoId);

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
        audioDelayMs: channelPreferences?.audioDelayMs ?? 0,
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
        _onSponsorSegmentsLoaded();
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
      _onSponsorSegmentsLoaded();

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
    // A rolling playlist gets the low buffer whatever the preference
    // says; see effectiveBufferPreset().
    await applyEngineTuning(isLive: true);
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

    // Opt-in DASH: describe the same two relayed URLs as a manifest and
    // hand mpv that single URL, so ffmpeg muxes video and audio itself
    // instead of the player carrying a separate audio track. The
    // libmpv media_kit ships is built with --enable-libxml2 and
    // --enable-demuxer=dash on both Android and iOS (see
    // docs/DASH_FEASIBILITY.md), so the manifest is demuxed natively.
    final mpdUrl = settings.adaptiveStreaming && localAudioUrl != null
        ? _registerManifest(proxy, resolved, localVideoUrl, localAudioUrl)
        : null;

    // Retire the routes of whatever was playing before: the previous
    // relay would otherwise keep downloading and compete for bandwidth
    // with the stream that replaced it.
    proxy.retainOnly([
      localVideoUrl,
      if (localAudioUrl != null) localAudioUrl,
      if (mpdUrl != null) mpdUrl,
    ]);

    if (mpdUrl != null) {
      debugPrint('openStreams: opening DASH manifest');
      await _player.open(Media(mpdUrl));
      await _player.setRate(state.playbackSpeed);
      return resolved;
    }

    await _player.open(Media(localVideoUrl));
    // mpv resets audio-delay and the demuxer limits per file, so the
    // tweaks are re-asserted on every open rather than only at startup.
    await applyEngineTuning(isLive: false);
    await _player.setRate(state.playbackSpeed);
    if (localAudioUrl != null) {
      await _player.setAudioTrack(AudioTrack.uri(localAudioUrl));
    }
    return resolved;
  }

  /// Builds the DASH manifest for [resolved] and serves it from the
  /// proxy, or returns null when the formats cannot describe one.
  ///
  /// The manifest points at the loopback routes that were just
  /// registered rather than at googlevideo: ffmpeg would otherwise fetch
  /// the media itself over a TLS stack that cannot always reach the CDN.
  String? _registerManifest(
    StreamProxy proxy,
    ResolvedStream resolved,
    String localVideoUrl,
    String localAudioUrl,
  ) {
    final routes = <String, String>{
      resolved.videoUrl: localVideoUrl,
      if (resolved.audioUrl != null) resolved.audioUrl!: localAudioUrl,
    };
    final representations = resolved.dashRepresentations
        .where((rep) => routes.containsKey(rep.url.toString()))
        .toList();
    final builder = MpdBuilder(
      duration: _manifestDuration(representations),
      representations: representations,
    );
    if (builder.isEmpty) {
      debugPrint('openStreams: no DASH manifest for these formats');
      return null;
    }
    return proxy.registerText(
      builder.build(rewrite: (url) => routes[url.toString()] ?? url.toString()),
    );
  }

  /// A static MPD is invalid without a total duration, and the stream
  /// manifest does not carry one. Prefer the metadata duration; fall
  /// back to size over bitrate, which is close enough to seek by.
  Duration _manifestDuration(List<MpdRepresentation> representations) {
    final known = state.currentItem?.duration ?? Duration.zero;
    if (known > Duration.zero) return known;
    for (final rep in representations) {
      final size = rep.contentLength ?? 0;
      if (size > 0 && rep.bandwidth > 0) {
        return Duration(milliseconds: size * 8 * 1000 ~/ rep.bandwidth);
      }
    }
    return Duration.zero;
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
    // "Previous" restarts the current video most of the time, but the
    // button is only worth showing once there is somewhere to go back to.
    handler.onSkipPrevious = _history.isEmpty ? null : skipPrevious;
    handler.refreshControls();
  }

  /// Which queued video plays next, and what is left of the queue.
  ///
  /// Pure so the three rules that matter — order, shuffle, and passing
  /// over Shorts — can be tested without a player. Skipped Shorts stay
  /// in the queue: the user put them there deliberately and can still
  /// play them by hand; autoplay just never lands on one.
  static ({MediaItem next, List<MediaItem> rest})? selectNext(
    List<MediaItem> queue, {
    RepeatMode mode = RepeatMode.none,
    bool skipShorts = false,
    int Function(int max)? pickRandom,
  }) {
    final eligible = skipShorts
        ? queue.where((item) => !isAutoplayShort(item)).toList()
        : queue;
    if (eligible.isEmpty) return null;
    final pick = pickRandom ?? _firstIndex;
    final next = mode == RepeatMode.shuffle && eligible.length > 1
        ? eligible[pick(eligible.length) % eligible.length]
        : eligible.first;
    return (
      next: next,
      rest: queue.where((item) => item.videoId != next.videoId).toList(),
    );
  }

  static int _firstIndex(int max) => 0;

  /// A Short by the same rule the feeds use, so "skip Shorts" means the
  /// same thing in autoplay as it does in "Hide content".
  static bool isAutoplayShort(MediaItem item) => ContentFilter.isShorts(item);

  bool get _skipShorts =>
      _ref.read(settingsControllerProvider).skipShortsInAutoplay;

  /// Starts the next queued video, removing it from the queue. [autoplay]
  /// marks the automatic continuation, which is the only case that passes
  /// over Shorts — an explicit "next" plays whatever the user asked for.
  Future<bool> playNextInQueue({bool autoplay = false}) async {
    final choice = selectNext(
      state.queue,
      mode: state.repeatMode,
      skipShorts: autoplay && _skipShorts,
      pickRandom: _random.nextInt,
    );
    if (choice == null) return false;
    _setQueue(choice.rest);
    await loadVideo(choice.next.videoId);
    return true;
  }

  // ============================================================
  // "Up next" — the countdown before autoplay takes over
  // ============================================================

  /// How long the "Up next" card waits before loading, matching
  /// SmartTube's `loadNextVideo(5_000)`.
  static const upNextSeconds = 5;

  static PlayerStateData beginUpNext(PlayerStateData state, MediaItem next) =>
      state.copyWith(
        upNext: next,
        upNextCountdown: upNextSeconds,
        showReplay: false,
      );

  /// One second of the countdown. A result of zero means the wait is
  /// over and the video should load.
  static PlayerStateData tickUpNext(PlayerStateData state) {
    final remaining = (state.upNextCountdown ?? 0) - 1;
    return state.copyWith(upNextCountdown: remaining < 0 ? 0 : remaining);
  }

  /// The user declined: the offer goes away and the ended screen with
  /// its replay button stays.
  static PlayerStateData cancelUpNextState(PlayerStateData state) =>
      state.copyWith(clearUpNext: true, showReplay: true);

  /// Autoplay: offers the first eligible related video on a countdown
  /// card rather than cutting straight to it. Silent when the setting is
  /// off, the video was live, or the related list failed to load — the
  /// ended screen is shown instead.
  Future<void> _offerRelated() async {
    final item = state.currentItem;
    if (item == null || item.isLive) return;
    if (!_ref.read(settingsControllerProvider).autoplayNext) {
      state = state.copyWith(showReplay: true);
      return;
    }
    final next = await _relatedCandidate(item);
    if (next == null) {
      state = state.copyWith(showReplay: true);
      return;
    }
    debugPrint('autoplay: offering ${next.videoId}');
    _startUpNextCountdown(next);
  }

  /// The video autoplay would continue with, or null when nothing
  /// suitable was suggested.
  Future<MediaItem?> _relatedCandidate(MediaItem item) async {
    try {
      final related = await _relatedFor(item.videoId);
      final skipShorts = _skipShorts;
      return related
          .where((v) =>
              v.videoId != item.videoId &&
              !v.isLive &&
              !v.isUpcoming &&
              !_history.any((played) => played.videoId == v.videoId) &&
              !(skipShorts && isAutoplayShort(v)))
          .firstOrNull;
    } catch (e) {
      debugPrint('autoplay: related list unavailable: $e');
      return null;
    }
  }

  Future<List<MediaItem>> _relatedFor(String videoId) async {
    final cached = _relatedCache[videoId];
    if (cached != null) return cached;
    final related = await _ref.read(relatedVideosProvider(videoId).future);
    _relatedCache[videoId] = related;
    return related;
  }

  /// Keeps `relatedVideosProvider` — autoDispose — alive for the video
  /// being watched, so the suggestions list and the autoplay candidate
  /// share one request rather than each paying for it.
  void _warmRelated(String videoId) {
    _relatedWarm?.close();
    _relatedWarm = _ref.listen<AsyncValue<List<MediaItem>>>(
      relatedVideosProvider(videoId),
      (_, next) {
        final items = next.valueOrNull;
        if (items != null) _relatedCache[videoId] = items;
      },
    );
  }

  void _startUpNextCountdown(MediaItem next) {
    _cancelUpNextTimer();
    state = beginUpNext(state, next);
    // The countdown is exactly the window in which to pay for the next
    // video's metadata, so the card's "Play now" is instant.
    unawaited(_prefetchMediaItem(next.videoId));
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = tickUpNext(state);
      if (state.upNextCountdown == 0) {
        _cancelUpNextTimer();
        unawaited(playUpNextNow());
      }
    });
  }

  void _cancelUpNextTimer() {
    _upNextTimer?.cancel();
    _upNextTimer = null;
  }

  /// Dismisses the "Up next" offer and leaves the ended screen up.
  void cancelUpNext() {
    _cancelUpNextTimer();
    state = cancelUpNextState(state);
  }

  /// Skips the rest of the countdown.
  Future<void> playUpNextNow() async {
    final next = state.upNext;
    _cancelUpNextTimer();
    state = state.copyWith(clearUpNext: true, showReplay: false);
    if (next == null) return;
    await loadVideo(next.videoId);
  }

  /// Plays the finished video again from the top.
  Future<void> replay() async {
    _cancelUpNextTimer();
    state = state.copyWith(clearUpNext: true, showReplay: false);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  // ============================================================
  // Preload
  // ============================================================

  /// Fetches the next video's metadata while the current one plays out
  /// its last [_preloadWindow]. `loadVideo` consumes it, so the switch
  /// costs the stream resolve alone.
  static const _preloadWindow = Duration(seconds: 20);

  void _maybePreloadNext(Duration position) {
    final item = state.currentItem;
    final duration = state.duration;
    if (item == null || item.isLive) return;
    if (duration <= Duration.zero) return;
    if (_preloadedFor == item.videoId) return;
    if (duration - position > _preloadWindow) return;
    _preloadedFor = item.videoId;
    unawaited(_prefetchNext(item));
  }

  Future<void> _prefetchNext(MediaItem current) async {
    // Shuffle draws its pick at the last moment, so guessing here would
    // usually prefetch the wrong video; the countdown covers that case.
    if (state.repeatMode == RepeatMode.shuffle) return;
    final queued = selectNext(
      state.queue,
      mode: state.repeatMode,
      skipShorts: _skipShorts,
    )?.next;
    final next = queued ?? await _relatedCandidate(current);
    if (next == null) return;
    await _prefetchMediaItem(next.videoId);
  }

  Future<void> _prefetchMediaItem(String videoId) async {
    if (_preloadedItem?.videoId == videoId) return;
    try {
      final result =
          await _ref.read(mediaItemRepositoryProvider).getMediaItem(videoId);
      final item = result.dataOrNull;
      if (item != null) {
        debugPrint('preload: metadata ready for $videoId');
        _preloadedItem = item;
      }
    } catch (e) {
      debugPrint('preload: $videoId unavailable: $e');
    }
  }

  // ============================================================
  // Previous
  // ============================================================

  /// How far in a video has to be before "previous" restarts it instead
  /// of stepping back — the convention every media player shares.
  static const previousRestartThreshold = Duration(seconds: 5);

  /// Whether "previous" would step back rather than restart.
  static bool previousGoesBack(Duration position, bool hasHistory) =>
      hasHistory && position <= previousRestartThreshold;

  void _pushHistory(MediaItem item) {
    _history
      ..removeWhere((played) => played.videoId == item.videoId)
      ..add(item);
    // A watch session, not a browsing history: enough to walk back
    // through what autoplay chained together.
    if (_history.length > 50) _history.removeAt(0);
    _syncSkipControls();
  }

  /// The videos played before this one, oldest first.
  List<MediaItem> get history => List.unmodifiable(_history);

  /// Restarts the current video, or steps back to the previous one when
  /// barely anything has played.
  Future<void> skipPrevious() async {
    if (!previousGoesBack(state.position, _history.isNotEmpty)) {
      await _player.seek(Duration.zero);
      state = state.copyWith(position: Duration.zero, showReplay: false);
      await _player.play();
      return;
    }
    final previous = _history.removeLast();
    _syncSkipControls();
    await loadVideo(previous.videoId, recordHistory: false);
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

  // ============================================================
  // Engine tweaks — buffer preset, audio delay, pitch
  // ============================================================

  /// Pushes the buffer preset, the audio delay and the pitch mode onto
  /// mpv. Safe to call at any time; a no-op when the platform player is
  /// not the native one (tests, web).
  Future<void> applyEngineTuning({bool? isLive}) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    final settings = _ref.read(settingsControllerProvider);
    final properties = playerTuningProperties(
      preset: settings.bufferPreset,
      audioDelayMs: state.audioDelayMs,
      keepPitch: settings.keepPitch,
      isLive: isLive ?? state.currentItem?.isLive ?? false,
      totalRamBytes: await readDeviceRamBytes(),
    );
    for (final entry in properties.entries) {
      await _setEngineProperty(entry.key, entry.value);
    }
  }

  /// One property, never fatal: an mpv build without a given option
  /// should cost the user that tweak, not the video.
  Future<void> _setEngineProperty(String name, String value) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty(name, value);
    } catch (e) {
      debugPrint('player tuning: $name=$value rejected ($e)');
    }
  }

  /// Chooses how far ahead the player buffers. Persisted globally and
  /// applied to the running playback immediately.
  Future<void> setBufferPreset(BufferPreset preset) async {
    await _ref
        .read(settingsControllerProvider.notifier)
        .setBufferPreset(preset);
    await applyEngineTuning();
  }

  /// Shifts the audio against the picture, in milliseconds, and
  /// remembers the choice for the current channel.
  Future<void> setAudioDelay(int milliseconds) async {
    final normalized = normalizeAudioDelayMs(milliseconds);
    state = state.copyWith(audioDelayMs: normalized);
    await _setEngineProperty('audio-delay', audioDelayProperty(normalized));
    await _rememberChannel(audioDelayMs: normalized);
  }

  /// SmartTube's pitch effect, inverted: keeping the pitch is mpv's
  /// default, turning it off lets the pitch ride the speed.
  Future<void> setKeepPitch(bool keepPitch) async {
    await _ref
        .read(settingsControllerProvider.notifier)
        .setKeepPitch(keepPitch);
    await _setEngineProperty(
      'audio-pitch-correction',
      pitchCorrectionProperty(keepPitch: keepPitch),
    );
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
    int? audioDelayMs,
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
        audioDelayMs: audioDelayMs,
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

  /// Runs on every position tick. Resolves the action configured for
  /// the segment under the playhead — skip it, offer a button, or leave
  /// it alone — mirroring SmartTube's per-category actions.
  void _checkSponsorSegment(Duration position) {
    final settings = _ref.read(settingsControllerProvider);
    if (state.sponsorSegments.isEmpty || !settings.sponsorBlockEnabled) {
      if (state.showSponsorSkipButton) {
        state = state.copyWith(showSponsorSkipButton: false);
      }
      return;
    }

    final match = resolveSponsorSegmentAt(
      segments: state.sponsorSegments,
      position: position,
      actionFor: settings.actionFor,
      doNotSkip: state.doNotSkipSegments,
    );
    final active = match?.segment;
    final action = match?.action ?? SegmentAction.none;

    if (active == null) {
      // Out of every segment: the next entry may skip again.
      _lastSkippedKey = null;
      if (state.showSponsorSkipButton) {
        state = state.copyWith(showSponsorSkipButton: false);
      }
      return;
    }

    if (action == SegmentAction.skip) {
      // Guard against a seek that lands a hair short of the end and
      // re-triggers the same skip forever.
      if (_lastSkippedKey == active.key) return;
      _lastSkippedKey = active.key;
      _skipWithNotice(active);
    } else {
      state = state.copyWith(
        upcomingSegment: active,
        showSponsorSkipButton: true,
      );
    }
  }

  /// Seeks past [segment] and offers the skip back for a few seconds.
  void _skipWithNotice(SponsorSegment segment) {
    // A submitted segment can end past the real media length; seeking
    // beyond it is what used to strand playback at the very end.
    final duration = state.duration;
    seek(
      duration > Duration.zero && segment.end > duration
          ? duration
          : segment.end,
    );
    _showSponsorNotice(segment);
  }

  void _showSponsorNotice(SponsorSegment segment) {
    _sponsorNoticeTimer?.cancel();
    state = state.copyWith(
      showSponsorSkipButton: false,
      sponsorNotice: SponsorSkipNotice(
        segment: segment,
        id: ++_sponsorNoticeId,
      ),
    );
    _sponsorNoticeTimer = Timer(const Duration(seconds: 4), () {
      if (state.sponsorNotice?.id == _sponsorNoticeId) {
        state = state.copyWith(clearSponsorNotice: true);
      }
    });
  }

  /// The skip button: seeks past the segment the button is offering.
  void skipSponsorSegment() {
    final segment = state.upcomingSegment;
    if (segment == null) return;
    _lastSkippedKey = segment.key;
    _skipWithNotice(segment);
  }

  /// Undo: back to where the segment started, and this segment is not
  /// skipped again for the rest of the video.
  void undoSponsorSkip() {
    final notice = state.sponsorNotice;
    if (notice == null) return;
    _sponsorNoticeTimer?.cancel();
    _lastSkippedKey = null;
    state = state.copyWith(
      doNotSkipSegments: {...state.doNotSkipSegments, notice.segment.key},
      showSponsorSkipButton: false,
      clearSponsorNotice: true,
    );
    seek(notice.segment.start);
  }

  void dismissSponsorNotice() {
    _sponsorNoticeTimer?.cancel();
    state = state.copyWith(clearSponsorNotice: true);
  }

  void dismissPaidPromotionNotice() {
    _paidPromotionTimer?.cancel();
    if (state.showPaidPromotionNotice) {
      state = state.copyWith(showPaidPromotionNotice: false);
    }
  }

  /// Jumps to the community-marked highlight, when the video has one.
  void jumpToHighlight() {
    final highlight = state.highlightSegment;
    if (highlight == null) return;
    seek(highlight.start);
  }

  /// Resets the per-video sponsor state and raises the paid-promotion
  /// notice when the whole video is a placement.
  void _onSponsorSegmentsLoaded() {
    _lastSkippedKey = null;
    _sponsorNoticeTimer?.cancel();
    _paidPromotionTimer?.cancel();
    final isPaid = state.sponsorSegments
        .any((s) => s.category == SponsorCategory.exclusiveAccess);
    state = state.copyWith(
      doNotSkipSegments: const {},
      showSponsorSkipButton: false,
      showPaidPromotionNotice:
          isPaid && _ref.read(settingsControllerProvider).sponsorBlockEnabled,
      clearSponsorNotice: true,
    );
    if (state.showPaidPromotionNotice) {
      _paidPromotionTimer = Timer(
        const Duration(seconds: 8),
        () => state = state.copyWith(showPaidPromotionNotice: false),
      );
    }
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
    _upNextTimer?.cancel();
    _relatedWarm?.close();
    _sponsorNoticeTimer?.cancel();
    _paidPromotionTimer?.cancel();
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

// ============================================================
// Network engine stats
// ============================================================

/// What mpv itself reports about the stream it is playing — the numbers
/// SmartTube shows in its debug overlay, which no Flutter-side state
/// mirror can answer (the demuxer cache, the decoder in use, dropped
/// frames).
class PlayerEngineStats {
  const PlayerEngineStats({
    this.cacheDuration,
    this.cacheBufferingPercent,
    this.videoBitrate,
    this.audioBitrate,
    this.hwdec,
    this.videoCodec,
    this.droppedFrames,
  });

  /// `demuxer-cache-duration` — seconds of media already downloaded
  /// beyond the playhead.
  final double? cacheDuration;

  /// `cache-buffering-state` — 0-100 while mpv is filling the cache.
  final int? cacheBufferingPercent;

  /// `video-bitrate` / `audio-bitrate`, in bits per second.
  final int? videoBitrate;
  final int? audioBitrate;

  /// `hwdec-current` — the hardware decoder actually in use, or "no".
  final String? hwdec;

  /// `video-codec` — the decoder's own description of the stream.
  final String? videoCodec;

  /// `frame-drop-count` — frames the decoder threw away to keep up.
  final int? droppedFrames;

  static const PlayerEngineStats empty = PlayerEngineStats();
}

/// Reads one property, treating any failure as "not available": mpv
/// raises for properties that have no value yet (before the first
/// frame) as readily as for ones it does not know.
Future<String?> _engineProperty(NativePlayer platform, String name) async {
  try {
    final value = await platform.getProperty(name);
    return value.isEmpty ? null : value;
  } catch (_) {
    return null;
  }
}

Future<PlayerEngineStats> readPlayerEngineStats(NativePlayer platform) async {
  final values = <String, String?>{};
  for (final name in const [
    'demuxer-cache-duration',
    'cache-buffering-state',
    'video-bitrate',
    'audio-bitrate',
    'hwdec-current',
    'video-codec',
    'frame-drop-count',
  ]) {
    values[name] = await _engineProperty(platform, name);
  }
  return PlayerEngineStats(
    cacheDuration: double.tryParse(values['demuxer-cache-duration'] ?? ''),
    cacheBufferingPercent:
        double.tryParse(values['cache-buffering-state'] ?? '')?.round(),
    videoBitrate: double.tryParse(values['video-bitrate'] ?? '')?.round(),
    audioBitrate: double.tryParse(values['audio-bitrate'] ?? '')?.round(),
    hwdec: values['hwdec-current'],
    videoCodec: values['video-codec'],
    droppedFrames: double.tryParse(values['frame-drop-count'] ?? '')?.round(),
  );
}

/// Polls mpv once a second. autoDispose is what bounds the polling: the
/// stats page is the only listener, so nothing is asked of mpv while
/// that page is closed.
final playerEngineStatsProvider =
    StreamProvider.autoDispose<PlayerEngineStats>((ref) async* {
  final platform = ref.watch(mediaPlayerProvider).platform;
  if (platform is! NativePlayer) {
    yield PlayerEngineStats.empty;
    return;
  }
  while (true) {
    yield await readPlayerEngineStats(platform);
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});
