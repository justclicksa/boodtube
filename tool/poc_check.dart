// Quick PoC diagnostic: can youtube_explode_dart 3.1.0 fetch metadata + streams?
// Run: dart run tool/poc_check.dart
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main() async {
  final yt = YoutubeExplode();
  const videoId = 'dQw4w9WgXcQ';
  final sw = Stopwatch()..start();
  try {
    print('[1] fetching metadata...');
    final video = await yt.videos.get(videoId).timeout(const Duration(seconds: 30));
    print('    OK (${sw.elapsedMilliseconds}ms): ${video.title} / ${video.duration}');

    print('[2] fetching stream manifest...');
    sw.reset();
    final manifest =
        await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 60));
    print('    OK (${sw.elapsedMilliseconds}ms)');
    print('    muxed: ${manifest.muxed.length}, videoOnly: ${manifest.videoOnly.length}, audioOnly: ${manifest.audioOnly.length}');
    for (final s in manifest.videoOnly.take(3)) {
      print('    video ${s.videoQuality} ${s.container.name} ${s.bitrate}');
    }
    for (final s in manifest.audioOnly.take(2)) {
      print('    audio ${s.container.name} ${s.bitrate}');
    }
    final best = manifest.videoOnly.isNotEmpty ? manifest.videoOnly.first : null;
    if (best != null) {
      print('[3] sample URL head: ${best.url.toString().substring(0, 90)}...');
    }

    // [4] CRITICAL: actually fetch bytes from the stream URLs.
    // URL generation succeeding does NOT mean YouTube will serve the bytes
    // (403 on missing/invalid `n`-param descramble or client mismatch).
    print('[4] fetching first bytes of video stream...');
    sw.reset();
    final httpClient = HttpClient();
    for (final entry in {
      'video': best?.url,
      'audio':
          manifest.audioOnly.isNotEmpty ? manifest.audioOnly.first.url : null,
    }.entries) {
      final url = entry.value;
      if (url == null) continue;
      try {
        final req = await httpClient.getUrl(url);
        req.headers.add('Range', 'bytes=0-65535');
        final res = await req.close().timeout(const Duration(seconds: 20));
        var bytes = 0;
        await for (final chunk in res.take(4)) {
          bytes += chunk.length;
        }
        print('    ${entry.key}: HTTP ${res.statusCode}, '
            'got $bytes bytes in ${sw.elapsedMilliseconds}ms');

        // Also probe the plain-http variant (mpv TLS is broken on the
        // x86_64 emulator, so http fallback may be the only viable path).
        final httpVariant = url.replace(scheme: 'http', port: 80);
        try {
          final req2 = await httpClient.getUrl(httpVariant);
          req2.headers.add('Range', 'bytes=0-1023');
          final res2 = await req2.close().timeout(const Duration(seconds: 15));
          await res2.drain<void>();
          print('    ${entry.key} PLAIN-HTTP: ${res2.statusCode}');
        } catch (e) {
          print('    ${entry.key} PLAIN-HTTP failed: $e');
        }
      } catch (e) {
        print('    ${entry.key}: FETCH FAILED: $e');
      }
    }
    httpClient.close(force: true);
  } catch (e, st) {
    print('    FAILED after ${sw.elapsedMilliseconds}ms: $e');
    print(st.toString().split('\n').take(5).join('\n'));
  } finally {
    yt.close();
  }
}
