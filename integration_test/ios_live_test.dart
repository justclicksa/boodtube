// ============================================================
// iOS live-broadcast smoke test
// ============================================================
// A live broadcast is the one stream that does NOT go through the
// loopback relay: it is a rolling HLS playlist handed to mpv over
// https, so ffmpeg fetches the segments itself. That makes it the only
// path exercising mpv's own TLS on iOS — the very thing the relay
// exists to avoid elsewhere. Own file because it needs the real app,
// and main() cannot run twice in one process.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/main.dart' as app;
import 'package:smarttube_poc/presentation/providers/content_providers.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/screens/browse/browse_screen.dart';

Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 90),
  Duration step = const Duration(milliseconds: 250),
}) async {
  var waited = Duration.zero;
  while (waited < timeout) {
    if (condition()) return true;
    await tester.pump(step);
    waited += step;
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live: an HLS broadcast opens and advances', (tester) async {
    app.main();
    await tester.pump();
    final ready = await pumpUntil(
      tester,
      () => find.byType(app.SmartTubeApp).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    );
    expect(ready, isTrue, reason: 'app never mounted');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(app.SmartTubeApp)),
    );

    // The app's own Live section first — it asks YouTube for the
    // `FEtopics_live` shelf, so everything in it is actually
    // broadcasting. Plain search rarely returns a live item at all.
    MediaItem? live;
    try {
      final section =
          await container.read(browseCategoryProvider(BrowseCategory.live)
              .future);
      live = section.cast<MediaItem?>().firstWhere(
            (MediaItem? i) => i != null && i.isLive,
            orElse: () => null,
          );
      debugPrint('IOSTEST[live]: Live section -> ${section.length} items, '
          'live hit=${live?.videoId ?? "none"}');
    } catch (e) {
      debugPrint('IOSTEST[live]: Live section unavailable: $e');
    }

    // Fall back to search; whether anything is broadcasting right now is
    // not under our control.
    for (final query in ['live now', 'news live stream', '24/7 live']) {
      if (live != null) break;
      final result =
          await container.read(contentRepositoryProvider).search(query);
      for (final item in result.dataOrNull?.mediaItems ?? const <MediaItem>[]) {
        if (item.isLive) {
          live = item;
          break;
        }
      }
      debugPrint(
          'IOSTEST[live]: "$query" -> ${live?.videoId ?? "no live hit"}');
    }

    if (live == null) {
      debugPrint('IOSTEST[live]: SKIPPED — no live broadcast surfaced. '
          'This is a search-result accident, not a pass.');
      return;
    }
    debugPrint('IOSTEST[live]: ${live.videoId} "${live.title}"');

    final controller = container.read(playerControllerProvider.notifier);
    unawaited(controller.loadVideo(live.videoId));

    final advanced = await pumpUntil(
      tester,
      () => container.read(playerControllerProvider).position > Duration.zero,
    );

    final s = container.read(playerControllerProvider);
    debugPrint('IOSTEST[live]: advanced=$advanced position=${s.position} '
        'isPlaying=${s.isPlaying} isLoading=${s.isLoading} error=${s.error}');

    expect(advanced, isTrue, reason: 'live stream never advanced: ${s.error}');
  });
}
