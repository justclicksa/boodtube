// ============================================================
// Comments — bottom sheet over the player, or a page of its own
// ============================================================
// YouTube never takes the video away to show comments: they arrive on a
// draggable sheet with the player still running above them. That is
// what `showCommentsSheet` is for. The full-screen route stays for deep
// links, and both render the same list.
//
// Three things here exist because the video is still playing behind the
// sheet:
//
//   * a timestamp in a comment is a link that seeks the player, exactly
//     as the ones in the description are — but only while the comment's
//     own video is the one loaded, so a deep-linked page cannot jump
//     someone else's playback;
//   * replies load on demand, one request per thread the user opens,
//     because a thread nobody expands should cost nothing;
//   * a failed "load more" is reported under the last comment instead of
//     replacing a section the user has already scrolled through.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/comment_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/comments_providers.dart';
import '../../providers/player_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

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
        videoId: videoId,
        scrollController: scrollController,
      ),
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
    final total =
        ref.watch(commentsFeedProvider(videoId)).valueOrNull?.totalCountText;

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
              Text(
                total == null ? l10n.comments : l10n.commentsCount(total),
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        _SortBar(videoId: videoId),
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

/// Top / Newest. Hidden while the section is still loading its first
/// page, so the control never appears before there is anything to sort.
class _SortBar extends ConsumerWidget {
  const _SortBar({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(commentsFeedProvider(videoId));
    if (feed.valueOrNull?.items.isEmpty ?? true) return const SizedBox.shrink();

    final selected = ref.watch(commentsSortProvider(videoId));

    return Semantics(
      label: l10n.commentsSortLabel,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
          children: [
            for (final sort in CommentSort.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(
                    switch (sort) {
                      CommentSort.top => l10n.commentsSortTop,
                      CommentSort.newest => l10n.commentsSortNewest,
                    },
                  ),
                  selected: sort == selected,
                  onSelected: (_) => ref
                      .read(commentsSortProvider(videoId).notifier)
                      .state = sort,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The list itself, shared by the sheet and the standalone route.
class CommentsList extends ConsumerStatefulWidget {
  const CommentsList({
    required this.videoId,
    super.key,
    this.scrollController,
  });

  final String videoId;
  final ScrollController? scrollController;

  @override
  ConsumerState<CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends ConsumerState<CommentsList> {
  /// How close to the bottom the user has to get before the next page is
  /// asked for. Two screens' worth, so the spinner is rarely seen.
  static const _prefetchExtent = 800.0;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    if (metrics.extentAfter > _prefetchExtent) return false;
    ref.read(commentsFeedProvider(widget.videoId).notifier).loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedAsync = ref.watch(commentsFeedProvider(widget.videoId));

    return feedAsync.when(
      data: (feed) {
        if (feed.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: widget.scrollController,
              // Without this the empty state does not scroll, and a list
              // that cannot scroll cannot be pulled to refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 360,
                  child: EmptyView(
                    icon: Icons.comment_outlined,
                    title: l10n.noComments,
                    subtitle: l10n.noCommentsSubtitle,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              // The tail row is one past the comments.
              itemCount: feed.items.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == feed.items.length) {
                  return _Tail(feed: feed, videoId: widget.videoId);
                }
                return CommentTile(
                  comment: feed.items[index],
                  videoId: widget.videoId,
                );
              },
            ),
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(
        error: e,
        onRetry: () =>
            ref.invalidate(commentsFeedProvider(widget.videoId)),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(commentsFeedProvider(widget.videoId));
    await ref.read(commentsFeedProvider(widget.videoId).future);
  }
}

/// The row under the last comment: a spinner while the next page loads,
/// a retry for a page that failed, or nothing once the section ends.
class _Tail extends ConsumerWidget {
  const _Tail({required this.feed, required this.videoId});

  final CommentsFeed feed;
  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feed.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.read(commentsFeedProvider(videoId).notifier).loadMore(),
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({required this.videoId, super.key});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.comments)),
      body: Column(
        children: [
          _SortBar(videoId: videoId),
          Expanded(child: CommentsList(videoId: videoId)),
        ],
      ),
    );
  }
}

// ============================================================
// One comment
// ============================================================

class CommentTile extends ConsumerStatefulWidget {
  const CommentTile({
    required this.comment,
    required this.videoId,
    super.key,
    this.indented = false,
  });

  final CommentItem comment;
  final String videoId;

  /// Replies sit inside their thread's left margin.
  final bool indented;

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> {
  bool _repliesOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final comment = widget.comment;
    final secondary = theme.yt.secondaryText;
    final statStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: secondary,
    );
    final avatarRadius = widget.indented ? 14.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            widget.indented ? 44 : 12,
            12,
            12,
            12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: avatarRadius,
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
                    if (comment.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_outlined,
                              size: 12,
                              color: secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(l10n.commentPinned, style: statStyle),
                          ],
                        ),
                      ),
                    _AuthorRow(comment: comment, statStyle: statStyle),
                    const SizedBox(height: 4),
                    _CommentText(
                      text: comment.content,
                      videoId: widget.videoId,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up_outlined,
                          size: 14,
                          color: secondary,
                        ),
                        if (comment.likeCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            comment.likeCountText ??
                                _formatCount(comment.likeCount),
                            style: statStyle,
                          ),
                        ],
                        if (comment.isHearted) ...[
                          const SizedBox(width: 12),
                          Tooltip(
                            message: l10n.commentHeartedTooltip,
                            child: const Icon(
                              Icons.favorite,
                              color: YouTubeColors.red,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (comment.hasReplies &&
                        comment.repliesContinuation != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              setState(() => _repliesOpen = !_repliesOpen),
                          icon: Icon(
                            _repliesOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                          ),
                          label: Text(
                            _repliesOpen
                                ? l10n.hideReplies
                                : l10n.viewReplies(comment.replyCount ?? 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_repliesOpen && comment.repliesContinuation != null)
          _Replies(
            continuation: comment.repliesContinuation!,
            videoId: widget.videoId,
          ),
      ],
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.comment, required this.statStyle});

  final CommentItem comment;
  final TextStyle? statStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Flexible(
          child: Container(
            padding: comment.isByOwner
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                : EdgeInsets.zero,
            decoration: comment.isByOwner
                ? BoxDecoration(
                    color: theme.yt.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Text(
              comment.author,
              semanticsLabel: comment.isByOwner
                  ? '${comment.author}, ${l10n.commentByCreator}'
                  : null,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (comment.isVerified) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle, size: 12, color: theme.yt.secondaryText),
        ],
        const SizedBox(width: 6),
        Text(_relativeDate(l10n, comment.publishedAt), style: statStyle),
      ],
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
}

/// The replies of one thread, fetched the first time it is opened.
class _Replies extends ConsumerWidget {
  const _Replies({required this.continuation, required this.videoId});

  final String continuation;
  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(commentRepliesProvider(continuation));

    return replies.when(
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reply in items)
            CommentTile(comment: reply, videoId: videoId, indented: true),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(56, 0, 16, 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                ref.invalidate(commentRepliesProvider(continuation)),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Comment body
// ============================================================

/// A comment's text, with its timestamps turned into jump links and a
/// "show more" once it runs past four lines.
///
/// The same mechanics as `_DescriptionBlock` on the player screen: the
/// tap recognizers are owned by the state and disposed with it, because
/// a recognizer created inside `build` is never freed.
class _CommentText extends ConsumerStatefulWidget {
  const _CommentText({required this.text, required this.videoId});

  final String text;
  final String videoId;

  @override
  ConsumerState<_CommentText> createState() => _CommentTextState();
}

class _CommentTextState extends ConsumerState<_CommentText> {
  /// `1:23` or `01:02:03`, not preceded or followed by another digit.
  static final _timestamp =
      RegExp(r'(?<!\d)(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?!\d)');

  static const _collapsedLines = 4;

  final List<TapGestureRecognizer> _recognizers = [];
  bool _expanded = false;

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  static Duration _parse(RegExpMatch match) => Duration(
        hours: int.tryParse(match.group(1) ?? '') ?? 0,
        minutes: int.tryParse(match.group(2) ?? '') ?? 0,
        seconds: int.tryParse(match.group(3) ?? '') ?? 0,
      );

  /// A timestamp only means something while the video it was written
  /// under is the one loaded — the sheet is usually over that video, but
  /// the standalone route can be reached with something else playing.
  void _seek(Duration target) {
    final playing = ref.read(playerControllerProvider).currentItem?.videoId;
    if (playing != widget.videoId) return;
    ref.read(playerControllerProvider.notifier).seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _timestamp.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final target = _parse(match);
      final recognizer = TapGestureRecognizer()..onTap = () => _seek(target);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: match[0], style: linkStyle, recognizer: recognizer),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    // Only offer "show more" when there is more: a two-line comment with
    // a toggle under it reads as broken.
    final long = '\n'.allMatches(text).length >= _collapsedLines ||
        text.length > 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(style: baseStyle, children: spans),
          maxLines: _expanded ? null : _collapsedLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (long)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _expanded ? l10n.showLess : l10n.showMore,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.yt.secondaryText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
