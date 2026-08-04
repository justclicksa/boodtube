// ============================================================
// ContentRepositoryImpl - Implementation
// ============================================================
// يطبّق contract من domain ويستخدم InnerTubeClient.
// ============================================================

import '../../domain/entities/media_group.dart';
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

  /// Topic shelves that make up the home feed. Kept distinct from the
  /// trending row so the home screen isn't the same list twice.
  static const _homeShelves = <String, String>{
    'Music': 'music 2026',
    'Gaming': 'gaming highlights',
    'Technology': 'tech review',
    'News': 'news today',
  };

  @override
  Future<Result<List<MediaGroup>>> getHomeFeed() async {
    try {
      final results = await Future.wait(
        _homeShelves.entries.map((entry) async {
          try {
            final videos = await _client.search(entry.value);
            if (videos.isEmpty) return null;
            return MediaGroup(
              title: entry.key,
              type: MediaGroupType.recommended,
              mediaItems:
                  videos.take(15).map(MediaItemMapper.fromVideo).toList(),
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
          mediaItems: videos
              .take(30)
              .map(MediaItemMapper.fromVideo)
              .toList(),
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
  Future<Result<List<MediaGroup>>> getSubscriptionsFeed({String? pageToken}) async {
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

      final subscriptions = (subsResult as Success).data as List<domain.LocalSubscription>;
      if (subscriptions.isEmpty) {
        return const Success([]);
      }

      // Fetch recent videos from each subscribed channel
      final groups = <MediaGroup>[];
      for (final sub in subscriptions) {
        try {
          final videos = await _client.getChannelVideos(sub.channelId);
          groups.add(MediaGroup(
            title: sub.title,
            type: MediaGroupType.channelVideos,
            channelId: sub.channelId,
            mediaItems: videos
                .take(20)
                .map(MediaItemMapper.fromVideo)
                .toList(),
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
      final videos = await _client.search(query);
      return Success(
        MediaGroup(
          title: 'Results for "$query"',
          type: MediaGroupType.search,
          mediaItems: videos
              .take(50)
              .map(MediaItemMapper.fromVideo)
              .toList(),
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
      final channel = await _client.getChannel(channelId);
      final videos = await _client.getChannelVideos(channelId);

      return Success(
        ChannelContent(
          channelId: channelId,
          title: channel.title,
          // FIXED: لا يوجد description property مباشرة في Channel
          description: null,
          avatarUrl: channel.logoUrl,
          shelves: [
            MediaGroup(
              title: 'Videos',
              type: MediaGroupType.channelVideos,
              mediaItems: videos
                  .take(30)
                  .map(MediaItemMapper.fromVideo)
                  .toList(),
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
  Future<Result<MediaGroup>> getPlaylist(
    String playlistId, {
    String? pageToken,
  }) async {
    try {
      final videos = await _client.getPlaylistVideos(playlistId);
      return Success(
        MediaGroup(
          title: 'Playlist',
          type: MediaGroupType.playlist,
          mediaItems: videos
              .take(100)
              .map(MediaItemMapper.fromVideo)
              .toList(),
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
}
