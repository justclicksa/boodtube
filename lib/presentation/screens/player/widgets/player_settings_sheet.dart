// ============================================================
// In-player settings — mirrors the SmartTube playback menu
// ============================================================
// Opened from the gear icon while a video is playing. Every option
// here acts on the running playback immediately.
// ============================================================

// RepeatMode also exists in Flutter's animation library.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/media_subtitle.dart';
import '../../../../domain/entities/sponsor_segment.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../l10n/enum_labels.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../theme/app_theme.dart';

/// Opens the playback menu.
///
/// Everything lives in a single bottom-sheet route and the sub-pages are
/// swapped inside it. Popping the route to push a replacement — the
/// obvious way to write this — uses the popped route's context for the
/// push, which silently does nothing: the submenu never appeared and the
/// tap fell through to the page behind the sheet.
enum PlayerSettingsPage { root, quality, speed, subtitles, videoFit, stats }

Future<void> showPlayerSettings(
  BuildContext context, {
  PlayerSettingsPage initialPage = PlayerSettingsPage.root,
}) {
  // Surface and shape both come from the theme's bottomSheetTheme, so
  // this sheet is dark in the dark theme and light in the light one —
  // it used to be a hardcoded #212121 with white text on top of it.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    builder: (_) => _SettingsSheet(initialPage: _sheetPage(initialPage)),
  );
}

_SheetPage _sheetPage(PlayerSettingsPage page) => switch (page) {
      PlayerSettingsPage.root => _SheetPage.root,
      PlayerSettingsPage.quality => _SheetPage.quality,
      PlayerSettingsPage.speed => _SheetPage.speed,
      PlayerSettingsPage.subtitles => _SheetPage.subtitles,
      PlayerSettingsPage.videoFit => _SheetPage.videoFit,
      PlayerSettingsPage.stats => _SheetPage.stats,
    };

/// Which page the sheet is showing.
enum _SheetPage {
  root,
  quality,
  speed,
  subtitles,
  audio,
  repeat,
  sleep,
  sponsorBlock,
  volume,
  queue,
  videoFit,
  seekInterval,
  stats,
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initialPage});

  final _SheetPage initialPage;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late _SheetPage _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
  }

  void _open(_SheetPage page) => setState(() => _page = page);
  void _back() => setState(() => _page = _SheetPage.root);

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _SheetPage.root => _RootMenu(onOpen: _open),
      _SheetPage.quality => _QualityMenu(onBack: _back),
      _SheetPage.speed => _SpeedMenu(onBack: _back),
      _SheetPage.subtitles => _SubtitlesMenu(onBack: _back),
      _SheetPage.audio => _AudioTrackMenu(onBack: _back),
      _SheetPage.repeat => _RepeatMenu(onBack: _back),
      _SheetPage.sleep => _SleepTimerMenu(onBack: _back),
      _SheetPage.sponsorBlock => _SponsorBlockMenu(onBack: _back),
      _SheetPage.volume => _VolumeMenu(onBack: _back),
      _SheetPage.queue => _QueueMenu(onBack: _back),
      _SheetPage.videoFit => _VideoFitMenu(onBack: _back),
      _SheetPage.seekInterval => _SeekIntervalMenu(onBack: _back),
      _SheetPage.stats => _StatsMenu(onBack: _back),
    };
  }
}

class _RootMenu extends ConsumerWidget {
  const _RootMenu({required this.onOpen});

  final void Function(_SheetPage) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playerControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final subtitles = state.currentItem?.subtitles ?? const <MediaSubtitle>[];
    final sleepEnd = state.sleepTimerEnd;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrip(),
            _MenuRow(
              icon: Icons.high_quality_outlined,
              title: l10n.quality,
              // A downloaded file is one rendition and nothing can
              // switch it, so the row says so instead of opening a menu
              // whose every entry would be a no-op.
              value: state.isOffline
                  ? l10n.offlineQuality
                  : state.pendingHeight != null
                      ? qualityLabelFor(state.pendingHeight!)
                      : (state.currentQualityLabel ?? l10n.qualityAuto),
              enabled: !state.isOffline,
              onTap: () => onOpen(_SheetPage.quality),
            ),
            _MenuRow(
              icon: Icons.speed,
              title: l10n.playbackSpeed,
              value: '${_trim(state.playbackSpeed)}x',
              onTap: () => onOpen(_SheetPage.speed),
            ),
            _MenuRow(
              icon: Icons.closed_caption_outlined,
              title: l10n.subtitles,
              value: state.selectedSubtitle?.name ??
                  (subtitles.isEmpty ? l10n.unavailable : l10n.off),
              enabled: subtitles.isNotEmpty,
              onTap: () => onOpen(_SheetPage.subtitles),
            ),
            _MenuRow(
              icon: Icons.audiotrack_outlined,
              title: l10n.audioTrack,
              value: state.audioTracks
                      .where(
                        (track) => track.id == state.selectedAudioTrackId,
                      )
                      .firstOrNull
                      ?.label ??
                  l10n.unavailable,
              enabled: state.audioTracks.length > 1,
              onTap: () => onOpen(_SheetPage.audio),
            ),
            _MenuRow(
              icon: Icons.repeat,
              title: l10n.repeatMode,
              value: state.repeatMode.shortLabel(l10n),
              onTap: () => onOpen(_SheetPage.repeat),
            ),
            _MenuRow(
              icon: Icons.bedtime_outlined,
              title: l10n.sleepTimer,
              value: sleepEnd == null
                  ? l10n.off
                  : l10n.minutesLeft(
                      sleepEnd.difference(DateTime.now()).inMinutes + 1,
                    ),
              onTap: () => onOpen(_SheetPage.sleep),
            ),
            _MenuRow(
              icon: Icons.block,
              title: l10n.sponsorBlockSection,
              value: settings.sponsorBlockEnabled
                  ? (settings.autoSkipSponsors ? l10n.autoSkip : l10n.manual)
                  : l10n.off,
              onTap: () => onOpen(_SheetPage.sponsorBlock),
            ),
            _MenuRow(
              icon: Icons.volume_up_outlined,
              title: l10n.volume,
              value: l10n.percentValue(state.volume.round()),
              onTap: () => onOpen(_SheetPage.volume),
            ),
            _MenuRow(
              icon: Icons.queue_music,
              title: l10n.playbackQueue,
              value: state.queue.isEmpty ? l10n.empty : '${state.queue.length}',
              enabled: state.queue.isNotEmpty,
              onTap: () => onOpen(_SheetPage.queue),
            ),
            _MenuRow(
              icon: Icons.aspect_ratio,
              title: l10n.videoZoom,
              value: state.videoFit.label(l10n),
              onTap: () => onOpen(_SheetPage.videoFit),
            ),
            _MenuRow(
              icon: Icons.fast_forward,
              title: l10n.seekInterval,
              value: l10n.secondsShort(state.seekInterval.inSeconds),
              onTap: () => onOpen(_SheetPage.seekInterval),
            ),
            _MenuRow(
              icon: Icons.info_outline,
              title: l10n.statsForNerds,
              value: '',
              onTap: () => onOpen(_SheetPage.stats),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Quality
// ============================================================

class _QualityMenu extends ConsumerWidget {
  const _QualityMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playerControllerProvider);
    final current = state.currentQualityLabel;
    final pending = state.pendingHeight;
    final heights = state.availableHeights;
    final auto = ref.watch(
      settingsControllerProvider.select((s) => s.autoQuality),
    );

    return _SubSheet(
      onBack: onBack,
      title: l10n.quality,
      children: [
        if (state.isOffline)
          ListTile(
            title: Text(
              l10n.offlineQualityNotice,
              style: TextStyle(color: Theme.of(context).yt.secondaryText),
            ),
          ),
        if (!state.isOffline && heights.isNotEmpty)
          _CheckRow(
            label: auto && current != null
                ? '${l10n.autoQualityLabel} ($current)'
                : l10n.autoQualityLabel,
            selected: auto && pending == null,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(playerControllerProvider.notifier).selectAutoQuality();
            },
          ),
        if (!state.isOffline && heights.isEmpty)
          ListTile(
            title: Text(
              l10n.noAlternativesAvailable,
              style: TextStyle(color: Theme.of(context).yt.secondaryText),
            ),
          ),
        for (final h in state.isOffline ? const <int>[] : heights)
          _CheckRow(
            label: qualityLabelFor(h),
            // While a switch is resolving, the tick follows the pick, not
            // the resolution still playing.
            selected: pending != null
                ? pending == h
                : !auto && current != null && current.startsWith('${h}p'),
            trailing: pending == h
                ? const SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(playerControllerProvider.notifier).switchQuality(h);
            },
          ),
      ],
    );
  }
}

/// "1440p (2K)" — resolution names are not translated, they are the same
/// everywhere YouTube shows them.
String qualityLabelFor(int height) => switch (height) {
      >= 4320 => '${height}p (8K)',
      >= 2160 => '${height}p (4K)',
      >= 1440 => '${height}p (2K)',
      >= 1080 => '${height}p (HD)',
      _ => '${height}p',
    };

// ============================================================
// Speed
// ============================================================

class _SpeedMenu extends ConsumerWidget {
  const _SpeedMenu({required this.onBack});

  final VoidCallback onBack;

  static const _speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(playerControllerProvider).playbackSpeed;
    return _SubSheet(
      onBack: onBack,
      title: l10n.playbackSpeed,
      children: [
        for (final s in _speeds)
          _CheckRow(
            label: s == 1.0 ? l10n.normal : '${_trim(s)}x',
            selected: (current - s).abs() < 0.01,
            onTap: () {
              ref.read(playerControllerProvider.notifier).setSpeed(s);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

// ============================================================
// Subtitles
// ============================================================

class _SubtitlesMenu extends ConsumerWidget {
  const _SubtitlesMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playerControllerProvider);
    final subtitles = state.currentItem?.subtitles ?? const <MediaSubtitle>[];
    final selected = state.selectedSubtitle;

    return _SubSheet(
      onBack: onBack,
      title: l10n.subtitles,
      children: [
        _CheckRow(
          label: l10n.off,
          selected: selected == null,
          onTap: () {
            ref.read(playerControllerProvider.notifier).selectSubtitle(null);
            Navigator.of(context).pop();
          },
        ),
        for (final sub in subtitles)
          _CheckRow(
            label: sub.isAutoGenerated
                ? '${sub.name} (${l10n.autoGenerated})'
                : sub.name,
            selected: selected?.url == sub.url,
            onTap: () {
              ref.read(playerControllerProvider.notifier).selectSubtitle(sub);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _AudioTrackMenu extends ConsumerWidget {
  const _AudioTrackMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playerControllerProvider);
    return _SubSheet(
      onBack: onBack,
      title: l10n.audioTrack,
      children: [
        for (final track in state.audioTracks)
          _CheckRow(
            label: track.label,
            selected: track.id == state.selectedAudioTrackId,
            onTap: () {
              Navigator.of(context).pop();
              ref
                  .read(playerControllerProvider.notifier)
                  .selectAudioTrack(track);
            },
          ),
        const Divider(),
        ListTile(title: Text(l10n.subtitleAppearance)),
        _SubtitleStyleSlider(
          label: l10n.subtitleSize,
          value: state.subtitleScale,
          min: 0.7,
          max: 1.6,
          onChanged: (value) => ref
              .read(playerControllerProvider.notifier)
              .setSubtitleStyle(scale: value),
        ),
        _SubtitleStyleSlider(
          label: l10n.subtitlePosition,
          value: state.subtitleOffset,
          min: 8,
          max: 140,
          onChanged: (value) => ref
              .read(playerControllerProvider.notifier)
              .setSubtitleStyle(offset: value),
        ),
        _SubtitleStyleSlider(
          label: l10n.subtitleBackground,
          value: state.subtitleBackgroundOpacity,
          min: 0,
          max: 0.95,
          onChanged: (value) => ref
              .read(playerControllerProvider.notifier)
              .setSubtitleStyle(backgroundOpacity: value),
        ),
      ],
    );
  }
}

class _SubtitleStyleSlider extends StatelessWidget {
  const _SubtitleStyleSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Repeat
// ============================================================

class _RepeatMenu extends ConsumerWidget {
  const _RepeatMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(playerControllerProvider).repeatMode;
    return _SubSheet(
      onBack: onBack,
      title: l10n.repeatMode,
      children: [
        for (final mode in RepeatMode.values)
          _CheckRow(
            label: mode.label(l10n),
            selected: current == mode,
            onTap: () {
              ref.read(playerControllerProvider.notifier).setRepeatMode(mode);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

// ============================================================
// Sleep timer
// ============================================================

class _SleepTimerMenu extends ConsumerWidget {
  const _SleepTimerMenu({required this.onBack});

  final VoidCallback onBack;

  static const _options = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(playerControllerProvider).sleepTimerEnd != null;
    return _SubSheet(
      onBack: onBack,
      title: l10n.sleepTimer,
      children: [
        _CheckRow(
          label: l10n.off,
          selected: !active,
          onTap: () {
            ref.read(playerControllerProvider.notifier).setSleepTimer(null);
            Navigator.of(context).pop();
          },
        ),
        for (final minutes in _options)
          _CheckRow(
            label: l10n.minutesShort(minutes),
            selected: false,
            onTap: () {
              ref
                  .read(playerControllerProvider.notifier)
                  .setSleepTimer(Duration(minutes: minutes));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.pausingIn(minutes))),
              );
            },
          ),
      ],
    );
  }
}

// ============================================================
// SponsorBlock
// ============================================================

class _SponsorBlockMenu extends ConsumerWidget {
  const _SponsorBlockMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    return _SubSheet(
      onBack: onBack,
      title: l10n.sponsorBlockSection,
      children: [
        SwitchListTile(
          title: Text(l10n.enableSponsorBlock),
          value: settings.sponsorBlockEnabled,
          onChanged: notifier.setSponsorBlockEnabled,
        ),
        SwitchListTile(
          title: Text(l10n.skipAutomatically),
          subtitle: Text(
            l10n.skipAutomaticallySubtitle,
            style: theme.textTheme.bodySmall,
          ),
          value: settings.autoSkipSponsors,
          onChanged: settings.sponsorBlockEnabled
              ? notifier.setAutoSkipSponsors
              : null,
        ),
        const Divider(),
        for (final category in SponsorCategory.values)
          CheckboxListTile(
            title: Text(category.label(l10n)),
            value: settings.sponsorCategories.contains(category),
            onChanged: settings.sponsorBlockEnabled
                ? (v) => notifier.toggleSponsorCategory(category, v ?? false)
                : null,
          ),
      ],
    );
  }
}

// ============================================================
// Volume / queue
// ============================================================

class _VolumeMenu extends ConsumerWidget {
  const _VolumeMenu({required this.onBack});

  final VoidCallback onBack;

  /// Mirrors SmartTube: up to 300%, boosting above 100%.
  static const _levels = [0, 25, 50, 75, 100, 125, 150, 200, 250, 300];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(playerControllerProvider).volume.round();
    return _SubSheet(
      onBack: onBack,
      title: l10n.volume,
      children: [
        for (final level in _levels)
          _CheckRow(
            label: level > 100
                ? l10n.percentBoost(level)
                : l10n.percentValue(level),
            selected: current == level,
            onTap: () {
              ref
                  .read(playerControllerProvider.notifier)
                  .setVolume(level.toDouble());
              Navigator.of(context).pop();
            },
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            20,
            AppSpacing.sm,
            20,
            AppSpacing.lg,
          ),
          child: Text(
            l10n.volumeBoostWarning,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _QueueMenu extends ConsumerWidget {
  const _QueueMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(playerControllerProvider).queue;
    final notifier = ref.read(playerControllerProvider.notifier);

    return _SubSheet(
      onBack: onBack,
      title: l10n.playbackQueue,
      children: [
        for (final item in queue)
          ListTile(
            minTileHeight: AppSpacing.minTapTarget,
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(item.author),
            trailing: IconButton(
              // "Delete" ships translated with the framework, so the
              // button gets a tooltip without a new app string.
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: () => notifier.removeFromQueue(item.videoId),
            ),
          ),
        if (queue.isNotEmpty)
          TextButton(
            onPressed: () {
              notifier.clearQueue();
              Navigator.of(context).pop();
            },
            child: Text(l10n.clearQueue),
          ),
      ],
    );
  }
}

// ============================================================
// Video zoom / seek interval
// ============================================================

class _VideoFitMenu extends ConsumerWidget {
  const _VideoFitMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(playerControllerProvider).videoFit;
    return _SubSheet(
      onBack: onBack,
      title: l10n.videoZoom,
      children: [
        for (final fit in VideoFit.values)
          _CheckRow(
            label: fit.label(l10n),
            selected: current == fit,
            onTap: () {
              ref.read(playerControllerProvider.notifier).setVideoFit(fit);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _SeekIntervalMenu extends ConsumerWidget {
  const _SeekIntervalMenu({required this.onBack});

  final VoidCallback onBack;

  static const _seconds = [1, 2, 3, 5, 7, 10, 15, 20, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(playerControllerProvider).seekInterval;
    return _SubSheet(
      onBack: onBack,
      title: l10n.seekInterval,
      children: [
        for (final s in _seconds)
          _CheckRow(
            label: l10n.secondsShort(s),
            selected: current.inSeconds == s,
            onTap: () {
              ref
                  .read(playerControllerProvider.notifier)
                  .setSeekInterval(Duration(seconds: s));
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

// ============================================================
// Stats for nerds
// ============================================================

class _StatsMenu extends ConsumerWidget {
  const _StatsMenu({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playerControllerProvider);
    final item = state.currentItem;
    final format = item?.bestFormat;

    return _SubSheet(
      onBack: onBack,
      title: l10n.statsForNerds,
      children: [
        _StatRow(l10n.videoIdLabel, item?.videoId ?? '—'),
        _StatRow(l10n.resolution, state.currentQualityLabel ?? '—'),
        _StatRow(l10n.codec, format?.codec ?? '—'),
        _StatRow(
          l10n.bitrate,
          format == null ? '—' : '${(format.bitrate / 1000).round()} kbps',
        ),
        _StatRow(
          l10n.audioTrack,
          state.currentAudioUrl == null
              ? l10n.muxedWithVideo
              : l10n.separateStream,
        ),
        _StatRow(l10n.buffered, '${state.buffered.inSeconds}s'),
        _StatRow(l10n.streamClient, state.sourceClient ?? '—'),
        _StatRow(
          l10n.failedClients,
          state.failedClients.isEmpty ? '—' : state.failedClients.join(', '),
        ),
        _StatRow(
          l10n.networkSpeed,
          state.networkMbps <= 0
              ? '—'
              : '${state.networkMbps.toStringAsFixed(1)} Mbps',
        ),
        _StatRow(l10n.automaticRecoveries, '${state.recoveryCount}'),
        _StatRow(
          l10n.fallbackReason,
          state.fallbackReason ?? l10n.noFallback,
        ),
        _StatRow(l10n.speed, '${_trim(state.playbackSpeed)}x'),
        _StatRow(l10n.sponsorSegments, '${state.sponsorSegments.length}'),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Two columns; read as one fact.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: TextStyle(
                  color: theme.yt.secondaryText,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Shared pieces
// ============================================================

class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: AppSpacing.xs,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SubSheet extends StatelessWidget {
  const _SubSheet({
    required this.title,
    required this.children,
    required this.onBack,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrip(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                20,
                AppSpacing.xs,
                20,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    // `Icons.arrow_back` does not mirror itself; in an
                    // RTL locale "back" points the other way.
                    icon: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_forward
                          : Icons.arrow_back,
                    ),
                    onPressed: onBack,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final color = enabled ? onSurface : onSurface.withValues(alpha: 0.38);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // "Quality, 1080p" rather than three separate announcements.
    return Semantics(
      label: value.isEmpty ? title : '$title: $value',
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: ListTile(
        minTileHeight: AppSpacing.minTapTarget,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.yt.secondaryText),
                ),
              ),
            // The chevron points at the submenu, so it follows the
            // reading direction.
            Icon(
              rtl ? Icons.chevron_left : Icons.chevron_right,
              color: onSurface.withValues(alpha: 0.38),
            ),
          ],
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppSpacing.minTapTarget,
      // ListTile turns this into a `selected` semantics flag, which is
      // what a screen reader needs — the tick alone said nothing.
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.onSurface,
      leading: Icon(selected ? Icons.check : null),
      title: Text(label),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// 1.0 -> "1", 1.25 -> "1.25"
String _trim(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
