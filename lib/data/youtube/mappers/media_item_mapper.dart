// ============================================================
// MediaItemMapper - DTO → Entity (FIXED for youtube_explode_dart v3.1.0)
// ============================================================
// Based on actual API:
//   - Video: id (VideoId), title, author, channelId, uploadDate, description, duration, isLive
//   - StreamInfo mixin: videoId, tag, url, container (StreamContainer), size (FileSize),
//                       bitrate (Bitrate), fragments, codec (MediaType), qualityLabel
//   - VideoStreamInfo mixin adds: videoCodec, videoQuality, videoResolution, framerate
//   - AudioStreamInfo mixin adds: audioCodec, audioTrack
//   - MuxedStreamInfo implements BOTH (use 'is' check correctly)
//   - MediaType is from http_parser (not String)
//   - Framerate is Framerate object (not double)
//   - VideoResolution has width, height (from streams/models/video_resolution.dart)
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../domain/entities/media_item.dart' as domain;
import '../../../domain/entities/media_format.dart' as fmt;
import '../../../domain/entities/chapter_item.dart';

class MediaItemMapper {
  /// Convert youtube_explode Video → MediaItem
  ///
  /// [channelAvatarUrl] is passed by callers that already know whose
  /// channel this is (a channel page, a subscription). The scraped
  /// search and playlist payloads carry no avatar at all, so for those
  /// it stays null rather than being guessed at.
  static domain.MediaItem fromVideo(Video video, {String? channelAvatarUrl}) {
    return domain.MediaItem(
      videoId: video.id.value,
      title: video.title,
      description: video.description,
      author: video.author,
      channelId: video.channelId.value,
      channelTitle: video.author,
      channelAvatarUrl: channelAvatarUrl,
      duration: video.duration ?? Duration.zero,
      // FIXED: uploadDate is DateTime in v3
      publishedAt: video.uploadDate ?? DateTime.now(),
      // FIXED: ThumbnailSet API
      // maxResUrl 404s for most videos (only uploads with a 1280x720+
      // source have it), so prefer the sizes YouTube always generates.
      thumbnailUrl: video.thumbnails.highResUrl,
      formats: const [],
      subtitles: const [],
      chapters: _extractChaptersFromDescription(video.description),
      isLive: video.isLive,
      viewCount: _viewCount(video),
    );
  }

  /// View count from the library's [Engagement] block.
  ///
  /// `Engagement.viewCount` is non-nullable, and the surfaces that carry
  /// no view count at all (playlist pages, some channel upload rows)
  /// construct it as `Engagement(0, null, null)` rather than leaving it
  /// out. Printing "0 views" under every card of such a feed is worse
  /// than printing nothing, so zero is read as "not reported" — the
  /// difference only matters for a genuinely brand-new upload, where the
  /// card simply falls back to the upload date.
  static int? _viewCount(Video video) {
    final views = video.engagement.viewCount;
    return views > 0 ? views : null;
  }

  /// Extract chapter timestamps from video description
  /// (e.g., "0:00 Intro\n1:23 Main Topic\n5:42 Conclusion")
  static List<ChapterItem> _extractChaptersFromDescription(
      String? description) {
    if (description == null || description.isEmpty) return const [];

    final regex = RegExp(
      r'^(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)$',
      multiLine: true,
    );

    return regex.allMatches(description).map((match) {
      final timeStr = match.group(1)!;
      final title = match.group(2)!.trim();

      return ChapterItem(
        title: title,
        start: _parseTimeString(timeStr),
      );
    }).toList();
  }

  static Duration _parseTimeString(String timeStr) {
    final parts = timeStr.split(':').map(int.parse).toList();
    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    return Duration.zero;
  }

  /// Convert StreamInfo → MediaFormat
  /// FIXED: handle all stream types with correct mixin checks
  static fmt.MediaFormat fromStream(StreamInfo stream) {
    // FIXED: use mixin checks (MuxedStreamInfo implements BOTH)
    final isMuxed = stream is MuxedStreamInfo;
    final isAudioOnly = stream is AudioStreamInfo && !isMuxed;
    final videoStream = stream is VideoStreamInfo ? stream : null;
    final audioStream = stream is AudioStreamInfo ? stream : null;

    return fmt.MediaFormat(
      // FIXED: tag is int, formatId in our entity is String
      formatId: stream.tag.toString(),
      url: stream.url.toString(),
      qualityLabel: videoStream?.qualityLabel,
      // FIXED: VideoResolution has .width, .height
      width: videoStream?.videoResolution.width,
      height: videoStream?.videoResolution.height,
      // FIXED: Framerate.framesPerSecond is num (not double)
      fps: videoStream?.framerate.framesPerSecond.toDouble(),
      // FIXED: MediaType (http_parser) only has type, subtype, parameters
      mimeType: stream.codec.mimeType,
      // Use type+subtype as codec identifier (e.g., "video/mp4")
      codec: '${stream.codec.type}/${stream.codec.subtype}',
      // FIXED: bitrate is Bitrate object with .bitsPerSecond
      bitrate: stream.bitrate.bitsPerSecond ~/ 1000,
      isAudioOnly: isAudioOnly,
      audioCodec: audioStream?.audioCodec,
      audioBitrate: audioStream?.bitrate.bitsPerSecond != null
          ? audioStream!.bitrate.bitsPerSecond ~/ 1000
          : null,
    );
  }

  /// Create MediaItem with formats populated
  static domain.MediaItem withFormats(
    domain.MediaItem item,
    List<fmt.MediaFormat> formats,
  ) {
    return item.copyWith(formats: formats);
  }
}
