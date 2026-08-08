// ============================================================
// App Router (go_router)
// ============================================================
// The four tabs live in a StatefulShellRoute so each keeps its own
// Navigator, scroll offset and provider subtree. A plain ShellRoute
// swaps `child` on every branch change, which tore the feed down and
// refetched it on every tab switch.
//
// The player is pushed over the shell as a non-opaque page. Keeping it
// transparent is what lets the shell stay visible underneath while the
// player is being dragged down, so the collapse reads as one continuous
// movement into the mini player rather than a route disappearing.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../screens/browse/browse_screen.dart';
import '../screens/channel/channel_screen.dart';
import '../screens/comments/comments_screen.dart';
import '../screens/downloads/downloads_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/player/player_screen.dart';
import '../screens/playlists/playlists_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/sign_in_screen.dart';
import '../screens/shorts/shorts_screen.dart';
import '../screens/subscriptions/subscriptions_screen.dart';
import '../providers/local_library_providers.dart';
import '../widgets/mini_player.dart';

/// True while the full player route is mounted.
///
/// The mini player and the player share Hero tags, so exactly one of
/// them may be in the tree at a time — two live widgets with the same
/// tag is a framework error, not just a visual glitch.
final playerRouteActiveProvider = StateProvider<bool>((ref) => false);

/// Hero tag shared by a card thumbnail, the mini player artwork and the
/// player surface, so the same image carries through every transition.
String playerHeroTag(String videoId) => 'player-surface-$videoId';

/// Bumped when the tab you are already on is tapped again.
///
/// Returning the branch to its root is only half of what every tabbed
/// app does — the other half is jumping the visible list back to the
/// top, and only the screen owns its scroll position. It listens for
/// this instead of the shell reaching into it.
final tabReselectedProvider = StateProvider<int>((ref) => 0);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shorts',
                name: 'shorts',
                builder: (context, state) => const ShortsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subscriptions',
                builder: (context, state) => const SubscriptionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => LibraryScreen(
                  initialTab:
                      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
      // Detail routes
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/playlists',
        name: 'playlists',
        builder: (context, state) => const PlaylistsScreen(),
      ),
      GoRoute(
        path: '/playlist/:playlistId',
        name: 'playlist',
        builder: (context, state) => PlaylistScreen(
          playlistId: state.pathParameters['playlistId']!,
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/browse/:category',
        name: 'browse',
        builder: (context, state) {
          final category =
              BrowseCategory.fromPath(state.pathParameters['category'] ?? '');
          if (category == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Unknown section: ${state.uri}')),
            );
          }
          return BrowseScreen(category: category);
        },
      ),
      GoRoute(
        path: '/player/:videoId',
        name: 'player',
        pageBuilder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          return CustomTransitionPage<void>(
            key: ValueKey('player-$videoId'),
            // Transparent so the shell shows through as the player is
            // dragged down; the player's own Scaffold supplies the
            // opaque ground while it is expanded.
            opaque: false,
            barrierDismissible: false,
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (context, animation, _, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                )),
                child: child,
              );
            },
            child: PlayerScreen(
              videoId: videoId,
              // Downloads open the on-disk copy instead of streaming.
              offline: state.uri.queryParameters['offline'] == '1',
              heroTag: state.uri.queryParameters['hero'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/channel/:channelId',
        name: 'channel',
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          return ChannelScreen(channelId: channelId);
        },
      ),
      GoRoute(
        path: '/comments/:videoId',
        name: 'comments',
        builder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          return CommentsScreen(videoId: videoId);
        },
      ),
    ],
  );
});

// ============================================================
// MainShell — YouTube-style bottom navigation
// ============================================================

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch order below: home, shorts, subscriptions, library.
  static const int _shortsBranchIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // A like or subscribe that YouTube refused is rolled back locally,
    // which would otherwise just make the button quietly snap back.
    // Say what happened instead.
    ref.listen<LibraryActionFailure?>(libraryActionErrorProvider,
        (previous, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      ref.read(libraryActionErrorProvider.notifier).state = null;
    });

    return Scaffold(
      // The mini player rides above the tab bar and renders itself away
      // when nothing is loaded, so the tabs keep their full height until
      // there is actually something playing.
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // Shorts is its own full-bleed player. A bar describing some
          // video watched earlier in the session would both cover it and
          // offer controls for the wrong thing.
          if (navigationShell.currentIndex != _shortsBranchIndex)
            const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          final reselected = index == navigationShell.currentIndex;
          navigationShell.goBranch(
            index,
            // Tapping the active tab returns it to its root, the way
            // every tabbed app on both platforms behaves.
            initialLocation: reselected,
          );
          // …and sends the visible list back to the top, which is the
          // half of that gesture the router cannot do by itself.
          if (reselected) {
            ref.read(tabReselectedProvider.notifier).state++;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle_outline),
            selectedIcon: const Icon(Icons.play_circle),
            label: l10n.shortsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.subscriptions_outlined),
            selectedIcon: const Icon(Icons.subscriptions),
            label: l10n.subscriptionsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: l10n.libraryTab,
          ),
        ],
      ),
    );
  }
}
