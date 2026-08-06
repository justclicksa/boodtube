// ============================================================
// SettingsProvider (StateNotifier)
// ============================================================
// يدير AppSettings (state + actions).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/preferences/settings_repository_impl.dart';
import '../../domain/entities/media_format.dart';
import '../../domain/entities/content_filter.dart';
import '../../domain/entities/sponsor_segment.dart';
import '../../services/backup_service.dart';
import 'repository_providers.dart';

// ============================================================
// SharedPreferences provider
// ============================================================

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main.dart');
});

// ============================================================
// SettingsRepository provider
// ============================================================

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

// ============================================================
// SettingsController (StateNotifier)
// ============================================================

class SettingsController extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsController(this._repo) : super(_repo.load());

  void reload() => state = _repo.load();

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repo.setThemeMode(mode);
  }

  // ============================================================
  // Player
  // ============================================================

  Future<void> setDefaultQuality(MediaFormatQuality quality) async {
    state = state.copyWith(defaultQuality: quality);
    await _repo.setDefaultQuality(quality);
  }

  Future<void> setDefaultSpeed(double speed) async {
    state = state.copyWith(defaultSpeed: speed);
    await _repo.setDefaultSpeed(speed);
  }

  Future<void> setBackgroundPlayback(bool enabled) async {
    state = state.copyWith(backgroundPlayback: enabled);
    await _repo.setBackgroundPlayback(enabled);
  }

  Future<void> setDoubleTapToSeek(bool enabled) async {
    state = state.copyWith(doubleTapToSeek: enabled);
    await _repo.setDoubleTapToSeek(enabled);
  }

  Future<void> toggleHiddenContent(HiddenContent rule, bool hide) async {
    final current = {...state.hiddenContent};
    if (hide) {
      current.add(rule);
    } else {
      current.remove(rule);
    }
    state = state.copyWith(hiddenContent: current);
    await _repo.toggleHiddenContent(rule, hide);
  }

  Future<void> blockChannel(String channelId) async {
    state = state.copyWith(
      blockedChannelIds: {...state.blockedChannelIds, channelId},
    );
    await _repo.blockChannel(channelId);
  }

  Future<void> unblockChannel(String channelId) async {
    state = state.copyWith(
      blockedChannelIds: {...state.blockedChannelIds}..remove(channelId),
    );
    await _repo.unblockChannel(channelId);
  }

  Future<void> setClickbaitThumbnail(ClickbaitThumbnail value) async {
    state = state.copyWith(clickbaitThumbnail: value);
    await _repo.setClickbaitThumbnail(value);
  }

  Future<void> setDeArrowEnabled(bool enabled) async {
    state = state.copyWith(deArrowEnabled: enabled);
    await _repo.setDeArrowEnabled(enabled);
  }

  Future<void> setShowRemainingTime(bool enabled) async {
    state = state.copyWith(showRemainingTime: enabled);
    await _repo.setShowRemainingTime(enabled);
  }

  Future<void> setPlayerQuickActions(List<PlayerQuickAction> actions) async {
    final normalized = <PlayerQuickAction>[
      ...actions.where((action) => action != PlayerQuickAction.settings),
      PlayerQuickAction.settings,
    ];
    state = state.copyWith(playerQuickActions: normalized);
    await _repo.setPlayerQuickActions(normalized);
  }

  Future<void> setPictureInPictureEnabled(bool enabled) async {
    state = state.copyWith(pictureInPictureEnabled: enabled);
    await _repo.setPictureInPictureEnabled(enabled);
  }

  // ============================================================
  // SponsorBlock
  // ============================================================

  Future<void> setSponsorBlockEnabled(bool enabled) async {
    state = state.copyWith(sponsorBlockEnabled: enabled);
    await _repo.setSponsorBlockEnabled(enabled);
  }

  Future<void> setAutoSkipSponsors(bool enabled) async {
    state = state.copyWith(autoSkipSponsors: enabled);
    await _repo.setAutoSkipSponsors(enabled);
  }

  Future<void> toggleSponsorCategory(
      SponsorCategory category, bool enabled) async {
    final current = {...state.sponsorCategories};
    if (enabled) {
      current.add(category);
    } else {
      current.remove(category);
    }
    state = state.copyWith(sponsorCategories: current);
    await _repo.toggleSponsorCategory(category, enabled);
  }

  // ============================================================
  // General
  // ============================================================

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await _repo.setLanguage(language);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _repo.setNotificationsEnabled(enabled);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});
