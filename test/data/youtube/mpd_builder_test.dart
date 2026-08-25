import 'package:flutter_test/flutter_test.dart';
// MediaType is youtube_explode_dart's own codec type; building a fake
// stream info needs it, but it reaches us transitively.
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:smarttube_poc/data/youtube/mpd_builder.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

MpdRepresentation _video({
  String id = '137',
  String mimeType = 'video/mp4',
  String codecs = 'avc1.640028',
  int bandwidth = 2500000,
  int width = 1920,
  int height = 1080,
  String? frameRate = '30',
  String url = 'https://rr1---sn-x.googlevideo.com/videoplayback?a=1&b=2',
  int? contentLength = 12345678,
  ByteRange? initRange = const ByteRange(0, 740),
  ByteRange? indexRange = const ByteRange(741, 1600),
}) =>
    MpdRepresentation(
      id: id,
      mimeType: mimeType,
      codecs: codecs,
      bandwidth: bandwidth,
      url: Uri.parse(url),
      width: width,
      height: height,
      frameRate: frameRate,
      contentLength: contentLength,
      initRange: initRange,
      indexRange: indexRange,
    );

MpdRepresentation _audio({
  String id = '251',
  String mimeType = 'audio/webm',
  String codecs = 'opus',
  int bandwidth = 128000,
  int? samplingRate = 48000,
  String? language,
  String url = 'https://rr1---sn-x.googlevideo.com/videoplayback?a=3',
}) =>
    MpdRepresentation(
      id: id,
      mimeType: mimeType,
      codecs: codecs,
      bandwidth: bandwidth,
      url: Uri.parse(url),
      audioSamplingRate: samplingRate,
      language: language,
      contentLength: 4000000,
      initRange: const ByteRange(0, 258),
      indexRange: const ByteRange(259, 1000),
    );

void main() {
  group('ByteRange', () {
    test('parses the start-end form', () {
      expect(ByteRange.parse('0-740'), const ByteRange(0, 740));
      expect(ByteRange.parse(' 12 - 34 '), const ByteRange(12, 34));
    });

    test('rejects the placeholders and malformed input', () {
      expect(ByteRange.parse(null), isNull);
      expect(ByteRange.parse(''), isNull);
      // YouTube writes 0-0 for formats that carry no index.
      expect(ByteRange.parse('0-0'), isNull);
      expect(ByteRange.parse('740'), isNull);
      expect(ByteRange.parse('abc-def'), isNull);
      expect(ByteRange.parse('900-100'), isNull);
    });
  });

  group('MpdBuilder', () {
    test('emits a static on-demand MPD with the DASH profile', () {
      final xml = MpdBuilder(
        duration: const Duration(minutes: 3, seconds: 25, milliseconds: 500),
        representations: [_video(), _audio()],
      ).build();

      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('xmlns="urn:mpeg:DASH:schema:MPD:2011"'));
      expect(xml, contains('xmlns:yt="http://youtube.com/yt/2012/10/10"'));
      expect(xml, contains('type="static"'));
      // ffmpeg's dash demuxer probes for this substring; without it the
      // manifest is never recognised as DASH.
      expect(xml, contains('profiles="urn:mpeg:dash:profile:isoff-on-demand'));
      expect(xml, contains('mediaPresentationDuration="PT205.500S"'));
      expect(xml, contains('<Period duration="PT205.500S">'));
      expect(xml.trimRight(), endsWith('</MPD>'));
    });

    test('groups one AdaptationSet per mime type, video first', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [
          _audio(),
          _video(id: '248', mimeType: 'video/webm', codecs: 'vp9'),
          _video(),
          _audio(id: '140', mimeType: 'audio/mp4', codecs: 'mp4a.40.2'),
        ],
      ).build();

      final sets = RegExp('mimeType="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1))
          .toList();
      expect(sets, ['video/mp4', 'video/webm', 'audio/mp4', 'audio/webm']);
      expect(RegExp('<AdaptationSet ').allMatches(xml), hasLength(4));
      expect(xml, contains('<AdaptationSet id="0" mimeType="video/mp4"'));
      expect(xml, contains('<AdaptationSet id="3" mimeType="audio/webm"'));
      expect(
        xml,
        contains('<Role schemeIdUri="urn:mpeg:DASH:role:2011" value="main"/>'),
      );
    });

    test('splits audio AdaptationSets per language and tags lang', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [
          _audio(id: '140', mimeType: 'audio/mp4', language: 'en'),
          _audio(id: '141', mimeType: 'audio/mp4', language: 'ar'),
        ],
      ).build();

      expect(RegExp('<AdaptationSet ').allMatches(xml), hasLength(2));
      expect(xml, contains('mimeType="audio/mp4" lang="ar"'));
      expect(xml, contains('mimeType="audio/mp4" lang="en"'));
    });

    test('writes the highest bandwidth rendition first', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [
          _video(id: '135', bandwidth: 800000, width: 854, height: 480),
          _video(), // id 137, the highest bandwidth of the three
          _video(id: '136', bandwidth: 1200000, width: 1280, height: 720),
        ],
      ).build();

      final ids = RegExp('<Representation id="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1))
          .toList();
      expect(ids, ['137', '136', '135']);
    });

    test('writes video attributes on video representations', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_video()],
      ).build();

      expect(
        xml,
        contains('<Representation id="137" codecs="avc1.640028" '
            'startWithSAP="1" bandwidth="2500000" width="1920" '
            'height="1080" maxPlayoutRate="1" frameRate="30">'),
      );
      expect(xml, isNot(contains('audioSamplingRate')));
    });

    test('writes audioSamplingRate on audio representations', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_audio()],
      ).build();

      expect(
        xml,
        contains('<Representation id="251" codecs="opus" startWithSAP="1" '
            'bandwidth="128000" audioSamplingRate="48000">'),
      );
      // Leading space matters: "bandwidth=" ends in "width=".
      expect(xml, isNot(contains(' width=')));
      expect(xml, isNot(contains(' height=')));
      expect(xml, isNot(contains('frameRate=')));
    });

    test('writes SegmentBase with Initialization and indexRange', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_video()],
      ).build();

      expect(
        xml,
        contains('<SegmentBase indexRange="741-1600" indexRangeExact="true">'),
      );
      expect(xml, contains('<Initialization range="0-740"/>'));
      expect(xml, contains('</SegmentBase>'));
    });

    test('omits SegmentBase when the format has no index range', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_video(initRange: null, indexRange: null)],
      ).build();

      expect(xml, isNot(contains('SegmentBase')));
      expect(xml, isNot(contains('Initialization')));
      expect(xml, contains('<BaseURL'));
    });

    test('emits BaseURL with yt:contentLength and escaped ampersands', () {
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_video()],
      ).build();

      // ignore: missing_whitespace_between_adjacent_strings -- a URL
      const expected = '<BaseURL yt:contentLength="12345678">'
          'https://rr1---sn-x.googlevideo.com/videoplayback?a=1&amp;b=2'
          '</BaseURL>';
      expect(xml, contains(expected));
      // A raw & would make the manifest invalid XML and libxml2 would
      // refuse the whole document.
      expect(RegExp('&(?!amp;|lt;|gt;|quot;|apos;)').hasMatch(xml), isFalse);
    });

    test('routes every URL through the rewrite callback', () {
      final seen = <Uri>[];
      final xml = MpdBuilder(
        duration: const Duration(seconds: 10),
        representations: [_video(), _audio()],
      ).build(
        rewrite: (url) {
          seen.add(url);
          return 'http://127.0.0.1:8080/s${seen.length - 1}';
        },
      );

      expect(seen, hasLength(2));
      expect(xml, contains('>http://127.0.0.1:8080/s0</BaseURL>'));
      expect(xml, contains('>http://127.0.0.1:8080/s1</BaseURL>'));
      expect(xml, isNot(contains('googlevideo.com')));
    });

    test('isEmpty guards against manifests no player would accept', () {
      expect(
        const MpdBuilder(
          duration: Duration(seconds: 10),
          representations: [],
        ).isEmpty,
        isTrue,
      );
      expect(
        MpdBuilder(
          duration: Duration.zero,
          representations: [_video()],
        ).isEmpty,
        isTrue,
      );
      expect(
        MpdBuilder(
          duration: const Duration(seconds: 10),
          representations: [_video()],
        ).isEmpty,
        isFalse,
      );
    });
  });

  group('MpdBuilder.fromStreams', () {
    VideoOnlyStreamInfo videoStream() => VideoOnlyStreamInfo(
          VideoId('cKmZTUqZ5eA'),
          137,
          Uri.parse('https://r1.googlevideo.com/videoplayback?itag=137&x=1'),
          StreamContainer.mp4,
          const FileSize(9000000),
          const Bitrate(2500000),
          'avc1.640028',
          '1080p',
          VideoQuality.high1080,
          const VideoResolution(1920, 1080),
          const Framerate(30),
          const [],
          MediaType.parse('video/mp4; codecs="avc1.640028"'),
          initRange: '0-740',
          indexRange: '741-1600',
        );

    AudioOnlyStreamInfo audioStream() => AudioOnlyStreamInfo(
          VideoId('cKmZTUqZ5eA'),
          251,
          Uri.parse('https://r1.googlevideo.com/videoplayback?itag=251&x=1'),
          StreamContainer.webM,
          const FileSize(3000000),
          const Bitrate(128000),
          'opus',
          'medium',
          const [],
          MediaType.parse('audio/webm; codecs="opus"'),
          null,
          initRange: '0-258',
          indexRange: '259-1000',
          audioSamplingRate: 48000,
        );

    test('adapts youtube_explode stream infos into representations', () {
      final builder = MpdBuilder.fromStreams(
        duration: const Duration(minutes: 1, seconds: 30),
        streams: [videoStream(), audioStream()],
      );

      expect(builder.representations, hasLength(2));
      final video = builder.representations.firstWhere((r) => r.isVideo);
      expect(video.id, '137');
      expect(video.mimeType, 'video/mp4');
      expect(video.codecs, 'avc1.640028');
      expect(video.bandwidth, 2500000);
      expect(video.width, 1920);
      expect(video.height, 1080);
      expect(video.frameRate, '30');
      expect(video.contentLength, 9000000);
      expect(video.initRange, const ByteRange(0, 740));
      expect(video.indexRange, const ByteRange(741, 1600));

      final audio = builder.representations.firstWhere((r) => !r.isVideo);
      expect(audio.id, '251');
      expect(audio.mimeType, 'audio/webm');
      expect(audio.codecs, 'opus');
      expect(audio.audioSamplingRate, 48000);
      expect(audio.language, isNull);
    });

    test('builds a two-AdaptationSet manifest from a manifest slice', () {
      final xml = MpdBuilder.fromStreams(
        duration: const Duration(minutes: 1, seconds: 30),
        streams: [videoStream(), audioStream()],
      ).build(
        rewrite: (url) => 'http://127.0.0.1:9/${url.queryParameters['itag']}',
      );

      expect(RegExp('<AdaptationSet ').allMatches(xml), hasLength(2));
      expect(xml, contains('mimeType="video/mp4"'));
      expect(xml, contains('mimeType="audio/webm"'));
      expect(xml, contains('>http://127.0.0.1:9/137</BaseURL>'));
      expect(xml, contains('>http://127.0.0.1:9/251</BaseURL>'));
      expect(xml, contains('mediaPresentationDuration="PT90.000S"'));
    });

    test('drops muxed streams, which need no manifest', () {
      final muxed = MuxedStreamInfo(
        VideoId('cKmZTUqZ5eA'),
        18,
        Uri.parse('https://r1.googlevideo.com/videoplayback?itag=18'),
        StreamContainer.mp4,
        const FileSize(5000000),
        const Bitrate(600000),
        'mp4a.40.2',
        'avc1.42001E',
        '360p',
        VideoQuality.medium360,
        const VideoResolution(640, 360),
        const Framerate(30),
        MediaType.parse('video/mp4; codecs="avc1.42001E, mp4a.40.2"'),
      );

      final builder = MpdBuilder.fromStreams(
        duration: const Duration(seconds: 30),
        streams: [muxed, videoStream()],
      );
      expect(builder.representations, hasLength(1));
      expect(builder.representations.single.id, '137');
    });
  });
}
