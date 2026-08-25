// ============================================================
// The scrub bar's duration / time-left label
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/l10n/app_localizations.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/presentation/screens/player/player_screen.dart';

import '../../../support/player_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const state = PlayerStateData(
    duration: Duration(minutes: 5),
    position: Duration(minutes: 1),
  );

  Future<PlayerTestHarness> pumpScrubBar(
    WidgetTester tester, {
    bool showRemainingTime = false,
    Locale locale = const Locale('en'),
  }) async {
    final harness = await playerTestHarness(
      initialPreferences: {'settings.remaining_time': showRemainingTime},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: PlayerScrubBar(
                  state: state,
                  onInteract: () {},
                  onToggleFullscreen: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return harness;
  }

  testWidgets('shows the total duration until it is tapped', (tester) async {
    final harness = await pumpScrubBar(tester);

    expect(find.text('1:00'), findsOneWidget, reason: 'elapsed');
    expect(find.text('5:00'), findsOneWidget, reason: 'total');

    await tester.tap(find.text('5:00'));
    await tester.pump();

    expect(find.text('5:00'), findsNothing);
    expect(find.text('-4:00'), findsOneWidget);
    expect(
      harness.container.read(settingsControllerProvider).showRemainingTime,
      isTrue,
      reason: 'the choice sticks',
    );
  });

  testWidgets('tapping the time left goes back to the total', (tester) async {
    final harness = await pumpScrubBar(tester, showRemainingTime: true);

    expect(find.text('-4:00'), findsOneWidget);

    await tester.tap(find.text('-4:00'));
    await tester.pump();

    expect(find.text('5:00'), findsOneWidget);
    expect(
      harness.container.read(settingsControllerProvider).showRemainingTime,
      isFalse,
    );
  });

  testWidgets('the time left stays left-to-right in Arabic', (tester) async {
    // The leading '-' is a neutral character: inside an RTL paragraph it
    // is reordered to the far end and the label reads "4:00-".
    await pumpScrubBar(
      tester,
      showRemainingTime: true,
      locale: const Locale('ar'),
    );

    expect(
      Directionality.of(tester.element(find.text('-4:00'))),
      TextDirection.rtl,
      reason: 'the surrounding layout really is RTL here',
    );
    expect(
      tester.widget<Text>(find.text('-4:00')).textDirection,
      TextDirection.ltr,
    );
  });
}
