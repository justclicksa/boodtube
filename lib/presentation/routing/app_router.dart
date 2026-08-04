// ============================================================
// App Router (go_router)
// ============================================================

import 'package:flutter/material.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
    routes: [
      // Shell route for bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/shorts',
            name: 'shorts',
            builder: (context, state) => const ShortsScreen(),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsScreen(),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => LibraryScreen(
              initialTab:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
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
          return MaterialPage(
            key: ValueKey('player-$videoId'),
            fullscreenDialog: true,
            child: PlayerScreen(
              videoId: videoId,
              // Downloads open the on-disk copy instead of streaming.
              offline: state.uri.queryParameters['offline'] == '1',
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

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = ['/', '/shorts', '/subscriptions', '/library'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) => context.go(_tabs[index]),
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

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.lastIndexWhere(
      (tab) => tab == '/' ? location == '/' : location.startsWith(tab),
    );
    return index < 0 ? 0 : index;
  }
}
