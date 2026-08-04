// ============================================================
// SmartTubeAudioHandler - background playback + system notification
// ============================================================
// Bridges the shared media_kit Player to audio_service so playback
// keeps running with the screen off and is controllable from the
// Android notification / iOS Control Center.
// ============================================================

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import '../domain/entities/media_item.dart' as domain;

class SmartTubeAudioHandler extends BaseAudioHandler with SeekHandler {
  SmartTubeAudioHandler(this._player) {
    _player.stream.playing.listen((playing) => _publish(playing: playing));
    _player.stream.duration.listen((duration) {
      _duration = duration;
      final current = mediaItem.value;
      if (current != null && duration > Duration.zero) {
        mediaItem.add(current.copyWith(duration: duration));
      }
      _publish();
    });
    _player.stream.position.listen((position) {
      _position = position;
      _publish();
    });
    _player.stream.buffer.listen((buffered) {
      _buffered = buffered;
      _publish();
    });
    _player.stream.buffering.listen((buffering) {
      _buffering = buffering;
      _publish();
    });
    _player.stream.completed.listen((completed) {
      if (completed) {
        _completed = true;
        _publish();
      }
    });
  }

  final Player _player;

  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;
  Duration _duration = Duration.zero;
  bool _buffering = false;
  bool _completed = false;

  /// Invoked when the user taps "next"/"previous" in the notification.
  /// Wired by the player controller when a queue exists.
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  void _publish({bool? playing}) {
    final isPlaying = playing ?? _player.state.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (onSkipPrevious != null) MediaControl.skipToPrevious,
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          if (onSkipNext != null) MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        // Show play/pause (and skip when available) in the collapsed view.
        androidCompactActionIndices:
            onSkipPrevious != null ? const [0, 2, 4] : const [1, 2, 3],
        playing: isPlaying,
        updatePosition: _position,
        bufferedPosition: _buffered,
        speed: _player.state.rate,
        processingState: _completed
            ? AudioProcessingState.completed
            : _buffering
                ? AudioProcessingState.buffering
                : _duration > Duration.zero
                    ? AudioProcessingState.ready
                    : AudioProcessingState.loading,
      ),
    );
  }

  /// Publishes the now-playing metadata shown in the notification.
  Future<void> setMediaItem(domain.MediaItem item) async {
    _completed = false;
    mediaItem.add(
      MediaItem(
        id: item.videoId,
        title: item.title,
        artist: item.author,
        album: item.channelTitle ?? item.author,
        duration: item.duration > Duration.zero ? item.duration : null,
        artUri:
            item.thumbnailUrl != null ? Uri.tryParse(item.thumbnailUrl!) : null,
      ),
    );
    _publish();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> skipToNext() async => onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipPrevious?.call();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}

/// Initialises audio_service. Call once from main().
Future<SmartTubeAudioHandler> setupAudioService(Player player) {
  return AudioService.init(
    builder: () => SmartTubeAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.smarttube.audio',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription:
          'Controls for the currently playing video',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}
