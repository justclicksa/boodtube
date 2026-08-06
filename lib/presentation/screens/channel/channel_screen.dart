// ============================================================
// ChannelScreen — صفحة القناة (Videos, Playlists, About)
// ============================================================
// The header used to paint white text over a black-to-transparent
// gradient, which only worked because the app was dark. The gradient is
// decoration over the scaffold — there is no banner behind it — so it
// now fades from the elevated surface and the text takes the theme's
// foreground colour, which reads in both themes.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:smarttube_poc/domain/entities/channel_info.dart';
import 'package:smarttube_poc/l10n/app_localizations.dart';
import 'package:smarttube_poc/presentation/providers/content_providers.dart';
import 'package:smarttube_poc/presentation/providers/local_library_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/theme/app_theme.dart';
import 'package:smarttube_poc/presentation/widgets/empty_view.dart';
import 'package:smarttube_poc/presentation/widgets/error_view.dart';
import 'package:smarttube_poc/presentation/widgets/feed_tail.dart';
import 'package:smarttube_poc/presentation/widgets/loading_view.dart';
import 'package:smarttube_poc/presentation/widgets/video_card.dart';

class ChannelScreen extends ConsumerWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Metadata and uploads are fetched apart: the header needs one and
    // the Videos tab needs the other, and the tab has to be able to page
    // its own list without redoing the channel lookup.
    final channelAsync = ref.watch(channelInfoProvider(channelId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: channelAsync.when(
          data: (content) => NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: _ChannelHeader(content: content),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  // Colours come from the theme's tabBarTheme, which
                  // already matches the rest of the app's tab bars.
                  TabBar(
                    tabs: [
                      Tab(text: l10n.videos),
                      Tab(text: l10n.playlists),
                      Tab(text: l10n.aboutSection),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _VideosTab(channelId: channelId),
                _PlaylistsTab(channelId: channelId),
                _AboutTab(content: content),
              ],
            ),
          ),
          loading: () => const SkeletonList(style: SkeletonStyle.compactRow),
          error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(channelInfoProvider(channelId)),
          ),
        ),
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  final ChannelInfo content;
  const _ChannelHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar — decorative; the channel name is right below it.
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: content.avatarUrl != null
                    ? CachedNetworkImageProvider(content.avatarUrl!)
                    : null,
                child: content.avatarUrl == null
                    ? Text(
                        content.title.isNotEmpty
                            ? content.title[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 28,
                          color: theme.colorScheme.onSurface,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Channel name
            Text(
              content.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subscribers
            if (content.subscriberCount != null)
              Text(
                l10n.subscriberCount(
                  _formatSubscribers(content.subscriberCount!),
                ),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.md),

            // Subscribe + share
            Row(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final subsAsync = ref.watch(subscriptionsProvider);
                    final isSubscribed = subsAsync.maybeWhen(
                      data: (subs) =>
                          subs.any((s) => s.channelId == content.channelId),
                      orElse: () => false,
                    );
                    // Subscribed is the muted chip, Subscribe is the
                    // theme's own filled pill — no literal red or grey,
                    // both of which were invisible in one theme or the
                    // other.
                    return FilledButton.icon(
                      onPressed: () =>
                          _toggleSubscribe(context, ref, content, isSubscribed),
                      icon: Icon(
                        isSubscribed
                            ? Icons.notifications_active
                            : Icons.notifications_outlined,
                      ),
                      label: Text(
                        isSubscribed ? l10n.subscribed : l10n.subscribe,
                      ),
                      style: isSubscribed
                          ? FilledButton.styleFrom(
                              backgroundColor: theme.yt.chipBackground,
                              foregroundColor: theme.colorScheme.onSurface,
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Copying the channel URL is what "share" can do
                    // without a platform share sheet dependency.
                    final messenger = ScaffoldMessenger.of(context);
                    final label = l10n.linkCopied;
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'https://youtube.com/channel/${content.channelId}',
                      ),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(label),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: Text(l10n.share),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSubscribers(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _toggleSubscribe(
    BuildContext context,
    WidgetRef ref,
    ChannelInfo content,
    bool isSubscribed,
  ) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(localLibraryRepositoryProvider);
    if (isSubscribed) {
      repo.unsubscribe(content.channelId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unsubscribed)),
      );
    } else {
      repo.subscribe(
        channelId: content.channelId,
        title: content.title,
        avatarUrl: content.avatarUrl,
        subscriberCount: content.subscriberCount,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subscribed)),
      );
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _VideosTab extends ConsumerStatefulWidget {
  final String channelId;
  const _VideosTab({required this.channelId});

  @override
  ConsumerState<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends ConsumerState<_VideosTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Fetch the next page while there is still a screenful to scroll, so
  /// the list never actually reaches a bottom the user can see.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent * 0.8) return;
    ref.read(channelVideosPagedProvider(widget.channelId).notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = channelVideosPagedProvider(widget.channelId);
    final videosAsync = ref.watch(provider);

    return videosAsync.when(
      data: (feed) {
        if (feed.items.isEmpty) {
          return EmptyView(
            icon: Icons.video_library_outlined,
            title: l10n.noVideos,
          );
        }
        return ListView.builder(
          controller: _scrollController,
          // One extra row for the tail: the next page's spinner, the
          // retry for a page that failed, or nothing once the channel's
          // uploads run out.
          itemCount: feed.items.length + 1,
          itemBuilder: (context, index) {
            if (index == feed.items.length) {
              return FeedTail(
                feed: feed,
                onRetry: () => ref.read(provider.notifier).loadMore(),
              );
            }
            final item = feed.items[index];
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: VideoCard(
                item: item,
                isHorizontal: true,
                onTap: () => context.push('/player/${item.videoId}'),
              ),
            );
          },
        );
      },
      loading: () => const SkeletonList(style: SkeletonStyle.compactRow),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(provider),
      ),
    );
  }
}

/// The channel's own playlists.
///
/// youtube_explode has no channel-playlists API, so this comes from
/// InnerTube's Playlists tab — see `ChannelBrowseClient`. A channel with
/// none still gets the honest empty state.
class _PlaylistsTab extends ConsumerWidget {
  final String channelId;
  const _PlaylistsTab({required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playlistsAsync = ref.watch(channelPlaylistsProvider(channelId));

    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return EmptyView(
            icon: Icons.playlist_play,
            title: l10n.noPlaylists,
            subtitle: l10n.channelHasNoPlaylists,
          );
        }
        return ListView.separated(
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              minTileHeight: AppSpacing.minTapTarget,
              leading: _PlaylistThumbnail(url: playlist.thumbnailUrl),
              title: Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: playlist.videoCount != null
                  ? Text(l10n.videoCount(playlist.videoCount!))
                  : null,
              onTap: () => context.push('/playlist/${playlist.playlistId}'),
            );
          },
        );
      },
      loading: () => const SkeletonList(style: SkeletonStyle.compactRow),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(channelPlaylistsProvider(channelId)),
      ),
    );
  }
}

class _PlaylistThumbnail extends StatelessWidget {
  const _PlaylistThumbnail({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Decorative: the playlist title sits right beside it.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: SizedBox(
          width: 80,
          height: 45,
          child: url != null
              ? CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                )
              : ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.playlist_play,
                    color: theme.yt.secondaryText,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final ChannelInfo content;
  const _AboutTab({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (content.description != null) ...[
          Text(
            l10n.aboutSection,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(content.description!),
          const SizedBox(height: AppSpacing.xl),
        ],
        _InfoRow(
          label: l10n.channelIdLabel,
          value: content.channelId,
        ),
        if (content.subscriberCount != null)
          _InfoRow(
            label: l10n.subscribers,
            value: content.subscriberCount!.toString(),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Two columns read as two disconnected fragments otherwise.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.yt.secondaryText,
                ),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
