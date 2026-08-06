// ============================================================
// SubscriptionsScreen — latest videos + the channel list
// ============================================================
// Signed in, both tabs come from the account. Signed out, they fall
// back to the locally subscribed channels.
//
// The Latest tab opens with YouTube's horizontal strip of subscribed
// channel avatars; tapping one filters the feed to that channel, which
// is what the strip does on youtube.com.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/repositories/local_library_repository.dart'
    show LocalSubscription;
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/local_library_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/feed_tail.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/video_card.dart';

/// Channel the Latest feed is filtered to. Empty means every channel.
final _channelFilterProvider = StateProvider.autoDispose<String>((ref) => '');

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    // Fills the channel list from the account on first visit; without it
    // the Channels tab and the avatar strip stayed empty until the user
    // happened to press Sync.
    ref.watch(autoSyncSubscriptionsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.subscriptionsTab),
          actions: [
            if (signedIn)
              IconButton(
                tooltip: l10n.syncFromAccount,
                icon: const Icon(Icons.sync),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final count = await ref
                      .read(libraryActionsProvider)
                      .syncSubscriptions();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        count > 0
                            ? l10n.syncedChannels(count)
                            : l10n.couldNotReadSubscriptions,
                      ),
                    ),
                  );
                },
              )
            else
              TextButton(
                onPressed: () => context.push('/sign-in'),
                child: Text(l10n.signIn),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.latest),
              Tab(text: l10n.channels),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_LatestTab(), _ChannelsTab()],
        ),
      ),
    );
  }
}

// ============================================================
// Latest
// ============================================================

class _LatestTab extends ConsumerStatefulWidget {
  const _LatestTab();

  @override
  ConsumerState<_LatestTab> createState() => _LatestTabState();
}

class _LatestTabState extends ConsumerState<_LatestTab> {
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
  /// the feed never actually reaches a bottom the user can see.
  ///
  /// The channel filter is applied over the loaded pages rather than
  /// re-queried, so this stays useful while one is selected: reaching
  /// the end of a filtered list is exactly when more pages are worth
  /// fetching, since that is where the rest of that channel's videos
  /// are.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent * 0.8) return;
    ref.read(subscriptionsFeedPagedProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(subscriptionsFeedPagedProvider);
    final filter = ref.watch(_channelFilterProvider);

    return feed.when(
      data: (paged) {
        if (paged.items.isEmpty) {
          return EmptyView(
            icon: Icons.subscriptions_outlined,
            title: l10n.nothingHereYet,
            subtitle: ref.watch(isSignedInProvider)
                ? l10n.subscriptionsFeedEmpty
                : l10n.signInToUseAccount,
            action: ElevatedButton.icon(
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search),
              label: Text(l10n.findChannels),
            ),
          );
        }

        final items = filter.isEmpty
            ? paged.items
            : paged.items.where((v) => v.channelId == filter).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(subscriptionsFeedPagedProvider),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              const SliverToBoxAdapter(child: _ChannelStrip()),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l10n.nothingToShow)),
                )
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return VideoCard(
                      item: item,
                      onTap: () => context.push('/player/${item.videoId}'),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: FeedTail(
                  feed: paged,
                  onRetry: () => ref
                      .read(subscriptionsFeedPagedProvider.notifier)
                      .loadMore(),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SkeletonList(style: SkeletonStyle.feed),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(subscriptionsFeedPagedProvider),
      ),
    );
  }
}

/// YouTube's row of subscribed channel avatars above the feed.
class _ChannelStrip extends ConsumerWidget {
  const _ChannelStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subs = ref.watch(subscriptionsProvider).value ?? const [];
    if (subs.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(_channelFilterProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: subs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StripEntry(
              label: l10n.allSubscriptions,
              selected: selected.isEmpty,
              onTap: () => ref.read(_channelFilterProvider.notifier).state = '',
              avatar: CircleAvatar(
                radius: 26,
                backgroundColor: theme.yt.chipBackground,
                child: Icon(
                  Icons.grid_view,
                  color: theme.yt.secondaryText,
                  semanticLabel: l10n.allSubscriptions,
                ),
              ),
            );
          }
          final sub = subs[index - 1];
          return _StripEntry(
            label: sub.title,
            selected: selected == sub.channelId,
            onTap: () => ref.read(_channelFilterProvider.notifier).state =
                selected == sub.channelId ? '' : sub.channelId,
            avatar: _ChannelAvatar(sub: sub, radius: 26),
          );
        },
      ),
    );
  }
}

class _StripEntry extends StatelessWidget {
  const _StripEntry({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // An avatar and a truncated name read as two fragments; the channel
    // name on its own is the whole control.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTapTarget,
            minHeight: AppSpacing.minTapTarget,
          ),
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.yt.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Channels
// ============================================================

class _ChannelsTab extends ConsumerWidget {
  const _ChannelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subsAsync = ref.watch(subscriptionsProvider);

    return subsAsync.when(
      data: (subs) {
        if (subs.isEmpty) {
          return EmptyView(
            icon: Icons.people_outline,
            title: l10n.noChannelsYet,
            subtitle: l10n.noChannelsSubtitle,
          );
        }
        return ListView.separated(
          itemCount: subs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sub = subs[index];
            return ListTile(
              minTileHeight: AppSpacing.minTapTarget,
              leading: _ChannelAvatar(sub: sub, radius: 24),
              title: Text(sub.title),
              subtitle: sub.subscriberCount != null
                  ? Text(
                      l10n.subscriberCount(
                        _formatNumber(sub.subscriberCount!),
                      ),
                    )
                  : null,
              trailing: IconButton(
                tooltip: l10n.unsubscribe,
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () => ref
                    .read(libraryActionsProvider)
                    .toggleSubscription(sub.channelId, sub.title),
              ),
              onTap: () => context.push('/channel/${sub.channelId}'),
            );
          },
        );
      },
      loading: () => const SkeletonList(style: SkeletonStyle.channelRow),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(subscriptionsProvider),
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.sub, required this.radius});
  final LocalSubscription sub;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Purely decorative beside the channel name: without this the
    // fallback initial is announced as its own stray letter.
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: sub.avatarUrl != null
            ? CachedNetworkImageProvider(sub.avatarUrl!)
            : null,
        child: sub.avatarUrl == null
            ? Text(
                sub.title.isNotEmpty
                    ? sub.title.characters.first.toUpperCase()
                    : '?',
                style: TextStyle(fontSize: radius * 0.7),
              )
            : null,
      ),
    );
  }
}
