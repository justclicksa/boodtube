// ============================================================
// LocalLibrary Providers (FIXED: use public mapper functions)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smarttube_poc/data/local/database/app_database.dart';
import 'package:smarttube_poc/data/youtube/authenticated_client.dart';
import 'package:smarttube_poc/presentation/providers/auth_providers.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/repositories/local_library_repository.dart'
    show LocalLibraryRepository, LocalSubscription;
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';

/// Helper to map WatchHistoryTableData to MediaItem
MediaItem _mapHistoryRecord(WatchHistoryTableData record) {
  final durationMs = record.durationMs;
  final positionMs = record.positionMs;
  return MediaItem(
    videoId: record.videoId,
    title: record.title,
    author: record.author,
    channelId: record.channelId,
    thumbnailUrl: record.thumbnailUrl,
    duration: Duration(milliseconds: durationMs),
    // History rows only know when the row was written, which for entries
    // pulled from the account is "when we synced" — showing that as the
    // video's age labelled everything "just now". The list is already
    // ordered by watchedAt in SQL, so the card simply omits the date.
    publishedAt: MediaItem.unknownDate,
    formats: const [],
    subtitles: const [],
    chapters: const [],
    percentWatched: (positionMs > 0 && durationMs > 0)
        ? ((positionMs * 100) ~/ durationMs).clamp(0, 100)
        : null,
  );
}

MediaItem _mapFavoriteRecord(FavoritesTableData record) {
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

MediaItem _mapWatchLaterRecord(WatchLaterTableData record) {
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

LocalSubscription _mapSubscriptionRecord(LocalSubscriptionsTableData record) {
  return LocalSubscription(
    channelId: record.channelId,
    title: record.title,
    avatarUrl: record.avatarUrl,
    subscriberCount: record.subscriberCount,
    subscribedAt: record.subscribedAt,
  );
}

/// Watch History stream
final watchHistoryProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRecentHistory().map((records) {
    return records.map(_mapHistoryRecord).toList();
  });
});

/// Favorites stream
final favoritesProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavorites().map((records) {
    return records.map(_mapFavoriteRecord).toList();
  });
});

/// Watch Later stream
final watchLaterProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchWatchLater().map((records) {
    return records.map(_mapWatchLaterRecord).toList();
  });
});

/// Subscriptions stream
final subscriptionsProvider =
    StreamProvider.autoDispose<List<LocalSubscription>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllSubscriptions().map((records) {
    return records.map(_mapSubscriptionRecord).toList();
  });
});

// ============================================================
// Membership checks — derived from the streams above so any write
// updates every screen showing the state without manual refreshes.
// ============================================================

final isFavoriteProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, videoId) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .watchFavorites()
      .map((rows) => rows.any((r) => r.videoId == videoId));
});

final isWatchLaterProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, videoId) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .watchWatchLater()
      .map((rows) => rows.any((r) => r.videoId == videoId));
});

final isSubscribedProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, channelId) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .watchAllSubscriptions()
      .map((rows) => rows.any((r) => r.channelId == channelId));
});

// ============================================================
// Toggle actions used by the player and channel screens.
// ============================================================

class LibraryActions {
  const LibraryActions(this._repo, this._remote);
  final LocalLibraryRepository _repo;

  /// Mirrors the action to the signed-in account. Local state is always
  /// updated first so the UI responds even when signed out or offline.
  final AuthenticatedInnerTubeClient _remote;

  Future<void> toggleFavorite(MediaItem item) async {
    final current = await _repo.isFavorite(item.videoId);
    final wasFavorite = current.dataOrNull ?? false;
    if (wasFavorite) {
      await _repo.removeFromFavorites(item.videoId);
      await _remote.removeLike(item.videoId);
    } else {
      await _repo.addToFavorites(item);
      await _remote.like(item.videoId);
    }
  }

  /// Dislikes on YouTube. There is no local counterpart — the app only
  /// tracks likes — so this removes any local like to stay consistent.
  Future<void> dislike(String videoId) async {
    await _repo.removeFromFavorites(videoId);
    await _remote.dislike(videoId);
  }

  Future<void> toggleWatchLater(MediaItem item) async {
    final current = await _repo.getWatchLater();
    final saved =
        current.dataOrNull?.any((v) => v.videoId == item.videoId) ?? false;
    if (saved) {
      await _repo.removeFromWatchLater(item.videoId);
    } else {
      await _repo.addToWatchLater(item);
    }
  }

  Future<void> toggleSubscription(
    String channelId,
    String title, {
    String? avatarUrl,
  }) async {
    final current = await _repo.isSubscribed(channelId);
    if (current.dataOrNull ?? false) {
      await _repo.unsubscribe(channelId);
      await _remote.unsubscribe(channelId);
    } else {
      await _repo.subscribe(
        channelId: channelId,
        title: title,
        avatarUrl: avatarUrl,
      );
      await _remote.subscribe(channelId);
    }
  }

  /// Pulls the account's real subscriptions into the local table so the
  /// Subscriptions tab shows them. No-op when signed out.
  Future<int> syncSubscriptions() async {
    final channels = await _remote.getSubscribedChannels();
    if (channels == null) return 0;
    for (final channel in channels) {
      await _repo.subscribe(
        channelId: channel.channelId,
        title: channel.title,
        avatarUrl: channel.avatarUrl,
      );
    }
    return channels.length;
  }
}

final libraryActionsProvider = Provider<LibraryActions>((ref) {
  return LibraryActions(
    ref.watch(localLibraryRepositoryProvider),
    ref.watch(authenticatedClientProvider),
  );
});

/// Pulls the account's channels the first time the Subscriptions screen
/// is shown with an empty local list. Before this the list only filled
/// after an explicit tap on Sync, so a freshly signed-in account looked
/// like it had no subscriptions at all.
final autoSyncSubscriptionsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  final existing = await ref.watch(subscriptionsProvider.future);
  if (existing.isNotEmpty) return existing.length;
  return ref.read(libraryActionsProvider).syncSubscriptions();
});

/// Brings the account's watch history — and with it the resume position
/// of anything watched on another device — into the local tables.
final historySyncProviderRefresh =
    FutureProvider.autoDispose<int?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  return ref.read(historySyncProvider).pull();
});
