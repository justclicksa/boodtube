// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BoodTube';

  @override
  String get homeTab => 'Home';

  @override
  String get searchTab => 'Search';

  @override
  String get subscriptionsTab => 'Subscriptions';

  @override
  String get libraryTab => 'Library';

  @override
  String get settingsTab => 'Settings';

  @override
  String get playVideo => 'Play';

  @override
  String get pauseVideo => 'Pause';

  @override
  String get skipForward => 'Skip forward 15 seconds';

  @override
  String get skipBackward => 'Skip backward 5 seconds';

  @override
  String get skipSponsor => 'Skip Sponsor';

  @override
  String get qualityLowest => 'Lowest (144p)';

  @override
  String get qualityLow => 'Low (240p)';

  @override
  String get qualityMedium => 'Medium (480p)';

  @override
  String get qualityHigh => 'High (720p)';

  @override
  String get qualityHighest => 'Highest (1080p+)';

  @override
  String get qualityBest => 'Best available';

  @override
  String get qualityAuto => 'Auto';

  @override
  String speedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get errorUnknown => 'Something went wrong';

  @override
  String get retry => 'Try again';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get noResults => 'No results found';

  @override
  String get noHistory => 'No watch history';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noWatchLater => 'Watch Later is empty';

  @override
  String get noSubscriptions => 'No subscriptions yet';

  @override
  String get emptyHistorySubtitle => 'Videos you watch will appear here';

  @override
  String get emptyFavoritesSubtitle =>
      'Tap the heart icon on any video to add it here';

  @override
  String get emptyWatchLaterSubtitle => 'Save videos to watch later';

  @override
  String get emptySubscriptionsSubtitle =>
      'Subscribe to channels to see their latest videos here';

  @override
  String get findChannels => 'Find channels';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get generalSection => 'General';

  @override
  String get playerSection => 'Player';

  @override
  String get sponsorBlockSection => 'SponsorBlock';

  @override
  String get aboutSection => 'About';

  @override
  String get defaultQuality => 'Default quality';

  @override
  String get defaultSpeed => 'Default speed';

  @override
  String get backgroundPlayback => 'Background playback';

  @override
  String get backgroundPlaybackSubtitle => 'Continue audio when screen is off';

  @override
  String get doubleTapToSeek => 'Double-tap to seek';

  @override
  String get doubleTapToSeekSubtitle => '15s forward, 5s backward';

  @override
  String get pictureInPicture => 'Picture-in-Picture';

  @override
  String get enableSponsorBlock => 'Enable SponsorBlock';

  @override
  String get enableSponsorBlockSubtitle =>
      'Skip sponsors, intros, outros automatically';

  @override
  String get autoSkipSponsors => 'Auto-skip';

  @override
  String get autoSkipSponsorsSubtitle => 'Skip without showing a button';

  @override
  String get sponsorSkipCategories => 'Skip these categories:';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get chooseTheme => 'Choose theme';

  @override
  String get followSystem => 'Follow system';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية (Arabic)';

  @override
  String get shortsTab => 'Shorts';

  @override
  String get search => 'Search';

  @override
  String get downloads => 'Downloads';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signedIn => 'Signed in';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearAll => 'Clear all';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get topicAll => 'All';

  @override
  String get topicMusic => 'Music';

  @override
  String get topicGaming => 'Gaming';

  @override
  String get topicLive => 'Live';

  @override
  String get topicNews => 'News';

  @override
  String get topicTechnology => 'Technology';

  @override
  String get topicSports => 'Sports';

  @override
  String get topicCooking => 'Cooking';

  @override
  String get like => 'Like';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get comments => 'Comments';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get subscribed => 'Subscribed';

  @override
  String get upNext => 'Up next';

  @override
  String get chapters => 'Chapters';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get quality => 'Quality';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get subtitles => 'Subtitles / CC';

  @override
  String get repeatMode => 'Repeat mode';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get volume => 'Volume';

  @override
  String get playbackQueue => 'Playback queue';

  @override
  String get videoZoom => 'Video zoom';

  @override
  String get seekInterval => 'Seek interval';

  @override
  String get statsForNerds => 'Stats for nerds';

  @override
  String get off => 'Off';

  @override
  String get normal => 'Normal';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get accountSection => 'Account';

  @override
  String get feedSection => 'Feed';

  @override
  String get theme => 'Theme';

  @override
  String get thumbnails => 'Thumbnails';

  @override
  String get deArrow => 'DeArrow titles and thumbnails';

  @override
  String get deArrowSubtitle => 'Community alternatives to clickbait';

  @override
  String get blockedChannels => 'Blocked channels';

  @override
  String get unblockAll => 'Unblock all';

  @override
  String get noDownloads => 'No downloads yet';

  @override
  String get noDownloadsSubtitle =>
      'Tap Download on a video to watch it offline';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get subscriptionsFeedEmpty =>
      'Videos from your subscriptions will show up here';

  @override
  String get noChannelsYet => 'No channels yet';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get latest => 'Latest';

  @override
  String get channels => 'Channels';

  @override
  String get syncFromAccount => 'Sync from my account';

  @override
  String get nothingToShow => 'Nothing to show';

  @override
  String get signInSubtitle => 'Use your subscriptions and playlists';

  @override
  String get signedInSubtitle => 'Tap to manage your account or sign out';

  @override
  String get downloadsSubtitle => 'Videos saved for offline playback';

  @override
  String get version => 'Version';

  @override
  String get noUpdatesAvailable => 'No updates available';

  @override
  String blockedCount(int count) {
    return '$count blocked';
  }

  @override
  String hideItem(String what) {
    return 'Hide $what';
  }

  @override
  String get hideShortsHome => 'Shorts in Home';

  @override
  String get hideShortsSubscriptions => 'Shorts in Subscriptions';

  @override
  String get hideShortsSearch => 'Shorts in Search';

  @override
  String get hideShortsChannel => 'Shorts on channels';

  @override
  String get hideWatchedHome => 'watched videos in Home';

  @override
  String get hideWatchedSubscriptions => 'watched videos in Subscriptions';

  @override
  String get hideUpcomingHome => 'upcoming videos in Home';

  @override
  String get hideUpcomingSubscriptions => 'upcoming videos in Subscriptions';

  @override
  String get hideStreamsSubscriptions => 'live streams in Subscriptions';

  @override
  String get thumbnailOriginal => 'Uploader\'s thumbnail';

  @override
  String get thumbnailStart => 'Frame near the start';

  @override
  String get thumbnailMiddle => 'Frame from the middle';

  @override
  String get thumbnailEnd => 'Frame near the end';

  @override
  String get categorySponsor => 'Sponsor';

  @override
  String get categoryIntro => 'Intro';

  @override
  String get categoryOutro => 'Outro';

  @override
  String get categorySelfPromo => 'Self-promotion';

  @override
  String get categoryInteraction => 'Interaction reminder';

  @override
  String get categoryHighlight => 'Highlight';

  @override
  String get categoryPreview => 'Preview';

  @override
  String get categoryMusicOffTopic => 'Music (off-topic)';

  @override
  String get categoryFiller => 'Filler';

  @override
  String get repeatNone => 'Stop playback after one video';

  @override
  String get repeatOne => 'Repeat current video';

  @override
  String get repeatPause => 'Pause playback after each video';

  @override
  String get repeatNoneShort => 'Off';

  @override
  String get repeatOneShort => 'Repeat one';

  @override
  String get repeatPauseShort => 'Pause at end';

  @override
  String get fitDefault => 'Default';

  @override
  String get fitWidth => 'Fit width';

  @override
  String get fitHeight => 'Fit height';

  @override
  String get fitStretch => 'Stretch';

  @override
  String get fitZoom => 'Zoom (crop)';

  @override
  String get noAlternativesAvailable => 'No alternatives available';

  @override
  String get autoGenerated => 'auto';

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String minutesLeft(int count) {
    return '$count min left';
  }

  @override
  String pausingIn(int count) {
    return 'Pausing in $count minutes';
  }

  @override
  String secondsShort(int count) {
    return '$count sec';
  }

  @override
  String percentBoost(int percent) {
    return '$percent% (boost)';
  }

  @override
  String percentValue(int percent) {
    return '$percent%';
  }

  @override
  String get volumeBoostWarning =>
      'Levels above 100% amplify the audio and can distort loud sources.';

  @override
  String get skipAutomatically => 'Skip automatically';

  @override
  String get skipAutomaticallySubtitle => 'Otherwise a Skip button appears';

  @override
  String get autoSkip => 'Auto-skip';

  @override
  String get manual => 'Manual';

  @override
  String get clearQueue => 'Clear queue';

  @override
  String get empty => 'Empty';

  @override
  String get videoIdLabel => 'Video ID';

  @override
  String get resolution => 'Resolution';

  @override
  String get codec => 'Codec';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get audioTrack => 'Audio track';

  @override
  String get muxedWithVideo => 'muxed with video';

  @override
  String get separateStream => 'separate stream';

  @override
  String get buffered => 'Buffered';

  @override
  String get speed => 'Speed';

  @override
  String get sponsorSegments => 'Sponsor segments';

  @override
  String switchingQuality(String quality) {
    return 'Switching to $quality…';
  }

  @override
  String syncedChannels(int count) {
    return 'Synced $count channels';
  }

  @override
  String get couldNotReadSubscriptions => 'Could not read your subscriptions';

  @override
  String get signInToUseAccount =>
      'Subscribe to channels, or sign in to use your account';

  @override
  String get noChannelsSubtitle =>
      'Subscribe from a channel page, or sync your account';

  @override
  String get unsubscribe => 'Unsubscribe';

  @override
  String subscriberCount(String count) {
    return '$count subscribers';
  }

  @override
  String get allSubscriptions => 'All';

  @override
  String get browse => 'Browse';

  @override
  String get you => 'You';

  @override
  String get trending => 'Trending';

  @override
  String get music => 'Music';

  @override
  String get gaming => 'Gaming';

  @override
  String get news => 'News';

  @override
  String get sports => 'Sports';

  @override
  String get live => 'Live';

  @override
  String get history => 'History';

  @override
  String get playlists => 'Playlists';

  @override
  String get watchLater => 'Watch later';

  @override
  String get favorites => 'Favorites';

  @override
  String get myChannel => 'Your channel';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String viewsCount(String count) {
    return '$count views';
  }

  @override
  String get justNow => 'just now';

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get noComments => 'No comments yet';

  @override
  String get noCommentsSubtitle => 'Be the first to comment';

  @override
  String get unsubscribed => 'Unsubscribed';

  @override
  String get noVideos => 'No videos';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String get channelHasNoPlaylists =>
      'This channel hasn\'t published any playlists';

  @override
  String get channelIdLabel => 'Channel ID';

  @override
  String get subscribers => 'Subscribers';

  @override
  String get waitingForApproval => 'Waiting for approval…';

  @override
  String get getSignInCode => 'Get a sign-in code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get signInUnofficialWarning =>
      'This app is not an official YouTube client. Google may restrict or suspend accounts used with unofficial clients. Consider using a secondary account.';

  @override
  String get signInStepOpenPage => '1. Open this page on any device';

  @override
  String get signInStepEnterCode => '2. Enter this code';

  @override
  String get signedInKeystoreNote =>
      'The session refreshes automatically. Your token is stored in the device keystore and never leaves this phone.';

  @override
  String get videos => 'Videos';

  @override
  String get streamCapped =>
      'YouTube stopped serving this video part-way through. It is usually restricted — try another quality, or another video.';

  @override
  String get noPlaylistsSubtitle =>
      'Playlists you create on YouTube show up here';

  @override
  String get syncing => 'Syncing…';

  @override
  String historySynced(int count) {
    return 'Synced $count videos from your account';
  }

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get liveUnavailable =>
      'This broadcast is not available — it may have ended, or be limited to members.';

  @override
  String get searchYouTube => 'Search YouTube…';

  @override
  String get pipUnavailable => 'Picture-in-picture is not available here';

  @override
  String skipCategory(String category) {
    return 'Skip $category';
  }

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchFilterUploadDate => 'Upload date';

  @override
  String get searchFilterType => 'Type';

  @override
  String get searchFilterDuration => 'Duration';

  @override
  String get searchFilterSortBy => 'Sort by';

  @override
  String get searchFilterAny => 'Any';

  @override
  String get uploadDateLastHour => 'Last hour';

  @override
  String get uploadDateToday => 'Today';

  @override
  String get uploadDateThisWeek => 'This week';

  @override
  String get uploadDateThisMonth => 'This month';

  @override
  String get uploadDateThisYear => 'This year';

  @override
  String get searchTypeVideo => 'Video';

  @override
  String get searchTypeMovie => 'Movie';

  @override
  String get searchDurationShort => 'Under 4 minutes';

  @override
  String get searchDurationMedium => '4–20 minutes';

  @override
  String get searchDurationLong => 'Over 20 minutes';

  @override
  String get sortByRelevance => 'Relevance';

  @override
  String get sortByUploadDate => 'Upload date';

  @override
  String get sortByViewCount => 'View count';

  @override
  String get sortByRating => 'Rating';

  @override
  String get resetFilters => 'Reset';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String activeFilterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters',
      one: '1 filter',
    );
    return '$_temp0';
  }

  @override
  String get noResultsSubtitle =>
      'Try different keywords, or clear your filters.';

  @override
  String get removeFromHistory => 'Remove from history';

  @override
  String get errorNotFound => 'Content not found';

  @override
  String get errorUnauthorized => 'You need to sign in to view this';

  @override
  String get errorRateLimited => 'Too many requests — try again in a moment';

  @override
  String get errorParse => 'YouTube sent something we could not read';

  @override
  String get errorDatabase => 'Could not read local data';

  @override
  String get errorYouTube => 'YouTube could not load this right now';

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get offlineSubtitle => 'Waiting for a connection…';

  @override
  String get backOnline => 'Back online';

  @override
  String get systemDefault => 'System default';

  @override
  String get searchSettings => 'Search settings';

  @override
  String noSettingsMatch(String query) {
    return 'No settings match \"$query\"';
  }

  @override
  String get updateCheckUnavailable =>
      'Automatic update checks aren\'t available in this build';

  @override
  String get shortsEmpty => 'No Shorts available right now';

  @override
  String get shortsLoadFailed => 'Couldn\'t load Shorts';

  @override
  String get shortsDislike => 'Dislike';

  @override
  String get shortsOpenChannel => 'Open channel';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get close => 'Close';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get videoOptions => 'More options';

  @override
  String get notInterested => 'Not interested';

  @override
  String get blockChannel => 'Don\'t recommend this channel';

  @override
  String get goToChannel => 'Go to channel';

  @override
  String miniPlayerLabel(String title) {
    return 'Now playing: $title';
  }

  @override
  String seekSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String viewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View $count replies',
      one: 'View 1 reply',
    );
    return '$_temp0';
  }

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get streamClient => 'Playback client';

  @override
  String get failedClients => 'Rejected clients';

  @override
  String get networkSpeed => 'Network speed';

  @override
  String get automaticRecoveries => 'Automatic recoveries';

  @override
  String get fallbackReason => 'Fallback reason';

  @override
  String get noFallback => 'None';

  @override
  String get playerShortcuts => 'Player shortcuts';

  @override
  String get playerShortcutsSubtitle =>
      'Choose and order the buttons shown over the video';

  @override
  String get homeEmptyTitle => 'No recommendations yet';

  @override
  String get homeEmptySubtitle =>
      'Refresh the feed or choose a topic to start exploring';

  @override
  String get refreshFeed => 'Refresh feed';

  @override
  String get backupAndRestore => 'Backup and restore';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get exportBackupSubtitle =>
      'Save settings, blocked channels, subscriptions, favorites and history';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get restoreBackupSubtitle =>
      'Replace local settings and library from a BoodTube backup';

  @override
  String get restoreBackupConfirm =>
      'This replaces the local history, subscriptions, favorites and Watch later list. Downloads are not changed.';

  @override
  String get backupRestored => 'Backup restored successfully';

  @override
  String get backupFailed => 'The backup could not be processed';

  @override
  String get liveChat => 'Live chat';

  @override
  String get liveChatWaiting => 'Waiting for new messages…';

  @override
  String get liveChatReadOnly => 'Read-only live conversation';

  @override
  String get castToTv => 'Cast to TV';

  @override
  String get castScanning => 'Looking for devices on your Wi-Fi…';

  @override
  String get castNoDevices => 'No Cast devices found';

  @override
  String get castFailed => 'Could not start casting';

  @override
  String get subtitleAppearance => 'Subtitle appearance';

  @override
  String get subtitleSize => 'Text size';

  @override
  String get subtitlePosition => 'Vertical position';

  @override
  String get subtitleBackground => 'Background';

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get autoplayNext => 'Autoplay';

  @override
  String get autoplayNextSubtitle => 'Continue with the next suggested video';

  @override
  String get autoQuality => 'Auto quality';

  @override
  String get autoQualitySubtitle =>
      'Pick resolution from your connection speed';

  @override
  String get autoQualityLabel => 'Auto';
}
