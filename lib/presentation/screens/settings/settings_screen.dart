// ============================================================
// SettingsScreen - شجرة الإعدادات الكاملة
// ============================================================
// One long scroll with 18+ controls, so the rows are declared as data
// (`_SettingsRow`) rather than inline widgets — that is what makes the
// in-page search filter possible.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../data/local/preferences/settings_repository_impl.dart';
import '../../../domain/entities/content_filter.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/sponsor_segment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/player_tuning.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/locale_preference.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/empty_view.dart';
import '../player/subtitle_styles.dart';

/// The running build's own name and version, read from the platform
/// instead of being retyped in the About section every release.
final packageInfoProvider =
    FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = _buildSections(context);
    final query = _query.trim().toLowerCase();

    final children = <Widget>[];
    for (final section in sections) {
      // A section title match keeps the whole section, so searching
      // "sponsor" does not hide the categories under that heading.
      final titleMatches = section.title.toLowerCase().contains(query);
      final rows = query.isEmpty || titleMatches
          ? section.rows
          : section.rows.where((row) => row.matches(query)).toList();
      if (rows.isEmpty) continue;
      if (children.isNotEmpty) children.add(const Divider());
      children
        ..add(_SectionHeader(title: section.title))
        ..addAll(rows.map((row) => row.widget));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTab),
        bottom: PreferredSize(
          // SearchBar's 56pt minimum plus the 12pt gap below it.
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: l10n.searchSettings,
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
      ),
      body: children.isEmpty
          ? EmptyView(
              icon: Icons.search_off,
              title: l10n.noSettingsMatch(_query.trim()),
              action: TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                child: Text(l10n.clearAll),
              ),
            )
          : ListView(children: children),
    );
  }

  // ============================================================
  // Rows
  // ============================================================

  List<_SettingsSection> _buildSections(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final signedIn = ref.watch(authControllerProvider) is SignedIn;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final versionText =
        info == null ? '—' : '${info.version}+${info.buildNumber}';

    return [
      _SettingsSection(
        title: l10n.accountSection,
        rows: [
          _SettingsRow(
            keywords: [
              if (signedIn) l10n.signedIn else l10n.signIn,
              if (signedIn) l10n.signedInSubtitle else l10n.signInSubtitle,
            ],
            widget: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(signedIn ? l10n.signedIn : l10n.signIn),
              subtitle: Text(
                signedIn ? l10n.signedInSubtitle : l10n.signInSubtitle,
              ),
              onTap: () => context.push('/sign-in'),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.downloads, l10n.downloadsSubtitle],
            widget: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.downloads),
              subtitle: Text(l10n.downloadsSubtitle),
              onTap: () => context.push('/downloads'),
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.generalSection,
        rows: [
          _SettingsRow(
            keywords: [l10n.theme, l10n.darkMode, l10n.light, l10n.dark],
            widget: ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(l10n.theme),
              subtitle: Text(_themeLabel(l10n, settings.themeMode)),
              onTap: () => _showThemePicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.language, 'english', 'العربية', l10n.systemDefault],
            widget: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(_languageLabel(l10n, settings.language)),
              onTap: () => _showLanguagePicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.notifications],
            widget: SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: Text(l10n.notifications),
              value: settings.notificationsEnabled,
              onChanged: controller.setNotificationsEnabled,
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.playerSection,
        rows: [
          _SettingsRow(
            keywords: [l10n.defaultQuality, l10n.quality],
            widget: ListTile(
              leading: const Icon(Icons.high_quality),
              title: Text(l10n.defaultQuality),
              subtitle: Text(settings.defaultQuality.label(l10n)),
              onTap: () => _showQualityPicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.defaultSpeed, l10n.playbackSpeed],
            widget: ListTile(
              leading: const Icon(Icons.speed),
              title: Text(l10n.defaultSpeed),
              subtitle: Text('${settings.defaultSpeed}x'),
              onTap: () => _showSpeedPicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.videoBuffer, l10n.videoBufferSubtitle],
            widget: ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: Text(l10n.videoBuffer),
              subtitle: Text(
                '${settings.bufferPreset.label(l10n)} · '
                '${settings.bufferPreset.secondsLabel(l10n)}',
              ),
              onTap: () => _showBufferPicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [
              l10n.backgroundPlayback,
              l10n.backgroundPlaybackSubtitle,
            ],
            widget: SwitchListTile(
              secondary: const Icon(Icons.headphones),
              title: Text(l10n.backgroundPlayback),
              subtitle: Text(l10n.backgroundPlaybackSubtitle),
              value: settings.backgroundPlayback,
              onChanged: controller.setBackgroundPlayback,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.autoplayNext, l10n.autoplayNextSubtitle],
            widget: SwitchListTile(
              secondary: const Icon(Icons.skip_next),
              title: Text(l10n.autoplayNext),
              subtitle: Text(l10n.autoplayNextSubtitle),
              value: settings.autoplayNext,
              onChanged: controller.setAutoplayNext,
            ),
          ),
          _SettingsRow(
            keywords: [
              l10n.skipShortsInAutoplay,
              l10n.skipShortsInAutoplaySubtitle,
            ],
            widget: SwitchListTile(
              secondary: const Icon(Icons.bolt_outlined),
              title: Text(l10n.skipShortsInAutoplay),
              subtitle: Text(l10n.skipShortsInAutoplaySubtitle),
              value: settings.skipShortsInAutoplay,
              onChanged: controller.setSkipShortsInAutoplay,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.autoQuality, l10n.autoQualitySubtitle],
            widget: SwitchListTile(
              secondary: const Icon(Icons.hd),
              title: Text(l10n.autoQuality),
              subtitle: Text(l10n.autoQualitySubtitle),
              value: settings.autoQuality,
              onChanged: controller.setAutoQuality,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.doubleTapToSeek, l10n.doubleTapToSeekSubtitle],
            widget: SwitchListTile(
              secondary: const Icon(Icons.touch_app),
              title: Text(l10n.doubleTapToSeek),
              subtitle: Text(l10n.doubleTapToSeekSubtitle),
              value: settings.doubleTapToSeek,
              onChanged: controller.setDoubleTapToSeek,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.pictureInPicture],
            widget: SwitchListTile(
              secondary: const Icon(Icons.picture_in_picture),
              title: Text(l10n.pictureInPicture),
              value: settings.pictureInPictureEnabled,
              onChanged: controller.setPictureInPictureEnabled,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.subtitleStyle, l10n.subtitles],
            widget: ListTile(
              leading: const Icon(Icons.subtitles),
              title: Text(l10n.subtitleStyle),
              subtitle: Text(
                subtitleStyleFromName(settings.subtitleStyle).label(l10n),
              ),
              onTap: () => _showSubtitleStylePicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [
              l10n.defaultSubtitleLanguage,
              l10n.defaultSubtitleLanguageSubtitle,
              l10n.subtitles,
            ],
            widget: ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.defaultSubtitleLanguage),
              subtitle: Text(
                _subtitleLanguageLabel(
                  l10n,
                  settings.preferredSubtitleLanguage,
                ),
              ),
              onTap: () =>
                  _showSubtitleLanguagePicker(settings, controller),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.playerShortcuts, l10n.playerShortcutsSubtitle],
            widget: ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.playerShortcuts),
              subtitle: Text(l10n.playerShortcutsSubtitle),
              onTap: () => _showPlayerShortcutsPicker(settings, controller),
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.feedSection,
        rows: [
          for (final rule in HiddenContent.values)
            _SettingsRow(
              keywords: [rule.label(l10n), l10n.hideItem(rule.label(l10n))],
              widget: SwitchListTile(
                title: Text(l10n.hideItem(rule.label(l10n))),
                value: settings.hiddenContent.contains(rule),
                onChanged: (hide) => controller.toggleHiddenContent(rule, hide),
              ),
            ),
          _SettingsRow(
            keywords: [
              l10n.thumbnails,
              settings.clickbaitThumbnail.label(l10n),
            ],
            widget: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.thumbnails),
              subtitle: Text(settings.clickbaitThumbnail.label(l10n)),
              onTap: () => _showClickbaitPicker(settings),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.deArrow, l10n.deArrowSubtitle],
            widget: SwitchListTile(
              secondary: const Icon(Icons.title),
              title: Text(l10n.deArrow),
              subtitle: Text(l10n.deArrowSubtitle),
              value: settings.deArrowEnabled,
              onChanged: controller.setDeArrowEnabled,
            ),
          ),
          if (settings.blockedChannelIds.isNotEmpty)
            _SettingsRow(
              keywords: [l10n.blockedChannels, l10n.unblockAll],
              widget: ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.blockedChannels),
                subtitle: Text(
                  l10n.blockedCount(settings.blockedChannelIds.length),
                ),
                trailing: TextButton(
                  onPressed: () {
                    for (final id in {...settings.blockedChannelIds}) {
                      controller.unblockChannel(id);
                    }
                  },
                  child: Text(l10n.unblockAll),
                ),
              ),
            ),
        ],
      ),
      _SettingsSection(
        title: l10n.sponsorBlockSection,
        rows: [
          _SettingsRow(
            keywords: [
              l10n.enableSponsorBlock,
              l10n.enableSponsorBlockSubtitle,
            ],
            widget: SwitchListTile(
              secondary: const Icon(Icons.skip_next),
              title: Text(l10n.enableSponsorBlock),
              subtitle: Text(l10n.enableSponsorBlockSubtitle),
              value: settings.sponsorBlockEnabled,
              onChanged: controller.setSponsorBlockEnabled,
            ),
          ),
          if (settings.sponsorBlockEnabled) ...[
            _SettingsRow(
              keywords: [l10n.autoSkipSponsors, l10n.autoSkipSponsorsSubtitle],
              widget: SwitchListTile(
                secondary: const Icon(Icons.fast_forward),
                title: Text(l10n.autoSkipSponsors),
                subtitle: Text(l10n.autoSkipSponsorsSubtitle),
                value: settings.autoSkipSponsors,
                onChanged: controller.setAutoSkipSponsors,
              ),
            ),
            _SettingsRow(
              keywords: [l10n.sponsorSkipCategories],
              widget: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l10n.sponsorSkipCategories,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final cat in SponsorCategoryX.actionable)
              _SettingsRow(
                keywords: [cat.label(l10n), l10n.sponsorSkipCategories],
                widget: SwitchListTile(
                  dense: true,
                  title: Text(cat.label(l10n)),
                  value: settings.sponsorCategories.contains(cat),
                  onChanged: (v) => controller.toggleSponsorCategory(cat, v),
                ),
              ),
          ],
        ],
      ),
      _SettingsSection(
        title: l10n.backupAndRestore,
        rows: [
          _SettingsRow(
            keywords: [l10n.exportBackup, l10n.exportBackupSubtitle],
            widget: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.exportBackup),
              subtitle: Text(l10n.exportBackupSubtitle),
              onTap: _exportBackup,
            ),
          ),
          _SettingsRow(
            keywords: [l10n.restoreBackup, l10n.restoreBackupSubtitle],
            widget: ListTile(
              leading: const Icon(Icons.restore),
              title: Text(l10n.restoreBackup),
              subtitle: Text(l10n.restoreBackupSubtitle),
              onTap: _restoreBackup,
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.aboutSection,
        rows: [
          _SettingsRow(
            keywords: [l10n.version, versionText],
            widget: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.version),
              trailing: Text(versionText),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.checkForUpdates],
            // Honest by construction: nothing in this build talks to an
            // update server, so the row says so instead of pretending to
            // have checked.
            widget: ListTile(
              enabled: false,
              leading: const Icon(Icons.system_update),
              title: Text(l10n.checkForUpdates),
              subtitle: Text(l10n.updateCheckUnavailable),
            ),
          ),
          _SettingsRow(
            keywords: [l10n.openSourceLicenses],
            widget: ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.openSourceLicenses),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: versionText,
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  // ============================================================
  // Pickers
  // ============================================================

  void _showThemePicker(AppSettings settings, SettingsController controller) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.chooseTheme),
        children: AppThemeMode.values.map((mode) {
          return RadioListTile<AppThemeMode>(
            value: mode,
            groupValue: settings.themeMode,
            onChanged: (value) {
              if (value != null) controller.setThemeMode(value);
              Navigator.pop(context);
            },
            title: Text(_themeLabel(l10n, mode)),
          );
        }).toList(),
      ),
    );
  }

  void _showLanguagePicker(
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: supportedLanguageCodes.map((code) {
          return RadioListTile<String>(
            value: code,
            groupValue: settings.language,
            onChanged: (v) {
              if (v != null) {
                controller.setLanguage(v);
                Navigator.pop(context);
              }
            },
            title: Text(_languageLabel(l10n, code)),
          );
        }).toList(),
      ),
    );
  }

  void _showQualityPicker(AppSettings settings, SettingsController controller) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.defaultQuality),
        children: MediaFormatQuality.values.map((q) {
          return RadioListTile<MediaFormatQuality>(
            value: q,
            groupValue: settings.defaultQuality,
            onChanged: (value) {
              if (value != null) controller.setDefaultQuality(value);
              Navigator.pop(context);
            },
            title: Text(q.label(l10n)),
          );
        }).toList(),
      ),
    );
  }

  void _showSpeedPicker(AppSettings settings, SettingsController controller) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.defaultSpeed),
        children: speeds.map((s) {
          return RadioListTile<double>(
            value: s,
            groupValue: settings.defaultSpeed,
            onChanged: (value) {
              if (value != null) controller.setDefaultSpeed(value);
              Navigator.pop(context);
            },
            title: Text(s == 1.0 ? l10n.normal : '${s}x'),
          );
        }).toList(),
      ),
    );
  }

  void _showSubtitleStylePicker(
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    final current = subtitleStyleFromName(settings.subtitleStyle);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.subtitleStyle),
        children: SubtitleStyle.values.map((style) {
          return RadioListTile<SubtitleStyle>(
            value: style,
            groupValue: current,
            onChanged: (value) {
              if (value != null) controller.setSubtitleStyle(value);
              Navigator.pop(context);
            },
            title: Text(style.label(l10n)),
            // The sample is drawn with the very function the player uses,
            // so what is listed here is what plays.
            subtitle: Text(
              l10n.subtitleStylePreview,
              style: subtitleTextStyleFor(style, baseFontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSubtitleLanguagePicker(
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.defaultSubtitleLanguage),
        children: preferredSubtitleLanguageOptions.map((code) {
          return RadioListTile<String>(
            value: code,
            groupValue: settings.preferredSubtitleLanguage,
            onChanged: (value) {
              if (value != null) {
                controller.setPreferredSubtitleLanguage(value);
              }
              Navigator.pop(context);
            },
            title: Text(_subtitleLanguageLabel(l10n, code)),
          );
        }).toList(),
      ),
    );
  }

  /// SmartTube's video buffer, chosen outside the player too — the
  /// running playback picks the change up on its next open, and
  /// immediately when set from the player's own sheet.
  void _showBufferPicker(AppSettings settings, SettingsController controller) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.videoBuffer),
        children: BufferPreset.values.map((preset) {
          return RadioListTile<BufferPreset>(
            value: preset,
            groupValue: settings.bufferPreset,
            onChanged: (value) {
              if (value != null) controller.setBufferPreset(value);
              Navigator.pop(context);
            },
            title: Text(preset.label(l10n)),
            subtitle: Text(preset.secondsLabel(l10n)),
          );
        }).toList(),
      ),
    );
  }

  void _showPlayerShortcutsPicker(
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    final selected = [...settings.playerQuickActions];
    final remaining = PlayerQuickAction.values
        .where((action) => !selected.contains(action))
        .toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.playerShortcuts),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ReorderableListView(
              children: [
                for (final action in [...selected, ...remaining])
                  CheckboxListTile(
                    key: ValueKey(action),
                    value: selected.contains(action),
                    secondary: Icon(_quickActionIcon(action)),
                    title: Text(_quickActionLabel(l10n, action)),
                    onChanged: action == PlayerQuickAction.settings
                        ? null
                        : (enabled) {
                            setDialogState(() {
                              if (enabled ?? false) {
                                remaining.remove(action);
                                selected.insert(
                                  (selected.length - 1)
                                      .clamp(0, selected.length),
                                  action,
                                );
                              } else {
                                selected.remove(action);
                                remaining.add(action);
                              }
                            });
                          },
                  ),
              ],
              onReorder: (oldIndex, newIndex) {
                final all = [...selected, ...remaining];
                final action = all[oldIndex];
                if (!selected.contains(action)) return;
                setDialogState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final selectedIndex = selected.indexOf(action);
                  selected.removeAt(selectedIndex);
                  selected.insert(newIndex.clamp(0, selected.length), action);
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                controller.setPlayerQuickActions(selected);
                Navigator.pop(dialogContext);
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(backupServiceProvider).shareBackup();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupFailed)),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreBackup),
        content: Text(l10n.restoreBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreBackup),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final summary = await ref.read(backupServiceProvider).pickAndRestore();
      if (summary == null || !mounted) return;
      ref.read(settingsControllerProvider.notifier).reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupRestored)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupFailed)),
      );
    }
  }

  String _quickActionLabel(
    AppLocalizations l10n,
    PlayerQuickAction action,
  ) =>
      switch (action) {
        PlayerQuickAction.cast => l10n.castToTv,
        PlayerQuickAction.pictureInPicture => l10n.pictureInPicture,
        PlayerQuickAction.subtitles => l10n.subtitles,
        PlayerQuickAction.quality => l10n.quality,
        PlayerQuickAction.speed => l10n.playbackSpeed,
        PlayerQuickAction.videoFit => l10n.videoZoom,
        PlayerQuickAction.stats => l10n.statsForNerds,
        PlayerQuickAction.settings => l10n.settingsTab,
      };

  IconData _quickActionIcon(PlayerQuickAction action) => switch (action) {
        PlayerQuickAction.cast => Icons.cast,
        PlayerQuickAction.pictureInPicture => Icons.picture_in_picture,
        PlayerQuickAction.subtitles => Icons.closed_caption_outlined,
        PlayerQuickAction.quality => Icons.high_quality_outlined,
        PlayerQuickAction.speed => Icons.speed,
        PlayerQuickAction.videoFit => Icons.aspect_ratio,
        PlayerQuickAction.stats => Icons.info_outline,
        PlayerQuickAction.settings => Icons.settings,
      };

  void _showClickbaitPicker(AppSettings settings) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in ClickbaitThumbnail.values)
              RadioListTile<ClickbaitThumbnail>(
                title: Text(style.label(l10n)),
                value: style,
                groupValue: settings.clickbaitThumbnail,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .setClickbaitThumbnail(value);
                  }
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.followSystem;
      case AppThemeMode.light:
        return l10n.light;
      case AppThemeMode.dark:
        return l10n.dark;
    }
  }

  /// Anything that is not one of the two shipped locales — including the
  /// [systemLanguageCode] sentinel — follows the device.
  String _languageLabel(AppLocalizations l10n, String code) => switch (code) {
        'en' => 'English',
        'ar' => 'العربية',
        _ => l10n.systemDefault,
      };

  /// Label for the default-subtitle-language picker. Reuses
  /// [_languageLabel] for the concrete locales so the two lists cannot
  /// disagree about what "ar" is called.
  String _subtitleLanguageLabel(AppLocalizations l10n, String code) =>
      switch (code) {
        appDefaultSubtitleLanguage => l10n.subtitleLanguageAppDefault,
        noPreferredSubtitleLanguage => l10n.off,
        _ => _languageLabel(l10n, code),
      };
}

// ============================================================
// Row model
// ============================================================

class _SettingsSection {
  const _SettingsSection({required this.title, required this.rows});

  final String title;
  final List<_SettingsRow> rows;
}

class _SettingsRow {
  const _SettingsRow({required this.keywords, required this.widget});

  /// Everything the row says, matched against the settings search field.
  final List<String> keywords;
  final Widget widget;

  bool matches(String lowercaseQuery) =>
      keywords.any((k) => k.toLowerCase().contains(lowercaseQuery));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
