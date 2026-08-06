// ============================================================
// Content Providers (Home, Search, Channel)
// ============================================================
// FutureProviders للـ data fetching مع auto-dispose.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smarttube_poc/data/dearrow/dearrow_service.dart';
import 'package:smarttube_poc/data/local/database/app_database.dart';
import 'package:smarttube_poc/data/youtube/authenticated_client.dart';
import 'package:smarttube_poc/data/youtube/return_dislike_service.dart';
import 'package:smarttube_poc/data/youtube/search_filter_params.dart';
import 'package:smarttube_poc/domain/entities/channel_info.dart';
import 'package:smarttube_poc/domain/entities/content_filter.dart';
import 'package:smarttube_poc/domain/entities/media_group.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/entities/playlist_info.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/domain/repositories/content_repository.dart'
    show SearchFilters;
import 'package:smarttube_poc/domain/repositories/local_library_repository.dart'
    show LocalLibraryRepository;
import 'package:smarttube_poc/presentation/providers/auth_providers.dart';
import 'package:smarttube_poc/presentation/screens/browse/browse_screen.dart'
    show BrowseCategory;
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';

// ============================================================
// Feed filtering — hidden content, blocked channels, thumbnails
// ============================================================

final contentFilterProvider = Provider<ContentFilter>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return ContentFilter(
    hidden: settings.hiddenContent,
    blockedChannelIds: settings.blockedChannelIds,
  );
});

/// Everything that turns raw extraction output into what the feed cards
/// actually draw, in the order the steps depend on each other:
///
///   1. resume progress, from the local play-position table — the
///      "hide watched" rules need it before they can decide anything;
///   2. the user's hidden-content and blocked-channel rules;
///   3. the clickbait-thumbnail preference;
///   4. channel avatars known locally, for items whose surface did not
///      carry one;
///   5. DeArrow's community title and thumbnail, when enabled.
///
/// Every lookup is one batched query or one batched request per feed,
/// never one per item.
Future<List<MediaItem>> _prepare(
  Ref ref,
  List<MediaItem> items,
  ContentSurface surface,
) async {
  if (items.isEmpty) return items;

  // Read everything reactive up front: the awaits below must not decide
  // which providers this one depends on.
  final filter = ref.watch(contentFilterProvider);
  final settings = ref.watch(settingsControllerProvider);
  final library = ref.watch(localLibraryRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  final deArrow = ref.watch(deArrowServiceProvider);

  var result = await _withWatchProgress(library, items);
  result = filter.apply(result, surface);
  if (result.isEmpty) return result;

  final style = settings.clickbaitThumbnail;
  if (style != ClickbaitThumbnail.original) {
    result = [
      for (final item in result)
        item.copyWith(thumbnailUrl: style.apply(item.thumbnailUrl)),
    ];
  }

  result = await _withLocalAvatars(db, result);
  if (settings.deArrowEnabled) result = await _withDeArrow(deArrow, result);
  _remember(result);
  return result;
}

// ============================================================
// Recently seen items
// ============================================================

/// The last few hundred items any surface has shown, by video id.
///
/// Opening a video used to leave the whole page blank behind a spinner
/// while metadata loaded, even though the card the user just tapped
/// already carried the title, thumbnail, channel and duration. The
/// player seeds itself from here so the page draws immediately and only
/// the video itself is waited on.
final _recentItems = <String, MediaItem>{};
const _recentItemsMax = 300;

void _remember(List<MediaItem> items) {
  for (final item in items) {
    // Re-inserting moves the key to the end, so the eviction below
    // drops what was genuinely least recently seen.
    _recentItems
      ..remove(item.videoId)
      ..[item.videoId] = item;
  }
  while (_recentItems.length > _recentItemsMax) {
    _recentItems.remove(_recentItems.keys.first);
  }
}

/// What a surface last showed for [videoId], if anything. Metadata only —
/// never stream URLs, which expire.
MediaItem? cachedMediaItem(String videoId) => _recentItems[videoId];

/// Joins the feed against the saved play positions so the red resume bar
/// and the "hide watched" settings have something to work with.
Future<List<MediaItem>> _withWatchProgress(
  LocalLibraryRepository library,
  List<MediaItem> items,
) async {
  final result = await library.getPlayPositions(
    items.map((item) => item.videoId),
  );
  final positions = result.dataOrNull;
  if (positions == null || positions.isEmpty) return items;

  return [
    for (final item in items)
      if (positions[item.videoId] case final position?)
        item.copyWith(
          resumePosition: position,
          percentWatched: item.duration > Duration.zero
              ? ((position.inMilliseconds * 100) ~/
                      item.duration.inMilliseconds)
                  .clamp(0, 100)
              : item.percentWatched,
        )
      else
        item,
  ];
}

/// Fills in channel avatars for items whose surface did not carry one,
/// from the channels the user is subscribed to. Nothing is invented: an
/// unknown channel keeps a null avatar and the card shows the initial.
Future<List<MediaItem>> _withLocalAvatars(
  AppDatabase db,
  List<MediaItem> items,
) async {
  if (items.every((item) => item.channelAvatarUrl != null)) return items;

  final rows = await db.getAllSubscriptions();
  final avatars = <String, String>{
    for (final row in rows)
      if (row.avatarUrl case final avatar?) row.channelId: avatar,
  };
  if (avatars.isEmpty) return items;

  return [
    for (final item in items)
      if (item.channelAvatarUrl == null && avatars[item.channelId] != null)
        item.copyWith(channelAvatarUrl: avatars[item.channelId])
      else
        item,
  ];
}

/// Substitutes DeArrow's community title and thumbnail. Fails soft: the
/// service swallows its own errors and returns whatever it did get, so a
/// DeArrow outage costs the feed nothing but the substitution.
Future<List<MediaItem>> _withDeArrow(
  DeArrowService service,
  List<MediaItem> items,
) async {
  final branding = await service.getDeArrowDataBatch(
    items.map((item) => item.videoId),
  );
  if (branding.isEmpty) return items;

  return [
    for (final item in items)
      if (branding[item.videoId] case final data?)
        item.copyWith(
          deArrowData: data,
          title: data.title ?? item.title,
          thumbnailUrl: data.thumbnailUrl ?? item.thumbnailUrl,
        )
      else
        item,
  ];
}

// ============================================================
// Paged feeds
// ============================================================

/// A feed that can grow. [hasMore] says whether another page exists;
/// [loadMoreError] carries the last failed `loadMore()` without
/// destroying the pages already on screen.
class PagedFeed {
  const PagedFeed({
    required this.items,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<MediaItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  static const empty = PagedFeed(items: <MediaItem>[]);
}

/// One `loadMore()` step, shared by the feeds below: fetch, drop the
/// duplicates YouTube repeats across continuations, prepare, append.
///
/// A failure keeps every page already on screen and reports itself
/// through [PagedFeed.loadMoreError] — a feed that has loaded four pages
/// must not collapse into an error screen because the fifth timed out.
Future<PagedFeed> _appendPage(
  Ref ref,
  PagedFeed current,
  Set<String> seen,
  ContentSurface surface,
  Future<List<MediaItem>?> Function() fetch,
) async {
  try {
    final fetched = await fetch();
    final fresh = fetched?.where((item) => seen.add(item.videoId)).toList() ??
        const <MediaItem>[];
    final prepared = fresh.isEmpty
        ? const <MediaItem>[]
        : await _prepare(ref, fresh, surface);
    return PagedFeed(
      items: [...current.items, ...prepared],
      hasMore: fetched != null && fetched.isNotEmpty,
    );
  } catch (e) {
    return PagedFeed(items: current.items, hasMore: true, loadMoreError: e);
  }
}

// ============================================================
// Home Feed
// ============================================================

/// The home feed, one page at a time.
///
/// Two sources, same shape: the account's personalised feed when signed
/// in (continued with YouTube's own continuation token), and the topic
/// shelves otherwise (continued shelf by shelf).
class HomeFeedNotifier extends AutoDisposeAsyncNotifier<PagedFeed> {
  static const _surface = ContentSurface.home;

  final _seen = <String>{};

  /// InnerTube continuation for the signed-in feed.
  String? _continuation;
  bool _viaAccount = false;

  /// One token per topic shelf, for the signed-out feed. They are
  /// followed in turn so the mixed list keeps drawing from every shelf.
  final _shelfTokens = <String>[];

  /// Loads the next page and appends it. Safe to call on every scroll
  /// tick: it is a no-op while a page is in flight or the feed is done.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      PagedFeed(items: current.items, hasMore: true, isLoadingMore: true),
    );
    state = AsyncData(
      await _appendPage(ref, current, _seen, _surface, _fetchNextPage),
    );
  }

  @override
  Future<PagedFeed> build() async {
    _seen.clear();
    _continuation = null;
    _viaAccount = false;
    _shelfTokens.clear();

    // Always ask the authenticated client first: it resolves a token
    // from secure storage itself and returns null when signed out, so
    // this does not depend on the sign-in state having been restored.
    final page = await ref.watch(authenticatedClientProvider).getHomeFeedPage();
    if (page != null && page.items.isNotEmpty) {
      _viaAccount = true;
      _continuation = page.continuation;
      return PagedFeed(
        items: await _prepare(ref, _fresh(page.items), _surface),
        hasMore: _continuation != null,
      );
    }

    final result = await ref.watch(contentRepositoryProvider).getHomeFeed();
    final groups = result.when(
      success: (groups) => groups,
      failure: (message, type, cause) => throw Exception(message),
    );
    for (final group in groups) {
      final token = group.nextPageToken;
      if (token != null && token.isNotEmpty) _shelfTokens.add(token);
    }
    return PagedFeed(
      items: await _prepare(
        ref,
        _fresh([for (final group in groups) ...group.mediaItems]),
        _surface,
      ),
      hasMore: _shelfTokens.isNotEmpty,
    );
  }

  List<MediaItem> _fresh(Iterable<MediaItem> items) =>
      items.where((item) => _seen.add(item.videoId)).toList();

  Future<List<MediaItem>?> _fetchNextPage() async {
    if (_viaAccount) {
      final continuation = _continuation;
      if (continuation == null) return null;
      final page = await ref
          .read(authenticatedClientProvider)
          .getHomeFeedPage(continuation: continuation);
      _continuation = page?.continuation;
      return page?.items;
    }

    // Signed out: take one shelf's next page per call, rotating through
    // the shelves so the mixed feed stays mixed.
    while (_shelfTokens.isNotEmpty) {
      final token = _shelfTokens.removeAt(0);
      final result = await ref.read(contentRepositoryProvider).loadMore(token);
      final page = result.dataOrNull;
      if (page == null || page.items.isEmpty) continue;
      final next = page.nextPageToken;
      if (next != null && next.isNotEmpty) _shelfTokens.add(next);
      return page.items;
    }
    return null;
  }
}

/// Home, paginated. Screens read `.items` / `.hasMore` and call
/// `ref.read(homeFeedPagedProvider.notifier).loadMore()`.
final homeFeedPagedProvider =
    AsyncNotifierProvider.autoDispose<HomeFeedNotifier, PagedFeed>(
  HomeFeedNotifier.new,
);

/// The first page of home, as shelves. Kept for callers that want the
/// grouped shape; [homeFeedPagedProvider] is what scrolls.
final homeFeedProvider =
    FutureProvider.autoDispose<List<MediaGroup>>((ref) async {
  final videos = await ref.watch(authenticatedClientProvider).getHomeFeed();
  if (videos != null && videos.isNotEmpty) {
    return [
      MediaGroup(
        title: 'Recommended',
        type: MediaGroupType.recommended,
        mediaItems: await _prepare(ref, videos, ContentSurface.home),
      ),
    ];
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.getHomeFeed();

  final groups = result.when(
    success: (groups) => groups,
    failure: (message, type, cause) => throw Exception(message),
  );
  return [
    for (final group in groups)
      group.copyWith(
        mediaItems: await _prepare(ref, group.mediaItems, ContentSurface.home),
      ),
  ];
});

// ============================================================
// Subscriptions feed — the account's, when signed in
// ============================================================

/// The subscriptions feed, one page at a time.
///
/// Two sources, same shape as home: the account's own feed when signed
/// in (continued with YouTube's continuation token), and the locally
/// subscribed channels' uploads otherwise (continued channel by
/// channel).
class SubscriptionsFeedNotifier extends AutoDisposeAsyncNotifier<PagedFeed> {
  static const _surface = ContentSurface.subscriptions;

  final _seen = <String>{};

  /// InnerTube continuation for the account's feed.
  String? _continuation;
  bool _viaAccount = false;

  /// One token per subscribed channel, for the signed-out feed. They are
  /// followed in turn so the merged list keeps drawing from every
  /// channel rather than exhausting the first.
  final _shelfTokens = <String>[];

  /// Loads the next page and appends it. Safe to call on every scroll
  /// tick: a no-op while a page is in flight or the feed is done.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      PagedFeed(items: current.items, hasMore: true, isLoadingMore: true),
    );
    state = AsyncData(
      await _appendPage(ref, current, _seen, _surface, _fetchNextPage),
    );
  }

  @override
  Future<PagedFeed> build() async {
    _seen.clear();
    _continuation = null;
    _viaAccount = false;
    _shelfTokens.clear();

    final page =
        await ref.watch(authenticatedClientProvider).getSubscriptionsFeedPage();
    if (page != null && page.items.isNotEmpty) {
      _viaAccount = true;
      _continuation = page.continuation;
      return PagedFeed(
        items: await _prepare(ref, _fresh(page.items), _surface),
        hasMore: _continuation != null,
      );
    }

    final result =
        await ref.watch(contentRepositoryProvider).getSubscriptionsFeed();
    final groups = result.when(
      success: (groups) => groups,
      failure: (message, type, cause) => throw Exception(message),
    );
    for (final group in groups) {
      final token = group.nextPageToken;
      if (token != null && token.isNotEmpty) _shelfTokens.add(token);
    }
    return PagedFeed(
      items: await _prepare(
        ref,
        _fresh([for (final group in groups) ...group.mediaItems]),
        _surface,
      ),
      hasMore: _shelfTokens.isNotEmpty,
    );
  }

  List<MediaItem> _fresh(Iterable<MediaItem> items) =>
      items.where((item) => _seen.add(item.videoId)).toList();

  Future<List<MediaItem>?> _fetchNextPage() async {
    if (_viaAccount) {
      final continuation = _continuation;
      if (continuation == null) return null;
      final page = await ref
          .read(authenticatedClientProvider)
          .getSubscriptionsFeedPage(continuation: continuation);
      _continuation = page?.continuation;
      return page?.items;
    }

    while (_shelfTokens.isNotEmpty) {
      final token = _shelfTokens.removeAt(0);
      final result = await ref.read(contentRepositoryProvider).loadMore(token);
      final page = result.dataOrNull;
      if (page == null || page.items.isEmpty) continue;
      final next = page.nextPageToken;
      if (next != null && next.isNotEmpty) _shelfTokens.add(next);
      return page.items;
    }
    return null;
  }
}

/// Subscriptions, paginated. Screens read `.items` / `.hasMore` and call
/// `ref.read(subscriptionsFeedPagedProvider.notifier).loadMore()`.
final subscriptionsFeedPagedProvider =
    AsyncNotifierProvider.autoDispose<SubscriptionsFeedNotifier, PagedFeed>(
  SubscriptionsFeedNotifier.new,
);

// ============================================================
// Playlists — the account's own
// ============================================================

/// Playlists the signed-in account owns or saved. Empty when signed out;
/// there is no local playlist concept to fall back to.
final playlistsProvider =
    FutureProvider.autoDispose<List<AccountPlaylist>>((ref) async {
  final playlists = await ref.watch(authenticatedClientProvider).getPlaylists();
  if (playlists == null || playlists.isEmpty) return const [];

  // YouTube keeps these two implicitly and does not list them among the
  // user's playlists, but every client shows them.
  final hasLiked = playlists.any((p) => p.playlistId == 'LL');
  final hasWatchLater = playlists.any((p) => p.playlistId == 'WL');
  return [
    if (!hasLiked)
      (
        playlistId: 'LL',
        title: 'Liked videos',
        thumbnailUrl: null,
        videoCount: null
      ),
    if (!hasWatchLater)
      (
        playlistId: 'WL',
        title: 'Watch later',
        thumbnailUrl: null,
        videoCount: null
      ),
    ...playlists,
  ];
});

/// The videos inside one playlist.
final playlistVideosProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, playlistId) async {
  final videos = await ref
      .watch(authenticatedClientProvider)
      .getPlaylistVideos(playlistId);
  if (videos != null && videos.isNotEmpty) {
    return _prepare(ref, videos, ContentSurface.channel);
  }

  final result =
      await ref.watch(contentRepositoryProvider).getPlaylist(playlistId);
  final group = result.dataOrNull;
  if (group == null) return const [];
  return _prepare(ref, group.mediaItems, ContentSurface.channel);
});

// ============================================================
// Sidebar categories
// ============================================================

/// One sidebar section's feed.
///
/// Three sources, in order of fidelity:
///   1. InnerTube `browse` on YouTube's own id for the section — this is
///      what its TV app does, and the only one that returns a real
///      "Live" or "Sports" feed.
///   2. InnerTube `search`, when the id has been retired.
///   3. youtube_explode's search, for signed-out use. It scrapes the
///      results page and throws outright on live-badge and shelf
///      renderers, so it is the last resort, not the default.
final browseCategoryProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, BrowseCategory>((ref, category) async {
  final client = ref.watch(authenticatedClientProvider);

  for (final browseId in category.browseIds) {
    final browsed = await client.browseVideos(browseId);
    if (browsed != null && browsed.isNotEmpty) {
      return _prepare(ref, browsed, ContentSurface.home);
    }
  }

  // YouTube retires browse ids without warning. Its own sidebar lists
  // the ones that currently work, so ask for that and take the entry
  // whose icon matches this section.
  final guide = await client.getGuideEntries();
  final match = guide?.where((e) => category.iconTypes.contains(e.iconType));
  if (match != null && match.isNotEmpty) {
    final videos = await client.browseVideos(match.first.browseId);
    if (videos != null && videos.isNotEmpty) {
      return _prepare(ref, videos, ContentSurface.home);
    }
  }

  final searched = await client.search(category.query);
  if (searched != null && searched.isNotEmpty) {
    return _prepare(ref, searched, ContentSurface.search);
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.search(category.query);
  final group = result.when(
    success: (group) => group,
    failure: (message, type, cause) => throw Exception(message),
  );
  return _prepare(ref, group.mediaItems, ContentSurface.search);
});

// ============================================================
// Search
// ============================================================

final searchQueryProvider = StateProvider<String>((ref) => '');

/// The filter panel's state. Changing it re-runs every search provider.
final searchFiltersProvider =
    StateProvider<SearchFilters>((ref) => const SearchFilters());

/// YouTube's own query completions for the text typed so far.
final searchSuggestionsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  try {
    return await ref
        .watch(youtubeExplodeProvider)
        .search
        .getQuerySuggestions(query);
  } catch (_) {
    // Suggestions are a nicety — never surface an error for them.
    return const [];
  }
});

/// The first page of results. [searchResultsPagedProvider] is what
/// scrolls; this stays for callers that just want one group.
final searchResultsProvider =
    FutureProvider.autoDispose.family<MediaGroup, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return const MediaGroup(
      title: '',
      type: MediaGroupType.search,
      mediaItems: [],
    );
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.search(
    query,
    filters: ref.watch(searchFiltersProvider),
  );

  final group = result.when(
    success: (group) => group,
    failure: (message, type, cause) => throw Exception(message),
  );
  return group.copyWith(
    mediaItems: await _prepare(ref, group.mediaItems, ContentSurface.search),
  );
});

/// Search results, one page at a time.
class SearchResultsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PagedFeed, String> {
  static const _surface = ContentSurface.search;

  final _seen = <String>{};
  String? _token;

  /// InnerTube continuation, for the signed-in path.
  String? _continuation;
  bool _viaAccount = false;

  /// Loads the next page of results and appends it.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      PagedFeed(items: current.items, hasMore: true, isLoadingMore: true),
    );
    state = AsyncData(
      await _appendPage(ref, current, _seen, _surface, _fetchNextPage),
    );
  }

  @override
  Future<PagedFeed> build(String query) async {
    _seen.clear();
    _token = null;
    _continuation = null;
    _viaAccount = false;
    if (query.trim().isEmpty) return PagedFeed.empty;

    final filters = ref.watch(searchFiltersProvider);

    // The signed-in path takes the same filters — `sp` on the website is
    // the `params` field of the InnerTube request.
    final page = await ref.watch(authenticatedClientProvider).searchPage(
          query,
          params: searchFilterFor(filters).value,
        );
    if (page != null && page.items.isNotEmpty) {
      _viaAccount = true;
      _continuation = page.continuation;
      return PagedFeed(
        items: await _prepare(ref, _fresh(page.items), _surface),
        hasMore: _continuation != null,
      );
    }

    final result = await ref
        .watch(contentRepositoryProvider)
        .search(query, filters: filters);
    final group = result.when(
      success: (group) => group,
      failure: (message, type, cause) => throw Exception(message),
    );
    _token = group.nextPageToken;
    return PagedFeed(
      items: await _prepare(ref, _fresh(group.mediaItems), _surface),
      hasMore: _token != null,
    );
  }

  List<MediaItem> _fresh(Iterable<MediaItem> items) =>
      items.where((item) => _seen.add(item.videoId)).toList();

  Future<List<MediaItem>?> _fetchNextPage() async {
    if (_viaAccount) {
      final continuation = _continuation;
      if (continuation == null) return null;
      final page = await ref
          .read(authenticatedClientProvider)
          .searchPage(arg, continuation: continuation);
      _continuation = page?.continuation;
      return page?.items;
    }

    final token = _token;
    if (token == null) return null;
    final result = await ref.read(contentRepositoryProvider).loadMore(token);
    final page = result.dataOrNull;
    _token = page?.nextPageToken;
    return page?.items;
  }
}

/// Search, paginated. Call
/// `ref.read(searchResultsPagedProvider(query).notifier).loadMore()`.
final searchResultsPagedProvider = AsyncNotifierProvider.autoDispose
    .family<SearchResultsNotifier, PagedFeed, String>(
  SearchResultsNotifier.new,
);

// ============================================================
// Related videos — YouTube's own "up next"
// ============================================================

/// The watch page's sidebar for [videoId]. This is the real related
/// list, not a text search for the title.
final relatedVideosProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, videoId) async {
  final result =
      await ref.watch(contentRepositoryProvider).getRelatedVideos(videoId);
  final page = result.when(
    success: (page) => page,
    failure: (message, type, cause) => throw Exception(message),
  );
  return _prepare(ref, page.items, ContentSurface.search);
});

// ============================================================
// Return YouTube Dislike — public like/dislike counts
// ============================================================

final videoVotesProvider =
    FutureProvider.autoDispose.family<VideoVotes?, String>((ref, videoId) {
  return ref.watch(returnDislikeServiceProvider).getVotes(videoId);
});

// ============================================================
// Channel
// ============================================================

/// One channel's uploads, one page at a time.
///
/// Deliberately separate from [channelInfoProvider]: the header wants
/// metadata and nothing else, the Videos tab wants uploads and nothing
/// else, and asking for them apart costs one request each — where the
/// old two-in-one channel provider fetched metadata again on every page.
class ChannelVideosNotifier
    extends AutoDisposeFamilyAsyncNotifier<PagedFeed, String> {
  static const _surface = ContentSurface.channel;

  final _seen = <String>{};
  String? _token;

  /// Loads the next page of uploads and appends it.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      PagedFeed(items: current.items, hasMore: true, isLoadingMore: true),
    );
    state = AsyncData(
      await _appendPage(ref, current, _seen, _surface, _fetchNextPage),
    );
  }

  @override
  Future<PagedFeed> build(String channelId) async {
    _seen.clear();
    _token = null;
    if (channelId.isEmpty) return PagedFeed.empty;

    final result =
        await ref.watch(contentRepositoryProvider).getChannelVideos(channelId);
    final page = result.when(
      success: (page) => page,
      failure: (message, type, cause) => throw Exception(message),
    );
    _token = page.nextPageToken;
    return PagedFeed(
      items: await _prepare(
        ref,
        page.items.where((item) => _seen.add(item.videoId)).toList(),
        _surface,
      ),
      hasMore: _token != null,
    );
  }

  Future<List<MediaItem>?> _fetchNextPage() async {
    final token = _token;
    if (token == null) return null;
    final result = await ref.read(contentRepositoryProvider).loadMore(token);
    final page = result.dataOrNull;
    _token = page?.nextPageToken;
    return page?.items;
  }
}

/// A channel's uploads, paginated. Call
/// `ref.read(channelVideosPagedProvider(id).notifier).loadMore()`.
final channelVideosPagedProvider = AsyncNotifierProvider.autoDispose
    .family<ChannelVideosNotifier, PagedFeed, String>(
  ChannelVideosNotifier.new,
);

/// The playlists a channel publishes.
///
/// Not paged — YouTube returns the whole Playlists tab in one response.
final channelPlaylistsProvider = FutureProvider.autoDispose
    .family<List<PlaylistInfo>, String>((ref, channelId) async {
  if (channelId.isEmpty) return const [];
  final result =
      await ref.watch(contentRepositoryProvider).getChannelPlaylists(channelId);
  return result.when(
    success: (playlists) => playlists,
    failure: (message, type, cause) => throw Exception(message),
  );
});

/// A channel's avatar, subscriber count and banner on their own.
///
/// This is what the player's channel row needs: it knows a channelId and
/// nothing else, and must not pay for a page of the channel's uploads to
/// print "1.2M subscribers".
final channelInfoProvider = FutureProvider.autoDispose
    .family<ChannelInfo, String>((ref, channelId) async {
  if (channelId.isEmpty) {
    throw ArgumentError('channelInfoProvider needs a channel id');
  }
  final result =
      await ref.watch(contentRepositoryProvider).getChannelInfo(channelId);
  return result.when(
    success: (info) => info,
    failure: (message, type, cause) => throw Exception(message),
  );
});
