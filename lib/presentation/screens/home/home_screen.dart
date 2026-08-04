// ============================================================
// HomeScreen — YouTube-style feed
// ============================================================
// Top app bar with the brand and quick actions, a horizontal chip row
// to switch topic, then a single vertical feed of large video cards.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/media_group.dart';
import '../../../domain/entities/media_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/content_providers.dart';
import '../browse/browse_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/error_view.dart';
import '../../widgets/video_card.dart';

/// Which topic chip is selected. Null means the mixed home feed.
///
/// The chips used to run a plain search, which throws for most of these
/// words — only "music" survived. They now share the sidebar's browse
/// path, which asks YouTube for the section instead of searching for
/// its name.
final selectedTopicProvider = StateProvider<BrowseCategory?>((ref) => null);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Chip labels are translated; the query sent to YouTube stays in
    // English so results are the same in every locale.
    final topics = <(String label, BrowseCategory? category)>[
      (l10n.topicAll, null),
      for (final category in BrowseCategory.values)
        (category.title(l10n), category),
    ];
    final topic = ref.watch(selectedTopicProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
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
            icon: const Icon(Icons.settings_outlined),
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
                  onSelected: (_) => ref
                      .read(selectedTopicProvider.notifier)
                      .state = category,
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (topic == null) {
            ref.invalidate(homeFeedProvider);
          } else {
            ref.invalidate(browseCategoryProvider(topic));
          }
        },
        child: _feed(ref, topic).when(
          data: (data) {
            final items = topic == null
                ? _flatten(data as List<MediaGroup>)
                : data as List<MediaItem>;
            if (items.isEmpty) {
              return Center(child: Text(l10n.nothingToShow));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return VideoCard(
                  item: item,
                  onTap: () => context.push('/player/${item.videoId}'),
                );
              },
            );
          },
          loading: () => ListView.builder(
            itemCount: 4,
            itemBuilder: (_, __) => const _CardSkeleton(),
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(
                error: error,
                onRetry: () => topic == null
                    ? ref.invalidate(homeFeedProvider)
                    : ref.invalidate(browseCategoryProvider(topic)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The mixed feed, or one topic section.
  static AsyncValue<Object> _feed(WidgetRef ref, BrowseCategory? topic) {
    return topic == null
        ? ref.watch(homeFeedProvider)
        : ref.watch(browseCategoryProvider(topic));
  }

  /// The home feed is a list of shelves; flatten it into one
  /// de-duplicated stream of videos.
  static List<MediaItem> _flatten(Object data) {
    final seen = <String>{};
    final result = <MediaItem>[];
    void add(Iterable<MediaItem> items) {
      for (final item in items) {
        if (seen.add(item.videoId)) result.add(item);
      }
    }

    if (data is List) {
      for (final group in data) {
        add((group as dynamic).mediaItems as List<MediaItem>);
      }
    } else {
      add((data as dynamic).mediaItems as List<MediaItem>);
    }
    return result;
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
