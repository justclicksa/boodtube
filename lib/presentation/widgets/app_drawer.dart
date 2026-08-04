// ============================================================
// AppDrawer — the source app's sidebar, adapted for mobile
// ============================================================
// SmartTube's TV build puts every section in a left rail: Home, Shorts,
// Trending, Sports, Live, Gaming, News, Music, Channels, Subscriptions,
// History, Playlists, Blocked channels, Playback queue, Settings.
//
// Everything here is a section that has real data behind it in this app.
// Left out deliberately, because nothing would load: Notifications and
// "My videos" (both need account endpoints this app does not implement
// yet) and Kids home (a separate YouTube property).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../screens/browse/browse_screen.dart';
import '../theme/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final signedIn = ref.watch(authControllerProvider) is SignedIn;

    void go(String location) {
      Navigator.of(context).pop();
      context.push(location);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Account header
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: theme.yt.chipBackground,
                child: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              title: Text(signedIn ? l10n.signedIn : l10n.notSignedIn),
              subtitle: Text(
                signedIn ? l10n.signedInSubtitle : l10n.signInSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => go('/sign-in'),
            ),
            const Divider(),

            _DrawerItem(
              icon: Icons.home_outlined,
              label: l10n.homeTab,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            _DrawerItem(
              icon: Icons.play_circle_outline,
              label: l10n.shortsTab,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/shorts');
              },
            ),
            _DrawerItem(
              icon: Icons.subscriptions_outlined,
              label: l10n.subscriptionsTab,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/subscriptions');
              },
            ),

            const Divider(),
            _DrawerHeader(l10n.browse),
            for (final category in BrowseCategory.values)
              _DrawerItem(
                icon: category.icon,
                label: category.title(l10n),
                onTap: () => go('/browse/${category.name}'),
              ),

            const Divider(),
            _DrawerHeader(l10n.you),
            _DrawerItem(
              icon: Icons.history,
              label: l10n.history,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/library?tab=0');
              },
            ),
            _DrawerItem(
              icon: Icons.watch_later_outlined,
              label: l10n.watchLater,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/library?tab=2');
              },
            ),
            _DrawerItem(
              icon: Icons.thumb_up_outlined,
              label: l10n.favorites,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/library?tab=1');
              },
            ),
            _DrawerItem(
              icon: Icons.playlist_play,
              label: l10n.playlists,
              onTap: () => go('/playlists'),
            ),
            _DrawerItem(
              icon: Icons.download_outlined,
              label: l10n.downloads,
              onTap: () => go('/downloads'),
            ),

            const Divider(),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: l10n.settingsTab,
              onTap: () => go('/settings'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).yt.secondaryText,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}
