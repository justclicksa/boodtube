// ============================================================
// DownloadManager — offline copies of videos
// ============================================================
// Downloads go through the same sliced-range logic the player uses:
// googlevideo refuses open-ended requests, so a plain `dio.download`
// fails. Video and audio are stored separately (that is how YouTube
// serves anything above 360p) and reunited at playback time.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local/database/app_database.dart';
import '../data/youtube/stream_resolver.dart';
import '../core/network/stream_proxy.dart';
import '../domain/entities/media_format.dart';
import '../domain/entities/media_item.dart';

enum DownloadStatus { queued, downloading, completed, failed }

/// Live progress for one download. Completed downloads live in the
/// database instead — this only tracks in-flight work.
class DownloadProgress {
  const DownloadProgress({
    required this.videoId,
    required this.title,
    required this.status,
    this.progress = 0,
    this.error,
  });

  final String videoId;
  final String title;
  final DownloadStatus status;
  final double progress;
  final String? error;

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
  }) {
    return DownloadProgress(
      videoId: videoId,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class DownloadManager {
  DownloadManager(this._db, this._resolver, this._proxy);

  final AppDatabase _db;
  final StreamResolver _resolver;
  final StreamProxy _proxy;

  final Map<String, DownloadProgress> _active = {};
  final _controller =
      StreamController<Map<String, DownloadProgress>>.broadcast();
  final Map<String, bool> _cancelled = {};

  Stream<Map<String, DownloadProgress>> get progressStream =>
      _controller.stream;

  Map<String, DownloadProgress> get active => Map.unmodifiable(_active);

  /// A download in flight outlives dispose() — it is a plain Future, not
  /// something the container can cancel — so it keeps reporting progress
  /// into a controller that is already closed and throws "Cannot add new
  /// events after calling close" over a torn-down app.
  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(Map.of(_active));
  }

  /// Downloads [item] at [quality] for offline playback. Returns when the
  /// files are on disk and recorded in the database.
  Future<void> download(
    MediaItem item, {
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) async {
    final videoId = item.videoId;
    if (_active[videoId]?.status == DownloadStatus.downloading) return;

    _cancelled.remove(videoId);
    _active[videoId] = DownloadProgress(
      videoId: videoId,
      title: item.title,
      status: DownloadStatus.downloading,
    );
    _emit();

    try {
      await _proxy.start();
      final resolved = await _resolver.getBestStream(
        videoId,
        quality: quality,
        probe: _proxy.probe,
      );

      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}'
          '/downloads');
      if (!dir.existsSync()) await dir.create(recursive: true);

      // Video is the bulk of the bytes; weight progress accordingly.
      final videoPath = '${dir.path}/$videoId.video';
      final videoBytes = await _fetchToFile(
        Uri.parse(resolved.videoUrl),
        File(videoPath),
        videoId,
        (p) => _report(videoId, p * (resolved.audioUrl == null ? 1.0 : 0.85)),
      );

      String? audioPath;
      var audioBytes = 0;
      if (resolved.audioUrl != null && resolved.audioUrl!.isNotEmpty) {
        audioPath = '${dir.path}/$videoId.audio';
        audioBytes = await _fetchToFile(
          Uri.parse(resolved.audioUrl!),
          File(audioPath),
          videoId,
          (p) => _report(videoId, 0.85 + p * 0.15),
        );
      }

      if (_cancelled[videoId] ?? false) {
        await _deleteFiles(videoPath, audioPath);
        _active.remove(videoId);
        _emit();
        return;
      }

      await _db.saveDownload(
        DownloadsTableCompanion.insert(
          videoId: videoId,
          title: item.title,
          author: item.author,
          channelId: item.channelId,
          thumbnailUrl: Value(item.thumbnailUrl),
          durationMs: item.duration.inMilliseconds,
          videoPath: videoPath,
          audioPath: Value(audioPath),
          qualityLabel: Value(resolved.qualityLabel),
          totalBytes: Value(videoBytes + audioBytes),
          downloadedAt: DateTime.now(),
        ),
      );

      _active[videoId] = _active[videoId]!
          .copyWith(status: DownloadStatus.completed, progress: 1);
      _emit();
    } catch (e) {
      debugPrint('download[$videoId] failed: $e');
      _active[videoId] = (_active[videoId] ??
              DownloadProgress(
                videoId: videoId,
                title: item.title,
                status: DownloadStatus.failed,
              ))
          .copyWith(status: DownloadStatus.failed, error: e.toString());
      _emit();
    }
  }

  void _report(String videoId, double progress) {
    final current = _active[videoId];
    if (current == null) return;
    _active[videoId] = current.copyWith(progress: progress.clamp(0, 1));
    _emit();
  }

  /// Streams [url] into [file] using the proxy's slice negotiation.
  Future<int> _fetchToFile(
    Uri url,
    File file,
    String videoId,
    void Function(double progress) onProgress,
  ) async {
    final sink = file.openWrite();
    var written = 0;
    try {
      final int total = await _proxy.contentLength(url);
      await for (final chunk in _proxy.readAll(url)) {
        if (_cancelled[videoId] ?? false) break;
        sink.add(chunk);
        written += chunk.length;
        if (total > 0) onProgress(written / total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return written;
  }

  Future<void> cancel(String videoId) async {
    _cancelled[videoId] = true;
    _active.remove(videoId);
    _emit();
  }

  /// Removes the offline copy and its database row.
  Future<void> remove(String videoId) async {
    final row = await _db.getDownload(videoId);
    if (row != null) {
      await _deleteFiles(row.videoPath, row.audioPath);
    }
    await _db.deleteDownload(videoId);
    _active.remove(videoId);
    _emit();
  }

  Future<void> _deleteFiles(String videoPath, String? audioPath) async {
    for (final path in [videoPath, if (audioPath != null) audioPath]) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
  }

  void dispose() => _controller.close();
}
