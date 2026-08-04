// ============================================================
// ContentFilter — hide shorts / watched / upcoming, block channels
// ============================================================
// Ported from SmartTube's "Hide content" bitmask plus its blocked
// channel list. One place decides what never reaches a feed.
// ============================================================

import '../entities/media_item.dart';

/// The kinds of item a user can hide, per surface.
enum HiddenContent {
  shortsHome,
  shortsSubscriptions,
  shortsSearch,
  shortsChannel,
  watchedHome,
  watchedSubscriptions,
  upcomingHome,
  upcomingSubscriptions,
  streamsSubscriptions,
}

/// Which feed the filter is being applied to.
enum ContentSurface { home, subscriptions, search, channel, history }

/// Swaps the uploader's chosen thumbnail for an auto-extracted frame.
/// YouTube exposes three such frames per video under fixed filenames,
/// so this costs nothing but a URL rewrite.
enum ClickbaitThumbnail {
  original,
  start,
  middle,
  end;

  String? get _filename => switch (this) {
        ClickbaitThumbnail.original => null,
        ClickbaitThumbnail.start => 'hq1',
        ClickbaitThumbnail.middle => 'hq2',
        ClickbaitThumbnail.end => 'hq3',
      };

  static final _qualityPattern =
      RegExp(r'/(hq1|hq2|hq3|hqdefault|mqdefault|sddefault|hq720)\.');

  /// Rewrites [url] to point at this frame, or returns it unchanged.
  String? apply(String? url) {
    final replacement = _filename;
    if (url == null || replacement == null) return url;
    return url.replaceFirstMapped(
      _qualityPattern,
      (_) => '/$replacement.',
    );
  }
}

class ContentFilter {
  const ContentFilter({
    this.hidden = defaultHidden,
    this.blockedChannelIds = const {},
  });

  /// SmartTube's defaults: shorts out of Subscriptions and History,
  /// upcoming out of Home.
  static const defaultHidden = {
    HiddenContent.shortsSubscriptions,
    HiddenContent.upcomingHome,
  };

  /// A video is treated as watched past this much of its duration.
  static const watchedThresholdPercent = 80;

  final Set<HiddenContent> hidden;
  final Set<String> blockedChannelIds;

  ContentFilter copyWith({
    Set<HiddenContent>? hidden,
    Set<String>? blockedChannelIds,
  }) {
    return ContentFilter(
      hidden: hidden ?? this.hidden,
      blockedChannelIds: blockedChannelIds ?? this.blockedChannelIds,
    );
  }

  /// Removes everything the user asked not to see on [surface].
  List<MediaItem> apply(List<MediaItem> items, ContentSurface surface) {
    if (hidden.isEmpty && blockedChannelIds.isEmpty) return items;
    return items.where((item) => _keep(item, surface)).toList();
  }

  bool _keep(MediaItem item, ContentSurface surface) {
    if (_isBlocked(item)) return false;
    if (_isShorts(item) && hidden.contains(_shortsRuleFor(surface))) {
      return false;
    }
    if (item.isUpcoming && hidden.contains(_upcomingRuleFor(surface))) {
      return false;
    }
    if (item.isLive &&
        surface == ContentSurface.subscriptions &&
        hidden.contains(HiddenContent.streamsSubscriptions)) {
      return false;
    }
    if (_isWatched(item) && hidden.contains(_watchedRuleFor(surface))) {
      return false;
    }
    return true;
  }

  bool _isBlocked(MediaItem item) {
    if (blockedChannelIds.isEmpty) return false;
    return item.channelId.isNotEmpty &&
        blockedChannelIds.contains(item.channelId);
  }

  bool _isWatched(MediaItem item) {
    final percent = item.percentWatched;
    return percent != null && percent > watchedThresholdPercent && !item.isLive;
  }

  /// SmartTube's heuristic: YouTube tags sub-minute clips itself, so
  /// anything up to 90s counts, and up to 3 minutes when the title
  /// carries a hashtag.
  static bool _isShorts(MediaItem item) {
    if (item.isShorts) return true;
    final ms = item.duration.inMilliseconds;
    if (ms <= 0) return false;
    if (ms <= 90 * 1000) return true;
    return ms <= 180 * 1000 && item.title.contains('#');
  }

  static HiddenContent? _shortsRuleFor(ContentSurface surface) =>
      switch (surface) {
        ContentSurface.home => HiddenContent.shortsHome,
        ContentSurface.subscriptions => HiddenContent.shortsSubscriptions,
        ContentSurface.search => HiddenContent.shortsSearch,
        ContentSurface.channel => HiddenContent.shortsChannel,
        ContentSurface.history => null,
      };

  static HiddenContent? _watchedRuleFor(ContentSurface surface) =>
      switch (surface) {
        ContentSurface.home => HiddenContent.watchedHome,
        ContentSurface.subscriptions => HiddenContent.watchedSubscriptions,
        _ => null,
      };

  static HiddenContent? _upcomingRuleFor(ContentSurface surface) =>
      switch (surface) {
        ContentSurface.home => HiddenContent.upcomingHome,
        ContentSurface.subscriptions => HiddenContent.upcomingSubscriptions,
        _ => null,
      };
}
