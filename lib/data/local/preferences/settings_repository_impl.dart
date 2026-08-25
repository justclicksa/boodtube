// ============================================================
// SettingsRepositoryImpl
// ============================================================
// يدير جميع إعدادات التطبيق (player, theme, sponsor, etc).
// يخزن في SharedPreferences (key-value).
// ============================================================

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/content_filter.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/sponsor_segment.dart';
import '../../../services/player_tuning.dart';
import '../../../domain/player/player_engine.dart';

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
    this.audioDelayMs,
    this.videoAspect,
    this.zoomPercent,
    this.subtitlesDisabled = false,
  });

  final double? speed;
  final int? qualityHeight;
  final String? subtitleCode;
  final String? audioTrackId;
  final double? subtitleScale;
  final double? subtitleOffset;
  final double? subtitleBackgroundOpacity;
  final String? videoFit;

  /// SmartTube's audio shift, in milliseconds, for this channel.
  final int? audioDelayMs;
  /// Name of a `VideoAspect` value — the forced display ratio.
  final String? videoAspect;

  /// 100–300. Rotation and flip are deliberately absent: those are a
  /// one-off fix for a single sideways upload, not a channel habit.
  final double? zoomPercent;

  /// The viewer switched captions off for this channel on purpose.
  ///
  /// Distinct from a null [subtitleCode], which only means "never
  /// chose one" — without the distinction the default-subtitle-language
  /// setting would switch captions straight back on for a channel the
  /// viewer had just silenced.
  final bool subtitlesDisabled;

  ChannelPlaybackPreferences copyWith({
    double? speed,
    int? qualityHeight,
    String? subtitleCode,
    String? audioTrackId,
    double? subtitleScale,
    double? subtitleOffset,
    double? subtitleBackgroundOpacity,
    String? videoFit,
    int? audioDelayMs,
    String? videoAspect,
    double? zoomPercent,
    bool clearSubtitle = false,
    bool clearQualityHeight = false,
  }) =>
      ChannelPlaybackPreferences(
        speed: speed ?? this.speed,
        qualityHeight:
            clearQualityHeight ? null : (qualityHeight ?? this.qualityHeight),
        subtitleCode:
            clearSubtitle ? null : (subtitleCode ?? this.subtitleCode),
        audioTrackId: audioTrackId ?? this.audioTrackId,
        subtitleScale: subtitleScale ?? this.subtitleScale,
        subtitleOffset: subtitleOffset ?? this.subtitleOffset,
        subtitleBackgroundOpacity:
            subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
        videoFit: videoFit ?? this.videoFit,
        audioDelayMs: audioDelayMs ?? this.audioDelayMs,
        videoAspect: videoAspect ?? this.videoAspect,
        zoomPercent: zoomPercent ?? this.zoomPercent,
        subtitlesDisabled: clearSubtitle
            ? true
            : (subtitleCode != null ? false : subtitlesDisabled),
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
        if (audioDelayMs != null) 'audioDelayMs': audioDelayMs,
        if (videoAspect != null) 'videoAspect': videoAspect,
        if (zoomPercent != null) 'zoomPercent': zoomPercent,
        if (subtitlesDisabled) 'subtitlesDisabled': true,
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
        audioDelayMs: (json['audioDelayMs'] as num?)?.toInt(),
        videoAspect: json['videoAspect'] as String?,
        zoomPercent: (json['zoomPercent'] as num?)?.toDouble(),
        subtitlesDisabled: json['subtitlesDisabled'] as bool? ?? false,
      );
}

class AppSettings {
  final AppThemeMode themeMode;
  final MediaFormatQuality defaultQuality;
  final double defaultSpeed;
  final bool backgroundPlayback;
  final bool sponsorBlockEnabled;

  /// What playback does per SponsorBlock category — SmartTube's
  /// per-category action instead of one global auto-skip switch.
  final Map<SponsorCategory, SegmentAction> sponsorActions;

  /// Categories that are acted on at all. Kept as a derived view so
  /// the older "tick the categories you want" UI still reads naturally.
  Set<SponsorCategory> get sponsorCategories => {
        for (final entry in sponsorActions.entries)
          if (entry.value != SegmentAction.none) entry.key,
      };

  /// True when at least one enabled category skips outright. The old
  /// global switch, derived rather than stored.
  bool get autoSkipSponsors =>
      sponsorActions.values.any((a) => a == SegmentAction.skip);

  /// Categories to request from the API: everything acted on, plus the
  /// two informational ones the player surfaces on its own.
  Set<SponsorCategory> get sponsorFetchCategories => {
        ...sponsorCategories,
        SponsorCategory.highlight,
        SponsorCategory.exclusiveAccess,
      };

  SegmentAction actionFor(SponsorCategory category) =>
      resolveSegmentAction(sponsorActions, category);
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

  /// When the queue is empty, continue with the first "Up next" video.
  final bool autoplayNext;

  /// Never continue automatically into a Short. A Short that follows a
  /// long video reads as the player having jumped somewhere else, so
  /// autoplay passes over them by default.
  final bool skipShortsInAutoplay;

  /// Pick the opening resolution from measured throughput instead of the
  /// fixed [defaultQuality] cap, and step down on stalls.
  final bool autoQuality;

  /// How far ahead the player buffers — SmartTube's "Video buffer".
  final BufferPreset bufferPreset;

  /// Keep the voice pitch when the playback speed is not 1x. Off is
  /// SmartTube's "pitch effect", where pitch rides the speed.
  final bool keepPitch;
  /// Hand the player a client-built DASH manifest instead of two
  /// separate progressive URLs, so ffmpeg muxes video and audio itself.
  /// Off by default: the progressive path is the proven one.
  final bool adaptiveStreaming;

  /// Ordered shortcuts shown in the player's top bar. The settings gear
  /// is always retained as an escape hatch even if an old backup omits it.
  final List<PlayerQuickAction> playerQuickActions;

  /// Name of a `SubtitleStyle` preset. Stored as a string so the data
  /// layer keeps no dependency on the presentation enum, the same way
  /// [ChannelPlaybackPreferences.videoFit] is.
  final String subtitleStyle;

  /// Language captions are switched on in when a video has no remembered
  /// choice — `'app'` follows the app language, `'off'` never picks one.
  final String preferredSubtitleLanguage;
  /// Which backend decodes video. The constructor default is libmpv
  /// because that is the one every platform has; [SettingsRepository
  /// .load] substitutes [defaultPlayerEngine] for an untouched install,
  /// which is how Android ends up on ExoPlayer without this class
  /// having to know what it is running on.
  final PlayerEngineKind playerEngine;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.defaultQuality = MediaFormatQuality.highest,
    this.defaultSpeed = 1.0,
    this.backgroundPlayback = true,
    this.sponsorBlockEnabled = true,
    this.sponsorActions = const {
      SponsorCategory.sponsor: SegmentAction.skip,
      SponsorCategory.intro: SegmentAction.skip,
      SponsorCategory.outro: SegmentAction.skip,
      SponsorCategory.selfPromo: SegmentAction.skip,
      SponsorCategory.interaction: SegmentAction.skip,
      SponsorCategory.preview: SegmentAction.skip,
      SponsorCategory.musicOffTopic: SegmentAction.skip,
      SponsorCategory.filler: SegmentAction.none,
    },
    this.language = 'en',
    this.notificationsEnabled = true,
    this.pictureInPictureEnabled = true,
    this.doubleTapToSeek = true,
    this.hiddenContent = ContentFilter.defaultHidden,
    this.blockedChannelIds = const {},
    this.clickbaitThumbnail = ClickbaitThumbnail.original,
    this.deArrowEnabled = false,
    this.showRemainingTime = false,
    this.autoplayNext = true,
    this.skipShortsInAutoplay = true,
    this.autoQuality = true,
    this.bufferPreset = BufferPreset.medium,
    this.keepPitch = true,
    this.adaptiveStreaming = false,
    this.playerQuickActions = const [
      PlayerQuickAction.cast,
      PlayerQuickAction.pictureInPicture,
      PlayerQuickAction.subtitles,
      PlayerQuickAction.settings,
    ],
    this.subtitleStyle = 'defaultStyle',
    this.preferredSubtitleLanguage = 'app',
    this.playerEngine = PlayerEngineKind.mpv,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    MediaFormatQuality? defaultQuality,
    double? defaultSpeed,
    bool? backgroundPlayback,
    bool? sponsorBlockEnabled,
    Map<SponsorCategory, SegmentAction>? sponsorActions,
    String? language,
    bool? notificationsEnabled,
    bool? pictureInPictureEnabled,
    bool? doubleTapToSeek,
    Set<HiddenContent>? hiddenContent,
    Set<String>? blockedChannelIds,
    ClickbaitThumbnail? clickbaitThumbnail,
    bool? deArrowEnabled,
    bool? showRemainingTime,
    bool? autoplayNext,
    bool? skipShortsInAutoplay,
    bool? autoQuality,
    BufferPreset? bufferPreset,
    bool? keepPitch,
    bool? adaptiveStreaming,
    List<PlayerQuickAction>? playerQuickActions,
    String? subtitleStyle,
    String? preferredSubtitleLanguage,
    PlayerEngineKind? playerEngine,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
      sponsorActions: sponsorActions ?? this.sponsorActions,
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
      autoplayNext: autoplayNext ?? this.autoplayNext,
      skipShortsInAutoplay: skipShortsInAutoplay ?? this.skipShortsInAutoplay,
      autoQuality: autoQuality ?? this.autoQuality,
      bufferPreset: bufferPreset ?? this.bufferPreset,
      keepPitch: keepPitch ?? this.keepPitch,
      adaptiveStreaming: adaptiveStreaming ?? this.adaptiveStreaming,
      playerQuickActions: playerQuickActions ?? this.playerQuickActions,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      playerEngine: playerEngine ?? this.playerEngine,
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
  static const _keySponsorActions = 'settings.sponsor_actions';
  static const _keyLanguage = 'settings.language';
  static const _keyNotificationsEnabled = 'settings.notifications';
  static const _keyPiP = 'settings.pip';
  static const _keyDoubleTapToSeek = 'settings.double_tap_to_seek';
  static const _keyHiddenContent = 'settings.hidden_content';
  static const _keyBlockedChannels = 'settings.blocked_channels';
  static const _keyClickbait = 'settings.clickbait_thumbnail';
  static const _keyDeArrow = 'settings.dearrow';
  static const _keyRemainingTime = 'settings.remaining_time';
  static const _keyAutoplayNext = 'settings.autoplay_next';
  static const _keySkipShortsInAutoplay = 'settings.skip_shorts_autoplay';
  static const _keyAutoQuality = 'settings.auto_quality';
  static const _keyAdaptiveStreaming = 'settings.adaptive_streaming';
  static const _keyPlayerQuickActions = 'settings.player_quick_actions';
  static const _keyBufferPreset = 'settings.buffer_preset';
  static const _keyKeepPitch = 'settings.keep_pitch';
  static const _keyPlayerEngine = 'settings.player_engine';
  static const _keyChannelPlayback = 'settings.channel_playback';
  static const _keySubtitleStyle = 'settings.subtitle_style';
  static const _keyPreferredSubtitleLanguage =
      'settings.preferred_subtitle_language';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  AppSettings load() {
    return AppSettings(
      themeMode: _readThemeMode(),
      defaultQuality: _readQuality(),
      defaultSpeed: _prefs.getDouble(_keyDefaultSpeed) ?? 1.0,
      backgroundPlayback: _prefs.getBool(_keyBackgroundPlayback) ?? true,
      sponsorBlockEnabled: _prefs.getBool(_keySponsorBlockEnabled) ?? true,
      sponsorActions: readSponsorActions(),
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
      autoplayNext: _prefs.getBool(_keyAutoplayNext) ?? true,
      skipShortsInAutoplay:
          _prefs.getBool(_keySkipShortsInAutoplay) ?? true,
      autoQuality: _prefs.getBool(_keyAutoQuality) ?? true,
      adaptiveStreaming: _prefs.getBool(_keyAdaptiveStreaming) ?? false,
      playerQuickActions: _readPlayerQuickActions(),
      bufferPreset: _readBufferPreset(),
      keepPitch: _prefs.getBool(_keyKeepPitch) ?? true,
      subtitleStyle: _prefs.getString(_keySubtitleStyle) ?? 'defaultStyle',
      preferredSubtitleLanguage:
          _prefs.getString(_keyPreferredSubtitleLanguage) ?? 'app',
      playerEngine: PlayerEngineKind.values.firstWhere(
        (engine) => engine.name == _prefs.getString(_keyPlayerEngine),
        orElse: () => defaultPlayerEngine,
      ),
    );
  }

  Future<void> setSubtitleStyle(String styleName) async {
    await _prefs.setString(_keySubtitleStyle, styleName);
  }

  Future<void> setPreferredSubtitleLanguage(String language) async {
    await _prefs.setString(_keyPreferredSubtitleLanguage, language);
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

  Future<void> setAutoplayNext(bool enabled) async {
    await _prefs.setBool(_keyAutoplayNext, enabled);
  }

  Future<void> setSkipShortsInAutoplay(bool enabled) async {
    await _prefs.setBool(_keySkipShortsInAutoplay, enabled);
  }

  Future<void> setAutoQuality(bool enabled) async {
    await _prefs.setBool(_keyAutoQuality, enabled);
  }

  Future<void> setBufferPreset(BufferPreset preset) async {
    await _prefs.setString(_keyBufferPreset, preset.name);
  }

  Future<void> setKeepPitch(bool keepPitch) async {
    await _prefs.setBool(_keyKeepPitch, keepPitch);
  }

  Future<void> setAdaptiveStreaming(bool enabled) async {
    await _prefs.setBool(_keyAdaptiveStreaming, enabled);
  }

  Future<void> setPlayerEngine(PlayerEngineKind engine) async {
    await _prefs.setString(_keyPlayerEngine, engine.name);
  }

  Future<void> setSponsorBlockEnabled(bool enabled) async {
    await _prefs.setBool(_keySponsorBlockEnabled, enabled);
  }

  /// Persists the whole action map, and mirrors it onto the two legacy
  /// keys so an older build (or a restored backup) still finds the
  /// categories it understands.
  Future<void> setSponsorActions(
    Map<SponsorCategory, SegmentAction> actions,
  ) async {
    final encoded = actions.entries
        .map((e) => '${e.key.name}:${e.value.name}')
        .join(',');
    await _prefs.setString(_keySponsorActions, encoded);

    final enabled = actions.entries
        .where((e) => e.value != SegmentAction.none)
        .map((e) => e.key.name)
        .join(',');
    await _prefs.setString(_keySponsorCategories, enabled);
    await _prefs.setBool(
      _keyAutoSkipSponsors,
      actions.values.any((a) => a == SegmentAction.skip),
    );
  }

  Future<void> setSponsorAction(
    SponsorCategory category,
    SegmentAction action,
  ) async {
    final current = {...readSponsorActions()};
    current[category] = action;
    await setSponsorActions(current);
  }

  Future<void> setSponsorCategories(Set<SponsorCategory> categories) async {
    final current = {...readSponsorActions()};
    final fallback = current.values.any((a) => a == SegmentAction.skip)
        ? SegmentAction.skip
        : SegmentAction.showButton;
    for (final category in SponsorCategoryX.actionable) {
      if (!categories.contains(category)) {
        current[category] = SegmentAction.none;
      } else if (resolveSegmentAction(current, category) ==
          SegmentAction.none) {
        current[category] = fallback;
      }
    }
    await setSponsorActions(current);
  }

  Future<void> toggleSponsorCategory(
      SponsorCategory category, bool enabled) async {
    final current = {...readSponsorActions()};
    if (enabled) {
      // Re-enabling from the coarse switch restores the skip behaviour
      // the rest of the enabled categories already have.
      current[category] = current.values.any((a) => a == SegmentAction.skip)
          ? SegmentAction.skip
          : SegmentAction.showButton;
    } else {
      current[category] = SegmentAction.none;
    }
    await setSponsorActions(current);
  }

  /// The legacy global switch, expressed over the action map: flip every
  /// still-enabled category between skipping and offering a button.
  Future<void> setAutoSkipSponsors(bool enabled) async {
    final current = {...readSponsorActions()};
    for (final entry in current.entries.toList()) {
      if (entry.value == SegmentAction.none) continue;
      current[entry.key] =
          enabled ? SegmentAction.skip : SegmentAction.showButton;
    }
    await setSponsorActions(current);
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

  BufferPreset _readBufferPreset() {
    final value = _prefs.getString(_keyBufferPreset);
    return BufferPreset.values.firstWhere(
      (preset) => preset.name == value,
      // Keep in sync with AppSettings.bufferPreset's default.
      orElse: () => BufferPreset.medium,
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

  /// The per-category actions, migrating the pre-action settings when
  /// this is the first run on a build that has them.
  ///
  /// Visible for testing.
  Map<SponsorCategory, SegmentAction> readSponsorActions() {
    final stored = _prefs.getString(_keySponsorActions);
    if (stored != null && stored.isNotEmpty) {
      final actions = <SponsorCategory, SegmentAction>{};
      for (final pair in stored.split(',')) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;
        final category = SponsorCategory.values
            .where((c) => c.name == parts[0])
            .firstOrNull;
        final action =
            SegmentAction.values.where((a) => a.name == parts[1]).firstOrNull;
        if (category == null || action == null) continue;
        actions[category] = action;
      }
      // A category this build knows but the stored map predates keeps
      // its upstream default rather than silently doing nothing.
      for (final category in SponsorCategoryX.actionable) {
        actions.putIfAbsent(
          category,
          () => SponsorCategoryX.defaultAction(category),
        );
      }
      return actions;
    }

    return migrateSponsorActions(
      legacyCategories: _prefs.getString(_keySponsorCategories),
      legacyAutoSkip: _prefs.getBool(_keyAutoSkipSponsors),
    );
  }

  /// Turns the old `sponsor_categories` + `auto_skip_sponsors` pair into
  /// per-category actions.
  ///
  /// A ticked category becomes [SegmentAction.skip] when auto-skip was
  /// on and [SegmentAction.showButton] when it was off — which is what
  /// those two settings together used to mean. An unticked one becomes
  /// [SegmentAction.none]. With neither key written (a fresh install)
  /// the SmartTube defaults apply instead.
  static Map<SponsorCategory, SegmentAction> migrateSponsorActions({
    String? legacyCategories,
    bool? legacyAutoSkip,
  }) {
    if (legacyCategories == null && legacyAutoSkip == null) {
      return SponsorCategoryX.defaultActions;
    }

    final enabled = <SponsorCategory>{};
    if (legacyCategories == null) {
      // Auto-skip was set but the categories were never touched: the
      // old build's own default list was in force.
      enabled.addAll(const {
        SponsorCategory.sponsor,
        SponsorCategory.intro,
        SponsorCategory.outro,
        SponsorCategory.selfPromo,
        SponsorCategory.interaction,
      });
    } else {
      for (final name in legacyCategories.split(',')) {
        final category =
            SponsorCategory.values.where((c) => c.name == name).firstOrNull;
        if (category != null) enabled.add(category);
      }
    }

    final onAction = (legacyAutoSkip ?? false)
        ? SegmentAction.skip
        : SegmentAction.showButton;

    return {
      for (final category in SponsorCategoryX.actionable)
        category:
            enabled.contains(category) ? onAction : SegmentAction.none,
    };
  }
}
