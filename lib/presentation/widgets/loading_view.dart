// ============================================================
// Loading states
// ============================================================
// Two of them:
//
// * [LoadingView] — a centred spinner, for waits with no shape to
//   predict (a single object, a modal action).
// * [SkeletonList] — shimmering placeholders shaped like the rows that
//   are about to replace them, for list screens. Because the blocks land
//   where the real content lands, the page does not jump when the data
//   arrives.
//
// Skeletons carry no semantics: to a screen reader a wall of grey boxes
// is noise, so the whole thing is excluded and the list simply announces
// itself once the real rows exist.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!),
          ],
        ],
      ),
    );
  }
}

/// The row shape a [SkeletonList] imitates.
enum SkeletonStyle {
  /// Full-width 16:9 thumbnail, avatar, two text lines — VideoCard's
  /// feed layout.
  feed,

  /// 160x90 thumbnail beside two text lines — VideoCard's compact row.
  compactRow,

  /// Circular avatar beside two text lines — the subscribed channel list.
  channelRow,

  /// 88x50 cover beside two text lines — the playlist list.
  playlistRow,
}

/// Shimmering stand-ins for a list that has not loaded yet.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    required this.style,
    this.itemCount = 6,
    super.key,
  });

  final SkeletonStyle style;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The shimmer reads as a lighter sweep over the resting block in
    // both themes: base is the chip surface, highlight is that surface
    // nudged towards the foreground colour.
    final base = theme.yt.chipBackground;
    final highlight = Color.lerp(base, theme.colorScheme.onSurface, 0.08)!;

    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: ListView.builder(
          // Nothing here is interactive, and dragging a skeleton to a
          // page that does not exist yet is meaningless.
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: itemCount,
          itemBuilder: (context, _) => switch (style) {
            SkeletonStyle.feed => const _FeedSkeleton(),
            SkeletonStyle.compactRow => const _RowSkeleton(
                leadingWidth: 160,
                leadingHeight: 90,
              ),
            SkeletonStyle.channelRow => const _RowSkeleton(
                leadingWidth: 48,
                leadingHeight: 48,
                circular: true,
              ),
            SkeletonStyle.playlistRow => const _RowSkeleton(
                leadingWidth: 88,
                leadingHeight: 50,
              ),
          },
        ),
      ),
    );
  }
}

/// A single block. Shimmer paints through it, so the colour only has to
/// be opaque.
class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    this.radius = AppSpacing.xs,
    this.circular = false,
  });

  final double width;
  final double height;
  final double radius;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).yt.chipBackground,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Mirrors VideoCard's feed layout.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Block(
            width: double.infinity,
            height: double.infinity,
            radius: 0,
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Block(width: 36, height: 36, circular: true),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Block(width: double.infinity, height: 14),
                    SizedBox(height: AppSpacing.sm),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: _Block(width: double.infinity, height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mirrors any leading-block-plus-two-lines row.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton({
    required this.leadingWidth,
    required this.leadingHeight,
    this.circular = false,
  });

  final double leadingWidth;
  final double leadingHeight;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Block(
            width: leadingWidth,
            height: leadingHeight,
            radius: AppSpacing.sm,
            circular: circular,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: double.infinity, height: 13),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: _Block(width: double.infinity, height: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
