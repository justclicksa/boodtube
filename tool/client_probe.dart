// Finds which YouTube API clients hand out stream URLs googlevideo will
// actually serve past the first few MiB.
//
//   dart run tool/client_probe.dart [videoId ...]

import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _target = 24 * 1024 * 1024; // enough to prove there is no early cap

Future<void> main(List<String> args) async {
  final videoIds = args.isNotEmpty ? args : ['p7UU97jS9Z4', 'dQw4w9WgXcQ'];
  final yt = YoutubeExplode();
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  final clients = <String, YoutubeApiClient>{
    'androidVr': YoutubeApiClient.androidVr,
    'mediaConnect': YoutubeApiClient.mediaConnect,
    'tv': YoutubeApiClient.tv,
    'tvSimplyEmbedded': YoutubeApiClient.tvSimplyEmbedded,
    'android': YoutubeApiClient.android,
    'androidSdkless': YoutubeApiClient.androidSdkless,
    'androidMusic': YoutubeApiClient.androidMusic,
    'ios': YoutubeApiClient.ios,
    'mweb': YoutubeApiClient.mweb,
    'safari': YoutubeApiClient.safari,
  };

  for (final videoId in videoIds) {
    stdout.writeln('\n########## $videoId ##########');
    for (final entry in clients.entries) {
      stdout.write('${entry.key.padRight(18)} ');
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(VideoId(videoId), ytClients: [entry.value])
            .timeout(const Duration(seconds: 40));
        final candidates =
            manifest.video.where((s) => s.videoResolution.height <= 720);
        if (candidates.isEmpty) {
          stdout.writeln('no <=720p stream');
          continue;
        }
        final stream = candidates.reduce((a, b) =>
            a.videoResolution.height >= b.videoResolution.height ? a : b);
        final total = stream.size.totalBytes;
        final reached = await _walk(http, stream.url, total);
        final mib = (reached / 1024 / 1024).toStringAsFixed(1);
        final capped = reached < _target && reached < total;
        stdout.writeln('itag ${stream.tag} ${stream.qualityLabel} '
            '-> ${capped ? 'CAPPED at' : 'ok, read'} $mib MiB '
            'of ${(total / 1024 / 1024).toStringAsFixed(1)}');
      } catch (e) {
        stdout.writeln('failed: ${e.toString().split('\n').first}');
      }
    }
  }

  http.close(force: true);
  yt.close();
}

/// Reads sequentially until refused or [_target] is reached; returns the
/// byte offset actually served.
Future<int> _walk(HttpClient http, Uri url, int total) async {
  const slice = 1024 * 1024;
  var offset = 0;
  while (offset < total && offset < _target) {
    final end = (offset + slice - 1).clamp(0, total - 1);
    try {
      final req = await http.getUrl(url.replace(queryParameters: {
        ...url.queryParameters,
        'range': '$offset-$end',
      }));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && res.statusCode != 206) {
        await res.drain<void>();
        return offset;
      }
      var count = 0;
      await for (final chunk in res) {
        count += chunk.length;
      }
      if (count == 0) return offset;
      offset += count;
    } catch (_) {
      return offset;
    }
  }
  return offset;
}
