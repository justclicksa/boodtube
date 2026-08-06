// ============================================================
// MediaItem - Pure Dart Entity (Freezed)
// ============================================================
// هذا الـ entity الأساسي الذي يمثّل أي فيديو في التطبيق.
// Pure Dart - لا يحتوي على أي imports لـ Flutter أو third-party.
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

import 'media_format.dart';
import 'media_subtitle.dart';
import 'chapter_item.dart';
import 'sponsor_segment.dart';
import 'dearrow_data.dart';

part 'media_item.freezed.dart';

/// Represents a single media item (video, live stream, short, etc.)
@freezed
class MediaItem with _$MediaItem {
  const factory MediaItem({
    required String videoId,
    required String title,
    String? description,

    // Channel info
    required String author,
    required String channelId,
    String? channelTitle,

    /// The channel's avatar, when the surface that produced this item
    /// carried one. Feed payloads often do not, so this stays null and
    /// the card falls back to the channel initial.
    String? channelAvatarUrl,

    /// The channel's subscriber count. Only the single-video path looks
    /// this up (the player's channel row shows it); feed items leave it
    /// null rather than pay for a channel request per card.
    int? subscriberCount,

    // Timing
    required Duration duration,
    required DateTime publishedAt,

    // Media
    String? thumbnailUrl,
    required List<MediaFormat> formats,
    required List<MediaSubtitle> subtitles,
    required List<ChapterItem> chapters,

    // SponsorBlock
    @Default(<SponsorSegment>[]) List<SponsorSegment> sponsorSegments,

    // DeArrow
    DeArrowData? deArrowData,

    // User state
    int? percentWatched,
    Duration? resumePosition,

    // Flags
    @Default(false) bool isLive,
    @Default(false) bool isUpcoming,
    @Default(false) bool isShorts,
    @Default(false) bool isVerified,

    // Stats
    int? viewCount,
    int? likeCount,
  }) = _MediaItem;

  const MediaItem._();

  /// Stands for "upload date unknown" — before YouTube existed, so the
  /// UI can tell it apart from a genuinely fresh upload and omit the
  /// "x ago" label rather than print something wrong.
  static final unknownDate = DateTime.utc(2000);

  /// Unique ID (for any provider)
  String get id => videoId;

  /// Is this a video the user hasn't finished yet?
  bool get isInProgress =>
      percentWatched != null && percentWatched! > 0 && percentWatched! < 100;

  /// Best quality format available
  MediaFormat? get bestFormat {
    if (formats.isEmpty) return null;
    return formats.reduce((a, b) => a.bitrate > b.bitrate ? a : b);
  }
}
