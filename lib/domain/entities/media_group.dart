// ============================================================
// MediaGroup - Pure Dart Entity
// ============================================================
// مجموعة من MediaItems (مثل "الترند"، "نتائج البحث"، "قناة X")
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

import 'media_item.dart';

part 'media_group.freezed.dart';

/// Type of the media group (للتمييز بين الـ shelves)
enum MediaGroupType {
  home,
  trending,
  subscriptions,
  search,
  channel,
  channelVideos,
  playlist,
  history,
  recommended,
  shorts,
  live,
  continueWatching,
  watchLater,
}

@freezed
class MediaGroup with _$MediaGroup {
  const factory MediaGroup({
    required String title,
    required MediaGroupType type,
    required List<MediaItem> mediaItems,
    String? nextPageToken,
    String? channelId,
    String? thumbnailUrl,
  }) = _MediaGroup;

  const MediaGroup._();

  /// Is there more to load?
  bool get hasMore => nextPageToken != null && nextPageToken!.isNotEmpty;

  /// Empty group helper
  static MediaGroup empty() => const MediaGroup(
        title: '',
        type: MediaGroupType.home,
        mediaItems: [],
      );
}
