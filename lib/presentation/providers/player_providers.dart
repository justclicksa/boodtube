// ============================================================
// PlayerController — owns playback state for the player screen
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/youtube/stream_resolver.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_subtitle.dart';
import '../../domain/entities/sponsor_segment.dart';
import '../../services/audio_player_handler.dart';
import '../../services/history_sync.dart';
import 'auth_providers.dart';
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
  });

  final MediaItem? currentItem;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isBuffering;
  final double playbackSpeed;
  final bool isLoading;
  final String? error;
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

  PlayerStateData copyWith({
    MediaItem? currentItem,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isBuffering,
    double? playbackSpeed,
    bool? isLoading,
    String? error,
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
    bool clearError = false,
    bool clearItem = false,
    bool clearSleepTimer = false,
    bool clearSubtitle = false,
    bool clearPendingHeight = false,
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
    );
  }
}

class PlayerController extends StateNotifier<PlayerStateData> {
  PlayerController(this._ref) : super(const PlayerStateData()) {
    _player = _ref.read(mediaPlayerProvider);

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
        state = state.copyWith(error: message, isLoading: false);
      }))
      ..add(_player.stream.position.listen((pos) {
        state = state.copyWith(position: pos);
        _checkSponsorSegment(pos);
      }))
      ..add(_player.stream.duration.listen((dur) {
        state = state.copyWith(duration: dur);
      }))
      ..add(_player.stream.buffer.listen((buf) {
        state = state.copyWith(buffered: buf);
      }))
      ..add(_player.stream.buffering.listen((buffering) {
        state = state.copyWith(isBuffering: buffering);
      }))
      ..add(_player.stream.playing.listen((playing) {
        // Frames are arriving, so whatever was reported earlier did not
        // stop playback.
        state = playing
            ? state.copyWith(isPlaying: true, clearError: true)
            : state.copyWith(isPlaying: false);
      }))
      ..add(_player.stream.completed.listen(_onCompleted));
  }

  final Ref _ref;
  late final Player _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _savePositionTimer;
  Timer? _sleepTimer;

  /// Guards against a second quality switch starting while the first is
  /// still resolving — two concurrent `Player.open` calls race.
  bool _switchingQuality = false;

  /// mpv messages that do not mean playback failed.
  static const _benignErrors = [
    'cannot seek in this stream',
    'force-seekable',
    'cannot reuse http connection',
    'failed to create file cache',
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
        // Continue with whatever the user queued up.
        await playNextInQueue();
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
    state = state.copyWith(isLoading: true, clearError: true);
    _cpn = HistorySync.newCpn();

    try {
      final sw = Stopwatch()..start();
      debugPrint('loadVideo[$videoId]: fetching metadata...');
      final repo = _ref.read(mediaItemRepositoryProvider);
      final result =
          await repo.getMediaItem(videoId).timeout(const Duration(seconds: 45));

      final item = result.when(
        success: (item) => item,
        failure: (message, type, cause) => throw Exception(message),
      );
      debugPrint('loadVideo: metadata done in ${sw.elapsedMilliseconds}ms');

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
          currentQualityLabel: 'LIVE',
          availableHeights: const [],
          sponsorSegments: const [],
        );
        await _ref.read(audioHandlerProvider).setMediaItem(item);
        return;
      }

      final resolved = await _openStreams(videoId);

      state = state.copyWith(
        currentItem: item,
        isLoading: false,
        currentVideoUrl: resolved.videoUrl,
        currentAudioUrl: resolved.audioUrl,
        currentQualityLabel: resolved.qualityLabel,
        availableHeights: resolved.availableHeights,
        sponsorSegments: item.sponsorSegments,
      );

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
        )
        .timeout(const Duration(seconds: 60));
    debugPrint('openStreams: resolved in ${sw.elapsedMilliseconds}ms '
        '(${resolved.qualityLabel}, audio: ${resolved.audioUrl != null})');

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

  /// Re-opens the current video at a different resolution, keeping the
  /// playback position, speed and play/pause state. Metadata is reused —
  /// only the stream URLs change — so this is a couple of seconds rather
  /// than a full reload.
  Future<void> switchQuality(int height) async {
    final item = state.currentItem;
    if (item == null || _switchingQuality) return;
    _switchingQuality = true;

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
      final resolved = await _openStreams(item.videoId, exactHeight: height);
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
        clearPendingHeight: true,
      );
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
    final item = state.currentItem;
    // A live broadcast has no position worth remembering — "where you
    // left off" is always "now".
    if (item == null || item.isLive) return;
    final libraryRepo = _ref.read(localLibraryRepositoryProvider);
    await libraryRepo.savePlayPosition(item.videoId, state.position);
    await libraryRepo.addToHistory(item, position: state.position);

    // Report to the account too, so the same video resumes here on the
    // phone, on the web and in the official apps.
    final cpn = _cpn;
    if (cpn != null) {
      await _ref.read(historySyncProvider).push(
            videoId: item.videoId,
            position: state.position,
            duration: state.duration,
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
    state = state.copyWith(queue: [...state.queue, item]);
  }

  void playNext(MediaItem item) {
    final rest = state.queue.where((q) => q.videoId != item.videoId).toList();
    state = state.copyWith(queue: [item, ...rest]);
  }

  void removeFromQueue(String videoId) {
    state = state.copyWith(
      queue: state.queue.where((q) => q.videoId != videoId).toList(),
    );
  }

  void clearQueue() => state = state.copyWith(queue: const []);

  /// Starts the next queued video, removing it from the queue.
  Future<bool> playNextInQueue() async {
    if (state.queue.isEmpty) return false;
    final next = state.queue.first;
    state = state.copyWith(queue: state.queue.skip(1).toList());
    await loadVideo(next.videoId);
    return true;
  }

  void setSeekInterval(Duration interval) {
    state = state.copyWith(seekInterval: interval);
  }

  void setSpeed(double speed) {
    _player.setRate(speed);
    state = state.copyWith(playbackSpeed: speed);
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
  Future<void> selectSubtitle(MediaSubtitle? subtitle) async {
    if (subtitle == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      state = state.copyWith(clearSubtitle: true);
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

  @override
  void dispose() {
    _savePositionTimer?.cancel();
    _sleepTimer?.cancel();
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
