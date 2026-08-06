// ============================================================
// AuthenticatedInnerTubeClient — signed-in YouTube requests
// ============================================================
// youtube_explode_dart has no notion of an account, so anything that
// depends on "who is watching" (real subscriptions, likes, subscribe)
// goes through InnerTube directly with an OAuth bearer token — the
// same approach SmartTube uses.
//
// Responses are walked recursively instead of by fixed paths: YouTube
// reshuffles its layout constantly, but the renderer objects
// themselves stay recognisable.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/media_item.dart';

/// One entry of the account's subscription list.
typedef SubscribedChannel = ({
  String channelId,
  String title,
  String? avatarUrl,
});

/// A playlist owned by (or saved to) the account.
typedef AccountPlaylist = ({
  String playlistId,
  String title,
  String? thumbnailUrl,
  int? videoCount,
});

/// A history entry: the video plus how far into it the account got, as
/// YouTube reports it on every surface.
typedef HistoryEntry = ({MediaItem item, int? percentWatched});

/// One section of YouTube's own sidebar, with the id that loads it.
typedef GuideEntry = ({String title, String browseId, String? iconType});

/// One page of a feed plus the continuation that fetches the next one.
typedef FeedPage = ({List<MediaItem> items, String? continuation});

class AuthenticatedInnerTubeClient {
  AuthenticatedInnerTubeClient(this._dio, this._accessToken, {String? locale})
      : _locale = locale ?? 'en';

  final Dio _dio;

  /// Resolves a fresh bearer token, or null when signed out.
  final Future<String?> Function() _accessToken;

  /// UI language. YouTube personalises recommendations by it, so sending
  /// the user's actual language is what makes the home feed resemble the
  /// official app instead of a generic US feed.
  final String _locale;

  static const _base = 'https://www.youtube.com/youtubei/v1';

  /// The TV client — the surface these OAuth tokens are issued for.
  Map<String, dynamic> get _context => {
        'client': {
          'clientName': 'TVHTML5',
          'clientVersion': '7.20250101.10.00',
          'hl': _locale,
          'gl': _locale == 'ar' ? 'SA' : 'US',
        },
      };

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _accessToken();
    if (token == null) {
      debugPrint('InnerTube $endpoint skipped: not signed in');
      return null;
    }
    debugPrint('InnerTube $endpoint: sending authenticated request');

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_base/$endpoint',
        data: {'context': _context, ...body},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Goog-Api-Format-Version': '1',
            // Identify as the TV surface these tokens belong to.
            'User-Agent': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version',
          },
          // InnerTube answers 4xx with a JSON body worth reading.
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 200) {
        debugPrint('InnerTube $endpoint -> ${response.statusCode}');
        return null;
      }
      return response.data;
    } on DioException catch (e) {
      debugPrint('InnerTube $endpoint failed: ${e.message}');
      return null;
    }
  }

  /// True while a token can be obtained — i.e. the account is usable.
  ///
  /// Callers that mirror an action to YouTube use this to tell "the
  /// request failed" apart from "there is no account to mirror to".
  Future<bool> isSignedIn() async => await _accessToken() != null;

  /// The signed-in user's subscription feed. Null when signed out or the
  /// request failed, so callers can fall back to the local list.
  Future<List<MediaItem>?> getSubscriptionsFeed() async {
    final page = await getSubscriptionsFeedPage();
    return page?.items;
  }

  /// One page of the subscription feed, with its continuation.
  Future<FeedPage?> getSubscriptionsFeedPage({String? continuation}) async {
    final data = await _post(
      'browse',
      continuation == null
          ? {'browseId': 'FEsubscriptions'}
          : {'continuation': continuation},
    );
    if (data == null) return null;
    final videos = _extractVideos(data);
    debugPrint('InnerTube subscriptions: ${videos.length} videos '
        '(response keys: ${data.keys.take(8).join(",")})');
    return (items: videos, continuation: _continuationToken(data));
  }

  /// The personalised home feed.
  ///
  /// One page is ~15 videos, which is a thin feed next to the official
  /// app. YouTube hands back a continuation token; following it a few
  /// times gets the feed to a comparable depth.
  Future<List<MediaItem>?> getHomeFeed({int pages = 3}) async {
    final first = await getHomeFeedPage();
    if (first == null) return null;

    final videos = first.items;
    var token = first.continuation;

    for (var page = 1; page < pages && token != null; page++) {
      final next = await getHomeFeedPage(continuation: token);
      if (next == null || next.items.isEmpty) break;
      final seen = videos.map((v) => v.videoId).toSet();
      videos.addAll(next.items.where((v) => seen.add(v.videoId)));
      token = next.continuation;
    }

    debugPrint('InnerTube home: ${videos.length} videos');
    return videos;
  }

  /// One page of the personalised home feed, with the continuation that
  /// fetches the next one. This is what an infinite feed scrolls on.
  Future<FeedPage?> getHomeFeedPage({String? continuation}) async {
    final data = await _post(
      'browse',
      continuation == null
          ? {'browseId': 'FEwhat_to_watch'}
          : {'continuation': continuation},
    );
    if (data == null) return null;
    return (
      items: _extractVideos(data),
      continuation: _continuationToken(data)
    );
  }

  /// The token that fetches the next page of a feed, wherever YouTube
  /// happens to have put it in this response shape.
  static String? _continuationToken(Map<String, dynamic> data) {
    String? token;
    _walk(data, (node) {
      if (token != null) return;
      for (final key in const [
        'continuationCommand',
        'nextContinuationData',
        'reloadContinuationData',
      ]) {
        final continuation = node[key];
        if (continuation is Map<String, dynamic>) {
          final value = continuation['token'] ?? continuation['continuation'];
          if (value is String && value.isNotEmpty) {
            token = value;
            return;
          }
        }
      }
    });
    return token;
  }

  /// The sections YouTube's own TV sidebar offers, in the account's
  /// language, each with the browse id that actually loads it.
  ///
  /// Searching for "live" or "sports" instead is not equivalent: those
  /// queries return shelf and live-badge renderers that the scraping
  /// search parser cannot read at all.
  Future<List<GuideEntry>?> getGuideEntries() async {
    final data = await _post('guide', const {});
    if (data == null) return null;

    final entries = <GuideEntry>[];
    final seen = <String>{};
    _walk(data, (node) {
      final guide = node['guideEntryRenderer'];
      if (guide is! Map<String, dynamic>) return;
      final endpoint = guide['navigationEndpoint'];
      if (endpoint is! Map) return;
      final browse = endpoint['browseEndpoint'];
      if (browse is! Map) return;
      final browseId = browse['browseId'];
      if (browseId is! String || !seen.add(browseId)) return;
      final title = _text(guide['formattedTitle']) ?? _text(guide['title']);
      if (title == null || title.trim().isEmpty) return;
      final icon = guide['icon'];
      entries.add((
        title: title,
        browseId: browseId,
        iconType: icon is Map ? icon['iconType'] as String? : null,
      ));
    });
    final summary = entries.map((e) => '${e.iconType}=${e.browseId}').join(' ');
    debugPrint('InnerTube guide: $summary');
    return entries;
  }

  /// The HLS playlist for a live stream.
  ///
  /// A live broadcast has no fixed-size file to fetch by byte range —
  /// it is a rolling playlist of segments. youtube_explode cannot get
  /// this at all (its manifest parser throws on live videos and its HLS
  /// helper rejects them), but the TV surface these tokens belong to is
  /// exactly the one YouTube serves HLS to.
  Future<String?> getLiveStreamUrl(String videoId) async {
    // Which client to ask matters more than anything else here.
    // Measured with tool/live_player_probe.dart on a live broadcast:
    //
    //   ANDROID  -> hlsManifestUrl + dashManifestUrl   ✅
    //   IOS      -> SABR only, no manifest
    //   WEB/MWEB -> UNPLAYABLE
    //   TVHTML5  -> LOGIN_REQUIRED / UNPLAYABLE ("reload the page")
    //
    // So live goes through the Android client, unauthenticated. The
    // signed-in TV client stays as a fallback in case that flips back.
    for (final android in [true, false]) {
      final data = await _playerResponse(videoId, asAndroid: android);
      if (data == null) continue;

      final streaming = data['streamingData'];
      if (streaming is! Map) {
        final status = data['playabilityStatus'];
        debugPrint('player $videoId (${android ? 'android' : 'tv'}): '
            'no streamingData; status='
            '${status is Map ? status['status'] : '?'} '
            '${status is Map ? status['reason'] ?? '' : ''}');
        continue;
      }
      // HLS first: ffmpeg handles it without a separate audio track.
      for (final key in const ['hlsManifestUrl', 'dashManifestUrl']) {
        final url = streaming[key];
        if (url is String && url.isNotEmpty) {
          debugPrint('player $videoId: $key via '
              '${android ? 'android' : 'tv'}');
          return url;
        }
      }
      debugPrint('player $videoId: streamingData without a manifest '
          '(${streaming.keys.join(",")})');
    }
    return null;
  }

  /// A player response, either from the Android client (no auth, still
  /// serves live manifests) or from the signed-in TV client.
  Future<Map<String, dynamic>?> _playerResponse(
    String videoId, {
    required bool asAndroid,
  }) async {
    if (!asAndroid) {
      return _post('player', {
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      });
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_base/player',
        data: {
          'context': {
            'client': {
              'clientName': 'ANDROID',
              'clientVersion': '20.10.38',
              'androidSdkVersion': 34,
              'osName': 'Android',
              'osVersion': '14',
              'hl': _locale,
              'gl': _locale == 'ar' ? 'SA' : 'US',
            },
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'com.google.android.youtube/20.10.38 '
                '(Linux; U; Android 14) gzip',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 200) {
        debugPrint('player(android) -> ${response.statusCode}');
        return null;
      }
      return response.data;
    } on DioException catch (e) {
      debugPrint('player(android) failed: ${e.message}');
      return null;
    }
  }

  /// Videos under an arbitrary browse id — the sidebar sections use this.
  Future<List<MediaItem>?> browseVideos(String browseId) async {
    final page = await browseVideosPage(browseId);
    return page?.items;
  }

  /// One page of an arbitrary browse id, with its continuation.
  Future<FeedPage?> browseVideosPage(
    String browseId, {
    String? continuation,
  }) async {
    final data = await _post(
      'browse',
      continuation == null
          ? {'browseId': browseId}
          : {'continuation': continuation},
    );
    if (data == null) return null;
    final videos = _extractVideos(data);
    debugPrint('InnerTube browse $browseId: ${videos.length} videos');
    return (items: videos, continuation: _continuationToken(data));
  }

  /// Search, through InnerTube rather than by scraping the results page.
  Future<List<MediaItem>?> search(String query, {String? params}) async {
    final page = await searchPage(query, params: params);
    return page?.items;
  }

  /// One page of search results, with its continuation.
  ///
  /// [params] is YouTube's `sp` filter value — the same protobuf the
  /// results page uses — so the signed-in path honours the same upload
  /// date / type / duration / sort filters as the scraped one.
  Future<FeedPage?> searchPage(
    String query, {
    String? params,
    String? continuation,
  }) async {
    final data = await _post('search', {
      if (continuation == null) 'query': query,
      if (continuation == null && params != null && params.isNotEmpty)
        'params': params,
      if (continuation != null) 'continuation': continuation,
    });
    if (data == null) return null;
    final videos = _extractVideos(data);
    debugPrint('InnerTube search "$query": ${videos.length} videos');
    return (items: videos, continuation: _continuationToken(data));
  }

  /// The channels the user actually subscribes to on YouTube.
  ///
  /// The TV surface has no endpoint that returns the subscription list:
  /// `guide` answers with navigation entries (Search, Home, topics) and
  /// `FEsubscriptions`'s avatar lockups are the filter chips ("All
  /// subscriptions", "Shorts"), not channels — which is why the Channels
  /// tab stayed empty however it was queried.
  ///
  /// What the subscriptions feed does carry is one tile per video, each
  /// with its channel's browse endpoint. Collecting the distinct
  /// channels out of the feed reconstructs the list, ordered by how
  /// recently each channel posted — which is a useful order in itself.
  Future<List<SubscribedChannel>?> getSubscribedChannels() async {
    final data = await _post('browse', const {'browseId': 'FEsubscriptions'});
    if (data == null) return null;

    // Prefer a real channel renderer when YouTube does send one.
    final direct = _extractChannels(data);
    if (direct.isNotEmpty) {
      debugPrint('InnerTube channels: ${direct.length} from renderers');
      return direct;
    }

    final channels = <SubscribedChannel>[];
    final seen = <String>{};
    _walk(data, (node) {
      final tile = node['tileRenderer'];
      if (tile is! Map<String, dynamic>) return;
      final channelId = _tileChannelId(tile);
      if (channelId == null || !seen.add(channelId)) return;
      final lines = _tileLines(
        (tile['metadata'] as Map<String, dynamic>?)?['tileMetadataRenderer'],
      );
      final title = lines.isNotEmpty ? lines.first : null;
      if (title == null || title.trim().isEmpty) return;
      channels.add((
        channelId: channelId,
        title: title,
        avatarUrl: _channelAvatarUrl(tile),
      ));
    });

    debugPrint('InnerTube channels: ${channels.length} from feed tiles');
    return channels;
  }

  /// The channel a tile belongs to: the first browse endpoint inside it
  /// that points at a channel.
  static String? _tileChannelId(Map<String, dynamic> tile) {
    String? found;
    _walk(tile, (node) {
      if (found != null) return;
      final id = _navigationChannelId(node['navigationEndpoint']) ??
          _navigationChannelId(node);
      if (id != null) found = id;
    });
    return found;
  }

  static List<SubscribedChannel> _extractChannels(Map<String, dynamic> data) {
    final channels = <SubscribedChannel>[];
    final seen = <String>{};

    void add(String? id, String? title, String? avatar) {
      if (id == null || !id.startsWith('UC') || !seen.add(id)) return;
      if (title == null || title.trim().isEmpty) return;
      channels.add((channelId: id, title: title, avatarUrl: avatar));
    }

    _walk(data, (node) {
      // The guide's own entry shape.
      final guide = node['guideEntryRenderer'];
      if (guide is Map<String, dynamic>) {
        add(
          _navigationChannelId(guide['navigationEndpoint']),
          _text(guide['formattedTitle']) ?? _text(guide['title']),
          _thumbnailUrl(guide['thumbnail']),
        );
        return;
      }
      // Grid/list channel renderers on the browse surfaces.
      for (final key in const [
        'gridChannelRenderer',
        'channelRenderer',
        'universalWatchCardRenderer',
      ]) {
        final renderer = node[key];
        if (renderer is! Map<String, dynamic>) continue;
        add(
          _string(renderer, ['channelId']) ??
              _navigationChannelId(renderer['navigationEndpoint']),
          _text(renderer['title']) ?? _text(renderer['displayName']),
          _thumbnailUrl(renderer['thumbnail']),
        );
      }
    });
    return channels;
  }

  // ============================================================
  // Playlists
  // ============================================================

  /// Playlists the account owns or saved, plus the two YouTube keeps
  /// implicitly (Liked videos, Watch later).
  Future<List<AccountPlaylist>?> getPlaylists() async {
    // YouTube has moved the library between these ids; try each until
    // one answers with playlists.
    const browseIds = [
      'FEplaylist_aggregation',
      'FEmy_youtube',
      'FElibrary',
    ];

    for (final browseId in browseIds) {
      final data = await _post('browse', {'browseId': browseId});
      if (data == null) continue;
      final playlists = _extractPlaylists(data);
      if (playlists.isNotEmpty) {
        debugPrint('InnerTube playlists: ${playlists.length} '
            'via $browseId');
        return playlists;
      }
    }
    return const [];
  }

  static List<AccountPlaylist> _extractPlaylists(Map<String, dynamic> data) {
    final playlists = <AccountPlaylist>[];
    final seen = <String>{};

    _walk(data, (node) {
      for (final key in const [
        'gridPlaylistRenderer',
        'playlistRenderer',
        'compactPlaylistRenderer',
        'tileRenderer',
      ]) {
        final renderer = node[key];
        if (renderer is! Map<String, dynamic>) continue;

        final id = _string(renderer, ['playlistId']) ??
            _browsePlaylistId(renderer['onSelectCommand']) ??
            _browsePlaylistId(renderer['navigationEndpoint']);
        if (id == null || !seen.add(id)) continue;

        final title =
            _text(renderer['title']) ?? _tileTitle(renderer['metadata']);
        if (title == null || title.trim().isEmpty) continue;

        playlists.add((
          playlistId: id,
          title: title,
          thumbnailUrl: _thumbnailUrl(renderer['thumbnail']),
          videoCount: _parseViews(
            _text(renderer['videoCountShortText']) ??
                _text(renderer['videoCountText']),
          ),
        ));
      }
    });
    return playlists;
  }

  /// The videos inside a playlist. Accepts a bare playlist id; YouTube
  /// browses playlists under a "VL" prefix.
  Future<List<MediaItem>?> getPlaylistVideos(String playlistId) async {
    final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final data = await _post('browse', {'browseId': browseId});
    if (data == null) return null;
    final videos = _extractVideos(data);
    debugPrint('InnerTube playlist $playlistId: ${videos.length} videos');
    return videos;
  }

  // ============================================================
  // Watch history
  // ============================================================

  /// The account's watch history, with how far into each video it got.
  ///
  /// This is what makes a video started on another device resumable
  /// here: YouTube attaches a resume overlay carrying the watched
  /// percentage to every history entry.
  Future<List<HistoryEntry>?> getHistory() async {
    final data = await _post('browse', const {'browseId': 'FEhistory'});
    if (data == null) return null;

    final entries = <HistoryEntry>[];
    final seen = <String>{};
    _walk(data, (node) {
      for (final key in _videoRendererKeys) {
        final renderer = node[key];
        if (renderer is! Map<String, dynamic>) continue;
        final item = key == 'tileRenderer'
            ? _fromTile(renderer)
            : _fromClassicRenderer(renderer);
        if (item == null || !seen.add(item.videoId)) continue;
        entries.add((item: item, percentWatched: _resumePercent(renderer)));
      }
    });
    debugPrint('InnerTube history: ${entries.length} entries');
    return entries;
  }

  /// The "how far you got" bar YouTube draws on a thumbnail, as a
  /// percentage. Present on history and continue-watching surfaces.
  static int? _resumePercent(Map<String, dynamic> renderer) {
    int? found;
    _walk(renderer, (node) {
      if (found != null) return;
      final resume = node['thumbnailOverlayResumePlaybackRenderer'];
      if (resume is Map<String, dynamic>) {
        final percent = resume['percentDurationWatched'];
        if (percent is int) found = percent;
        if (percent is num) found = percent.round();
      }
    });
    return found;
  }

  /// Reports the current playback position to YouTube so the same video
  /// resumes at this point in the official apps.
  ///
  /// This is the endpoint the web player uses; it is separate from
  /// InnerTube and takes query parameters rather than a JSON body.
  Future<bool> reportPosition({
    required String videoId,
    required Duration position,
    required Duration duration,
    required String cpn,
  }) async {
    final token = await _accessToken();
    if (token == null || duration <= Duration.zero) return false;

    final seconds = position.inMilliseconds / 1000.0;
    final total = duration.inMilliseconds / 1000.0;
    try {
      final response = await _dio.get<String>(
        'https://www.youtube.com/api/stats/watchtime',
        queryParameters: <String, dynamic>{
          'ns': 'yt',
          'el': 'detailpage',
          'ver': '2',
          'docid': videoId,
          'cpn': cpn,
          'len': total.toStringAsFixed(3),
          // `cmt` is the position YouTube stores as "resume here".
          'cmt': seconds.toStringAsFixed(3),
          'st': '0',
          'et': seconds.toStringAsFixed(3),
          'hl': _locale,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final ok = response.statusCode == 200 || response.statusCode == 204;
      debugPrint('watchtime $videoId @${seconds.toStringAsFixed(0)}s '
          '-> ${response.statusCode}');
      return ok;
    } on DioException catch (e) {
      debugPrint('watchtime failed: ${e.message}');
      return false;
    }
  }

  Future<bool> like(String videoId) => _action('like/like', {
        'target': {'videoId': videoId}
      });

  Future<bool> removeLike(String videoId) => _action('like/removelike', {
        'target': {'videoId': videoId}
      });

  Future<bool> dislike(String videoId) => _action('like/dislike', {
        'target': {'videoId': videoId}
      });

  Future<bool> subscribe(String channelId) =>
      _action('subscription/subscribe', {
        'channelIds': [channelId]
      });

  Future<bool> unsubscribe(String channelId) =>
      _action('subscription/unsubscribe', {
        'channelIds': [channelId]
      });

  Future<bool> _action(String endpoint, Map<String, dynamic> body) async {
    final data = await _post(endpoint, body);
    return data != null;
  }

  // ============================================================
  // Response walking
  // ============================================================

  /// Renderer wrappers that carry a video, across surfaces. The TV
  /// client (which these tokens belong to) uses `tileRenderer`; the
  /// others appear on web/mobile surfaces and cost nothing to support.
  static const _videoRendererKeys = [
    'tileRenderer',
    'videoRenderer',
    'gridVideoRenderer',
    'compactVideoRenderer',
    'richItemRenderer',
  ];

  /// Collects every video-like renderer in the response, in order.
  static List<MediaItem> _extractVideos(Map<String, dynamic> data) {
    final items = <MediaItem>[];
    final seen = <String>{};

    _walk(data, (node) {
      for (final key in _videoRendererKeys) {
        final renderer = node[key];
        if (renderer is! Map<String, dynamic>) continue;
        final item = key == 'tileRenderer'
            ? _fromTile(renderer)
            : _fromClassicRenderer(renderer);
        if (item != null && seen.add(item.videoId)) items.add(item);
      }
    });

    return items;
  }

  /// TV surface: id lives in the select command, text in a metadata
  /// renderer made of "lines" (channel, views, age).
  static MediaItem? _fromTile(Map<String, dynamic> tile) {
    // Shelves, channels and playlists are tiles too. Only a watch
    // endpoint proves this one is a video; contentId is accepted just
    // when it has the shape of a video id.
    final videoId = _watchEndpointVideoId(tile['onSelectCommand']) ??
        (_isVideoId(tile['contentId']) ? tile['contentId'] as String : null);
    if (videoId == null) return null;

    final metadata = tile['metadata'];
    final meta = metadata is Map<String, dynamic>
        ? metadata['tileMetadataRenderer']
        : null;
    if (meta is! Map<String, dynamic>) return null;

    final title = _text(meta['title']);
    if (title == null || title.isEmpty) return null;

    // Lines are localised and ordered differently per surface, so each
    // value is recognised by shape rather than by position.
    final lines = _tileLines(meta['lines']);
    final viewsLine = lines.firstWhere(_looksLikeViews, orElse: () => '');
    final ageLine = lines.firstWhere(_looksLikeAge, orElse: () => '');

    return MediaItem(
      videoId: videoId,
      title: title,
      author: lines.isNotEmpty ? lines.first : '',
      channelId: _tileChannelId(tile) ?? '',
      channelAvatarUrl: _channelAvatarUrl(tile),
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      duration: _parseDuration(_tileDuration(tile['header'])),
      publishedAt: _parseRelativeDate(ageLine),
      viewCount: viewsLine.isEmpty ? null : _parseViews(viewsLine),
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );
  }

  static bool _looksLikeViews(String text) {
    final lower = text.toLowerCase();
    return lower.contains('view') || text.contains('مشاهد');
  }

  static bool _looksLikeAge(String text) {
    final lower = text.toLowerCase();
    return lower.contains('ago') ||
        lower.contains('streamed') ||
        text.contains('قبل') ||
        text.contains('منذ');
  }

  /// Marks "upload date unknown" — before YouTube existed, so the UI can
  /// tell it apart from a genuinely fresh upload and omit the label.
  static final unknownDate = DateTime.utc(2000);

  /// "3 hours ago" / "قبل 3 ساعات" -> an approximate DateTime.
  static DateTime _parseRelativeDate(String text) {
    final now = DateTime.now();
    if (text.isEmpty) return unknownDate;

    final amount =
        int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '') ?? 0;
    if (amount == 0) return unknownDate;

    final lower = text.toLowerCase();
    final days = switch (lower) {
      _
          when lower.contains('year') ||
              text.contains('سنة') ||
              text.contains('سنوات') =>
        amount * 365,
      _
          when lower.contains('month') ||
              text.contains('شهر') ||
              text.contains('أشهر') =>
        amount * 30,
      _
          when lower.contains('week') ||
              text.contains('أسبوع') ||
              text.contains('أسابيع') =>
        amount * 7,
      _
          when lower.contains('day') ||
              text.contains('يوم') ||
              text.contains('أيام') =>
        amount,
      _ => 0,
    };
    if (days > 0) return now.subtract(Duration(days: days));

    if (lower.contains('hour') || text.contains('ساع')) {
      return now.subtract(Duration(hours: amount));
    }
    if (lower.contains('minute') || text.contains('دقيق')) {
      return now.subtract(Duration(minutes: amount));
    }
    return now;
  }

  /// Web/mobile surfaces: everything sits directly on the renderer.
  static MediaItem? _fromClassicRenderer(Map<String, dynamic> renderer) {
    // richItemRenderer just wraps another renderer.
    final inner = renderer['content'];
    if (inner is Map<String, dynamic>) {
      for (final key in _videoRendererKeys) {
        final nested = inner[key];
        if (nested is Map<String, dynamic>) {
          return key == 'tileRenderer'
              ? _fromTile(nested)
              : _fromClassicRenderer(nested);
        }
      }
      return null;
    }

    final videoId = renderer['videoId'];
    if (videoId is! String || videoId.isEmpty) return null;
    final title = _text(renderer['title']) ?? _text(renderer['headline']);
    if (title == null || title.isEmpty) return null;

    final byline = renderer['longBylineText'] ??
        renderer['shortBylineText'] ??
        renderer['ownerText'];

    return MediaItem(
      videoId: videoId,
      title: title,
      author: _text(byline) ?? '',
      channelId: _navigationChannelId(_firstRunEndpoint(byline)) ?? '',
      channelAvatarUrl: _channelAvatarUrl(renderer),
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      duration: _parseDuration(_text(renderer['lengthText'])),
      publishedAt: DateTime.now(),
      viewCount: _parseViews(_text(renderer['viewCountText']) ??
          _text(renderer['shortViewCountText'])),
      formats: const [],
      subtitles: const [],
      chapters: const [],
    );
  }

  static final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static bool _isVideoId(dynamic value) =>
      value is String && _videoIdPattern.hasMatch(value);

  static String? _watchEndpointVideoId(dynamic command) {
    if (command is! Map) return null;
    final watch = command['watchEndpoint'];
    if (watch is Map && _isVideoId(watch['videoId'])) {
      return watch['videoId'] as String;
    }
    return null;
  }

  /// Flattens tileMetadataRenderer.lines into plain strings. Accepts
  /// either the lines array or the renderer that holds it.
  static List<String> _tileLines(dynamic source) {
    final lines =
        source is Map && source['lines'] != null ? source['lines'] : source;
    if (lines is! List) return const [];
    final result = <String>[];
    for (final line in lines) {
      if (line is! Map) continue;
      final renderer = line['lineRenderer'];
      if (renderer is! Map) continue;
      final items = renderer['items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final itemRenderer = item['lineItemRenderer'];
        if (itemRenderer is! Map) continue;
        final text = _text(itemRenderer['text']);
        if (text != null && text.isNotEmpty) result.add(text);
      }
    }
    return result;
  }

  /// Duration badge from the tile header's thumbnail overlays.
  static String? _tileDuration(dynamic header) {
    if (header is! Map) return null;
    final renderer = header['tileHeaderRenderer'];
    if (renderer is! Map) return null;
    final overlays = renderer['thumbnailOverlays'];
    if (overlays is! List) return null;
    for (final overlay in overlays) {
      if (overlay is! Map) continue;
      final time = overlay['thumbnailOverlayTimeStatusRenderer'];
      if (time is Map) {
        final text = _text(time['text']);
        if (text != null) return text;
      }
    }
    return null;
  }

  /// Depth-first walk over every map in the tree.
  static void _walk(dynamic node, void Function(Map<String, dynamic>) visit) {
    if (node is Map<String, dynamic>) {
      visit(node);
      for (final value in node.values) {
        _walk(value, visit);
      }
    } else if (node is List) {
      for (final value in node) {
        _walk(value, visit);
      }
    }
  }

  /// InnerTube text is either {simpleText} or {runs:[{text}]}.
  static String? _text(dynamic node) {
    if (node is String) return node;
    if (node is! Map<String, dynamic>) return null;
    final simple = node['simpleText'];
    if (simple is String) return simple;
    final runs = node['runs'];
    if (runs is List) {
      return runs
          .whereType<Map<dynamic, dynamic>>()
          .map((run) => run['text'])
          .whereType<String>()
          .join();
    }
    return null;
  }

  static String? _string(Map<String, dynamic> node, List<String> keys) {
    for (final key in keys) {
      final value = node[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static dynamic _firstRunEndpoint(dynamic textNode) {
    if (textNode is! Map) return null;
    final runs = textNode['runs'];
    if (runs is! List || runs.isEmpty) return null;
    final first = runs.first;
    return first is Map ? first['navigationEndpoint'] : null;
  }

  /// The channel's avatar, when the renderer carries one.
  ///
  /// Only the keys that specifically mean "this channel's picture" are
  /// read — never the video thumbnail sitting next to them — so a
  /// renderer without an avatar yields null and the card falls back to
  /// the channel initial.
  static const _channelAvatarKeys = [
    'channelThumbnailSupportedRenderers',
    'channelThumbnailWithLinkRenderer',
    'channelThumbnail',
    'channelAvatar',
    'decoratedAvatarViewModel',
    'avatarViewModel',
    'avatar',
  ];

  static String? _channelAvatarUrl(Map<String, dynamic> renderer) {
    String? found;
    _walk(renderer, (node) {
      if (found != null) return;
      for (final key in _channelAvatarKeys) {
        final value = node[key];
        if (value == null) continue;
        // The avatar node is itself a wrapper on some surfaces, so look
        // for the image inside whatever this key holds.
        final url = _imageUrl(value) ??
            (value is Map<String, dynamic> ? _deepImageUrl(value) : null);
        if (url != null) {
          found = url;
          return;
        }
      }
    });
    return found;
  }

  /// The first image found anywhere under an avatar wrapper.
  static String? _deepImageUrl(Map<String, dynamic> node) {
    String? found;
    _walk(node, (child) {
      found ??= _imageUrl(child);
    });
    return found;
  }

  /// Largest image out of a node holding either `thumbnails` (classic
  /// renderers) or `sources` (the newer view models).
  static String? _imageUrl(dynamic node) {
    if (node is! Map) return null;
    if (node['thumbnails'] is List) return _thumbnailUrl(node);
    final sources = node['sources'];
    if (sources is List) return _thumbnailUrl({'thumbnails': sources});
    final image = node['image'];
    if (image is Map) return _imageUrl(image);
    return null;
  }

  /// Largest thumbnail out of a `{thumbnails:[{url,width}]}` node.
  static String? _thumbnailUrl(dynamic node) {
    if (node is! Map) return null;
    final thumbnails = node['thumbnails'];
    if (thumbnails is! List || thumbnails.isEmpty) return null;
    String? best;
    var bestWidth = -1;
    for (final entry in thumbnails) {
      if (entry is! Map) continue;
      final url = entry['url'];
      if (url is! String || url.isEmpty) continue;
      final width = entry['width'];
      final value = width is num ? width.toInt() : 0;
      if (value >= bestWidth) {
        bestWidth = value;
        best = url.startsWith('//') ? 'https:$url' : url;
      }
    }
    return best;
  }

  /// Playlist id out of a browse endpoint, with the "VL" prefix removed.
  static String? _browsePlaylistId(dynamic endpoint) {
    if (endpoint is! Map) return null;
    final watch = endpoint['watchEndpoint'];
    if (watch is Map) {
      final id = watch['playlistId'];
      if (id is String && id.isNotEmpty) return id;
    }
    final browse = endpoint['browseEndpoint'];
    if (browse is Map) {
      final id = browse['browseId'];
      if (id is String && id.startsWith('VL')) return id.substring(2);
    }
    return null;
  }

  /// Title out of a tile's metadata renderer.
  static String? _tileTitle(dynamic metadata) {
    if (metadata is! Map) return null;
    final renderer = metadata['tileMetadataRenderer'];
    if (renderer is! Map) return null;
    return _text(renderer['title']);
  }

  static String? _navigationChannelId(dynamic endpoint) {
    if (endpoint is! Map) return null;
    final browse = endpoint['browseEndpoint'];
    if (browse is Map) {
      final id = browse['browseId'];
      if (id is String && id.startsWith('UC')) return id;
    }
    return null;
  }

  /// "12:34" / "1:02:03" -> Duration.
  static Duration _parseDuration(String? text) {
    if (text == null) return Duration.zero;
    final parts = text.split(':').reversed.toList();
    var seconds = 0;
    for (var i = 0; i < parts.length && i < 3; i++) {
      final value = int.tryParse(parts[i].trim()) ?? 0;
      seconds += value * [1, 60, 3600][i];
    }
    return Duration(seconds: seconds);
  }

  /// "1,234,567 views" -> 1234567, "258K views" / "258 ألف مشاهدة" ->
  /// 258000. YouTube abbreviates in the viewer's locale, so the
  /// multiplier has to be read from the text, not just the digits.
  static int? _parseViews(String? text) {
    if (text == null) return null;

    final match = RegExp(r'([\d.,]+)').firstMatch(text);
    if (match == null) return null;
    final number = double.tryParse(
      match.group(1)!.replaceAll(',', '').trim(),
    );
    if (number == null) return null;

    final multiplier = switch (text) {
      _ when text.contains('ألف') || RegExp('[0-9]\\s*[Kk]').hasMatch(text) =>
        1000,
      _ when text.contains('مليون') || RegExp('[0-9]\\s*[Mm]').hasMatch(text) =>
        1000000,
      _ when text.contains('مليار') || RegExp('[0-9]\\s*[Bb]').hasMatch(text) =>
        1000000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }
}
