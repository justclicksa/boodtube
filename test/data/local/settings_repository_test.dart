import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/data/local/preferences/settings_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remembers playback choices per channel', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.saveChannelPlaybackPreferences(
      'UC-test',
      const ChannelPlaybackPreferences(
        speed: 1.5,
        qualityHeight: 720,
        subtitleCode: 'ar',
        audioTrackId: 'original',
        videoFit: 'fitWidth',
      ),
    );

    final restored = repository.channelPlaybackPreferences('UC-test');
    expect(restored?.speed, 1.5);
    expect(restored?.qualityHeight, 720);
    expect(restored?.subtitleCode, 'ar');
    expect(restored?.audioTrackId, 'original');
    expect(restored?.videoFit, 'fitWidth');
  });

  test('remembers the video transform per channel', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.saveChannelPlaybackPreferences(
      'UC-transform',
      const ChannelPlaybackPreferences(videoAspect: 'r16_9', zoomPercent: 150),
    );

    final restored = repository.channelPlaybackPreferences('UC-transform');
    expect(restored?.videoAspect, 'r16_9');
    expect(restored?.zoomPercent, 150);
    expect(restored?.subtitlesDisabled, isFalse);
  });

  test('tells "captions off" apart from "never chose captions"', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    // Switching captions off has to survive the round trip, otherwise the
    // default-subtitle-language setting turns them straight back on.
    await repository.saveChannelPlaybackPreferences(
      'UC-silent',
      const ChannelPlaybackPreferences(subtitleCode: 'en')
          .copyWith(clearSubtitle: true),
    );

    final off = repository.channelPlaybackPreferences('UC-silent');
    expect(off?.subtitleCode, isNull);
    expect(off?.subtitlesDisabled, isTrue);

    // Choosing one again lifts the flag.
    await repository.saveChannelPlaybackPreferences(
      'UC-silent',
      off!.copyWith(subtitleCode: 'ar'),
    );
    final on = repository.channelPlaybackPreferences('UC-silent');
    expect(on?.subtitleCode, 'ar');
    expect(on?.subtitlesDisabled, isFalse);
  });

  test('persists the subtitle style and default caption language', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    expect(repository.load().subtitleStyle, 'defaultStyle');
    expect(repository.load().preferredSubtitleLanguage, 'app');

    await repository.setSubtitleStyle('yellowOnBlack');
    await repository.setPreferredSubtitleLanguage('ar');

    expect(repository.load().subtitleStyle, 'yellowOnBlack');
    expect(repository.load().preferredSubtitleLanguage, 'ar');
  });

  test('always retains settings in player shortcuts', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.setPlayerQuickActions(const [PlayerQuickAction.cast]);

    expect(
      repository.load().playerQuickActions,
      const [PlayerQuickAction.cast, PlayerQuickAction.settings],
    );
  });
}
