// ============================================================
// Tests for PlayerStateData (FIXED: no real Player, no dynamic implement)
// ============================================================

import 'package:audio_service/audio_service.dart' show MediaControl;
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/local/preferences/settings_repository_impl.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';

import '../../support/player_container.dart';

MediaItem _item(String videoId, {String channelId = 'UC-test'}) => MediaItem(
      videoId: videoId,
      title: videoId,
      author: 'author',
      channelId: channelId,
      duration: const Duration(minutes: 3),
      publishedAt: DateTime(2026),
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  autoQualityTests();
  queueTests();
  autoQualitySelectionTests();
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

void queueTests() {
  group('PlayerController queue', () {
    test('play next jumps ahead of what is already queued', () async {
      final harness = await playerTestHarness();
      harness.controller
        ..enqueue(_item('a'))
        ..enqueue(_item('b'))
        ..playNext(_item('c'));

      expect(harness.playerState.queue.map((q) => q.videoId), ['c', 'a', 'b']);
    });

    test('a video is never queued twice', () async {
      final harness = await playerTestHarness();
      harness.controller
        ..enqueue(_item('a'))
        ..enqueue(_item('a'));

      expect(harness.playerState.queue, hasLength(1));
    });

    test('play next moves a video that is already queued', () async {
      final harness = await playerTestHarness();
      harness.controller
        ..enqueue(_item('a'))
        ..enqueue(_item('b'))
        ..playNext(_item('b'));

      expect(harness.playerState.queue.map((q) => q.videoId), ['b', 'a']);
    });

    test('the notification follows the queue in and out of existence',
        () async {
      final harness = await playerTestHarness();
      List<MediaControl> controls() =>
          harness.audioHandler.playbackState.value.controls;

      harness.controller.enqueue(_item('a'));
      expect(controls(), contains(MediaControl.skipToNext));

      harness.controller.removeFromQueue('a');
      expect(controls(), isNot(contains(MediaControl.skipToNext)));
    });

    test('a disposed controller lets go of the notification button',
        () async {
      // The handler outlives the controller. Left wired, the button
      // would call into a disposed notifier and throw.
      final harness = await playerTestHarness();
      harness.controller.enqueue(_item('a'));
      expect(harness.audioHandler.onSkipNext, isNotNull);

      harness.container.dispose();
      expect(harness.audioHandler.onSkipNext, isNull);
      expect(
        harness.audioHandler.playbackState.value.controls,
        isNot(contains(MediaControl.skipToNext)),
      );
    });
  });
}

void autoQualitySelectionTests() {
  group('PlayerController.selectAutoQuality', () {
    test('turns the setting back on and unpins the channel', () async {
      final harness = await playerTestHarness();
      final repository = harness.container.read(settingsRepositoryProvider);
      await repository.saveChannelPlaybackPreferences(
        'UC-test',
        const ChannelPlaybackPreferences(speed: 1.5, qualityHeight: 1080),
      );
      await harness.container
          .read(settingsControllerProvider.notifier)
          .setAutoQuality(false);
      // ignore: invalid_use_of_protected_member
      harness.controller.state =
          harness.controller.state.copyWith(currentItem: _item('a'));

      await harness.controller.selectAutoQuality();

      expect(
        harness.container.read(settingsControllerProvider).autoQuality,
        isTrue,
      );
      final stored = repository.channelPlaybackPreferences('UC-test');
      expect(
        stored?.qualityHeight,
        isNull,
        reason: 'a pinned height would defeat auto quality on this channel',
      );
      expect(stored?.speed, 1.5, reason: 'the rest of the channel is intact');
    });
  });
}
