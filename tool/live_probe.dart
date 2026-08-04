// Checks what is available for a live stream, and whether the HLS
// playlist can be fetched the way mpv would.
//
//   dart run tool/live_probe.dart <videoId>

import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final videoId = args.isNotEmpty ? args.first : 'e27qjWbHJrM';
  final yt = YoutubeExplode();

  try {
    final video = await yt.videos.get(videoId);
    stdout.writeln('title: ${video.title}');
    stdout.writeln('isLive: ${video.isLive}');
  } catch (e) {
    stdout.writeln('metadata failed: $e');
  }

  stdout.writeln('\n-- progressive manifest --');
  try {
    final manifest = await yt.videos.streamsClient.getManifest(
      VideoId(videoId),
      ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.android],
    );
    stdout.writeln('video streams: ${manifest.video.length}');
  } catch (e) {
    stdout.writeln('FAILED: ${e.toString().split('\n').first}');
  }

  stdout.writeln('\n-- HLS --');
  try {
    final url = await yt.videos.streamsClient
        .getHttpLiveStreamUrl(VideoId(videoId));
    stdout.writeln('hls: ${url.substring(0, url.length.clamp(0, 110))}');

    final client = HttpClient();
    final res = await (await client.getUrl(Uri.parse(url))).close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    stdout.writeln('playlist status: ${res.statusCode}, '
        '${body.length} bytes');
    final variants = body
        .split('\n')
        .where((l) => l.startsWith('http'))
        .toList();
    stdout.writeln('variant urls: ${variants.length}');
    if (variants.isNotEmpty) {
      stdout.writeln('first: ${variants.first.substring(
        0,
        variants.first.length.clamp(0, 110),
      )}');
    }
    client.close();
  } catch (e) {
    stdout.writeln('FAILED: ${e.toString().split('\n').first}');
  }

  yt.close();
}
