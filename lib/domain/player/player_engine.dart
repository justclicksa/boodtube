// ============================================================
// PlayerEngine — the port every playback backend plugs into
// ============================================================
// Two backends answer this contract: libmpv through media_kit, and
// ExoPlayer behind a platform channel on Android. PlayerController talks
// to this and never to either of them directly, so which one plays a
// video is a persisted setting rather than a fork through the whole
// player screen.
//
// The two do not resolve streams the same way, and pretending otherwise
// is what would make this leak: mpv is handed signed googlevideo URLs
// through the loopback relay from Dart, while the native engine is given
// nothing but a video id and does its own resolving. Everything that
// differs between them is expressed here — [PlayerEngine
// .resolvesStreamsNatively], the nullable [EngineOpenResult] a track
// switch returns — instead of being smuggled through an `is MpvEngine`
// check upstream.
// ============================================================

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../../presentation/screens/player/subtitle_styles.dart';
import '../../services/player_tuning.dart';

/// Which backend plays video. Persisted as `settings.player_engine`.
enum PlayerEngineKind {
  /// ExoPlayer on the platform side, over `app.smarttube/native_player`.
  native,

  /// libmpv through media_kit, in-process.
  mpv,
}

/// Android is the only platform the native engine is built for; libmpv
/// is what exists everywhere else, so it stays the default there.
PlayerEngineKind get defaultPlayerEngine =>
    defaultTargetPlatform == TargetPlatform.android
        ? PlayerEngineKind.native
        : PlayerEngineKind.mpv;

/// One resolution rung an engine can play.
class EngineVideoTrack {
  const EngineVideoTrack({
    required this.height,
    this.codec,
    this.fps,
    this.bitrate,
    this.hdr = false,
    this.label,
  });

  final int height;
  final String? codec;
  final int? fps;
  final int? bitrate;
  final bool hdr;
  final String? label;
}

/// One audio rendition — a dub, a description track, or just the
/// original. [url] is only ever set by an engine that resolved the
/// stream in Dart; the native engine keeps its URLs to itself.
class EngineAudioTrack {
  const EngineAudioTrack({
    required this.id,
    required this.label,
    this.bitrate = 0,
    this.codec,
    this.url,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final int bitrate;
  final String? codec;
  final String? url;
  final bool isDefault;
}

class EngineSubtitleTrack {
  const EngineSubtitleTrack({required this.code, required this.label});

  final String code;
  final String label;
}

/// Everything the engine currently knows it could switch to.
class EngineTracks {
  const EngineTracks({
    this.video = const [],
    this.audio = const [],
    this.subtitle = const [],
  });

  final List<EngineVideoTrack> video;
  final List<EngineAudioTrack> audio;
  final List<EngineSubtitleTrack> subtitle;
}

/// What is playing right now, for the quality label and the stats panel.
class EngineFormat {
  const EngineFormat({
    required this.label,
    this.codec,
    this.fps,
    this.bitrate,
    this.width,
    this.height,
    this.hdr = false,
    this.source,
  });

  final String label;
  final String? codec;
  final int? fps;
  final int? bitrate;
  final int? width;
  final int? height;
  final bool hdr;

  /// Where the bytes come from — `dash`, `dash+hls`, `sabr`, `dash-url`,
  /// `hls` or `progressive`. Diagnostics only.
  final String? source;
}

/// A playback failure the engine could not handle by itself.
class EnginePlaybackError {
  const EnginePlaybackError(this.code, this.message);

  /// The upstream served only part of what it promised. Not fatal by
  /// itself: dropping a quality rung usually gets playback moving again.
  static const String streamCapped = 'stream_capped';

  /// Catch-all for a decoder or transport failure.
  static const String playerError = 'player_error';

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty ? code : message;
}

/// What an engine learned while opening a video.
///
/// Only an engine that resolves in Dart fills most of this in — the
/// native engine returns an empty result and reports the same facts
/// through [PlayerEngine.tracks] and [PlayerEngine.format] once the
/// platform has them.
class EngineOpenResult {
  const EngineOpenResult({
    this.videoUrl,
    this.audioUrl,
    this.qualityLabel,
    this.videoHeight,
    this.availableHeights = const [],
    this.sourceClient,
    this.failedClients = const [],
    this.audioTracks = const [],
    this.selectedAudioTrackId,
  });

  final String? videoUrl;
  final String? audioUrl;
  final String? qualityLabel;
  final int? videoHeight;
  final List<int> availableHeights;

  /// InnerTube client that produced the playable URL, and the ones that
  /// were rejected on the way there. Shown in the diagnostics panel.
  final String? sourceClient;
  final List<String> failedClients;
  final List<EngineAudioTrack> audioTracks;
  final String? selectedAudioTrackId;
}

abstract class PlayerEngine {
  PlayerEngineKind get kind;

  /// True when the platform resolves streams itself, so [openVideo] is
  /// handed a video id and nothing else. Such an engine has no use for
  /// the Dart stream resolver or the loopback relay, and cannot be
  /// pointed at a URL through [openDirect].
  bool get resolvesStreamsNatively;

  // ============================================================
  // Lifecycle
  // ============================================================

  /// Brings the backend up. Safe to call more than once — later calls
  /// return the same future rather than starting a second player.
  Future<void> initialize();

  Future<void> dispose();

  // ============================================================
  // Playback
  // ============================================================

  /// Starts [videoId]. [preferredHeight] null means "let the engine
  /// choose"; the other two restore what the user last picked for this
  /// channel.
  Future<EngineOpenResult> openVideo(
    String videoId, {
    int? preferredHeight,
    String? audioTrackId,
    String? subtitleCode,
  });

  /// Plays a URL that needs no resolving — a downloaded file, or a live
  /// HLS playlist. Throws [UnsupportedError] when
  /// [resolvesStreamsNatively] is true.
  Future<void> openDirect({required String url, String? audioUrl});

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  /// Volume as a percentage, not a fraction: SmartTube lets the user
  /// boost past 100% and mpv obliges, so the range is 0–300 and an
  /// engine that only understands 0–1 clamps on the way down.
  Future<void> setVolume(double percent);

  // ============================================================
  // Tracks
  // ============================================================

  /// Switches resolution. [height] null means automatic.
  ///
  /// Returns null when the engine switched the track in place and there
  /// is nothing new to tell the caller — the platform reports the result
  /// through [format] instead. An engine that has to re-resolve and
  /// re-open returns what that produced, and the caller is then
  /// responsible for restoring the playhead.
  Future<EngineOpenResult?> selectVideoTrack({int? height, String? codec});

  /// Switches audio rendition. Same null-means-in-place contract as
  /// [selectVideoTrack].
  Future<EngineOpenResult?> selectAudioTrack(String id);

  /// Selects a caption track, or turns captions off when [code] is null.
  /// [url] and [label] are only consulted by an engine that sideloads
  /// captions itself rather than picking one the manifest already
  /// carries.
  Future<void> selectSubtitle(String? code, {String? url, String? label});

  /// Drops or restores the video track. Used to keep audio playing in
  /// the background without paying for — or, on iOS, crashing on —
  /// off-screen video decoding.
  Future<void> setVideoTrackEnabled(bool enabled);

  /// Applies the tuning that has no shared vocabulary between engines.
  /// mpv takes a bag of properties (cache seconds, demuxer limits, audio
  /// delay, pitch correction); ExoPlayer takes a buffer preset and sizes
  /// its own LoadControl. Each engine honours what it can and ignores
  /// the rest — a tweak an engine cannot express should cost the user
  /// that tweak, never the video.
  ///
  /// [isLive] is passed rather than read from state because a live
  /// window is forced onto the low buffer whatever the preference says.
  Future<void> applyTuning({
    required BufferPreset preset,
    required int audioDelayMs,
    required bool keepPitch,
    required bool isLive,
  });

  // ============================================================
  // Streams
  // ============================================================

  Stream<Duration> get position;

  Stream<Duration> get duration;

  Stream<Duration> get buffer;

  Stream<bool> get buffering;

  Stream<bool> get playing;

  Stream<bool> get completed;

  Stream<EnginePlaybackError> get error;

  /// What could be switched to. An engine that learns its rungs while
  /// resolving reports them through [EngineOpenResult] instead and never
  /// emits here.
  Stream<EngineTracks> get tracks;

  /// What is playing now. Same caveat as [tracks].
  Stream<EngineFormat> get format;

  // ============================================================
  // Surface
  // ============================================================

  /// The video surface for this engine, display-only: the app owns every
  /// player gesture, so the returned widget must never join the gesture
  /// arena.
  ///
  /// The subtitle arguments are for an engine that draws captions in
  /// Flutter; one whose captions are rendered on the platform side
  /// ignores them.
  Widget buildSurface({
    BoxFit fit = BoxFit.contain,
    SubtitleStyle subtitleStyle = SubtitleStyle.defaultStyle,
    double subtitleScale = 1,
    double subtitleOffset = 24,
    double subtitleBackgroundOpacity = 0.67,
  });
}
