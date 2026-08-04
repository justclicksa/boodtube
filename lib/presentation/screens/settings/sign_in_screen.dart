// ============================================================
// SignInScreen — device-code login, mirroring SmartTube's flow
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_providers.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).signIn)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (state) {
          SignedIn(:final expiresAt) => _SignedInView(
              expiresAt: expiresAt,
              onSignOut: controller.signOut,
            ),
          AwaitingCode(:final code) => _CodeView(
              code: code,
              onCancel: controller.cancel,
            ),
          SignedOut(:final error) => _SignedOutView(
              error: error,
              onStart: controller.startSignIn,
            ),
        },
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.error, required this.onStart});
  final String? error;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.account_circle_outlined, size: 72),
        const SizedBox(height: 16),
        Text(
          'Sign in with your Google account',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Signing in enables your real subscriptions, playlists and watch '
          'history instead of the local-only ones.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This app is not an official YouTube client. Google may '
                    'restrict or suspend accounts used with unofficial '
                    'clients. Consider using a secondary account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onStart,
          child: Text(AppLocalizations.of(context).getSignInCode),
        ),
      ],
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, required this.onCancel});
  final DeviceCode code;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('1. Open this page on any device',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(code.verificationUrl),
          onPressed: () => launchUrl(
            Uri.parse(code.verificationUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 24),
        Text('2. Enter this code', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code.userCode));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).codeCopied)),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              code.userCode,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).waitingForApproval),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: onCancel,
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ],
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.expiresAt, required this.onSignOut});
  final DateTime expiresAt;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Signed in',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'The session refreshes automatically. Your token is stored in the '
          'device keystore and never leaves this phone.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: onSignOut,
          child: Text(AppLocalizations.of(context).signOut),
        ),
      ],
    );
  }
}
