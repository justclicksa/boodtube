// ============================================================
// MpdBuilder - client-side DASH manifest for YouTube streams
// ============================================================
// YouTube hands out one signed progressive URL per adaptive format and
// no manifest. The native SmartTube app assembles a DASH MPD from those
// formats on the device (YouTubeMPDBuilder.java) so one URL carries both
// video and audio; this is the Dart equivalent.
//
// The manifest describes each format as a `SegmentBase` representation:
// a whole-file BaseURL plus the byte ranges of its `moov` init block and
// its `sidx` index, exactly the shape YouTube's own adaptiveFormats
// entries describe (initRange/indexRange).
//
// URLs go through [MpdBuilder.build]'s `rewrite` callback so the manifest
// can point at the loopback relay (StreamProxy) rather than at
// googlevideo directly — mpv's bundled TLS cannot always reach the CDN,
// and the relay already knows how to walk a googlevideo file by range.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A byte range as DASH writes it: `start-end`, both inclusive.
@immutable
class ByteRange {
  const ByteRange(this.start, this.end);

  final int start;
  final int end;

  /// Parses the `start-end` form. Returns null for anything that is not
  /// two numbers, and for the `0-0` placeholder YouTube uses to mean
  /// "this format has no index" (the Java builder rejects it too).
  static ByteRange? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());
    if (start == null || end == null) return null;
    if (start == 0 && end == 0) return null;
    if (end < start) return null;
    return ByteRange(start, end);
  }

  @override
  String toString() => '$start-$end';

  @override
  bool operator ==(Object other) =>
      other is ByteRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// One `<Representation>`: a single rendition of the video or audio.
class MpdRepresentation {
  const MpdRepresentation({
    required this.id,
    required this.mimeType,
    required this.codecs,
    required this.bandwidth,
    required this.url,
    this.width,
    this.height,
    this.frameRate,
    this.audioSamplingRate,
    this.language,
    this.contentLength,
    this.initRange,
    this.indexRange,
  });

  /// Adapts a stream from the youtube_explode_dart manifest.
  ///
  /// Only adaptive (video-only / audio-only) streams belong in an MPD;
  /// a muxed stream already carries both tracks and needs no manifest.
  factory MpdRepresentation.fromStreamInfo(StreamInfo info) {
    final isVideo = info is VideoStreamInfo;
    final audio = info is AudioStreamInfo ? info : null;
    final resolution = isVideo ? info.videoResolution : null;
    return MpdRepresentation(
      id: '${info.tag}',
      mimeType: '${info.codec.type}/${info.codec.subtype}',
      codecs: info.codec.parameters['codecs'] ?? '',
      bandwidth: info.bitrate.bitsPerSecond,
      url: info.url,
      width: resolution?.width,
      height: resolution?.height,
      frameRate: isVideo ? '${info.framerate.framesPerSecond}' : null,
      audioSamplingRate: audio?.audioSamplingRate,
      language: audio?.audioTrack?.id,
      contentLength: info.size.totalBytes,
      initRange: ByteRange.parse(info.initRange),
      indexRange: ByteRange.parse(info.indexRange),
    );
  }

  /// Unique within the manifest — the itag, matching the Java builder.
  final String id;

  /// `video/mp4`, `audio/webm`, ... — parameters stripped: the codecs
  /// belong on the Representation, and the AdaptationSet groups on the
  /// bare type.
  final String mimeType;

  /// `avc1.640028`, `opus`, ...
  final String codecs;

  /// Bits per second.
  final int bandwidth;

  final Uri url;
  final int? width;
  final int? height;

  /// Frames per second, as text so `30000/1001` stays expressible.
  final String? frameRate;
  final int? audioSamplingRate;

  /// BCP-47-ish audio track language, for multi-language audio.
  final String? language;

  /// Total size in bytes, emitted as `yt:contentLength`.
  final int? contentLength;

  final ByteRange? initRange;
  final ByteRange? indexRange;

  bool get isVideo => (width ?? 0) > 0 && (height ?? 0) > 0;
}

/// Builds a static (on-demand) DASH manifest out of [representations].
///
/// The output mirrors SmartTube's YouTubeMPDBuilder: one AdaptationSet
/// per mime type (per language for audio), video sets first, and the
/// highest-bandwidth rendition written first inside each set.
class MpdBuilder {
  const MpdBuilder({
    required this.duration,
    required this.representations,
  });

  /// Builds from a youtube_explode_dart manifest slice. Muxed streams
  /// and streams without a usable URL are dropped.
  factory MpdBuilder.fromStreams({
    required Duration duration,
    required Iterable<StreamInfo> streams,
  }) {
    return MpdBuilder(
      duration: duration,
      representations: streams
          .where((s) => s is VideoOnlyStreamInfo || s is AudioOnlyStreamInfo)
          .map(MpdRepresentation.fromStreamInfo)
          .toList(),
    );
  }

  /// Total presentation duration. A static MPD is invalid without it.
  final Duration duration;

  final List<MpdRepresentation> representations;

  bool get isEmpty => representations.isEmpty || duration <= Duration.zero;

  /// Serialises the manifest.
  ///
  /// [rewrite] maps each stream URL to whatever the player should
  /// actually fetch — typically a StreamProxy loopback URL. When it is
  /// omitted the upstream URLs are written unchanged.
  String build({String Function(Uri url)? rewrite}) {
    final durationText = _durationText(duration);
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<MPD '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xmlns="urn:mpeg:DASH:schema:MPD:2011" '
          'xmlns:yt="http://youtube.com/yt/2012/10/10" '
          'xsi:schemaLocation="urn:mpeg:DASH:schema:MPD:2011 DASH-MPD.xsd" '
          'minBufferTime="PT1.500S" '
          // ffmpeg's dash demuxer only probes a document as DASH when it
          // finds "dash:profile" near the top, so this attribute is load
          // bearing, not decoration.
          'profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" '
          'type="static" '
          'mediaPresentationDuration="$durationText">')
      ..writeln('  <Period duration="$durationText">');

    var setId = 0;
    for (final group in _groups()) {
      final first = group.first;
      out.write('    <AdaptationSet id="${setId++}" '
          'mimeType="${_esc(first.mimeType)}"');
      if (first.language != null && first.language!.isNotEmpty) {
        out.write(' lang="${_esc(first.language!)}"');
      }
      out
        ..writeln(' subsegmentAlignment="true">')
        ..writeln('      <Role schemeIdUri="urn:mpeg:DASH:role:2011" '
            'value="main"/>');
      for (final rep in group) {
        _writeRepresentation(out, rep, rewrite);
      }
      out.writeln('    </AdaptationSet>');
    }

    out
      ..writeln('  </Period>')
      ..writeln('</MPD>');
    return out.toString();
  }

  void _writeRepresentation(
    StringBuffer out,
    MpdRepresentation rep,
    String Function(Uri url)? rewrite,
  ) {
    out.write('      <Representation id="${_esc(rep.id)}" '
        'codecs="${_esc(rep.codecs)}" '
        'startWithSAP="1" '
        'bandwidth="${rep.bandwidth}"');
    if (rep.isVideo) {
      out.write(' width="${rep.width}" height="${rep.height}" '
          'maxPlayoutRate="1"');
      if (rep.frameRate != null) {
        out.write(' frameRate="${_esc(rep.frameRate!)}"');
      }
    } else if (rep.audioSamplingRate != null) {
      out.write(' audioSamplingRate="${rep.audioSamplingRate}"');
    }
    out.writeln('>');

    final url = rewrite == null ? rep.url.toString() : rewrite(rep.url);
    out.write('        <BaseURL');
    if (rep.contentLength != null && rep.contentLength! > 0) {
      out.write(' yt:contentLength="${rep.contentLength}"');
    }
    out.writeln('>${_esc(url)}</BaseURL>');

    final index = rep.indexRange;
    if (index != null) {
      out.writeln('        <SegmentBase indexRange="$index" '
          'indexRangeExact="true">');
      if (rep.initRange != null) {
        out.writeln('          <Initialization range="${rep.initRange}"/>');
      }
      out.writeln('        </SegmentBase>');
    }
    out.writeln('      </Representation>');
  }

  /// Representations bucketed into AdaptationSets, in write order.
  List<List<MpdRepresentation>> _groups() {
    final groups = <String, List<MpdRepresentation>>{};
    for (final rep in representations) {
      final key = '${rep.mimeType} ${rep.language ?? ''}';
      groups.putIfAbsent(key, () => <MpdRepresentation>[]).add(rep);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final rank = _rank(groups[a]!.first).compareTo(_rank(groups[b]!.first));
        return rank != 0 ? rank : a.compareTo(b);
      });
    return [
      for (final key in keys)
        groups[key]!
          // Highest quality first: MX Player (and mpv's default track
          // pick) take the first playable rendition they are offered.
          ..sort((a, b) {
            final byBandwidth = b.bandwidth.compareTo(a.bandwidth);
            return byBandwidth != 0 ? byBandwidth : a.id.compareTo(b.id);
          }),
    ];
  }

  static int _rank(MpdRepresentation rep) {
    final isVideoType = rep.mimeType.startsWith('video/');
    final isMp4 = rep.mimeType.endsWith('/mp4');
    if (isVideoType) return isMp4 ? 0 : 1;
    return isMp4 ? 2 : 3;
  }

  /// `PT12.345S` — the xs:duration form DASH wants.
  static String _durationText(Duration duration) {
    final micros = duration.inMicroseconds < 0 ? 0 : duration.inMicroseconds;
    final seconds = micros ~/ Duration.microsecondsPerSecond;
    final millis = (micros % Duration.microsecondsPerSecond) ~/ 1000;
    return 'PT$seconds.${millis.toString().padLeft(3, '0')}S';
  }

  /// Signed googlevideo URLs are full of `&`, which is not valid raw XML.
  static String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
