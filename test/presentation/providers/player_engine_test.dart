// ============================================================
// PlayerController against a fake PlayerEngine
// ============================================================
// The controller used to drive media_kit directly, so nothing about it
// could be exercised without libmpv. Everything below runs against a
// recording engine instead, which is also how the two real engines are
// told apart: one re-opens on a quality switch and returns what that
// produced, the other switches in place and returns null.
// ============================================================

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/core/utils/result.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/player/player_engine.dart';
import 'package:smarttube_poc/presentation/screens/player/subtitle_styles.dart';
import 'package:smarttube_poc/services/player_tuning.dart';
import 'package:smarttube_poc/domain/repositories/local_library_repository.dart';
import 'package:smarttube_poc/domain/repositories/media_item_repository.dart';
import 'package:smarttube_poc/presentation/providers/content_providers.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/services/audio_player_handler.dart';
import 'package:smarttube_poc/services/history_sync.dart';

import '../../support/player_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlayerEngine engine;

  /// Built on the shared harness rather than a bare container: the
  /// merged loadVideo reaches for the library, the history sync and the
  /// feed repositories, and without those stubs it opens a real sqlite
  /// file that `flutter test` has no path_provider for.
  Future<ProviderContainer> makeContainer({bool nativeStyle = false}) async {
    engine = FakePlayerEngine(switchesInPlace: nativeStyle);
    final harness = await playerTestHarness(
      overrides: [
        playerEngineProvider.overrideWithValue(engine),
        localLibraryRepositoryProvider.overrideWithValue(FakeLibrary()),
        historySyncProvider.overrideWithValue(FakeHistorySync()),
        audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
        mediaItemRepositoryProvider.overrideWithValue(FakeMediaItems()),
        // loadVideo warms the suggestions list so autoplay and the
        // sidebar share one request. Overriding the whole family keeps
        // that off the content repository, and therefore off the
        // database, which has no path_provider here.
        relatedVideosProvider.overrideWith((ref, videoId) async => <MediaItem>[]),
      ],
    );
    return harness.container;
  }

  group('PlayerController delegates to the engine', () {
    test('transport controls go through the engine, not media_kit', () async {
      final container = await makeContainer();
      final controller = container.read(playerControllerProvider.notifier);

      controller.togglePlayPause();
      controller.seek(const Duration(seconds: 42));
      controller.setSpeed(1.5);
      await controller.setVolume(80);

      expect(engine.calls, contains('play'));
      expect(engine.calls, contains('seek:42000'));
      expect(engine.calls, contains('setSpeed:1.5'));
      expect(engine.calls, contains('setVolume:80.0'));
      expect(
        container.read(playerControllerProvider).position,
        const Duration(seconds: 42),
      );
    });

    test('boosted volume reaches the engine as a percentage', () async {
      final container = await makeContainer();
      await container.read(playerControllerProvider.notifier).setVolume(400);

      // Clamped to the 300% ceiling the menu offers, still a percentage:
      // an engine that speaks 0..1 is the one that has to convert.
      expect(engine.calls, contains('setVolume:300.0'));
    });

    test('backgrounding drops the video track through the engine', () async {
      final container = await makeContainer();
      final controller = container.read(playerControllerProvider.notifier);
      await controller.loadVideo('abc123');

      controller
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(engine.calls, contains('setVideoTrackEnabled:false'));
      expect(engine.calls, contains('setVideoTrackEnabled:true'));
    });
  });

  group('quality switching', () {
    test('a re-opening engine is not asked to switch tracks', () async {
      final container = await makeContainer();
      final controller = container.read(playerControllerProvider.notifier);
      await controller.loadVideo('abc123');
      controller.seek(const Duration(seconds: 90));
      engine.calls.clear();

      await controller.switchQuality(720);

      // An engine that does not resolve streams cannot switch height on
      // its own: there is one signed URL for one rendition behind it. The
      // controller resolves again and reopens instead, so the engine must
      // never see selectVideoTrack.
      //
      // What that re-open then does is not asserted here — it runs the
      // real resolver against googlevideo, which a unit test has no
      // business reaching. The emulator run in docs/UNIFIED_PLAYER.md
      // covers it, and StreamResolver has no interface to fake behind.
      expect(engine.calls, isNot(contains('selectVideoTrack:720')));
      expect(container.read(playerControllerProvider).pendingHeight, isNull);
    });

    test('an in-place engine never re-seeks', () async {
      final container = await makeContainer(nativeStyle: true);
      final controller = container.read(playerControllerProvider.notifier);
      await controller.loadVideo('abc123');
      controller.seek(const Duration(seconds: 90));
      engine.calls.clear();

      await controller.switchQuality(720);

      expect(engine.calls, ['selectVideoTrack:720']);
      expect(container.read(playerControllerProvider).pendingHeight, isNull);
      expect(container.read(playerControllerProvider).isLoading, isFalse);
    });
  });

  group('platform-reported tracks', () {
    test('populate the quality menu and the audio track list', () async {
      final container = await makeContainer(nativeStyle: true);
      container.read(playerControllerProvider.notifier);

      engine.emitTracks(
        const EngineTracks(
          video: [
            EngineVideoTrack(height: 720),
            EngineVideoTrack(height: 1080),
            EngineVideoTrack(height: 360),
          ],
          audio: [EngineAudioTrack(id: 'orig', label: 'Original')],
        ),
      );
      await pumpEventQueue();

      final state = container.read(playerControllerProvider);
      // Highest first, the order the picker renders in.
      expect(state.availableHeights, [1080, 720, 360]);
      expect(state.audioTracks.single.id, 'orig');
    });

    test('a format event names the rung that took effect', () async {
      final container = await makeContainer(nativeStyle: true);
      container.read(playerControllerProvider.notifier);

      engine.emitFormat(
        const EngineFormat(label: '1080p', source: 'dash'),
      );
      await pumpEventQueue();

      final state = container.read(playerControllerProvider);
      expect(state.currentQualityLabel, '1080p');
      expect(state.sourceClient, 'dash');
    });
  });

  group('a capped stream', () {
    test('steps down a rung instead of showing an error', () async {
      final container = await makeContainer(nativeStyle: true);
      final controller = container.read(playerControllerProvider.notifier);
      await controller.loadVideo('abc123');
      engine
        ..emitTracks(
          const EngineTracks(
            video: [
              EngineVideoTrack(height: 1080),
              EngineVideoTrack(height: 720),
            ],
          ),
        )
        ..emitFormat(const EngineFormat(label: '1080p'));
      await pumpEventQueue();
      engine.calls.clear();

      engine.emitError(
        const EnginePlaybackError(
          EnginePlaybackError.streamCapped,
          'stream-capped',
        ),
      );
      await pumpEventQueue();

      expect(engine.calls, contains('selectVideoTrack:720'));
      expect(container.read(playerControllerProvider).error, isNull);
    });

    test('surfaces the error once there is nothing lower left', () async {
      final container = await makeContainer(nativeStyle: true);
      final controller = container.read(playerControllerProvider.notifier);
      await controller.loadVideo('abc123');
      await pumpEventQueue();

      engine.emitError(
        const EnginePlaybackError(
          EnginePlaybackError.streamCapped,
          'stream-capped',
        ),
      );
      await pumpEventQueue();

      expect(container.read(playerControllerProvider).error, 'stream-capped');
    });
  });
}

/// Records what the controller asks for and answers the way whichever
/// real engine is being stood in for would.
class FakePlayerEngine implements PlayerEngine {
  FakePlayerEngine({this.switchesInPlace = false});

  /// True stands in for the native engine, which selects a track on a
  /// manifest it already holds; false for mpv, which has to re-resolve.
  final bool switchesInPlace;

  final List<String> calls = [];

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffer =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<EnginePlaybackError> _errors =
      StreamController<EnginePlaybackError>.broadcast();
  final StreamController<EngineTracks> _tracks =
      StreamController<EngineTracks>.broadcast();
  final StreamController<EngineFormat> _formats =
      StreamController<EngineFormat>.broadcast();

  void emitTracks(EngineTracks tracks) => _tracks.add(tracks);

  void emitFormat(EngineFormat format) => _formats.add(format);

  void emitError(EnginePlaybackError error) => _errors.add(error);

  @override
  PlayerEngineKind get kind =>
      switchesInPlace ? PlayerEngineKind.native : PlayerEngineKind.mpv;

  @override
  bool get resolvesStreamsNatively => switchesInPlace;

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<EngineOpenResult> openVideo(
    String videoId, {
    int? preferredHeight,
    String? audioTrackId,
    String? subtitleCode,
  }) async {
    calls.add('openVideo:$videoId:$preferredHeight');
    if (switchesInPlace) return const EngineOpenResult();
    return EngineOpenResult(
      videoUrl: 'https://example.test/$videoId',
      qualityLabel: '${preferredHeight ?? 1080}p',
      videoHeight: preferredHeight ?? 1080,
      availableHeights: const [1080, 720, 360],
      sourceClient: 'fake',
    );
  }

  @override
  Future<void> openDirect({required String url, String? audioUrl}) async =>
      calls.add('openDirect:$url');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setSpeed(double speed) async => calls.add('setSpeed:$speed');

  @override
  Future<void> setVolume(double percent) async =>
      calls.add('setVolume:$percent');

  @override
  Future<EngineOpenResult?> selectVideoTrack({int? height, String? codec}) {
    calls.add('selectVideoTrack:$height');
    if (switchesInPlace) return Future.value();
    return openVideo('abc123', preferredHeight: height);
  }

  @override
  Future<EngineOpenResult?> selectAudioTrack(String id) {
    calls.add('selectAudioTrack:$id');
    if (switchesInPlace) return Future.value();
    return openVideo('abc123');
  }

  @override
  Future<void> selectSubtitle(
    String? code, {
    String? url,
    String? label,
  }) async =>
      calls.add('selectSubtitle:$code');

  @override
  Future<void> setVideoTrackEnabled(bool enabled) async =>
      calls.add('setVideoTrackEnabled:$enabled');

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<Duration> get buffer => _buffer.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<EnginePlaybackError> get error => _errors.stream;

  @override
  Stream<EngineTracks> get tracks => _tracks.stream;

  @override
  Stream<EngineFormat> get format => _formats.stream;

  final List<String> tuningCalls = [];

  @override
  Future<void> applyTuning({
    required BufferPreset preset,
    required int audioDelayMs,
    required bool keepPitch,
    required bool isLive,
  }) async {
    tuningCalls.add('${preset.name}/$audioDelayMs/$keepPitch/$isLive');
  }

  @override
  Widget buildSurface({
    BoxFit fit = BoxFit.contain,
    SubtitleStyle subtitleStyle = SubtitleStyle.defaultStyle,
    double subtitleScale = 1,
    double subtitleOffset = 24,
    double subtitleBackgroundOpacity = 0.67,
  }) =>
      const SizedBox.shrink();
}

/// Only the three members PlayerController reaches for are real; the
/// rest of the interface is never touched from the player.
class FakeLibrary implements LocalLibraryRepository {
  @override
  Future<Result<void>> savePlayPosition(String videoId, Duration position) =>
      Future.value(const Success<void>(null));

  @override
  Future<Result<void>> addToHistory(MediaItem item, {Duration? position}) =>
      Future.value(const Success<void>(null));

  @override
  Future<Result<Duration?>> getPlayPosition(String videoId) =>
      Future.value(const Success<Duration?>(null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHistorySync implements HistorySync {
  @override
  Future<void> push({
    required String videoId,
    required Duration position,
    required Duration duration,
    required String cpn,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioHandler implements SmartTubeAudioHandler {
  @override
  Future<void> setMediaItem(MediaItem item) async {}

  @override
  void refreshControls() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMediaItems implements MediaItemRepository {
  @override
  Future<Result<MediaItem>> getMediaItem(String videoId) async => Success(
        MediaItem(
          videoId: videoId,
          title: 'Fake',
          author: 'Fake channel',
          channelId: '',
          duration: const Duration(minutes: 3),
          publishedAt: MediaItem.unknownDate,
          formats: const [],
          subtitles: const [],
          chapters: const [],
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
