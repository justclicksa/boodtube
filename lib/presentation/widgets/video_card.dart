// ============================================================
// VideoCard — YouTube's feed and list rows
// ============================================================
// Vertical: full-width 16:9 thumbnail, 36px channel avatar, 14sp
// two-line title, one 12sp metadata line, overflow button.
// Horizontal: 160x90 thumbnail beside the same text block.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/duration_formatter.dart';
import '../../domain/entities/media_item.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMore,
    this.isHorizontal = false,
    this.showChannel = true,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool isHorizontal;
  final bool showChannel;

  @override
  Widget build(BuildContext context) {
    return isHorizontal ? _buildHorizontal(context) : _buildVertical(context);
  }

  // ============================================================
  // Feed card
  // ============================================================

  Widget _buildVertical(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: _thumbnail(context, radius: 0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showChannel) ...[
                  _ChannelAvatar(name: item.author, size: 36),
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
                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: theme.yt.secondaryText,
                    onPressed: onMore ?? onTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Compact row (suggestions, search results)
  // ============================================================

  Widget _buildHorizontal(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
            SizedBox(
              width: 32,
              child: IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                color: theme.yt.secondaryText,
                onPressed: onMore ?? onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Pieces
  // ============================================================

  Widget _thumbnail(BuildContext context, {required double radius}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbnailImage(context),
            if (item.isLive)
              const Positioned(left: 8, bottom: 8, child: _LiveBadge())
            else if (!item.isShorts && item.duration > Duration.zero)
              Positioned(
                right: 8,
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
        l10n.viewsCount(_compactCount(item.viewCount!)),
      _relativeDate(l10n, item.publishedAt),
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  static String _compactCount(int views) {
    if (views >= 1000000000) {
      return '${(views / 1000000000).toStringAsFixed(1)}B';
    }
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  static String _relativeDate(AppLocalizations l10n, DateTime date) {
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
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.name, this.size = 36});
  final String name;
  final double size;

  /// Channel avatars are not part of the feed payload YouTube returns,
  /// so the initial stands in until a channel lookup provides one.
  String? get url => null;

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
