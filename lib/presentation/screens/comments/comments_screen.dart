// ============================================================
// CommentsScreen - قائمة التعليقات للفيديو
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/comment_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';

final commentsProvider = FutureProvider.autoDispose
    .family<List<CommentItem>, String>((ref, videoId) {
  return ref.watch(commentsServiceProvider).getComments(videoId);
});

class CommentsScreen extends ConsumerWidget {
  final String videoId;
  const CommentsScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commentsAsync = ref.watch(commentsProvider(videoId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comments),
      ),
      body: commentsAsync.when(
        data: (comments) {
          if (comments.isEmpty) {
            return EmptyView(
              icon: Icons.comment_outlined,
              title: l10n.noComments,
              subtitle: l10n.noCommentsSubtitle,
            );
          }
          return ListView.separated(
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _CommentTile(comment: comments[index]);
            },
          );
        },
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(commentsProvider(videoId)),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[700],
            backgroundImage: comment.authorAvatarUrl != null
                ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Text(
                    comment.author.isNotEmpty ? comment.author[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Comment body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + heart
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.isHearted) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.favorite, color: Colors.red, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Content
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),

                // Stats row
                Row(
                  children: [
                    Text(
                      _formatDate(comment.publishedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    if (comment.likeCount > 0)
                      Text(
                        _formatCount(comment.likeCount),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_down_outlined, size: 14, color: Colors.grey[600]),
                    if (comment.replyCount != null && comment.replyCount! > 0) ...[
                      const SizedBox(width: 16),
                      Text(
                        'View ${comment.replyCount} replies',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
