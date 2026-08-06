// ============================================================
// Comments — bottom sheet over the player, or a page of its own
// ============================================================
// YouTube never takes the video away to show comments: they arrive on a
// draggable sheet with the player still running above them. That is
// what `showCommentsSheet` is for. The full-screen route stays for deep
// links, and both render the same list.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/comment_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

final commentsProvider = FutureProvider.autoDispose
    .family<List<CommentItem>, String>((ref, videoId) {
  return ref.watch(commentsServiceProvider).getComments(videoId);
});

/// Open the comments over whatever is on screen, keeping the video
/// visible and playing above them.
Future<void> showCommentsSheet(BuildContext context, String videoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CommentsSheetBody(
          videoId: videoId, scrollController: scrollController),
    ),
  );
}

class _CommentsSheetBody extends ConsumerWidget {
  const _CommentsSheetBody({
    required this.videoId,
    required this.scrollController,
  });

  final String videoId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Grab handle — the affordance that says this sheet moves.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.yt.secondaryText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
          child: Row(
            children: [
              Text(l10n.comments, style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CommentsList(
            videoId: videoId,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

/// The list itself, shared by the sheet and the standalone route.
class CommentsList extends ConsumerWidget {
  const CommentsList({super.key, required this.videoId, this.scrollController});

  final String videoId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commentsAsync = ref.watch(commentsProvider(videoId));

    return commentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return EmptyView(
            icon: Icons.comment_outlined,
            title: l10n.noComments,
            subtitle: l10n.noCommentsSubtitle,
          );
        }
        return ListView.separated(
          controller: scrollController,
          itemCount: comments.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _CommentTile(comment: comments[index]),
        );
      },
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(commentsProvider(videoId)),
      ),
    );
  }
}

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.comments)),
      body: CommentsList(videoId: videoId),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommentItem comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final secondary = theme.yt.secondaryText;
    final statStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: secondary,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: comment.authorAvatarUrl != null
                ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Text(
                    comment.author.isNotEmpty
                        ? comment.author.characters.first.toUpperCase()
                        : '?',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      const Icon(
                        Icons.favorite,
                        color: YouTubeColors.red,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _relativeDate(l10n, comment.publishedAt),
                      style: statStyle,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_up_outlined, size: 14, color: secondary),
                    if (comment.likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(_formatCount(comment.likeCount), style: statStyle),
                    ],
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_down_outlined, size: 14, color: secondary),
                    if (comment.replyCount != null &&
                        comment.replyCount! > 0) ...[
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          l10n.viewReplies(comment.replyCount!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: statStyle?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
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

  static String _relativeDate(AppLocalizations l10n, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return l10n.yearsAgo(diff.inDays ~/ 365);
    if (diff.inDays >= 30) return l10n.monthsAgo(diff.inDays ~/ 30);
    if (diff.inDays >= 7) return l10n.weeksAgo(diff.inDays ~/ 7);
    if (diff.inDays >= 1) return l10n.daysAgo(diff.inDays);
    if (diff.inHours >= 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inMinutes >= 1) return l10n.minutesAgo(diff.inMinutes);
    return l10n.justNow;
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
