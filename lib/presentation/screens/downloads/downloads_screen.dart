// ============================================================
// DownloadsScreen — offline library
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/duration_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/downloads_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // "Delete" and "Cancel" already ship translated with the framework,
    // so the row actions get tooltips without a new app string.
    final material = MaterialLocalizations.of(context);
    final saved = ref.watch(savedDownloadsProvider);
    final active = ref.watch(activeDownloadsProvider).value ?? const {};
    final inFlight = active.values
        .where((d) => d.status != DownloadStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloads)),
      body: saved.when(
        data: (rows) {
          if (rows.isEmpty && inFlight.isEmpty) {
            return EmptyView(
              icon: Icons.download_outlined,
              title: l10n.noDownloads,
              subtitle: l10n.noDownloadsSubtitle,
            );
          }
          return ListView(
            children: [
              for (final progress in inFlight)
                ListTile(
                  minTileHeight: AppSpacing.minTapTarget,
                  leading: const SizedBox(
                    width: AppSpacing.minTapTarget,
                    child: Icon(Icons.downloading),
                  ),
                  title: Text(progress.title, maxLines: 1),
                  subtitle: progress.status == DownloadStatus.failed
                      ? Text(
                          progress.error ?? l10n.errorUnknown,
                          style: TextStyle(color: theme.colorScheme.error),
                          maxLines: 1,
                        )
                      : LinearProgressIndicator(
                          value: progress.progress,
                          // Otherwise the bar is silent to a screen
                          // reader and the row reads as a bare title.
                          semanticsLabel: l10n.downloads,
                          semanticsValue: l10n.percentValue(
                            (progress.progress * 100).round(),
                          ),
                        ),
                  trailing: IconButton(
                    tooltip: material.cancelButtonLabel,
                    icon: const Icon(Icons.close),
                    onPressed: () => ref
                        .read(downloadsControllerProvider.notifier)
                        .cancel(progress.videoId),
                  ),
                ),
              if (inFlight.isNotEmpty && rows.isNotEmpty)
                const Divider(height: 1),
              for (final row in rows)
                ListTile(
                  minTileHeight: AppSpacing.minTapTarget,
                  onTap: () => context.push('/player/${row.videoId}?offline=1'),
                  leading: ExcludeSemantics(
                    child: SizedBox(
                      width: 96,
                      height: 54,
                      child: row.thumbnailUrl == null
                          ? ColoredBox(color: theme.yt.chipBackground)
                          : CachedNetworkImage(
                              imageUrl: row.thumbnailUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(row.title, maxLines: 2),
                  subtitle: Text(
                    [
                      row.author,
                      if (row.qualityLabel != null) row.qualityLabel!,
                      DurationFormatter.format(
                        Duration(milliseconds: row.durationMs),
                      ),
                      _size(row.totalBytes),
                    ].join(' · '),
                    maxLines: 1,
                  ),
                  trailing: IconButton(
                    tooltip: material.deleteButtonTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(downloadsControllerProvider.notifier)
                        .remove(row.videoId),
                  ),
                ),
            ],
          );
        },
        loading: () => const SkeletonList(style: SkeletonStyle.compactRow),
        // Was `Center(child: Text('$e'))` — a raw exception with no way
        // out. ErrorView picks a localized sentence and offers a retry.
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(savedDownloadsProvider),
        ),
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
