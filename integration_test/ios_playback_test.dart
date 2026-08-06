// ============================================================
// iOS playback smoke test — drives the app on a real simulator
// ============================================================
// The iOS paths this exercises had never been run: mpv through
// VideoToolbox, and the 127.0.0.1 stream relay under App Transport
// Security. `pumpAndSettle` is unusable here — the loading shimmer
// animates forever and the feed comes off the network — so every wait
// is an explicit pump loop with a deadline.
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smarttube_poc/main.dart' as app;
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/widgets/video_card.dart';

/// Pumps until [condition] holds or [timeout] elapses. Returns whether
/// the condition was met.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 45),
  Duration step = const Duration(milliseconds: 250),
}) async {
  var waited = Duration.zero;
  while (waited < timeout) {
    if (condition()) return true;
    await tester.pump(step);
    waited += step;
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home feed loads, then a video actually plays', (tester) async {
    app.main();
    await tester.pump();

    // 1. Home feed — proves InnerTube extraction works on iOS.
    final feedLoaded = await pumpUntil(
      tester,
      () => find.byType(VideoCard).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    );
    expect(feedLoaded, isTrue, reason: 'home feed never produced a VideoCard');
    debugPrint('IOSTEST: feed loaded '
        '${find.byType(VideoCard).evaluate().length} cards');

    // 2. Open the player.
    await tester.tap(find.byType(VideoCard).first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(app.SmartTubeApp)),
    );
    PlayerStateData state() => container.read(playerControllerProvider);

    // media_kit builds libmpv for the simulator with every audio output
    // disabled (`-Daudiounit=disabled -Dcoreaudio=disabled`); the device
    // slice has `-Daudiounit=enabled`. So on the simulator this one error
    // always fires, arrives before the first frame, and says nothing
    // about the app — waiting on `error != null` would end the wait
    // before playback ever had a chance to start.
    const simulatorHasNoAudioOutput = 'could not open/initialize audio device';
    bool fatalError() {
      // `error` carries the cause object now, not a message, so that the
      // watch page can tell an outage from a pulled video.
      final e = state().error;
      return e != null &&
          !e.toString().toLowerCase().contains(simulatorHasNoAudioOutput);
    }

    // 3. Position advancing is the honest signal — `isPlaying` can be
    //    true while the decoder is stuck.
    final settled = await pumpUntil(
      tester,
      () => state().position > Duration.zero || fatalError(),
      timeout: const Duration(seconds: 90),
    );

    final s = state();
    debugPrint('IOSTEST: settled=$settled isPlaying=${s.isPlaying} '
        'position=${s.position} duration=${s.duration} '
        'quality=${s.currentQualityLabel} error=${s.error}');
    debugPrint('IOSTEST: videoUrl=${s.currentVideoUrl}');
    debugPrint('IOSTEST: audioUrl=${s.currentAudioUrl}');

    expect(fatalError(), isFalse, reason: 'player reported: ${s.error}');
    expect(
      s.position,
      greaterThan(Duration.zero),
      reason: 'playback position never advanced past zero',
    );

    // Hold on the player long enough to photograph it from outside.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (i % 8 == 0) debugPrint('IOSTEST: holding, pos=${state().position}');
    }
    debugPrint('IOSTEST: final position=${state().position}');

    // 4. Adaptive playback hands mpv the video, then attaches the audio
    //    as an external track (`audio-add`). No audio device can be
    //    opened on the simulator, but the track still has to be demuxed
    //    and selected — if it is not, the video is silent on a real
    //    device too, and nothing here would have said so.
    final player = container.read(mediaPlayerProvider);
    final selected = player.state.track.audio;
    debugPrint('IOSTEST[audio]: selected=${selected.id} '
        'title=${selected.title} lang=${selected.language} '
        'available=${player.state.tracks.audio.length}');
    expect(selected.id, isNot('no'),
        reason: 'no audio track attached — this video would be silent');

    // 5. audio_service is what iOS reads to build the lock screen and
    //    Control Center. Empty here means background playback shows
    //    nothing to control.
    final handler = container.read(audioHandlerProvider);
    final nowPlaying = handler.mediaItem.value;
    final playback = handler.playbackState.value;
    debugPrint('IOSTEST[background]: nowPlaying=${nowPlaying?.title} '
        'artist=${nowPlaying?.artist} playing=${playback.playing} '
        'state=${playback.processingState} '
        'position=${playback.updatePosition}');

    expect(nowPlaying, isNotNull, reason: 'no Now Playing entry published');
    expect(playback.playing, isTrue);
    expect(
      playback.processingState,
      isNot(AudioProcessingState.idle),
      reason: 'audio_service never left idle',
    );
  });
}
