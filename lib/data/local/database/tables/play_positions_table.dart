// ============================================================
// PlayPositionsTable
// ============================================================

import 'package:drift/drift.dart';

@DataClassName('PlayPositionsTableData')
class PlayPositionsTable extends Table {
  TextColumn get videoId => text()();
  IntColumn get positionMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}
