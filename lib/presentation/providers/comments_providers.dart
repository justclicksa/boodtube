// ============================================================
// Comments providers
// ============================================================
// The section is paged the same way every other feed here is: an
// AsyncNotifier holding the pages loaded so far plus the token for the
// next one, so a failed `loadMore()` never destroys what is already on
// screen. Replies are their own one-shot family, keyed by the thread's
// continuation token — a thread nobody expanded costs nothing.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smarttube_poc/domain/entities/comment_item.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';

/// Which order the user last asked for, per video. Held outside the
/// notifier so flipping it rebuilds the section from scratch — a
/// re-sorted section is a different list, not more of the same one.
final commentsSortProvider =
    StateProvider.autoDispose.family<CommentSort, String>(
  (ref, videoId) => CommentSort.top,
);

/// The comments loaded so far, plus what is known about the rest.
class CommentsFeed {
  const CommentsFeed({
    required this.items,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.totalCountText,
    this.sort = CommentSort.top,
  });

  final List<CommentItem> items;
  final bool hasMore;
  final bool isLoadingMore;

  /// The last failed `loadMore()`, reported under the list instead of
  /// replacing it.
  final Object? loadMoreError;

  /// The section total as YouTube formatted it, when it gave one.
  final String? totalCountText;

  final CommentSort sort;

  static const empty = CommentsFeed(items: <CommentItem>[]);
}

class CommentsNotifier
    extends AutoDisposeFamilyAsyncNotifier<CommentsFeed, String> {
  String? _continuation;

  /// Ids already shown. YouTube repeats a pinned comment on the second
  /// page often enough to be worth guarding against.
  final _seen = <String>{};

  @override
  Future<CommentsFeed> build(String videoId) async {
    _seen.clear();
    _continuation = null;

    final sort = ref.watch(commentsSortProvider(videoId));
    final page = await ref
        .watch(commentsServiceProvider)
        .getComments(videoId, sort: sort);

    _continuation = page.continuation;
    return CommentsFeed(
      items: _fresh(page.items),
      hasMore: page.hasMore,
      totalCountText: page.totalCountText,
      sort: sort,
    );
  }

  /// Appends the next page. Never throws: a failure keeps the pages
  /// already loaded and surfaces itself as [CommentsFeed.loadMoreError].
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final token = _continuation;
    if (current == null ||
        token == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(
      CommentsFeed(
        items: current.items,
        hasMore: true,
        isLoadingMore: true,
        totalCountText: current.totalCountText,
        sort: current.sort,
      ),
    );

    try {
      final page = await ref.read(commentsServiceProvider).continuePage(token);
      _continuation = page.continuation;
      state = AsyncData(
        CommentsFeed(
          items: [...current.items, ..._fresh(page.items)],
          hasMore: page.hasMore,
          totalCountText: current.totalCountText ?? page.totalCountText,
          sort: current.sort,
        ),
      );
    } catch (e) {
      state = AsyncData(
        CommentsFeed(
          items: current.items,
          hasMore: true,
          loadMoreError: e,
          totalCountText: current.totalCountText,
          sort: current.sort,
        ),
      );
    }
  }

  List<CommentItem> _fresh(Iterable<CommentItem> items) =>
      items.where((item) => _seen.add(item.id)).toList();
}

/// A video's comment section, paginated. Call
/// `ref.read(commentsFeedProvider(videoId).notifier).loadMore()`.
final commentsFeedProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsFeed, String>(CommentsNotifier.new);

/// The replies under one thread, keyed by that thread's continuation
/// token. Only fetched once the row is expanded.
final commentRepliesProvider = FutureProvider.autoDispose
    .family<List<CommentItem>, String>((ref, continuation) async {
  final page =
      await ref.watch(commentsServiceProvider).getReplies(continuation);
  return page.items;
});

/// The number YouTube prints beside the watch page's comments entry
/// point, for the player's pill. Null while loading, when comments are
/// off, or when the request failed — the pill just shows its label then.
final commentCountProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, videoId) {
  return ref.watch(commentsServiceProvider).getCommentCountText(videoId);
});
