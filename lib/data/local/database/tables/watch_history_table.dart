// ============================================================
// WatchHistoryTable (FIXED: no primary key on videoId)
// ============================================================
// كل مشاهدة تُسجَّل كصف جديد — يعيد المشاهدة نفس الفيديو تظهر
// في القائمة أكثر من مرة.
// ============================================================

import 'package:drift/drift.dart';

@DataClassName('WatchHistoryTableData')
class WatchHistoryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get channelId => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get watchedAt => dateTime()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'watch_history';
}
