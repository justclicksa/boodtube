// ============================================================
// LocalLibraryRepository - Domain interface (FIXED: was missing)
// ============================================================
// Drives: History, Favorites, Watch Later, Local Subscriptions
// ============================================================

import '../entities/media_item.dart';
import '../../core/utils/result.dart';

class LocalSubscription {
  final String channelId;
  final String title;
  final String? avatarUrl;
  final int? subscriberCount;
  final DateTime subscribedAt;

  const LocalSubscription({
    required this.channelId,
    required this.title,
    this.avatarUrl,
    this.subscriberCount,
    required this.subscribedAt,
  });
}

abstract interface class LocalLibraryRepository {
  // History
  Future<Result<List<MediaItem>>> getWatchHistory({int limit = 50});
  Future<Result<void>> addToHistory(MediaItem item, {Duration? position});
  Future<Result<void>> clearHistory();

  // Favorites
  Future<Result<List<MediaItem>>> getFavorites();
  Future<Result<bool>> isFavorite(String videoId);
  Future<Result<void>> addToFavorites(MediaItem item);
  Future<Result<void>> removeFromFavorites(String videoId);

  // Watch Later
  Future<Result<List<MediaItem>>> getWatchLater();
  Future<Result<void>> addToWatchLater(MediaItem item);
  Future<Result<void>> removeFromWatchLater(String videoId);

  // Subscriptions
  Future<Result<List<LocalSubscription>>> getSubscriptions();
  Future<Result<bool>> isSubscribed(String channelId);
  Future<Result<void>> subscribe({
    required String channelId,
    required String title,
    String? avatarUrl,
    int? subscriberCount,
  });
  Future<Result<void>> unsubscribe(String channelId);

  // Play positions
  Future<Result<Duration?>> getPlayPosition(String videoId);
  Future<Result<void>> savePlayPosition(String videoId, Duration position);
}
