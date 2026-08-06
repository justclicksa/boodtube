// ============================================================
// SettingsRepositoryImpl
// ============================================================
// يدير جميع إعدادات التطبيق (player, theme, sponsor, etc).
// يخزن في SharedPreferences (key-value).
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/content_filter.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/sponsor_segment.dart';

class AppSettings {
  final AppThemeMode themeMode;
  final MediaFormatQuality defaultQuality;
  final double defaultSpeed;
  final bool backgroundPlayback;
  final bool sponsorBlockEnabled;
  final Set<SponsorCategory> sponsorCategories;
  final bool autoSkipSponsors;
  final String language; // 'en', 'ar'
  final bool notificationsEnabled;
  final bool pictureInPictureEnabled;
  final bool doubleTapToSeek;

  /// Feeds to filter — SmartTube's "Hide content".
  final Set<HiddenContent> hiddenContent;

  /// Channels whose videos never appear in any feed.
  final Set<String> blockedChannelIds;

  /// Replace uploader thumbnails with an auto-extracted frame.
  final ClickbaitThumbnail clickbaitThumbnail;

  /// Show community titles/thumbnails from DeArrow.
  final bool deArrowEnabled;

  /// Show the time left instead of the total duration.
  final bool showRemainingTime;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.defaultQuality = MediaFormatQuality.highest,
    this.defaultSpeed = 1.0,
    this.backgroundPlayback = true,
    this.sponsorBlockEnabled = true,
    this.sponsorCategories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
      SponsorCategory.selfPromo,
      SponsorCategory.interaction,
    },
    this.autoSkipSponsors = false,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.pictureInPictureEnabled = true,
    this.doubleTapToSeek = true,
    this.hiddenContent = ContentFilter.defaultHidden,
    this.blockedChannelIds = const {},
    this.clickbaitThumbnail = ClickbaitThumbnail.original,
    this.deArrowEnabled = false,
    this.showRemainingTime = false,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    MediaFormatQuality? defaultQuality,
    double? defaultSpeed,
    bool? backgroundPlayback,
    bool? sponsorBlockEnabled,
    Set<SponsorCategory>? sponsorCategories,
    bool? autoSkipSponsors,
    String? language,
    bool? notificationsEnabled,
    bool? pictureInPictureEnabled,
    bool? doubleTapToSeek,
    Set<HiddenContent>? hiddenContent,
    Set<String>? blockedChannelIds,
    ClickbaitThumbnail? clickbaitThumbnail,
    bool? deArrowEnabled,
    bool? showRemainingTime,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
      sponsorCategories: sponsorCategories ?? this.sponsorCategories,
      autoSkipSponsors: autoSkipSponsors ?? this.autoSkipSponsors,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      pictureInPictureEnabled:
          pictureInPictureEnabled ?? this.pictureInPictureEnabled,
      doubleTapToSeek: doubleTapToSeek ?? this.doubleTapToSeek,
      hiddenContent: hiddenContent ?? this.hiddenContent,
      blockedChannelIds: blockedChannelIds ?? this.blockedChannelIds,
      clickbaitThumbnail: clickbaitThumbnail ?? this.clickbaitThumbnail,
      deArrowEnabled: deArrowEnabled ?? this.deArrowEnabled,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
    );
  }
}

/// Local theme mode (لا تتعارض مع Flutter's ThemeMode من material.dart)
enum AppThemeMode { system, light, dark }

class SettingsRepository {
  static const _keyThemeMode = 'settings.theme_mode';
  static const _keyDefaultQuality = 'settings.default_quality';
  static const _keyDefaultSpeed = 'settings.default_speed';
  static const _keyBackgroundPlayback = 'settings.background_playback';
  static const _keySponsorBlockEnabled = 'settings.sponsor_block_enabled';
  static const _keySponsorCategories = 'settings.sponsor_categories';
  static const _keyAutoSkipSponsors = 'settings.auto_skip_sponsors';
  static const _keyLanguage = 'settings.language';
  static const _keyNotificationsEnabled = 'settings.notifications';
  static const _keyPiP = 'settings.pip';
  static const _keyDoubleTapToSeek = 'settings.double_tap_to_seek';
  static const _keyHiddenContent = 'settings.hidden_content';
  static const _keyBlockedChannels = 'settings.blocked_channels';
  static const _keyClickbait = 'settings.clickbait_thumbnail';
  static const _keyDeArrow = 'settings.dearrow';
  static const _keyRemainingTime = 'settings.remaining_time';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  AppSettings load() {
    return AppSettings(
      themeMode: _readThemeMode(),
      defaultQuality: _readQuality(),
      defaultSpeed: _prefs.getDouble(_keyDefaultSpeed) ?? 1.0,
      backgroundPlayback: _prefs.getBool(_keyBackgroundPlayback) ?? true,
      sponsorBlockEnabled: _prefs.getBool(_keySponsorBlockEnabled) ?? true,
      sponsorCategories: _readSponsorCategories(),
      autoSkipSponsors: _prefs.getBool(_keyAutoSkipSponsors) ?? false,
      language: _prefs.getString(_keyLanguage) ?? 'en',
      notificationsEnabled: _prefs.getBool(_keyNotificationsEnabled) ?? true,
      pictureInPictureEnabled: _prefs.getBool(_keyPiP) ?? true,
      doubleTapToSeek: _prefs.getBool(_keyDoubleTapToSeek) ?? true,
      hiddenContent: _readHiddenContent(),
      blockedChannelIds:
          (_prefs.getStringList(_keyBlockedChannels) ?? const []).toSet(),
      clickbaitThumbnail: ClickbaitThumbnail.values.firstWhere(
        (t) => t.name == _prefs.getString(_keyClickbait),
        orElse: () => ClickbaitThumbnail.original,
      ),
      deArrowEnabled: _prefs.getBool(_keyDeArrow) ?? false,
      showRemainingTime: _prefs.getBool(_keyRemainingTime) ?? false,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setDefaultQuality(MediaFormatQuality quality) async {
    await _prefs.setString(_keyDefaultQuality, quality.name);
  }

  Future<void> setDefaultSpeed(double speed) async {
    await _prefs.setDouble(_keyDefaultSpeed, speed);
  }

  Future<void> setBackgroundPlayback(bool enabled) async {
    await _prefs.setBool(_keyBackgroundPlayback, enabled);
  }

  Future<void> setSponsorBlockEnabled(bool enabled) async {
    await _prefs.setBool(_keySponsorBlockEnabled, enabled);
  }

  Future<void> setSponsorCategories(Set<SponsorCategory> categories) async {
    final values = categories.map((c) => c.name).join(',');
    await _prefs.setString(_keySponsorCategories, values);
  }

  Future<void> toggleSponsorCategory(
      SponsorCategory category, bool enabled) async {
    // FIXED: create new mutable set (not const)
    final current = {..._readSponsorCategories()};
    if (enabled) {
      current.add(category);
    } else {
      current.remove(category);
    }
    await setSponsorCategories(current);
  }

  Future<void> setAutoSkipSponsors(bool enabled) async {
    await _prefs.setBool(_keyAutoSkipSponsors, enabled);
  }

  Future<void> setLanguage(String language) async {
    await _prefs.setString(_keyLanguage, language);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<void> setPictureInPictureEnabled(bool enabled) async {
    await _prefs.setBool(_keyPiP, enabled);
  }

  Future<void> setDoubleTapToSeek(bool enabled) async {
    await _prefs.setBool(_keyDoubleTapToSeek, enabled);
  }

  Future<void> toggleHiddenContent(HiddenContent rule, bool hide) async {
    final current = {..._readHiddenContent()};
    if (hide) {
      current.add(rule);
    } else {
      current.remove(rule);
    }
    // An empty list still means "nothing hidden" — store a marker so it
    // is not mistaken for "never configured" and reset to the defaults.
    await _prefs.setStringList(
      _keyHiddenContent,
      current.isEmpty ? ['none'] : current.map((r) => r.name).toList(),
    );
  }

  Future<void> blockChannel(String channelId) async {
    final current = (_prefs.getStringList(_keyBlockedChannels) ?? const [])
        .toSet()
      ..add(channelId);
    await _prefs.setStringList(_keyBlockedChannels, current.toList());
  }

  Future<void> unblockChannel(String channelId) async {
    final current = (_prefs.getStringList(_keyBlockedChannels) ?? const [])
        .toSet()
      ..remove(channelId);
    await _prefs.setStringList(_keyBlockedChannels, current.toList());
  }

  Future<void> setClickbaitThumbnail(ClickbaitThumbnail value) async {
    await _prefs.setString(_keyClickbait, value.name);
  }

  Future<void> setDeArrowEnabled(bool enabled) async {
    await _prefs.setBool(_keyDeArrow, enabled);
  }

  Future<void> setShowRemainingTime(bool enabled) async {
    await _prefs.setBool(_keyRemainingTime, enabled);
  }

  Set<HiddenContent> _readHiddenContent() {
    final stored = _prefs.getStringList(_keyHiddenContent);
    if (stored == null) return ContentFilter.defaultHidden;
    if (stored.length == 1 && stored.first == 'none') return const {};
    return stored
        .map(
          (name) => HiddenContent.values
              .where((rule) => rule.name == name)
              .firstOrNull,
        )
        .whereType<HiddenContent>()
        .toSet();
  }

  // ============================================================
  // Private helpers
  // ============================================================

  AppThemeMode _readThemeMode() {
    final value = _prefs.getString(_keyThemeMode);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppThemeMode.dark,
    );
  }

  MediaFormatQuality _readQuality() {
    final value = _prefs.getString(_keyDefaultQuality);
    return MediaFormatQuality.values.firstWhere(
      (q) => q.name == value,
      // Keep in sync with AppSettings.defaultQuality's default.
      orElse: () => MediaFormatQuality.highest,
    );
  }

  Set<SponsorCategory> _readSponsorCategories() {
    final value = _prefs.getString(_keySponsorCategories);
    if (value == null || value.isEmpty) {
      return const {
        SponsorCategory.sponsor,
        SponsorCategory.intro,
        SponsorCategory.outro,
        SponsorCategory.selfPromo,
        SponsorCategory.interaction,
      };
    }
    return value
        .split(',')
        .map((s) => SponsorCategory.values.firstWhere(
              (c) => c.name == s,
              orElse: () => SponsorCategory.sponsor,
            ))
        .toSet();
  }
}
