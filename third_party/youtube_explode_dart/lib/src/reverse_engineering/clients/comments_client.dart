import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../../youtube_explode_dart.dart';
import '../../extensions/helpers_extension.dart';
import '../../retry.dart';
import '../pages/watch_page.dart';

@internal
class CommentsClient {
  final JsonMap root;

  late final List<JsonMap>? _commentRenderers = _getCommentRenderers();

  /// BOODTUBE PATCH: YouTube moved comment data out of the render tree.
  /// A commentThreadRenderer now carries a commentViewModel holding only
  /// keys, and the text, author and counts arrive separately under
  /// frameworkUpdates as commentEntityPayload entities. Upstream still
  /// reads commentRenderer, which is simply absent — its null check
  /// threw for every video on every request. This indexes the entities
  /// once so each comment can find its own.
  late final Map<String, JsonMap> _entities = _collectCommentEntities();

  Map<String, JsonMap> _collectCommentEntities() {
    final mutations = root.getJson<List<dynamic>>(
      'frameworkUpdates/entityBatchUpdate/mutations',
    );
    if (mutations == null) return const {};
    final out = <String, JsonMap>{};
    for (final mutation in mutations) {
      if (mutation is! Map) continue;
      final payload = (mutation as JsonMap).getJson<JsonMap>(
        'payload/commentEntityPayload',
      );
      final key = payload?.getT<String>('key');
      if (payload != null && key != null) out[key] = payload;
    }
    return out;
  }

  late final List<_Comment>? comments = _commentRenderers
      ?.map((e) => _Comment(e, _entities))
      .where((e) => e.isUsable)
      .toList(growable: false);

  late final String? _continuationToken = _getContinuationToken();

  CommentsClient(this.root);

  ///
  static Future<CommentsClient?> get(
    YoutubeHttpClient httpClient,
    Video video,
  ) async {
    final watchPage = video.watchPage ??
        await retry<WatchPage>(
          httpClient,
          () async => WatchPage.get(httpClient, video.id.value),
        );

    final continuation = watchPage.initialData.commentsContinuation;
    if (continuation == null) {
      return null;
    }

    final data = await httpClient.sendContinuation('next', continuation);
    return CommentsClient(data);
  }

  ///
  static Future<CommentsClient?> getReplies(
    YoutubeHttpClient httpClient,
    String token,
  ) async {
    final data = await httpClient.sendContinuation('next', token);
    return CommentsClient(data);
  }

  /*
onResponseReceivedEndpoints[1].reloadContinuationItemsCommand.continuationItems[2].commentThreadRenderer.comment.commentRenderer.contentText.runs[0].text   */
  List<JsonMap>? _getCommentRenderers() {
    final endpoints =
        root.getJson<List<dynamic>>('onResponseReceivedEndpoints');
    final endpoint = endpoints?.last as JsonMap?;
    if (endpoint == null) {
      return null;
    }

    // This was used in old youtube versions.
    final continuationItems = endpoint.getJson<List<dynamic>>(
      'appendContinuationItemsAction/continuationItems',
    );
    final comments = continuationItems
        ?.where((e) => e['commentRenderer'] != null)
        .toList(growable: false);

    if (comments?.isNotEmpty ?? false) {
      return comments?.cast<JsonMap>();
    }

    // This can probably be simplified.
    final cmd = endpoint.getJson<JsonMap>('reloadContinuationItemsCommand') ??
        endpoint.getJson<JsonMap>('appendContinuationItemsAction');
    final items = cmd?.getJson<List<dynamic>>('continuationItems') ??
        cmd?.getJson<List<dynamic>>('appendContinuationItemsAction');
    return items
            ?.where((e) => e['commentThreadRenderer'] != null)
            .map((e) =>
                (e as JsonMap).getJson<JsonMap>('commentThreadRenderer')!)
            .toList(growable: false) ??
        const [];
  }

  String? _getContinuationToken() {
    final endpoints =
        root.getJson<List<dynamic>>('onResponseReceivedEndpoints')!;
    final last = endpoints.last as JsonMap;
    final items = last.getJson<List<dynamic>>(
      'appendContinuationItemsAction/continuationItems',
    );
    final item =
        items?.firstWhereOrNull((e) => e['continuationItemRenderer'] != null)
            as JsonMap?;
    final token = item?.getJson<String>(
      'continuationItemRenderer/button/buttonRenderer/command/continuationCommand/token',
    ); /* Used for the replies */
    if (token != null) return token;

    final cmd = last.getJson<JsonMap>('reloadContinuationItemsCommand') ??
        last.getJson<JsonMap>('appendContinuationItemsAction');
    final continuationItems =
        cmd?.getJson<List<dynamic>>('continuationItems') ??
            cmd?.getJson<List<dynamic>>('appendContinuationItemsAction');
    final continuationItem = continuationItems?.firstWhereOrNull(
        (e) => e['continuationItemRenderer'] != null) as JsonMap?;
    return continuationItem?.getJson<String>(
      'continuationItemRenderer/continuationEndpoint/continuationCommand/token',
    );
  }

  // onResponseReceivedEndpoints[0].reloadContinuationItemsCommand.continuationItems[0].commentsHeaderRenderer
  int getCommentsCount() {
    final firstEndpoint = root
        .getJson<List<dynamic>>('onResponseReceivedEndpoints')!
        .first as JsonMap;
    return firstEndpoint
            .getJson<String>(
              'reloadContinuationItemsCommand/continuationItems/0/commentsHeaderRenderer/commentsCount/runs/0/text',
            )
            ?.parseIntWithUnits() ??
        0;
  }

  Future<CommentsClient?> nextPage(YoutubeHttpClient httpClient) async {
    if (_continuationToken == null) {
      return null;
    }

    final data = await httpClient.sendContinuation('next', _continuationToken!);
    return CommentsClient(data);
  }
}

/// BOODTUBE PATCH: reads either shape.
///
/// The current one is a commentViewModel in the thread plus a
/// commentEntityPayload under frameworkUpdates, joined on commentKey.
/// The old commentRenderer path is kept as a fallback so a rollback on
/// YouTube's side does not break this again, and every field is
/// nullable — a comment that cannot be read is dropped by [isUsable]
/// rather than throwing out of the whole batch, which is how one
/// changed field used to take all twenty with it.
class _Comment {
  final JsonMap root;
  final Map<String, JsonMap> entities;

  _Comment(this.root, this.entities);

  late final JsonMap? _commentRenderer =
      root.getJson<JsonMap>('commentRenderer') ??
          root.getJson<JsonMap>('comment/commentRenderer');

  late final JsonMap? _payload = () {
    // The thread's commentViewModel wraps another object of the same
    // name; the keys live one level further down than the field
    // suggests.
    final key =
        root.getJson<String>('commentViewModel/commentViewModel/commentKey');
    return key == null ? null : entities[key];
  }();

  late final JsonMap? _commentRepliesRenderer =
      root.getJson<JsonMap>('replies/commentRepliesRenderer');

  /// Used to get replies
  late final String? continuation = _commentRepliesRenderer?.getJson<String>(
    'contents/0/continuationItemRenderer/continuationEndpoint/continuationCommand/token',
  );

  /// Reads the entity payload when there is one and falls back to the
  /// old renderer otherwise, in one place so every field reads the same.
  String? _str(String payloadPath, String rendererPath) {
    final payload = _payload;
    if (payload != null) return payload.getJson<String>(payloadPath);
    return _commentRenderer?.getJson<String>(rendererPath);
  }

  late final int? repliesCount = () {
    final payload = _payload;
    if (payload != null) {
      return payload.getJson<String>('toolbar/replyCount').parseIntWithUnits();
    }
    return _commentRenderer?.getT<int>('replyCount');
  }();

  late final String? author =
      _str('author/displayName', 'authorText/simpleText');

  late final String? channelThumbnail = () {
    final payload = _payload;
    if (payload != null) {
      return payload.getJson<String>('author/avatarThumbnailUrl');
    }
    final thumbs =
        _commentRenderer?.getJson<List<dynamic>>('authorThumbnail/thumbnails');
    return (thumbs?.lastOrNull as JsonMap?)?.getT<String>('url');
  }();

  late final String? channelId =
      _str('author/channelId', 'authorEndpoint/browseEndpoint/browseId');

  late final String? text = () {
    final payload = _payload;
    if (payload != null) {
      return payload.getJson<String>('properties/content/content');
    }
    return _commentRenderer
        ?.getJson<List<dynamic>>('contentText/runs')
        ?.cast<Map<dynamic, dynamic>>()
        .parseRuns();
  }();

  late final String? publishTime =
      _str('properties/publishedTime', 'publishedTimeText/runs/0/text');

  late final int? likeCount = () {
    final payload = _payload;
    if (payload != null) {
      return payload
          .getJson<String>('toolbar/likeCountNotliked')
          .parseIntWithUnits();
    }
    return _commentRenderer
        ?.getJson<String>('voteCount/simpleText')
        .parseIntWithUnits();
  }();

  /// The entity payload carries no creator-heart flag; the pinned marker
  /// on the view model is the nearest thing it does have.
  late final bool isHearted = _payload != null
      ? root.getJson<String>(
                'commentViewModel/commentViewModel/pinnedText',
              ) !=
              null
      : _commentRenderer?.getJson<JsonMap>(
              'actionButtons/commentActionButtonsRenderer/creatorHeart',
            ) !=
          null;

  /// A comment without an author or a body is not worth showing, and is
  /// dropped instead of surfacing as a blank row.
  bool get isUsable => author != null && text != null && channelId != null;

  @override
  String toString() => '$author: $text';
}

extension _CommentsDataExtension on WatchPageInitialData {
  JsonMap? getContinuationContext() {
    if (root['contents'] != null) {
      final contents = root.getJson<List<dynamic>>(
        'contents/twoColumnWatchNextResults/results/results/contents',
      );
      final section =
          contents?.lastWhereOrNull((e) => e['itemSectionRenderer'] != null)
              as JsonMap?;
      final sectionContents =
          section?.getJson<List<dynamic>>('itemSectionRenderer/contents');
      final first = sectionContents?.firstOrNull as JsonMap?;
      return first?.getJson<JsonMap>(
        'continuationItemRenderer/continuationEndpoint/continuationCommand',
      );
    }
    return null;
  }

  String? get commentsContinuation =>
      getContinuationContext()?.getT<String>('token');
}
