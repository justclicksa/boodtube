// ============================================================
// LibraryScreen — History, Favorites, Watch Later
// ============================================================
// The tabs read the Drift streams directly, so anything saved while a
// video plays shows up here without a refresh.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/media_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/local_library_providers.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/video_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.initialTab = 0});

  /// 0 = History, 1 = Favorites, 2 = Watch later. The sidebar links
  /// straight to a tab.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.libraryTab),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.history),
              Tab(text: l10n.favorites),
              Tab(text: l10n.watchLater),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HistoryTab(),
            _FavoritesTab(),
            _WatchLaterTab(),
          ],
        ),
      ),
    );
  }
}

/// Shared body: a list of cards, or the empty state.
class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<MediaItem> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyView(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return VideoCard(
          item: item,
          isHorizontal: true,
          onTap: () => context.push('/player/${item.videoId}'),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Brings in anything watched on another device, along with where it
    // was left off, so the resume position is shared across devices.
    ref.watch(historySyncProviderRefresh);
    return ref.watch(watchHistoryProvider).when(
          data: (items) => _LibraryList(
            items: items,
            emptyIcon: Icons.history,
            emptyTitle: l10n.noHistory,
            emptySubtitle: l10n.emptyHistorySubtitle,
          ),
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(watchHistoryProvider),
          ),
        );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(favoritesProvider).when(
          data: (items) => _LibraryList(
            items: items,
            emptyIcon: Icons.thumb_up_outlined,
            emptyTitle: l10n.noFavorites,
            emptySubtitle: l10n.emptyFavoritesSubtitle,
          ),
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(favoritesProvider),
          ),
        );
  }
}

class _WatchLaterTab extends ConsumerWidget {
  const _WatchLaterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(watchLaterProvider).when(
          data: (items) => _LibraryList(
            items: items,
            emptyIcon: Icons.watch_later_outlined,
            emptyTitle: l10n.noWatchLater,
            emptySubtitle: l10n.emptyWatchLaterSubtitle,
          ),
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(watchLaterProvider),
          ),
        );
  }
}
