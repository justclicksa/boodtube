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
import '../../domain/player/player_engine.dart';
import '../../services/backup_service.dart';
import '../../services/player_tuning.dart';
import '../screens/player/subtitle_styles.dart';
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

  Future<void> setAutoplayNext(bool enabled) async {
    state = state.copyWith(autoplayNext: enabled);
    await _repo.setAutoplayNext(enabled);
  }

  Future<void> setSkipShortsInAutoplay(bool enabled) async {
    state = state.copyWith(skipShortsInAutoplay: enabled);
    await _repo.setSkipShortsInAutoplay(enabled);
  }

  Future<void> setAutoQuality(bool enabled) async {
    state = state.copyWith(autoQuality: enabled);
    await _repo.setAutoQuality(enabled);
  }

  /// SmartTube's "Video buffer". The running player picks the change
  /// up through PlayerController.applyEngineTuning().
  Future<void> setBufferPreset(BufferPreset preset) async {
    state = state.copyWith(bufferPreset: preset);
    await _repo.setBufferPreset(preset);
  }

  Future<void> setKeepPitch(bool keepPitch) async {
    state = state.copyWith(keepPitch: keepPitch);
    await _repo.setKeepPitch(keepPitch);
  }

  Future<void> setAdaptiveStreaming(bool enabled) async {
    state = state.copyWith(adaptiveStreaming: enabled);
    await _repo.setAdaptiveStreaming(enabled);
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

  /// Which backend plays video. playerEngineProvider reads this once,
  /// so a change lands on the next app start rather than swapping the
  /// engine out from under a running playback.
  Future<void> setPlayerEngine(PlayerEngineKind engine) async {
    state = state.copyWith(playerEngine: engine);
    await _repo.setPlayerEngine(engine);
  }

  Future<void> setPictureInPictureEnabled(bool enabled) async {
    state = state.copyWith(pictureInPictureEnabled: enabled);
    await _repo.setPictureInPictureEnabled(enabled);
  }

  // ============================================================
  // Subtitles
  // ============================================================

  /// Caption look. Stored by name — see [SubtitleStyle] in
  /// presentation/screens/player/subtitle_styles.dart for the presets.
  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    state = state.copyWith(subtitleStyle: style.name);
    await _repo.setSubtitleStyle(style.name);
  }

  /// Language captions are auto-selected in for videos with no
  /// remembered subtitle. See [preferredSubtitleLanguageOptions].
  Future<void> setPreferredSubtitleLanguage(String language) async {
    state = state.copyWith(preferredSubtitleLanguage: language);
    await _repo.setPreferredSubtitleLanguage(language);
  }

  // ============================================================
  // SponsorBlock
  // ============================================================

  Future<void> setSponsorBlockEnabled(bool enabled) async {
    state = state.copyWith(sponsorBlockEnabled: enabled);
    await _repo.setSponsorBlockEnabled(enabled);
  }

  /// The coarse switch, kept for the settings screen: it moves every
  /// enabled category between skipping and offering a button.
  Future<void> setAutoSkipSponsors(bool enabled) async {
    await _repo.setAutoSkipSponsors(enabled);
    state = state.copyWith(sponsorActions: _repo.readSponsorActions());
  }

  Future<void> toggleSponsorCategory(
      SponsorCategory category, bool enabled) async {
    await _repo.toggleSponsorCategory(category, enabled);
    state = state.copyWith(sponsorActions: _repo.readSponsorActions());
  }

  /// The per-category action — SmartTube's skip / notify / ignore.
  Future<void> setSponsorAction(
    SponsorCategory category,
    SegmentAction action,
  ) async {
    final next = {...state.sponsorActions, category: action};
    state = state.copyWith(sponsorActions: next);
    await _repo.setSponsorAction(category, action);
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
