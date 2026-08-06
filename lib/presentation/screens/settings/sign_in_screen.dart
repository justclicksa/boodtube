// ============================================================
// SignInScreen — device-code login, mirroring SmartTube's flow
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).signIn)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.account_circle_outlined,
          size: 72,
          semanticLabel: l10n.signIn,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.signIn,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.signInSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.signInUnofficialWarning,
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
          const SizedBox(height: AppSpacing.md),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: onStart,
          child: Text(l10n.getSignInCode),
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
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.signInStepOpenPage,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(code.verificationUrl),
          onPressed: () => launchUrl(
            Uri.parse(code.verificationUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.signInStepEnterCode, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        // The code box is the copy button; say so rather than leaving a
        // screen reader to guess why a heading is tappable. "Copy" ships
        // translated with the framework.
        Semantics(
          label: '${code.userCode}, ${material.copyButtonLabel}',
          button: true,
          excludeSemantics: true,
          child: Tooltip(
            message: material.copyButtonLabel,
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: code.userCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.codeCopied)),
                  );
                }
              },
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
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
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(l10n.waitingForApproval),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: onCancel,
          child: Text(l10n.cancel),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle,
          size: 72,
          color: theme.colorScheme.primary,
          semanticLabel: l10n.signedIn,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.signedIn,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.signedInKeystoreNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: onSignOut,
          child: Text(l10n.signOut),
        ),
      ],
    );
  }
}
