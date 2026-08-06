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

import '../../domain/entities/channel_info.dart';
import '../../domain/entities/media_item.dart' as domain;
import '../../domain/entities/media_subtitle.dart';
import '../../domain/entities/media_format.dart' as fmt;
import '../../domain/entities/playlist_info.dart';
import '../../domain/repositories/content_repository.dart' show SearchFilters;
import '../../core/errors/exceptions.dart';
import 'channel_browse_client.dart';
import 'mappers/media_item_mapper.dart';
import 'search_filter_params.dart';

/// Alias for MediaFormat (to avoid import conflicts)
typedef MediaFormatEntity = fmt.MediaFormat;

/// One page of results plus the token that fetches the next one. A null
/// token means the feed is exhausted.
typedef VideoPage = ({List<Video> videos, String? nextPageToken});

/// A feed that has been opened and can be advanced.
///
/// youtube_explode models continuation as an object you keep and call
/// `nextPage()` on (or as a lazy stream), not as a token you can hand
/// back later. Repositories, though, speak in tokens. This bridges the
/// two: the open feed stays here and the caller gets an opaque handle.
class _Cursor {
  _Cursor(this._advance);

  final Future<List<Video>> Function() _advance;
  bool _exhausted = false;

  Future<List<Video>> next() async {
    if (_exhausted) return const [];
    final videos = await _advance();
    if (videos.isEmpty) _exhausted = true;
    return videos;
  }
}

class InnerTubeClient {
  final YoutubeExplode _yt;

  /// Signed-out InnerTube `browse`, for the two things the scraping API
  /// cannot answer: a channel's subscriber count and its playlists.
  /// Optional so a caller can construct this client without one; the
  /// methods that need it fall back to youtube_explode.
  final ChannelBrowseClient? _browse;

  InnerTubeClient(this._yt, [this._browse]);

  /// Open feeds, keyed by the token handed to callers. Bounded: a user
  /// only ever scrolls a handful of feeds at once, and dropping the
  /// oldest just means a stale "load more" starts over.
  final _cursors = <String, _Cursor>{};
  static const _maxCursors = 12;
  int _cursorSeq = 0;

  /// How many videos a stream-backed feed (playlists) yields per page.
  /// YouTube's own pages are 30 for playlists, 20 for search.
  static const _streamPageSize = 30;

  String _register(_Cursor cursor) {
    final token = 'ytc:${++_cursorSeq}';
    _cursors[token] = cursor;
    while (_cursors.length > _maxCursors) {
      _cursors.remove(_cursors.keys.first);
    }
    return token;
  }

  _Cursor _fromPagedList(BasePagedList<Video> first) {
    BasePagedList<Video>? current = first;
    return _Cursor(() async {
      final page = await current?.nextPage();
      current = page;
      return page?.toList() ?? const <Video>[];
    });
  }

  _Cursor _fromStream(Stream<Video> stream) {
    final iterator = StreamIterator(stream);
    return _Cursor(() async {
      final page = <Video>[];
      while (page.length < _streamPageSize && await iterator.moveNext()) {
        page.add(iterator.current);
      }
      if (page.length < _streamPageSize) await iterator.cancel();
      return page;
    });
  }

  /// The first page of [videos], with a token that continues it. The
  /// token stays valid across calls — the cursor behind it advances.
  VideoPage _openPage(List<Video> videos, _Cursor cursor) {
    if (videos.isEmpty) return (videos: videos, nextPageToken: null);
    return (videos: videos, nextPageToken: _register(cursor));
  }

  /// Advances the feed [pageToken] came from.
  ///
  /// Returns an empty page with no token when the feed is exhausted or
  /// the cursor has been evicted, which the caller reads as "no more".
  Future<VideoPage> continuePage(String pageToken) async {
    final cursor = _cursors[pageToken];
    if (cursor == null) return (videos: const <Video>[], nextPageToken: null);
    try {
      final videos = await cursor.next();
      return (
        videos: videos,
        nextPageToken: videos.isEmpty ? null : pageToken,
      );
    } catch (e) {
      throw YouTubeException('Failed to load more: $e', cause: e);
    }
  }

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
  Future<List<Video>> search(String query) async =>
      (await searchPage(query)).videos;

  /// One page of search results, with the token that continues it.
  ///
  /// [filters] is encoded into YouTube's `sp` parameter — upload date,
  /// type, duration and sort order all in one request.
  Future<VideoPage> searchPage(
    String query, {
    SearchFilters filters = const SearchFilters(),
    String? pageToken,
  }) async {
    if (pageToken != null) return continuePage(pageToken);
    if (query.trim().isEmpty) {
      return (videos: const <Video>[], nextPageToken: null);
    }

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final searchList = await _yt.search.search(
          query,
          filter: searchFilterFor(filters),
        );
        return _openPage(
          searchList.whereType<Video>().toList(),
          _fromPagedList(searchList),
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw YouTubeException('Search failed: $lastError', cause: lastError);
  }

  /// YouTube's own "up next" list for a video — the sidebar of the watch
  /// page, not a text search for the title.
  Future<VideoPage> relatedVideosPage(
    String videoId, {
    String? pageToken,
  }) async {
    if (pageToken != null) return continuePage(pageToken);
    try {
      final video = await _yt.videos.get(videoId);
      final related = await _yt.videos.getRelatedVideos(video);
      if (related == null) {
        return (videos: const <Video>[], nextPageToken: null);
      }
      return _openPage(related.toList(), _fromPagedList(related));
    } on VideoUnavailableException catch (e) {
      throw NotFoundException('Video $videoId unavailable: ${e.message}');
    } catch (e) {
      throw YouTubeException('Failed to get related videos: $e', cause: e);
    }
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

  /// A channel's avatar, banner and subscriber count.
  ///
  /// InnerTube first, youtube_explode second — not the other way round.
  /// The library reads the subscriber count out of
  /// `header/c4TabbedHeaderRenderer`, a renderer YouTube retired: every
  /// channel now ships `header/pageHeaderRenderer`, so
  /// `Channel.subscribersCount` and `Channel.bannerUrl` are null for
  /// every channel and have been for as long as this app has run. The
  /// browse response carries all of it in one JSON POST, instead of
  /// scraping a 1.5 MB HTML page.
  ///
  /// The library still backs it up, and fills any field the header
  /// happened not to carry.
  Future<ChannelInfo> getChannelInfo(String channelId) async {
    final browsed = await _browse?.getChannelInfo(channelId);
    if (browsed != null && browsed.subscriberCount != null) return browsed;

    try {
      final channel = await _yt.channels.get(channelId);
      return ChannelInfo(
        channelId: channelId,
        title: browsed?.title ?? channel.title,
        description: browsed?.description,
        avatarUrl: browsed?.avatarUrl ?? channel.logoUrl,
        bannerUrl: browsed?.bannerUrl ?? channel.bannerUrl,
        subscriberCount: browsed?.subscriberCount ?? channel.subscribersCount,
        videoCount: browsed?.videoCount,
      );
    } catch (e) {
      // The browse response is still a perfectly good answer when the
      // page scrape is the half that failed.
      if (browsed != null) return browsed;
      throw YouTubeException('Failed to get channel: $e', cause: e);
    }
  }

  /// The playlists a channel publishes.
  ///
  /// youtube_explode has no channel-playlists API at all — `ChannelClient`
  /// exposes uploads and nothing else — so this is InnerTube only, and
  /// returns an empty list rather than throwing when it cannot answer.
  Future<List<PlaylistInfo>> getChannelPlaylists(String channelId) async {
    return await _browse?.getChannelPlaylists(channelId) ?? const [];
  }

  /// One page of a channel's uploads.
  ///
  /// InnerTube first. youtube_explode's `getUploadsFromPage` still finds
  /// the right video ids, but YouTube moved the Videos tab to
  /// `lockupViewModel` and the library reads the retired renderer's
  /// paths, so every upload arrives with an empty title, a zero
  /// duration, no upload date and no view count — a page of blank cards.
  /// Its other path, the uploads playlist, now yields nothing at all.
  ///
  /// Both remain as fallbacks: if the browse is rate-limited or reshaped
  /// again, ids and thumbnails are still better than an error.
  Future<VideoPage> channelVideosPage(
    String channelId, {
    String? pageToken,
  }) async {
    if (pageToken != null) return continuePage(pageToken);

    final browse = _browse;
    if (browse != null) {
      try {
        final first = await browse.getChannelVideosPage(channelId);
        if (first != null && first.videos.isNotEmpty) {
          // The cursor carries the continuation forward; the channel's
          // name only appears in the first response, so it rides along.
          var continuation = first.continuation;
          final author = first.author;
          return _openPage(
            first.videos,
            _Cursor(() async {
              final token = continuation;
              if (token == null) return const <Video>[];
              final next = await browse.getChannelVideosPage(
                channelId,
                continuation: token,
                author: author,
              );
              continuation = next?.continuation;
              return next?.videos ?? const <Video>[];
            }),
          );
        }
      } catch (_) {
        // Fall through to the library.
      }
    }

    try {
      final uploads = await _yt.channels.getUploadsFromPage(channelId);
      if (uploads.isNotEmpty) {
        return _openPage(uploads.toList(), _fromPagedList(uploads));
      }
    } catch (_) {
      // The uploads *page* is scraped from the channel tab and YouTube
      // reshuffles it; the uploads *playlist* below is the older, duller
      // path that keeps working when the tab layout changes.
    }

    try {
      final cursor = _fromStream(_yt.channels.getUploads(channelId));
      return _openPage(await cursor.next(), cursor);
    } catch (e) {
      throw YouTubeException('Failed to get channel videos: $e', cause: e);
    }
  }

  /// Get channel videos (first page only; see [channelVideosPage]).
  Future<List<Video>> getChannelVideos(String channelId) async =>
      (await channelVideosPage(channelId)).videos;

  /// One page of a playlist's videos.
  Future<VideoPage> playlistVideosPage(
    String playlistId, {
    String? pageToken,
  }) async {
    if (pageToken != null) return continuePage(pageToken);
    try {
      final cursor = _fromStream(_yt.playlists.getVideos(playlistId));
      return _openPage(await cursor.next(), cursor);
    } catch (e) {
      throw YouTubeException('Failed to get playlist: $e', cause: e);
    }
  }

  /// Get playlist videos (first page only; see [playlistVideosPage]).
  Future<List<Video>> getPlaylistVideos(String playlistId) async =>
      (await playlistVideosPage(playlistId)).videos;

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
