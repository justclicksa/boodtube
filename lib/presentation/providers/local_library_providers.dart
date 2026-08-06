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

/// The first element, or null for an empty or absent iterable.
T? _firstOrNull<T>(Iterable<T>? items) {
  if (items == null) return null;
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

/// Which library action failed, so the UI can word its message.
enum LibraryAction {
  like,
  removeLike,
  dislike,
  watchLater,
  subscribe,
  unsubscribe
}

/// A library action that could not be completed. The local change has
/// already been rolled back by the time this appears — it exists so the
/// UI can say so rather than leave a button lying.
class LibraryActionFailure {
  const LibraryActionFailure({
    required this.action,
    required this.message,
    this.cause,
  });

  final LibraryAction action;
  final String message;
  final Object? cause;

  @override
  String toString() => 'LibraryActionFailure($action, $message)';
}

/// The last failed library action, or null when the last one worked.
///
/// Watch it to show a snackbar; set it back to null once shown.
final libraryActionErrorProvider =
    StateProvider<LibraryActionFailure?>((ref) => null);

class LibraryActions {
  const LibraryActions(this._repo, this._remote, this._ref);
  final LocalLibraryRepository _repo;

  /// Mirrors the action to the signed-in account. Local state is always
  /// updated first so the UI responds even when signed out or offline.
  final AuthenticatedInnerTubeClient _remote;

  final Ref _ref;

  Future<void> toggleFavorite(MediaItem item) async {
    _clearError();
    final current = await _repo.isFavorite(item.videoId);
    final wasFavorite = current.dataOrNull ?? false;
    if (wasFavorite) {
      await _repo.removeFromFavorites(item.videoId);
      await _mirror(
        LibraryAction.removeLike,
        'Could not remove the like from your YouTube account',
        () => _remote.removeLike(item.videoId),
        () => _repo.addToFavorites(item),
      );
    } else {
      await _repo.addToFavorites(item);
      await _mirror(
        LibraryAction.like,
        'Could not like this video on your YouTube account',
        () => _remote.like(item.videoId),
        () => _repo.removeFromFavorites(item.videoId),
      );
    }
  }

  /// Dislikes on YouTube. There is no local counterpart — the app only
  /// tracks likes — so this removes any local like to stay consistent.
  Future<void> dislike(String videoId) async {
    _clearError();
    // Kept so the like can be put back if YouTube refuses the dislike.
    final favorites = (await _repo.getFavorites()).dataOrNull;
    final previous = _firstOrNull(
      favorites?.where((item) => item.videoId == videoId),
    );

    await _repo.removeFromFavorites(videoId);
    await _mirror(
      LibraryAction.dislike,
      'Could not dislike this video on your YouTube account',
      () => _remote.dislike(videoId),
      () async {
        if (previous != null) await _repo.addToFavorites(previous);
      },
    );
  }

  /// Watch Later is local-only, so there is nothing to mirror — but the
  /// write itself can still fail, and silently doing nothing is exactly
  /// the failure mode this reports.
  Future<void> toggleWatchLater(MediaItem item) async {
    _clearError();
    final current = await _repo.getWatchLater();
    final saved =
        current.dataOrNull?.any((v) => v.videoId == item.videoId) ?? false;
    final result = saved
        ? await _repo.removeFromWatchLater(item.videoId)
        : await _repo.addToWatchLater(item);
    result.when(
      success: (_) {},
      failure: (message, type, cause) => _report(
        LibraryActionFailure(
          action: LibraryAction.watchLater,
          message: message,
          cause: cause,
        ),
      ),
    );
  }

  Future<void> toggleSubscription(
    String channelId,
    String title, {
    String? avatarUrl,
  }) async {
    _clearError();
    final current = await _repo.isSubscribed(channelId);
    final wasSubscribed = current.dataOrNull ?? false;
    if (wasSubscribed) {
      final existing = _firstOrNull(
        (await _repo.getSubscriptions())
            .dataOrNull
            ?.where((s) => s.channelId == channelId),
      );
      await _repo.unsubscribe(channelId);
      await _mirror(
        LibraryAction.unsubscribe,
        'Could not unsubscribe on your YouTube account',
        () => _remote.unsubscribe(channelId),
        () => _repo.subscribe(
          channelId: channelId,
          title: existing?.title ?? title,
          avatarUrl: existing?.avatarUrl ?? avatarUrl,
          subscriberCount: existing?.subscriberCount,
        ),
      );
    } else {
      await _repo.subscribe(
        channelId: channelId,
        title: title,
        avatarUrl: avatarUrl,
      );
      await _mirror(
        LibraryAction.subscribe,
        'Could not subscribe on your YouTube account',
        () => _remote.subscribe(channelId),
        () => _repo.unsubscribe(channelId),
      );
    }
  }

  /// Sends a local change on to YouTube and undoes it locally when the
  /// account rejects it.
  ///
  /// Signed out is not a failure: the whole library works offline, and
  /// there is simply nothing to mirror to. Only a real refusal — a
  /// non-200, a thrown request — rolls the local change back.
  Future<void> _mirror(
    LibraryAction action,
    String message,
    Future<bool> Function() send,
    Future<void> Function() rollback,
  ) async {
    if (!await _remote.isSignedIn()) return;

    Object? cause;
    var accepted = false;
    try {
      accepted = await send();
    } catch (e) {
      cause = e;
    }
    if (accepted) return;

    await rollback();
    _report(
      LibraryActionFailure(action: action, message: message, cause: cause),
    );
  }

  void _report(LibraryActionFailure failure) {
    _ref.read(libraryActionErrorProvider.notifier).state = failure;
  }

  void _clearError() {
    _ref.read(libraryActionErrorProvider.notifier).state = null;
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
    ref,
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
