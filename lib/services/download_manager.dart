// ============================================================
// DownloadManager — offline copies of videos
// ============================================================
// Downloads go through the same sliced-range logic the player uses
// (core/network/range_fetcher.dart): googlevideo refuses open-ended
// requests, so a plain `dio.download` fails, and some URLs are served
// for only the first few MiB whatever slice size is used. When that
// happens the manager re-resolves the video and resumes from the byte
// it stopped at instead of leaving a truncated file behind.
//
// Video and audio are stored as separate files (that is how YouTube
// serves anything above 360p) and reunited at playback time.
//
// Bytes land in `<documents>/downloads/<id>.video.part` first and are
// renamed on success, so a half-finished transfer is never mistaken for
// a playable file — and is exactly what a resume picks up from.
//
// No "download finished" system notification: nothing already in
// pubspec.yaml can post one. audio_service owns a notification, but it
// is the media session's transport controls and is tied to what is
// playing — reusing it would replace the now-playing notification with
// a download message. Posting an arbitrary local notification needs a
// new dependency (flutter_local_notifications), which is out of scope
// here; the Downloads screen and the player pill both report progress
// while the app is open.
// ============================================================

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/range_fetcher.dart';
import '../data/youtube/stream_resolver.dart';
import '../domain/entities/media_format.dart';
import '../domain/entities/media_item.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

/// Why a download stopped, so the UI can say something better than the
/// exception's toString().
enum DownloadFailure {
  /// The transfer could not be started or kept alive.
  network,

  /// The device refused the write — full disk, or a sandbox problem.
  storage,

  /// googlevideo served the first few MiB of every URL it offered for
  /// this video and then refused, at every quality tried.
  capped,

  /// YouTube offers no playable stream for the video at all.
  unavailable,

  unknown,
}

/// Live state of one download. Completed downloads live in the database
/// as well; this is what the in-flight rows and the pill render from.
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.videoId,
    required this.title,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.qualityHeight,
    this.error,
    this.failure,
  });

  final String videoId;
  final String title;
  final DownloadStatus status;

  /// Bytes on disk for this video so far, video and audio together.
  final int receivedBytes;

  /// Expected size of both files, or 0 before the streams are resolved.
  final int totalBytes;

  /// Rolling transfer rate over the last second or so.
  final double bytesPerSecond;

  final int? qualityHeight;
  final String? error;
  final DownloadFailure? failure;

  /// 0..1, or null while the total is still unknown — a determinate bar
  /// sitting at zero reads as a stalled download rather than a starting
  /// one, so the UI shows an indeterminate bar for null.
  double? get progress {
    if (status == DownloadStatus.completed) return 1;
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Time left at the current rate, or null when it cannot be guessed.
  Duration? get eta {
    if (bytesPerSecond <= 0 || totalBytes <= 0) return null;
    final remaining = totalBytes - receivedBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / bytesPerSecond).round());
  }

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  DownloadProgress copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    int? qualityHeight,
    String? error,
    DownloadFailure? failure,
    bool clearError = false,
  }) {
    return DownloadProgress(
      videoId: videoId,
      title: title,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      qualityHeight: qualityHeight ?? this.qualityHeight,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
    );
  }
}

/// A finished offline copy, as the manager sees it. Mirrors the Drift row
/// without dragging generated database types into the service layer — the
/// point being that the state machine can be tested against a map.
@immutable
class DownloadRecord {
  const DownloadRecord({
    required this.videoId,
    required this.title,
    required this.author,
    required this.channelId,
    required this.durationMs,
    required this.videoPath,
    required this.downloadedAt,
    this.thumbnailUrl,
    this.audioPath,
    this.qualityLabel,
    this.totalBytes = 0,
  });

  final String videoId;
  final String title;
  final String author;
  final String channelId;
  final String? thumbnailUrl;
  final int durationMs;
  final String videoPath;
  final String? audioPath;
  final String? qualityLabel;
  final int totalBytes;
  final DateTime downloadedAt;
}

/// Where finished downloads are recorded. Implemented over Drift in
/// data/local/database/drift_download_store.dart.
abstract class DownloadStore {
  Future<DownloadRecord?> get(String videoId);
  Future<void> save(DownloadRecord record);
  Future<void> delete(String videoId);
  Future<List<DownloadRecord>> all();
}

/// The network half of a download, behind an interface so the state
/// machine can be exercised without touching googlevideo.
abstract class DownloadSource {
  /// Resolves fresh signed URLs. Called again mid-transfer when a URL
  /// stops being served, which is how a capped stream gets past the cap.
  Future<ResolvedStream> resolve(
    String videoId, {
    int? height,
    MediaFormatQuality quality = MediaFormatQuality.high,
  });

  /// Reads [url] from byte [from] onwards. [onRefused] is called with the
  /// offset reached when the server stops serving early, after which the
  /// stream ends without an error.
  Stream<List<int>> read(
    Uri url, {
    int from = 0,
    void Function(int servedBytes, int totalBytes)? onRefused,
  });

  /// Total size of [url], or 0 when the server won't say.
  Future<int> length(Uri url);
}

/// Real implementation: youtube_explode for the URLs, RangeFetcher for
/// the bytes.
class NetworkDownloadSource implements DownloadSource {
  NetworkDownloadSource(this._resolver, {RangeFetcher? fetcher})
      // Its own fetcher, not the player's: a download that has stepped
      // the slice ladder down to 64 KiB must not slow playback with it,
      // and the two would otherwise fight over the connection pool.
      : _fetcher = fetcher ?? RangeFetcher(maxConnectionsPerHost: 4);

  final StreamResolver _resolver;
  final RangeFetcher _fetcher;

  @override
  Future<ResolvedStream> resolve(
    String videoId, {
    int? height,
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) {
    return _resolver.getBestStream(
      videoId,
      quality: quality,
      exactHeight: height,
      probe: _fetcher.probe,
    );
  }

  @override
  Stream<List<int>> read(
    Uri url, {
    int from = 0,
    void Function(int servedBytes, int totalBytes)? onRefused,
  }) {
    return _fetcher.read(url, from: from, onRefused: onRefused);
  }

  @override
  Future<int> length(Uri url) => _fetcher.contentLength(url);

  void dispose() => _fetcher.close();
}

/// Thrown internally when the server stops serving part-way through a
/// file. Carries the offset so the retry resumes rather than restarts.
class _StalledAt implements Exception {
  const _StalledAt(this.offset);
  final int offset;
}

class _Job {
  _Job(this.item, this.height, this.quality);

  final MediaItem item;
  final int? height;
  final MediaFormatQuality quality;
  final Completer<void> done = Completer<void>();
  bool cancelled = false;
  bool paused = false;
}

class DownloadManager {
  DownloadManager(
    this._store,
    this._source, {
    Future<Directory> Function()? directory,
    this.maxConcurrent = 2,
  }) : _directory = directory ?? _defaultDirectory;

  final DownloadStore _store;
  final DownloadSource _source;
  final Future<Directory> Function() _directory;

  /// Two at a time. More does not make the link faster — googlevideo
  /// throttles per stream, not per client — and each extra transfer
  /// steals slices from whatever is playing.
  final int maxConcurrent;

  /// How many times a stalled file is re-resolved before giving up. Each
  /// attempt gets a brand new signed URL and resumes from the byte the
  /// last one stopped at, so four attempts clear a cap far bigger than
  /// the one measured on real videos.
  static const int maxStallRecoveries = 4;

  final Map<String, DownloadProgress> _active = {};
  final Queue<_Job> _queue = Queue<_Job>();
  final Map<String, _Job> _jobs = {};
  final Set<String> _running = {};

  final _controller =
      StreamController<Map<String, DownloadProgress>>.broadcast();

  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _emitTimer;
  bool _disposed = false;

  /// Snapshot first, then updates: a screen that opens while a download
  /// is already running must not sit blank until the next slice lands.
  ///
  /// `Stream.multi` rather than an `async*` bridge on purpose — an
  /// `async*` generator only subscribes to the inner stream after its
  /// first yield has been delivered, so every update emitted in that
  /// gap is dropped. Here the subscription is attached synchronously on
  /// listen, and nothing between subscribing and the first slice is
  /// lost.
  Stream<Map<String, DownloadProgress>> get progressStream {
    return Stream.multi((listener) {
      listener.add(Map.of(_active));
      final subscription = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener
        ..onCancel = subscription.cancel
        ..onPause = subscription.pause
        ..onResume = subscription.resume;
    });
  }

  Map<String, DownloadProgress> get active => Map.unmodifiable(_active);

  static Future<Directory> _defaultDirectory() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/downloads',
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // ============================================================
  // Queue
  // ============================================================

  /// Queues [item] for offline playback and returns as soon as it is
  /// queued — the caller gets to show "Download started" immediately
  /// rather than after the whole file. Await [waitFor] for completion.
  ///
  /// [height] is the exact resolution picked in the quality sheet; null
  /// falls back to [quality].
  Future<void> download(
    MediaItem item, {
    int? height,
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) async {
    final videoId = item.videoId;
    if (_disposed) return;
    final existing = _active[videoId];
    if (existing != null &&
        (existing.isActive || existing.status == DownloadStatus.completed)) {
      return;
    }
    if (await _store.get(videoId) != null) return;

    final job = _Job(item, height, quality);
    _jobs[videoId] = job;
    _queue.add(job);
    _active[videoId] = DownloadProgress(
      videoId: videoId,
      title: item.title,
      status: DownloadStatus.queued,
      qualityHeight: height,
    );
    _emit(force: true);
    unawaited(_pump());
  }

  /// Completes when the download for [videoId] leaves the queue, however
  /// it leaves it. Returns immediately when nothing is queued for it.
  Future<void> waitFor(String videoId) =>
      _jobs[videoId]?.done.future ?? Future<void>.value();

  Future<void> _pump() async {
    while (!_disposed && _running.length < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (job.cancelled) {
        _finish(job);
        continue;
      }
      _running.add(job.item.videoId);
      unawaited(
        _run(job).whenComplete(() {
          _running.remove(job.item.videoId);
          unawaited(_pump());
        }),
      );
    }
  }

  void _finish(_Job job) {
    if (!job.done.isCompleted) job.done.complete();
  }

  // ============================================================
  // One download
  // ============================================================

  Future<void> _run(_Job job) async {
    final videoId = job.item.videoId;
    final quality = job.quality;
    _update(
      videoId,
      (p) => p.copyWith(
        status: DownloadStatus.downloading,
        clearError: true,
      ),
    );

    Directory dir;
    try {
      dir = await _directory();
    } catch (e) {
      _fail(videoId, DownloadFailure.storage, e);
      _finish(job);
      return;
    }

    final videoPart = File('${dir.path}/$videoId.video.part');
    final audioPart = File('${dir.path}/$videoId.audio.part');

    try {
      var resolved = await _source.resolve(
        videoId,
        height: job.height,
        quality: quality,
      );

      final videoUrl = Uri.parse(resolved.videoUrl);
      final videoTotal = await _source.length(videoUrl);
      var audioUrl = resolved.audioUrl == null || resolved.audioUrl!.isEmpty
          ? null
          : Uri.parse(resolved.audioUrl!);
      final audioTotal = audioUrl == null ? 0 : await _source.length(audioUrl);

      if (videoTotal <= 0) {
        throw const _Unavailable('stream size unknown');
      }
      if (audioUrl != null && audioTotal <= 0) {
        // The server would not say how long the audio is, so there is
        // nothing to walk and nothing to resume. A silent video is a
        // worse outcome than a muxed-quality one, but a download that
        // fails outright is worse than both.
        debugPrint('download[$videoId]: audio length unknown, '
            'saving video only');
        audioUrl = null;
      }

      _update(
        videoId,
        (p) => p.copyWith(
          totalBytes: videoTotal + audioTotal,
          qualityHeight: resolved.videoHeight,
        ),
      );

      // Bytes already on disk from an earlier attempt count towards the
      // bar from the first frame, otherwise a resumed 400 MB download
      // appears to start over.
      final meter = _RateMeter();
      final carried = await _partLength(videoPart);
      _update(videoId, (p) => p.copyWith(receivedBytes: carried));

      final videoBytes = await _fetchFile(
        job: job,
        url: videoUrl,
        part: videoPart,
        expectedTotal: videoTotal,
        meter: meter,
        base: 0,
        reResolve: () async {
          resolved = await _source.resolve(
            videoId,
            height: resolved.videoHeight,
            quality: quality,
          );
          return Uri.parse(resolved.videoUrl);
        },
      );
      if (job.cancelled || job.paused) {
        await _stopped(job, videoPart, audioPart);
        _finish(job);
        return;
      }

      var audioBytes = 0;
      if (audioUrl != null) {
        audioBytes = await _fetchFile(
          job: job,
          url: audioUrl,
          part: audioPart,
          expectedTotal: audioTotal,
          meter: meter,
          base: videoBytes,
          reResolve: () async {
            resolved = await _source.resolve(
              videoId,
              height: resolved.videoHeight,
              quality: quality,
            );
            final refreshed = resolved.audioUrl;
            if (refreshed == null || refreshed.isEmpty) {
              throw const _Unavailable('audio stream disappeared');
            }
            return audioUrl = Uri.parse(refreshed);
          },
        );
        if (job.cancelled || job.paused) {
          await _stopped(job, videoPart, audioPart);
          _finish(job);
          return;
        }
      }

      // Rename only now: a `.video` file existing at all is the promise
      // that it is complete and playable.
      final videoPath = '${dir.path}/$videoId.video';
      // Windows refuses a rename onto an existing name; a leftover from
      // an interrupted earlier run would otherwise fail the download at
      // the very last step.
      await _deleteQuietly(File(videoPath));
      await videoPart.rename(videoPath);
      String? audioPath;
      if (audioUrl != null) {
        audioPath = '${dir.path}/$videoId.audio';
        await _deleteQuietly(File(audioPath));
        await audioPart.rename(audioPath);
      }

      await _store.save(
        DownloadRecord(
          videoId: videoId,
          title: job.item.title,
          author: job.item.author,
          channelId: job.item.channelId,
          thumbnailUrl: job.item.thumbnailUrl,
          durationMs: job.item.duration.inMilliseconds,
          videoPath: videoPath,
          audioPath: audioPath,
          qualityLabel: resolved.qualityLabel,
          totalBytes: videoBytes + audioBytes,
          downloadedAt: DateTime.now(),
        ),
      );

      _update(
        videoId,
        (p) => p.copyWith(
          status: DownloadStatus.completed,
          receivedBytes: videoBytes + audioBytes,
          totalBytes: videoBytes + audioBytes,
          bytesPerSecond: 0,
          clearError: true,
        ),
      );
    } catch (e) {
      if (job.cancelled || job.paused) {
        await _stopped(job, videoPart, audioPart);
      } else {
        debugPrint('download[$videoId] failed: $e');
        _fail(videoId, _classify(e), e);
      }
    } finally {
      _finish(job);
    }
  }

  /// Streams one file to disk, resuming from whatever is already there
  /// and re-resolving the URL when googlevideo stops serving it.
  ///
  /// Returns the number of bytes the finished file holds.
  Future<int> _fetchFile({
    required _Job job,
    required Uri url,
    required File part,
    required int expectedTotal,
    required _RateMeter meter,
    required int base,
    required Future<Uri> Function() reResolve,
  }) async {
    var current = url;
    var offset = await _partLength(part);
    if (offset > expectedTotal) {
      // A previous attempt wrote a file for a different rendition. It
      // cannot be resumed into this one.
      await _deleteQuietly(part);
      offset = 0;
    }

    for (var attempt = 0; attempt <= maxStallRecoveries; attempt++) {
      if (offset >= expectedTotal) return expectedTotal;
      if (job.cancelled || job.paused) return offset;

      final startedAt = offset;
      try {
        offset = await _appendFrom(
          job: job,
          url: current,
          part: part,
          from: offset,
          expectedTotal: expectedTotal,
          meter: meter,
          base: base,
        );
        if (job.cancelled || job.paused) return offset;
        if (offset >= expectedTotal) return offset;
        // Ended without an explicit refusal and without finishing.
        throw _StalledAt(offset);
      } on _StalledAt catch (stall) {
        offset = stall.offset;
        if (attempt == maxStallRecoveries) {
          throw const _Capped('upstream refused the rest of the stream');
        }
        if (offset == startedAt && attempt > 0) {
          // Two attempts in a row moved nothing: a fresh URL is not
          // going to help, this rendition is capped at this byte.
          throw const _Capped('upstream served no further bytes');
        }
        debugPrint('download: stalled at $offset/$expectedTotal, '
            're-resolving (attempt ${attempt + 1})');
        await Future<void>.delayed(Duration(seconds: attempt + 1));
        if (job.cancelled || job.paused) return offset;
        current = await reResolve();
      }
    }
    return offset;
  }

  /// One pass over the network into [part], appending from [from].
  /// Returns the new file length. Throws [_StalledAt] on early refusal.
  Future<int> _appendFrom({
    required _Job job,
    required Uri url,
    required File part,
    required int from,
    required int expectedTotal,
    required _RateMeter meter,
    required int base,
  }) async {
    IOSink? sink;
    var written = from;
    int? refusedAt;
    try {
      sink = part.openWrite(
        mode: from > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      );
      final stream = _source.read(
        url,
        from: from,
        onRefused: (served, _) => refusedAt = served,
      );
      await for (final chunk in stream) {
        if (job.cancelled || job.paused) break;
        sink.add(chunk);
        written += chunk.length;
        meter.add(chunk.length);
        _update(
          job.item.videoId,
          (p) => p.copyWith(
            receivedBytes: base + written,
            bytesPerSecond: meter.bytesPerSecond,
          ),
        );
      }
      // A full disk surfaces here, not on add(): IOSink buffers, and the
      // write error is only delivered when the sink is drained.
      await sink.flush();
      await sink.close();
      sink = null;
    } on FileSystemException catch (e) {
      throw _StorageError(e);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
    }

    final onDisk = await _partLength(part);
    if (job.cancelled || job.paused) return onDisk;
    if (refusedAt != null && onDisk < expectedTotal) {
      throw _StalledAt(onDisk);
    }
    return onDisk;
  }

  Future<int> _partLength(File file) async {
    try {
      return file.existsSync() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Controls
  // ============================================================

  /// Stops the download and keeps the partial file, so resuming picks up
  /// where it left off instead of re-downloading.
  Future<void> pause(String videoId) async {
    final job = _jobs[videoId];
    if (job == null) return;
    job.paused = true;
    _queue.removeWhere((queued) => identical(queued, job));
    _update(
      videoId,
      (p) => p.copyWith(
        status: DownloadStatus.paused,
        bytesPerSecond: 0,
      ),
    );
    _emit(force: true);
  }

  /// Re-queues a paused or failed download. The partial file on disk is
  /// resumed with a Range request rather than started over.
  Future<void> resume(
    MediaItem item, {
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) async {
    final videoId = item.videoId;
    final previous = _active[videoId];
    if (previous != null && previous.isActive) return;
    final height = previous?.qualityHeight ?? _jobs[videoId]?.height;
    _jobs.remove(videoId);
    _active[videoId] = (previous ??
            DownloadProgress(
              videoId: videoId,
              title: item.title,
              status: DownloadStatus.queued,
            ))
        .copyWith(
      status: DownloadStatus.queued,
      bytesPerSecond: 0,
      clearError: true,
    );
    _emit(force: true);
    final job = _Job(item, height, quality);
    _jobs[videoId] = job;
    _queue.add(job);
    unawaited(_pump());
  }

  /// Alias of [resume] — a failed download and a paused one both carry a
  /// partial file, and both continue from it.
  Future<void> retry(
    MediaItem item, {
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) =>
      resume(item, quality: quality);

  /// Abandons the download and deletes anything already written.
  Future<void> cancel(String videoId) async {
    final job = _jobs[videoId];
    if (job != null) {
      job.cancelled = true;
      _queue.removeWhere((queued) => identical(queued, job));
    }
    _active.remove(videoId);
    _emit(force: true);
    if (job != null && !_running.contains(videoId)) {
      await _deletePartials(videoId);
      _finish(job);
      _jobs.remove(videoId);
    }
  }

  /// Removes the offline copy, its partial files and its database row.
  Future<void> remove(String videoId) async {
    await cancel(videoId);
    final row = await _store.get(videoId);
    if (row != null) {
      await _deleteQuietly(File(row.videoPath));
      if (row.audioPath != null) {
        await _deleteQuietly(File(row.audioPath!));
      }
    }
    await _store.delete(videoId);
    await _deletePartials(videoId);
    _active.remove(videoId);
    _emit(force: true);
  }

  /// Total bytes the offline library occupies, partial transfers included
  /// — the footer has to account for the space actually taken, not only
  /// for what finished.
  Future<int> storageUsed() async {
    var total = 0;
    for (final row in await _store.all()) {
      total += await _sizeOf(row.videoPath);
      if (row.audioPath != null) total += await _sizeOf(row.audioPath!);
    }
    try {
      final dir = await _directory();
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.part')) {
          total += await _partLength(entity);
        }
      }
    } catch (_) {
      // Directory not created yet, or unreadable: the row sizes stand.
    }
    return total;
  }

  /// Deletes `.part` files with no job behind them — what an app killed
  /// mid-download leaves behind. Safe to call at startup.
  ///
  /// Only ones older than [olderThan], because a partial file is not
  /// junk: tapping Download again resumes from it. A kill mid-transfer
  /// should cost the user nothing if they come back the same week; a
  /// partial nobody has returned to in that time is abandoned.
  Future<void> pruneOrphans({
    Duration olderThan = const Duration(days: 7),
  }) async {
    try {
      final dir = await _directory();
      final cutoff = DateTime.now().subtract(olderThan);
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.part')) continue;
        final name = entity.uri.pathSegments.last;
        final videoId = name.split('.').first;
        if (_jobs.containsKey(videoId)) continue;
        if ((await entity.lastModified()).isAfter(cutoff)) continue;
        await _deleteQuietly(entity);
      }
    } catch (_) {}
  }

  /// The resolutions this video can be saved at, for the quality sheet.
  Future<List<int>> availableHeights(String videoId) async {
    final resolved = await _source.resolve(videoId);
    return resolved.availableHeights;
  }

  Future<int> _sizeOf(String path) async {
    final file = File(path);
    return _partLength(file);
  }

  Future<void> _stopped(_Job job, File videoPart, File audioPart) async {
    final videoId = job.item.videoId;
    if (job.cancelled) {
      await _deleteQuietly(videoPart);
      await _deleteQuietly(audioPart);
      _active.remove(videoId);
      _jobs.remove(videoId);
    } else {
      _update(
        videoId,
        (p) => p.copyWith(
          status: DownloadStatus.paused,
          bytesPerSecond: 0,
        ),
      );
    }
    _emit(force: true);
  }

  Future<void> _deletePartials(String videoId) async {
    try {
      final dir = await _directory();
      await _deleteQuietly(File('${dir.path}/$videoId.video.part'));
      await _deleteQuietly(File('${dir.path}/$videoId.audio.part'));
    } catch (_) {}
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  // ============================================================
  // State plumbing
  // ============================================================

  void _update(
    String videoId,
    DownloadProgress Function(DownloadProgress current) transform,
  ) {
    final current = _active[videoId];
    if (current == null) return;
    final next = transform(current);
    _active[videoId] = next;
    // Byte counts can be coalesced — nobody reads a bar 40 times a
    // second. A status change is a different row entirely, so it is
    // never held back by the throttle.
    _emit(force: next.status != current.status);
  }

  void _fail(String videoId, DownloadFailure failure, Object error) {
    final current = _active[videoId];
    if (current == null) return;
    _active[videoId] = current.copyWith(
      status: DownloadStatus.failed,
      bytesPerSecond: 0,
      failure: failure,
      error: error.toString(),
    );
    _emit(force: true);
  }

  static DownloadFailure _classify(Object error) {
    if (error is _Capped) return DownloadFailure.capped;
    if (error is _StorageError) return DownloadFailure.storage;
    if (error is _Unavailable) return DownloadFailure.unavailable;
    if (error is FileSystemException) return DownloadFailure.storage;
    if (error is SocketException || error is HttpException) {
      return DownloadFailure.network;
    }
    if (error is TimeoutException) return DownloadFailure.network;
    final message = error.toString().toLowerCase();
    if (message.contains('no space') || message.contains('enospc')) {
      return DownloadFailure.storage;
    }
    if (message.contains('failed to resolve') ||
        message.contains('unavailable')) {
      return DownloadFailure.unavailable;
    }
    return DownloadFailure.unknown;
  }

  /// Progress arrives a slice at a time; forwarding every one of them
  /// rebuilds the list far more often than a human can read it. Status
  /// changes still go out immediately.
  void _emit({bool force = false}) {
    if (_disposed || _controller.isClosed) return;
    final now = DateTime.now();
    const window = Duration(milliseconds: 250);
    if (force || now.difference(_lastEmit) >= window) {
      _emitTimer?.cancel();
      _emitTimer = null;
      _lastEmit = now;
      _controller.add(Map.of(_active));
      return;
    }
    _emitTimer ??= Timer(const Duration(milliseconds: 250), () {
      _emitTimer = null;
      if (_disposed || _controller.isClosed) return;
      _lastEmit = DateTime.now();
      _controller.add(Map.of(_active));
    });
  }

  /// A download in flight outlives dispose() — it is a plain Future, not
  /// something the container can cancel — so without the guard it keeps
  /// reporting into a closed controller and throws "Cannot add new events
  /// after calling close" over a torn-down app.
  void dispose() {
    _disposed = true;
    _emitTimer?.cancel();
    for (final job in _jobs.values) {
      // Paused, not cancelled: the app is going away and the bytes
      // already written are what a later resume picks up from. A cancel
      // here would delete them on every app exit.
      job.paused = true;
      _finish(job);
    }
    _queue.clear();
    _controller.close();
    final source = _source;
    if (source is NetworkDownloadSource) source.dispose();
  }
}

/// Rolling transfer rate. A whole-download average is useless while the
/// link is changing, which on a phone is most of the time.
class _RateMeter {
  int _windowBytes = 0;
  DateTime _windowStart = DateTime.now();
  double bytesPerSecond = 0;

  void add(int bytes) {
    _windowBytes += bytes;
    final elapsed = DateTime.now().difference(_windowStart);
    if (elapsed < const Duration(milliseconds: 700)) return;
    bytesPerSecond = _windowBytes / (elapsed.inMilliseconds / 1000);
    _windowBytes = 0;
    _windowStart = DateTime.now();
  }
}

class _Capped implements Exception {
  const _Capped(this.message);
  final String message;
  @override
  String toString() => 'stream-capped: $message';
}

class _Unavailable implements Exception {
  const _Unavailable(this.message);
  final String message;
  @override
  String toString() => 'stream-unavailable: $message';
}

class _StorageError implements Exception {
  const _StorageError(this.cause);
  final Object cause;
  @override
  String toString() => 'storage-error: $cause';
}
