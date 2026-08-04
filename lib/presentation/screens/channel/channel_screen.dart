// ============================================================
// ChannelScreen - صفحة القناة (Videos, Playlists, About) (FIXED: real subscribe)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

import 'package:smarttube_poc/domain/entities/media_group.dart';
import 'package:smarttube_poc/domain/repositories/content_repository.dart' show ChannelContent;
import 'package:smarttube_poc/presentation/providers/content_providers.dart';
import 'package:smarttube_poc/presentation/providers/local_library_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/widgets/video_card.dart';
import 'package:smarttube_poc/presentation/widgets/loading_view.dart';
import 'package:smarttube_poc/presentation/widgets/error_view.dart';

class ChannelScreen extends ConsumerWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelAsync = ref.watch(channelProvider(channelId));

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
                  TabBar(
                    tabs: [
                      Tab(text: AppLocalizations.of(context).videos),
                      Tab(text: AppLocalizations.of(context).playlists),
                      Tab(text: AppLocalizations.of(context).aboutSection),
                    ],
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _VideosTab(shelves: content.shelves),
                _PlaylistsTab(channelId: content.channelId),
                _AboutTab(content: content),
              ],
            ),
          ),
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(channelProvider(channelId)),
          ),
        ),
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  final ChannelContent content;
  const _ChannelHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey[700],
              backgroundImage: content.avatarUrl != null
                  ? CachedNetworkImageProvider(content.avatarUrl!)
                  : null,
              child: content.avatarUrl == null
                  ? Text(
                      content.title.isNotEmpty ? content.title[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Channel name
            Text(
              content.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Subscribers
            if (content.subscriberCount != null)
              Text(
                AppLocalizations.of(context).subscriberCount(
                  _formatSubscribers(content.subscriberCount!),
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            const SizedBox(height: 12),

            // Subscribe button
            Row(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final subsAsync = ref.watch(subscriptionsProvider);
                    final isSubscribed = subsAsync.maybeWhen(
                      data: (subs) => subs.any((s) => s.channelId == content.channelId),
                      orElse: () => false,
                    );
                    return ElevatedButton.icon(
                      onPressed: () => _toggleSubscribe(context, ref, content, isSubscribed),
                      icon: Icon(isSubscribed
                          ? Icons.notifications_active
                          : Icons.notifications_outlined),
                      label: Text(
                        isSubscribed
                            ? AppLocalizations.of(context).subscribed
                            : AppLocalizations.of(context).subscribe,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubscribed ? Colors.grey : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Copying the channel URL is what "share" can do
                    // without a platform share sheet dependency.
                    final messenger = ScaffoldMessenger.of(context);
                    final label = AppLocalizations.of(context).linkCopied;
                    await Clipboard.setData(
                      ClipboardData(
                        text: 'https://youtube.com/channel/${content.channelId}',
                      ),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(label),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context).share,
                    style: const TextStyle(color: Colors.white),
                  ),
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
    ChannelContent content,
    bool isSubscribed,
  ) {
    final repo = ref.read(localLibraryRepositoryProvider);
    if (isSubscribed) {
      repo.unsubscribe(content.channelId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).unsubscribed)),
      );
    } else {
      repo.subscribe(
        channelId: content.channelId,
        title: content.title,
        avatarUrl: content.avatarUrl,
        subscriberCount: content.subscriberCount,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).subscribed)),
      );
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
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

class _VideosTab extends ConsumerWidget {
  final List<MediaGroup> shelves;
  const _VideosTab({required this.shelves});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allVideos = shelves.expand((g) => g.mediaItems).toList();

    if (allVideos.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).noVideos));
    }

    return ListView.builder(
      itemCount: allVideos.length,
      itemBuilder: (context, index) {
        final item = allVideos[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: VideoCard(
            item: item,
            isHorizontal: true,
            onTap: () => context.push('/player/${item.videoId}'),
          ),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final String channelId;
  const _PlaylistsTab({required this.channelId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.queue_play_next, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).noPlaylists),
          const SizedBox(height: 8),
          Text(
            'Public playlists will appear here',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final ChannelContent content;
  const _AboutTab({required this.content});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (content.description != null) ...[
          const Text(
            'About',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(content.description!),
          const SizedBox(height: 24),
        ],
        _InfoRow(
          label: AppLocalizations.of(context).channelIdLabel,
          value: content.channelId,
        ),
        if (content.subscriberCount != null)
          _InfoRow(
            label: AppLocalizations.of(context).subscribers,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
