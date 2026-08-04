// ============================================================
// SettingsScreen - شجرة الإعدادات الكاملة
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/preferences/settings_repository_impl.dart';
import '../../../domain/entities/content_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/media_format.dart';
import '../../../domain/entities/sponsor_segment.dart';
import '../../l10n/enum_labels.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider) is SignedIn;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTab)),
      body: ListView(
        children: [
          // ============================================================
          // Account
          // ============================================================
          _SectionHeader(title: l10n.accountSection),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(signedIn ? l10n.signedIn : l10n.signIn),
            subtitle: Text(
              signedIn ? l10n.signedInSubtitle : l10n.signInSubtitle,
            ),
            onTap: () => context.push('/sign-in'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.downloads),
            subtitle: Text(l10n.downloadsSubtitle),
            onTap: () => context.push('/downloads'),
          ),

          const Divider(),

          // ============================================================
          // General
          // ============================================================
          _SectionHeader(title: l10n.generalSection),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(l10n, settings.themeMode)),
            onTap: () => _showThemePicker(context, settings, controller),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(settings.language == 'ar' ? 'العربية' : 'English'),
            onTap: () => _showLanguagePicker(context, settings, controller),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: Text(l10n.notifications),
            value: settings.notificationsEnabled,
            onChanged: controller.setNotificationsEnabled,
          ),

          const Divider(),

          // ============================================================
          // Player
          // ============================================================
          _SectionHeader(title: l10n.playerSection),
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: Text(l10n.defaultQuality),
            subtitle: Text(settings.defaultQuality.label(l10n)),
            onTap: () => _showQualityPicker(context, settings, controller),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: Text(l10n.defaultSpeed),
            subtitle: Text('${settings.defaultSpeed}x'),
            onTap: () => _showSpeedPicker(context, settings, controller),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.headphones),
            title: Text(l10n.backgroundPlayback),
            subtitle: Text(l10n.backgroundPlaybackSubtitle),
            value: settings.backgroundPlayback,
            onChanged: controller.setBackgroundPlayback,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.touch_app),
            title: Text(l10n.doubleTapToSeek),
            subtitle: Text(l10n.doubleTapToSeekSubtitle),
            value: settings.doubleTapToSeek,
            onChanged: controller.setDoubleTapToSeek,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.picture_in_picture),
            title: Text(l10n.pictureInPicture),
            value: settings.pictureInPictureEnabled,
            onChanged: controller.setPictureInPictureEnabled,
          ),

          const Divider(),

          // ============================================================
          // Feed — what shows up in Home / Subscriptions / Search
          // ============================================================
          _SectionHeader(title: l10n.feedSection),
          ...HiddenContent.values.map(
            (rule) => SwitchListTile(
              title: Text(l10n.hideItem(rule.label(l10n))),
              value: settings.hiddenContent.contains(rule),
              onChanged: (hide) => controller.toggleHiddenContent(rule, hide),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.thumbnails),
            subtitle: Text(settings.clickbaitThumbnail.label(l10n)),
            onTap: () => _showClickbaitPicker(context, ref, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.title),
            title: Text(l10n.deArrow),
            subtitle: Text(l10n.deArrowSubtitle),
            value: settings.deArrowEnabled,
            onChanged: controller.setDeArrowEnabled,
          ),
          if (settings.blockedChannelIds.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.blockedChannels),
              subtitle:
                  Text(l10n.blockedCount(settings.blockedChannelIds.length)),
              trailing: TextButton(
                onPressed: () {
                  for (final id in {...settings.blockedChannelIds}) {
                    controller.unblockChannel(id);
                  }
                },
                child: Text(l10n.unblockAll),
              ),
            ),

          const Divider(),

          // ============================================================
          // SponsorBlock
          // ============================================================
          _SectionHeader(title: l10n.sponsorBlockSection),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next),
            title: Text(l10n.enableSponsorBlock),
            subtitle: Text(l10n.enableSponsorBlockSubtitle),
            value: settings.sponsorBlockEnabled,
            onChanged: controller.setSponsorBlockEnabled,
          ),
          if (settings.sponsorBlockEnabled) ...[
            SwitchListTile(
              secondary: const Icon(Icons.fast_forward),
              title: Text(l10n.autoSkipSponsors),
              subtitle: Text(l10n.autoSkipSponsorsSubtitle),
              value: settings.autoSkipSponsors,
              onChanged: controller.setAutoSkipSponsors,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.sponsorSkipCategories,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...SponsorCategory.values.map((cat) => SwitchListTile(
                  dense: true,
                  title: Text(cat.label(l10n)),
                  value: settings.sponsorCategories.contains(cat),
                  onChanged: (v) => controller.toggleSponsorCategory(cat, v),
                )),
          ],

          const Divider(),

          // ============================================================
          // About
          // ============================================================
          _SectionHeader(title: l10n.aboutSection),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            trailing: const Text('0.1.0+1'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(l10n.checkForUpdates),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.noUpdatesAvailable)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.openSourceLicenses),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'SmartTube',
                applicationVersion: '0.1.0+1',
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Pickers
  // ============================================================

  void _showThemePicker(
    BuildContext context,
    AppSettings settings,
    SettingsController controller,
  ) {
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
    BuildContext context,
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          RadioListTile<String>(
            value: 'en',
            groupValue: settings.language,
            onChanged: (v) {
              if (v != null) {
                controller.setLanguage(v);
                Navigator.pop(context);
              }
            },
            title: const Text('English'),
          ),
          RadioListTile<String>(
            value: 'ar',
            groupValue: settings.language,
            onChanged: (v) {
              if (v != null) {
                controller.setLanguage(v);
                Navigator.pop(context);
              }
            },
            title: const Text('العربية'),
          ),
        ],
      ),
    );
  }

  void _showQualityPicker(
    BuildContext context,
    AppSettings settings,
    SettingsController controller,
  ) {
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

  void _showSpeedPicker(
    BuildContext context,
    AppSettings settings,
    SettingsController controller,
  ) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
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

  void _showClickbaitPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

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
