// ============================================================
// MiniPlayer — the bar YouTube leaves behind when you swipe a video down
// ============================================================
// The player route leaves playback running when it is popped —
// PlayerController outlives it and nothing calls stop(). This bar gives
// that surviving state a face: swipe it aside to stop, drag it up or tap
// it to go back into the player.
//
// It shows the thumbnail rather than a live texture. A second `Video`
// widget would sit in the tree beneath the player route and pause mpv
// on every backgrounding (media_kit_video's
// `pauseUponEnteringBackgroundMode`), which is exactly the bug that
// broke background playback in the first place.
//
// It renders nothing while the full player is mounted. Both surfaces
// describe the same playback, and showing the bar under a transparent
// player route would let it peek out during the collapse drag.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/player_providers.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const double height = 64;
  static const double totalHeight = height + 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final item = state.currentItem;
    if (item == null) return const SizedBox.shrink();
    if (ref.watch(playerRouteActiveProvider)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final theme = Theme.of(context);
    final progress = state.duration > Duration.zero
        ? (state.position.inMilliseconds / state.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    void expand() {
      HapticFeedback.lightImpact();
      context.push('/player/${item.videoId}');
    }

    return Dismissible(
      key: ValueKey('mini-${item.videoId}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        controller.stop();
      },
      background: ColoredBox(color: theme.scaffoldBackgroundColor),
      child: Semantics(
        label: l10n.miniPlayerLabel(item.title),
        button: true,
        // An upward flick reopens the player, mirroring the downward
        // drag that collapsed it. It sits outside the Material so the
        // ink response still owns plain taps.
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -180) expand();
          },
          child: Material(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF212121)
                : Colors.white,
            child: InkWell(
              onTap: expand,
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
                          tooltip: state.isPlaying ? l10n.pause : l10n.play,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            controller.togglePlayPause();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 26),
                          tooltip: l10n.close,
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
          ),
        ),
      ),
    );
  }
}
