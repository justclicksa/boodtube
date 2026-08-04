// ============================================================
// Content Providers (Home, Search, Channel)
// ============================================================
// FutureProviders للـ data fetching مع auto-dispose.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smarttube_poc/data/youtube/authenticated_client.dart';
import 'package:smarttube_poc/data/youtube/return_dislike_service.dart';
import 'package:smarttube_poc/domain/entities/content_filter.dart';
import 'package:smarttube_poc/domain/entities/media_group.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/domain/repositories/content_repository.dart' show ChannelContent;
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

/// Applies the user's filters and thumbnail preference to a feed.
List<MediaItem> _prepare(
  Ref ref,
  List<MediaItem> items,
  ContentSurface surface,
) {
  final filtered = ref.watch(contentFilterProvider).apply(items, surface);
  final style = ref.watch(settingsControllerProvider).clickbaitThumbnail;
  if (style == ClickbaitThumbnail.original) return filtered;
  return filtered
      .map((item) =>
          item.copyWith(thumbnailUrl: style.apply(item.thumbnailUrl)))
      .toList();
}

// ============================================================
// Home Feed
// ============================================================

final homeFeedProvider = FutureProvider.autoDispose<List<MediaGroup>>((ref) async {
  // Always ask the authenticated client first: it resolves a token from
  // secure storage itself and returns null when signed out, so this does
  // not depend on the sign-in state having been restored yet.
  final videos = await ref.watch(authenticatedClientProvider).getHomeFeed();
  if (videos != null && videos.isNotEmpty) {
    return [
      MediaGroup(
        title: 'Recommended',
        type: MediaGroupType.recommended,
        mediaItems: _prepare(ref, videos, ContentSurface.home),
      ),
    ];
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.getHomeFeed();

  return result.when(
    success: (groups) => [
      for (final group in groups)
        group.copyWith(
          mediaItems: _prepare(ref, group.mediaItems, ContentSurface.home),
        ),
    ],
    failure: (message, type, cause) {
      throw Exception(message);
    },
  );
});

// ============================================================
// Subscriptions feed — the account's, when signed in
// ============================================================

final subscriptionsFeedProvider =
    FutureProvider.autoDispose<List<MediaGroup>>((ref) async {
  final videos =
      await ref.watch(authenticatedClientProvider).getSubscriptionsFeed();
  if (videos != null && videos.isNotEmpty) {
    return [
      MediaGroup(
        title: 'Latest',
        type: MediaGroupType.subscriptions,
        mediaItems: _prepare(ref, videos, ContentSurface.subscriptions),
      ),
    ];
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.getSubscriptionsFeed();
  return result.when(
    success: (groups) => [
      for (final group in groups)
        group.copyWith(
          mediaItems:
              _prepare(ref, group.mediaItems, ContentSurface.subscriptions),
        ),
    ],
    failure: (message, type, cause) => throw Exception(message),
  );
});

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
      (playlistId: 'LL', title: 'Liked videos', thumbnailUrl: null,
          videoCount: null),
    if (!hasWatchLater)
      (playlistId: 'WL', title: 'Watch later', thumbnailUrl: null,
          videoCount: null),
    ...playlists,
  ];
});

/// The videos inside one playlist.
final playlistVideosProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, playlistId) async {
  final videos = await ref
      .watch(authenticatedClientProvider)
      .getPlaylistVideos(playlistId);
  return videos ?? const [];
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
  return result.when(
    success: (group) =>
        _prepare(ref, group.mediaItems, ContentSurface.search),
    failure: (message, type, cause) => throw Exception(message),
  );
});

// ============================================================
// Search
// ============================================================

final searchQueryProvider = StateProvider<String>((ref) => '');

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

final searchResultsProvider = FutureProvider.autoDispose
    .family<MediaGroup, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return const MediaGroup(
      title: '',
      type: MediaGroupType.search,
      mediaItems: [],
    );
  }

  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.search(query);

  return result.when(
    success: (group) => group.copyWith(
      mediaItems: _prepare(ref, group.mediaItems, ContentSurface.search),
    ),
    failure: (message, type, cause) {
      throw Exception(message);
    },
  );
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

final channelProvider = FutureProvider.autoDispose
    .family<ChannelContent, String>((ref, channelId) async {
  final repo = ref.watch(contentRepositoryProvider);
  final result = await repo.getChannel(channelId);

  return result.when(
    success: (content) => content,
    failure: (message, type, cause) {
      throw Exception(message);
    },
  );
});
