// ============================================================
// ShortsScreen - واجهة Shorts (vertical pager like TikTok)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../l10n/app_localizations.dart';

import '../../../data/youtube/mappers/media_item_mapper.dart';
import '../../../domain/entities/media_item.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/loading_view.dart';

/// Shorts have no dedicated endpoint in youtube_explode, so this
/// searches for them and keeps only genuinely short videos.
final shortsProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final client = ref.watch(innerTubeClientProvider);
  final videos = await client.search('#shorts');
  return videos
      .map(MediaItemMapper.fromVideo)
      .where((v) =>
          v.duration > Duration.zero &&
          v.duration <= const Duration(seconds: 90))
      .take(20)
      .toList();
});

class ShortsScreen extends ConsumerWidget {
  const ShortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(shortsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: shortsAsync.when(
        data: (shorts) {
          if (shorts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_outlined,
                      color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No shorts available',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: shorts.length,
            itemBuilder: (context, index) {
              return _ShortItem(item: shorts[index]);
            },
          );
        },
        loading: () => const LoadingView(),
        error: (e, st) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ShortItem extends ConsumerStatefulWidget {
  final MediaItem item;
  const _ShortItem({required this.item});

  @override
  ConsumerState<_ShortItem> createState() => _ShortItemState();
}

class _ShortItemState extends ConsumerState<_ShortItem> {
  late final VideoController _controller;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    // FIXED: use shared Player singleton (not new Player)
    _controller = VideoController(ref.read(mediaPlayerProvider));
    _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    final player = ref.read(mediaPlayerProvider);
    final repo = ref.read(mediaItemRepositoryProvider);
    final result = await repo.getMediaItem(widget.item.videoId);
    final item = result.dataOrNull;
    if (item?.bestFormat != null && mounted) {
      await player.open(Media(item!.bestFormat!.url));
    }
  }

  @override
  void dispose() {
    // Do NOT dispose shared player
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        Center(child: Video(controller: _controller)),

        // Right side actions
        Positioned(
          right: 8,
          bottom: 80,
          child: Column(
            children: [
              _ActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: l10n.like,
                color: _isLiked ? Colors.red : Colors.white,
                onTap: () => setState(() => _isLiked = !_isLiked),
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: '0',
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.share_outlined,
                label: l10n.share,
                color: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          left: 12,
          right: 80,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.item.author}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
