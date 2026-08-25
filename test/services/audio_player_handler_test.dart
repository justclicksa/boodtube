// ============================================================
// The notification's control row
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/services/audio_player_handler.dart';

import '../support/fake_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('notificationControls', () {
    test('offers skip buttons only when something is wired to them', () {
      final none = notificationControls(
        playing: true,
        hasNext: false,
        hasPrevious: false,
      );
      expect(none.controls, isNot(contains(MediaControl.skipToNext)));
      expect(none.controls, isNot(contains(MediaControl.skipToPrevious)));

      final next = notificationControls(
        playing: true,
        hasNext: true,
        hasPrevious: false,
      );
      expect(next.controls, contains(MediaControl.skipToNext));
      expect(next.controls, isNot(contains(MediaControl.skipToPrevious)));
    });

    test('shows pause while playing and play while paused', () {
      expect(
        notificationControls(playing: true, hasNext: false, hasPrevious: false)
            .controls,
        contains(MediaControl.pause),
      );
      expect(
        notificationControls(playing: false, hasNext: false, hasPrevious: false)
            .controls,
        contains(MediaControl.play),
      );
    });

    test('every compact index points at a control that exists', () {
      // The regression this guards: the indices were hardcoded [1, 2, 3],
      // which is past the end of a three-button row. Android drops the
      // collapsed view entirely when an index is out of range.
      for (final playing in [true, false]) {
        for (final hasNext in [true, false]) {
          for (final hasPrevious in [true, false]) {
            final row = notificationControls(
              playing: playing,
              hasNext: hasNext,
              hasPrevious: hasPrevious,
            );
            expect(row.compactIndices, hasLength(3));
            for (final index in row.compactIndices) {
              expect(
                index,
                allOf(greaterThanOrEqualTo(0), lessThan(row.controls.length)),
                reason: 'playing=$playing next=$hasNext prev=$hasPrevious',
              );
            }
            expect(
              row.compactIndices.toSet(),
              hasLength(3),
              reason: 'the collapsed view must show three distinct buttons',
            );
          }
        }
      }
    });

    test('the collapsed view keeps play/pause in the middle', () {
      final row = notificationControls(
        playing: true,
        hasNext: true,
        hasPrevious: true,
      );
      expect(row.controls[row.compactIndices[1]], MediaControl.pause);
      expect(row.controls[row.compactIndices[0]], MediaControl.skipToPrevious);
      expect(row.controls[row.compactIndices[2]], MediaControl.skipToNext);
    });
  });

  group('SmartTubeAudioHandler.refreshControls', () {
    test('publishes skipToNext only once a queue is wired up', () {
      final handler = SmartTubeAudioHandler(fakePlayer())..refreshControls();

      expect(
        handler.playbackState.value.controls,
        isNot(contains(MediaControl.skipToNext)),
      );
      expect(handler.playbackState.value.controls, isNotEmpty);

      handler
        ..onSkipNext = (() async {})
        ..refreshControls();
      expect(
        handler.playbackState.value.controls,
        contains(MediaControl.skipToNext),
      );

      // Emptying the queue takes the button away again.
      handler
        ..onSkipNext = null
        ..refreshControls();
      expect(
        handler.playbackState.value.controls,
        isNot(contains(MediaControl.skipToNext)),
      );
    });

    test('the published skip action runs the wired callback', () async {
      final handler = SmartTubeAudioHandler(fakePlayer());
      var skipped = 0;
      handler.onSkipNext = () async => skipped++;

      await handler.skipToNext();
      expect(skipped, 1);

      handler.onSkipNext = null;
      await handler.skipToNext();
      expect(skipped, 1, reason: 'nothing wired: the tap is a no-op');
    });
  });
}
