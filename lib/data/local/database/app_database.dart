// ============================================================
// AppDatabase - Drift database (FIXED: streams + delete history item)
// ============================================================

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/downloads_table.dart';
import 'tables/watch_history_table.dart';
import 'tables/local_subscriptions_table.dart';
import 'tables/favorites_table.dart';
import 'tables/watch_later_table.dart';
import 'tables/play_positions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  WatchHistoryTable,
  LocalSubscriptionsTable,
  FavoritesTable,
  WatchLaterTable,
  PlayPositionsTable,
  DownloadsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2: drop old history table, recreate with new schema
          if (from < 2) {
            await m.deleteTable('watch_history');
            await m.createTable(watchHistoryTable);
          }
          // v2 -> v3: offline downloads
          if (from < 3) {
            await m.createTable(downloadsTable);
          }
        },
      );

  // ============================================================
  // Downloads
  // ============================================================

  Stream<List<DownloadTableData>> watchDownloads() {
    return (select(downloadsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)]))
        .watch();
  }

  Future<DownloadTableData?> getDownload(String videoId) {
    return (select(downloadsTable)..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
  }

  Future<void> saveDownload(DownloadsTableCompanion entry) {
    return into(downloadsTable).insertOnConflictUpdate(entry);
  }

  Future<void> deleteDownload(String videoId) {
    return (delete(downloadsTable)..where((t) => t.videoId.equals(videoId)))
        .go();
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smarttube_db');
  }

  // ============================================================
  // Watch History (FIXED: real stream + delete item)
  // ============================================================

  /// Stream of recent history (UI updates automatically)
  Stream<List<WatchHistoryTableData>> watchRecentHistory({int limit = 50}) {
    return (select(watchHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.watchedAt)])
          ..limit(limit))
        .watch();
  }

  Future<List<WatchHistoryTableData>> getRecentHistory({int limit = 50}) {
    return (select(watchHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.watchedAt)])
          ..limit(limit))
        .get();
  }

  Future<int> addToHistory(WatchHistoryTableCompanion entry) {
    return into(watchHistoryTable).insert(entry);
  }

  Future<int> deleteHistoryItem(String videoId) {
    return (delete(watchHistoryTable)
          ..where((t) => t.videoId.equals(videoId)))
        .go();
  }

  Future<int> clearHistory() {
    return delete(watchHistoryTable).go();
  }

  // ============================================================
  // Local Subscriptions (FIXED: real stream)
  // ============================================================

  Stream<List<LocalSubscriptionsTableData>> watchAllSubscriptions() {
    return (select(localSubscriptionsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  Future<List<LocalSubscriptionsTableData>> getAllSubscriptions() {
    return (select(localSubscriptionsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
  }

  Future<bool> isSubscribed(String channelId) async {
    final result = await (select(localSubscriptionsTable)
          ..where((t) => t.channelId.equals(channelId)))
        .getSingleOrNull();
    return result != null;
  }

  Future<int> addSubscription(LocalSubscriptionsTableCompanion entry) {
    return into(localSubscriptionsTable).insertOnConflictUpdate(entry);
  }

  Future<int> removeSubscription(String channelId) {
    return (delete(localSubscriptionsTable)
          ..where((t) => t.channelId.equals(channelId)))
        .go();
  }

  // ============================================================
  // Favorites (FIXED: real stream)
  // ============================================================

  Stream<List<FavoritesTableData>> watchFavorites() {
    return (select(favoritesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .watch();
  }

  Future<List<FavoritesTableData>> getFavorites() {
    return (select(favoritesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<bool> isFavorite(String videoId) async {
    final result = await (select(favoritesTable)
          ..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
    return result != null;
  }

  Future<int> addToFavorites(FavoritesTableCompanion entry) {
    return into(favoritesTable).insertOnConflictUpdate(entry);
  }

  Future<int> removeFromFavorites(String videoId) {
    return (delete(favoritesTable)..where((t) => t.videoId.equals(videoId))).go();
  }

  // ============================================================
  // Watch Later (FIXED: real stream)
  // ============================================================

  Stream<List<WatchLaterTableData>> watchWatchLater() {
    return (select(watchLaterTable)
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .watch();
  }

  Future<List<WatchLaterTableData>> getWatchLater() {
    return (select(watchLaterTable)
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<int> addToWatchLater(WatchLaterTableCompanion entry) {
    return into(watchLaterTable).insertOnConflictUpdate(entry);
  }

  Future<int> removeFromWatchLater(String videoId) {
    return (delete(watchLaterTable)..where((t) => t.videoId.equals(videoId))).go();
  }

  // ============================================================
  // Play Positions
  // ============================================================

  Future<PlayPositionsTableData?> getPlayPosition(String videoId) {
    return (select(playPositionsTable)
          ..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
  }

  Future<int> savePlayPosition(String videoId, Duration position) {
    return into(playPositionsTable).insertOnConflictUpdate(
      PlayPositionsTableCompanion.insert(
        videoId: videoId,
        positionMs: position.inMilliseconds,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
