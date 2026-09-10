// ============================================================
// HomeScreen — YouTube-style feed
// ============================================================
// Top app bar with the brand and quick actions, a horizontal chip row
// to switch topic, then a mixed feed: a rail of half-finished videos,
// full-width recommendation cards, and a Shorts rail dropped in a few
// cards down — the shape YouTube's own home has.
//
// A topic chip narrows this to a single plain list; shelves only make
// sense on the mixed feed.
// ============================================================

// Narrowed: the package also re-exports flutter_cache_manager's
// DownloadProgress, which collides with this app's own class.
import 'package:cached_network_image/cached_network_image.dart'
    show CachedNetworkImage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/duration_formatter.dart';
import '../../../domain/entities/media_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/content_providers.dart';
import '../../providers/local_library_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/feed_tail.dart';
import '../../widgets/video_card.dart';
import '../../routing/app_router.dart' show tabReselectedProvider;
import '../browse/browse_screen.dart';
import '../shorts/shorts_screen.dart' show shortsProvider;
import '../player/widgets/cast_device_sheet.dart';

/// Which topic chip is selected. Null means the mixed home feed.
///
/// The chips used to run a plain search, which throws for most of these
/// words — only "music" survived. They now share the sidebar's browse
/// path, which asks YouTube for the section instead of searching for
/// its name.
final selectedTopicProvider = StateProvider<BrowseCategory?>((ref) => null);

/// Videos left part-watched, newest first — YouTube's "Continue
/// watching" rail. Derived from local history rather than fetched.
final continueWatchingProvider = Provider.autoDispose<List<MediaItem>>((ref) {
  final history = ref.watch(watchHistoryProvider).value ?? const <MediaItem>[];
  return history.where((item) => item.isInProgress).take(12).toList();
});

/// How many cards sit above the Shorts rail. YouTube buries it a couple
/// of videos down rather than opening with it.
const int _shortsShelfAfter = 3;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent * 0.8) return;
    if (ref.read(selectedTopicProvider) != null) return;
    ref.read(homeFeedPagedProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Chip labels are translated; the query sent to YouTube stays in
    // English so results are the same in every locale.
    final topics = <(String label, BrowseCategory? category)>[
      (l10n.topicAll, null),
      for (final category in BrowseCategory.values)
        (category.title(l10n), category),
    ];
    final topic = ref.watch(selectedTopicProvider);

    // Tapping Home while already on Home jumps back to the top, the way
    // YouTube's own tab bar behaves. The shell raises the signal; the
    // scroll position lives here.
    ref.listen<int>(tabReselectedProvider, (_, __) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });

    return Scaffold(
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        // Awaited, not fired and forgotten: invalidate returns at once,
        // so the spinner used to vanish a frame later while the feed was
        // still being fetched, and the pull read as having done nothing.
        onRefresh: () async {
          if (topic == null) {
            ref
              ..invalidate(homeFeedPagedProvider)
              ..invalidate(shortsProvider);
            await ref.read(homeFeedPagedProvider.future);
          } else {
            ref.invalidate(browseCategoryProvider(topic));
            await ref.read(browseCategoryProvider(topic).future);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          // So the pull works even when the feed is shorter than the
          // screen — an empty or failed feed is exactly when a refresh
          // matters most.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _appBar(context, l10n, topics, topic),
            ...topic == null ? _mixedSlivers(l10n) : _topicSlivers(l10n, topic),
          ],
        ),
      ),
    );
  }

  /// Scrolling down hides the bar and gives the feed the whole screen;
  /// scrolling up brings it straight back, the way YouTube's does.
  Widget _appBar(
    BuildContext context,
    AppLocalizations l10n,
    List<(String, BrowseCategory?)> topics,
    BrowseCategory? topic,
  ) {
    return SliverAppBar(
      floating: true,
      snap: true,
      titleSpacing: 0,
      title: Row(
        children: [
          const Icon(Icons.play_arrow_rounded,
              color: YouTubeColors.red, size: 30),
          const SizedBox(width: 2),
          Text(l10n.appTitle, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.cast_outlined),
          tooltip: l10n.castToTv,
          onPressed: () => showCastDeviceSheet(context, null),
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: l10n.downloads,
          onPressed: () => context.push('/downloads'),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.search,
          onPressed: () => context.push('/search'),
        ),
        IconButton(
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            child: Icon(
              Icons.person,
              size: 18,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          tooltip: l10n.settingsTab,
          onPressed: () => context.push('/settings'),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (label, category) = topics[index];
              return ChoiceChip(
                label: Text(label),
                selected: topic == category,
                onSelected: (_) =>
                    ref.read(selectedTopicProvider.notifier).state = category,
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // The mixed home feed
  // ============================================================

  List<Widget> _mixedSlivers(AppLocalizations l10n) {
    return ref.watch(homeFeedPagedProvider).when(
          data: (feed) {
            if (feed.items.isEmpty) {
              return [
                _emptySliver(
                  l10n,
                  () => ref.invalidate(homeFeedPagedProvider),
                ),
              ];
            }

            final resumable = ref.watch(continueWatchingProvider);
            // Shorts do not belong among 16:9 cards; they are pulled out
            // of the feed and shown as a rail of their own.
            final cards = feed.items
                .where((item) => !item.isShorts)
                .toList(growable: false);
            final above = cards.take(_shortsShelfAfter).toList();
            final below = cards.skip(_shortsShelfAfter).toList();

            return [
              if (resumable.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _ShelfHeader(
                    title: l10n.continueWatching,
                    icon: Icons.history,
                  ),
                ),
                SliverToBoxAdapter(child: _ResumeRail(items: resumable)),
              ],
              _cardSliver(above),
              SliverToBoxAdapter(child: _ShortsShelf(l10n: l10n)),
              _cardSliver(below),
              SliverToBoxAdapter(
                child: FeedTail(
                  feed: feed,
                  onRetry: () =>
                      ref.read(homeFeedPagedProvider.notifier).loadMore(),
                ),
              ),
            ];
          },
          loading: () => [_skeletonSliver()],
          error: (error, _) => [
            _errorSliver(error, () => ref.invalidate(homeFeedPagedProvider)),
          ],
        );
  }

  /// One topic section. These come back as a single page.
  List<Widget> _topicSlivers(AppLocalizations l10n, BrowseCategory topic) {
    return ref.watch(browseCategoryProvider(topic)).when(
          data: (items) => items.isEmpty
              ? [
                  _emptySliver(
                    l10n,
                    () => ref.invalidate(browseCategoryProvider(topic)),
                  ),
                ]
              : [
                  _cardSliver(items),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
          loading: () => [_skeletonSliver()],
          error: (error, _) => [
            _errorSliver(
              error,
              () => ref.invalidate(browseCategoryProvider(topic)),
            ),
          ],
        );
  }

  SliverList _cardSliver(List<MediaItem> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _card(context, items[index]),
        childCount: items.length,
      ),
    );
  }

  Widget _skeletonSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => const _CardSkeleton(),
        childCount: 4,
      ),
    );
  }

  Widget _emptySliver(AppLocalizations l10n, VoidCallback onRefresh) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyView(
        icon: Icons.video_library_outlined,
        title: l10n.homeEmptyTitle,
        subtitle: l10n.homeEmptySubtitle,
        action: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refreshFeed),
        ),
      ),
    );
  }

  Widget _errorSliver(Object error, VoidCallback onRetry) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ErrorView(error: error, onRetry: onRetry),
    );
  }

  Widget _card(BuildContext context, MediaItem item) {
    // Hero tags have to be unique across everything mounted, and all
    // four tabs stay alive in the shell. Home is the only surface that
    // hands them out, so a video showing in two tabs at once cannot
    // collide.
    final heroTag = 'feed-${item.videoId}';
    return VideoCard(
      item: item,
      heroTag: heroTag,
      onTap: () => context.push('/player/${item.videoId}?hero=$heroTag'),
    );
  }
}

// ============================================================
// Shelves
// ============================================================

/// The title strip above a rail.
class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.title, this.icon, this.iconColor});

  final String title;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: iconColor ?? theme.yt.secondaryText),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Half-finished videos, newest first. The red bar under each thumbnail
/// is the whole point of the rail: it says how far in you already are.
class _ResumeRail extends StatelessWidget {
  const _ResumeRail({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 190,
            child: Semantics(
              label: item.title,
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.push('/player/${item.videoId}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _Thumb(url: item.thumbnailUrl),
                            if (item.duration > Duration.zero)
                              PositionedDirectional(
                                end: 6,
                                bottom: 6,
                                child: _MiniBadge(
                                  DurationFormatter.format(item.duration),
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: (item.percentWatched ?? 0) / 100,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  YouTubeColors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The Shorts rail. Vertical thumbnails, because a 9:16 clip shown in a
/// 16:9 card is mostly letterbox.
class _ShortsShelf extends ConsumerWidget {
  const _ShortsShelf({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shorts = ref.watch(shortsProvider).value ?? const <MediaItem>[];
    // A shelf that failed to load is simply absent, rather than an error
    // panel wedged into the middle of a working feed.
    if (shorts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        _ShelfHeader(
          title: l10n.shortsTab,
          icon: Icons.play_circle_fill,
          iconColor: YouTubeColors.red,
        ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
            itemCount: shorts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _ShortsCard(item: shorts[index]),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

class _ShortsCard extends StatelessWidget {
  const _ShortsCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 146,
      child: Semantics(
        label: item.title,
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.push('/player/${item.videoId}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Thumb(url: item.thumbnailUrl),
                // A scrim, so the title stays legible over a bright frame.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 8,
                  end: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (item.viewCount != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.viewsCount(compactCount(item.viewCount!)),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      memCacheWidth: 480,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: color),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 240, color: color),
                const SizedBox(height: 8),
                Container(height: 12, width: 140, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
