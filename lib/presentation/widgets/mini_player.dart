// ============================================================
// MiniPlayer — the bar YouTube leaves behind when you swipe a video down
// ============================================================
// The player route already leaves playback running when it is popped —
// PlayerController outlives it and nothing calls stop(). What was
// missing was any way to see or control what is still playing once the
// player screen is gone, so collapsing it looked identical to closing
// it. This bar sits above the bottom navigation and gives that state a
// face: tap to go back into the player, or stop it outright.
//
// It shows the thumbnail rather than a live texture. A second `Video`
// widget would sit in the tree beneath the player route and pause mpv
// on every backgrounding (media_kit_video's
// `pauseUponEnteringBackgroundMode`), which is exactly the bug that
// broke background playback in the first place.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/player_providers.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final item = state.currentItem;
    if (item == null) return const SizedBox.shrink();

    final controller = ref.read(playerControllerProvider.notifier);
    final theme = Theme.of(context);
    final progress = state.duration > Duration.zero
        ? (state.position.inMilliseconds / state.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF212121)
          : Colors.white,
      child: InkWell(
        onTap: () => context.push('/player/${item.videoId}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Row(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: item.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Colors.black),
                          )
                        : const ColoredBox(color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      state.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 28,
                    ),
                    onPressed: controller.togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 26),
                    onPressed: controller.stop,
                  ),
                ],
              ),
            ),
            // A hairline of progress, the way YouTube marks the bar.
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.dividerColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(YouTubeColors.red),
            ),
          ],
        ),
      ),
    );
  }
}
