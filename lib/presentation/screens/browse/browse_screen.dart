// ============================================================
// BrowseScreen — one category from the sidebar
// ============================================================
// The source app's sidebar sections are each "a feed of videos with a
// title", and each maps to a YouTube browse id — searching for the word
// instead returns shelf and live-badge renderers that the scraping
// search parser cannot read.
//
// Trending is deliberately absent: YouTube retired that page. Every id
// for it (FEtrending, FEtopics_trending) answers empty, the account's
// own sidebar no longer lists it, and searching "trending" returns
// nothing — so an entry for it could only ever show an empty screen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/content_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/video_card.dart';

/// Sidebar categories that resolve to a feed.
enum BrowseCategory {
  music,
  gaming,
  news,
  sports,
  live;

  static BrowseCategory? fromPath(String value) {
    for (final category in BrowseCategory.values) {
      if (category.name == value) return category;
    }
    return null;
  }

  /// YouTube's own browse ids for these sections, tried in order. The
  /// `FEtopics_*` family came from the account's guide response rather
  /// than guesswork; the extras are for ids YouTube has moved before.
  List<String> get browseIds => switch (this) {
        BrowseCategory.music => ['FEtopics_music', 'FEmusic'],
        BrowseCategory.gaming => ['FEtopics_gaming', 'FEgaming'],
        BrowseCategory.news => ['FEtopics_news', 'FEnews_destination'],
        BrowseCategory.sports => ['FEtopics_sports', 'FEsports'],
        BrowseCategory.live => ['FEtopics_live', 'FElive'],
      };

  /// Icons YouTube uses for this section in its own sidebar. Used to
  /// re-find the section by icon when the hard-coded browse id stops
  /// working — the icons outlive the ids.
  Set<String> get iconTypes => switch (this) {
        BrowseCategory.music => {'MUSIC', 'MUSIC_NOTE'},
        BrowseCategory.gaming => {'GAMING', 'VIDEO_GAME'},
        BrowseCategory.news => {'NEWS', 'ARTICLE'},
        BrowseCategory.sports => {'TROPHY', 'SPORTS'},
        BrowseCategory.live => {'LIVE', 'SENSORS', 'BROADCAST'},
      };

  /// Fallback query when the browse id returns nothing (signed out, or
  /// YouTube retired the id). Kept in English so results do not change
  /// with the UI language.
  String get query => switch (this) {
        BrowseCategory.music => 'music',
        BrowseCategory.gaming => 'gaming',
        BrowseCategory.news => 'news',
        BrowseCategory.sports => 'sports',
        BrowseCategory.live => 'live stream',
      };

  String title(AppLocalizations l10n) => switch (this) {
        BrowseCategory.music => l10n.music,
        BrowseCategory.gaming => l10n.gaming,
        BrowseCategory.news => l10n.news,
        BrowseCategory.sports => l10n.sports,
        BrowseCategory.live => l10n.live,
      };

  IconData get icon => switch (this) {
        BrowseCategory.music => Icons.music_note_outlined,
        BrowseCategory.gaming => Icons.sports_esports_outlined,
        BrowseCategory.news => Icons.newspaper_outlined,
        BrowseCategory.sports => Icons.sports_soccer_outlined,
        BrowseCategory.live => Icons.sensors,
      };
}

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key, required this.category});

  final BrowseCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(browseCategoryProvider(category));

    void refresh() => ref.invalidate(browseCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(title: Text(category.title(l10n))),
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: feed.when(
          data: (items) {
            if (items.isEmpty) {
              // Still a scrollable, so pull-to-refresh keeps working on
              // the one screen most likely to need it.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: AppSpacing.xxl * 2),
                  EmptyView(
                    icon: category.icon,
                    title: l10n.nothingToShow,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
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
          loading: () => const SkeletonList(style: SkeletonStyle.feed),
          error: (error, _) => ErrorView(error: error, onRetry: refresh),
        ),
      ),
    );
  }
}
