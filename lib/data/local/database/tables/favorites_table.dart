// ============================================================
// FavoritesTable
// ============================================================

import 'package:drift/drift.dart';

@DataClassName('FavoritesTableData')
class FavoritesTable extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get channelId => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}
