// ============================================================
// iOS sign-in + download smoke tests
// ============================================================
// Neither path needs a widget tree, so both run against a bare
// ProviderContainer. Anything that needs the real app lives in its own
// file: main() calls AudioService.init(), which cannot run twice in one
// process, and the widget tree is torn down between testWidgets.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/presentation/providers/auth_providers.dart';
import 'package:smarttube_poc/presentation/providers/downloads_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/services/download_manager.dart';

Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 60),
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

Future<ProviderContainer> headlessContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<MediaItem?> firstPlayableResult(ProviderContainer container) async {
  final search = await container
      .read(contentRepositoryProvider)
      .search('flutter widget of the week');
  final items = search.dataOrNull?.mediaItems ?? const <MediaItem>[];
  for (final item in items) {
    if (!item.isLive) return item;
  }
  return null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Stops where a human has to type the code — the one boundary the app
  // cannot cross by itself. Proves the TV client IDs still work and that
  // Dio reaches Google over iOS TLS.
  testWidgets('sign-in: Google issues a device code over iOS TLS',
      (tester) async {
    final container = await headlessContainer();
    addTearDown(container.dispose);

    final code = await container.read(oauthClientProvider).requestDeviceCode();

    debugPrint('IOSTEST[auth]: userCode=${code.userCode} '
        'url=${code.verificationUrl} expires=${code.expiresIn} '
        'interval=${code.interval}');

    expect(code.userCode, isNotEmpty);
    expect(code.deviceCode, isNotEmpty);
    expect(code.verificationUrl, contains('google.com'));
    expect(code.expiresIn, greaterThan(Duration.zero));
  });

  // Runs the real relay against real googlevideo bytes and writes into
  // the app's Documents directory, then cancels — the write path without
  // pulling down a whole video.
  testWidgets('downloads: bytes land in Documents/downloads', (tester) async {
    final container = await headlessContainer();

    final item = await firstPlayableResult(container);
    expect(item, isNotNull, reason: 'search returned nothing downloadable');

    final manager = container.read(downloadManagerProvider);
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/downloads',
    );

    DownloadProgress? seen;
    final sub = manager.progressStream.listen((map) {
      final p = map[item!.videoId];
      if (p != null) seen = p;
    });

    // Not awaited: we want to watch it run, not wait for a whole file.
    unawaited(manager.download(item!));

    final started = await pumpUntil(
      tester,
      () => (seen?.progress ?? 0) > 0 || seen?.status == DownloadStatus.failed,
      timeout: const Duration(seconds: 90),
    );
    debugPrint('IOSTEST[download]: started=$started status=${seen?.status} '
        'progress=${seen?.progress} error=${seen?.error}');

    final videoFile = File('${dir.path}/${item.videoId}.video');
    final bytes = videoFile.existsSync() ? videoFile.lengthSync() : 0;
    debugPrint('IOSTEST[download]: ${videoFile.path} -> $bytes bytes');

    await manager.cancel(item.videoId);
    // Let the in-flight slice notice the cancel before the container
    // takes the manager out from under it.
    await pumpUntil(tester, () => false, timeout: const Duration(seconds: 3));
    await sub.cancel();
    container.dispose();

    expect(seen?.status, isNot(DownloadStatus.failed),
        reason: 'download failed: ${seen?.error}');
    expect(bytes, greaterThan(0), reason: 'no bytes written to Documents');
  });
}
