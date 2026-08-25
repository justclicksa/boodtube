import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/data/local/preferences/settings_repository_impl.dart';
import 'package:smarttube_poc/services/player_tuning.dart';

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
        audioDelayMs: -150,
      ),
    );

    final restored = repository.channelPlaybackPreferences('UC-test');
    expect(restored?.speed, 1.5);
    expect(restored?.qualityHeight, 720);
    expect(restored?.subtitleCode, 'ar');
    expect(restored?.audioTrackId, 'original');
    expect(restored?.videoFit, 'fitWidth');
    expect(restored?.audioDelayMs, -150);
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

  test("player tweaks default to SmartTube's own defaults", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences).load();

    expect(settings.bufferPreset, BufferPreset.medium);
    expect(settings.keepPitch, isTrue);
  });

  test('player tweaks survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.setBufferPreset(BufferPreset.highest);
    await repository.setKeepPitch(false);

    // A second repository over the same store stands in for a restart.
    final reloaded = SettingsRepository(preferences).load();
    expect(reloaded.bufferPreset, BufferPreset.highest);
    expect(reloaded.keepPitch, isFalse);
  });

  test('an unknown stored preset falls back to the default', () async {
    SharedPreferences.setMockInitialValues({
      'settings.buffer_preset': 'gigantic',
    });
    final preferences = await SharedPreferences.getInstance();

    expect(
      SettingsRepository(preferences).load().bufferPreset,
      BufferPreset.medium,
    );
  });

  group('autoplay and auto quality', () {
    test('both start on, the way YouTube behaves out of the box', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();

      final settings = SettingsRepository(preferences).load();
      expect(settings.autoplayNext, isTrue);
      expect(settings.autoQuality, isTrue);
    });

    test('turning them off survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final repository = SettingsRepository(preferences);

      await repository.setAutoplayNext(false);
      await repository.setAutoQuality(false);

      expect(repository.load().autoplayNext, isFalse);
      expect(repository.load().autoQuality, isFalse);

      // The keys a backup carries; renaming one silently drops the
      // setting from every existing backup file.
      expect(preferences.getBool('settings.autoplay_next'), isFalse);
      expect(preferences.getBool('settings.auto_quality'), isFalse);

      await repository.setAutoplayNext(true);
      expect(repository.load().autoplayNext, isTrue);
      expect(
        repository.load().autoQuality,
        isFalse,
        reason: 'the two settings are independent',
      );
    });
  });

  group('ChannelPlaybackPreferences.copyWith', () {
    const pinned = ChannelPlaybackPreferences(
      speed: 1.5,
      qualityHeight: 1080,
      subtitleCode: 'ar',
      videoFit: 'zoom',
    );

    test('clearQualityHeight unpins the resolution and nothing else', () {
      final cleared = pinned.copyWith(clearQualityHeight: true);

      expect(cleared.qualityHeight, isNull);
      expect(cleared.speed, 1.5);
      expect(cleared.subtitleCode, 'ar');
      expect(cleared.videoFit, 'zoom');
    });

    test('clearQualityHeight wins over a height passed alongside it', () {
      // Callers that clear are saying "let auto decide"; a stale height
      // arriving in the same call must not put the pin back.
      expect(
        pinned.copyWith(qualityHeight: 720, clearQualityHeight: true)
            .qualityHeight,
        isNull,
      );
    });

    test('an untouched height is kept', () {
      expect(pinned.copyWith(speed: 2).qualityHeight, 1080);
      expect(pinned.copyWith(qualityHeight: 720).qualityHeight, 720);
    });

    test('a cleared height is not written back on save', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final repository = SettingsRepository(preferences);

      await repository.saveChannelPlaybackPreferences('UC-a', pinned);
      await repository.saveChannelPlaybackPreferences(
        'UC-a',
        repository
            .channelPlaybackPreferences('UC-a')!
            .copyWith(clearQualityHeight: true),
      );

      final stored = repository.channelPlaybackPreferences('UC-a');
      expect(stored?.qualityHeight, isNull);
      expect(stored?.speed, 1.5);
    });
  });
}
