// ============================================================
// NativeEngine — ExoPlayer over a platform channel
// ============================================================
// Everything that makes a video playable happens on the platform side
// here: resolving, DASH/HLS/SABR selection, ABR, decoding. Dart sends a
// video id and intent ("give me 1080p", "mute the video track") and gets
// state back over an EventChannel. Nothing in this file may reach for
// the Dart stream resolver or the loopback relay — that is the whole
// point of the engine existing.
//
// The channel contract is fixed and shared with the Kotlin side; the
// literals below are the contract, so they are spelled out rather than
// derived.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/player_tuning.dart';
import '../../domain/player/player_engine.dart';
import '../../presentation/screens/player/subtitle_styles.dart';

/// How much the platform buffers ahead. Mirrors the `setBufferPreset`
/// argument the Kotlin side understands.
enum NativeBufferPreset { low, medium, high, highest }

class NativeEngine implements PlayerEngine {
  NativeEngine({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _channel = methodChannel ?? const MethodChannel(methodChannelName),
        _events = eventChannel ?? const EventChannel(eventChannelName);

  static const String methodChannelName = 'app.smarttube/native_player';
  static const String eventChannelName =
      'app.smarttube/native_player/events';

  final MethodChannel _channel;
  final EventChannel _events;

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffer =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<EnginePlaybackError> _errors =
      StreamController<EnginePlaybackError>.broadcast();
  final StreamController<EngineTracks> _tracks =
      StreamController<EngineTracks>.broadcast();
  final StreamController<EngineFormat> _formats =
      StreamController<EngineFormat>.broadcast();

  /// The texture the platform renders into, and the frame size the
  /// format event last reported. One notifier so the surface rebuilds
  /// once, not twice, when both arrive together.
  final ValueNotifier<_NativeSurface> _surface =
      ValueNotifier<_NativeSurface>(const _NativeSurface());

  StreamSubscription<dynamic>? _eventSubscription;
  Future<void>? _initializing;

  /// Repeats are dropped rather than forwarded: the platform sends a
  /// full state snapshot on a timer, and the listeners upstream turn
  /// every one of them into a rebuild.
  bool? _lastPlaying;
  bool? _lastBuffering;
  bool? _lastCompleted;
  Duration? _lastDuration;
  Duration? _lastBuffered;

  @override
  PlayerEngineKind get kind => PlayerEngineKind.native;

  @override
  bool get resolvesStreamsNatively => true;

  @override
  Future<void> initialize() => _initializing ??= _create();

  Future<void> _create() async {
    _eventSubscription = _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: (Object error) {
            debugPrint('native player events failed: $error');
          },
        );
    final textureId = await _channel.invokeMethod<int>('create');
    _surface.value = _surface.value.copyWith(textureId: textureId);
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException catch (e) {
      debugPrint('native player dispose failed: $e');
    }
    await _position.close();
    await _duration.close();
    await _buffer.close();
    await _buffering.close();
    await _playing.close();
    await _completed.close();
    await _errors.close();
    await _tracks.close();
    await _formats.close();
    _surface.dispose();
  }

  @override
  Future<EngineOpenResult> openVideo(
    String videoId, {
    int? preferredHeight,
    String? audioTrackId,
    String? subtitleCode,
  }) async {
    await initialize();
    await _channel.invokeMethod<void>('open', <String, Object?>{
      'videoId': videoId,
      'preferredHeight': preferredHeight,
      'audioTrackId': audioTrackId,
      'subtitleCode': subtitleCode,
    });
    // Nothing is known yet — the rungs and the playing format arrive as
    // `tracks` and `format` events once the platform has the manifest.
    return const EngineOpenResult();
  }

  /// The platform resolves for itself and has no method that takes a
  /// URL, so downloaded files and live playlists are not this engine to
  /// play. Callers check [resolvesStreamsNatively] instead of catching.
  @override
  Future<void> openDirect({required String url, String? audioUrl}) {
    throw UnsupportedError(
      'the native engine resolves streams itself; it cannot be handed a URL',
    );
  }

  @override
  Future<void> play() => _channel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  /// The channel has no `stop`: `dispose` is the only teardown, and it
  /// would cost a `create` round-trip to come back from. Parking the
  /// playhead at zero and pausing leaves the same thing on screen.
  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) =>
      _channel.invokeMethod<void>('seek', <String, Object?>{
        'positionMs': position.inMilliseconds,
      });

  @override
  Future<void> setSpeed(double speed) =>
      _channel.invokeMethod<void>('setSpeed', <String, Object?>{
        'speed': speed,
      });

  /// ExoPlayer takes a gain factor and clips above 1.0, so the boost
  /// range mpv offers is flattened here rather than distorted.
  @override
  Future<void> setVolume(double percent) =>
      _channel.invokeMethod<void>('setVolume', <String, Object?>{
        'volume': (percent / 100).clamp(0.0, 1.0),
      });

  Future<void> setBufferPreset(NativeBufferPreset preset) =>
      _channel.invokeMethod<void>('setBufferPreset', <String, Object?>{
        'preset': preset.name,
      });

  /// Switching rungs is a track selection on a manifest that is already
  /// loaded, so nothing is re-opened and there is nothing to report back
  /// — the resulting format arrives as an event.
  @override
  Future<EngineOpenResult?> selectVideoTrack({
    int? height,
    String? codec,
  }) async {
    await _channel.invokeMethod<void>('selectVideoTrack', <String, Object?>{
      'height': height,
      'codec': codec,
    });
    return null;
  }

  @override
  Future<EngineOpenResult?> selectAudioTrack(String id) async {
    await _channel.invokeMethod<void>('selectAudioTrack', <String, Object?>{
      'id': id,
    });
    return null;
  }

  /// Only the code travels: the platform picks the caption track out of
  /// the manifest itself and never needs the timedtext URL Dart resolved.
  @override
  Future<void> selectSubtitle(String? code, {String? url, String? label}) =>
      _channel.invokeMethod<void>('selectSubtitle', <String, Object?>{
        'code': code,
      });

  @override
  Future<void> setVideoTrackEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setVideoEnabled', <String, Object?>{
        'enabled': enabled,
      });

  /// ExoPlayer builds its LoadControl from the preset, so only that
  /// crosses the channel. The audio delay and the pitch mode have no
  /// ExoPlayer 2.10 equivalent and are dropped on purpose — see
  /// docs/UNIFIED_PLAYER.md.
  @override
  Future<void> applyTuning({
    required BufferPreset preset,
    required int audioDelayMs,
    required bool keepPitch,
    required bool isLive,
  }) =>
      _channel.invokeMethod<void>('setBufferPreset', <String, Object?>{
        'preset': effectiveBufferPreset(preset, isLive: isLive).name,
      });

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<Duration> get buffer => _buffer.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<EnginePlaybackError> get error => _errors.stream;

  @override
  Stream<EngineTracks> get tracks => _tracks.stream;

  @override
  Stream<EngineFormat> get format => _formats.stream;

  /// Captions are drawn by the platform into the same surface, so the
  /// subtitle arguments have nowhere to go here.
  @override
  Widget buildSurface({
    BoxFit fit = BoxFit.contain,
    // Captions are rendered by ExoPlayer on the platform side, so the
    // Flutter caption presets do not reach them. See docs/UNIFIED_PLAYER.md.
    SubtitleStyle subtitleStyle = SubtitleStyle.defaultStyle,
    double subtitleScale = 1,
    double subtitleOffset = 24,
    double subtitleBackgroundOpacity = 0.67,
  }) {
    // IgnorePointer for the same reason the mpv surface has one: a
    // platform texture can claim the gesture arena, and every player
    // gesture belongs to the screen above this.
    return IgnorePointer(
      child: ValueListenableBuilder<_NativeSurface>(
        valueListenable: _surface,
        builder: (context, surface, _) {
          final textureId = surface.textureId;
          return ColoredBox(
            color: Colors.black,
            child: textureId == null
                ? const SizedBox.expand()
                : _fitted(fit, surface, Texture(textureId: textureId)),
          );
        },
      ),
    );
  }

  /// A Flutter [Texture] stretches to whatever box it is given, so the
  /// video ratio has to be reimposed from the size the format event
  /// reported. Before the first format event there is nothing to fit to
  /// and the texture simply fills.
  Widget _fitted(BoxFit fit, _NativeSurface surface, Widget texture) {
    final width = surface.width;
    final height = surface.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return texture;
    }
    return FittedBox(
      fit: fit,
      child: SizedBox(
        width: width.toDouble(),
        height: height.toDouble(),
        child: texture,
      ),
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<Object?, Object?>();
    switch (map['event']) {
      case 'state':
        _onState(map);
      case 'tracks':
        _onTracks(map);
      case 'format':
        _onFormat(map);
      case 'error':
        _errors.add(
          EnginePlaybackError(
            _string(map['code']) ?? EnginePlaybackError.playerError,
            _string(map['message']) ?? '',
          ),
        );
    }
  }

  void _onState(Map<Object?, Object?> map) {
    // Position is the one field that is expected to move every tick, so
    // it is forwarded unconditionally.
    final positionMs = _int(map['positionMs']);
    if (positionMs != null) {
      _position.add(Duration(milliseconds: positionMs));
    }

    final durationMs = _int(map['durationMs']);
    if (durationMs != null) {
      final value = Duration(milliseconds: durationMs);
      if (value != _lastDuration) {
        _lastDuration = value;
        _duration.add(value);
      }
    }

    final bufferedMs = _int(map['bufferedMs']);
    if (bufferedMs != null) {
      final value = Duration(milliseconds: bufferedMs);
      if (value != _lastBuffered) {
        _lastBuffered = value;
        _buffer.add(value);
      }
    }

    final playing = _bool(map['playing']);
    if (playing != null && playing != _lastPlaying) {
      _lastPlaying = playing;
      _playing.add(playing);
    }

    final buffering = _bool(map['buffering']);
    if (buffering != null && buffering != _lastBuffering) {
      _lastBuffering = buffering;
      _buffering.add(buffering);
    }

    final completed = _bool(map['completed']);
    if (completed != null && completed != _lastCompleted) {
      _lastCompleted = completed;
      _completed.add(completed);
    }
  }

  void _onTracks(Map<Object?, Object?> map) {
    _tracks.add(
      EngineTracks(
        video: [
          for (final entry in _maps(map['video']))
            EngineVideoTrack(
              height: _int(entry['height']) ?? 0,
              codec: _string(entry['codec']),
              fps: _int(entry['fps']),
              bitrate: _int(entry['bitrate']),
              hdr: _bool(entry['hdr']) ?? false,
              label: _string(entry['label']),
            ),
        ],
        audio: [
          for (final entry in _maps(map['audio']))
            EngineAudioTrack(
              id: _string(entry['id']) ?? '',
              label: _string(entry['label']) ?? '',
              bitrate: _int(entry['bitrate']) ?? 0,
              codec: _string(entry['codec']),
            ),
        ],
        subtitle: [
          for (final entry in _maps(map['subtitle']))
            EngineSubtitleTrack(
              code: _string(entry['code']) ?? '',
              label: _string(entry['label']) ?? '',
            ),
        ],
      ),
    );
  }

  void _onFormat(Map<Object?, Object?> map) {
    final width = _int(map['width']);
    final height = _int(map['height']);
    _surface.value = _surface.value.copyWith(width: width, height: height);
    _formats.add(
      EngineFormat(
        label: _string(map['label']) ?? '',
        codec: _string(map['codec']),
        fps: _int(map['fps']),
        bitrate: _int(map['bitrate']),
        width: width,
        height: height,
        hdr: _bool(map['hdr']) ?? false,
        source: _string(map['source']),
      ),
    );
  }

  static Iterable<Map<Object?, Object?>> _maps(Object? value) sync* {
    if (value is! List) return;
    for (final entry in value) {
      if (entry is Map) yield entry.cast<Object?, Object?>();
    }
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static bool? _bool(Object? value) => value is bool ? value : null;

  static String? _string(Object? value) => value is String ? value : null;
}

/// What the surface needs to draw: the platform texture and the frame
/// size to impose a ratio with.
@immutable
class _NativeSurface {
  const _NativeSurface({this.textureId, this.width, this.height});

  final int? textureId;
  final int? width;
  final int? height;

  _NativeSurface copyWith({int? textureId, int? width, int? height}) =>
      _NativeSurface(
        textureId: textureId ?? this.textureId,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      other is _NativeSurface &&
      other.textureId == textureId &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(textureId, width, height);
}
