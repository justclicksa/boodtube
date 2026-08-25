import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/youtube/storyboard_service.dart';

/// A real-shaped `playerStoryboardSpecRenderer.spec`: three levels, the
/// coarse one with no frame interval, and a base URL that already
/// carries a query string.
const _spec =
    r'https://i.ytimg.com/sb/dQw4w9WgXcQ/storyboard3_L$L/$N.jpg'
    '?sqp=-oaymwENSDfyq4qpAwVwAcABBqLzl_8DBgii4tzABg=='
    r'|48#27#100#10#10#0#default#rs$AOn4CLD1Q3z0'
    r'|80#45#90#10#10#2000#M$M#rs$AOn4CLBz9C7L'
    r'|160#90#90#5#5#2000#M$M#rs$AOn4CLCXvQdd';

void main() {
  group('StoryboardSpec.parse', () {
    test('reads the base URL and every level', () {
      final spec = StoryboardSpec.parse(_spec)!;

      expect(
        spec.baseUrl,
        startsWith('https://i.ytimg.com/sb/dQw4w9WgXcQ/storyboard3_L'),
      );
      expect(spec.levels, hasLength(3));

      final coarse = spec.levels[0];
      expect(coarse.index, 0);
      expect(coarse.width, 48);
      expect(coarse.height, 27);
      expect(coarse.frameCount, 100);
      expect(coarse.columns, 10);
      expect(coarse.rows, 10);
      expect(coarse.interval, Duration.zero);
      expect(coarse.name, 'default');
      expect(coarse.signature, r'rs$AOn4CLD1Q3z0');
      expect(coarse.isTimeIndexed, isFalse);

      final finest = spec.levels[2];
      expect(finest.index, 2);
      expect(finest.width, 160);
      expect(finest.columns, 5);
      expect(finest.rows, 5);
      expect(finest.interval, const Duration(seconds: 2));
      expect(finest.framesPerSheet, 25);
      // 90 frames over 25-frame sheets.
      expect(finest.sheetCount, 4);
      expect(finest.isTimeIndexed, isTrue);
    });

    test('unescapes slashes as they arrive inside raw JSON', () {
      final spec = StoryboardSpec.parse(
        r'https:\/\/i.ytimg.com\/sb\/ID\/storyboard3_L$L\/$N.jpg'
        r'|160#90#90#5#5#2000#M$M#sig',
      )!;

      expect(spec.baseUrl, contains('https://i.ytimg.com/sb/ID/'));
      expect(spec.baseUrl, isNot(contains(r'\/')));
    });

    test('tolerates a level without a name or signature', () {
      final spec = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg|160#90#40#4#5#1000',
      )!;

      expect(spec.levels.single.name, r'M$M');
      expect(spec.levels.single.signature, isNull);
      expect(spec.sheetUrl(spec.levels.single, 2), 'https://host/L0/M2.jpg');
    });

    test('rejects nothing usable', () {
      expect(StoryboardSpec.parse(null), isNull);
      expect(StoryboardSpec.parse(''), isNull);
      expect(StoryboardSpec.parse('https://host/only-a-url'), isNull);
      expect(StoryboardSpec.parse('https://host/x|not#a#level'), isNull);
      expect(StoryboardSpec.parse('https://host/x|0#0#0#0#0#0#n#s'), isNull);
    });

    test('the single-section live form is not addressable by time', () {
      // Live specs carry no interval, so there is no frame to show.
      expect(
        StoryboardSpec.parse(
          'https://i.ytimg.com/sb/CFsd4UxzpLo/storyboard_live_90_3x3_b1/'
          r'M$M.jpg?rs=AOn4CLAa9egp#159#90#3#3',
        ),
        isNull,
      );
    });
  });

  group('StoryboardSpec.previewLevel', () {
    test('picks the mid 160x90 level, not the interval-less coarse one', () {
      final level = StoryboardSpec.parse(_spec)!.previewLevel!;

      expect(level.index, 2);
      expect(level.width, 160);
      expect(level.height, 90);
    });

    test('falls back to the only timed level available', () {
      final spec = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg'
        '|48#27#100#10#10#0#default#a'
        r'|80#45#90#10#10#2000#M$M#b',
      )!;

      expect(spec.previewLevel!.width, 80);
    });

    test('is null when no level carries an interval', () {
      final spec = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg|48#27#100#10#10#0#default#a',
      )!;

      expect(spec.previewLevel, isNull);
      expect(spec.tileAt(const Duration(seconds: 5)), isNull);
    });
  });

  group('StoryboardSpec.sheetUrl', () {
    test('substitutes the level, name and sheet number', () {
      final spec = StoryboardSpec.parse(_spec)!;
      final url = spec.sheetUrl(spec.previewLevel!, 3);

      expect(url, contains('/storyboard3_L2/M3.jpg'));
    });

    test('appends the signature onto the existing query string', () {
      final spec = StoryboardSpec.parse(_spec)!;
      final url = spec.sheetUrl(spec.previewLevel!, 0);

      expect(url, contains('?sqp='));
      expect(url, endsWith(r'&sigh=rs$AOn4CLCXvQdd'));
    });

    test('starts a query string when the base URL has none', () {
      final spec = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg|160#90#40#4#5#1000#M$M#sig',
      )!;

      expect(
        spec.sheetUrl(spec.levels.single, 1),
        'https://host/L0/M1.jpg?sigh=sig',
      );
    });
  });

  group('StoryboardSpec.tileAt', () {
    late StoryboardSpec spec;

    setUp(() => spec = StoryboardSpec.parse(_spec)!);

    test('the start of the video is the first cell of the first sheet', () {
      final tile = spec.tileAt(Duration.zero)!;

      expect(tile.sheetIndex, 0);
      expect(tile.column, 0);
      expect(tile.row, 0);
      expect(tile.columns, 5);
      expect(tile.rows, 5);
      expect(tile.tileWidth, 160);
      expect(tile.tileHeight, 90);
      expect(tile.start, Duration.zero);
      expect(tile.sheetUrl, contains('/storyboard3_L2/M0.jpg'));
    });

    test('walks across the first row before dropping to the next', () {
      // 2s per frame, 5 columns: 7s is frame 3 of row 0.
      expect(spec.tileAt(const Duration(seconds: 7))!.column, 3);
      expect(spec.tileAt(const Duration(seconds: 7))!.row, 0);

      // 11s is frame 5 — first cell of row 1.
      final wrapped = spec.tileAt(const Duration(seconds: 11))!;
      expect(wrapped.column, 0);
      expect(wrapped.row, 1);
      expect(wrapped.start, const Duration(seconds: 10));
    });

    test('rolls over to the next sheet after 25 frames', () {
      final tile = spec.tileAt(const Duration(seconds: 52))!;

      expect(tile.sheetIndex, 1);
      expect(tile.column, 1);
      expect(tile.row, 0);
      expect(tile.sheetUrl, contains('/storyboard3_L2/M1.jpg'));
    });

    test('divides by the column count on a non-square grid', () {
      // The Java original divides by the row count here and lands on the
      // wrong cell whenever rows != columns.
      final wide = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg|160#90#30#5#3#1000#M$M#sig',
      )!;
      final tile = wide.tileAt(const Duration(seconds: 7))!;

      expect(tile.row, 1);
      expect(tile.column, 2);
    });

    test('clamps a negative or past-the-end position', () {
      expect(spec.tileAt(const Duration(seconds: -5))!.column, 0);

      // 90 frames, so frame 89: sheet 3, cell 14 -> row 2, column 4.
      final last = spec.tileAt(const Duration(hours: 3))!;
      expect(last.sheetIndex, 3);
      expect(last.row, 2);
      expect(last.column, 4);
    });

    test('honours an explicitly chosen level', () {
      final tile = spec.tileAt(
        const Duration(seconds: 7),
        level: spec.levels[1],
      )!;

      expect(tile.tileWidth, 80);
      expect(tile.columns, 10);
      expect(tile.sheetUrl, contains('/storyboard3_L1/M0.jpg'));
    });
  });

  group('StoryboardSpec.fromPlayerResponse', () {
    test('reads playerStoryboardSpecRenderer.spec', () {
      final spec = StoryboardSpec.fromPlayerResponse({
        'videoDetails': {'videoId': 'dQw4w9WgXcQ'},
        'storyboards': {
          'playerStoryboardSpecRenderer': {'spec': _spec},
        },
      });

      expect(spec, isNotNull);
      expect(spec!.levels, hasLength(3));
    });

    test('returns null when the response carries no storyboards', () {
      expect(StoryboardSpec.fromPlayerResponse(null), isNull);
      expect(StoryboardSpec.fromPlayerResponse(const {}), isNull);
      expect(
        StoryboardSpec.fromPlayerResponse(
          const {'storyboards': <String, dynamic>{}},
        ),
        isNull,
      );
      expect(
        StoryboardSpec.fromPlayerResponse(const {
          'storyboards': {
            'playerLiveStoryboardSpecRenderer': {'spec': 'https://host/x#1#2'},
          },
        }),
        isNull,
      );
    });
  });
}
