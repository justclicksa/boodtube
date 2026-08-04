// ============================================================
// PlaylistsScreen — the account's playlists, and one playlist's videos
// ============================================================
// Playlists live on the account, not on the device, so both screens are
// empty (with a sign-in prompt) when signed out.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/youtube/authenticated_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/content_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/video_card.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (!ref.watch(isSignedInProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.playlists)),
        body: EmptyView(
          icon: Icons.playlist_play,
          title: l10n.noPlaylists,
          subtitle: l10n.signInSubtitle,
          action: ElevatedButton(
            onPressed: () => context.push('/sign-in'),
            child: Text(l10n.signIn),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playlists)),
      body: ref.watch(playlistsProvider).when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return EmptyView(
                  icon: Icons.playlist_play,
                  title: l10n.noPlaylists,
                  subtitle: l10n.noPlaylistsSubtitle,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(playlistsProvider),
                child: ListView.separated(
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _PlaylistRow(playlist: playlists[index]),
                ),
              );
            },
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(playlistsProvider),
            ),
          ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist});
  final AccountPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // YouTube's two implicit playlists get their own icons; the rest
    // show their cover.
    final icon = switch (playlist.playlistId) {
      'LL' => Icons.thumb_up_outlined,
      'WL' => Icons.watch_later_outlined,
      _ => Icons.playlist_play,
    };
    final title = switch (playlist.playlistId) {
      'LL' => l10n.favorites,
      'WL' => l10n.watchLater,
      _ => playlist.title,
    };

    return ListTile(
      leading: SizedBox(
        width: 88,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: playlist.thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: playlist.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: theme.yt.chipBackground,
                    child: Icon(icon, color: theme.yt.secondaryText),
                  ),
                )
              : ColoredBox(
                  color: theme.yt.chipBackground,
                  child: Icon(icon, color: theme.yt.secondaryText),
                ),
        ),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: playlist.videoCount != null
          ? Text(l10n.videoCount(playlist.videoCount!))
          : null,
      onTap: () => context.push(
        '/playlist/${playlist.playlistId}?title=${Uri.encodeComponent(title)}',
      ),
    );
  }
}

// ============================================================
// One playlist
// ============================================================

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({
    super.key,
    required this.playlistId,
    required this.title,
  });

  final String playlistId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final videos = ref.watch(playlistVideosProvider(playlistId));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: videos.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              icon: Icons.playlist_remove,
              title: l10n.nothingHereYet,
              subtitle: l10n.nothingToShow,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(playlistVideosProvider(playlistId)),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return VideoCard(
                  item: item,
                  isHorizontal: true,
                  onTap: () => context.push('/player/${item.videoId}'),
                );
              },
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(playlistVideosProvider(playlistId)),
        ),
      ),
    );
  }
}
