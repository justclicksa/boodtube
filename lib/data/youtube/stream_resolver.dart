// ============================================================
// StreamResolver - Selects best streams for a video (FIXED)
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/media_format.dart';

class ResolvedStream {
  final String videoUrl;
  final String? audioUrl;
  final int? videoHeight;
  final String? videoCodec;
  final int? audioBitrate;
  final String qualityLabel;

  /// Every height the manifest offers, highest first — used to populate
  /// the in-player quality picker without a second network round-trip.
  final List<int> availableHeights;

  const ResolvedStream({
    required this.videoUrl,
    this.audioUrl,
    this.videoHeight,
    this.videoCodec,
    this.audioBitrate,
    required this.qualityLabel,
    this.availableHeights = const [],
  });
}

class StreamResolver {
  final YoutubeExplode _yt;

  StreamResolver(this._yt);

  /// Get the best streams for a video based on quality preference.
  ///
  /// [probe] (optional) is called with each candidate URL and must return
  /// the HTTP status googlevideo answers with; candidates that don't
  /// return 2xx are skipped (YouTube 403s some adaptive itags for
  /// non-browser clients). Falls back through: preferred video-only →
  /// lower video-only qualities → muxed streams.
  /// Clients to try, in order. androidVr is first because it is the only
  /// one whose URLs are not throttled after ~1.5 MiB (measured with
  /// tool/client_probe.dart) — but it cannot play every video
  /// (VideoUnplayableException), so throttled clients remain as fallback:
  /// with the proxy slicing requests they still start, just degraded.
  static const _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.android,
    YoutubeApiClient.androidSdkless,
  ];

  Future<ResolvedStream> getBestStream(
    String videoId, {
    MediaFormatQuality quality = MediaFormatQuality.high,
    Future<int> Function(Uri url)? probe,
    int? exactHeight,
  }) async {
    Object? lastError;
    for (final client in _clients) {
      try {
        return await _resolveWithClient(
          videoId,
          client,
          quality,
          probe,
          exactHeight,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Failed to resolve stream: $lastError');
  }

  Future<ResolvedStream> _resolveWithClient(
    String videoId,
    YoutubeApiClient client,
    MediaFormatQuality quality,
    Future<int> Function(Uri url)? probe,
    int? exactHeight,
  ) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        VideoId(videoId),
        ytClients: [client],
      );

      // Heights offered for this video, best first, for the picker UI.
      final heights = manifest.video
          .map((s) => s.videoResolution.height)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      // An explicit pick from the quality menu wins over the preference.
      var videoStream = exactHeight != null
          ? _selectExactHeight(manifest.video, exactHeight)
          : _selectVideo(manifest.video, quality);
      final audioStream = _selectAudio(manifest.audio);

      if (videoStream == null) {
        throw Exception('No suitable video stream found');
      }

      if (probe != null) {
        // Preferred first, then the rest ordered by how close they are
        // to it. Falling back from a deliberate 720p to 2160p because
        // one URL was refused is not a fallback, it is ignoring both the
        // request and the reason the cap exists.
        final target = exactHeight ?? videoStream.videoResolution.height;
        final fallbacks = manifest.video.toList()
          ..sort((a, b) {
            final aH = a.videoResolution.height;
            final bH = b.videoResolution.height;
            final da = (aH - target).abs();
            final db = (bH - target).abs();
            if (da != db) return da.compareTo(db);
            return bH.compareTo(aH);
          });
        videoStream = await _firstServed(
          <VideoStreamInfo>[videoStream, ...fallbacks],
          probe,
        );
        if (videoStream == null) {
          throw Exception('All video stream URLs were refused (403)');
        }
      }

      // FIXED: get URL directly from VideoStreamInfo (it's a public getter)
      final height = videoStream.videoResolution.height as int? ??
          int.tryParse(videoStream.qualityLabel.replaceAll('p', '').split('p').first);

      return ResolvedStream(
        videoUrl: videoStream.url.toString(),
        audioUrl: audioStream?.url.toString(),
        videoHeight: height,
        // FIXED: codec is MediaType, convert to string
        videoCodec: videoStream.codec.mimeType,
        audioBitrate: audioStream?.bitrate.bitsPerSecond,
        qualityLabel: videoStream.qualityLabel,
        availableHeights: heights,
      );
    } catch (e) {
      throw Exception('Failed to resolve stream: $e');
    }
  }

  /// Picks the stream the user explicitly chose from the quality menu,
  /// falling back to the closest height the manifest actually offers.
  VideoStreamInfo? _selectExactHeight(
    List<VideoStreamInfo> streams,
    int height,
  ) {
    if (streams.isEmpty) return null;
    final sorted = streams.toList()
      ..sort((a, b) {
        final da = (a.videoResolution.height - height).abs();
        final db = (b.videoResolution.height - height).abs();
        if (da != db) return da.compareTo(db);
        // Same distance: prefer the higher bitrate rendition.
        return b.bitrate.compareTo(a.bitrate);
      });
    return sorted.first;
  }

  /// Returns the first candidate whose URL googlevideo actually serves
  /// (2xx on a tiny Range request). Deduplicates by URL.
  Future<VideoStreamInfo?> _firstServed(
    List<VideoStreamInfo> candidates,
    Future<int> Function(Uri url) probe,
  ) async {
    final seen = <String>{};
    for (final candidate in candidates) {
      if (!seen.add(candidate.url.toString())) continue;
      final status = await probe(candidate.url);
      if (status >= 200 && status < 300) return candidate;
    }
    return null;
  }

  /// Get all available qualities (for quality picker UI)
  Future<List<String>> getAvailableQualities(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(
      VideoId(videoId),
    );
    return manifest.video
        .map((s) => s.qualityLabel)
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) {
        final aH = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bH = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return bH.compareTo(aH);
      });
  }

  /// FIXED: select HIGHEST quality <= preferred (not lowest)
  VideoStreamInfo? _selectVideo(
    List<VideoStreamInfo> streams,
    MediaFormatQuality quality,
  ) {
    if (streams.isEmpty) return null;

    // Map quality preference to max height
    final maxHeight = switch (quality) {
      MediaFormatQuality.lowest => 144,
      MediaFormatQuality.low => 360,
      MediaFormatQuality.medium => 480,
      MediaFormatQuality.high => 720,
      MediaFormatQuality.highest => 1080,
      MediaFormatQuality.best => 9999, // no cap
    };

    // Filter streams with videoResolution
    final withResolution = streams.toList();
    if (withResolution.isEmpty) return streams.first;

    // Sort by height DESCENDING
    withResolution.sort((a, b) {
      final aH = a.videoResolution.height;
      final bH = b.videoResolution.height;
      return bH.compareTo(aH);
    });

    // Only "best" means uncapped. `highest` advertises 1080p and must
    // honour that: returning the top rendition here made every video
    // default to 2160p, which no phone needs and which starves the
    // relay — that was the stutter, not the network.
    if (quality == MediaFormatQuality.best) {
      return withResolution.first; // already sorted descending
    }

    // Pick highest that's <= maxHeight
    for (final stream in withResolution) {
      if (stream.videoResolution.height <= maxHeight) {
        return stream;
      }
    }
    // If nothing fits under cap, return the lowest
    return withResolution.last;
  }

  /// FIXED: returns the actual best audio stream, not sort().first (which was void)
  AudioStreamInfo? _selectAudio(List<AudioStreamInfo> streams) {
    if (streams.isEmpty) return null;
    final sorted = [...streams]
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return sorted.first; // sorted.first is valid - returns first element
  }
}
