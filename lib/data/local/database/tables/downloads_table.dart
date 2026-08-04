import 'package:drift/drift.dart';

/// Videos saved for offline playback. Video and audio are stored as two
/// files because YouTube serves high resolutions as separate adaptive
/// streams — the player attaches the audio track the same way it does
/// when streaming.
@DataClassName('DownloadTableData')
class DownloadsTable extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get channelId => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationMs => integer()();
  TextColumn get videoPath => text()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get qualityLabel => text().nullable()();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}
