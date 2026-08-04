// ============================================================
// SponsorSegment - Freezed entity (FIXED: was inside media_subtitle.dart)
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sponsor_segment.freezed.dart';

enum SponsorCategory {
  sponsor, // paid promotion
  intro, // intro animation
  outro, // outro (end cards, subscribe reminder)
  selfPromo, // merch, Patreon
  interaction, // like, subscribe reminder
  highlight, // highlights (like a summary)
  preview, // preview of another video
  musicOffTopic, // non-music portion of music video
  filler, // filler content
}

extension SponsorCategoryX on SponsorCategory {
  /// API string for SponsorBlock (sponsor.ajay.app)
  String get apiValue => switch (this) {
        SponsorCategory.sponsor => 'sponsor',
        SponsorCategory.intro => 'intro',
        SponsorCategory.outro => 'outro',
        SponsorCategory.selfPromo => 'selfpromo',
        SponsorCategory.interaction => 'interaction',
        SponsorCategory.highlight => 'highlight',
        SponsorCategory.preview => 'preview',
        SponsorCategory.musicOffTopic => 'music_offtopic',
        SponsorCategory.filler => 'filler',
      };

  static SponsorCategory fromApiValue(String s) => switch (s) {
        'sponsor' => SponsorCategory.sponsor,
        'intro' => SponsorCategory.intro,
        'outro' => SponsorCategory.outro,
        'selfpromo' => SponsorCategory.selfPromo,
        'interaction' => SponsorCategory.interaction,
        'highlight' => SponsorCategory.highlight,
        'preview' => SponsorCategory.preview,
        'music_offtopic' => SponsorCategory.musicOffTopic,
        'filler' => SponsorCategory.filler,
        _ => SponsorCategory.sponsor,
      };
}

@freezed
class SponsorSegment with _$SponsorSegment {
  const factory SponsorSegment({
    required Duration start,
    required Duration end,
    required SponsorCategory category,
    String? description,
    String? uuid, // SponsorBlock UUID for voting
  }) = _SponsorSegment;

  const SponsorSegment._();

  Duration get duration => end - start;

  bool isActiveAt(Duration position) {
    return position >= start && position < end;
  }

  bool get isNotEmpty => end > start;
  bool get isEmpty => end <= start;
}
