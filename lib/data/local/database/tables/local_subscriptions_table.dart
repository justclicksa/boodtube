// ============================================================
// LocalSubscriptionsTable
// ============================================================

import 'package:drift/drift.dart';

@DataClassName('LocalSubscriptionsTableData')
class LocalSubscriptionsTable extends Table {
  TextColumn get channelId => text()();
  TextColumn get title => text()();
  TextColumn get avatarUrl => text().nullable()();
  IntColumn get subscriberCount => integer().nullable()();
  DateTimeColumn get subscribedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {channelId};
}
