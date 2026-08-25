import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';

SponsorSegment _segment(
  SponsorCategory category,
  int startSeconds,
  int endSeconds, {
  String? uuid,
}) =>
    SponsorSegment(
      start: Duration(seconds: startSeconds),
      end: Duration(seconds: endSeconds),
      category: category,
      uuid: uuid,
    );

void main() {
  group('SponsorCategory API mapping', () {
    test('uses the names the API actually files segments under', () {
      expect(SponsorCategory.highlight.apiValue, 'poi_highlight');
      expect(SponsorCategory.exclusiveAccess.apiValue, 'exclusive_access');
      expect(SponsorCategory.selfPromo.apiValue, 'selfpromo');
    });

    test('pairs each category with the action type it is filed under', () {
      expect(SponsorCategory.sponsor.apiActionType, 'skip');
      expect(SponsorCategory.highlight.apiActionType, 'poi');
      expect(SponsorCategory.exclusiveAccess.apiActionType, 'full');
    });

    test('parses both highlight spellings and rejects unknown ones', () {
      expect(
        SponsorCategoryX.tryFromApiValue('poi_highlight'),
        SponsorCategory.highlight,
      );
      expect(
        SponsorCategoryX.tryFromApiValue('highlight'),
        SponsorCategory.highlight,
      );
      expect(SponsorCategoryX.tryFromApiValue('chapter'), isNull);
    });

    test('only time-spanning categories are skippable', () {
      expect(SponsorCategory.sponsor.isSkippable, isTrue);
      expect(SponsorCategory.highlight.isSkippable, isFalse);
      expect(SponsorCategory.exclusiveAccess.isSkippable, isFalse);
    });

    test('carries the SponsorBlock category colours', () {
      expect(SponsorCategory.sponsor.colorValue, 0xFF00D400);
      expect(SponsorCategory.musicOffTopic.colorValue, 0xFFFF9900);
      expect(SponsorCategory.filler.colorValue, 0xFF7300FF);
    });
  });

  group('resolveSegmentAction', () {
    test('falls back to the default for an unconfigured category', () {
      expect(
        resolveSegmentAction(const {}, SponsorCategory.sponsor),
        SegmentAction.skip,
      );
      expect(
        resolveSegmentAction(const {}, SponsorCategory.filler),
        SegmentAction.none,
      );
    });

    test('a stored action wins over the default', () {
      expect(
        resolveSegmentAction(
          const {SponsorCategory.sponsor: SegmentAction.none},
          SponsorCategory.sponsor,
        ),
        SegmentAction.none,
      );
    });
  });

  group('resolveSponsorSegmentAt', () {
    final segments = [
      _segment(SponsorCategory.sponsor, 10, 30, uuid: 'a'),
      _segment(SponsorCategory.filler, 40, 45, uuid: 'b'),
      _segment(SponsorCategory.highlight, 50, 50, uuid: 'c'),
    ];

    SegmentAction actionFor(SponsorCategory category) =>
        SponsorCategoryX.defaultAction(category);

    test('returns the segment and its action inside a segment', () {
      final match = resolveSponsorSegmentAt(
        segments: segments,
        position: const Duration(seconds: 20),
        actionFor: actionFor,
      );

      expect(match?.segment.uuid, 'a');
      expect(match?.action, SegmentAction.skip);
    });

    test('returns nothing between segments', () {
      expect(
        resolveSponsorSegmentAt(
          segments: segments,
          position: const Duration(seconds: 35),
          actionFor: actionFor,
        ),
        isNull,
      );
    });

    test('the end of a segment is already outside it', () {
      expect(
        resolveSponsorSegmentAt(
          segments: segments,
          position: const Duration(seconds: 30),
          actionFor: actionFor,
        ),
        isNull,
      );
    });

    test('a category set to none is passed over', () {
      expect(
        resolveSponsorSegmentAt(
          segments: segments,
          position: const Duration(seconds: 42),
          actionFor: actionFor,
        ),
        isNull,
      );

      final match = resolveSponsorSegmentAt(
        segments: segments,
        position: const Duration(seconds: 42),
        actionFor: (category) => SegmentAction.showButton,
      );
      expect(match?.segment.uuid, 'b');
      expect(match?.action, SegmentAction.showButton);
    });

    test('a highlight is never something to seek past', () {
      expect(
        resolveSponsorSegmentAt(
          segments: [_segment(SponsorCategory.highlight, 50, 60)],
          position: const Duration(seconds: 55),
          actionFor: (category) => SegmentAction.skip,
        ),
        isNull,
      );
    });

    test('an undone segment is left alone for the rest of the video', () {
      expect(
        resolveSponsorSegmentAt(
          segments: segments,
          position: const Duration(seconds: 20),
          actionFor: actionFor,
          doNotSkip: {segments.first.key},
        ),
        isNull,
      );
    });

    test('a segment without a UUID still has a stable key', () {
      final anonymous = _segment(SponsorCategory.sponsor, 10, 30);
      expect(anonymous.key, 'sponsor:10000-30000');
      expect(segments.first.key, 'a');
    });
  });
}
