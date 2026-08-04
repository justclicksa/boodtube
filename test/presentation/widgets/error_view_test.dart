// ============================================================
// Tests for ErrorView and LoadingView
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smarttube_poc/l10n/app_localizations.dart';

import 'package:smarttube_poc/presentation/widgets/error_view.dart';
import 'package:smarttube_poc/presentation/widgets/loading_view.dart';

void main() {
  group('ErrorView', () {
    testWidgets('shows error icon and retry button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorView(
              error: 'Test error',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shows network error message for network errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorView(
              error: 'NetworkException: No internet',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('shows not found message for not found errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorView(
              error: 'NotFoundException: Content not found',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Content not found'), findsOneWidget);
    });

    testWidgets('triggers onRetry when button tapped', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorView(
              error: 'Test error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });

  group('LoadingView', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LoadingView(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LoadingView(message: 'Loading videos...'),
          ),
        ),
      );

      expect(find.text('Loading videos...'), findsOneWidget);
    });
  });
}
