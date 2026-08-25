// ============================================================
// NativeEngine — the platform channel contract
// ============================================================
// The Kotlin side is written against these exact method names, argument
// keys and event shapes. Nothing here reaches the platform, so what is
// actually asserted is that Dart holds up its half of the contract.
// ============================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/player/native_engine.dart';
import 'package:smarttube_poc/domain/player/player_engine.dart';

/// Top level: a getter cannot be declared inside a function body, and the
/// binding is only valid once ensureInitialized() has run — which it has
/// by the time any test touches this.
TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeEngine engine;
  late List<MethodCall> calls;

  Future<void> emit(Map<String, Object?> event) => messenger
      .handlePlatformMessage(
        NativeEngine.eventChannelName,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );

  setUp(() async {
    calls = [];
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel(NativeEngine.methodChannelName),
        (MethodCall call) async {
          calls.add(call);
          return call.method == 'create' ? 7 : null;
        },
      )
      // An EventChannel is a MethodChannel underneath; its listen/cancel
      // has to be answered or receiveBroadcastStream throws.
      ..setMockMethodCallHandler(
        const MethodChannel(NativeEngine.eventChannelName),
        (call) async => null,
      );
    engine = NativeEngine();
    await engine.initialize();
  });

  tearDown(() async {
    await engine.dispose();
  });

  test('resolves streams on the platform side', () {
    expect(engine.kind, PlayerEngineKind.native);
    expect(engine.resolvesStreamsNatively, isTrue);
  });

  test('initialize creates the player once', () async {
    await engine.initialize();
    expect(calls.where((call) => call.method == 'create'), hasLength(1));
  });

  test('open carries the video id and the restored preferences', () async {
    await engine.openVideo(
      'dQw4w9WgXcQ',
      preferredHeight: 1080,
      audioTrackId: 'orig',
      subtitleCode: 'ar',
    );

    final open = calls.firstWhere((call) => call.method == 'open');
    expect(open.arguments, {
      'videoId': 'dQw4w9WgXcQ',
      'preferredHeight': 1080,
      'audioTrackId': 'orig',
      'subtitleCode': 'ar',
    });
  });

  test('a URL is refused rather than quietly resolved twice', () {
    expect(
      () => engine.openDirect(url: 'file:///tmp/a.mp4'),
      throwsUnsupportedError,
    );
  });

  test('intent methods use the argument keys the platform reads', () async {
    await engine.seek(const Duration(milliseconds: 4500));
    await engine.setSpeed(1.25);
    await engine.setVolume(50);
    await engine.selectVideoTrack(height: 720, codec: 'avc1');
    await engine.selectAudioTrack('dub-ar');
    await engine.selectSubtitle('ar', url: 'https://ignored.test');
    await engine.setVideoTrackEnabled(false);
    await engine.setBufferPreset(NativeBufferPreset.highest);

    final byName = {
      for (final call in calls) call.method: call.arguments,
    };
    expect(byName['seek'], {'positionMs': 4500});
    expect(byName['setSpeed'], {'speed': 1.25});
    // 0..300 on the way in, 0..1 on the way out.
    expect(byName['setVolume'], {'volume': 0.5});
    expect(byName['selectVideoTrack'], {'height': 720, 'codec': 'avc1'});
    expect(byName['selectAudioTrack'], {'id': 'dub-ar'});
    // The timedtext URL is Dart's business, never the platform's.
    expect(byName['selectSubtitle'], {'code': 'ar'});
    expect(byName['setVideoEnabled'], {'enabled': false});
    expect(byName['setBufferPreset'], {'preset': 'highest'});
  });

  test('auto quality and captions off travel as nulls', () async {
    await engine.selectVideoTrack();
    await engine.selectSubtitle(null);

    final byName = {
      for (final call in calls) call.method: call.arguments,
    };
    expect(byName['selectVideoTrack'], {'height': null, 'codec': null});
    expect(byName['selectSubtitle'], {'code': null});
  });

  test('boosted volume is flattened, not distorted', () async {
    await engine.setVolume(250);
    final call = calls.firstWhere((call) => call.method == 'setVolume');
    expect(call.arguments, {'volume': 1.0});
  });

  test('a state event feeds every playback stream', () async {
    final playing = engine.playing.first;
    final buffering = engine.buffering.first;
    final position = engine.position.first;
    final duration = engine.duration.first;
    final buffered = engine.buffer.first;
    final completed = engine.completed.first;

    await emit({
      'event': 'state',
      'playing': true,
      'buffering': true,
      'completed': true,
      'positionMs': 1000,
      'durationMs': 60000,
      'bufferedMs': 20000,
    });

    expect(await playing, isTrue);
    expect(await buffering, isTrue);
    expect(await completed, isTrue);
    expect(await position, const Duration(seconds: 1));
    expect(await duration, const Duration(minutes: 1));
    expect(await buffered, const Duration(seconds: 20));
  });

  test('an unchanged flag is not republished', () async {
    final seen = <bool>[];
    final subscription = engine.playing.listen(seen.add);

    for (final playing in [true, true, false]) {
      await emit({
        'event': 'state',
        'playing': playing,
        'buffering': false,
        'completed': false,
        'positionMs': 0,
        'durationMs': 0,
        'bufferedMs': 0,
      });
    }
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [true, false]);
  });

  test('a tracks event becomes the pickers', () async {
    final tracks = engine.tracks.first;

    await emit({
      'event': 'tracks',
      'video': [
        {
          'height': 1080,
          'codec': 'vp9',
          'fps': 60,
          'bitrate': 4200000,
          'hdr': true,
          'label': '1080p60 HDR',
        },
      ],
      'audio': [
        {
          'id': 'orig',
          'label': 'Original',
          'bitrate': 128000,
          'codec': 'opus',
        },
      ],
      'subtitle': [
        {'code': 'ar', 'label': 'العربية'},
      ],
    });

    final result = await tracks;
    expect(result.video.single.height, 1080);
    expect(result.video.single.hdr, isTrue);
    expect(result.video.single.fps, 60);
    expect(result.audio.single.id, 'orig');
    expect(result.subtitle.single.code, 'ar');
  });

  test('a format event names what is playing and where it came from',
      () async {
    final format = engine.format.first;

    await emit({
      'event': 'format',
      'label': '720p',
      'codec': 'avc1',
      'fps': 30,
      'bitrate': 1500000,
      'width': 1280,
      'height': 720,
      'hdr': false,
      'source': 'sabr',
    });

    final result = await format;
    expect(result.label, '720p');
    expect(result.source, 'sabr');
    expect(result.width, 1280);
    expect(result.height, 720);
  });

  test('an error event keeps the platform code intact', () async {
    final error = engine.error.first;

    await emit({
      'event': 'error',
      'code': 'unplayable',
      'message': 'members-only',
    });

    final result = await error;
    expect(result.code, 'unplayable');
    expect(result.message, 'members-only');
  });

  test('a malformed event is dropped rather than thrown', () async {
    // The platform is another codebase; a missing key must not take the
    // player down with it.
    await emit({'event': 'state'});
    await emit({'event': 'tracks'});
    await emit({'event': 'nonsense'});
    await pumpEventQueue();
  });
}
