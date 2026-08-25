// ============================================================
// The in-player quality menu
// ============================================================
// Which row carries the tick is the whole point of the "Auto" row: it
// has to be the resolution the user picked, or "Auto", never both.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/l10n/app_localizations.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/presentation/screens/player/widgets/player_settings_sheet.dart';

import '../../../support/player_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// True when the row with [label] is showing the tick.
  bool ticked(WidgetTester tester, String label) {
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
    );
    return tile.selected;
  }

  Future<PlayerTestHarness> openQualityMenu(
    WidgetTester tester, {
    required bool autoQuality,
    String? currentQualityLabel = '720p',
    List<int> heights = const [1080, 720, 480],
    int? pendingHeight,
  }) async {
    final harness = await playerTestHarness(
      initialPreferences: {'settings.auto_quality': autoQuality},
    );
    // ignore: invalid_use_of_protected_member
    harness.controller.state = harness.controller.state.copyWith(
      availableHeights: heights,
      currentQualityLabel: currentQualityLabel,
      pendingHeight: pendingHeight,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPlayerSettings(
                    context,
                    initialPage: PlayerSettingsPage.quality,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Not pumpAndSettle: a row that is still switching spins a
    // CircularProgressIndicator, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return harness;
  }

  testWidgets('auto quality ticks Auto and nothing else', (tester) async {
    await openQualityMenu(tester, autoQuality: true);

    // The label carries the resolution auto settled on, so the user can
    // still see what they are watching.
    expect(find.text('Auto (720p)'), findsOneWidget);
    expect(ticked(tester, 'Auto (720p)'), isTrue);
    expect(ticked(tester, '720p'), isFalse);
    expect(ticked(tester, '1080p (HD)'), isFalse);
  });

  testWidgets('a manual pick ticks its own row', (tester) async {
    await openQualityMenu(tester, autoQuality: false);

    expect(find.text('Auto'), findsOneWidget);
    expect(ticked(tester, 'Auto'), isFalse);
    expect(ticked(tester, '720p'), isTrue);
    expect(ticked(tester, '1080p (HD)'), isFalse);
  });

  testWidgets('a switch in flight ticks the pick, not Auto', (tester) async {
    await openQualityMenu(tester, autoQuality: true, pendingHeight: 1080);

    expect(ticked(tester, 'Auto (720p)'), isFalse);
    expect(ticked(tester, '1080p (HD)'), isTrue);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('1080p (HD)'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no Auto row when the video offers no alternatives',
      (tester) async {
    await openQualityMenu(
      tester,
      autoQuality: true,
      heights: const [],
      currentQualityLabel: null,
    );

    expect(find.text('Auto'), findsNothing);
    expect(find.textContaining('Auto ('), findsNothing);
  });

  testWidgets('choosing Auto hands quality back to the heuristic',
      (tester) async {
    final harness = await openQualityMenu(tester, autoQuality: false);
    expect(
      harness.container.read(settingsControllerProvider).autoQuality,
      isFalse,
    );

    await tester.tap(find.text('Auto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      harness.container.read(settingsControllerProvider).autoQuality,
      isTrue,
    );
  });
}
