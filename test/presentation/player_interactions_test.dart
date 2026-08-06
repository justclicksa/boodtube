import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/core/errors/exceptions.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/screens/player/player_screen.dart';

void main() {
  group('fullscreen vertical gestures', () {
    const surface = Size(800, 450);

    test('an upward or downward portrait drag belongs to the watch sheet', () {
      expect(
        playerVerticalDragMode(
          collapsible: true,
          start: const Offset(400, 100),
          surfaceSize: surface,
        ),
        PlayerVerticalDragMode.collapseOrExpand,
      );
    });

    test('a drag starting near the fullscreen top exits at either edge', () {
      for (final x in [20.0, 400.0, 780.0]) {
        expect(
          playerVerticalDragMode(
            collapsible: false,
            start: Offset(x, 40),
            surfaceSize: surface,
          ),
          PlayerVerticalDragMode.leaveFullscreen,
        );
      }
    });

    test('the fullscreen centre remains an exit gesture', () {
      expect(
        playerVerticalDragMode(
          collapsible: false,
          start: const Offset(400, 300),
          surfaceSize: surface,
        ),
        PlayerVerticalDragMode.leaveFullscreen,
      );
    });

    test('lower outer edges retain brightness and volume gestures', () {
      expect(
        playerVerticalDragMode(
          collapsible: false,
          start: const Offset(40, 300),
          surfaceSize: surface,
        ),
        PlayerVerticalDragMode.brightness,
      );
      expect(
        playerVerticalDragMode(
          collapsible: false,
          start: const Offset(760, 300),
          surfaceSize: surface,
        ),
        PlayerVerticalDragMode.volume,
      );
    });
  });

  group('playback retry', () {
    test('retries a transient failure and returns the next result', () async {
      var attempts = 0;
      final result = await retryPlaybackOperation(
        () async {
          attempts++;
          if (attempts == 1) throw const NetworkException('temporary');
          return 'opened';
        },
        delay: Duration.zero,
        shouldRetry: isRetryablePlaybackError,
      );

      expect(result, 'opened');
      expect(attempts, 2);
    });

    test('does not retry a permanent not-found failure', () async {
      var attempts = 0;

      await expectLater(
        retryPlaybackOperation<void>(
          () async {
            attempts++;
            throw const NotFoundException('removed');
          },
          delay: Duration.zero,
          shouldRetry: isRetryablePlaybackError,
        ),
        throwsA(isA<NotFoundException>()),
      );
      expect(attempts, 1);
    });
  });
}
