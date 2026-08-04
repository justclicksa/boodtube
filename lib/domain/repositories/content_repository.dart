// ============================================================
// ContentRepository - Interface (Pure Dart)
// ============================================================
// عقد (contract) لـ repository المحتوى.
// التنفيذ الفعلي في طبقة data/.
// ============================================================

import '../entities/media_group.dart';
import '../../core/utils/result.dart';

/// Repository for browsing YouTube content
abstract interface class ContentRepository {
  /// Get the home feed
  Future<Result<List<MediaGroup>>> getHomeFeed();

  /// Get trending videos
  Future<Result<List<MediaGroup>>> getTrending();

  /// Get user subscriptions feed (إذا كان مسجل دخول)
  /// أو local subscriptions (إذا لم يكن)
  Future<Result<List<MediaGroup>>> getSubscriptionsFeed();

  /// Search for videos
  Future<Result<MediaGroup>> search(
    String query, {
    String? pageToken,
    SearchFilters filters = const SearchFilters(),
  });

  /// Get channel info + recent videos
  Future<Result<ChannelContent>> getChannel(String channelId, {String? pageToken});

  /// Get playlist videos
  Future<Result<MediaGroup>> getPlaylist(String playlistId, {String? pageToken});
}

class SearchFilters {
  final String? uploadDate; // "hour", "today", "week", "month", "year"
  final String? type; // "video", "channel", "playlist", "movie"
  final String? duration; // "short", "medium", "long"
  final String? sortBy; // "relevance", "date", "viewCount", "rating"

  const SearchFilters({
    this.uploadDate,
    this.type,
    this.duration,
    this.sortBy,
  });

  bool get isEmpty =>
      uploadDate == null && type == null && duration == null && sortBy == null;
}

class ChannelContent {
  final String channelId;
  final String title;
  final String? description;
  final String? avatarUrl;
  final int? subscriberCount;
  final List<MediaGroup> shelves; // videos, playlists, shorts, live, etc.

  const ChannelContent({
    required this.channelId,
    required this.title,
    this.description,
    this.avatarUrl,
    this.subscriberCount,
    required this.shelves,
  });
}
