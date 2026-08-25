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
  highlight, // the point the video is actually about (poi_highlight)
  preview, // preview of another video
  musicOffTopic, // non-music portion of music video
  filler, // filler content
  exclusiveAccess, // the whole video is a paid/sponsored placement
}

/// What playback does when the playhead enters a segment of a category.
///
/// Mirrors SmartTube's `SponsorBlockData.ACTION_*`: skip silently (we
/// still flash an undoable toast), offer a button, or ignore it.
enum SegmentAction { skip, showButton, none }

extension SponsorCategoryX on SponsorCategory {
  /// API string for SponsorBlock (sponsor.ajay.app)
  String get apiValue => switch (this) {
        SponsorCategory.sponsor => 'sponsor',
        SponsorCategory.intro => 'intro',
        SponsorCategory.outro => 'outro',
        SponsorCategory.selfPromo => 'selfpromo',
        SponsorCategory.interaction => 'interaction',
        SponsorCategory.highlight => 'poi_highlight',
        SponsorCategory.preview => 'preview',
        SponsorCategory.musicOffTopic => 'music_offtopic',
        SponsorCategory.filler => 'filler',
        SponsorCategory.exclusiveAccess => 'exclusive_access',
      };

  /// The `actionType` the API files this category under. Asking for a
  /// category without its action type returns nothing: highlights are
  /// `poi` and exclusive access is `full`, never `skip`.
  String get apiActionType => switch (this) {
        SponsorCategory.highlight => 'poi',
        SponsorCategory.exclusiveAccess => 'full',
        _ => 'skip',
      };

  /// SponsorBlock's own category colours, as used on the seek bar.
  int get colorValue => switch (this) {
        SponsorCategory.sponsor => 0xFF00D400,
        SponsorCategory.selfPromo => 0xFFFFFF00,
        SponsorCategory.interaction => 0xFFCC00FF,
        SponsorCategory.intro => 0xFF00FFFF,
        SponsorCategory.outro => 0xFF0202ED,
        SponsorCategory.preview => 0xFF008FD6,
        SponsorCategory.musicOffTopic => 0xFFFF9900,
        SponsorCategory.filler => 0xFF7300FF,
        SponsorCategory.highlight => 0xFFFF1684,
        SponsorCategory.exclusiveAccess => 0xFF008A5C,
      };

  /// Whether entering the segment can seek past it. A highlight is a
  /// single point and exclusive access covers the whole video, so
  /// neither is ever skipped — they are surfaced in the UI instead.
  bool get isSkippable =>
      this != SponsorCategory.highlight &&
      this != SponsorCategory.exclusiveAccess;

  /// Categories the user can assign a [SegmentAction] to. The two
  /// non-skippable ones are driven by the player UI, not by an action.
  static const List<SponsorCategory> actionable = [
    SponsorCategory.sponsor,
    SponsorCategory.intro,
    SponsorCategory.outro,
    SponsorCategory.selfPromo,
    SponsorCategory.interaction,
    SponsorCategory.preview,
    SponsorCategory.musicOffTopic,
    SponsorCategory.filler,
  ];

  /// SmartTube's defaults: everything skips except filler, which is
  /// aggressive enough that upstream ships it disabled.
  static SegmentAction defaultAction(SponsorCategory category) =>
      switch (category) {
        SponsorCategory.filler => SegmentAction.none,
        SponsorCategory.highlight => SegmentAction.none,
        SponsorCategory.exclusiveAccess => SegmentAction.none,
        _ => SegmentAction.skip,
      };

  static Map<SponsorCategory, SegmentAction> get defaultActions => {
        for (final category in actionable)
          category: defaultAction(category),
      };

  static SponsorCategory? tryFromApiValue(String s) => switch (s) {
        'sponsor' => SponsorCategory.sponsor,
        'intro' => SponsorCategory.intro,
        'outro' => SponsorCategory.outro,
        'selfpromo' => SponsorCategory.selfPromo,
        'interaction' => SponsorCategory.interaction,
        // Both spellings: 'highlight' is what this app used to persist.
        'poi_highlight' || 'highlight' => SponsorCategory.highlight,
        'preview' => SponsorCategory.preview,
        'music_offtopic' => SponsorCategory.musicOffTopic,
        'filler' => SponsorCategory.filler,
        'exclusive_access' => SponsorCategory.exclusiveAccess,
        _ => null,
      };

  static SponsorCategory fromApiValue(String s) =>
      tryFromApiValue(s) ?? SponsorCategory.sponsor;
}

/// Resolves the action for [category] from a stored map, falling back
/// to the SmartTube default when the category has never been
/// configured (a category added by a later version, say).
SegmentAction resolveSegmentAction(
  Map<SponsorCategory, SegmentAction> actions,
  SponsorCategory category,
) =>
    actions[category] ?? SponsorCategoryX.defaultAction(category);

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

  /// Stable identity for "don't skip this one again". The API UUID when
  /// there is one; the bounds otherwise, which is what the hash-prefix
  /// endpoint gives for locally merged segments.
  String get key =>
      uuid ?? '${category.name}:${start.inMilliseconds}-${end.inMilliseconds}';
}
