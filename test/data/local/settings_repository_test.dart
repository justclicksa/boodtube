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
