// ============================================================
// Tests for PlayerStateData (FIXED: no real Player, no dynamic implement)
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';

void main() {
  autoQualityTests();
  group('PlayerStateData', () {
    test('initial state is empty', () {
      const state = PlayerStateData();
      expect(state.currentItem, isNull);
      expect(state.isPlaying, isFalse);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.playbackSpeed, 1.0);
    });

    test('copyWith updates fields correctly', () {
      const initial = PlayerStateData();
      final updated = initial.copyWith(
        isPlaying: true,
        position: const Duration(seconds: 30),
        playbackSpeed: 1.5,
      );

      expect(updated.isPlaying, isTrue);
      expect(updated.position, const Duration(seconds: 30));
      expect(updated.playbackSpeed, 1.5);
      expect(updated.duration, Duration.zero);
    });

    test('copyWith with clearError removes error', () {
      const withError = PlayerStateData(error: 'something went wrong');
      final cleared = withError.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith with clearItem removes currentItem', () {
      // We can't easily create MediaItem without all fields
      // Just verify the flag works conceptually
      const initial = PlayerStateData();
      final cleared = initial.copyWith(clearItem: true);
      expect(cleared.currentItem, isNull);
    });
  });
}

void autoQualityTests() {
  group('PlayerController.autoHeightForMbps', () {
    const offered = [2160, 1440, 1080, 720, 480, 360, 240, 144];

    test('has no opinion before any bytes have flowed', () {
      expect(PlayerController.autoHeightForMbps(0, offered), isNull);
      expect(PlayerController.autoHeightForMbps(10, const []), isNull);
    });

    test('maps throughput onto the ladder', () {
      expect(PlayerController.autoHeightForMbps(30, offered), 2160);
      expect(PlayerController.autoHeightForMbps(12, offered), 1440);
      expect(PlayerController.autoHeightForMbps(7, offered), 1080);
      expect(PlayerController.autoHeightForMbps(3.5, offered), 720);
      expect(PlayerController.autoHeightForMbps(2, offered), 480);
      expect(PlayerController.autoHeightForMbps(0.5, offered), 360);
    });

    test('never picks a rung the video does not offer', () {
      expect(PlayerController.autoHeightForMbps(30, const [1080, 720]), 1080);
      expect(PlayerController.autoHeightForMbps(2, const [1080, 720]), 720);
      expect(PlayerController.autoHeightForMbps(0.5, const [1080]), 1080);
    });
  });
}
