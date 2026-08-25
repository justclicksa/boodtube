// ============================================================
// Playback modes, "Up next" countdown, and "previous"
// ============================================================
// Everything here is the controller's pure logic — no Player, no
// ProviderContainer — so the rules that decide what plays next can be
// pinned down without a running video.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';

MediaItem _item(
  String id, {
  Duration duration = const Duration(minutes: 10),
  bool isShorts = false,
  String title = 'Video',
}) {
  return MediaItem(
    videoId: id,
    title: title,
    author: 'Channel',
    channelId: 'UC$id',
    duration: duration,
    publishedAt: MediaItem.unknownDate,
    formats: const [],
    subtitles: const [],
    chapters: const [],
    isShorts: isShorts,
  );
}

void main() {
  group('PlayerController.selectNext', () {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');

    test('an empty queue has no next item', () {
      expect(PlayerController.selectNext(const []), isNull);
    });

    test('plays the queue in order and consumes the head', () {
      final choice = PlayerController.selectNext([a, b, c]);
      expect(choice!.next.videoId, 'a');
      expect(choice.rest.map((item) => item.videoId), ['b', 'c']);
    });

    test('repeat-all takes the head like any other mode — the finished '
        'video is what goes back on the end', () {
      final choice =
          PlayerController.selectNext([a, b], mode: RepeatMode.all);
      expect(choice!.next.videoId, 'a');
      expect(choice.rest.map((item) => item.videoId), ['b']);
    });

    test('shuffle draws from the whole queue, not just the head', () {
      final choice = PlayerController.selectNext(
        [a, b, c],
        mode: RepeatMode.shuffle,
        pickRandom: (max) {
          expect(max, 3);
          return 2;
        },
      );
      expect(choice!.next.videoId, 'c');
      expect(choice.rest.map((item) => item.videoId), ['a', 'b']);
    });

    test('shuffle of a single item does not need the generator', () {
      final choice = PlayerController.selectNext(
        [a],
        mode: RepeatMode.shuffle,
        pickRandom: (_) => fail('should not be consulted'),
      );
      expect(choice!.next.videoId, 'a');
      expect(choice.rest, isEmpty);
    });

    test('skips over Shorts but leaves them queued', () {
      final short = _item('s', duration: const Duration(seconds: 30));
      final choice =
          PlayerController.selectNext([short, b], skipShorts: true);
      expect(choice!.next.videoId, 'b');
      expect(choice.rest.map((item) => item.videoId), ['s']);
    });

    test('a queue of nothing but Shorts has no autoplay candidate', () {
      final short = _item('s', duration: const Duration(seconds: 30));
      final flagged = _item('f', isShorts: true);
      expect(
        PlayerController.selectNext([short, flagged], skipShorts: true),
        isNull,
      );
      // ...while an explicit "next" still plays it.
      expect(
        PlayerController.selectNext([short, flagged])!.next.videoId,
        's',
      );
    });

    test('shuffle picks only from the eligible items', () {
      final short = _item('s', duration: const Duration(seconds: 30));
      final choice = PlayerController.selectNext(
        [short, b, c],
        mode: RepeatMode.shuffle,
        skipShorts: true,
        pickRandom: (max) {
          expect(max, 2, reason: 'the Short is not a candidate');
          return 1;
        },
      );
      expect(choice!.next.videoId, 'c');
    });
  });

  group('PlayerController.isAutoplayShort', () {
    test('agrees with the feed filter about what a Short is', () {
      expect(
        PlayerController.isAutoplayShort(
          _item('a', duration: const Duration(seconds: 45)),
        ),
        isTrue,
      );
      expect(
        PlayerController.isAutoplayShort(_item('a', isShorts: true)),
        isTrue,
      );
      expect(
        PlayerController.isAutoplayShort(
          _item('a', duration: const Duration(minutes: 10)),
        ),
        isFalse,
      );
      expect(
        PlayerController.isAutoplayShort(
          _item(
            'a',
            duration: const Duration(minutes: 2),
            title: 'A clip #shorts',
          ),
        ),
        isTrue,
        reason: 'a hashtag widens the window to three minutes',
      );
    });
  });

  group('"Up next" countdown', () {
    final next = _item('n', title: 'Something else');

    test('nothing is offered until the countdown begins', () {
      const idle = PlayerStateData();
      expect(idle.upNext, isNull);
      expect(idle.upNextCountdown, isNull);
      expect(idle.isUpNextPending, isFalse);
      expect(idle.showReplay, isFalse);
    });

    test('starting the countdown offers the video for five seconds', () {
      final started =
          PlayerController.beginUpNext(const PlayerStateData(), next);
      expect(started.upNext, next);
      expect(started.upNextCountdown, PlayerController.upNextSeconds);
      expect(started.isUpNextPending, isTrue);
      expect(started.showReplay, isFalse);
    });

    test('ticks down to zero, which is the moment it fires', () {
      var state = PlayerController.beginUpNext(const PlayerStateData(), next);
      final seen = <int?>[];
      for (var i = 0; i < PlayerController.upNextSeconds; i++) {
        state = PlayerController.tickUpNext(state);
        seen.add(state.upNextCountdown);
      }
      expect(seen, [4, 3, 2, 1, 0]);
      expect(state.isUpNextPending, isFalse, reason: 'zero is not pending');
      expect(state.upNext, next, reason: 'still the video about to load');
    });

    test('the card clears the ended state it was shown over', () {
      const ended = PlayerStateData(showReplay: true);
      final started = PlayerController.beginUpNext(ended, next);
      expect(started.showReplay, isFalse);
    });

    test('cancelling drops the offer and leaves a replay button', () {
      var state = PlayerController.beginUpNext(const PlayerStateData(), next);
      state = PlayerController.tickUpNext(state);
      state = PlayerController.cancelUpNextState(state);
      expect(state.upNext, isNull);
      expect(state.upNextCountdown, isNull);
      expect(state.isUpNextPending, isFalse);
      expect(state.showReplay, isTrue);
    });

    test('a countdown that never started stays at zero rather than '
        'going negative', () {
      final state = PlayerController.tickUpNext(const PlayerStateData());
      expect(state.upNextCountdown, 0);
      expect(state.isUpNextPending, isFalse);
    });
  });

  group('PlayerController.previousGoesBack', () {
    test('restarts the video once it is properly under way', () {
      expect(
        PlayerController.previousGoesBack(const Duration(seconds: 30), true),
        isFalse,
      );
    });

    test('steps back when barely anything has played', () {
      expect(
        PlayerController.previousGoesBack(const Duration(seconds: 2), true),
        isTrue,
      );
      expect(
        PlayerController.previousGoesBack(
          PlayerController.previousRestartThreshold,
          true,
        ),
        isTrue,
        reason: 'the threshold itself still steps back',
      );
    });

    test('restarts rather than stepping back with nowhere to go', () {
      expect(
        PlayerController.previousGoesBack(Duration.zero, false),
        isFalse,
      );
    });
  });
}
