// ============================================================
// Player engine tuning — SmartTube's player tweaks, in mpv terms
// ============================================================
// SmartTube tunes ExoPlayer's DefaultLoadControl (see
// ExoPlayerInitializer.createLoadControl) with four buffer presets and
// a device-RAM-derived byte cap. mpv has no LoadControl, but the same
// intent maps onto `cache-secs` / `demuxer-readahead-secs` /
// `demuxer-max-bytes` / `demuxer-max-back-bytes`.
//
// Everything here is a pure function of its inputs so the mapping can
// be asserted in a unit test without a player, a platform channel or an
// mpv build. The only IO is [readDeviceRamBytes], which is a thin
// wrapper over a pure parser.
// ============================================================

import 'dart:convert';
import 'dart:io';

/// How far ahead the player downloads. Mirrors SmartTube's
/// `PlayerData.BUFFER_*` constants.
enum BufferPreset { low, medium, high, highest }

/// Rough memory tier of the device. SmartTube divides the reported RAM
/// by 18 to get its byte cap; we keep the same idea but bucket it, so a
/// test can pin exact numbers instead of tracking a device's real RAM.
enum DeviceRamClass { low, normal, high }

const int _mib = 1024 * 1024;
const int _gib = 1024 * 1024 * 1024;

/// Seconds of media each preset keeps ahead of the playhead.
/// Matches SmartTube's max buffer: low 5s (its "LIVE fix"), medium 30s,
/// high 50s, highest 100s.
const Map<BufferPreset, int> bufferPresetSeconds = {
  BufferPreset.low: 5,
  BufferPreset.medium: 30,
  BufferPreset.high: 50,
  BufferPreset.highest: 100,
};

/// Byte budget per preset before the RAM-class multiplier. mpv counts
/// demuxer packets, not decoded frames, so these stay well under
/// SmartTube's 196 MB ceiling for anything but `highest`.
const Map<BufferPreset, int> _presetBaseBytes = {
  BufferPreset.low: 16 * _mib,
  BufferPreset.medium: 64 * _mib,
  BufferPreset.high: 96 * _mib,
  BufferPreset.highest: 128 * _mib,
};

/// SmartTube's guard against a negative/absurd RAM reading: 196 MB is
/// enough for any preset and safe on any device.
const int maxBufferBytesCeiling = 196 * _mib;

/// Buckets total RAM. Unknown (null, zero or negative — the exact case
/// SmartTube guards against) is treated as an ordinary device.
DeviceRamClass deviceRamClassFor(int? totalRamBytes) {
  if (totalRamBytes == null || totalRamBytes <= 0) return DeviceRamClass.normal;
  if (totalRamBytes < 3 * _gib) return DeviceRamClass.low;
  if (totalRamBytes >= 6 * _gib) return DeviceRamClass.high;
  return DeviceRamClass.normal;
}

/// What each RAM class is allowed to do to the base byte budget.
double ramClassMultiplier(DeviceRamClass ramClass) => switch (ramClass) {
      DeviceRamClass.low => 0.5,
      DeviceRamClass.normal => 1.0,
      DeviceRamClass.high => 1.5,
    };

/// The mpv side of one buffer preset.
class BufferTuning {
  const BufferTuning({
    required this.cacheSecs,
    required this.readaheadSecs,
    required this.maxBytes,
    required this.maxBackBytes,
  });

  /// `cache-secs` — the forward cache ceiling in seconds.
  final int cacheSecs;

  /// `demuxer-readahead-secs` — how far the demuxer runs ahead.
  final int readaheadSecs;

  /// `demuxer-max-bytes` — the hard byte ceiling for that read-ahead.
  final int maxBytes;

  /// `demuxer-max-back-bytes` — what survives a backwards seek.
  final int maxBackBytes;

  /// Ready to hand to `NativePlayer.setProperty`, in the order mpv
  /// likes: the byte ceilings before the seconds that depend on them.
  Map<String, String> get mpvProperties => {
        'cache': 'yes',
        'demuxer-max-bytes': '$maxBytes',
        'demuxer-max-back-bytes': '$maxBackBytes',
        'cache-secs': '$cacheSecs',
        'demuxer-readahead-secs': '$readaheadSecs',
      };

  @override
  String toString() => 'BufferTuning(cacheSecs: $cacheSecs, '
      'readaheadSecs: $readaheadSecs, maxBytes: $maxBytes, '
      'maxBackBytes: $maxBackBytes)';
}

/// The preset actually used for a stream.
///
/// SmartTube's comment on the low preset is "LIVE fix": a large buffer
/// on a rolling HLS playlist stutters constantly, because the segments
/// the player wants to read ahead into do not exist yet. So a live
/// broadcast always plays at [BufferPreset.low] whatever the user chose
/// for on-demand video.
BufferPreset effectiveBufferPreset(
  BufferPreset preset, {
  required bool isLive,
}) =>
    isLive ? BufferPreset.low : preset;

/// Maps a preset onto mpv properties. Pure: [totalRamBytes] is passed
/// in, never read from the platform here.
BufferTuning bufferTuningFor(
  BufferPreset preset, {
  int? totalRamBytes,
  bool isLive = false,
}) {
  final effective = effectiveBufferPreset(preset, isLive: isLive);
  final seconds = bufferPresetSeconds[effective]!;
  final base = _presetBaseBytes[effective]!;
  final scaled =
      (base * ramClassMultiplier(deviceRamClassFor(totalRamBytes))).round();
  final maxBytes = scaled.clamp(8 * _mib, maxBufferBytesCeiling);
  // A backwards seek should land inside what is still in memory, but
  // the back buffer competes with the read-ahead for the same budget —
  // SmartTube only enables one at all on the two large presets.
  final maxBackBytes = (maxBytes ~/ 3).clamp(8 * _mib, 64 * _mib);
  return BufferTuning(
    cacheSecs: seconds,
    readaheadSecs: seconds,
    maxBytes: maxBytes,
    maxBackBytes: maxBackBytes,
  );
}

// ============================================================
// Audio delay
// ============================================================

/// SmartTube's audio shift, bounded. Anything past a second is a broken
/// file rather than a preference.
const int audioDelayMinMs = -1000;
const int audioDelayMaxMs = 1000;
const int audioDelayStepMs = 50;

/// Snaps [milliseconds] to the nearest step inside the allowed range.
int normalizeAudioDelayMs(int milliseconds) {
  final clamped = milliseconds.clamp(audioDelayMinMs, audioDelayMaxMs);
  return (clamped / audioDelayStepMs).round() * audioDelayStepMs;
}

/// Every offered delay, negative (audio early) through zero to positive.
List<int> get audioDelayChoices => [
      for (var ms = audioDelayMinMs;
          ms <= audioDelayMaxMs;
          ms += audioDelayStepMs)
        ms,
    ];

/// mpv's `audio-delay` is seconds, not milliseconds.
String audioDelayProperty(int milliseconds) =>
    (normalizeAudioDelayMs(milliseconds) / 1000).toStringAsFixed(3);

// ============================================================
// Pitch
// ============================================================

/// mpv's `audio-pitch-correction` defaults to yes, which keeps the
/// voice pitch constant as the speed changes. Turning it off gives
/// SmartTube's "pitch effect": the pitch rides the speed, chipmunk
/// upwards and slowed-record downwards.
String pitchCorrectionProperty({required bool keepPitch}) =>
    keepPitch ? 'yes' : 'no';

/// Everything that has to be (re-)asserted on the shared player after
/// mpv reopens a file — mpv resets several of these per-file.
Map<String, String> playerTuningProperties({
  required BufferPreset preset,
  required int audioDelayMs,
  required bool keepPitch,
  bool isLive = false,
  int? totalRamBytes,
}) =>
    {
      ...bufferTuningFor(
        preset,
        totalRamBytes: totalRamBytes,
        isLive: isLive,
      ).mpvProperties,
      'audio-delay': audioDelayProperty(audioDelayMs),
      'audio-pitch-correction': pitchCorrectionProperty(keepPitch: keepPitch),
    };

// ============================================================
// Device RAM
// ============================================================

/// Pulls `MemTotal` out of a Linux/Android `/proc/meminfo` dump.
/// Returns null when the line is missing or unparseable.
int? parseMemTotalBytes(String meminfo) {
  for (final line in const LineSplitter().convert(meminfo)) {
    if (!line.startsWith('MemTotal')) continue;
    final match = RegExp(r'(\d+)\s*kB', caseSensitive: false).firstMatch(line);
    if (match == null) return null;
    final kb = int.tryParse(match.group(1)!);
    return kb == null ? null : kb * 1024;
  }
  return null;
}

int? _cachedRamBytes;
bool _ramProbed = false;

/// Best-effort total RAM. Android and Linux expose it through
/// `/proc/meminfo`; everywhere else this is null and the tuning falls
/// back to the [DeviceRamClass.normal] budget.
Future<int?> readDeviceRamBytes() async {
  if (_ramProbed) return _cachedRamBytes;
  _ramProbed = true;
  try {
    if (Platform.isAndroid || Platform.isLinux) {
      final file = File('/proc/meminfo');
      if (file.existsSync()) {
        _cachedRamBytes = parseMemTotalBytes(await file.readAsString());
      }
    }
  } catch (_) {
    _cachedRamBytes = null;
  }
  return _cachedRamBytes;
}
