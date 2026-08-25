import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BoodTube'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @searchTab.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTab;

  /// No description provided for @subscriptionsTab.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTab;

  /// No description provided for @libraryTab.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @playVideo.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playVideo;

  /// No description provided for @pauseVideo.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseVideo;

  /// No description provided for @skipForward.
  ///
  /// In en, this message translates to:
  /// **'Skip forward 15 seconds'**
  String get skipForward;

  /// No description provided for @skipBackward.
  ///
  /// In en, this message translates to:
  /// **'Skip backward 5 seconds'**
  String get skipBackward;

  /// No description provided for @skipSponsor.
  ///
  /// In en, this message translates to:
  /// **'Skip Sponsor'**
  String get skipSponsor;

  /// No description provided for @qualityLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest (144p)'**
  String get qualityLowest;

  /// No description provided for @qualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low (240p)'**
  String get qualityLow;

  /// No description provided for @qualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (480p)'**
  String get qualityMedium;

  /// No description provided for @qualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High (720p)'**
  String get qualityHigh;

  /// No description provided for @qualityHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest (1080p+)'**
  String get qualityHighest;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best available'**
  String get qualityBest;

  /// No description provided for @qualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get qualityAuto;

  /// No description provided for @speedLabel.
  ///
  /// In en, this message translates to:
  /// **'{speed}x'**
  String speedLabel(String speed);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknown;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No watch history'**
  String get noHistory;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch Later is empty'**
  String get noWatchLater;

  /// No description provided for @noSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get noSubscriptions;

  /// No description provided for @emptyHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos you watch will appear here'**
  String get emptyHistorySubtitle;

  /// No description provided for @emptyFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any video to add it here'**
  String get emptyFavoritesSubtitle;

  /// No description provided for @emptyWatchLaterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save videos to watch later'**
  String get emptyWatchLaterSubtitle;

  /// No description provided for @emptySubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to channels to see their latest videos here'**
  String get emptySubscriptionsSubtitle;

  /// No description provided for @findChannels.
  ///
  /// In en, this message translates to:
  /// **'Find channels'**
  String get findChannels;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @generalSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSection;

  /// No description provided for @playerSection.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerSection;

  /// No description provided for @sponsorBlockSection.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock'**
  String get sponsorBlockSection;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @defaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default quality'**
  String get defaultQuality;

  /// No description provided for @defaultSpeed.
  ///
  /// In en, this message translates to:
  /// **'Default speed'**
  String get defaultSpeed;

  /// No description provided for @backgroundPlayback.
  ///
  /// In en, this message translates to:
  /// **'Background playback'**
  String get backgroundPlayback;

  /// No description provided for @backgroundPlaybackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue audio when screen is off'**
  String get backgroundPlaybackSubtitle;

  /// No description provided for @doubleTapToSeek.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to seek'**
  String get doubleTapToSeek;

  /// No description provided for @doubleTapToSeekSubtitle.
  ///
  /// In en, this message translates to:
  /// **'15s forward, 5s backward'**
  String get doubleTapToSeekSubtitle;

  /// No description provided for @pictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-Picture'**
  String get pictureInPicture;

  /// No description provided for @enableSponsorBlock.
  ///
  /// In en, this message translates to:
  /// **'Enable SponsorBlock'**
  String get enableSponsorBlock;

  /// No description provided for @enableSponsorBlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip sponsors, intros, outros automatically'**
  String get enableSponsorBlockSubtitle;

  /// No description provided for @autoSkipSponsors.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip'**
  String get autoSkipSponsors;

  /// No description provided for @autoSkipSponsorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip without showing a button'**
  String get autoSkipSponsorsSubtitle;

  /// No description provided for @sponsorSkipCategories.
  ///
  /// In en, this message translates to:
  /// **'Skip these categories:'**
  String get sponsorSkipCategories;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose theme'**
  String get chooseTheme;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية (Arabic)'**
  String get arabic;

  /// No description provided for @shortsTab.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get shortsTab;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @topicAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get topicAll;

  /// No description provided for @topicMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get topicMusic;

  /// No description provided for @topicGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get topicGaming;

  /// No description provided for @topicLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get topicLive;

  /// No description provided for @topicNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get topicNews;

  /// No description provided for @topicTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get topicTechnology;

  /// No description provided for @topicSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get topicSports;

  /// No description provided for @topicCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get topicCooking;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @subscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get subscribed;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles / CC'**
  String get subtitles;

  /// No description provided for @repeatMode.
  ///
  /// In en, this message translates to:
  /// **'Repeat mode'**
  String get repeatMode;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @playbackQueue.
  ///
  /// In en, this message translates to:
  /// **'Playback queue'**
  String get playbackQueue;

  /// No description provided for @videoZoom.
  ///
  /// In en, this message translates to:
  /// **'Video zoom'**
  String get videoZoom;

  /// No description provided for @seekInterval.
  ///
  /// In en, this message translates to:
  /// **'Seek interval'**
  String get seekInterval;

  /// No description provided for @statsForNerds.
  ///
  /// In en, this message translates to:
  /// **'Stats for nerds'**
  String get statsForNerds;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @feedSection.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feedSection;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @thumbnails.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails'**
  String get thumbnails;

  /// No description provided for @deArrow.
  ///
  /// In en, this message translates to:
  /// **'DeArrow titles and thumbnails'**
  String get deArrow;

  /// No description provided for @deArrowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community alternatives to clickbait'**
  String get deArrowSubtitle;

  /// No description provided for @blockedChannels.
  ///
  /// In en, this message translates to:
  /// **'Blocked channels'**
  String get blockedChannels;

  /// No description provided for @unblockAll.
  ///
  /// In en, this message translates to:
  /// **'Unblock all'**
  String get unblockAll;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get noDownloads;

  /// No description provided for @noDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap Download on a video to watch it offline'**
  String get noDownloadsSubtitle;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @subscriptionsFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos from your subscriptions will show up here'**
  String get subscriptionsFeedEmpty;

  /// No description provided for @noChannelsYet.
  ///
  /// In en, this message translates to:
  /// **'No channels yet'**
  String get noChannelsYet;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @syncFromAccount.
  ///
  /// In en, this message translates to:
  /// **'Sync from my account'**
  String get syncFromAccount;

  /// No description provided for @nothingToShow.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get nothingToShow;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your subscriptions and playlists'**
  String get signInSubtitle;

  /// No description provided for @signedInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to manage your account or sign out'**
  String get signedInSubtitle;

  /// No description provided for @downloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos saved for offline playback'**
  String get downloadsSubtitle;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @noUpdatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No updates available'**
  String get noUpdatesAvailable;

  /// No description provided for @blockedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String blockedCount(int count);

  /// No description provided for @hideItem.
  ///
  /// In en, this message translates to:
  /// **'Hide {what}'**
  String hideItem(String what);

  /// No description provided for @hideShortsHome.
  ///
  /// In en, this message translates to:
  /// **'Shorts in Home'**
  String get hideShortsHome;

  /// No description provided for @hideShortsSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Shorts in Subscriptions'**
  String get hideShortsSubscriptions;

  /// No description provided for @hideShortsSearch.
  ///
  /// In en, this message translates to:
  /// **'Shorts in Search'**
  String get hideShortsSearch;

  /// No description provided for @hideShortsChannel.
  ///
  /// In en, this message translates to:
  /// **'Shorts on channels'**
  String get hideShortsChannel;

  /// No description provided for @hideWatchedHome.
  ///
  /// In en, this message translates to:
  /// **'watched videos in Home'**
  String get hideWatchedHome;

  /// No description provided for @hideWatchedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'watched videos in Subscriptions'**
  String get hideWatchedSubscriptions;

  /// No description provided for @hideUpcomingHome.
  ///
  /// In en, this message translates to:
  /// **'upcoming videos in Home'**
  String get hideUpcomingHome;

  /// No description provided for @hideUpcomingSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'upcoming videos in Subscriptions'**
  String get hideUpcomingSubscriptions;

  /// No description provided for @hideStreamsSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'live streams in Subscriptions'**
  String get hideStreamsSubscriptions;

  /// No description provided for @thumbnailOriginal.
  ///
  /// In en, this message translates to:
  /// **'Uploader\'s thumbnail'**
  String get thumbnailOriginal;

  /// No description provided for @thumbnailStart.
  ///
  /// In en, this message translates to:
  /// **'Frame near the start'**
  String get thumbnailStart;

  /// No description provided for @thumbnailMiddle.
  ///
  /// In en, this message translates to:
  /// **'Frame from the middle'**
  String get thumbnailMiddle;

  /// No description provided for @thumbnailEnd.
  ///
  /// In en, this message translates to:
  /// **'Frame near the end'**
  String get thumbnailEnd;

  /// No description provided for @categorySponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get categorySponsor;

  /// No description provided for @categoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get categoryIntro;

  /// No description provided for @categoryOutro.
  ///
  /// In en, this message translates to:
  /// **'Outro'**
  String get categoryOutro;

  /// No description provided for @categorySelfPromo.
  ///
  /// In en, this message translates to:
  /// **'Self-promotion'**
  String get categorySelfPromo;

  /// No description provided for @categoryInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction reminder'**
  String get categoryInteraction;

  /// No description provided for @categoryHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get categoryHighlight;

  /// No description provided for @categoryPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get categoryPreview;

  /// No description provided for @categoryMusicOffTopic.
  ///
  /// In en, this message translates to:
  /// **'Music (off-topic)'**
  String get categoryMusicOffTopic;

  /// No description provided for @categoryFiller.
  ///
  /// In en, this message translates to:
  /// **'Filler'**
  String get categoryFiller;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Stop playback after one video'**
  String get repeatNone;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat current video'**
  String get repeatOne;

  /// No description provided for @repeatPause.
  ///
  /// In en, this message translates to:
  /// **'Pause playback after each video'**
  String get repeatPause;

  /// No description provided for @repeatNoneShort.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get repeatNoneShort;

  /// No description provided for @repeatOneShort.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOneShort;

  /// No description provided for @repeatPauseShort.
  ///
  /// In en, this message translates to:
  /// **'Pause at end'**
  String get repeatPauseShort;

  /// No description provided for @fitDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get fitDefault;

  /// No description provided for @fitWidth.
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get fitWidth;

  /// No description provided for @fitHeight.
  ///
  /// In en, this message translates to:
  /// **'Fit height'**
  String get fitHeight;

  /// No description provided for @fitStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get fitStretch;

  /// No description provided for @fitZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom (crop)'**
  String get fitZoom;

  /// No description provided for @noAlternativesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No alternatives available'**
  String get noAlternativesAvailable;

  /// No description provided for @autoGenerated.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get autoGenerated;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} min left'**
  String minutesLeft(int count);

  /// No description provided for @pausingIn.
  ///
  /// In en, this message translates to:
  /// **'Pausing in {count} minutes'**
  String pausingIn(int count);

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} sec'**
  String secondsShort(int count);

  /// No description provided for @percentBoost.
  ///
  /// In en, this message translates to:
  /// **'{percent}% (boost)'**
  String percentBoost(int percent);

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String percentValue(int percent);

  /// No description provided for @volumeBoostWarning.
  ///
  /// In en, this message translates to:
  /// **'Levels above 100% amplify the audio and can distort loud sources.'**
  String get volumeBoostWarning;

  /// No description provided for @skipAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Skip automatically'**
  String get skipAutomatically;

  /// No description provided for @skipAutomaticallySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Otherwise a Skip button appears'**
  String get skipAutomaticallySubtitle;

  /// No description provided for @autoSkip.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip'**
  String get autoSkip;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @clearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get clearQueue;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @videoIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Video ID'**
  String get videoIdLabel;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @codec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get codec;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @audioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get audioTrack;

  /// No description provided for @muxedWithVideo.
  ///
  /// In en, this message translates to:
  /// **'muxed with video'**
  String get muxedWithVideo;

  /// No description provided for @separateStream.
  ///
  /// In en, this message translates to:
  /// **'separate stream'**
  String get separateStream;

  /// No description provided for @buffered.
  ///
  /// In en, this message translates to:
  /// **'Buffered'**
  String get buffered;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @sponsorSegments.
  ///
  /// In en, this message translates to:
  /// **'Sponsor segments'**
  String get sponsorSegments;

  /// No description provided for @switchingQuality.
  ///
  /// In en, this message translates to:
  /// **'Switching to {quality}…'**
  String switchingQuality(String quality);

  /// No description provided for @syncedChannels.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} channels'**
  String syncedChannels(int count);

  /// No description provided for @couldNotReadSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Could not read your subscriptions'**
  String get couldNotReadSubscriptions;

  /// No description provided for @signInToUseAccount.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to channels, or sign in to use your account'**
  String get signInToUseAccount;

  /// No description provided for @noChannelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe from a channel page, or sync your account'**
  String get noChannelsSubtitle;

  /// No description provided for @unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get unsubscribe;

  /// No description provided for @subscriberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subscribers'**
  String subscriberCount(String count);

  /// No description provided for @allSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allSubscriptions;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @gaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get gaming;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @watchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch later'**
  String get watchLater;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @myChannel.
  ///
  /// In en, this message translates to:
  /// **'Your channel'**
  String get myChannel;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @viewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String viewsCount(String count);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String yearsAgo(int count);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String monthsAgo(int count);

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String weeksAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noComments;

  /// No description provided for @noCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment'**
  String get noCommentsSubtitle;

  /// No description provided for @unsubscribed.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed'**
  String get unsubscribed;

  /// No description provided for @noVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos'**
  String get noVideos;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylists;

  /// No description provided for @channelHasNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'This channel hasn\'t published any playlists'**
  String get channelHasNoPlaylists;

  /// No description provided for @channelIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel ID'**
  String get channelIdLabel;

  /// No description provided for @subscribers.
  ///
  /// In en, this message translates to:
  /// **'Subscribers'**
  String get subscribers;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval…'**
  String get waitingForApproval;

  /// No description provided for @getSignInCode.
  ///
  /// In en, this message translates to:
  /// **'Get a sign-in code'**
  String get getSignInCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @signInUnofficialWarning.
  ///
  /// In en, this message translates to:
  /// **'This app is not an official YouTube client. Google may restrict or suspend accounts used with unofficial clients. Consider using a secondary account.'**
  String get signInUnofficialWarning;

  /// No description provided for @signInStepOpenPage.
  ///
  /// In en, this message translates to:
  /// **'1. Open this page on any device'**
  String get signInStepOpenPage;

  /// No description provided for @signInStepEnterCode.
  ///
  /// In en, this message translates to:
  /// **'2. Enter this code'**
  String get signInStepEnterCode;

  /// No description provided for @signedInKeystoreNote.
  ///
  /// In en, this message translates to:
  /// **'The session refreshes automatically. Your token is stored in the device keystore and never leaves this phone.'**
  String get signedInKeystoreNote;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @streamCapped.
  ///
  /// In en, this message translates to:
  /// **'YouTube stopped serving this video part-way through. It is usually restricted — try another quality, or another video.'**
  String get streamCapped;

  /// No description provided for @noPlaylistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists you create on YouTube show up here'**
  String get noPlaylistsSubtitle;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @historySynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} videos from your account'**
  String historySynced(int count);

  /// No description provided for @videoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video} other{{count} videos}}'**
  String videoCount(int count);

  /// No description provided for @liveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This broadcast is not available — it may have ended, or be limited to members.'**
  String get liveUnavailable;

  /// No description provided for @searchYouTube.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube…'**
  String get searchYouTube;

  /// No description provided for @pipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-picture is not available here'**
  String get pipUnavailable;

  /// No description provided for @skipCategory.
  ///
  /// In en, this message translates to:
  /// **'Skip {category}'**
  String skipCategory(String category);

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @searchFilterUploadDate.
  ///
  /// In en, this message translates to:
  /// **'Upload date'**
  String get searchFilterUploadDate;

  /// No description provided for @searchFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get searchFilterType;

  /// No description provided for @searchFilterDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get searchFilterDuration;

  /// No description provided for @searchFilterSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get searchFilterSortBy;

  /// No description provided for @searchFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get searchFilterAny;

  /// No description provided for @uploadDateLastHour.
  ///
  /// In en, this message translates to:
  /// **'Last hour'**
  String get uploadDateLastHour;

  /// No description provided for @uploadDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get uploadDateToday;

  /// No description provided for @uploadDateThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get uploadDateThisWeek;

  /// No description provided for @uploadDateThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get uploadDateThisMonth;

  /// No description provided for @uploadDateThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get uploadDateThisYear;

  /// No description provided for @searchTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get searchTypeVideo;

  /// No description provided for @searchTypeMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get searchTypeMovie;

  /// No description provided for @searchDurationShort.
  ///
  /// In en, this message translates to:
  /// **'Under 4 minutes'**
  String get searchDurationShort;

  /// No description provided for @searchDurationMedium.
  ///
  /// In en, this message translates to:
  /// **'4–20 minutes'**
  String get searchDurationMedium;

  /// No description provided for @searchDurationLong.
  ///
  /// In en, this message translates to:
  /// **'Over 20 minutes'**
  String get searchDurationLong;

  /// No description provided for @sortByRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get sortByRelevance;

  /// No description provided for @sortByUploadDate.
  ///
  /// In en, this message translates to:
  /// **'Upload date'**
  String get sortByUploadDate;

  /// No description provided for @sortByViewCount.
  ///
  /// In en, this message translates to:
  /// **'View count'**
  String get sortByViewCount;

  /// No description provided for @sortByRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sortByRating;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @activeFilterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 filter} other{{count} filters}}'**
  String activeFilterCount(int count);

  /// No description provided for @noResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try different keywords, or clear your filters.'**
  String get noResultsSubtitle;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get removeFromHistory;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Content not found'**
  String get errorNotFound;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You need to sign in to view this'**
  String get errorUnauthorized;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests — try again in a moment'**
  String get errorRateLimited;

  /// No description provided for @errorParse.
  ///
  /// In en, this message translates to:
  /// **'YouTube sent something we could not read'**
  String get errorParse;

  /// No description provided for @errorDatabase.
  ///
  /// In en, this message translates to:
  /// **'Could not read local data'**
  String get errorDatabase;

  /// No description provided for @errorYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube could not load this right now'**
  String get errorYouTube;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get offlineTitle;

  /// No description provided for @offlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection…'**
  String get offlineSubtitle;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// No description provided for @noSettingsMatch.
  ///
  /// In en, this message translates to:
  /// **'No settings match \"{query}\"'**
  String noSettingsMatch(String query);

  /// No description provided for @updateCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Automatic update checks aren\'t available in this build'**
  String get updateCheckUnavailable;

  /// No description provided for @shortsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Shorts available right now'**
  String get shortsEmpty;

  /// No description provided for @shortsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load Shorts'**
  String get shortsLoadFailed;

  /// No description provided for @shortsDislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get shortsDislike;

  /// No description provided for @shortsOpenChannel.
  ///
  /// In en, this message translates to:
  /// **'Open channel'**
  String get shortsOpenChannel;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @videoOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get videoOptions;

  /// No description provided for @notInterested.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get notInterested;

  /// No description provided for @blockChannel.
  ///
  /// In en, this message translates to:
  /// **'Don\'t recommend this channel'**
  String get blockChannel;

  /// No description provided for @goToChannel.
  ///
  /// In en, this message translates to:
  /// **'Go to channel'**
  String get goToChannel;

  /// No description provided for @miniPlayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {title}'**
  String miniPlayerLabel(String title);

  /// No description provided for @seekSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String seekSeconds(int count);

  /// No description provided for @viewReplies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View 1 reply} other{View {count} replies}}'**
  String viewReplies(int count);

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatching;

  /// No description provided for @streamClient.
  ///
  /// In en, this message translates to:
  /// **'Playback client'**
  String get streamClient;

  /// No description provided for @failedClients.
  ///
  /// In en, this message translates to:
  /// **'Rejected clients'**
  String get failedClients;

  /// No description provided for @networkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Network speed'**
  String get networkSpeed;

  /// No description provided for @automaticRecoveries.
  ///
  /// In en, this message translates to:
  /// **'Automatic recoveries'**
  String get automaticRecoveries;

  /// No description provided for @fallbackReason.
  ///
  /// In en, this message translates to:
  /// **'Fallback reason'**
  String get fallbackReason;

  /// No description provided for @noFallback.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noFallback;

  /// No description provided for @playerShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Player shortcuts'**
  String get playerShortcuts;

  /// No description provided for @playerShortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose and order the buttons shown over the video'**
  String get playerShortcutsSubtitle;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recommendations yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh the feed or choose a topic to start exploring'**
  String get homeEmptySubtitle;

  /// No description provided for @refreshFeed.
  ///
  /// In en, this message translates to:
  /// **'Refresh feed'**
  String get refreshFeed;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupAndRestore;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @exportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save settings, blocked channels, subscriptions, favorites and history'**
  String get exportBackupSubtitle;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace local settings and library from a BoodTube backup'**
  String get restoreBackupSubtitle;

  /// No description provided for @restoreBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'This replaces the local history, subscriptions, favorites and Watch later list. Downloads are not changed.'**
  String get restoreBackupConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored successfully'**
  String get backupRestored;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be processed'**
  String get backupFailed;

  /// No description provided for @liveChat.
  ///
  /// In en, this message translates to:
  /// **'Live chat'**
  String get liveChat;

  /// No description provided for @liveChatWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new messages…'**
  String get liveChatWaiting;

  /// No description provided for @liveChatReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only live conversation'**
  String get liveChatReadOnly;

  /// No description provided for @castToTv.
  ///
  /// In en, this message translates to:
  /// **'Cast to TV'**
  String get castToTv;

  /// No description provided for @castScanning.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices on your Wi-Fi…'**
  String get castScanning;

  /// No description provided for @castNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No Cast devices found'**
  String get castNoDevices;

  /// No description provided for @castFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start casting'**
  String get castFailed;

  /// No description provided for @subtitleAppearance.
  ///
  /// In en, this message translates to:
  /// **'Subtitle appearance'**
  String get subtitleAppearance;

  /// No description provided for @subtitleSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get subtitleSize;

  /// No description provided for @subtitlePosition.
  ///
  /// In en, this message translates to:
  /// **'Vertical position'**
  String get subtitlePosition;

  /// No description provided for @subtitleBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get subtitleBackground;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get addedToQueue;

  /// No description provided for @autoplayNext.
  ///
  /// In en, this message translates to:
  /// **'Autoplay'**
  String get autoplayNext;

  /// No description provided for @autoplayNextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with the next suggested video'**
  String get autoplayNextSubtitle;

  /// No description provided for @autoQuality.
  ///
  /// In en, this message translates to:
  /// **'Auto quality'**
  String get autoQuality;

  /// No description provided for @autoQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick resolution from your connection speed'**
  String get autoQualitySubtitle;

  /// No description provided for @autoQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoQualityLabel;

  /// No description provided for @adaptiveStreaming.
  ///
  /// In en, this message translates to:
  /// **'Adaptive streaming (DASH)'**
  String get adaptiveStreaming;

  /// No description provided for @adaptiveStreamingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental: let the player combine video and audio itself'**
  String get adaptiveStreamingSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
