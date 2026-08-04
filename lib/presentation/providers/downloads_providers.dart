// ============================================================
// Downloads — offline library state
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';
import '../../domain/entities/media_item.dart';
import '../../services/download_manager.dart';
import 'repository_providers.dart';

export '../../services/download_manager.dart'
    show DownloadProgress, DownloadStatus;

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    ref.watch(appDatabaseProvider),
    ref.watch(streamResolverProvider),
    ref.watch(streamProxyProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// In-flight downloads, keyed by video id.
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

/// Thin controller so widgets don't touch the manager directly.
class DownloadsController extends StateNotifier<void> {
  DownloadsController(this._manager) : super(null);
  final DownloadManager _manager;

  Future<void> download(MediaItem item) => _manager.download(item);
  Future<void> cancel(String videoId) => _manager.cancel(videoId);
  Future<void> remove(String videoId) => _manager.remove(videoId);
}

final downloadsControllerProvider =
    StateNotifierProvider<DownloadsController, void>((ref) {
  return DownloadsController(ref.watch(downloadManagerProvider));
});
