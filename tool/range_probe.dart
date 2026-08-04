// Diagnoses where googlevideo stops serving a stream URL, and whether the
// cutoff depends on the range dialect used.
//
//   dart run tool/range_probe.dart <videoId>

import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final videoId = args.isNotEmpty ? args.first : 'p7UU97jS9Z4';
  final yt = YoutubeExplode();
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  for (final api in [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.android,
    YoutubeApiClient.ios,
  ]) {
    stdout.writeln('\n=== client: $api ===');
    Uri url;
    int total;
    int tag;
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(VideoId(videoId), ytClients: [api]);
      final stream = manifest.video
          .where((s) => s.videoResolution.height <= 720)
          .reduce((a, b) =>
              a.videoResolution.height >= b.videoResolution.height ? a : b);
      url = stream.url;
      total = stream.size.totalBytes;
      tag = stream.tag;
      stdout.writeln('itag ${stream.tag} ${stream.qualityLabel} '
          '${(total / 1024 / 1024).toStringAsFixed(1)} MiB');
    } catch (e) {
      stdout.writeln('resolve failed: $e');
      continue;
    }

    // Walk the file, re-resolving the URL whenever googlevideo refuses,
    // to confirm the cap is per-URL and that a fresh one resumes cleanly.
    var offset = 0;
    const slice = 1024 * 1024;
    var refreshes = 0;
    final sw = Stopwatch()..start();
    while (offset < total && offset < 40 * 1024 * 1024) {
      final end = (offset + slice - 1).clamp(0, total - 1);
      final bytes = await _read(client, url, offset, end, true);
      if (bytes == null || bytes == 0) {
        if (refreshes >= 5) {
          stdout.writeln('  gave up at '
              '${(offset / 1024 / 1024).toStringAsFixed(2)} MiB');
          break;
        }
        refreshes++;
        stdout.writeln('  refused at '
            '${(offset / 1024 / 1024).toStringAsFixed(2)} MiB '
            '-> re-resolving (#$refreshes)');
        final refreshSw = Stopwatch()..start();
        try {
          final manifest = await yt.videos.streamsClient
              .getManifest(VideoId(videoId), ytClients: [api]);
          url = manifest.video
              .firstWhere(
                (s) => s.tag == tag,
                orElse: () => manifest.video.first,
              )
              .url;
          stdout.writeln('    fresh URL in ${refreshSw.elapsedMilliseconds}ms');
        } catch (e) {
          stdout.writeln('    re-resolve failed: $e');
          break;
        }
        continue;
      }
      offset += bytes;
    }
    stdout.writeln('  read ${(offset / 1024 / 1024).toStringAsFixed(1)} MiB '
        'in ${sw.elapsedMilliseconds}ms with $refreshes refresh(es)');
  }

  client.close(force: true);
  yt.close();
}

Future<int?> _read(
  HttpClient client,
  Uri url,
  int start,
  int end,
  bool useQuery,
) async {
  try {
    final HttpClientRequest req;
    if (useQuery) {
      req = await client.getUrl(url.replace(queryParameters: {
        ...url.queryParameters,
        'range': '$start-$end',
      }));
    } else {
      req = await client.getUrl(url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    }
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200 && res.statusCode != 206) {
      stdout.writeln('  status ${res.statusCode} at $start');
      await res.drain<void>();
      return null;
    }
    var count = 0;
    await for (final chunk in res) {
      count += chunk.length;
    }
    return count;
  } catch (e) {
    stdout.writeln('  error at $start: $e');
    return null;
  }
}
