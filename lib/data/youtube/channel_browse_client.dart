// ============================================================
// ChannelBrowseClient — signed-out InnerTube `browse` for channels
// ============================================================
// Two things the vendored youtube_explode_dart cannot give us:
//
//   1. A subscriber count. Its channel-page parser reads
//      `header/c4TabbedHeaderRenderer/subscriberCountText`, a renderer
//      YouTube retired — every channel page now ships
//      `header/pageHeaderRenderer` instead, so `Channel.subscribersCount`
//      (and `bannerUrl`) come back null for every channel. The watch
//      page's channel row therefore never had a number to show.
//
//   2. A channel's playlists. `ChannelClient` exposes uploads and
//      nothing else; there is no playlists tab anywhere in the library.
//
//   3. A channel's uploads with anything on them. `getUploadsFromPage`
//      still returns the right video ids, but YouTube moved the Videos
//      tab to `lockupViewModel` and the library's parser reads the old
//      renderer's paths: every upload comes back with an empty title, a
//      zero duration, no upload date and zero views. The uploads
//      *playlist* fallback (`getUploads`) now yields nothing at all. So
//      the same browse call that answers 1 and 2 answers this too, and
//      hands back real `Video` objects the rest of the app already
//      knows how to map.
//
// Both are one InnerTube `browse` call away, and `YoutubeHttpClient`
// already exposes `sendPost('browse', ...)` — the unauthenticated WEB
// request its own paging uses, with the library's retry, headers and
// cookie handling. That is what this reuses, so nothing here has to
// duplicate the transport.
//
// Everything is best effort: a null return means "ask the library
// instead", never "this channel is broken".
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show ChannelId, Engagement, ThumbnailSet, Video, VideoId, YoutubeHttpClient;

import '../../domain/entities/channel_info.dart';
import '../../domain/entities/playlist_info.dart';

/// One page of a channel's uploads: the videos, the token that continues
/// them, and the channel's own name (only the first response carries it,
/// so callers thread it back through the continuations).
typedef ChannelVideoPage = ({
  List<Video> videos,
  String? continuation,
  String? author,
});

class ChannelBrowseClient {
  ChannelBrowseClient(this._http);

  final YoutubeHttpClient _http;

  /// The `params` value YouTube's own channel page sends for its
  /// Playlists tab. It is the tab's browse endpoint, taken verbatim from
  /// the tab list of a channel browse response.
  ///
  /// The shorter legacy value (`EglwbGF5bGlzdHM=`) is silently ignored
  /// today: the response comes back as the channel's Home tab instead,
  /// which is why this is the long form.
  static const _playlistsTabParams = 'EglwbGF5bGlzdHPyBgQKAkIA';

  /// The same, for the Videos tab.
  static const _videosTabParams = 'EgZ2aWRlb3PyBgQKAjoA';

  /// Channel metadata from the new page header. Null when the request
  /// failed or the response carried no recognisable header.
  Future<ChannelInfo?> getChannelInfo(String channelId) async {
    if (channelId.isEmpty) return null;
    final data = await _browse(channelId);
    if (data == null) return null;

    final header = _pageHeader(data);
    if (header == null) return null;

    final title = _string(header['pageTitle']) ??
        _viewModelText(
          _at(header, ['content', 'pageHeaderViewModel', 'title']),
        );
    if (title == null || title.isEmpty) return null;

    final view = _at(header, ['content', 'pageHeaderViewModel']);
    if (view is! Map) return null;

    // The metadata block is a flat list of localised strings —
    // "@handle", "2.67M subscribers", "6K videos" — in an order that
    // varies by channel, so each is recognised by shape.
    final parts = _metadataParts(view['metadata']);

    return ChannelInfo(
      channelId: channelId,
      title: title,
      // The header only carries a two-line preview ending in "...more";
      // the metadata block carries the whole thing, which is what the
      // About tab wants.
      description: _string(
        _at(data, ['metadata', 'channelMetadataRenderer', 'description']),
      ),
      avatarUrl: _largestImage(
        _at(view, [
              'image',
              'decoratedAvatarViewModel',
              'avatar',
              'avatarViewModel',
              'image',
            ]) ??
            _at(view, ['image', 'avatarViewModel', 'image']),
      ),
      bannerUrl:
          _largestImage(_at(view, ['banner', 'imageBannerViewModel', 'image'])),
      subscriberCount: _firstCount(parts, _looksLikeSubscribers),
      videoCount: _firstCount(parts, _looksLikeVideos),
    );
  }

  /// The playlists a channel publishes, in the order its Playlists tab
  /// lists them. Empty when the channel has none; empty (not an error)
  /// when the request failed, so the tab degrades to its empty state.
  Future<List<PlaylistInfo>> getChannelPlaylists(String channelId) async {
    if (channelId.isEmpty) return const [];
    final data = await _browse(channelId, params: _playlistsTabParams);
    if (data == null) return const [];

    final playlists = <PlaylistInfo>[];
    final seen = <String>{};

    _walk(data, (node) {
      // Current surface: every playlist is a lockup keyed by contentId.
      final lockup = node['lockupViewModel'];
      if (lockup is Map<String, dynamic>) {
        final entry = _fromLockup(lockup, channelId);
        if (entry != null && seen.add(entry.playlistId)) playlists.add(entry);
      }
      // Older grid/list renderers, still served to some clients.
      for (final key in const ['gridPlaylistRenderer', 'playlistRenderer']) {
        final renderer = node[key];
        if (renderer is! Map<String, dynamic>) continue;
        final entry = _fromRenderer(renderer, channelId);
        if (entry != null && seen.add(entry.playlistId)) playlists.add(entry);
      }
    });

    return playlists;
  }

  /// One page of a channel's uploads, as the `Video` objects the rest of
  /// the app already maps. Null when the request failed or the response
  /// held no uploads, so the caller can fall back to youtube_explode.
  ///
  /// [author] is threaded back in on continuations: only the first
  /// response carries the channel's name, and every card wants it.
  Future<ChannelVideoPage?> getChannelVideosPage(
    String channelId, {
    String? continuation,
    String? author,
  }) async {
    if (channelId.isEmpty) return null;
    final data = continuation != null
        ? await _continue(continuation)
        : await _browse(channelId, params: _videosTabParams);
    if (data == null) return null;

    final name = author ??
        _string(
          _at(data, ['metadata', 'channelMetadataRenderer', 'title']),
        ) ??
        '';

    final videos = <Video>[];
    final seen = <String>{};

    _walk(data, (node) {
      final lockup = node['lockupViewModel'];
      if (lockup is! Map<String, dynamic>) return;
      final video = _videoFromLockup(lockup, channelId, name);
      if (video != null && seen.add(video.id.value)) videos.add(video);
    });

    if (videos.isEmpty) return null;
    return (
      videos: videos,
      continuation: _continuationToken(data),
      author: name,
    );
  }

  static Video? _videoFromLockup(
    Map<String, dynamic> lockup,
    String channelId,
    String author,
  ) {
    if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') return null;
    final id = _string(lockup['contentId']);
    if (id == null) return null;

    final metadata = _at(lockup, ['metadata', 'lockupMetadataViewModel']);
    if (metadata is! Map<String, dynamic>) return null;
    final title = _viewModelText(metadata['title']);
    if (title == null || title.isEmpty) return null;

    // One flat list of localised strings, whose order varies and whose
    // members are optional — a members-only upload has an age and no
    // view count at all — so each is recognised by shape.
    final parts = _metadataParts(metadata['metadata']);
    final views = _firstCount(parts, _looksLikeViews);
    final age = parts.firstWhere(_looksLikeAge, orElse: () => '');

    return Video(
      VideoId(id),
      title,
      author,
      ChannelId(channelId),
      _parseRelativeDate(age),
      age.isEmpty ? null : age,
      null,
      '',
      _parseDuration(_durationBadge(lockup)),
      ThumbnailSet(id),
      null,
      // The library's own surfaces use 0 for "not reported"; the mapper
      // reads it back as null rather than printing "0 views".
      Engagement(views ?? 0, null, null),
      false,
    );
  }

  /// "13:48" from the badge overlaid on the thumbnail.
  static String? _durationBadge(Map<String, dynamic> lockup) {
    String? found;
    _walk(lockup['contentImage'], (node) {
      if (found != null) return;
      final badge = node['thumbnailBadgeViewModel'];
      if (badge is! Map<String, dynamic>) return;
      final text = _string(badge['text']);
      if (text != null && _timestampPattern.hasMatch(text)) found = text;
    });
    return found;
  }

  static final _timestampPattern = RegExp(r'^\d{1,3}(:\d{2})+$');

  static Duration _parseDuration(String? text) {
    if (text == null) return Duration.zero;
    final parts = text.split(':').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return Duration.zero;
    final values = parts.cast<int>();
    return switch (values.length) {
      2 => Duration(minutes: values[0], seconds: values[1]),
      3 => Duration(hours: values[0], minutes: values[1], seconds: values[2]),
      _ => Duration.zero,
    };
  }

  static bool _looksLikeViews(String text) =>
      text.toLowerCase().contains('view') || text.contains('مشاهد');

  static bool _looksLikeAge(String text) {
    final lower = text.toLowerCase();
    return lower.contains('ago') ||
        lower.contains('streamed') ||
        text.contains('قبل') ||
        text.contains('منذ');
  }

  /// "3 hours ago" / "قبل ٣ ساعات" -> an approximate DateTime. Null when
  /// the string says nothing usable, which the mapper reads as unknown.
  static DateTime? _parseRelativeDate(String text) {
    if (text.isEmpty) return null;
    final amount = _parseCount(text);
    if (amount == null || amount == 0) return null;

    final lower = text.toLowerCase();
    final days = switch (lower) {
      _ when lower.contains('year') || text.contains('سن') => amount * 365,
      _
          when lower.contains('month') ||
              text.contains('شهر') ||
              text.contains('أشهر') =>
        amount * 30,
      _ when lower.contains('week') || text.contains('أسب') => amount * 7,
      _
          when lower.contains('day') ||
              text.contains('يوم') ||
              text.contains('أيام') =>
        amount,
      _ => 0,
    };
    final now = DateTime.now();
    if (days > 0) return now.subtract(Duration(days: days));
    if (lower.contains('hour') || text.contains('ساع')) {
      return now.subtract(Duration(hours: amount));
    }
    if (lower.contains('minute') || text.contains('دقيق')) {
      return now.subtract(Duration(minutes: amount));
    }
    return null;
  }

  /// The token that continues a feed, wherever this response shape put
  /// it. Null means the feed is exhausted.
  static String? _continuationToken(Map<String, dynamic> data) {
    String? token;
    _walk(data, (node) {
      if (token != null) return;
      final command = node['continuationCommand'];
      if (command is Map<String, dynamic>) {
        final value = _string(command['token']);
        if (value != null) token = value;
      }
    });
    return token;
  }

  Future<Map<String, dynamic>?> _continue(String continuation) async {
    try {
      return await _http.sendPost('browse', {'continuation': continuation});
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _browse(
    String browseId, {
    String? params,
  }) async {
    try {
      final data = await _http.sendPost('browse', {
        'browseId': browseId,
        if (params != null) 'params': params,
      });
      return data;
    } catch (_) {
      // YouTube rate-limits and reshuffles; neither is worth failing a
      // channel page over.
      return null;
    }
  }

  // ============================================================
  // Playlist renderers
  // ============================================================

  static PlaylistInfo? _fromLockup(
    Map<String, dynamic> lockup,
    String channelId,
  ) {
    final id = _string(lockup['contentId']);
    // Videos and shorts are lockups too; a playlist id is the only thing
    // that proves this one is a playlist.
    if (id == null || !_isPlaylistId(id)) return null;

    final metadata = _at(lockup, ['metadata', 'lockupMetadataViewModel']);
    final title = _viewModelText(metadata is Map ? metadata['title'] : null);
    if (title == null || title.isEmpty) return null;

    return PlaylistInfo(
      playlistId: id,
      title: title,
      channelId: channelId,
      thumbnailUrl: _largestImage(
        _at(lockup, [
          'contentImage',
          'collectionThumbnailViewModel',
          'primaryThumbnail',
          'thumbnailViewModel',
          'image',
        ]),
      ),
      videoCount: _parseCount(_badgeText(lockup)),
    );
  }

  static PlaylistInfo? _fromRenderer(
    Map<String, dynamic> renderer,
    String channelId,
  ) {
    final id = _string(renderer['playlistId']);
    if (id == null || id.isEmpty) return null;
    final title = _runsText(renderer['title']);
    if (title == null || title.isEmpty) return null;

    return PlaylistInfo(
      playlistId: id,
      title: title,
      channelId: channelId,
      thumbnailUrl: _largestImage(renderer['thumbnail']),
      videoCount: _parseCount(
        _runsText(renderer['videoCountShortText']) ??
            _runsText(renderer['videoCountText']),
      ),
    );
  }

  /// "16 videos" from a lockup's thumbnail overlay badge.
  static String? _badgeText(Map<String, dynamic> lockup) {
    String? found;
    _walk(lockup, (node) {
      if (found != null) return;
      final badge = node['thumbnailBadgeViewModel'];
      if (badge is Map<String, dynamic>) found = _string(badge['text']);
    });
    return found;
  }

  // ============================================================
  // Header metadata
  // ============================================================

  static Map<String, dynamic>? _pageHeader(Map<String, dynamic> data) {
    final header = data['header'];
    if (header is! Map) return null;
    final page = header['pageHeaderRenderer'];
    return page is Map<String, dynamic> ? page : null;
  }

  /// Flattens contentMetadataViewModel.metadataRows[].metadataParts[]
  /// into the plain strings they render as.
  static List<String> _metadataParts(dynamic metadata) {
    final view = _at(metadata, ['contentMetadataViewModel']);
    if (view is! Map) return const [];
    final rows = view['metadataRows'];
    if (rows is! List) return const [];

    final parts = <String>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final items = row['metadataParts'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final text = _viewModelText(item['text']);
        if (text != null && text.isNotEmpty) parts.add(text);
      }
    }
    return parts;
  }

  static int? _firstCount(List<String> parts, bool Function(String) matches) {
    for (final part in parts) {
      if (matches(part)) {
        final count = _parseCount(part);
        if (count != null) return count;
      }
    }
    return null;
  }

  static bool _looksLikeSubscribers(String text) =>
      text.toLowerCase().contains('subscriber') || text.contains('مشترك');

  static bool _looksLikeVideos(String text) =>
      text.toLowerCase().contains('video') || text.contains('فيديو');

  // ============================================================
  // Shared JSON helpers
  // ============================================================

  /// "2.67M subscribers" / "16 videos" / "١٦ فيديو" -> a number.
  ///
  /// Arabic-Indic digits are normalised first: YouTube returns them
  /// whenever the request carries an Arabic locale, and the app ships in
  /// Arabic.
  static int? _parseCount(String? text) {
    if (text == null || text.isEmpty) return null;

    final normalised = String.fromCharCodes([
      for (final unit in text.runes)
        if (unit >= 0x0660 && unit <= 0x0669)
          unit - 0x0660 + 0x30
        else if (unit >= 0x06F0 && unit <= 0x06F9)
          unit - 0x06F0 + 0x30
        else
          unit,
    ]).replaceAll(',', '').replaceAll('٬', '');

    // No whitespace before the multiplier: YouTube writes "1.2M", never
    // "1.2 M", and allowing a gap would read the "m" of "1 month ago" as
    // a million.
    final match = RegExp(r'(\d+(?:\.\d+)?)([KMB])?', caseSensitive: false)
        .firstMatch(normalised);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;

    final multiplier = switch (match.group(2)?.toUpperCase()) {
      'K' => 1000,
      'M' => 1000000,
      'B' => 1000000000,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  static final _playlistIdPattern = RegExp(r'^[A-Za-z0-9_-]{13,}$');

  static bool _isPlaylistId(String id) =>
      (id.startsWith('PL') ||
          id.startsWith('UU') ||
          id.startsWith('OL') ||
          id.startsWith('RD') ||
          id.startsWith('FL') ||
          id.startsWith('LL')) &&
      _playlistIdPattern.hasMatch(id);

  static String? _string(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;

  /// Follows a path of map keys, returning null the moment one is
  /// missing or is not a map.
  static dynamic _at(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  /// The `{content: "..."}` shape every *ViewModel* uses for text, also
  /// accepting the `dynamicTextViewModel` wrapper the page title has.
  static String? _viewModelText(dynamic node) {
    if (node is String) return _string(node);
    if (node is! Map) return null;
    final direct = _string(node['content']);
    if (direct != null) return direct;
    for (final key in const ['text', 'dynamicTextViewModel']) {
      final nested = _viewModelText(node[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  /// The `{simpleText}` / `{runs: [...]}` shape classic renderers use.
  static String? _runsText(dynamic node) {
    if (node is String) return _string(node);
    if (node is! Map) return null;
    final simple = _string(node['simpleText']);
    if (simple != null) return simple;
    final runs = node['runs'];
    if (runs is! List) return null;
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map) buffer.write(run['text'] ?? '');
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }

  /// The widest `sources` / `thumbnails` entry under [node].
  static String? _largestImage(dynamic node) {
    if (node is! Map) return null;
    final list = node['sources'] ?? node['thumbnails'];
    if (list is! List || list.isEmpty) return null;

    String? best;
    var bestWidth = -1;
    for (final entry in list) {
      if (entry is! Map) continue;
      final url = _string(entry['url']);
      if (url == null) continue;
      final width = entry['width'];
      final value = width is int ? width : 0;
      if (value > bestWidth) {
        bestWidth = value;
        best = url;
      }
    }
    return best;
  }

  /// Visits every map in the response. InnerTube moves renderers between
  /// paths constantly; the renderers themselves stay recognisable.
  static void _walk(
    dynamic node,
    void Function(Map<String, dynamic> node) visit,
  ) {
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
}
