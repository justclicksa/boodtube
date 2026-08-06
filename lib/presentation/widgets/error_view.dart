// ============================================================
// ErrorView Widget
// ============================================================
// One localized sentence per failure kind, chosen from the *type* of the
// error rather than by grepping its message. Raw exception text never
// reaches a release build — it is a debug aid, not a user-facing string.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/errors/exceptions.dart';
import '../../l10n/app_localizations.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = _kindOf(error);

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
                      _iconFor(kind),
                      size: compact ? 32 : 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    Text(
                      _messageFor(kind, l10n),
                      textAlign: TextAlign.center,
                      style: compact
                          ? Theme.of(context).textTheme.bodyMedium
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    // Developers get the real thing; users never do.
                    if (!compact && kDebugMode) ...[
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
                      label: Text(l10n.retry),
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

  /// Maps whatever was thrown onto the small set of things worth telling
  /// the user apart. Anything unrecognised is [_ErrorKind.unknown].
  _ErrorKind _kindOf(Object error) {
    if (error is AppException) {
      return switch (error) {
        NetworkException() => _ErrorKind.network,
        NotFoundException() => _ErrorKind.notFound,
        AuthException() => _ErrorKind.unauthorized,
        RateLimitException() => _ErrorKind.rateLimited,
        ParseException() => _ErrorKind.parse,
        DatabaseException() => _ErrorKind.database,
        YouTubeException() => _ErrorKind.youtube,
        UnknownException() => _ErrorKind.unknown,
      };
    }
    if (error is Failure) {
      return switch (error.type) {
        FailureType.network => _ErrorKind.network,
        FailureType.notFound => _ErrorKind.notFound,
        FailureType.unauthorized => _ErrorKind.unauthorized,
        FailureType.rateLimited => _ErrorKind.rateLimited,
        FailureType.parse => _ErrorKind.parse,
        FailureType.database => _ErrorKind.database,
        FailureType.unknown => _ErrorKind.unknown,
      };
    }
    // The transport layer's own types, which never get wrapped when a
    // request fails before the repository sees it.
    if (error is IOException || error is TimeoutException) {
      return _ErrorKind.network;
    }
    return _ErrorKind.unknown;
  }

  IconData _iconFor(_ErrorKind kind) => switch (kind) {
        _ErrorKind.network => Icons.cloud_off_outlined,
        _ErrorKind.notFound => Icons.search_off_outlined,
        _ErrorKind.unauthorized => Icons.lock_outline,
        _ErrorKind.rateLimited => Icons.hourglass_empty,
        _ErrorKind.parse ||
        _ErrorKind.database ||
        _ErrorKind.youtube ||
        _ErrorKind.unknown =>
          Icons.error_outline,
      };

  String _messageFor(_ErrorKind kind, AppLocalizations l10n) => switch (kind) {
        _ErrorKind.network => l10n.errorNetwork,
        _ErrorKind.notFound => l10n.errorNotFound,
        _ErrorKind.unauthorized => l10n.errorUnauthorized,
        _ErrorKind.rateLimited => l10n.errorRateLimited,
        _ErrorKind.parse => l10n.errorParse,
        _ErrorKind.database => l10n.errorDatabase,
        _ErrorKind.youtube => l10n.errorYouTube,
        _ErrorKind.unknown => l10n.errorUnknown,
      };
}

enum _ErrorKind {
  network,
  notFound,
  unauthorized,
  rateLimited,
  parse,
  database,
  youtube,
  unknown,
}
