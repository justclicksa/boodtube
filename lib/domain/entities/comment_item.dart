// ============================================================
// CommentItem — one comment, top-level or reply
// ============================================================
// Plain and immutable rather than freezed: nothing copies or compares a
// comment, and the file was the only thing in the entity folder that
// needed code generation to add a field. [LiveChatMessage] and
// [MediaPage] are already written this way.
//
// The two InnerTube shapes (`commentRenderer` and the newer
// `commentEntityPayload`) both land here, so the UI never has to know
// which one YouTube served.
// ============================================================

/// How YouTube orders a comment section. The tokens that actually select
/// an order come from the response's own sort menu — this only names
/// which of them the user asked for.
enum CommentSort {
  /// YouTube's default: engagement-ranked, pinned comment first.
  top,

  /// Strictly newest first.
  newest,
}

class CommentItem {
  const CommentItem({
    required this.id,
    required this.author,
    required this.authorChannelId,
    required this.content,
    required this.publishedAt,
    required this.likeCount,
    this.authorAvatarUrl,
    this.publishedTimeText,
    this.likeCountText,
    this.replyCount,
    this.parentId,
    this.repliesContinuation,
    this.isHearted = false,
    this.isPinned = false,
    this.isByOwner = false,
    this.isVerified = false,
  });

  final String id;
  final String author;
  final String authorChannelId;
  final String? authorAvatarUrl;
  final String content;

  /// Derived from [publishedTimeText] so the UI can render the age in
  /// the app's own language instead of whatever YouTube replied in.
  final DateTime publishedAt;

  /// YouTube's own wording ("2 years ago", "3 days ago (edited)"), kept
  /// for fidelity and for tests.
  final String? publishedTimeText;

  final int likeCount;

  /// The compact form YouTube shipped ("1.2K"), when it shipped one.
  final String? likeCountText;

  /// Number of replies on a top-level comment. Null on a reply, and on a
  /// thread YouTube did not count.
  final int? replyCount;

  /// Null on a top-level comment; the parent's id on a reply.
  final String? parentId;

  /// Continuation token that loads this thread's replies. Null when the
  /// thread has none.
  final String? repliesContinuation;

  /// The uploader hearted this comment.
  final bool isHearted;

  /// Pinned to the top of the section by the uploader.
  final bool isPinned;

  /// Written by the channel that uploaded the video.
  final bool isByOwner;

  /// The author's channel carries a verification badge.
  final bool isVerified;

  bool get isReply => parentId != null;
  bool get isPopular => likeCount > 100;
  bool get hasReplies => (replyCount ?? 0) > 0 || repliesContinuation != null;
}

/// One page of a comment section: the comments themselves, the token
/// that fetches the next page, and whatever the section header said
/// about the whole thing.
class CommentPage {
  const CommentPage({
    required this.items,
    this.continuation,
    this.totalCountText,
    this.sortTokens = const {},
    this.selectedSort,
  });

  final List<CommentItem> items;

  /// Hand straight back to `CommentsService.continuePage`. Null when the
  /// section is exhausted.
  final String? continuation;

  /// "1,234" as YouTube formatted it, from the section header.
  final String? totalCountText;

  /// The continuation token that re-loads the section in each order,
  /// taken from `sortFilterSubMenuRenderer`. Empty when the response
  /// carried no sort menu (reply pages never do).
  final Map<CommentSort, String> sortTokens;

  /// Which order the response says it is already in, when it says.
  final CommentSort? selectedSort;

  bool get hasMore => continuation != null && continuation!.isNotEmpty;

  static const empty = CommentPage(items: <CommentItem>[]);
}
