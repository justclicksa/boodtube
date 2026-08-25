// ============================================================
// Download quality sheet
// ============================================================
// A download is the one place where quality is a lasting decision — it
// costs storage and cannot be changed without downloading again — so it
// is asked before the transfer starts rather than defaulted silently to
// 720p the way the old menu entry did.
//
// The resolutions come from the same `availableHeights` the in-player
// picker uses, which means one manifest round-trip. The sheet opens
// straight away with a spinner rather than freezing the menu, and still
// offers "Best available" if the manifest never arrives — a download
// that cannot be started at all is worse than one at an unknown height.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/downloads_providers.dart';
import '../screens/player/widgets/player_settings_sheet.dart'
    show qualityLabelFor;
import '../theme/app_theme.dart';

/// What the user picked. [height] null means "let the resolver choose".
@immutable
class DownloadQualityChoice {
  const DownloadQualityChoice(this.height);
  final int? height;
}

/// Returns null when the sheet is dismissed without choosing.
Future<DownloadQualityChoice?> showDownloadQualitySheet(
  BuildContext context,
  String videoId,
) {
  return showModalBottomSheet<DownloadQualityChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => _DownloadQualitySheet(videoId: videoId),
  );
}

class _DownloadQualitySheet extends ConsumerStatefulWidget {
  const _DownloadQualitySheet({required this.videoId});

  final String videoId;

  @override
  ConsumerState<_DownloadQualitySheet> createState() =>
      _DownloadQualitySheetState();
}

class _DownloadQualitySheetState extends ConsumerState<_DownloadQualitySheet> {
  late final Future<List<int>> _heights;

  @override
  void initState() {
    super.initState();
    _heights = ref
        .read(downloadsControllerProvider.notifier)
        .availableHeights(widget.videoId)
        // A failed resolve is not an error state here: the sheet still
        // has a usable answer ("Best available"), and the download will
        // report its own failure if the video really is unplayable.
        .catchError((Object _) => <int>[]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: FutureBuilder<List<int>>(
        future: _heights,
        builder: (context, snapshot) {
          final heights = snapshot.data ?? const <int>[];
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.downloadQuality,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  minTileHeight: AppSpacing.minTapTarget,
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(l10n.qualityBest),
                  onTap: () => Navigator.of(context)
                      .pop(const DownloadQualityChoice(null)),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                for (final height in heights)
                  ListTile(
                    minTileHeight: AppSpacing.minTapTarget,
                    leading: const Icon(Icons.high_quality_outlined),
                    title: Text(qualityLabelFor(height)),
                    onTap: () => Navigator.of(context)
                        .pop(DownloadQualityChoice(height)),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }
}
