// ============================================================
// MediaItemRepositoryImpl - Implementation (FIXED: formats duplicate, dynamic types)
// ============================================================
// يطبّق contract للحصول على media item واحد بكل تفاصيله.
// ============================================================

import 'package:smarttube_poc/domain/entities/media_item.dart' as domain;
import 'package:smarttube_poc/domain/entities/media_format.dart' as domain;
import 'package:smarttube_poc/domain/entities/media_subtitle.dart';
import 'package:smarttube_poc/domain/entities/chapter_item.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart' show SponsorCategory, SponsorSegment;
import 'package:smarttube_poc/domain/repositories/media_item_repository.dart';
import 'package:smarttube_poc/core/utils/result.dart';
import 'package:smarttube_poc/core/errors/exceptions.dart';
import 'package:smarttube_poc/data/youtube/innertube_client.dart';
import 'package:smarttube_poc/data/youtube/stream_resolver.dart';
import 'package:smarttube_poc/data/sponsorblock/sponsorblock_service.dart';

class MediaItemRepositoryImpl implements MediaItemRepository {
  final InnerTubeClient _client;
  // ignore: unused_field - kept for future StreamResolver usage
  final StreamResolver? _streamResolver;
  final SponsorBlockService _sponsorBlockService;

  MediaItemRepositoryImpl(
    this._client, [
    StreamResolver? streamResolver,
    SponsorBlockService? sponsorBlockService,
  ])  : _streamResolver = streamResolver,
        _sponsorBlockService = sponsorBlockService ?? SponsorBlockService.create();

  @override
  Future<Result<domain.MediaItem>> getMediaItem(String videoId) async {
    try {
      // 1) Get basic video info
      var mediaItem = await _client.getVideo(videoId);

      // 2) Get streams ONCE (FIXED: previously called twice).
      // A live broadcast has none — the manifest parser throws on it —
      // and the player switches to HLS for those, so a failure here
      // must not sink the whole load.
      var streams = <domain.MediaFormat>[];
      try {
        streams = await _client.getStreams(videoId);
      } catch (e) {
        if (!mediaItem.isLive) rethrow;
      }

      // 3) Get subtitles
      final subtitles = await _client.getSubtitles(videoId);

      // 4) Get sponsor segments (parallel with above)
      final sponsorResult = await getSponsorSegments(videoId);
      final sponsorSegments = sponsorResult.dataOrNull ?? <SponsorSegment>[];

      // 5) Get play position from local DB (will be set elsewhere)

      // 5) Get play position from local DB (will be set elsewhere)
      // For now, we don't have access to local DB here. Return base item.
      // 6) Combine everything (FIXED: streams are already MediaFormatEntity)
      return Success(
        mediaItem.copyWith(
          formats: streams,
          subtitles: subtitles,
          chapters: mediaItem.chapters,
          sponsorSegments: sponsorSegments,
        ),
      );
    } on AppException catch (e) {
      return FailureResult.fromException(e);
    } catch (e) {
      return FailureResult(
        'Failed to load video: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<SponsorSegment>>> getSponsorSegments(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
    },
  }) async {
    try {
      // FIXED: call real SponsorBlock service
      final segments = await _sponsorBlockService.getSegments(
        videoId,
        categories: categories,
      );
      return Success(segments);
    } catch (e) {
      return FailureResult(
        'Failed to load sponsor segments: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<MediaSubtitle>>> getSubtitles(String videoId) async {
    try {
      final subtitles = await _client.getSubtitles(videoId);
      return Success(subtitles);
    } catch (e) {
      return FailureResult(
        'Failed to load subtitles: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<List<ChapterItem>>> getChapters(String videoId) async {
    try {
      final item = await _client.getVideo(videoId);
      return Success(item.chapters);
    } catch (e) {
      return FailureResult(
        'Failed to load chapters: $e',
        type: FailureType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<Result<void>> rateVideo(String videoId, VideoRating rating) async {
    return const FailureResult(
      'Rating not supported in PoC',
      type: FailureType.notFound,
    );
  }

  @override
  Future<Result<void>> setSubscription(String channelId, bool subscribe) async {
    return const FailureResult(
      'Subscriptions not supported in PoC',
      type: FailureType.notFound,
    );
  }
}
