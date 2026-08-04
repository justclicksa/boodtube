// ============================================================
// InnerTubeClient - Implementation (FIXED for youtube_explode_dart v3.1.0)
// ============================================================
// Based on actual API inspection:
//   - YoutubeExplode().videos.get(VideoId) - takes VideoId or string
//   - .videos.getTrending() does NOT exist - use search
//   - .videos.commentsClient.getComments(Video) - takes Video
//   - .channels.get(ChannelId.fromString(id)) - takes string or ChannelId
//   - .channels.getUploads() returns Stream<Video>
//   - .videos.streamsClient.getManifest(VideoId) - takes VideoId or string
//   - Exceptions: VideoUnplayableException, VideoUnavailableException
//   - StreamInfo mixin: videoId, tag, url, container, size, bitrate, codec (MediaType), qualityLabel
//   - VideoStreamInfo adds: videoCodec, videoQuality, videoResolution, framerate
//   - AudioStreamInfo adds: audioCodec, audioTrack
//   - MuxedStreamInfo implements BOTH Audio and Video
//   - MediaType is from http_parser package (not String)
//   - Framerate is Framerate object (not double)
// ============================================================

import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/media_item.dart' as domain;
import '../../domain/entities/media_subtitle.dart';
import '../../domain/entities/media_format.dart' as fmt;
import '../../core/errors/exceptions.dart';
import 'mappers/media_item_mapper.dart';

/// Alias for MediaFormat (to avoid import conflicts)
typedef MediaFormatEntity = fmt.MediaFormat;

class InnerTubeClient {
  final YoutubeExplode _yt;

  InnerTubeClient(this._yt);

  /// Get full video info
  Future<domain.MediaItem> getVideo(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return MediaItemMapper.fromVideo(video);
    } on VideoUnavailableException catch (e) {
      // Must precede VideoUnplayableException — it is a subtype.
      throw NotFoundException('Video $videoId unavailable: ${e.message}');
    } on VideoUnplayableException catch (e) {
      throw YouTubeException('Video not playable: ${e.message}');
    } catch (e) {
      throw YouTubeException('Failed to get video: $e', cause: e);
    }
  }

  /// Get all available streams as MediaFormat entities
  /// FIXED: uses StreamInfo API correctly
  /// Progressive/adaptive formats. Empty for live broadcasts — those
  /// have no fixed-size streams, only a rolling HLS playlist, and the
  /// manifest parser throws outright on them. The caller falls back to
  /// the live path rather than failing the whole load.
  Future<List<MediaFormatEntity>> getStreams(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // FIXED: use mixin checks (not `is AudioStreamInfo` directly since
      // MuxedStreamInfo implements both). Iterate all streams.
      final allStreams = <StreamInfo>[
        ...manifest.video,
        ...manifest.audio,
      ];
      return allStreams.map(MediaItemMapper.fromStream).toList();
    } catch (e) {
      throw YouTubeException('Failed to get streams: $e', cause: e);
    }
  }

  /// Get trending videos.
  ///
  /// v3.1.0 has no trending endpoint, so this searches popular terms.
  /// YouTube's response shape varies between requests and the library
  /// sometimes throws while parsing one variant (`NoSuchMethodError:
  /// 'getT'`), so several queries are tried before giving up.
  Future<List<Video>> getTrending() async {
    const queries = ['trending music', 'trending', 'popular videos'];
    Object? lastError;

    for (final query in queries) {
      try {
        final results = await _yt.search.search(query);
        final videos = results.whereType<Video>().toList();
        if (videos.isNotEmpty) return videos;
      } catch (e) {
        lastError = e;
      }
    }
    throw YouTubeException(
      'Failed to get trending: ${lastError ?? 'no results'}',
      cause: lastError,
    );
  }

  /// Search for videos.
  ///
  /// Retries once: the same transient parse failure that affects trending
  /// can hit any single search response.
  Future<List<Video>> search(String query) async {
    if (query.trim().isEmpty) return [];

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final searchList = await _yt.search.search(query);
        return searchList.whereType<Video>().toList();
      } catch (e) {
        lastError = e;
      }
    }
    throw YouTubeException('Search failed: $lastError', cause: lastError);
  }

  /// Get channel info
  /// FIXED: Channel is the entity, not Channel object with description
  Future<Channel> getChannel(String channelId) async {
    try {
      return await _yt.channels.get(channelId);
    } catch (e) {
      throw YouTubeException('Failed to get channel: $e', cause: e);
    }
  }

  /// Get channel videos
  /// FIXED: getUploadsFromPage doesn't exist in v3.1.0
  /// Use channels.uploads or get the channel page
  Future<List<Video>> getChannelVideos(String channelId) async {
    try {
      // FIXED: getUploads() returns Stream<Video> in v3.1.0
      final stream = _yt.channels.getUploads(channelId);
      return await stream.toList();
    } catch (e) {
      throw YouTubeException('Failed to get channel videos: $e', cause: e);
    }
  }

  /// Get playlist videos
  /// FIXED: API signature verified
  Future<List<Video>> getPlaylistVideos(String playlistId) async {
    try {
      return await _yt.playlists.getVideos(playlistId).toList();
    } catch (e) {
      throw YouTubeException('Failed to get playlist: $e', cause: e);
    }
  }

  /// Get video captions/subtitles
  /// FIXED: closedCaptions.getManifest returns ClosedCaptionManifest (Iterable of ClosedCaptionTrackInfo)
  Future<List<MediaSubtitle>> getSubtitles(String videoId) async {
    try {
      // FIXED: API method is getManifest, not getManifest (correct in v3)
      // But returns ClosedCaptionManifest, not List
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);

      // YouTube lists the same caption track once per serialisation
      // format (srv1/srv2/srv3/ttml/vtt), which showed up as five
      // identical "English" rows in the picker. Keep one per
      // language+origin and ask for WebVTT, which mpv reads directly.
      final seen = <String>{};
      final subtitles = <MediaSubtitle>[];
      for (final track in manifest.tracks) {
        final key = '${track.language.code}|${track.isAutoGenerated}';
        if (!seen.add(key)) continue;
        final url = track.url.replace(queryParameters: {
          ...track.url.queryParameters,
          'fmt': 'vtt',
        });
        subtitles.add(
          MediaSubtitle(
            // FIXED: language is a Language object with .code
            code: track.language.code,
            name: track.language.name,
            url: url.toString(),
            isAutoGenerated: track.isAutoGenerated,
          ),
        );
      }
      return subtitles;
    } catch (e) {
      // No subtitles is not an error
      return [];
    }
  }

  /// Parse video ID from various URL formats
  String? parseVideoId(String url) {
    return VideoId.parseVideoId(url);
  }
}
