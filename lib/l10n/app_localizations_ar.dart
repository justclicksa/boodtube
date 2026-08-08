// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'بود تيوب';

  @override
  String get homeTab => 'الرئيسية';

  @override
  String get searchTab => 'البحث';

  @override
  String get subscriptionsTab => 'الاشتراكات';

  @override
  String get libraryTab => 'المكتبة';

  @override
  String get settingsTab => 'الإعدادات';

  @override
  String get playVideo => 'تشغيل';

  @override
  String get pauseVideo => 'إيقاف مؤقت';

  @override
  String get skipForward => 'تقديم 15 ثانية';

  @override
  String get skipBackward => 'إرجاع 5 ثوانٍ';

  @override
  String get skipSponsor => 'تخطي الإعلان';

  @override
  String get qualityLowest => 'الأدنى (144p)';

  @override
  String get qualityLow => 'منخفضة (240p)';

  @override
  String get qualityMedium => 'متوسطة (480p)';

  @override
  String get qualityHigh => 'عالية (720p)';

  @override
  String get qualityHighest => 'الأعلى (1080p فأكثر)';

  @override
  String get qualityBest => 'أفضل جودة متاحة';

  @override
  String get qualityAuto => 'تلقائي';

  @override
  String speedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String get errorNetwork => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorUnknown => 'حدث خطأ ما';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get noHistory => 'لا يوجد سجل مشاهدة';

  @override
  String get noFavorites => 'لا توجد مفضلات بعد';

  @override
  String get noWatchLater => 'قائمة المشاهدة لاحقًا فارغة';

  @override
  String get noSubscriptions => 'لا توجد اشتراكات بعد';

  @override
  String get emptyHistorySubtitle => 'ستظهر هنا المقاطع التي تشاهدها';

  @override
  String get emptyFavoritesSubtitle =>
      'اضغط أيقونة القلب على أي مقطع لإضافته هنا';

  @override
  String get emptyWatchLaterSubtitle => 'احفظ المقاطع لمشاهدتها لاحقًا';

  @override
  String get emptySubscriptionsSubtitle =>
      'اشترك في القنوات لتظهر أحدث مقاطعها هنا';

  @override
  String get findChannels => 'ابحث عن قنوات';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get language => 'اللغة';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get generalSection => 'عام';

  @override
  String get playerSection => 'المشغّل';

  @override
  String get sponsorBlockSection => 'حظر الرعايات';

  @override
  String get aboutSection => 'حول التطبيق';

  @override
  String get defaultQuality => 'الجودة الافتراضية';

  @override
  String get defaultSpeed => 'السرعة الافتراضية';

  @override
  String get backgroundPlayback => 'التشغيل في الخلفية';

  @override
  String get backgroundPlaybackSubtitle => 'متابعة الصوت عند إطفاء الشاشة';

  @override
  String get doubleTapToSeek => 'النقر المزدوج للتنقل';

  @override
  String get doubleTapToSeekSubtitle => '15 ثانية للأمام، 5 ثوانٍ للخلف';

  @override
  String get pictureInPicture => 'صورة داخل صورة';

  @override
  String get enableSponsorBlock => 'تفعيل حظر الرعايات';

  @override
  String get enableSponsorBlockSubtitle =>
      'تخطي الرعايات والمقدمات والخواتيم تلقائيًا';

  @override
  String get autoSkipSponsors => 'التخطي التلقائي';

  @override
  String get autoSkipSponsorsSubtitle => 'التخطي دون إظهار زر';

  @override
  String get sponsorSkipCategories => 'تخطَّ هذه الفئات:';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get openSourceLicenses => 'تراخيص المصادر المفتوحة';

  @override
  String get chooseTheme => 'اختيار المظهر';

  @override
  String get followSystem => 'حسب النظام';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get shortsTab => 'شورتس';

  @override
  String get search => 'بحث';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signedIn => 'تم تسجيل الدخول';

  @override
  String get cancel => 'إلغاء';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get topicAll => 'الكل';

  @override
  String get topicMusic => 'موسيقى';

  @override
  String get topicGaming => 'ألعاب';

  @override
  String get topicLive => 'بث مباشر';

  @override
  String get topicNews => 'أخبار';

  @override
  String get topicTechnology => 'تقنية';

  @override
  String get topicSports => 'رياضة';

  @override
  String get topicCooking => 'طبخ';

  @override
  String get like => 'إعجاب';

  @override
  String get share => 'مشاركة';

  @override
  String get save => 'حفظ';

  @override
  String get download => 'تنزيل';

  @override
  String get downloaded => 'تم التنزيل';

  @override
  String get comments => 'التعليقات';

  @override
  String get subscribe => 'اشتراك';

  @override
  String get subscribed => 'مشترك';

  @override
  String get upNext => 'التالي';

  @override
  String get chapters => 'الفصول';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String get downloadStarted => 'بدأ التنزيل';

  @override
  String get quality => 'الجودة';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get subtitles => 'الترجمة / CC';

  @override
  String get repeatMode => 'وضع التكرار';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String get volume => 'مستوى الصوت';

  @override
  String get playbackQueue => 'قائمة التشغيل';

  @override
  String get videoZoom => 'تكبير الفيديو';

  @override
  String get seekInterval => 'مقدار التنقل';

  @override
  String get statsForNerds => 'إحصائيات تفصيلية';

  @override
  String get off => 'إيقاف';

  @override
  String get normal => 'عادي';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get accountSection => 'الحساب';

  @override
  String get feedSection => 'المحتوى';

  @override
  String get theme => 'المظهر';

  @override
  String get thumbnails => 'الصور المصغّرة';

  @override
  String get deArrow => 'عناوين وصور DeArrow';

  @override
  String get deArrowSubtitle => 'بدائل مجتمعية للعناوين المضللة';

  @override
  String get blockedChannels => 'القنوات المحظورة';

  @override
  String get unblockAll => 'إلغاء حظر الكل';

  @override
  String get noDownloads => 'لا توجد تنزيلات بعد';

  @override
  String get noDownloadsSubtitle => 'اضغط تنزيل على أي مقطع لمشاهدته دون اتصال';

  @override
  String get nothingHereYet => 'لا يوجد شيء هنا بعد';

  @override
  String get subscriptionsFeedEmpty => 'ستظهر هنا مقاطع القنوات التي تشترك بها';

  @override
  String get noChannelsYet => 'لا توجد قنوات بعد';

  @override
  String get recentSearches => 'عمليات البحث الأخيرة';

  @override
  String get latest => 'الأحدث';

  @override
  String get channels => 'القنوات';

  @override
  String get syncFromAccount => 'مزامنة من حسابي';

  @override
  String get nothingToShow => 'لا يوجد محتوى لعرضه';

  @override
  String get signInSubtitle => 'استخدم اشتراكاتك وقوائم التشغيل الخاصة بك';

  @override
  String get signedInSubtitle => 'اضغط لإدارة حسابك أو تسجيل الخروج';

  @override
  String get downloadsSubtitle => 'مقاطع محفوظة للتشغيل دون اتصال';

  @override
  String get version => 'الإصدار';

  @override
  String get noUpdatesAvailable => 'لا توجد تحديثات متاحة';

  @override
  String blockedCount(int count) {
    return '$count محظورة';
  }

  @override
  String hideItem(String what) {
    return 'إخفاء $what';
  }

  @override
  String get hideShortsHome => 'الشورتس في الرئيسية';

  @override
  String get hideShortsSubscriptions => 'الشورتس في الاشتراكات';

  @override
  String get hideShortsSearch => 'الشورتس في البحث';

  @override
  String get hideShortsChannel => 'الشورتس في القنوات';

  @override
  String get hideWatchedHome => 'المقاطع المُشاهَدة في الرئيسية';

  @override
  String get hideWatchedSubscriptions => 'المقاطع المُشاهَدة في الاشتراكات';

  @override
  String get hideUpcomingHome => 'المقاطع القادمة في الرئيسية';

  @override
  String get hideUpcomingSubscriptions => 'المقاطع القادمة في الاشتراكات';

  @override
  String get hideStreamsSubscriptions => 'البث المباشر في الاشتراكات';

  @override
  String get thumbnailOriginal => 'صورة الناشر';

  @override
  String get thumbnailStart => 'لقطة من بداية المقطع';

  @override
  String get thumbnailMiddle => 'لقطة من منتصف المقطع';

  @override
  String get thumbnailEnd => 'لقطة من نهاية المقطع';

  @override
  String get categorySponsor => 'رعاية إعلانية';

  @override
  String get categoryIntro => 'المقدمة';

  @override
  String get categoryOutro => 'الخاتمة';

  @override
  String get categorySelfPromo => 'ترويج ذاتي';

  @override
  String get categoryInteraction => 'التذكير بالتفاعل';

  @override
  String get categoryHighlight => 'أبرز اللحظات';

  @override
  String get categoryPreview => 'معاينة';

  @override
  String get categoryMusicOffTopic => 'مقاطع غير موسيقية';

  @override
  String get categoryFiller => 'محتوى حشو';

  @override
  String get repeatNone => 'إيقاف التشغيل بعد مقطع واحد';

  @override
  String get repeatOne => 'تكرار المقطع الحالي';

  @override
  String get repeatPause => 'الإيقاف المؤقت بعد كل مقطع';

  @override
  String get repeatNoneShort => 'إيقاف';

  @override
  String get repeatOneShort => 'تكرار المقطع';

  @override
  String get repeatPauseShort => 'توقف عند النهاية';

  @override
  String get fitDefault => 'افتراضي';

  @override
  String get fitWidth => 'ملء العرض';

  @override
  String get fitHeight => 'ملء الارتفاع';

  @override
  String get fitStretch => 'تمديد';

  @override
  String get fitZoom => 'تكبير (اقتصاص)';

  @override
  String get noAlternativesAvailable => 'لا توجد جودات أخرى متاحة';

  @override
  String get autoGenerated => 'تلقائية';

  @override
  String minutesShort(int count) {
    return '$count دقيقة';
  }

  @override
  String minutesLeft(int count) {
    return 'بقي $count دقيقة';
  }

  @override
  String pausingIn(int count) {
    return 'سيتوقف بعد $count دقيقة';
  }

  @override
  String secondsShort(int count) {
    return '$count ثانية';
  }

  @override
  String percentBoost(int percent) {
    return '$percent% (تضخيم)';
  }

  @override
  String percentValue(int percent) {
    return '$percent%';
  }

  @override
  String get volumeBoostWarning =>
      'المستويات فوق 100% تضخّم الصوت وقد تُحدث تشويشًا في المصادر العالية.';

  @override
  String get skipAutomatically => 'التخطي تلقائيًا';

  @override
  String get skipAutomaticallySubtitle => 'وإلا سيظهر زر التخطي';

  @override
  String get autoSkip => 'تلقائي';

  @override
  String get manual => 'يدوي';

  @override
  String get clearQueue => 'إفراغ القائمة';

  @override
  String get empty => 'فارغة';

  @override
  String get videoIdLabel => 'معرّف المقطع';

  @override
  String get resolution => 'الدقة';

  @override
  String get codec => 'الترميز';

  @override
  String get bitrate => 'معدل البت';

  @override
  String get audioTrack => 'مسار الصوت';

  @override
  String get muxedWithVideo => 'مدمج مع الفيديو';

  @override
  String get separateStream => 'مسار منفصل';

  @override
  String get buffered => 'المخزَّن مؤقتًا';

  @override
  String get speed => 'السرعة';

  @override
  String get sponsorSegments => 'مقاطع الرعاية';

  @override
  String switchingQuality(String quality) {
    return 'جارٍ التحويل إلى $quality…';
  }

  @override
  String syncedChannels(int count) {
    return 'تمت مزامنة $count قناة';
  }

  @override
  String get couldNotReadSubscriptions => 'تعذّرت قراءة اشتراكاتك';

  @override
  String get signInToUseAccount =>
      'اشترك في قنوات، أو سجّل الدخول لاستخدام حسابك';

  @override
  String get noChannelsSubtitle => 'اشترك من صفحة قناة، أو زامن حسابك';

  @override
  String get unsubscribe => 'إلغاء الاشتراك';

  @override
  String subscriberCount(String count) {
    return '$count مشترك';
  }

  @override
  String get allSubscriptions => 'الكل';

  @override
  String get browse => 'التصفح';

  @override
  String get you => 'حسابي';

  @override
  String get trending => 'الرائج';

  @override
  String get music => 'موسيقى';

  @override
  String get gaming => 'ألعاب';

  @override
  String get news => 'أخبار';

  @override
  String get sports => 'رياضة';

  @override
  String get live => 'بث مباشر';

  @override
  String get history => 'سجل المشاهدة';

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String get watchLater => 'مشاهدة لاحقًا';

  @override
  String get favorites => 'المفضلة';

  @override
  String get myChannel => 'قناتك';

  @override
  String get notSignedIn => 'لم تسجّل الدخول';

  @override
  String viewsCount(String count) {
    return '$count مشاهدة';
  }

  @override
  String get justNow => 'الآن';

  @override
  String yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count سنة',
      few: 'قبل $count سنوات',
      two: 'قبل سنتين',
      one: 'قبل سنة',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count شهرًا',
      few: 'قبل $count أشهر',
      two: 'قبل شهرين',
      one: 'قبل شهر',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count أسبوعًا',
      few: 'قبل $count أسابيع',
      two: 'قبل أسبوعين',
      one: 'قبل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get noComments => 'لا توجد تعليقات بعد';

  @override
  String get commentsUnavailable => 'تعذّر تحميل التعليقات';

  @override
  String get description => 'الوصف';

  @override
  String get noCommentsSubtitle => 'كن أول من يعلّق';

  @override
  String get unsubscribed => 'تم إلغاء الاشتراك';

  @override
  String get noVideos => 'لا توجد مقاطع';

  @override
  String get noPlaylists => 'لا توجد قوائم تشغيل بعد';

  @override
  String get channelHasNoPlaylists => 'لم تنشر هذه القناة أي قوائم تشغيل';

  @override
  String get channelIdLabel => 'معرّف القناة';

  @override
  String get subscribers => 'المشتركون';

  @override
  String get waitingForApproval => 'بانتظار الموافقة…';

  @override
  String get getSignInCode => 'احصل على رمز تسجيل الدخول';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String get signInUnofficialWarning =>
      'هذا التطبيق ليس عميلاً رسمياً ليوتيوب. قد تُقيّد Google الحسابات المستخدمة مع العملاء غير الرسمية أو توقفها. يُفضّل استخدام حساب ثانوي.';

  @override
  String get signInStepOpenPage => '١. افتح هذه الصفحة على أي جهاز';

  @override
  String get signInStepEnterCode => '٢. أدخل هذا الرمز';

  @override
  String get signedInKeystoreNote =>
      'تُجدَّد الجلسة تلقائياً. يُخزَّن الرمز في مخزن مفاتيح الجهاز ولا يغادر هذا الهاتف.';

  @override
  String get videos => 'المقاطع';

  @override
  String get streamCapped =>
      'أوقف يوتيوب بث هذا المقطع في منتصفه. عادةً ما يكون مقيّدًا — جرّب جودة أخرى أو مقطعًا آخر.';

  @override
  String get noPlaylistsSubtitle =>
      'ستظهر هنا قوائم التشغيل التي تنشئها في يوتيوب';

  @override
  String get syncing => 'جارٍ المزامنة…';

  @override
  String historySynced(int count) {
    return 'تمت مزامنة $count مقطعاً من حسابك';
  }

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطعاً',
      few: '$count مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String get liveUnavailable =>
      'هذا البث غير متاح — ربما انتهى أو أنه مخصص للأعضاء.';

  @override
  String get searchYouTube => 'ابحث في يوتيوب…';

  @override
  String get pipUnavailable => 'وضع صورة داخل صورة غير متاح هنا';

  @override
  String skipCategory(String category) {
    return 'تخطي $category';
  }

  @override
  String get searchFilters => 'عوامل التصفية';

  @override
  String get searchFilterUploadDate => 'تاريخ الرفع';

  @override
  String get searchFilterType => 'النوع';

  @override
  String get searchFilterDuration => 'المدة';

  @override
  String get searchFilterSortBy => 'الترتيب حسب';

  @override
  String get searchFilterAny => 'الكل';

  @override
  String get uploadDateLastHour => 'آخر ساعة';

  @override
  String get uploadDateToday => 'اليوم';

  @override
  String get uploadDateThisWeek => 'هذا الأسبوع';

  @override
  String get uploadDateThisMonth => 'هذا الشهر';

  @override
  String get uploadDateThisYear => 'هذه السنة';

  @override
  String get searchTypeVideo => 'فيديو';

  @override
  String get searchTypeMovie => 'فيلم';

  @override
  String get searchDurationShort => 'أقل من ٤ دقائق';

  @override
  String get searchDurationMedium => 'من ٤ إلى ٢٠ دقيقة';

  @override
  String get searchDurationLong => 'أكثر من ٢٠ دقيقة';

  @override
  String get sortByRelevance => 'الأكثر صلة';

  @override
  String get sortByUploadDate => 'تاريخ الرفع';

  @override
  String get sortByViewCount => 'عدد المشاهدات';

  @override
  String get sortByRating => 'التقييم';

  @override
  String get resetFilters => 'إعادة تعيين';

  @override
  String get clearFilters => 'مسح عوامل التصفية';

  @override
  String activeFilterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عامل تصفية',
      few: '$count عوامل تصفية',
      two: 'عاملا تصفية',
      one: 'عامل تصفية واحد',
    );
    return '$_temp0';
  }

  @override
  String get noResultsSubtitle => 'جرّب كلمات أخرى أو امسح عوامل التصفية.';

  @override
  String get removeFromHistory => 'إزالة من السجل';

  @override
  String get errorNotFound => 'المحتوى غير موجود';

  @override
  String get errorUnauthorized => 'تحتاج إلى تسجيل الدخول لعرض هذا';

  @override
  String get errorRateLimited => 'طلبات كثيرة — حاول بعد قليل';

  @override
  String get errorParse => 'تعذّرت قراءة رد يوتيوب';

  @override
  String get errorDatabase => 'تعذّرت قراءة البيانات المحلية';

  @override
  String get errorYouTube => 'تعذّر على يوتيوب تحميل هذا الآن';

  @override
  String get offlineTitle => 'أنت غير متصل بالإنترنت';

  @override
  String get offlineSubtitle => 'في انتظار الاتصال…';

  @override
  String get backOnline => 'عاد الاتصال';

  @override
  String get systemDefault => 'لغة النظام';

  @override
  String get searchSettings => 'ابحث في الإعدادات';

  @override
  String noSettingsMatch(String query) {
    return 'لا توجد إعدادات تطابق \"$query\"';
  }

  @override
  String get updateCheckUnavailable =>
      'التحقق التلقائي من التحديثات غير متاح في هذه النسخة';

  @override
  String get shortsEmpty => 'لا توجد شورتس متاحة حاليًا';

  @override
  String get shortsLoadFailed => 'تعذّر تحميل الشورتس';

  @override
  String get shortsDislike => 'عدم إعجاب';

  @override
  String get shortsOpenChannel => 'فتح القناة';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقّت';

  @override
  String get close => 'إغلاق';

  @override
  String get fullscreen => 'ملء الشاشة';

  @override
  String get exitFullscreen => 'إنهاء ملء الشاشة';

  @override
  String get videoOptions => 'خيارات أخرى';

  @override
  String get notInterested => 'لا يهمّني';

  @override
  String get blockChannel => 'لا تقترح هذه القناة';

  @override
  String get goToChannel => 'الانتقال إلى القناة';

  @override
  String miniPlayerLabel(String title) {
    return 'يُشغَّل الآن: $title';
  }

  @override
  String seekSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية واحدة',
    );
    return '$_temp0';
  }

  @override
  String viewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count ردّ',
      few: 'عرض $count ردود',
      two: 'عرض ردّين',
      one: 'عرض ردّ واحد',
    );
    return '$_temp0';
  }

  @override
  String get continueWatching => 'تابع المشاهدة';

  @override
  String get streamClient => 'عميل التشغيل';

  @override
  String get failedClients => 'العملاء المرفوضون';

  @override
  String get networkSpeed => 'سرعة الشبكة';

  @override
  String get automaticRecoveries => 'مرات الاسترداد التلقائي';

  @override
  String get fallbackReason => 'سبب الانتقال الاحتياطي';

  @override
  String get noFallback => 'لا يوجد';

  @override
  String get playerShortcuts => 'اختصارات المشغّل';

  @override
  String get playerShortcutsSubtitle =>
      'اختر ورتّب الأزرار التي تظهر فوق الفيديو';

  @override
  String get homeEmptyTitle => 'لا توجد اقتراحات بعد';

  @override
  String get homeEmptySubtitle => 'حدّث الصفحة أو اختر موضوعًا لبدء الاستكشاف';

  @override
  String get refreshFeed => 'تحديث الصفحة';

  @override
  String get backupAndRestore => 'النسخ الاحتياطي والاستعادة';

  @override
  String get exportBackup => 'تصدير نسخة احتياطية';

  @override
  String get exportBackupSubtitle =>
      'حفظ الإعدادات والقنوات المحظورة والاشتراكات والمفضلة والسجل';

  @override
  String get restoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get restoreBackupSubtitle =>
      'استبدال الإعدادات والمكتبة المحلية من نسخة BoodTube';

  @override
  String get restoreBackupConfirm =>
      'سيُستبدل السجل والاشتراكات والمفضلة وقائمة المشاهدة لاحقًا. لن تتغير التنزيلات.';

  @override
  String get backupRestored => 'تمت استعادة النسخة الاحتياطية بنجاح';

  @override
  String get backupFailed => 'تعذرت معالجة النسخة الاحتياطية';

  @override
  String get liveChat => 'الدردشة المباشرة';

  @override
  String get liveChatWaiting => 'بانتظار رسائل جديدة…';

  @override
  String get liveChatReadOnly => 'عرض المحادثة المباشرة فقط';

  @override
  String get castToTv => 'البث إلى التلفزيون';

  @override
  String get castScanning => 'جارٍ البحث عن أجهزة على شبكة Wi-Fi…';

  @override
  String get castNoDevices => 'لم يتم العثور على أجهزة بث';

  @override
  String get castFailed => 'تعذر بدء البث';

  @override
  String get subtitleAppearance => 'مظهر الترجمة';

  @override
  String get subtitleSize => 'حجم النص';

  @override
  String get subtitlePosition => 'الموضع الرأسي';

  @override
  String get subtitleBackground => 'الخلفية';
}
