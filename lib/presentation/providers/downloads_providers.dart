// ============================================================
// Downloads — offline library state
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';
import '../../data/local/database/drift_download_store.dart';
import '../../domain/entities/media_item.dart';
import '../../services/download_manager.dart';
import 'player_providers.dart';
import 'repository_providers.dart';

export '../../services/download_manager.dart'
    show DownloadFailure, DownloadProgress, DownloadStatus;

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    DriftDownloadStore(ref.watch(appDatabaseProvider)),
    NetworkDownloadSource(ref.watch(streamResolverProvider)),
  );
  // Whatever an app kill left half-written is not resumable without the
  // job behind it, and would otherwise sit in the sandbox forever.
  unawaited(manager.pruneOrphans());
  ref.onDispose(manager.dispose);
  return manager;
});

/// In-flight downloads, keyed by video id. The manager replays its
/// current snapshot to every new listener, so a screen opened while a
/// download is running is populated on its first frame.
final activeDownloadsProvider =
    StreamProvider<Map<String, DownloadProgress>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.progressStream;
});

/// Progress for one video (null when nothing is in flight for it).
final downloadForVideoProvider =
    Provider.family<AsyncValue<DownloadProgress?>, String>((ref, videoId) {
  return ref.watch(activeDownloadsProvider).whenData((map) => map[videoId]);
});

/// Everything already saved for offline playback.
final savedDownloadsProvider =
    StreamProvider.autoDispose<List<DownloadTableData>>((ref) {
  return ref.watch(appDatabaseProvider).watchDownloads();
});

/// True when the video has a completed offline copy.
final isDownloadedProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, videoId) {
  return ref
      .watch(appDatabaseProvider)
      .watchDownloads()
      .map((rows) => rows.any((r) => r.videoId == videoId));
});

/// How the offline library is ordered. Newest first is the default: the
/// reason to open this screen is usually the thing just downloaded.
enum DownloadSort { newest, oldest, largest, title }

final downloadSortProvider =
    StateProvider<DownloadSort>((ref) => DownloadSort.newest);

/// Bytes the offline library occupies on disk, partial transfers
/// included.
///
/// Recomputed when the library changes or a transfer changes state —
/// deliberately not on every progress tick, which would stat every file
/// in the directory four times a second for the length of a download.
final downloadStorageUsedProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref
    ..watch(savedDownloadsProvider)
    ..watch(
      activeDownloadsProvider.select(
        (value) => value.whenData(
          (map) =>
              map.entries.map((e) => '${e.key}:${e.value.status}').join(','),
        ),
      ),
    );
  return ref.watch(downloadManagerProvider).storageUsed();
});

/// Thin controller so widgets don't touch the manager directly.
class DownloadsController extends StateNotifier<void> {
  DownloadsController(this._ref, this._manager) : super(null);

  final Ref _ref;
  final DownloadManager _manager;

  Future<void> download(MediaItem item, {int? height}) =>
      _manager.download(item, height: height);
  Future<void> pause(String videoId) => _manager.pause(videoId);
  Future<void> resume(MediaItem item) => _manager.resume(item);
  Future<void> retry(MediaItem item) => _manager.retry(item);
  Future<void> cancel(String videoId) => _manager.cancel(videoId);

  /// Deleting the copy that is playing right now is allowed — the
  /// player is stopped first so mpv is not left reading a file that no
  /// longer has a name.
  Future<void> remove(String videoId) async {
    await _ref
        .read(playerControllerProvider.notifier)
        .handleDownloadRemoved(videoId);
    await _manager.remove(videoId);
  }

  /// Resolutions this video can be saved at, for the quality sheet.
  Future<List<int>> availableHeights(String videoId) =>
      _manager.availableHeights(videoId);
}

final downloadsControllerProvider =
    StateNotifierProvider<DownloadsController, void>((ref) {
  return DownloadsController(ref, ref.watch(downloadManagerProvider));
});
