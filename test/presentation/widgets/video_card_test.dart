// ============================================================
// Widget tests for VideoCard
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smarttube_poc/l10n/app_localizations.dart';

import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/entities/media_format.dart';
import 'package:smarttube_poc/presentation/widgets/video_card.dart';

MediaItem _createTestItem({
  String videoId = 'test123',
  String title = 'Test Video',
  String author = 'Test Channel',
  Duration duration = const Duration(minutes: 5),
  String? thumbnailUrl = 'https://example.com/thumb.jpg',
  bool isLive = false,
  bool isShorts = false,
  int? percentWatched,
  int? viewCount = 1000,
}) {
  return MediaItem(
    videoId: videoId,
    title: title,
    author: author,
    channelId: 'channel123',
    duration: duration,
    publishedAt: DateTime(2026, 1, 1),
    thumbnailUrl: thumbnailUrl,
    formats: const [
      MediaFormat(
        formatId: '1',
        url: 'url',
        mimeType: 'video/mp4',
        codec: 'avc1',
        bitrate: 1000,
      ),
    ],
    subtitles: const [],
    chapters: const [],
    isLive: isLive,
    isShorts: isShorts,
    percentWatched: percentWatched,
    viewCount: viewCount,
  );
}

void main() {
  group('VideoCard', () {
    testWidgets('renders title and author', (tester) async {
      final item = _createTestItem(title: 'My Video', author: 'My Channel');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: VideoCard(item: item),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('My Video'), findsOneWidget);
      // The channel shares one metadata line with views and upload date,
      // the way YouTube's feed cards render it.
      expect(find.textContaining('My Channel'), findsOneWidget);
    });

    testWidgets('shows LIVE badge for live videos', (tester) async {
      final item = _createTestItem(isLive: true);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: VideoCard(item: item),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('shows duration badge for non-live videos', (tester) async {
      final item = _createTestItem(duration: const Duration(minutes: 5, seconds: 30));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: VideoCard(item: item),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('5:30'), findsOneWidget);
    });

    testWidgets('shows progress indicator for in-progress videos', (tester) async {
      final item = _createTestItem(percentWatched: 45);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: VideoCard(item: item),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      var tapped = false;
      final item = _createTestItem();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: VideoCard(
                item: item,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(VideoCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders horizontal layout when isHorizontal is true', (tester) async {
      final item = _createTestItem();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 120,
              child: VideoCard(item: item, isHorizontal: true),
            ),
          ),
        ),
      );

      await tester.pump();

      // Horizontal cards should have wider aspect ratio
      expect(find.text('Test Video'), findsOneWidget);
    });
  });
}
