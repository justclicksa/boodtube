// ============================================================
// A media_kit Player with no native player behind it
// ============================================================
// media_kit resolves libmpv through dart:ffi the moment a real
// [Player] is built, which no `flutter test` process can do. `Player`
// accepts a platform implementation though, and [PlatformPlayer] owns
// the state and the stream controllers itself — so a subclass that
// simply records the calls gives the widgets and the controller a
// player that behaves well enough to build against.
// ============================================================

import 'package:media_kit/media_kit.dart';

class FakePlatformPlayer extends PlatformPlayer {
  FakePlatformPlayer() : super(configuration: const PlayerConfiguration());

  final calls = <String>[];

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> playOrPause() async => calls.add('playOrPause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration duration) async => calls.add('seek:$duration');

  @override
  Future<void> setRate(double rate) async => calls.add('rate:$rate');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');

  @override
  Future<void> open(Playable playable, {bool play = true}) async =>
      calls.add('open');

  @override
  Future<void> setVideoTrack(VideoTrack track) async =>
      calls.add('videoTrack:${track.id}');

  @override
  Future<void> setAudioTrack(AudioTrack track) async =>
      calls.add('audioTrack:${track.id}');

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async =>
      calls.add('subtitleTrack:${track.id}');
}

/// A [Player] backed by [FakePlatformPlayer].
Player fakePlayer([FakePlatformPlayer? platform]) =>
    Player(platformPlayer: platform ?? FakePlatformPlayer());
