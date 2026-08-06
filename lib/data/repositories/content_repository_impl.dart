// ============================================================
// ContentRepositoryImpl - Implementation
// ============================================================
// يطبّق contract من domain ويستخدم InnerTubeClient.
// ============================================================

import 'dart:math' show Random;

import 'package:youtube_explode_dart/youtube_explode_dart.dart' show Video;

import '../../domain/entities/channel_info.dart';
import '../../domain/entities/media_group.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_page.dart';
import '../../domain/entities/playlist_info.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/local_library_repository.dart' as domain;
import '../../core/utils/result.dart';
import '../../core/errors/exceptions.dart';
import '../local/database/app_database.dart';
import '../youtube/innertube_client.dart';
import '../youtube/mappers/media_item_mapper.dart';
import 'local_library_repository_impl.dart' as impl;

class ContentRepositoryImpl implements ContentRepository {
  final InnerTubeClient _client;
  final AppDatabase _db;

  ContentRepositoryImpl(this._client, this._db);

  /// The pool the home feed draws its shelves from.
  ///
  /// Signed out there is no personalised feed to ask for, so home is
  /// assembled from topic searches. Four fixed queries meant the same
  /// four shelves in the same order every single launch — the screen
  /// never looked like it had been anywhere. A handful are drawn from
  /// this pool per load instead, so home has something new on it each
  /// time the way YouTube's does.
  static const _homeShelfPool = <String, String>{
    'Music': 'music 2026',
    'Gaming': 'gaming highlights',
    'Technology': 'tech review',
    'News': 'news today',
    'Podcasts': 'podcast episode 2026',
    'Football': 'football highlights 2026',
    'Cooking': 'easy recipes 2026',
    'Documentary': 'documentary 2026',
    'Comedy': 'stand up comedy 2026',
    'Science': 'science explained 2026',
    'Travel': 'travel vlog 2026',
    'Cars': 'car review 2026',
    'Fitness': 'workout routine 2026',
    'Learning': 'tutorial 2026',
  };

  /// How many shelves one home load asks for. More is slower to first
  /// paint and the extra rarely gets scrolled to.
  static const _homeShelfCount = 5;

  static final _shelfPicker = Random();

  /// A fresh handful of shelves, in a fresh order.
  static Iterable<MapEntry<String, String>> _pickHomeShelves() {
    final pool = _homeShelfPool.entries.toList()..shuffle(_shelfPicker);
    return pool.take(_homeShelfCount);
  }

  /// Videos → items, carrying the channel avatar when the caller knows
  /// it (a channel page does; a search result does not).
  static List<MediaItem> _items(
    Iterable<Video> videos, {
    String? channelAvatarUrl,
  }) =>
      videos
          .map((v) =>
              MediaItemMapper.fromVideo(v, channelAvatarUrl: channelAvatarUrl))
          .toList();

  @override
  Future<Result<List<MediaGroup>>> getHomeFeed({String? pageToken}) async {
    try {
      // A token continues one shelf, not the whole screen: each shelf is
      // its own query, so the caller pages them independently.
      if (pageToken != null) {
        final page = await _client.continuePage(pageToken);
        return Success([
          MediaGroup(
            title: '',
            type: MediaGroupType.recommended,
            mediaItems: _items(page.videos),
            nextPageToken: page.nextPageToken,
          ),
        ]);
      }

      final results = await Future.wait(
        _pickHomeShelves().map((entry) async {
          try {
            final page = await _client.searchPage(entry.value);
            if (page.videos.isEmpty) return null;
            return MediaGroup(
              title: entry.key,
              type: MediaGroupType.recommended,
              mediaItems: _items(page.videos),
              nextPageToken: page.nextPageToken,
            );
          } catch (_) {
            // One failing shelf must not blank the whole home screen.
            return null;
          }
        }),
      );

      final groups = results.whereType<MediaGroup>().toList();
      if (groups.isEmpty) {
        return const FailureResult(
          'Could not load any home shelves',
          type: FailureType.network,
        );
      }
      return Success(groups);
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load home feed: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<MediaGroup>>> getTrending() async {
    try {
      final videos = await _client.getTrending();
      return Success([
        MediaGroup(
          title: 'Trending Now',
          type: MediaGroupType.trending,
          mediaItems: _items(videos),
        ),
      ]);
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load trending: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<MediaGroup>>> getSubscriptionsFeed() async {
    // FIXED: actually loads from local subscriptions + fetches recent videos
    try {
      final localRepo = impl.LocalLibraryRepositoryImpl(_db);
      final subsResult = await localRepo.getSubscriptions();

      // FIXED: use .when() to access fields
      if (subsResult.isFailure) {
        return subsResult.when(
          success: (data) => Success(<MediaGroup>[]),
          failure: (message, type, cause) => FailureResult(
            message,
            type: type,
            cause: cause,
          ),
        );
      }

      final subscriptions =
          (subsResult as Success).data as List<domain.LocalSubscription>;
      if (subscriptions.isEmpty) {
        return const Success([]);
      }

      // Fetch recent videos from each subscribed channel
      final groups = <MediaGroup>[];
      for (final sub in subscriptions) {
        try {
          final page = await _client.channelVideosPage(sub.channelId);
          groups.add(MediaGroup(
            title: sub.title,
            type: MediaGroupType.channelVideos,
            channelId: sub.channelId,
            // The local subscription row already knows the channel's
            // picture, so every card in this shelf can show it.
            mediaItems: _items(page.videos, channelAvatarUrl: sub.avatarUrl),
            nextPageToken: page.nextPageToken,
          ));
        } catch (e) {
          // Skip individual channel errors
          continue;
        }
      }

      return Success(groups);
    } catch (e) {
      return FailureResult(
        'Failed to load subscriptions feed: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<MediaGroup>> search(
    String query, {
    String? pageToken,
    SearchFilters filters = const SearchFilters(),
  }) async {
    try {
      final page = await _client.searchPage(
        query,
        filters: filters,
        pageToken: pageToken,
      );
      return Success(
        MediaGroup(
          title: 'Results for "$query"',
          type: MediaGroupType.search,
          mediaItems: _items(page.videos),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Search failed: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<ChannelContent>> getChannel(
    String channelId, {
    String? pageToken,
  }) async {
    try {
      final channel = await _client.getChannelInfo(channelId);
      final page = await _client.channelVideosPage(
        channelId,
        pageToken: pageToken,
      );

      return Success(
        ChannelContent(
          channelId: channelId,
          title: channel.title,
          description: channel.description,
          avatarUrl: channel.avatarUrl,
          bannerUrl: channel.bannerUrl,
          subscriberCount: channel.subscriberCount,
          shelves: [
            MediaGroup(
              title: 'Videos',
              type: MediaGroupType.channelVideos,
              channelId: channelId,
              mediaItems:
                  _items(page.videos, channelAvatarUrl: channel.avatarUrl),
              nextPageToken: page.nextPageToken,
            ),
          ],
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load channel: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<ChannelInfo>> getChannelInfo(String channelId) async {
    try {
      return Success(await _client.getChannelInfo(channelId));
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load channel info: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<MediaPage>> getChannelVideos(
    String channelId, {
    String? pageToken,
  }) async {
    try {
      final page = await _client.channelVideosPage(
        channelId,
        pageToken: pageToken,
      );
      return Success(
        MediaPage(
          items: _items(page.videos),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load channel videos: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<PlaylistInfo>>> getChannelPlaylists(
    String channelId,
  ) async {
    try {
      return Success(await _client.getChannelPlaylists(channelId));
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load channel playlists: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<MediaGroup>> getPlaylist(
    String playlistId, {
    String? pageToken,
  }) async {
    try {
      final page = await _client.playlistVideosPage(
        playlistId,
        pageToken: pageToken,
      );
      return Success(
        MediaGroup(
          title: 'Playlist',
          type: MediaGroupType.playlist,
          mediaItems: _items(page.videos),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load playlist: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<MediaPage>> getRelatedVideos(
    String videoId, {
    String? pageToken,
  }) async {
    try {
      final page = await _client.relatedVideosPage(
        videoId,
        pageToken: pageToken,
      );
      return Success(
        MediaPage(
          items: _items(page.videos),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load related videos: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<MediaPage>> loadMore(String pageToken) async {
    try {
      final page = await _client.continuePage(pageToken);
      return Success(
        MediaPage(
          items: _items(page.videos),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load more: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }
}
