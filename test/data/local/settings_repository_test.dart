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
}
