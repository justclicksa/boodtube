// ============================================================
// MpvEngine — libmpv through media_kit
// ============================================================
// The engine the app shipped with, unchanged in behaviour and merely
// moved behind [PlayerEngine]: it resolves streams in Dart, relays them
// through the loopback proxy because mpv's bundled TLS cannot reach
// googlevideo reliably, and renders through media_kit's Video widget.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../presentation/screens/player/subtitle_styles.dart';
import '../../services/player_tuning.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/stream_proxy.dart';
import '../../domain/player/player_engine.dart';

/// How mpv gets frames onto the screen, per platform.
///
/// Android: mpv's default `vo=gpu` needs its own EGL context, which
/// fails on the emulator ("Could not create EGL context for GLES 2.x").
/// `mediacodec_embed` decodes straight onto the Android Surface — no
/// mpv-side GL — and works on devices and emulators alike.
///
/// iOS/macOS: neither of those exists. VideoToolbox is the hardware
/// decoder there, and media_kit's default video output already renders
/// through Metal, so only the decoder is named.
///
/// Anything else keeps media_kit's defaults.
VideoControllerConfiguration get videoOutputConfiguration =>
    switch (defaultTargetPlatform) {
      TargetPlatform.android => const VideoControllerConfiguration(
          vo: 'mediacodec_embed',
          hwdec: 'mediacodec',
        ),
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        const VideoControllerConfiguration(hwdec: 'videotoolbox'),
      _ => const VideoControllerConfiguration(),
    };

class MpvEngine implements PlayerEngine {
  MpvEngine({
    required Player player,
    required StreamProxy proxy,
  })  : _player = player,
        _proxy = proxy {

    // Surface mpv logs/errors — mpv does not write to logcat by itself,
    // so without these listeners playback failures are invisible.
    _subscriptions
      ..add(
        _player.stream.log.listen((event) {
          debugPrint('mpv[${event.level}] ${event.prefix}: ${event.text}');
        }),
      )
      ..add(
        _player.stream.error.listen((message) {
          debugPrint('mpv ERROR: $message');
          _errors.add(
            EnginePlaybackError(EnginePlaybackError.playerError, message),
          );
        }),
      );

    // Some videos are served for only the first few MiB whatever client
    // asked for them. mpv just stalls when that happens, so turn it into
    // something the caller can act on.
    _proxy.onUpstreamRefused = (served, total) {
      if (served >= total) return;
      _errors.add(
        const EnginePlaybackError(
          EnginePlaybackError.streamCapped,
          'stream-capped',
        ),
      );
    };
  }

  final Player _player;
  final StreamProxy _proxy;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<EnginePlaybackError> _errors =
      StreamController<EnginePlaybackError>.broadcast();

  /// mpv learns nothing about renditions the resolver did not already
  /// know, so these exist only to satisfy the contract.
  final StreamController<EngineTracks> _tracks =
      StreamController<EngineTracks>.broadcast();
  final StreamController<EngineFormat> _formats =
      StreamController<EngineFormat>.broadcast();

  /// Created on first paint rather than up front, so attaching a video
  /// output to mpv still happens when the player UI appears — which is
  /// what the screen used to do for itself.
  VideoController? _videoController;

  /// What the last successful open was for. A track switch re-resolves
  /// the same video, and the caller has no business repeating itself.

  @override
  PlayerEngineKind get kind => PlayerEngineKind.mpv;

  @override
  bool get resolvesStreamsNatively => false;

  /// Nothing to bring up: the [Player] is created in main() and shared
  /// with the audio handler, and the video output is attached lazily by
  /// [buildSurface].
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    _proxy.onUpstreamRefused = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _errors.close();
    await _tracks.close();
    await _formats.close();
    // The Player itself belongs to mediaPlayerProvider, which disposes
    // it alongside the audio handler that shares it.
  }

  /// Never called. mpv is fed by PlayerController's resolution pipeline —
  /// resolver, 403 probing, the sideloaded MPD and the loopback relay,
  /// with the cap/step-down recovery wrapped around it — which arrives
  /// here as [openDirect]. Keeping a second copy of that pipeline in the
  /// engine is how the two drift apart, so there is deliberately no copy.
  /// See [resolvesStreamsNatively].
  @override
  Future<EngineOpenResult> openVideo(
    String videoId, {
    int? preferredHeight,
    String? audioTrackId,
    String? subtitleCode,
  }) =>
      throw UnsupportedError(
        'MpvEngine does not resolve streams; PlayerController calls '
        'openDirect() with URLs it resolved and relayed itself.',
      );

  @override
  Future<void> openDirect({required String url, String? audioUrl}) async {
    await _player.open(Media(url));
    if (audioUrl != null) {
      await _player.setAudioTrack(AudioTrack.uri(audioUrl));
    }
    // A direct URL is not one of ours to re-resolve.
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) {
    // Remembered because a re-open resets mpv to 1x, and the rate has to
    // be re-applied before the first frame or the switch is audible.
    return _player.setRate(speed);
  }


  @override
  Future<void> setVolume(double percent) => _player.setVolume(percent);

  /// mpv cannot switch rungs inside a progressive stream, so a quality
  /// change means resolving and opening again. The caller restores the
  /// playhead from the result it gets back.
  /// Also never called, for the same reason: changing height on mpv means
  /// resolving again, and that lives in PlayerController.
  @override
  Future<EngineOpenResult?> selectVideoTrack({int? height, String? codec}) =>
      throw UnsupportedError(
        'MpvEngine does not resolve streams; PlayerController re-opens at '
        'the new height itself.',
      );

  @override
  Future<EngineOpenResult?> selectAudioTrack(String id) =>
      throw UnsupportedError(
        'MpvEngine does not resolve streams; PlayerController re-opens with '
        'the new audio track itself.',
      );

  @override
  Future<void> selectSubtitle(
    String? code, {
    String? url,
    String? label,
  }) async {
    if (code == null || url == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    // Route captions through the proxy too: the same TLS limitation
    // applies to timedtext URLs.
    await _proxy.start();
    final local = _proxy.register(Uri.parse(url));
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(local, title: label, language: code),
    );
  }

  @override
  Future<void> setVideoTrackEnabled(bool enabled) =>
      _player.setVideoTrack(enabled ? VideoTrack.auto() : VideoTrack.no());

  /// mpv resets these per file, so the controller re-asserts them on
  /// every open rather than once at startup.
  @override
  Future<void> applyTuning({
    required BufferPreset preset,
    required int audioDelayMs,
    required bool keepPitch,
    required bool isLive,
  }) async {
    final platform = _player.platform;
    // Not the native backend: tests and web get a player with no property
    // interface at all, and that is not a failure.
    if (platform is! NativePlayer) return;
    final properties = playerTuningProperties(
      preset: preset,
      audioDelayMs: audioDelayMs,
      keepPitch: keepPitch,
      isLive: isLive,
      totalRamBytes: await readDeviceRamBytes(),
    );
    for (final entry in properties.entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (e) {
        // An mpv build without a given option should cost the user that
        // tweak, not the video.
        debugPrint('player tuning: ${entry.key}=${entry.value} rejected ($e)');
      }
    }
  }

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<Duration> get buffer => _player.stream.buffer;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<EnginePlaybackError> get error => _errors.stream;

  @override
  Stream<EngineTracks> get tracks => _tracks.stream;

  @override
  Stream<EngineFormat> get format => _formats.stream;

  @override
  Widget buildSurface({
    BoxFit fit = BoxFit.contain,
    SubtitleStyle subtitleStyle = SubtitleStyle.defaultStyle,
    double subtitleScale = 1,
    double subtitleOffset = 24,
    double subtitleBackgroundOpacity = 0.67,
  }) {
    final controller = _videoController ??= VideoController(
      _player,
      configuration: videoOutputConfiguration,
    );

    // controls: null hides media_kit's controls, but its video surface
    // can still join the gesture arena on a real iOS or Android texture.
    // The app owns every player gesture, so the renderer must be
    // display-only; otherwise taps and vertical drags intermittently
    // disappear before reaching the parent.
    return IgnorePointer(
      child: Video(
        controller: controller,
        controls: null,
        fit: fit,
        fill: Colors.black,
        // Shared with the settings sheet's preview line, so the sample and
        // the real captions cannot drift apart.
        subtitleViewConfiguration: subtitleViewConfigurationFor(
          subtitleStyle,
          scale: subtitleScale,
          bottomPadding: subtitleOffset,
          // AppSpacing.lg, matching what the player screen used before
          // the surface moved behind the engine.
          horizontalPadding: 16,
          customBackgroundOpacity: subtitleBackgroundOpacity,
        ),
        // media_kit_video defaults this to true and calls player.pause()
        // the moment the app backgrounds. That is right for a widget that
        // assumes you are watching, and it is what silently defeated
        // background playback here: the process stayed alive and the audio
        // session stayed active, but mpv had been paused out from under
        // us. PlayerController drops the video track on background itself,
        // so nothing decodes off-screen.
        pauseUponEnteringBackgroundMode: false,
      ),
    );
  }


}
