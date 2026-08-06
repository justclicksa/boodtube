// ============================================================
// ContentRepository - Interface (Pure Dart)
// ============================================================
// عقد (contract) لـ repository المحتوى.
// التنفيذ الفعلي في طبقة data/.
// ============================================================

import '../entities/channel_info.dart';
import '../entities/media_group.dart';
import '../entities/media_item.dart';
import '../entities/media_page.dart';
import '../entities/playlist_info.dart';
import '../entities/search_options.dart';
import '../../core/utils/result.dart';

/// Repository for browsing YouTube content
abstract interface class ContentRepository {
  /// Get the home feed. [pageToken] continues a previous page.
  Future<Result<List<MediaGroup>>> getHomeFeed({String? pageToken});

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
  Future<Result<ChannelContent>> getChannel(String channelId,
      {String? pageToken});

  /// Channel metadata on its own — avatar, subscriber count — without
  /// paying for a page of uploads.
  Future<Result<ChannelInfo>> getChannelInfo(String channelId);

  /// One page of a channel's uploads, without the channel metadata
  /// [getChannel] also fetches. This is what the channel page's Videos
  /// tab scrolls; continue it with [loadMore].
  Future<Result<MediaPage>> getChannelVideos(String channelId,
      {String? pageToken});

  /// The playlists a channel publishes.
  ///
  /// Not paged: YouTube returns a channel's whole Playlists tab in one
  /// response, and channels with more than a screenful are rare enough
  /// that a continuation would be machinery for nobody.
  Future<Result<List<PlaylistInfo>>> getChannelPlaylists(String channelId);

  /// Get playlist videos
  Future<Result<MediaGroup>> getPlaylist(String playlistId,
      {String? pageToken});

  /// YouTube's own "up next" list for a video.
  Future<Result<MediaPage>> getRelatedVideos(String videoId,
      {String? pageToken});

  /// Continues any paged feed this repository produced.
  ///
  /// [pageToken] is opaque and self-describing: it identifies the feed it
  /// came from, so the caller does not have to remember the query,
  /// channel or playlist that produced it.
  Future<Result<MediaPage>> loadMore(String pageToken);
}

/// The search refinements YouTube's own filter panel offers.
///
/// Every field is honoured — see `data/youtube/search_filter_params.dart`
/// for how each one is encoded into the `sp` query parameter.
class SearchFilters {
  final SearchUploadDate uploadDate;
  final SearchType type;
  final SearchDuration duration;
  final SearchSortBy sortBy;

  const SearchFilters({
    this.uploadDate = SearchUploadDate.any,
    this.type = SearchType.any,
    this.duration = SearchDuration.any,
    this.sortBy = SearchSortBy.relevance,
  });

  /// The filter half of a [SearchOptions] (everything but the query).
  factory SearchFilters.fromOptions(SearchOptions options) => SearchFilters(
        uploadDate: options.uploadDate,
        type: options.type,
        duration: options.duration,
        sortBy: options.sortBy,
      );

  bool get isEmpty =>
      uploadDate == SearchUploadDate.any &&
      type == SearchType.any &&
      duration == SearchDuration.any &&
      sortBy == SearchSortBy.relevance;

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.uploadDate == uploadDate &&
      other.type == type &&
      other.duration == duration &&
      other.sortBy == sortBy;

  @override
  int get hashCode => Object.hash(uploadDate, type, duration, sortBy);
}

class ChannelContent {
  final String channelId;
  final String title;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final int? subscriberCount;
  final List<MediaGroup> shelves; // videos, playlists, shorts, live, etc.

  const ChannelContent({
    required this.channelId,
    required this.title,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.subscriberCount,
    required this.shelves,
  });

  /// Every video across every shelf, in order.
  List<MediaItem> get allItems =>
      [for (final shelf in shelves) ...shelf.mediaItems];

  ChannelInfo get info => ChannelInfo(
        channelId: channelId,
        title: title,
        description: description,
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
        subscriberCount: subscriberCount,
      );
}
