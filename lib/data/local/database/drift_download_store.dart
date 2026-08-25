// ============================================================
// DriftDownloadStore — DownloadManager's persistence, over Drift
// ============================================================
// The manager talks to a narrow interface rather than to AppDatabase so
// its state machine can be tested without a native sqlite3 in the test
// VM. This is the one place that knows about the generated row types.
// ============================================================

import 'package:drift/drift.dart' show Value;

import '../../../services/download_manager.dart';
import 'app_database.dart';

class DriftDownloadStore implements DownloadStore {
  const DriftDownloadStore(this._db);

  final AppDatabase _db;

  @override
  Future<DownloadRecord?> get(String videoId) async {
    final row = await _db.getDownload(videoId);
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<List<DownloadRecord>> all() async {
    final rows = await _db.getDownloads();
    return rows.map(_toRecord).toList();
  }

  @override
  Future<void> save(DownloadRecord record) {
    return _db.saveDownload(
      DownloadsTableCompanion.insert(
        videoId: record.videoId,
        title: record.title,
        author: record.author,
        channelId: record.channelId,
        thumbnailUrl: Value(record.thumbnailUrl),
        durationMs: record.durationMs,
        videoPath: record.videoPath,
        audioPath: Value(record.audioPath),
        qualityLabel: Value(record.qualityLabel),
        totalBytes: Value(record.totalBytes),
        downloadedAt: record.downloadedAt,
      ),
    );
  }

  @override
  Future<void> delete(String videoId) => _db.deleteDownload(videoId);

  static DownloadRecord _toRecord(DownloadTableData row) => DownloadRecord(
        videoId: row.videoId,
        title: row.title,
        author: row.author,
        channelId: row.channelId,
        thumbnailUrl: row.thumbnailUrl,
        durationMs: row.durationMs,
        videoPath: row.videoPath,
        audioPath: row.audioPath,
        qualityLabel: row.qualityLabel,
        totalBytes: row.totalBytes,
        downloadedAt: row.downloadedAt,
      );
}
