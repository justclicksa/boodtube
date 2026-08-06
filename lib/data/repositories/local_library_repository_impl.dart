// ============================================================
// LocalLibraryRepositoryImpl (FIXED: typed mappers, division by zero, history upsert)
// ============================================================

import 'package:drift/drift.dart';

import '../../domain/entities/media_item.dart';
import '../../domain/repositories/local_library_repository.dart' as domain;
import '../../core/utils/result.dart';
import '../../core/errors/exceptions.dart';
import '../local/database/app_database.dart';

// Re-export LocalSubscription for convenience
typedef LocalSubscription = domain.LocalSubscription;

// FIXED: rename class to avoid conflict with domain interface
class LocalLibraryRepositoryImpl implements domain.LocalLibraryRepository {
  final AppDatabase _db;

  LocalLibraryRepositoryImpl(this._db);

  // ============================================================
  // Watch History (FIXED: not upsert on videoId so re-watches are logged)
  // ============================================================

  Future<Result<List<MediaItem>>> getWatchHistory({int limit = 50}) async {
    try {
      final records = await _db.getRecentHistory(limit: limit);
      return Success(records.map(_historyToMediaItem).toList());
    } catch (e) {
      return FailureResult(
        'Failed to load history: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> addToHistory(MediaItem item,
      {Duration? position}) async {
    try {
      // FIXED: append new row (delete existing first) so re-watches are recorded
      await _db.deleteHistoryItem(item.videoId);
      await _db.addToHistory(
        WatchHistoryTableCompanion.insert(
          videoId: item.videoId,
          title: item.title,
          author: item.author,
          channelId: item.channelId,
          thumbnailUrl: Value(item.thumbnailUrl),
          durationMs: item.duration.inMilliseconds,
          watchedAt: DateTime.now(),
          positionMs: Value(position?.inMilliseconds ?? 0),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to add to history: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> clearHistory() async {
    try {
      await _db.clearHistory();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to clear history: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  // ============================================================
  // Local Subscriptions
  // ============================================================

  Future<Result<List<LocalSubscription>>> getSubscriptions() async {
    try {
      final records = await _db.getAllSubscriptions();
      return Success(records.map(_subscriptionFromRecord).toList());
    } catch (e) {
      return FailureResult(
        'Failed to load subscriptions: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<bool>> isSubscribed(String channelId) async {
    try {
      final result = await _db.isSubscribed(channelId);
      return Success(result);
    } catch (e) {
      return FailureResult(
        'Failed to check subscription: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> subscribe({
    required String channelId,
    required String title,
    String? avatarUrl,
    int? subscriberCount,
  }) async {
    try {
      await _db.addSubscription(
        LocalSubscriptionsTableCompanion.insert(
          channelId: channelId,
          title: title,
          avatarUrl: Value(avatarUrl),
          subscriberCount: Value(subscriberCount),
          subscribedAt: DateTime.now(),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to subscribe: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> unsubscribe(String channelId) async {
    try {
      await _db.removeSubscription(channelId);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to unsubscribe: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  // ============================================================
  // Favorites
  // ============================================================

  Future<Result<List<MediaItem>>> getFavorites() async {
    try {
      final records = await _db.getFavorites();
      return Success(records.map(_favoriteToMediaItem).toList());
    } catch (e) {
      return FailureResult(
        'Failed to load favorites: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<bool>> isFavorite(String videoId) async {
    try {
      final result = await _db.isFavorite(videoId);
      return Success(result);
    } catch (e) {
      return FailureResult(
        'Failed to check favorite: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> addToFavorites(MediaItem item) async {
    try {
      await _db.addToFavorites(
        FavoritesTableCompanion.insert(
          videoId: item.videoId,
          title: item.title,
          author: item.author,
          channelId: item.channelId,
          thumbnailUrl: Value(item.thumbnailUrl),
          durationMs: item.duration.inMilliseconds,
          addedAt: DateTime.now(),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to add to favorites: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> removeFromFavorites(String videoId) async {
    try {
      await _db.removeFromFavorites(videoId);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to remove from favorites: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  // ============================================================
  // Watch Later
  // ============================================================

  Future<Result<List<MediaItem>>> getWatchLater() async {
    try {
      final records = await _db.getWatchLater();
      return Success(records.map(_watchLaterToMediaItem).toList());
    } catch (e) {
      return FailureResult(
        'Failed to load watch later: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> addToWatchLater(MediaItem item) async {
    try {
      await _db.addToWatchLater(
        WatchLaterTableCompanion.insert(
          videoId: item.videoId,
          title: item.title,
          author: item.author,
          channelId: item.channelId,
          thumbnailUrl: Value(item.thumbnailUrl),
          durationMs: item.duration.inMilliseconds,
          addedAt: DateTime.now(),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to add to watch later: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> removeFromWatchLater(String videoId) async {
    try {
      await _db.removeFromWatchLater(videoId);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to remove from watch later: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  // ============================================================
  // Play Positions
  // ============================================================

  Future<Result<Duration?>> getPlayPosition(String videoId) async {
    try {
      final record = await _db.getPlayPosition(videoId);
      return Success(
          record != null ? Duration(milliseconds: record.positionMs) : null);
    } catch (e) {
      return FailureResult(
        'Failed to get position: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<Map<String, Duration>>> getPlayPositions(
    Iterable<String> videoIds,
  ) async {
    try {
      return Success(await _db.getPlayPositions(videoIds));
    } catch (e) {
      return FailureResult(
        'Failed to get positions: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  Future<Result<void>> savePlayPosition(
      String videoId, Duration position) async {
    try {
      await _db.savePlayPosition(videoId, position);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        'Failed to save position: $e',
        type: FailureType.database,
        cause: e,
      );
    }
  }

  // ============================================================
  // Mappers (FIXED: typed, not dynamic)
  // ============================================================

  MediaItem _historyToMediaItem(WatchHistoryTableData record) {
    final durationMs = record.durationMs;
    final positionMs = record.positionMs;
    return MediaItem(
      videoId: record.videoId,
      title: record.title,
      author: record.author,
      channelId: record.channelId,
      thumbnailUrl: record.thumbnailUrl,
      duration: Duration(milliseconds: durationMs),
      publishedAt: record.watchedAt,
      formats: const [],
      subtitles: const [],
      chapters: const [],
      // FIXED: protect against zero duration (e.g., live streams)
      percentWatched: (positionMs > 0 && durationMs > 0)
          ? ((positionMs * 100) ~/ durationMs).clamp(0, 100)
          : null,
    );
  }

  MediaItem _favoriteToMediaItem(FavoritesTableData record) {
    return MediaItem(
      videoId: record.videoId,
      title: record.title,
      author: record.author,
      channelId: record.channelId,
      thumbnailUrl: record.thumbnailUrl,
      duration: Duration(milliseconds: record.durationMs),
      publishedAt: record.addedAt,
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );
  }

  MediaItem _watchLaterToMediaItem(WatchLaterTableData record) {
    return MediaItem(
      videoId: record.videoId,
      title: record.title,
      author: record.author,
      channelId: record.channelId,
      thumbnailUrl: record.thumbnailUrl,
      duration: Duration(milliseconds: record.durationMs),
      publishedAt: record.addedAt,
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );
  }

  LocalSubscription _subscriptionFromRecord(
      LocalSubscriptionsTableData record) {
    return LocalSubscription(
      channelId: record.channelId,
      title: record.title,
      avatarUrl: record.avatarUrl,
      subscriberCount: record.subscriberCount,
      subscribedAt: record.subscribedAt,
    );
  }
}

/// Plain DTO for subscriptions (UI-friendly)
// Re-exported from domain/repositories/local_library_repository.dart
