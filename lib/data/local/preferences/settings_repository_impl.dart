// ============================================================
// SettingsRepositoryImpl
// ============================================================
// يدير جميع إعدادات التطبيق (player, theme, sponsor, etc).
// يخزن في SharedPreferences (key-value).
// ============================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/content_filter.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/sponsor_segment.dart';

enum PlayerQuickAction {
  cast,
  pictureInPicture,
  subtitles,
  quality,
  speed,
  videoFit,
  stats,
  settings
}

class ChannelPlaybackPreferences {
  const ChannelPlaybackPreferences({
    this.speed,
    this.qualityHeight,
    this.subtitleCode,
    this.audioTrackId,
    this.subtitleScale,
    this.subtitleOffset,
    this.subtitleBackgroundOpacity,
    this.videoFit,
  });

  final double? speed;
  final int? qualityHeight;
  final String? subtitleCode;
  final String? audioTrackId;
  final double? subtitleScale;
  final double? subtitleOffset;
  final double? subtitleBackgroundOpacity;
  final String? videoFit;

  ChannelPlaybackPreferences copyWith({
    double? speed,
    int? qualityHeight,
    String? subtitleCode,
    String? audioTrackId,
    double? subtitleScale,
    double? subtitleOffset,
    double? subtitleBackgroundOpacity,
    String? videoFit,
    bool clearSubtitle = false,
  }) =>
      ChannelPlaybackPreferences(
        speed: speed ?? this.speed,
        qualityHeight: qualityHeight ?? this.qualityHeight,
        subtitleCode:
            clearSubtitle ? null : (subtitleCode ?? this.subtitleCode),
        audioTrackId: audioTrackId ?? this.audioTrackId,
        subtitleScale: subtitleScale ?? this.subtitleScale,
        subtitleOffset: subtitleOffset ?? this.subtitleOffset,
        subtitleBackgroundOpacity:
            subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
        videoFit: videoFit ?? this.videoFit,
      );

  Map<String, Object?> toJson() => {
        if (speed != null) 'speed': speed,
        if (qualityHeight != null) 'qualityHeight': qualityHeight,
        if (subtitleCode != null) 'subtitleCode': subtitleCode,
        if (audioTrackId != null) 'audioTrackId': audioTrackId,
        if (subtitleScale != null) 'subtitleScale': subtitleScale,
        if (subtitleOffset != null) 'subtitleOffset': subtitleOffset,
        if (subtitleBackgroundOpacity != null)
          'subtitleBackgroundOpacity': subtitleBackgroundOpacity,
        if (videoFit != null) 'videoFit': videoFit,
      };

  factory ChannelPlaybackPreferences.fromJson(Map<String, Object?> json) =>
      ChannelPlaybackPreferences(
        speed: (json['speed'] as num?)?.toDouble(),
        qualityHeight: (json['qualityHeight'] as num?)?.toInt(),
        subtitleCode: json['subtitleCode'] as String?,
        audioTrackId: json['audioTrackId'] as String?,
        subtitleScale: (json['subtitleScale'] as num?)?.toDouble(),
        subtitleOffset: (json['subtitleOffset'] as num?)?.toDouble(),
        subtitleBackgroundOpacity:
            (json['subtitleBackgroundOpacity'] as num?)?.toDouble(),
        videoFit: json['videoFit'] as String?,
      );
}

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

  /// Ordered shortcuts shown in the player's top bar. The settings gear
  /// is always retained as an escape hatch even if an old backup omits it.
  final List<PlayerQuickAction> playerQuickActions;

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
    this.playerQuickActions = const [
      PlayerQuickAction.cast,
      PlayerQuickAction.pictureInPicture,
      PlayerQuickAction.subtitles,
      PlayerQuickAction.settings,
    ],
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
    List<PlayerQuickAction>? playerQuickActions,
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
      playerQuickActions: playerQuickActions ?? this.playerQuickActions,
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
  static const _keyPlayerQuickActions = 'settings.player_quick_actions';
  static const _keyChannelPlayback = 'settings.channel_playback';

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
      playerQuickActions: _readPlayerQuickActions(),
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

  Future<void> setPlayerQuickActions(List<PlayerQuickAction> actions) async {
    final normalized = <PlayerQuickAction>[
      ...actions.where((action) => action != PlayerQuickAction.settings),
      PlayerQuickAction.settings,
    ];
    await _prefs.setStringList(
      _keyPlayerQuickActions,
      normalized.map((action) => action.name).toList(),
    );
  }

  Map<String, ChannelPlaybackPreferences> _readChannelPlaybackMap() {
    final raw = _prefs.getString(_keyChannelPlayback);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (channelId, value) => MapEntry(
          channelId,
          ChannelPlaybackPreferences.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  ChannelPlaybackPreferences? channelPlaybackPreferences(String channelId) =>
      channelId.isEmpty ? null : _readChannelPlaybackMap()[channelId];

  Future<void> saveChannelPlaybackPreferences(
    String channelId,
    ChannelPlaybackPreferences preferences,
  ) async {
    if (channelId.isEmpty) return;
    final current = _readChannelPlaybackMap()..[channelId] = preferences;
    // Keep the preference file bounded even after years of use.
    while (current.length > 500) {
      current.remove(current.keys.first);
    }
    await _prefs.setString(
      _keyChannelPlayback,
      jsonEncode(current.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  List<PlayerQuickAction> _readPlayerQuickActions() {
    final stored = _prefs.getStringList(_keyPlayerQuickActions);
    if (stored == null) {
      return const [
        PlayerQuickAction.cast,
        PlayerQuickAction.pictureInPicture,
        PlayerQuickAction.subtitles,
        PlayerQuickAction.settings,
      ];
    }
    final actions = stored
        .map(
          (name) => PlayerQuickAction.values
              .where((action) => action.name == name)
              .firstOrNull,
        )
        .whereType<PlayerQuickAction>()
        .toList();
    if (!actions.contains(PlayerQuickAction.settings)) {
      actions.add(PlayerQuickAction.settings);
    }
    return actions;
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
