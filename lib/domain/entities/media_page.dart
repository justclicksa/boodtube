// ============================================================
// MediaPage - one page of a feed, plus how to get the next
// ============================================================
// A MediaGroup is a *shelf*: it has a title and a type because the UI
// draws it as a section. A continuation has neither — it is just the
// next slice of a feed that was already opened — so paging speaks in
// MediaPage and the caller appends the items to whatever it is holding.
// ============================================================

import 'media_item.dart';

class MediaPage {
  const MediaPage({required this.items, this.nextPageToken});

  final List<MediaItem> items;

  /// Opaque; hand it straight back to `ContentRepository.loadMore`.
  /// Null when the feed is exhausted.
  final String? nextPageToken;

  bool get hasMore => nextPageToken != null && nextPageToken!.isNotEmpty;

  static const empty = MediaPage(items: <MediaItem>[]);

  MediaPage copyWith({List<MediaItem>? items, String? nextPageToken}) =>
      MediaPage(
        items: items ?? this.items,
        nextPageToken: nextPageToken ?? this.nextPageToken,
      );
}
