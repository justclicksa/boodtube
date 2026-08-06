// ============================================================
// EmptyView Widget
// ============================================================

import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.secondaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Primary way out of the empty state — usually a filled button.
  final Widget? action;

  /// Optional second, lower-emphasis way out shown beside [action].
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            if (action != null || secondaryAction != null) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (action != null) action!,
                  if (secondaryAction != null) secondaryAction!,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
