// ============================================================
// Unit tests for MediaItem entity
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/entities/media_format.dart';
import 'package:smarttube_poc/domain/entities/media_subtitle.dart';
import 'package:smarttube_poc/domain/entities/chapter_item.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart';

void main() {
  group('MediaItem', () {
    test('creates instance with required fields', () {
      final item = MediaItem(
        videoId: 'abc123',
        title: 'Test Video',
        author: 'Test Channel',
        channelId: 'UC123',
        duration: const Duration(minutes: 5),
        publishedAt: DateTime(2026, 1, 1),
        formats: const [],
        subtitles: const [],
        chapters: const [],
      );

      expect(item.videoId, 'abc123');
      expect(item.title, 'Test Video');
      expect(item.isLive, isFalse);
      expect(item.isShorts, isFalse);
    });

    test('id returns videoId', () {
      final item = _makeItem(videoId: 'xyz789');
      expect(item.id, 'xyz789');
    });

    test('isInProgress returns true for partially watched', () {
      final item = _makeItem(percentWatched: 50);
      expect(item.isInProgress, isTrue);
    });

    test('isInProgress returns false for fully watched', () {
      final item = _makeItem(percentWatched: 100);
      expect(item.isInProgress, isFalse);
    });

    test('isInProgress returns false for unwatched', () {
      final item = _makeItem();
      expect(item.isInProgress, isFalse);
    });

    test('bestFormat returns highest bitrate', () {
      final item = _makeItem(
        formats: [
          const MediaFormat(
            formatId: '1',
            url: 'url1',
            mimeType: 'video/mp4',
            codec: 'avc1',
            bitrate: 1000,
          ),
          const MediaFormat(
            formatId: '2',
            url: 'url2',
            mimeType: 'video/mp4',
            codec: 'avc1',
            bitrate: 5000,
          ),
          const MediaFormat(
            formatId: '3',
            url: 'url3',
            mimeType: 'video/mp4',
            codec: 'avc1',
            bitrate: 3000,
          ),
        ],
      );

      expect(item.bestFormat?.bitrate, 5000);
    });

    test('bestFormat returns null when no formats', () {
      final item = _makeItem(formats: const []);
      expect(item.bestFormat, isNull);
    });
  });

  group('SponsorSegment', () {
    test('isActiveAt returns true when position within segment', () {
      const segment = SponsorSegment(
        start: Duration(seconds: 10),
        end: Duration(seconds: 20),
        category: SponsorCategory.sponsor,
      );

      expect(segment.isActiveAt(const Duration(seconds: 15)), isTrue);
      expect(segment.isActiveAt(const Duration(seconds: 5)), isFalse);
      expect(segment.isActiveAt(const Duration(seconds: 25)), isFalse);
    });
  });

  group('MediaFormat', () {
    test('parsedHeight extracts from qualityLabel', () {
      const format = MediaFormat(
        formatId: '1',
        url: 'url',
        mimeType: 'video/mp4',
        codec: 'avc1',
        bitrate: 1000,
        qualityLabel: '1080p60',
      );

      expect(format.parsedHeight, 1080);
    });

    test('displayLabel includes quality and codec', () {
      const format = MediaFormat(
        formatId: '1',
        url: 'url',
        mimeType: 'video/mp4',
        codec: 'vp9',
        bitrate: 1000,
        qualityLabel: '720p',
      );

      expect(format.displayLabel, '720p • VP9');
    });
  });
}

MediaItem _makeItem({
  String videoId = 'test',
  String title = 'Test',
  String author = 'Author',
  String channelId = 'channel',
  Duration duration = const Duration(minutes: 1),
  DateTime? publishedAt,
  List<MediaFormat> formats = const [],
  List<MediaSubtitle> subtitles = const [],
  List<ChapterItem> chapters = const [],
  int? percentWatched,
}) {
  return MediaItem(
    videoId: videoId,
    title: title,
    author: author,
    channelId: channelId,
    duration: duration,
    publishedAt: publishedAt ?? DateTime(2026, 1, 1),
    formats: formats,
    subtitles: subtitles,
    chapters: chapters,
    percentWatched: percentWatched,
  );
}
