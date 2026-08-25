import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/services/player_tuning.dart';

const int _mib = 1024 * 1024;
const int _gib = 1024 * 1024 * 1024;

void main() {
  group('buffer preset -> mpv seconds', () {
    test('matches SmartTube createLoadControl', () {
      // ExoPlayerInitializer: low 5s (LIVE fix), medium 30s (default),
      // high 50s, highest 100s.
      expect(bufferTuningFor(BufferPreset.low).cacheSecs, 5);
      expect(bufferTuningFor(BufferPreset.medium).cacheSecs, 30);
      expect(bufferTuningFor(BufferPreset.high).cacheSecs, 50);
      expect(bufferTuningFor(BufferPreset.highest).cacheSecs, 100);
    });

    test('read-ahead follows the cache ceiling', () {
      for (final preset in BufferPreset.values) {
        final tuning = bufferTuningFor(preset);
        expect(tuning.readaheadSecs, tuning.cacheSecs, reason: preset.name);
      }
    });

    test('every preset is larger than the one below it', () {
      final ordered = [
        BufferPreset.low,
        BufferPreset.medium,
        BufferPreset.high,
        BufferPreset.highest,
      ].map(bufferTuningFor).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].cacheSecs, greaterThan(ordered[i - 1].cacheSecs));
        expect(
          ordered[i].maxBytes,
          greaterThanOrEqualTo(ordered[i - 1].maxBytes),
        );
      }
    });
  });

  group('device RAM class', () {
    test('unknown RAM is treated as an ordinary device', () {
      expect(deviceRamClassFor(null), DeviceRamClass.normal);
      expect(deviceRamClassFor(0), DeviceRamClass.normal);
      // SmartTube's overflow case: RAM bigger than a signed int reads
      // back negative.
      expect(deviceRamClassFor(-1), DeviceRamClass.normal);
    });

    test('buckets real devices', () {
      expect(deviceRamClassFor(2 * _gib), DeviceRamClass.low);
      expect(deviceRamClassFor(4 * _gib), DeviceRamClass.normal);
      expect(deviceRamClassFor(8 * _gib), DeviceRamClass.high);
    });

    test('scales the byte ceiling', () {
      final small = bufferTuningFor(
        BufferPreset.medium,
        totalRamBytes: 2 * _gib,
      );
      final normal = bufferTuningFor(
        BufferPreset.medium,
        totalRamBytes: 4 * _gib,
      );
      final large = bufferTuningFor(
        BufferPreset.medium,
        totalRamBytes: 8 * _gib,
      );

      expect(normal.maxBytes, 64 * _mib);
      expect(small.maxBytes, 32 * _mib);
      expect(large.maxBytes, 96 * _mib);
      // Unknown RAM behaves like an ordinary device.
      expect(bufferTuningFor(BufferPreset.medium).maxBytes, normal.maxBytes);
    });

    test('never exceeds the SmartTube ceiling', () {
      final tuning = bufferTuningFor(
        BufferPreset.highest,
        totalRamBytes: 64 * _gib,
      );
      expect(tuning.maxBytes, lessThanOrEqualTo(maxBufferBytesCeiling));
      expect(tuning.maxBackBytes, lessThanOrEqualTo(tuning.maxBytes));
    });
  });

  group('live streams', () {
    test('are pinned to the low preset whatever the user chose', () {
      for (final preset in BufferPreset.values) {
        expect(
          effectiveBufferPreset(preset, isLive: true),
          BufferPreset.low,
          reason: preset.name,
        );
      }
      expect(
        bufferTuningFor(BufferPreset.highest, isLive: true),
        isA<BufferTuning>().having((t) => t.cacheSecs, 'cacheSecs', 5),
      );
    });

    test('leave on-demand playback alone', () {
      expect(
        effectiveBufferPreset(BufferPreset.high, isLive: false),
        BufferPreset.high,
      );
    });
  });

  group('mpv property names', () {
    test('are the ones the player sets', () {
      final properties = bufferTuningFor(
        BufferPreset.high,
        totalRamBytes: 4 * _gib,
      ).mpvProperties;
      expect(properties['cache'], 'yes');
      expect(properties['cache-secs'], '50');
      expect(properties['demuxer-readahead-secs'], '50');
      expect(properties['demuxer-max-bytes'], '${96 * _mib}');
      expect(properties['demuxer-max-back-bytes'], '${32 * _mib}');
    });

    test('the full tweak set carries delay and pitch', () {
      final properties = playerTuningProperties(
        preset: BufferPreset.medium,
        audioDelayMs: -250,
        keepPitch: false,
        totalRamBytes: 4 * _gib,
      );
      expect(properties['audio-delay'], '-0.250');
      expect(properties['audio-pitch-correction'], 'no');
      expect(properties['cache-secs'], '30');
    });
  });

  group('audio delay', () {
    test("is clamped to SmartTube's range", () {
      expect(normalizeAudioDelayMs(5000), audioDelayMaxMs);
      expect(normalizeAudioDelayMs(-5000), audioDelayMinMs);
    });

    test('snaps to 50 ms steps', () {
      expect(normalizeAudioDelayMs(37), 50);
      expect(normalizeAudioDelayMs(-37), -50);
      expect(normalizeAudioDelayMs(12), 0);
    });

    test('offers every step between the bounds', () {
      final choices = audioDelayChoices;
      expect(choices.first, audioDelayMinMs);
      expect(choices.last, audioDelayMaxMs);
      expect(choices.contains(0), isTrue);
      expect(choices.length, 41);
    });

    test('reaches mpv as seconds', () {
      expect(audioDelayProperty(0), '0.000');
      expect(audioDelayProperty(150), '0.150');
      expect(audioDelayProperty(-1000), '-1.000');
    });
  });

  group('pitch', () {
    test('keeping the pitch is mpv default', () {
      expect(pitchCorrectionProperty(keepPitch: true), 'yes');
      expect(pitchCorrectionProperty(keepPitch: false), 'no');
    });
  });

  group('MemTotal parsing', () {
    test('reads the Android/Linux meminfo line', () {
      const meminfo = 'MemTotal:        3910284 kB\n'
          'MemFree:          123456 kB\n';
      expect(parseMemTotalBytes(meminfo), 3910284 * 1024);
    });

    test('is null when the line is absent or malformed', () {
      expect(parseMemTotalBytes('MemFree: 100 kB'), isNull);
      expect(parseMemTotalBytes('MemTotal: lots'), isNull);
      expect(parseMemTotalBytes(''), isNull);
    });
  });
}
