// ============================================================
// CommentsService — real comments, straight from InnerTube `next`
// ============================================================
// youtube_explode's comments client is a scraper for a watch page
// layout YouTube no longer serves the same way twice, and it exposes no
// avatar, no pinned/hearted state, no sort order and no reply paging.
// The comment section is one InnerTube endpoint away, so this asks for
// it directly — the same `next` call the watch page itself makes, over
// the same `YoutubeHttpClient` the rest of the app already shares (same
// cookies, same retry, same visitor identity), exactly as
// [ChannelBrowseClient] does for `browse`.
//
// Two round trips, mirroring SmartTube's CommentsService:
//
//   1. `next` with the video id. The watch response does not carry a
//      single comment — it carries the *token* that loads them, in the
//      `comment-item-section` (or the comments engagement panel), plus
//      the section's total in `commentsEntryPointHeaderRenderer`.
//   2. `next` with that token, which returns the threads themselves.
//      Paging, sorting and replies are all the same call with a
//      different token.
//
// YouTube is mid-migration in what comes back from step 2, and both
// shapes are live depending on the day and the video:
//
//   * the classic one, where every field sits inside
//     `commentThreadRenderer/comment/commentRenderer`;
//   * the current one, where the thread list only names entity keys and
//     the content arrives out of band in
//     `frameworkUpdates.entityBatchUpdate.mutations` as
//     `commentEntityPayload` (plus `commentSurfaceEntityPayload` for the
//     pinned marker and `engagementToolbarStateEntityPayload` for the
//     creator's heart).
//
// [CommentsParser] reads both and hands back the same [CommentPage], so
// nothing above this file knows which one arrived.
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeHttpClient;

import '../../core/errors/exceptions.dart';
import '../../domain/entities/comment_item.dart';

/// What the watch page knows about a video's comments before any of them
/// have been fetched: the token that loads them (null when comments are
/// off), the count YouTube prints beside the section, and — on the
/// current surface, where the sort menu ships with the panel rather than
/// with the comments — the tokens that load each order.
typedef CommentsEntryPoint = ({
  String? continuation,
  String? countText,
  Map<CommentSort, String> sortTokens,
});

class CommentsService {
  CommentsService(this._http);

  final YoutubeHttpClient _http;

  /// Watch-page lookups, by video id. The player asks for the count to
  /// label its pill and the sheet asks for the token moments later;
  /// caching means those two share one request instead of making two.
  final _entryPoints = <String, CommentsEntryPoint>{};
  static const _maxEntryPoints = 16;

  /// The section header's total, for the player's comments pill. Null
  /// when the video has comments turned off or YouTube printed no count.
  Future<String?> getCommentCountText(String videoId) async {
    try {
      return (await _entryPoint(videoId)).countText;
    } catch (_) {
      // A missing label is not worth failing the watch page over.
      return null;
    }
  }

  /// The first page of [videoId]'s comments in [sort] order.
  ///
  /// Returns [CommentPage.empty] when the video has comments disabled —
  /// that is an answer, not a failure. Transport failures throw so the
  /// sheet can offer a retry.
  Future<CommentPage> getComments(
    String videoId, {
    CommentSort sort = CommentSort.top,
  }) async {
    final entry = await _entryPoint(videoId);
    // The watch page's own panel usually carries a token per order, so
    // the wanted order can be asked for in the very first request.
    final token = entry.sortTokens[sort] ?? entry.continuation;
    if (token == null) return CommentPage.empty;

    final first = _withCount(await continuePage(token), entry.countText);
    if (sort == first.selectedSort || sort == CommentSort.top) return first;

    // The older surface only names its orders in the section's own
    // header, which does not exist until the section has answered once.
    final reorder = first.sortTokens[sort];
    if (reorder == null) return first;

    final sorted = _withCount(await continuePage(reorder), entry.countText);
    return CommentPage(
      items: sorted.items,
      continuation: sorted.continuation,
      totalCountText: sorted.totalCountText,
      sortTokens:
          sorted.sortTokens.isEmpty ? first.sortTokens : sorted.sortTokens,
      selectedSort: sorted.selectedSort ?? sort,
    );
  }

  /// The next page of a section, or the replies of one thread — both are
  /// the same request with the token the previous response handed over.
  Future<CommentPage> continuePage(String continuation) async {
    final data = await _post({'continuation': continuation});
    return CommentsParser.parsePage(data);
  }

  /// The replies under one comment. [continuation] is
  /// [CommentItem.repliesContinuation].
  Future<CommentPage> getReplies(String continuation) async {
    final page = await continuePage(continuation);
    // A reply page repeats nothing about its parent, so the caller can
    // only tell replies from top-level comments by where they came from.
    return CommentPage(
      items: [
        for (final item in page.items)
          if (item.parentId != null) item else _asReply(item),
      ],
      continuation: page.continuation,
    );
  }

  static CommentItem _asReply(CommentItem item) => CommentItem(
        id: item.id,
        author: item.author,
        authorChannelId: item.authorChannelId,
        authorAvatarUrl: item.authorAvatarUrl,
        content: item.content,
        publishedAt: item.publishedAt,
        publishedTimeText: item.publishedTimeText,
        likeCount: item.likeCount,
        likeCountText: item.likeCountText,
        parentId: '',
        isHearted: item.isHearted,
        isByOwner: item.isByOwner,
        isVerified: item.isVerified,
      );

  static CommentPage _withCount(CommentPage page, String? fallback) {
    if (page.totalCountText != null || fallback == null) return page;
    return CommentPage(
      items: page.items,
      continuation: page.continuation,
      totalCountText: fallback,
      sortTokens: page.sortTokens,
      selectedSort: page.selectedSort,
    );
  }

  Future<CommentsEntryPoint> _entryPoint(String videoId) async {
    final cached = _entryPoints[videoId];
    if (cached != null) return cached;

    final entry = CommentsParser.parseEntryPoint(
      await _post({'videoId': videoId}),
    );
    _entryPoints[videoId] = entry;
    while (_entryPoints.length > _maxEntryPoints) {
      _entryPoints.remove(_entryPoints.keys.first);
    }
    return entry;
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    try {
      return await _http.sendPost('next', body);
    } catch (e) {
      throw YouTubeException('Failed to load comments: $e', cause: e);
    }
  }
}

// ============================================================
// Parsing
// ============================================================

/// Turns a `next` response into [CommentPage]s. Pure and static, so the
/// whole of it is testable against a recorded response with no network
/// anywhere near it.
abstract final class CommentsParser {
  /// What the watch page says about a video's comment section.
  ///
  /// Two surfaces, in order of preference:
  ///
  ///   * the comments *engagement panel*, which is what YouTube serves
  ///     today. Its header holds the count and the sort menu, and its
  ///     content holds the token that loads the first page. The token is
  ///     taken from the content specifically — the header's sort menu
  ///     holds tokens too, and picking one of those by accident would
  ///     mean the section's default order silently depended on which key
  ///     the walk happened to reach first;
  ///   * the older `comment-item-section` and
  ///     `commentsEntryPointHeaderRenderer`, still served to some
  ///     clients.
  static CommentsEntryPoint parseEntryPoint(Map<String, dynamic> json) {
    String? token;
    String? count;
    var sortTokens = const <CommentSort, String>{};

    _walk(json, (node) {
      final panel = node['engagementPanelSectionListRenderer'];
      if (panel is Map<String, dynamic> && _isCommentsPanel(panel)) {
        token ??= _tokenIn(panel['content']) ?? _tokenIn(panel);
        final header = _firstOf(panel, 'engagementPanelTitleHeaderRenderer');
        if (header != null) {
          count ??= _firstRun(header['contextualInfo']);
          if (sortTokens.isEmpty) sortTokens = _sortTokens(header);
        }
      }

      // The classic watch page: a section that names itself.
      final section = node['itemSectionRenderer'];
      if (section is Map<String, dynamic> &&
          _string(section['sectionIdentifier']) == 'comment-item-section') {
        token ??= _tokenIn(section);
      }

      final entry = node['commentsEntryPointHeaderRenderer'];
      if (entry is Map<String, dynamic>) {
        count ??= _text(entry['commentCount']) ?? _text(entry['headerText']);
      }
    });

    return (continuation: token, countText: count, sortTokens: sortTokens);
  }

  static bool _isCommentsPanel(Map<String, dynamic> panel) {
    final id = _string(panel['panelIdentifier']) ??
        _string(panel['targetId']) ??
        _string(panel['identifier']);
    return id != null && id.contains('comments-section');
  }

  /// One page of comments, in either of YouTube's two shapes.
  static CommentPage parsePage(Map<String, dynamic> json) {
    // The out-of-band half of the current shape. Gathered first: the
    // thread list below is only a list of keys into it.
    final comments = _payloads(json, 'commentEntityPayload');
    final surfaces = _payloads(json, 'commentSurfaceEntityPayload');
    final toolbars = _payloads(json, 'engagementToolbarStateEntityPayload');

    final items = <CommentItem>[];
    final seen = <String>{};
    String? continuation;

    void add(CommentItem? item) {
      if (item == null || item.id.isEmpty || !seen.add(item.id)) return;
      items.add(item);
    }

    void entry(dynamic node) {
      if (node is! Map<String, dynamic>) return;

      final thread = node['commentThreadRenderer'];
      if (thread is Map<String, dynamic>) {
        add(_fromThread(thread, comments, surfaces, toolbars));
        return;
      }
      final renderer = node['commentRenderer'];
      if (renderer is Map<String, dynamic>) {
        add(_fromRenderer(renderer));
        return;
      }
      final view = _viewModel(node['commentViewModel']);
      if (view != null) {
        add(_fromViewModel(view, comments, surfaces, toolbars));
        return;
      }
      final more = node['continuationItemRenderer'];
      if (more is Map<String, dynamic>) {
        continuation ??= _tokenIn(more);
      }
    }

    final lists = _itemLists(json);
    for (final list in lists) {
      for (final node in list) {
        entry(node);
      }
    }

    // No recognisable list — YouTube reshuffled the envelope again.
    // Recognise the renderers wherever they landed rather than returning
    // an empty section.
    if (lists.isEmpty) {
      _walk(json, entry);
    }

    final header = _firstOf(json, 'commentsHeaderRenderer');
    return CommentPage(
      items: items,
      continuation: continuation,
      totalCountText: header == null ? null : _headerCount(header),
      sortTokens: header == null ? const {} : _sortTokens(header),
      selectedSort: header == null ? null : _selectedSort(header),
    );
  }

  // ------------------------------------------------------------
  // Threads
  // ------------------------------------------------------------

  static CommentItem? _fromThread(
    Map<String, dynamic> thread,
    Map<String, Map<String, dynamic>> comments,
    Map<String, Map<String, dynamic>> surfaces,
    Map<String, Map<String, dynamic>> toolbars,
  ) {
    final pinned = _string(thread['renderingPriority']) ==
        'RENDERING_PRIORITY_PINNED_COMMENT';
    final replies = thread['replies'];
    final repliesToken = replies == null ? null : _tokenIn(replies);
    final repliesCount = _count(_repliesLabel(replies));

    final renderer = _at(thread, ['comment', 'commentRenderer']);
    if (renderer is Map<String, dynamic>) {
      return _fromRenderer(
        renderer,
        repliesContinuation: repliesToken,
        repliesCount: repliesCount,
        pinned: pinned,
      );
    }

    final view = _viewModel(thread['commentViewModel']);
    if (view != null) {
      return _fromViewModel(
        view,
        comments,
        surfaces,
        toolbars,
        repliesContinuation: repliesToken,
        repliesCount: repliesCount,
        pinned: pinned,
      );
    }
    return null;
  }

  /// A `commentViewModel` is wrapped in a key of its own name inside a
  /// thread, and served bare inside a reply list. Both arrive here.
  static Map<String, dynamic>? _viewModel(dynamic node) {
    if (node is! Map<String, dynamic>) return null;
    final inner = node['commentViewModel'];
    if (inner is Map<String, dynamic>) return inner;
    return node.containsKey('commentKey') || node.containsKey('commentId')
        ? node
        : null;
  }

  /// "5 replies" / "View 12 replies", whichever button the thread has.
  static String? _repliesLabel(dynamic replies) {
    String? label;
    _walk(replies, (node) {
      if (label != null) return;
      final button = node['buttonRenderer'];
      if (button is Map<String, dynamic>) label = _text(button['text']);
    });
    return label;
  }

  // ------------------------------------------------------------
  // Classic: commentRenderer
  // ------------------------------------------------------------

  static CommentItem? _fromRenderer(
    Map<String, dynamic> renderer, {
    String? repliesContinuation,
    int? repliesCount,
    bool pinned = false,
  }) {
    final id = _string(renderer['commentId']);
    if (id == null) return null;

    final published = _text(renderer['publishedTimeText']);
    final votes = _text(renderer['voteCount']);
    final buttons =
        _at(renderer, ['actionButtons', 'commentActionButtonsRenderer']);
    final replies = repliesCount ??
        _int(renderer['replyCount']) ??
        _count(_text(renderer['repliesCount']));

    return CommentItem(
      id: id,
      author: _text(renderer['authorText']) ?? '',
      authorChannelId: _string(
            _at(renderer, ['authorEndpoint', 'browseEndpoint', 'browseId']),
          ) ??
          '',
      authorAvatarUrl: _largestImage(renderer['authorThumbnail']),
      content: _text(renderer['contentText']) ?? '',
      publishedAt: parsePublishedTime(published),
      publishedTimeText: published,
      likeCount: _count(votes) ?? _int(renderer['likeCount']) ?? 0,
      likeCountText: votes,
      replyCount: replies,
      repliesContinuation: repliesContinuation,
      isHearted: _hearted(buttons),
      isPinned: pinned || _firstOf(renderer, 'pinnedCommentBadge') != null,
      isByOwner: renderer['authorIsChannelOwner'] == true,
      isVerified: _verified(renderer['authorCommentBadge']),
    );
  }

  static bool _hearted(dynamic buttons) {
    if (buttons is! Map<String, dynamic>) return false;
    final heart = _at(buttons, ['creatorHeart', 'creatorHeartRenderer']);
    if (heart is! Map<String, dynamic>) return false;
    // The renderer only ships on hearted comments, but newer responses
    // ship it always and carry the state instead.
    final state = heart['isHearted'];
    return state is! bool || state;
  }

  /// YouTube marks a verified channel with a check badge and a verified
  /// *artist* with a music note, under three different icon names
  /// depending on the surface — hence the list rather than one match.
  static bool _verified(dynamic badge) {
    if (badge == null) return false;
    const marks = ['VERIFIED', 'CHECK_CIRCLE', 'AUDIO_BADGE', 'MUSIC'];
    var verified = false;
    _walk(badge, (node) {
      final type = _string(node['iconType']);
      if (type != null && marks.any(type.contains)) verified = true;
    });
    return verified;
  }

  // ------------------------------------------------------------
  // Current: commentViewModel + commentEntityPayload
  // ------------------------------------------------------------

  static CommentItem? _fromViewModel(
    Map<String, dynamic> view,
    Map<String, Map<String, dynamic>> comments,
    Map<String, Map<String, dynamic>> surfaces,
    Map<String, Map<String, dynamic>> toolbars, {
    String? repliesContinuation,
    int? repliesCount,
    bool pinned = false,
  }) {
    final payload = _lookup(comments, [
      _string(view['commentKey']),
      _string(view['commentId']),
    ]);
    if (payload == null) return null;

    final properties = _map(payload['properties']);
    final author = _map(payload['author']);
    final toolbar = _map(payload['toolbar']);

    final id = _string(properties['commentId']) ??
        _string(view['commentId']) ??
        _string(payload['key']);
    if (id == null) return null;

    final surface = _map(
      _lookup(surfaces, [
        _string(view['commentSurfaceKey']),
        _string(properties['toolbarSurfaceKey']),
      ]),
    );
    final toolbarState = _map(
      _lookup(toolbars, [
        _string(view['toolbarStateKey']),
        _string(properties['toolbarStateKey']),
      ]),
    );

    final published = _string(properties['publishedTime']);
    final likes = _string(toolbar['likeCountNotliked']) ??
        _string(toolbar['likeCountLiked']);
    final level = _int(properties['replyLevel']) ?? 0;

    return CommentItem(
      id: id,
      author: _string(author['displayName']) ?? '',
      authorChannelId: _string(author['channelId']) ?? '',
      authorAvatarUrl: _string(author['avatarThumbnailUrl']) ??
          _largestImage(_at(payload, ['avatar', 'image'])),
      content: _string(_at(properties, ['content', 'content'])) ?? '',
      publishedAt: parsePublishedTime(published),
      publishedTimeText: published,
      likeCount: _count(likes) ??
          _count(_string(toolbar['likeCountA11ylabel'])) ??
          0,
      likeCountText: likes,
      replyCount: repliesCount ?? _count(_string(toolbar['replyCount'])),
      parentId: level > 0 ? '' : null,
      repliesContinuation: repliesContinuation,
      // The heart lives in its own entity, keyed off the toolbar, so
      // that liking a comment can update it without touching the thread.
      isHearted: _heartState(toolbarState) || _heartState(toolbar),
      isPinned: pinned || _string(surface['pinnedText']) != null,
      isByOwner: author['isCreator'] == true,
      isVerified:
          author['isVerified'] == true || author['isVerifiedArtist'] == true,
    );
  }

  static bool _heartState(Map<String, dynamic> node) =>
      _string(node['heartState']) == 'TOOLBAR_HEART_STATE_HEARTED';

  static Map<String, dynamic>? _lookup(
    Map<String, Map<String, dynamic>> source,
    List<String?> keys,
  ) {
    for (final key in keys) {
      if (key == null) continue;
      final found = source[key];
      if (found != null) return found;
    }
    return null;
  }

  /// Every `frameworkUpdates` mutation of one payload type, indexed by
  /// its entity key and — for comments — by comment id as well, since
  /// the thread list names either one depending on the response.
  static Map<String, Map<String, dynamic>> _payloads(
    dynamic json,
    String name,
  ) {
    final out = <String, Map<String, dynamic>>{};
    _walk(json, (node) {
      final payload = node[name];
      if (payload is! Map<String, dynamic>) return;
      final key = _string(payload['key']) ?? _string(node['entityKey']);
      if (key != null) out[key] = payload;
      final id = _string(_at(payload, ['properties', 'commentId']));
      if (id != null) out.putIfAbsent(id, () => payload);
    });
    return out;
  }

  // ------------------------------------------------------------
  // Header: total and sort menu
  // ------------------------------------------------------------

  static String? _headerCount(Map<String, dynamic> header) =>
      _firstRun(header['countText']) ??
      _text(header['commentsCount']) ??
      _firstRun(header['titleText']);

  /// The tokens that reload the section in each order. YouTube localises
  /// the titles, so the menu is read positionally: it has always been
  /// [top, newest].
  static Map<CommentSort, String> _sortTokens(Map<String, dynamic> header) {
    final items = _subMenuItems(header);
    final tokens = <CommentSort, String>{};
    for (var i = 0; i < items.length && i < CommentSort.values.length; i++) {
      final token = _tokenIn(items[i]);
      if (token != null) tokens[CommentSort.values[i]] = token;
    }
    return tokens;
  }

  static CommentSort? _selectedSort(Map<String, dynamic> header) {
    final items = _subMenuItems(header);
    for (var i = 0; i < items.length && i < CommentSort.values.length; i++) {
      if (items[i]['selected'] == true) return CommentSort.values[i];
    }
    return null;
  }

  /// The section header calls its sort menu `sortMenu`; the panel header
  /// calls the same renderer `menu`.
  static List<Map<String, dynamic>> _subMenuItems(Map<String, dynamic> header) {
    for (final key in const ['sortMenu', 'menu']) {
      final menu = _at(header, [key, 'sortFilterSubMenuRenderer']);
      final items = menu is Map ? menu['subMenuItems'] : null;
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  // ------------------------------------------------------------
  // Envelope
  // ------------------------------------------------------------

  /// Every list of section entries the response might have used. The
  /// first page arrives under `reloadContinuationItemsCommand`, later
  /// pages under `appendContinuationItemsAction`, and the TV/legacy
  /// surface under `continuationContents`.
  static List<List<dynamic>> _itemLists(dynamic json) {
    const holders = [
      'reloadContinuationItemsCommand',
      'appendContinuationItemsAction',
    ];
    const sections = [
      'itemSectionContinuation',
      'commentRepliesContinuation',
      'commentItemSectionContinuation',
    ];

    final lists = <List<dynamic>>[];
    _walk(json, (node) {
      for (final key in holders) {
        final holder = node[key];
        if (holder is Map && holder['continuationItems'] is List) {
          lists.add(holder['continuationItems'] as List);
        }
      }
      for (final key in sections) {
        final section = node[key];
        if (section is Map && section['contents'] is List) {
          lists.add(section['contents'] as List);
        }
      }
    });
    return lists;
  }

  /// The first `continuationCommand` token anywhere under [node].
  static String? _tokenIn(dynamic node) {
    String? token;
    _walk(node, (candidate) {
      if (token != null) return;
      for (final key in const [
        'continuationCommand',
        'reloadContinuationData',
        'nextContinuationData',
      ]) {
        final command = candidate[key];
        if (command is Map) {
          token ??= _string(command['token']) ??
              _string(command['continuation']);
        }
      }
    });
    return token;
  }

  static Map<String, dynamic>? _firstOf(dynamic json, String key) {
    Map<String, dynamic>? found;
    _walk(json, (node) {
      if (found != null) return;
      final value = node[key];
      if (value is Map<String, dynamic>) found = value;
    });
    return found;
  }

  // ------------------------------------------------------------
  // Scalars
  // ------------------------------------------------------------

  /// "1.2K", "1,234", "5 likes" → an int. Null when there is no number.
  ///
  /// Which separators appear depends on the locale of the response, and
  /// several of them pad thousands with a non-breaking space, so every
  /// kind of space goes before anything is parsed.
  static int? _count(String? text) {
    if (text == null) return null;
    final normalised = text.replaceAll(RegExp(r'\s|\u00a0'), '');
    final match = RegExp(r'(\d[\d.,]*)([KMB])?', caseSensitive: false)
        .firstMatch(normalised);
    if (match == null) return null;

    final digits = match.group(1)!;
    final suffix = match.group(2)?.toUpperCase();
    if (suffix == null) {
      return int.tryParse(digits.replaceAll(RegExp('[.,]'), ''));
    }
    // A suffixed number is decimal: "1.2K", and in some locales "1,2K".
    final value = double.tryParse(digits.replaceAll(',', '.'));
    if (value == null) return null;
    const scale = {'K': 1000, 'M': 1000000, 'B': 1000000000};
    return (value * scale[suffix]!).round();
  }

  /// YouTube's "3 days ago" turned into a moment, so the UI can render
  /// the age in the app's own language instead of YouTube's.
  static DateTime parsePublishedTime(String? text, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (text == null) return reference;

    final match = RegExp(
      r'(\d+)\s*(second|minute|hour|day|week|month|year)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return reference;

    final amount = int.parse(match.group(1)!);
    return switch (match.group(2)!.toLowerCase()) {
      'second' => reference.subtract(Duration(seconds: amount)),
      'minute' => reference.subtract(Duration(minutes: amount)),
      'hour' => reference.subtract(Duration(hours: amount)),
      'day' => reference.subtract(Duration(days: amount)),
      'week' => reference.subtract(Duration(days: amount * 7)),
      'month' => reference.subtract(Duration(days: amount * 30)),
      _ => reference.subtract(Duration(days: amount * 365)),
    };
  }

  /// Non-blank strings only: an unliked comment ships its like count as
  /// a single space, and " " is not a count.
  static String? _string(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : const {};

  static dynamic _at(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  /// `{simpleText}` / `{runs: [...]}`, joined.
  static String? _text(dynamic node) {
    if (node is String) return _string(node);
    if (node is! Map) return null;
    final simple = _string(node['simpleText']);
    if (simple != null) return simple;
    final runs = node['runs'];
    if (runs is! List) return _string(node['content']);
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map) buffer.write(run['text'] ?? '');
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }

  /// Only the first run — the section header reads "1,234" then
  /// " Comments", and only the number is wanted.
  static String? _firstRun(dynamic node) {
    if (node is Map && node['runs'] is List) {
      final runs = node['runs'] as List;
      if (runs.isNotEmpty && runs.first is Map) {
        return _string((runs.first as Map)['text']);
      }
    }
    return _text(node);
  }

  static String? _largestImage(dynamic node) {
    if (node is! Map) return null;
    final list = node['thumbnails'] ?? node['sources'];
    if (list is! List) return null;

    String? best;
    var bestWidth = -1;
    for (final entry in list) {
      if (entry is! Map) continue;
      final url = _string(entry['url']);
      if (url == null) continue;
      final width = entry['width'];
      final value = width is num ? width.toInt() : 0;
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
