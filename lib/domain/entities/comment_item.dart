// ============================================================
// CommentItem entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_item.freezed.dart';

@freezed
class CommentItem with _$CommentItem {
  const factory CommentItem({
    required String id,
    required String author,
    required String authorChannelId,
    String? authorAvatarUrl,
    required String content,
    required DateTime publishedAt,
    required int likeCount,
    int? replyCount,
    String? parentId, // null = top-level comment
    @Default(false) bool isHearted,
    @Default(false) bool isPinned,
  }) = _CommentItem;

  const CommentItem._();

  bool get isReply => parentId != null;
  bool get isPopular => likeCount > 100;
}
