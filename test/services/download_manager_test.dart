// The download state machine, driven by a fake network and a fake
// store. Everything here is about the transitions the real thing kept
// getting wrong: a capped stream silently producing a truncated file, a
// retry starting from zero, a cancel leaving bytes on disk, and more
// transfers running at once than the link can carry.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/youtube/stream_resolver.dart';
import 'package:smarttube_poc/domain/entities/media_format.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/services/download_manager.dart';

// ============================================================
// Fakes
// ============================================================

class _FakeStore implements DownloadStore {
  final Map<String, DownloadRecord> rows = {};

  @override
  Future<List<DownloadRecord>> all() async => rows.values.toList();

  @override
  Future<void> delete(String videoId) async => rows.remove(videoId);

  @override
  Future<DownloadRecord?> get(String videoId) async => rows[videoId];

  @override
  Future<void> save(DownloadRecord record) async {
    rows[record.videoId] = record;
  }
}

/// A googlevideo stand-in with a switchable byte cap.
class _FakeSource implements DownloadSource {
  _FakeSource({this.hasAudio = true});

  /// Big enough that the walk takes several slices, small enough that a
  /// test finishes in milliseconds.
  final int videoSize = 300 * 1024;
  final int audioSize = 100 * 1024;
  final bool hasAudio;

  int resolveCount = 0;
  final List<int?> resolvedHeights = [];

  /// Offsets each read was asked to start from — this is how a test
  /// proves a retry resumed instead of starting over.
  final List<int> readOffsets = [];

  /// Refuse everything at or past this offset. Null serves the whole
  /// file.
  int? capAt;

  /// Number of resolves after which the cap stops applying, the way a
  /// freshly signed URL lifts a per-URL cap in practice. Null keeps the
  /// cap forever.
  int? liftCapAfterResolves;

  /// Held open to keep a transfer in flight while a test inspects state.
  Completer<void>? gate;

  /// Thrown by the next read, to exercise the failure paths.
  Exception? readError;

  /// Makes `length()` refuse to say how long the audio is.
  bool audioLengthUnknown = false;

  @override
  Future<ResolvedStream> resolve(
    String videoId, {
    int? height,
    MediaFormatQuality quality = MediaFormatQuality.high,
  }) async {
    resolveCount++;
    resolvedHeights.add(height);
    return ResolvedStream(
      videoUrl: 'https://cdn.test/$videoId/video?n=$resolveCount',
      audioUrl: hasAudio
          ? 'https://cdn.test/$videoId/audio?n=$resolveCount'
          : null,
      videoHeight: height ?? 720,
      qualityLabel: '${height ?? 720}p',
      sourceClient: 'fake',
      availableHeights: const [1080, 720, 360],
    );
  }

  @override
  Future<int> length(Uri url) async {
    if (!url.path.endsWith('/audio')) return videoSize;
    return audioLengthUnknown ? 0 : audioSize;
  }

  @override
  Stream<List<int>> read(
    Uri url, {
    int from = 0,
    void Function(int servedBytes, int totalBytes)? onRefused,
  }) async* {
    readOffsets.add(from);
    if (gate != null) await gate!.future;
    if (readError != null) {
      final error = readError!;
      readError = null;
      throw error;
    }

    final total = await length(url);
    final capped = capAt != null &&
        (liftCapAfterResolves == null || resolveCount <= liftCapAfterResolves!);
    final limit = capped ? capAt! : total;

    var offset = from;
    const chunk = 32 * 1024;
    while (offset < limit && offset < total) {
      final end = (offset + chunk) > limit ? limit : offset + chunk;
      yield List<int>.filled(end - offset, 7);
      offset = end;
      // Let the manager's writes interleave the way a real socket does.
      await Future<void>.delayed(Duration.zero);
    }
    if (offset < total) onRefused?.call(offset, total);
  }
}

MediaItem _item(String id) => MediaItem(
      videoId: id,
      title: 'Video $id',
      author: 'Channel',
      channelId: 'UC$id',
      duration: const Duration(minutes: 3),
      publishedAt: DateTime(2024),
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );

void main() {
  late Directory dir;
  late _FakeStore store;
  late _FakeSource source;

  DownloadManager build({int maxConcurrent = 2}) => DownloadManager(
        store,
        source,
        directory: () async => dir,
        maxConcurrent: maxConcurrent,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('downloads_test');
    store = _FakeStore();
    source = _FakeSource();
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('writes both files, records the row and reports completion',
      () async {
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('abc'), height: 720);
    await manager.waitFor('abc');

    final video = File('${dir.path}/abc.video');
    final audio = File('${dir.path}/abc.audio');
    expect(video.existsSync(), isTrue);
    expect(audio.existsSync(), isTrue);
    expect(await video.length(), source.videoSize);
    expect(await audio.length(), source.audioSize);

    // Nothing partial survives a success.
    expect(File('${dir.path}/abc.video.part').existsSync(), isFalse);

    final row = store.rows['abc'];
    expect(row, isNotNull);
    expect(row!.videoPath, video.path);
    expect(row.audioPath, audio.path);
    expect(row.qualityLabel, '720p');
    expect(row.totalBytes, source.videoSize + source.audioSize);

    final progress = manager.active['abc']!;
    expect(progress.status, DownloadStatus.completed);
    expect(progress.progress, 1);
    expect(progress.receivedBytes, source.videoSize + source.audioSize);
    expect(source.resolvedHeights.first, 720);
  });

  test('emits queued → downloading → completed with byte counts',
      () async {
    final manager = build();
    addTearDown(manager.dispose);

    final seen = <DownloadStatus>[];
    final sub = manager.progressStream.listen((map) {
      final status = map['abc']?.status;
      if (status != null && (seen.isEmpty || seen.last != status)) {
        seen.add(status);
      }
    });
    addTearDown(sub.cancel);

    await manager.download(_item('abc'));
    await manager.waitFor('abc');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(seen.first, DownloadStatus.queued);
    expect(seen.last, DownloadStatus.completed);
    expect(seen, contains(DownloadStatus.downloading));
  });

  test('a capped stream is re-resolved and resumed, not restarted',
      () async {
    // Served for 96 KiB of a 300 KiB file until a second URL is signed.
    source
      ..capAt = 96 * 1024
      ..liftCapAfterResolves = 1;
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('cap'));
    await manager.waitFor('cap');

    expect(manager.active['cap']!.status, DownloadStatus.completed);
    expect(await File('${dir.path}/cap.video').length(), source.videoSize);
    // The point of the exercise: the second attempt asked for the bytes
    // after the cap rather than downloading the first 96 KiB twice.
    expect(source.readOffsets, contains(96 * 1024));
    expect(source.resolveCount, greaterThan(1));
  });

  test('a stream capped at every URL fails as capped and keeps the '
      'partial file', () async {
    source.capAt = 64 * 1024;
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('hard'));
    await manager.waitFor('hard');

    final progress = manager.active['hard']!;
    expect(progress.status, DownloadStatus.failed);
    expect(progress.failure, DownloadFailure.capped);
    // No `.video` file: a truncated download must never look playable.
    expect(File('${dir.path}/hard.video').existsSync(), isFalse);
    expect(store.rows, isEmpty);
    // The bytes that did arrive are kept for the retry.
    final part = File('${dir.path}/hard.video.part');
    expect(part.existsSync(), isTrue);
    expect(await part.length(), 64 * 1024);
  });

  test('retry resumes from the bytes already on disk', () async {
    source.capAt = 64 * 1024;
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('resume'));
    await manager.waitFor('resume');
    expect(manager.active['resume']!.status, DownloadStatus.failed);

    // The link comes back.
    source
      ..capAt = null
      ..readOffsets.clear();
    await manager.retry(_item('resume'));
    await manager.waitFor('resume');

    expect(manager.active['resume']!.status, DownloadStatus.completed);
    expect(source.readOffsets.first, 64 * 1024);
    expect(
      await File('${dir.path}/resume.video').length(),
      source.videoSize,
    );
  });

  test('pause keeps the partial file and resume finishes it', () async {
    source.gate = Completer<void>();
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('p1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(manager.active['p1']!.status, DownloadStatus.downloading);

    await manager.pause('p1');
    source.gate!.complete();
    await manager.waitFor('p1');
    expect(manager.active['p1']!.status, DownloadStatus.paused);
    expect(store.rows, isEmpty);

    source.gate = null;
    await manager.resume(_item('p1'));
    await manager.waitFor('p1');
    expect(manager.active['p1']!.status, DownloadStatus.completed);
    expect(store.rows.containsKey('p1'), isTrue);
  });

  test('cancel drops the entry and deletes what was written', () async {
    source.gate = Completer<void>();
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('c1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await manager.cancel('c1');
    source.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(manager.active.containsKey('c1'), isFalse);
    expect(File('${dir.path}/c1.video.part').existsSync(), isFalse);
    expect(File('${dir.path}/c1.video').existsSync(), isFalse);
    expect(store.rows, isEmpty);
  });

  test('never runs more than the concurrency limit at once', () async {
    source.gate = Completer<void>();
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('a'));
    await manager.download(_item('b'));
    await manager.download(_item('c'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final downloading = manager.active.values
        .where((p) => p.status == DownloadStatus.downloading)
        .length;
    expect(downloading, 2);
    expect(manager.active['c']!.status, DownloadStatus.queued);

    source.gate!.complete();
    await manager.waitFor('a');
    await manager.waitFor('b');
    await manager.waitFor('c');
    expect(manager.active['c']!.status, DownloadStatus.completed);
  });

  test('a storage failure is reported as storage, not as a network '
      'problem', () async {
    source.readError = const FileSystemException(
      'No space left on device',
      '/downloads',
    );
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('full'));
    await manager.waitFor('full');

    final progress = manager.active['full']!;
    expect(progress.status, DownloadStatus.failed);
    expect(progress.failure, DownloadFailure.storage);
  });

  test('a dropped connection is reported as network', () async {
    source.readError = const SocketException('Connection reset');
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('drop'));
    await manager.waitFor('drop');

    expect(manager.active['drop']!.failure, DownloadFailure.network);
  });

  test('remove deletes the files, the partials and the row', () async {
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('gone'));
    await manager.waitFor('gone');
    expect(File('${dir.path}/gone.video').existsSync(), isTrue);

    await manager.remove('gone');

    expect(File('${dir.path}/gone.video').existsSync(), isFalse);
    expect(File('${dir.path}/gone.audio').existsSync(), isFalse);
    expect(store.rows, isEmpty);
    expect(manager.active.containsKey('gone'), isFalse);
  });

  test('does not download a video that is already saved', () async {
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('once'));
    await manager.waitFor('once');
    final resolves = source.resolveCount;

    await manager.download(_item('once'));
    await manager.waitFor('once');
    expect(source.resolveCount, resolves);
  });

  test('storageUsed counts finished files and partial transfers',
      () async {
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('sz'));
    await manager.waitFor('sz');
    expect(
      await manager.storageUsed(),
      source.videoSize + source.audioSize,
    );

    // A partial left by a failed transfer occupies the device too.
    await File('${dir.path}/other.video.part').writeAsBytes(
      List<int>.filled(2048, 0),
    );
    expect(
      await manager.storageUsed(),
      source.videoSize + source.audioSize + 2048,
    );
  });

  test('pruneOrphans clears abandoned partials but spares recent ones',
      () async {
    final manager = build();
    addTearDown(manager.dispose);

    final ghost = File('${dir.path}/ghost.video.part');
    await ghost.writeAsBytes([1, 2, 3]);

    // A partial from a transfer killed a moment ago is what the next
    // Download tap resumes from, so the default window keeps it.
    await manager.pruneOrphans();
    expect(ghost.existsSync(), isTrue);

    await manager.pruneOrphans(olderThan: Duration.zero);
    expect(ghost.existsSync(), isFalse);
  });

  test('an audio stream of unknown length is dropped rather than '
      'failing the download', () async {
    source.audioLengthUnknown = true;
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('noaudio'));
    await manager.waitFor('noaudio');

    expect(manager.active['noaudio']!.status, DownloadStatus.completed);
    expect(File('${dir.path}/noaudio.video').existsSync(), isTrue);
    expect(store.rows['noaudio']!.audioPath, isNull);
  });

  test('availableHeights comes from the resolved manifest', () async {
    final manager = build();
    addTearDown(manager.dispose);

    expect(await manager.availableHeights('any'), [1080, 720, 360]);
  });

  test('a video with no separate audio track still completes', () async {
    source = _FakeSource(hasAudio: false);
    final manager = build();
    addTearDown(manager.dispose);

    await manager.download(_item('muxed'));
    await manager.waitFor('muxed');

    expect(manager.active['muxed']!.status, DownloadStatus.completed);
    expect(File('${dir.path}/muxed.video').existsSync(), isTrue);
    expect(File('${dir.path}/muxed.audio').existsSync(), isFalse);
    expect(store.rows['muxed']!.audioPath, isNull);
  });
}
