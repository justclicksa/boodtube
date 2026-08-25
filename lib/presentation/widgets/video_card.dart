// ============================================================
// VideoCard — YouTube's feed and list rows
// ============================================================
// Vertical: full-width 16:9 thumbnail, 36px channel avatar, 14sp
// two-line title, one 12sp metadata line, overflow button.
// Horizontal: 160x90 thumbnail beside the same text block.
//
// The overflow button opens the sheet below. It used to fall through to
// `onTap`, so pressing the three dots played the video — a control that
// did the opposite of what it promised.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/duration_formatter.dart';
import '../../domain/entities/media_item.dart';
import '../../l10n/app_localizations.dart';
import '../providers/downloads_providers.dart';
import '../providers/local_library_providers.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/app_theme.dart';
import 'download_quality_sheet.dart';

/// Minimum touch target. Anything smaller is a miss waiting to happen,
/// and fails the platform accessibility guidance on both stores.
const double _kMinTapTarget = 48;

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMore,
    this.isHorizontal = false,
    this.showChannel = true,
    this.heroTag,
  });

  final MediaItem item;
  final VoidCallback? onTap;

  /// Overrides the standard overflow sheet. Screens with their own
  /// row actions (downloads, history) pass one; everything else gets
  /// the shared menu.
  final VoidCallback? onMore;
  final bool isHorizontal;
  final bool showChannel;

  /// Set to carry this thumbnail into the player as a shared element.
  ///
  /// Tags must be unique across everything mounted at once, and the four
  /// tabs are all alive together in the shell, so only one surface hands
  /// these out — see HomeScreen.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return isHorizontal ? _buildHorizontal(context) : _buildVertical(context);
  }

  // ============================================================
  // Feed card
  // ============================================================

  Widget _buildVertical(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: _semanticLabel(context),
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: _thumbnail(context, radius: 0)),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showChannel) ...[
                    _ChannelAvatar(
                      name: item.author,
                      url: item.channelAvatarUrl,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _metadataLine(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _MoreButton(item: item, onMore: onMore, iconSize: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Compact row (suggestions, search results)
  // ============================================================

  Widget _buildHorizontal(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: _semanticLabel(context),
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                height: 90,
                child: _thumbnail(context, radius: 8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metadataLine(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              _MoreButton(item: item, onMore: onMore, iconSize: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Pieces
  // ============================================================

  Widget _thumbnail(BuildContext context, {required double radius}) {
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbnailImage(context),
            if (item.isLive)
              const PositionedDirectional(
                start: 8,
                bottom: 8,
                child: _LiveBadge(),
              )
            else if (!item.isShorts && item.duration > Duration.zero)
              PositionedDirectional(
                end: 8,
                bottom: 8,
                child: _Badge(DurationFormatter.format(item.duration)),
              ),
            if (item.isInProgress)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _WatchedProgress(percent: item.percentWatched!),
              ),
          ],
        ),
      ),
    );

    final tag = heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    return image;
  }

  Widget _thumbnailImage(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    if (item.thumbnailUrl == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: item.thumbnailUrl!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      memCacheWidth: 720,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  /// "Channel · 1.2M views · 3 days ago", skipping unknown parts.
  String _metadataLine(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <String>[
      if (showChannel) item.author,
      if (item.viewCount != null)
        l10n.viewsCount(compactCount(item.viewCount!)),
      relativeDate(l10n, item.publishedAt),
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  String _semanticLabel(BuildContext context) {
    final parts = <String>[item.title, _metadataLine(context)];
    if (item.isLive) parts.add('LIVE');
    return parts.where((p) => p.isNotEmpty).join('. ');
  }
}

/// Compact view/like counts: 1.2K, 3.4M, 1.1B.
String compactCount(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

/// "3 days ago", or empty when the source reported no upload date.
String relativeDate(AppLocalizations l10n, DateTime date) {
  // Sources that don't report an upload date use a pre-YouTube
  // sentinel; showing "25 years ago" would be worse than nothing.
  if (date.isBefore(DateTime.utc(2005))) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) return l10n.yearsAgo(diff.inDays ~/ 365);
  if (diff.inDays >= 30) return l10n.monthsAgo(diff.inDays ~/ 30);
  if (diff.inDays >= 7) return l10n.weeksAgo(diff.inDays ~/ 7);
  if (diff.inDays >= 1) return l10n.daysAgo(diff.inDays);
  if (diff.inHours >= 1) return l10n.hoursAgo(diff.inHours);
  if (diff.inMinutes >= 1) return l10n.minutesAgo(diff.inMinutes);
  return l10n.justNow;
}

// ============================================================
// Overflow menu
// ============================================================

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.item,
    required this.onMore,
    required this.iconSize,
  });

  final MediaItem item;
  final VoidCallback? onMore;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: _kMinTapTarget,
      height: _kMinTapTarget,
      child: IconButton(
        icon: Icon(Icons.more_vert, size: iconSize),
        padding: EdgeInsets.zero,
        tooltip: l10n.videoOptions,
        color: Theme.of(context).yt.secondaryText,
        onPressed: () {
          if (onMore != null) {
            onMore!();
            return;
          }
          HapticFeedback.selectionClick();
          showVideoMenu(context, item);
        },
      ),
    );
  }
}

/// The sheet behind every ⋮ in the app: save, download, share, and the
/// two controls that let someone steer their own feed.
Future<void> showVideoMenu(BuildContext context, MediaItem item) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _VideoMenu(item: item),
  );
}

class _VideoMenu extends ConsumerWidget {
  const _VideoMenu({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isSaved =
        ref.watch(isWatchLaterProvider(item.videoId)).value ?? false;
    final isFavorite =
        ref.watch(isFavoriteProvider(item.videoId)).value ?? false;

    void close() => Navigator.of(context).pop();

    return SafeArea(
      // Scrollable rather than a bare Column: eight rows plus a
      // two-line title overflow a landscape phone, and overflow again
      // at large text sizes on any device.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.yt.secondaryText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            // Queue controls. Neither needs a video to be playing: the
            // queue is consumed when the current one ends, or when the
            // next one is opened.
            _MenuRow(
              icon: Icons.playlist_play,
              label: l10n.playNext,
              onTap: () {
                ref.read(playerControllerProvider.notifier).playNext(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.addedToQueue)),
                );
                close();
              },
            ),
            _MenuRow(
              icon: Icons.queue_music,
              label: l10n.addToQueue,
              onTap: () {
                ref.read(playerControllerProvider.notifier).enqueue(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.addedToQueue)),
                );
                close();
              },
            ),
            _MenuRow(
              icon: isSaved ? Icons.playlist_add_check : Icons.playlist_add,
              label: l10n.watchLater,
              onTap: () {
                ref.read(libraryActionsProvider).toggleWatchLater(item);
                close();
              },
            ),
            _MenuRow(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              label: l10n.favorites,
              onTap: () {
                ref.read(libraryActionsProvider).toggleFavorite(item);
                close();
              },
            ),
            _MenuRow(
              icon: Icons.download_outlined,
              label: l10n.download,
              // Quality is asked before the transfer starts rather than
              // defaulted to 720p out of sight: a download is storage
              // spent, and re-choosing means spending it again.
              //
              // The sheet is stacked on top of this menu rather than
              // replacing it: dismissing the quality list lands back
              // here, and this menu's context is still mounted when the
              // choice comes back.
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller =
                    ref.read(downloadsControllerProvider.notifier);
                final choice =
                    await showDownloadQualitySheet(context, item.videoId);
                if (choice == null) return;
                if (context.mounted) close();
                await controller.download(item, height: choice.height);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.downloadStarted)),
                );
              },
            ),
            _MenuRow(
              icon: Icons.reply,
              label: l10n.share,
              flipIcon: true,
              onTap: () {
                Share.share(
                  'https://youtu.be/${item.videoId}',
                  subject: item.title,
                );
                close();
              },
            ),
            const Divider(height: 1),
            if (item.channelId.isNotEmpty) ...[
              _MenuRow(
                icon: Icons.account_circle_outlined,
                label: l10n.goToChannel,
                onTap: () {
                  close();
                  context.push('/channel/${item.channelId}');
                },
              ),
              // The two controls that make the feed steerable. Without
              // them a bad recommendation has no exit.
              _MenuRow(
                icon: Icons.not_interested,
                label: l10n.notInterested,
                onTap: () {
                  ref.read(libraryActionsProvider).dislike(item.videoId);
                  close();
                },
              ),
              _MenuRow(
                icon: Icons.block,
                label: l10n.blockChannel,
                onTap: () {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .blockChannel(item.channelId);
                  close();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.flipIcon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool flipIcon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22);
    return ListTile(
      minTileHeight: _kMinTapTarget,
      leading: flipIcon
          ? Transform.flip(flipX: true, child: iconWidget)
          : iconWidget,
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.name, this.url, this.size = 36});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              style: TextStyle(
                fontSize: size * 0.4,
                color: theme.colorScheme.onSurface,
              ),
            )
          : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.color = const Color(0xCC000000)});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return const _Badge('LIVE', color: YouTubeColors.red);
  }
}

class _WatchedProgress extends StatelessWidget {
  const _WatchedProgress({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: percent / 100,
      minHeight: 3,
      backgroundColor: Colors.white24,
      valueColor: const AlwaysStoppedAnimation(YouTubeColors.red),
    );
  }
}
