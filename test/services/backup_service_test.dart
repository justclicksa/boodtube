// ============================================================
// Backup round-trip for the settings half of a backup file
// ============================================================
// The database half needs a real sqlite connection; this covers what
// [BackupService] does with SharedPreferences, through the same JSON
// encode/decode a real backup file goes through.
// ============================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/data/local/database/app_database.dart';
import 'package:smarttube_poc/data/local/preferences/settings_repository_impl.dart';
import 'package:smarttube_poc/services/backup_service.dart';

/// Empties the store and hands back a handle onto it.
///
/// SharedPreferences is a process-wide singleton under the test mock, so
/// this returns the same object every time — "the device the backup came
/// from" and "the device it is restored onto" are the same handle, one
/// after the other. Exporting to a plain Map first is what keeps the two
/// halves honest.
Future<SharedPreferences> _emptyStore([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(Map.of(initial));
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  return preferences;
}

/// Constructing the real [AppDatabase] opens a sqlite file through
/// path_provider, which no `flutter test` process has. The settings half
/// of a backup never asks the database anything, so this stands in for
/// it and says so loudly if that ever stops being true.
class _NoDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        'the settings half of a backup does not touch the database',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A backup file's settings section, after a JSON round-trip — which
  /// is where an `int` can come back as a `double` and a `List<String>`
  /// as a `List<dynamic>`.
  Map<String, Object?> exported(SharedPreferences preferences) {
    final service = BackupService(_NoDatabase(), preferences);
    final encoded = jsonEncode(service.exportSettings());
    return Map<String, Object?>.from(jsonDecode(encoded) as Map);
  }

  test('the new player settings survive a backup and a restore', () async {
    final source = await _emptyStore();
    final sourceRepo = SettingsRepository(source);

    // Both default to true, so flip them: a restore that quietly did
    // nothing would still look correct against the defaults.
    await sourceRepo.setAutoplayNext(false);
    await sourceRepo.setAutoQuality(false);
    await sourceRepo.setShowRemainingTime(true);

    final settings = exported(source);
    expect(settings, containsPair('settings.autoplay_next', false));
    expect(settings, containsPair('settings.auto_quality', false));

    final target = await _emptyStore();
    await BackupService(_NoDatabase(), target).restoreSettings(settings);

    final restored = SettingsRepository(target).load();
    expect(restored.autoplayNext, isFalse);
    expect(restored.autoQuality, isFalse);
    expect(restored.showRemainingTime, isTrue);
  });

  test('per-channel playback preferences round-trip', () async {
    final source = await _emptyStore();
    final sourceRepo = SettingsRepository(source);
    await sourceRepo.saveChannelPlaybackPreferences(
      'UC-backup',
      const ChannelPlaybackPreferences(
        speed: 1.25,
        qualityHeight: 1080,
        subtitleCode: 'ar',
        videoFit: 'zoom',
      ),
    );

    final settings = exported(source);
    final target = await _emptyStore();
    await BackupService(_NoDatabase(), target).restoreSettings(settings);

    final restored =
        SettingsRepository(target).channelPlaybackPreferences('UC-backup');
    expect(restored?.speed, 1.25);
    expect(restored?.qualityHeight, 1080);
    expect(restored?.subtitleCode, 'ar');
    expect(restored?.videoFit, 'zoom');
  });

  test('a channel handed back to auto quality stays that way', () async {
    // clearQualityHeight drops the key from the stored JSON rather than
    // writing a null, so the restore has nothing to carry over either.
    final source = await _emptyStore();
    final sourceRepo = SettingsRepository(source);
    await sourceRepo.saveChannelPlaybackPreferences(
      'UC-backup',
      const ChannelPlaybackPreferences(speed: 2, qualityHeight: 720),
    );
    await sourceRepo.saveChannelPlaybackPreferences(
      'UC-backup',
      sourceRepo
          .channelPlaybackPreferences('UC-backup')!
          .copyWith(clearQualityHeight: true),
    );

    final settings = exported(source);
    expect(
      settings['settings.channel_playback'],
      isNot(contains('qualityHeight')),
    );

    final target = await _emptyStore();
    await BackupService(_NoDatabase(), target).restoreSettings(settings);

    final restored =
        SettingsRepository(target).channelPlaybackPreferences('UC-backup');
    expect(restored?.qualityHeight, isNull);
    expect(restored?.speed, 2, reason: 'the rest of the channel is intact');
  });

  test('a backup written before these settings existed keeps the '
      'defaults', () async {
    final source = await _emptyStore({'settings.dearrow': true});
    final settings = exported(source);
    final target = await _emptyStore();
    await BackupService(_NoDatabase(), target).restoreSettings(settings);

    final restored = SettingsRepository(target).load();
    expect(restored.deArrowEnabled, isTrue);
    expect(restored.autoplayNext, isTrue);
    expect(restored.autoQuality, isTrue);
  });

  test('only the settings namespace is exported', () async {
    final preferences = await _emptyStore({
      'settings.dearrow': true,
      'auth.token': 'secret',
    });
    expect(exported(preferences).keys, ['settings.dearrow']);
  });
}
