// ============================================================
// DownloadsScreen — offline library
// ============================================================
// Two lists in one: what is transferring right now (live, from the
// manager's stream) and what is already on disk (from the database).
// The footer says how much of the device the library is using, because
// that is the question this screen exists to answer after the first
// half dozen videos.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart'
    show CachedNetworkImage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/byte_formatter.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/entities/media_item.dart';
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
    final saved = ref.watch(savedDownloadsProvider);
    final sort = ref.watch(downloadSortProvider);
    final active = ref.watch(activeDownloadsProvider).value ?? const {};
    final inFlight = active.values
        .where((d) => d.status != DownloadStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloads),
        actions: [
          PopupMenuButton<DownloadSort>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sortBy,
            initialValue: sort,
            onSelected: (value) =>
                ref.read(downloadSortProvider.notifier).state = value,
            itemBuilder: (context) => [
              for (final option in DownloadSort.values)
                PopupMenuItem(
                  value: option,
                  child: Text(_sortLabel(l10n, option)),
                ),
            ],
          ),
        ],
      ),
      body: saved.when(
        data: (rows) {
          if (rows.isEmpty && inFlight.isEmpty) {
            return EmptyView(
              icon: Icons.download_outlined,
              title: l10n.noDownloads,
              subtitle: l10n.noDownloadsSubtitle,
            );
          }
          final ordered = _sorted(rows, sort);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final progress in inFlight)
                      _ActiveRow(progress: progress),
                    if (inFlight.isNotEmpty && ordered.isNotEmpty)
                      const Divider(height: 1),
                    for (final row in ordered) _SavedRow(row: row),
                  ],
                ),
              ),
              const _StorageFooter(),
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

  static String _sortLabel(AppLocalizations l10n, DownloadSort sort) =>
      switch (sort) {
        DownloadSort.newest => l10n.sortNewest,
        DownloadSort.oldest => l10n.sortOldest,
        DownloadSort.largest => l10n.sortLargest,
        DownloadSort.title => l10n.sortTitle,
      };

  static List<DownloadTableData> _sorted(
    List<DownloadTableData> rows,
    DownloadSort sort,
  ) {
    final ordered = [...rows];
    switch (sort) {
      case DownloadSort.newest:
        ordered.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      case DownloadSort.oldest:
        ordered.sort((a, b) => a.downloadedAt.compareTo(b.downloadedAt));
      case DownloadSort.largest:
        ordered.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
      case DownloadSort.title:
        ordered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return ordered;
  }
}

// ============================================================
// In-flight row
// ============================================================

class _ActiveRow extends ConsumerWidget {
  const _ActiveRow({required this.progress});

  final DownloadProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final controller = ref.read(downloadsControllerProvider.notifier);
    final failed = progress.status == DownloadStatus.failed;
    final paused = progress.status == DownloadStatus.paused;

    return ListTile(
      minTileHeight: AppSpacing.minTapTarget,
      leading: SizedBox(
        width: AppSpacing.minTapTarget,
        child: Icon(
          switch (progress.status) {
            DownloadStatus.failed => Icons.error_outline,
            DownloadStatus.paused => Icons.pause_circle_outline,
            DownloadStatus.queued => Icons.schedule,
            _ => Icons.downloading,
          },
          color: failed ? theme.colorScheme.error : null,
        ),
      ),
      title: Text(progress.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failed)
            Text(
              _failureMessage(l10n, progress),
              style: TextStyle(color: theme.colorScheme.error),
              maxLines: 2,
            )
          else ...[
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: progress.progress,
              // Otherwise the bar is silent to a screen reader and the
              // row reads as a bare title.
              semanticsLabel: l10n.downloads,
              semanticsValue: progress.progress == null
                  ? l10n.downloadQueued
                  : l10n.percentValue((progress.progress! * 100).round()),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _statusLine(l10n, progress, paused: paused),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
            ),
          ],
        ],
      ),
      isThreeLine: !failed,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failed || paused)
            IconButton(
              tooltip: paused ? l10n.resumeDownload : l10n.retry,
              icon: const Icon(Icons.play_arrow),
              onPressed: () => controller.resume(_stub(progress)),
            )
          else if (progress.status == DownloadStatus.downloading)
            IconButton(
              tooltip: l10n.pauseDownload,
              icon: const Icon(Icons.pause),
              onPressed: () => controller.pause(progress.videoId),
            ),
          IconButton(
            tooltip: material.cancelButtonLabel,
            icon: const Icon(Icons.close),
            onPressed: () => controller.cancel(progress.videoId),
          ),
        ],
      ),
    );
  }

  /// Resuming only needs the identity and the title the row already
  /// shows; the rest of the metadata is re-resolved with the stream.
  static MediaItem _stub(DownloadProgress progress) => MediaItem(
        videoId: progress.videoId,
        title: progress.title,
        author: '',
        channelId: '',
        duration: Duration.zero,
        publishedAt: DateTime.now(),
        formats: const [],
        subtitles: const [],
        chapters: const [],
      );

  static String _statusLine(
    AppLocalizations l10n,
    DownloadProgress progress, {
    required bool paused,
  }) {
    if (paused) return l10n.downloadPaused;
    if (progress.status == DownloadStatus.queued) return l10n.downloadQueued;
    if (progress.totalBytes <= 0) return l10n.downloadQueued;
    final size = l10n.downloadProgressDetail(
      formatBytes(progress.receivedBytes),
      formatBytes(progress.totalBytes),
    );
    if (progress.bytesPerSecond <= 0) return size;
    return '$size · ${l10n.transferRate(formatRate(progress.bytesPerSecond))}';
  }

  static String _failureMessage(
    AppLocalizations l10n,
    DownloadProgress progress,
  ) =>
      switch (progress.failure) {
        DownloadFailure.network => l10n.downloadFailedNetwork,
        DownloadFailure.storage => l10n.downloadFailedStorage,
        DownloadFailure.capped => l10n.downloadFailedCapped,
        DownloadFailure.unavailable => l10n.downloadFailedUnavailable,
        _ => l10n.downloadFailedUnknown,
      };
}

// ============================================================
// Saved row
// ============================================================

class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.row});

  final DownloadTableData row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);

    return Dismissible(
      key: ValueKey('download-${row.videoId}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      // A download is minutes of somebody's data allowance; a stray
      // swipe must not spend it again.
      confirmDismiss: (_) => _confirm(context, l10n),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await ref
            .read(downloadsControllerProvider.notifier)
            .remove(row.videoId);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.downloadRemoved)),
        );
      },
      child: ListTile(
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
        title: Text(row.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (row.author.isNotEmpty) row.author,
            if (row.qualityLabel != null) row.qualityLabel!,
            DurationFormatter.format(Duration(milliseconds: row.durationMs)),
            formatBytes(row.totalBytes),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: material.deleteButtonTooltip,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (!await _confirm(context, l10n)) return;
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            await ref
                .read(downloadsControllerProvider.notifier)
                .remove(row.videoId);
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.downloadRemoved)),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, AppLocalizations l10n) async {
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text(l10n.deleteDownloadConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(material.deleteButtonTooltip),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

// ============================================================
// Footer
// ============================================================

class _StorageFooter extends ConsumerWidget {
  const _StorageFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final used = ref.watch(downloadStorageUsedProvider).value;
    if (used == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Text(
          l10n.storageUsed(formatBytes(used)),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
