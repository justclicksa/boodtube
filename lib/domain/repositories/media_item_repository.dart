// ============================================================
// MediaItemRepository - Interface (FIXED: removed duplicate SponsorSegment)
// ============================================================
// عقد لـ operations على media item واحد (video).
// ============================================================

import '../entities/media_item.dart';
import '../entities/media_subtitle.dart';
import '../entities/chapter_item.dart';
import '../entities/sponsor_segment.dart' show SponsorCategory, SponsorSegment;
import '../../core/utils/result.dart';

/// Repository for single media item operations
abstract interface class MediaItemRepository {
  /// Get full media item info (metadata + formats + chapters + subtitles + sponsor segments)
  Future<Result<MediaItem>> getMediaItem(String videoId);

  /// Get sponsor segments for a video
  Future<Result<List<SponsorSegment>>> getSponsorSegments(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
    },
  });

  /// Get subtitles for a video
  Future<Result<List<MediaSubtitle>>> getSubtitles(String videoId);

  /// Get chapters for a video
  Future<Result<List<ChapterItem>>> getChapters(String videoId);

  /// Like / dislike a video (يتطلب تسجيل دخول - للمستقبل)
  Future<Result<void>> rateVideo(String videoId, VideoRating rating);

  /// Subscribe / unsubscribe to channel (يتطلب تسجيل دخول)
  Future<Result<void>> setSubscription(String channelId, bool subscribe);
}

enum VideoRating { like, dislike, none }
