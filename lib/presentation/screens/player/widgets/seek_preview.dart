// ============================================================
// SeekPreviewBubble — the frame under the finger while scrubbing
// ============================================================
// Sits above the scrub bar and shows the storyboard frame for the
// position being dragged to, cropped out of the sheet that holds it.
// The bubble tracks the thumb but never leaves the bar's own width, so
// it stays on screen at both ends of the track.
//
// Direction-aware: the track runs right-to-left in Arabic, so the
// bubble is placed with a *directional* offset from the track's start.
// The timestamp itself is forced LTR — a clock reading is not mirrored.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart'
    show CachedNetworkImageProvider;
import 'package:flutter/material.dart';

import '../../../../core/utils/duration_formatter.dart';
import '../../../../data/youtube/storyboard_service.dart';
import '../../../../l10n/app_localizations.dart';

/// How storyboard sheets are loaded in the running app. Shared with the
/// prefetch on drag start so both hit the same cache entry.
ImageProvider storyboardImageProvider(String url) =>
    CachedNetworkImageProvider(url);

class SeekPreviewBubble extends StatelessWidget {
  const SeekPreviewBubble({
    required this.spec,
    required this.position,
    required this.fraction,
    super.key,
    this.tileWidth = 148,
    this.trackPadding = 12,
    this.imageProviderFactory = storyboardImageProvider,
  });

  /// The video's storyboard, or null when it has none — then nothing is
  /// drawn at all, which is the whole of the "no storyboard" handling.
  final StoryboardSpec? spec;

  /// Position being dragged to.
  final Duration position;

  /// Where that position sits along the track, 0..1.
  final double fraction;

  /// Width of the drawn frame in logical pixels.
  final double tileWidth;

  /// Inset of the track inside this widget — matches the scrub bar's
  /// own padding so the bubble lines up with the thumb.
  final double trackPadding;

  /// Injectable so widget tests need no network or cache manager.
  final ImageProvider Function(String url) imageProviderFactory;

  /// Space taken by the timestamp under the frame.
  static const _labelHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final tile = spec?.tileAt(position);
    if (tile == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final tileHeight = tileWidth / tile.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final usable = (trackWidth - trackPadding * 2).clamp(0.0, trackWidth);
        final centre = trackPadding + usable * fraction.clamp(0.0, 1.0);
        final limit = (trackWidth - tileWidth).clamp(0.0, trackWidth);
        final start = (centre - tileWidth / 2).clamp(0.0, limit);

        return SizedBox(
          height: tileHeight + _labelHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: start,
                top: 0,
                child: Semantics(
                  image: true,
                  label: l10n.seekPreview,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StoryboardFrame(
                        tile: tile,
                        width: tileWidth,
                        height: tileHeight,
                        imageProviderFactory: imageProviderFactory,
                      ),
                      const SizedBox(height: 3),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          DurationFormatter.format(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One cell of a storyboard sheet.
///
/// The sheet is laid out at its full scaled size inside an [OverflowBox]
/// and the clip around it keeps only the wanted cell: the alignment maps
/// cell (column, row) onto the -1..1 alignment range.
class _StoryboardFrame extends StatelessWidget {
  const _StoryboardFrame({
    required this.tile,
    required this.width,
    required this.height,
    required this.imageProviderFactory,
  });

  final StoryboardTile tile;
  final double width;
  final double height;
  final ImageProvider Function(String url) imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    final sheetWidth = width * tile.columns;
    final sheetHeight = height * tile.rows;
    final alignX =
        tile.columns > 1 ? (2 * tile.column / (tile.columns - 1)) - 1 : 0.0;
    final alignY = tile.rows > 1 ? (2 * tile.row / (tile.rows - 1)) - 1 : 0.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black54),
        ],
      ),
      // Painted over the frame rather than around it: a border in the
      // decoration would inset the clip window and crop the cell.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        alignment: Alignment(alignX, alignY),
        minWidth: sheetWidth,
        maxWidth: sheetWidth,
        minHeight: sheetHeight,
        maxHeight: sheetHeight,
        child: Image(
          image: imageProviderFactory(tile.sheetUrl),
          width: sheetWidth,
          height: sheetHeight,
          fit: BoxFit.fill,
          // The sheet only changes every few seconds of drag; keeping
          // the old one until the next decodes avoids a black flash.
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
