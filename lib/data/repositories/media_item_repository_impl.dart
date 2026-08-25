// ============================================================
// MediaItemRepositoryImpl - Implementation (FIXED: formats duplicate, dynamic types)
// ============================================================
// يطبّق contract للحصول على media item واحد بكل تفاصيله.
// ============================================================

import 'package:smarttube_poc/domain/entities/media_item.dart' as domain;
import 'package:smarttube_poc/domain/entities/media_subtitle.dart';
import 'package:smarttube_poc/domain/entities/chapter_item.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart'
    show SponsorCategory, SponsorSegment;
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

  /// Resolves the categories to ask SponsorBlock for at call time, so a
  /// settings change takes effect on the next video without rebuilding
  /// the repository. Null falls back to the parameter defaults.
  final Set<SponsorCategory> Function()? _sponsorCategories;

  MediaItemRepositoryImpl(
    this._client, [
    StreamResolver? streamResolver,
    SponsorBlockService? sponsorBlockService,
    Set<SponsorCategory> Function()? sponsorCategories,
  ])  : _streamResolver = streamResolver,
        _sponsorBlockService =
            sponsorBlockService ?? SponsorBlockService.create(),
        _sponsorCategories = sponsorCategories;

  @override
  Future<Result<domain.MediaItem>> getMediaItem(String videoId) async {
    try {
      // Only this one has to finish before the others can start: the
      // channel lookup needs `channelId`, and nothing else is known yet.
      final mediaItem = await _client.getVideo(videoId);

      // The stream manifest is deliberately NOT fetched here.
      //
      // It used to be, to fill `MediaItem.formats` — a field nothing
      // reads. Its only consumer was the `GetVideoStreamUrl` usecase,
      // which no screen ever called. Playback resolves its own manifest
      // through StreamResolver, so this was the single most expensive
      // call in the app (7–8.5s measured) paying for a result that was
      // thrown away, and on a live broadcast it was 8s spent on a parse
      // that is *expected* to fail.
      //
      // Everything below is decoration: subtitles, the channel's avatar
      // and subscriber count, sponsor segments. None of it gates
      // playback, so all three run concurrently instead of end to end.
      final subtitlesFuture = _client
          .getSubtitles(videoId)
          // Subtitles are optional. Letting this throw used to fail the
          // entire video load over a caption track.
          .catchError((_) => <MediaSubtitle>[]);
      final channelFuture = _channelDetails(mediaItem);
      final categories = _sponsorCategories?.call();
      final sponsorFuture = categories == null
          ? getSponsorSegments(videoId)
          : getSponsorSegments(videoId, categories: categories);

      final subtitles = await subtitlesFuture;
      final channel = await channelFuture;
      final sponsorSegments =
          (await sponsorFuture).dataOrNull ?? <SponsorSegment>[];

      return Success(
        mediaItem.copyWith(
          subtitles: subtitles,
          chapters: mediaItem.chapters,
          sponsorSegments: sponsorSegments,
          channelAvatarUrl: channel.$1 ?? mediaItem.channelAvatarUrl,
          subscriberCount: channel.$2 ?? mediaItem.subscriberCount,
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

  /// The channel's avatar and subscriber count, or nulls.
  ///
  /// youtube_explode reads `subscribersCount` out of
  /// `c4TabbedHeaderRenderer`, a renderer YouTube retired in favour of
  /// `pageHeaderRenderer`, so the field is null for every channel today.
  /// `getChannelInfo` reads the current header instead. Best effort — a
  /// video is perfectly watchable without either.
  Future<(String?, int?)> _channelDetails(domain.MediaItem item) async {
    if (item.channelId.isEmpty) return (null, null);
    try {
      final channel = await _client.getChannelInfo(item.channelId);
      return (channel.avatarUrl, channel.subscriberCount);
    } catch (_) {
      // Leave both null rather than guess at a URL.
      return (null, null);
    }
  }

  @override
  Future<Result<List<SponsorSegment>>> getSponsorSegments(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
      SponsorCategory.highlight,
      SponsorCategory.exclusiveAccess,
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
