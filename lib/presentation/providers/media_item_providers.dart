// ============================================================
// MediaItem Providers (Single video operations)
// ============================================================
// FutureProviders للحصول على media item واحد + تحميل streams.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';

/// Get full media item by videoId
final mediaItemProvider =
    FutureProvider.autoDispose.family<MediaItem, String>((ref, videoId) async {
  final repo = ref.watch(mediaItemRepositoryProvider);
  final result = await repo.getMediaItem(videoId);

  return result.when(
    success: (item) => item,
    failure: (message, type, cause) {
      throw Exception(message);
    },
  );
});

/// Get subtitles
final subtitlesProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, videoId) async {
  final repo = ref.watch(mediaItemRepositoryProvider);
  final result = await repo.getSubtitles(videoId);
  return result.dataOrNull ?? [];
});

/// Get chapters
final chaptersProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, videoId) async {
  final repo = ref.watch(mediaItemRepositoryProvider);
  final result = await repo.getChapters(videoId);
  return result.dataOrNull ?? [];
});
