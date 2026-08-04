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
import '../../widgets/empty_view.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                  leading: const SizedBox(
                    width: 48,
                    child: Icon(Icons.downloading),
                  ),
                  title: Text(progress.title, maxLines: 1),
                  subtitle: progress.status == DownloadStatus.failed
                      ? Text(
                          progress.error ?? l10n.errorUnknown,
                          style: const TextStyle(color: Colors.redAccent),
                          maxLines: 1,
                        )
                      : LinearProgressIndicator(value: progress.progress),
                  trailing: IconButton(
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
                  onTap: () => context.push('/player/${row.videoId}?offline=1'),
                  leading: SizedBox(
                    width: 96,
                    height: 54,
                    child: row.thumbnailUrl == null
                        ? const ColoredBox(color: Colors.black26)
                        : CachedNetworkImage(
                            imageUrl: row.thumbnailUrl!,
                            fit: BoxFit.cover,
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
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(downloadsControllerProvider.notifier)
                        .remove(row.videoId),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
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
