// ============================================================
// Localized labels for domain enums
// ============================================================
// Domain entities stay free of Flutter and of AppLocalizations, so the
// English `label` getters they carry are only a debug fallback. Every
// enum the user can actually see gets its display string here instead.
// ============================================================

import '../../domain/entities/content_filter.dart';
import '../../domain/entities/media_format.dart';
import '../../domain/entities/sponsor_segment.dart';
import '../../l10n/app_localizations.dart';
import '../../services/player_tuning.dart';
import '../providers/player_providers.dart';

extension LocalizedQuality on MediaFormatQuality {
  String label(AppLocalizations l10n) => switch (this) {
        MediaFormatQuality.lowest => l10n.qualityLowest,
        MediaFormatQuality.low => l10n.qualityLow,
        MediaFormatQuality.medium => l10n.qualityMedium,
        MediaFormatQuality.high => l10n.qualityHigh,
        MediaFormatQuality.highest => l10n.qualityHighest,
        MediaFormatQuality.best => l10n.qualityBest,
      };
}

extension LocalizedHiddenContent on HiddenContent {
  String label(AppLocalizations l10n) => switch (this) {
        HiddenContent.shortsHome => l10n.hideShortsHome,
        HiddenContent.shortsSubscriptions => l10n.hideShortsSubscriptions,
        HiddenContent.shortsSearch => l10n.hideShortsSearch,
        HiddenContent.shortsChannel => l10n.hideShortsChannel,
        HiddenContent.watchedHome => l10n.hideWatchedHome,
        HiddenContent.watchedSubscriptions => l10n.hideWatchedSubscriptions,
        HiddenContent.upcomingHome => l10n.hideUpcomingHome,
        HiddenContent.upcomingSubscriptions => l10n.hideUpcomingSubscriptions,
        HiddenContent.streamsSubscriptions => l10n.hideStreamsSubscriptions,
      };
}

extension LocalizedThumbnail on ClickbaitThumbnail {
  String label(AppLocalizations l10n) => switch (this) {
        ClickbaitThumbnail.original => l10n.thumbnailOriginal,
        ClickbaitThumbnail.start => l10n.thumbnailStart,
        ClickbaitThumbnail.middle => l10n.thumbnailMiddle,
        ClickbaitThumbnail.end => l10n.thumbnailEnd,
      };
}

extension LocalizedSegmentAction on SegmentAction {
  String label(AppLocalizations l10n) => switch (this) {
        SegmentAction.skip => l10n.segmentActionSkip,
        SegmentAction.showButton => l10n.segmentActionShowButton,
        SegmentAction.none => l10n.segmentActionNone,
      };
}

extension LocalizedSponsorCategory on SponsorCategory {
  String label(AppLocalizations l10n) => switch (this) {
        SponsorCategory.sponsor => l10n.categorySponsor,
        SponsorCategory.intro => l10n.categoryIntro,
        SponsorCategory.outro => l10n.categoryOutro,
        SponsorCategory.selfPromo => l10n.categorySelfPromo,
        SponsorCategory.interaction => l10n.categoryInteraction,
        SponsorCategory.highlight => l10n.categoryHighlight,
        SponsorCategory.preview => l10n.categoryPreview,
        SponsorCategory.musicOffTopic => l10n.categoryMusicOffTopic,
        SponsorCategory.filler => l10n.categoryFiller,
        SponsorCategory.exclusiveAccess => l10n.categoryExclusiveAccess,
      };
}

extension LocalizedRepeatMode on RepeatMode {
  /// Full sentence, shown in the mode picker.
  String label(AppLocalizations l10n) => switch (this) {
        RepeatMode.none => l10n.repeatNone,
        RepeatMode.one => l10n.repeatOne,
        RepeatMode.all => l10n.repeatAll,
        RepeatMode.shuffle => l10n.repeatShuffle,
        RepeatMode.pause => l10n.repeatPause,
      };

  /// Compact form for the settings row's trailing value.
  String shortLabel(AppLocalizations l10n) => switch (this) {
        RepeatMode.none => l10n.repeatNoneShort,
        RepeatMode.one => l10n.repeatOneShort,
        RepeatMode.all => l10n.repeatAllShort,
        RepeatMode.shuffle => l10n.repeatShuffleShort,
        RepeatMode.pause => l10n.repeatPauseShort,
      };
}

extension LocalizedVideoFit on VideoFit {
  String label(AppLocalizations l10n) => switch (this) {
        VideoFit.fit => l10n.fitDefault,
        VideoFit.fitWidth => l10n.fitWidth,
        VideoFit.fitHeight => l10n.fitHeight,
        VideoFit.stretch => l10n.fitStretch,
        VideoFit.zoom => l10n.fitZoom,
      };
}

extension LocalizedBufferPreset on BufferPreset {
  String label(AppLocalizations l10n) => switch (this) {
        BufferPreset.low => l10n.bufferLow,
        BufferPreset.medium => l10n.bufferMedium,
        BufferPreset.high => l10n.bufferHigh,
        BufferPreset.highest => l10n.bufferHighest,
      };

  /// "30 sec" — the same number the mpv properties are derived from,
  /// so the menu never drifts from what the engine was told.
  String secondsLabel(AppLocalizations l10n) =>
      l10n.secondsShort(bufferPresetSeconds[this]!);
}
