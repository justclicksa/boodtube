// ============================================================
// ErrorView Widget
// ============================================================

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Also rendered inside the 16:9 player box, which is far shorter
    // than a full screen — scroll rather than overflow there.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 260;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: compact ? 32 : 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    Text(
                      _getErrorMessage(error),
                      textAlign: TextAlign.center,
                      style: compact
                          ? Theme.of(context).textTheme.bodyMedium
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: compact ? 8 : 16),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection';
    }
    if (msg.contains('not found')) {
      return 'Content not found';
    }
    if (msg.contains('unauthorized')) {
      return 'Authentication required';
    }
    return 'Something went wrong';
  }
}
