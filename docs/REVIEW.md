# مراجعة تنفيذ flutter_poc مقابل وثيقة FLUTTER_MOBILE_STRATEGY.md

**تاريخ المراجعة:** 2026-08-03
**النتيجة العامة: المشروع لا يُترجَم (compile) إطلاقاً، ولم يُشغَّل ولو مرة واحدة، ومعظم "الميزات المنفّذة" واجهات وهمية ببيانات ثابتة.**

الأدلة القاطعة على أنه لم يُشغَّل قط:
- لا يوجد `pubspec.lock` → لم يُنفَّذ `flutter pub get` أبداً.
- لا يوجد أي ملف مولّد (`*.freezed.dart` / `*.g.dart`) → لم يُنفَّذ `build_runner` أبداً، وكل الكيانات وقاعدة البيانات تعتمد عليها.
- مجلدا `android/` و`ios/` ليسا مشروعاً حقيقياً من `flutter create`: أندرويد يحتوي فقط `build.gradle` و`AndroidManifest.xml` (لا gradle wrapper، لا `settings.gradle`، لا `MainActivity.kt`، لا مجلد `res/`)، وiOS يحتوي `Info.plist` فقط (لا `Runner.xcodeproj`، لا `AppDelegate.swift`، لا `Podfile`). أي أن `flutter run` و`flutter build` مستحيلان.
- المشروع كله غير مضاف إلى git (untracked بالكامل) — لا يوجد أي commit.
- حجم الكود الفعلي 5,861 سطراً وليس ~7,500 كما تدّعي الوثيقة.

---

## أولاً: أخطاء تمنع الترجمة (Blockers) — يجب إصلاحها قبل أي شيء

1. **ثلاثة ملفات entities غير موجودة رغم استيرادها في 10+ ملفات:** `chapter_item.dart` و`sponsor_segment.dart` و`dearrow_data.dart` مستوردة في `media_item.dart:12-14`، `media_item_mapper.dart:12-14`، `media_item_repository_impl.dart:9-10`، `sponsorblock_service.dart:8`، `dearrow_service.dart:7`، `settings_repository_impl.dart:11`، `settings_providers.dart:12`، `settings_screen.dart:10`، واختبارات. الأصناف نفسها معرّفة داخل `media_subtitle.dart` — يجب فصلها إلى ملفاتها أو تصحيح كل الاستيرادات.
2. **بنية `part` غير صالحة في `media_subtitle.dart:9-12`:** يعلن أربعة `part` directives (`chapter_item.freezed.dart` إلخ) بينما freezed يولّد ملفاً واحداً فقط باسم الملف المصدر — هذه الملفات لن تتولّد أبداً حتى لو شُغِّل build_runner. خطأ بنيوي وليس مجرد "لم يُشغَّل التوليد".
3. **قيم افتراضية غير قانونية في redirecting factory constructors:** `media_format.dart:50` (`bool isAudioOnly = false`) و`comment_item.dart:21-22` — Dart يمنعها؛ الصحيح `@Default(false)`. الكيانان لا يُترجمان بمعزل عن التوليد.
4. **صنف `SponsorSegment` مكرر ومتضارب:** `media_item_repository.dart:44-53` يعرّف صنفاً يدوياً ثانياً بحقول `dynamic` يتعارض مع الكيان الحقيقي ويكسر الـ override في الـ impl.
5. **`media_item_repository_impl.dart:42,45`:** تمرير المعامل المسمّى `formats:` مرتين في استدعاء `copyWith` واحد — خطأ ترجمة مباشر.
6. **تضارب `ThemeMode`:** `settings_repository_impl.dart:75` يعرّف `enum ThemeMode` محلياً يتصادم مع `material.ThemeMode` في `main.dart` و`settings_screen.dart` و`settings_providers.dart` — استيراد غامض لا يُترجم، ودالة `_mapThemeMode` في `main.dart:54-63` لا تحوّل شيئاً فعلياً.
7. **أخطاء استخدام API مكتبة `youtube_explode_dart` (v3):**
   - `innertube_client.dart:52`: `getTrendingVideos()` غير موجودة في المكتبة إطلاقاً — **الصفحة الرئيسية/Trending كلها مبنية على دالة غير موجودة**.
   - `innertube_client.dart:63-64`: `search.search()` تُرجع `SearchList` وليس `List<Video>` — عدم تطابق أنواع يمتد لكل `content_repository_impl.dart`.
   - `innertube_client.dart:30`: `VideoNotFoundException` غير موجود (الصحيح `VideoUnavailableException`).
   - `innertube_client.dart:98-111`: استخدام خاطئ لواجهة الترجمات (`ClosedCaptionManifest` ليست Iterable، والحقول `languageCode`/`name` غير موجودة) + `MediaSubtitle` مستخدم بلا استيراد.
   - `comments_service.dart`: كل الدوال تستخدم توقيعات غير موجودة (`getComments` يأخذ `Video` لا `VideoId`، `Comment` بلا `id`/`isHearted`/`isPinned`، و`publishedTime` نص وليس `DateTime`).
   - `content_repository_impl.dart:127`: `channel.description` غير موجود في صنف `Channel`.
8. **`stream_resolver.dart:129-131`:** `[...streams]..sort(...).first` — استدعاء `.first` على نتيجة `sort()` وهي `void` + نوع خاطئ للتعبير. خطآ ترجمة.
9. **`media_item_mapper.dart:86`:** `~/` على `int?` nullable — لا يُترجم.
10. **`player_screen.dart:27`:** `final PlayerController _playerController = PlayerController;` — إسناد اسم النوع نفسه لمتغير. خطأ ترجمة.
11. **`audio_player_handler.dart`:** استيراد غامض لـ `MediaItem` (من audio_service ومن الكيان المحلي بلا prefix)، و`PlaybackState.copyWith(position:)` معامل غير موجود في audio_service 0.18.
12. **`download_manager.dart:8`:** يستورد `path_provider` وهي **غير معلنة في `pubspec.yaml`**.
13. **`integration_test/app_test.dart:7`:** حزمة `integration_test` غير معلنة في dev_dependencies.
14. **مسارات تنقّل تسبب crash فوري:** `home_screen.dart:29,173` يستخدم `Navigator.pushNamed` بينما التطبيق يعمل بـ `MaterialApp.router` بلا named routes — **كل ضغطة على أي فيديو في الرئيسية سترمي استثناء**. و`search_screen.dart:83` يدفع إلى `/search/results` وهو مسار غير مسجّل في `app_router.dart` أصلاً.
15. **شاشتا Shorts وComments غير مسجّلتين في الراوتر نهائياً** — لا يمكن الوصول إليهما من التطبيق بأي طريقة.
16. **`video_card.dart:116-138`:** `AspectRatio` داخل `Row` بلا قيود ارتفاع — سيرمي layout exception وقت التشغيل في كل أماكن استخدامه الثلاثة (الرئيسية، البحث، القناة).

---

## ثانياً: ميزات وهمية تدّعي الوثيقة أنها "منفّذة ✅"

| الميزة (حسب الوثيقة) | الواقع |
|---|---|
| SponsorBlock "منفّذ مع skip logic" | **لا يوجد أي ربط بالمشغّل**: `player_providers.dart` لا يقرأ الخدمة ولا يفحص المقاطع ولا يوجد زر تخطي ولا auto-skip. `media_item_repository_impl.dart:63-74` يُرجع `Success([])` مع TODO. فوق ذلك عنوان الخادم خاطئ (`sponsor.ajayapis.com` بدل `sponsor.ajay.app`) فحتى لو رُبط لن يعمل، ويستخدم endpoint الـ videoID المكشوف بدل hash-prefix الخاص بالخصوصية |
| التشغيل التكيّفي (فصل صوت/فيديو) — "قلب المشروع" | `stream_resolver` يُرجع رابطي صوت وفيديو منفصلين **لكن لا أحد يستهلكهما**؛ المشغّل يفتح رابطاً واحداً هو `bestFormat` (أعلى bitrate = غالباً مسار فيديو بلا صوت) → فيديو صامت. و`_buildProgressiveFormat` مجرد `return null` |
| اختيار الجودة | زر "Auto" ثابت بلا onTap في `player_screen.dart:272-287` |
| المكتبة (History/Favorites/Watch Later) | الـ providers الثلاثة في `library_screen.dart:18-29` تُرجع `[]` ثابتة، والصفوف placeholder نصية ("Video 1") — رغم وجود قاعدة Drift كاملة و`LocalLibraryRepository` جاهز وغير مستخدَم |
| الاشتراكات | `subscriptionsProvider` معلَّق صراحةً "Mock for PoC" ويُرجع `[]`، وزر Subscribe في شاشة القناة `// TODO` لا يكتب شيئاً — أي لا يمكن أن تمتلئ الشاشة أبداً |
| البحث — الاقتراحات والتاريخ | Trending suggestions وتاريخ البحث **بيانات ثابتة مكتوبة يدوياً** ('Music 2026'، 'Flutter tutorial'...) |
| الإعدادات (13 إعداداً) | **8 من 10 إعدادات لا تفعل شيئاً**: الجودة الافتراضية والسرعة الافتراضية لا يقرؤهما المشغّل، Background playback لا يُهيَّأ audio_service إطلاقاً، PiP بلا كود native (كل استدعاء MethodChannel سيفشل)، Double-tap ثابت لا يقرأ الإعداد، مفاتيح SponsorBlock كلها بلا أثر، اللغة تكتب 'ar' في التخزين ولا يوجد توطين. الوحيد الفعّال: الثيم |
| العربية وRTL "من اليوم الأول" | **صفر تنفيذ**: مجلد `lib/l10n` فارغ تماماً، لا ملفات `.arb`، لا `l10n.yaml`، لا delegates في `MaterialApp`، ولا أي `EdgeInsetsDirectional` في كل الواجهات — مع أن `generate: true` مفعّل وقد يُفشل البناء بحد ذاته |
| Shorts | غير مسجّلة في الراوتر + provider يُرجع `[]` + دالة التشغيل `_loadAndPlay` **معلّقة بالكامل بالتعليقات** → شاشة سوداء دائمة |
| التعليقات | غير مسجّلة في الراوتر، لا زر يفتحها من المشغّل، provider يُرجع `[]`، و`comments_service.dart` لا يستدعيه أحد |
| DeArrow | لا يُنشئه أحد + شكل الاستجابة المفترض خاطئ كلياً (سيرجع `null` دائماً) + العنوان خاطئ (الـ API على `sponsor.ajay.app/api/branding`) |
| Background audio / Download manager / PiP | ثلاث خدمات ميتة لا يشير إليها أي ملف في التطبيق. `setMediaItem` في الـ audio handler لا يشغّل شيئاً، و`cancelDownload` لا يلغي التحميل فعلياً |
| "فحص التحديثات" | SnackBar ثابتة "No updates available" دائماً |
| Fullscreen / إيماءات السطوع والصوت / مشاركة القناة / جرس الإشعارات / الردود على التعليقات | كلها `// TODO` أو أزرار بلا handler |

---

## ثالثاً: أخطاء منطقية حقيقية (حتى بعد إصلاح الترجمة)

1. `stream_resolver.dart:114-125`: منطق اختيار الجودة **معكوس** — يختار أدنى جودة تحت السقف بدل أعلاها (طلب 720p يعطي 144p).
2. `media_item_mapper.dart:70-72`: `MuxedStreamInfo` يحقق `is AudioStreamInfo` أيضاً → كل stream مدموج يُعلَّم `isAudioOnly: true` ويفسد اختيار `bestFormat`.
3. `settings_repository_impl.dart:136-142`: `toggleSponsorCategory` يعدّل `const Set` → `UnsupportedError` عند أول استخدام. وتعطيل كل الفئات يعيد الافتراضيات (لا يمكن الإيقاف الكامل).
4. `local_library_repository_impl.dart:36-49`: `addToHistory` بدون position **يصفّر نقطة الاستئناف المحفوظة**. وقسمة على `durationMs` بلا حماية من الصفر (:309) تُسقط قائمة التاريخ مع البث المباشر.
5. `local_library_repository_impl.dart:297-353`: كل الـ mappers تستخدم `dynamic` — تخالف قواعد التحليل الخاصة بالمشروع نفسه وتحوّل أي تغيير عمود إلى خطأ وقت تشغيل.
6. `watch_history_table.dart:19`: `videoId` مفتاح أساسي مع `insertOnConflictUpdate` → التاريخ لا يسجّل المشاهدات المتكررة أبداً.
7. `app_database.dart`: كل الاستعلامات `Future` لمرة واحدة بلا `watch()` streams → الواجهات لن تتحدّث تلقائياً عند أي تغيير. ومصدران متضاربان لموضع الاستئناف (جدول positions + عمود في history) بلا مزامنة.
8. `player_providers.dart:187-190`: provider المشغّل global وغير autoDispose → حالة المشغّل تتسرب بين الفيديوهات، ولا كتابة للتاريخ ولا استعادة لموضع الاستئناف رغم جاهزية الجداول. و`dispose` لا يوقف الـ Player.
9. `shorts_screen.dart:84-85` + `repository_providers.dart:43`: إنشاء `Player()` جديد لكل صفحة Shorts بجانب الـ singleton → عدة نسخ mpv متزامنة.
10. `media_item_repository_impl.dart:28-37`: استدعاء `getManifest` مرتين لنفس الفيديو عند كل فتح (استخراج مكلف مكرر بلا داعٍ).
11. `innertube_client.dart`: يخالف "قاعدة العزل الذهبية" (§3.3 في الوثيقة) — يُرجع أنواع المكتبة الخام (`Video`/`StreamInfo`) لكل الطبقات بدل عزلها.
12. `content_repository_impl.dart`: `pageToken` و`SearchFilters` مقبولان ومُهملان في كل الدوال، ولا يُضبط `nextPageToken` أبداً → التمرير اللانهائي مستحيل في كل الشاشات. و`getSubscriptionsFeed` تُرجع `[]` مع TODO.

---

## رابعاً: الاختبارات — "25+ اختباراً" لا يمكن أن ينجح منها شيء تقريباً

- كل اختبار يستورد الكيانات يفشل عند التحليل (ملفات مفقودة + كيانات لا تُترجم).
- `media_item_mapper_test.dart`: يبني `Video(...)` بتوقيع لا يطابق constructor المكتبة v3.
- `player_controller_test.dart`: ينشئ `Player` (mpv) حقيقياً في اختبار وحدة headless → فشل حتمي، واختباران فيه **بلا أي `expect`** (تغطية زائفة).
- `video_card_golden_test.dart`: **لا يوجد مجلد goldens أصلاً** في المستودع → `screenMatchesGolden` يفشل، والاختبار يحمّل صورة شبكة (ممنوعة في flutter_test).
- `integration_test/app_test.dart`: الحزمة غير معلنة، `app.main()` يُستدعى بلا await، وكل اختبار يكدّس شجرة تطبيق جديدة فوق السابقة، ويعتمد على شبكة حقيقية.
- `mocktail` مضافة ولا يستخدمها أي اختبار. لا يوجد اختبار واحد لفرضيتي الـ PoC الأساسيتين (الاستخراج والتشغيل).
- الاختبار الوحيد المرشح للنجاح بعد الإصلاح: `error_view_test.dart`.

---

## خامساً: CI والبناء والمنصات

- **`.github/workflows/ci.yml`:** كل الخطوات ستفشل (build_runner على parts غير صالحة، `analyze --fatal-infos` مع عشرات المخالفات القائمة مثل unused imports، golden بلا goldens، بناء أندرويد/iOS بلا مشروع منصات). خطوة غريبة تسحب `yuliskov/SharedModules` وهي بقايا من مشروع أندرويد الأصلي لا علاقة لها بـ Flutter. و`--no-codesign` ليست flag صالحة لـ `build ipa`.
- **`android/app/build.gradle`:** يطبّق `com.google.gms.google-services` بلا `google-services.json` وبلا أي استخدام لـ Firebase (فشل Gradle فوري)، يشير إلى `MainActivity` و`proguard-rules.pro` و`src/main/kotlin` وكلها غير موجودة، وفي حال غياب `key.properties` يوقّع نسخة release بمفتاح debug بصمت.
- **`AndroidManifest.xml`:** يشير إلى `@mipmap/ic_launcher` و`@style/LaunchTheme` بلا مجلد `res/`، يفعّل `usesCleartextTraffic="true"` بلا مبرر (تنزيل أمني)، يطلب أذونات تخزين لميزة تحميل غير موصولة، ويعلن "إذن" `PICTURE_IN_PICTURE` وهو غير موجود في أندرويد.
- **`ios/Runner/Info.plist`:** مفتاح `UIBackgroundModes` **مكرر مرتين** (ملف plist غير صالح)، أوصاف كاميرا/مايكروفون نصّها "التطبيق لا يستخدمها" (رفض تلقائي من مراجعة آبل)، ولا `UILaunchStoryboardName`.
- **`scripts/build_*.sh`:** تجمع `--debug --obfuscate` وهو تركيب مرفوض من أداة Flutter، وكلها ستفشل لغياب مشاريع المنصات.
- **`analysis_options.yaml`:** يستخدم مفاتيح `strong-mode` المحذوفة من المحلل منذ سنوات (يجب `language: strict-casts/strict-raw-types`) — أي أن حماية الأنواع التي يدّعيها معطّلة فعلياً.

---

## سادساً: فجوات بنيوية مقابل الوثيقة

- **لا يوجد مجلد `domain/usecases/` إطلاقاً** (الوثيقة تدّعي 15+ use case).
- لا واجهة domain لـ `LocalLibraryRepository` ولا لـ `SettingsRepository` (يخالف Clean Architecture المعلنة).
- كيانات ناقصة مقابل الوثيقة: `channel_info`, `playlist_info`, `search_options`, `account` غير موجودة.
- `README.md` يناقض الواقع في الاتجاهين: يدّعي اكتمال ملفات غير موجودة، ويقول "coming soon" عن ملفات موجودة.
- مجلد `assets/` فارغ، ومكتبات معلنة بلا أي استخدام (`google_fonts`, `just_audio`, `url_launcher`, `qr`/`mobile_scanner` غير مضافة أصلاً رغم ذكرها بالوثيقة، `regex` ميتة).

---

## المطلوب من المنفّذ (بالترتيب)

1. **إنشاء مشروع Flutter حقيقي**: `flutter create` لتوليد مجلدات android/ios كاملة ثم دمج الإعدادات المخصصة فيها، ثم `flutter pub get`.
2. **إصلاح كل أخطاء الترجمة** (القسم أولاً): فصل الكيانات لملفاتها، إصلاح `part`/`@Default`، حذف `SponsorSegment` المكرر، حل تضارب `ThemeMode`، تصحيح كل استخدامات youtube_explode_dart على الإصدار الفعلي، إضافة `path_provider` و`integration_test` للـ pubspec.
3. **تشغيل `build_runner` ثم `flutter analyze` حتى الصفر أخطاء**، وإرفاق مخرجات الأمرين كدليل.
4. **إثبات فرضيتي الـ PoC قبل أي شيء آخر** (هذا هدف المرحلة 0 المعلن): فيديو 1080p+ يعمل بصوت وصورة معاً (ربط `audioUrl` الفعلي في media_kit)، على جهاز حقيقي، مع تسجيل شاشة أو لقطات كدليل.
5. **إزالة أو وسم كل البيانات الوهمية**: منع تسمية أي شاشة تُرجع `[]` أو بيانات ثابتة بأنها "منفّذة". ربط المكتبة والاشتراكات بـ Drift الموجود فعلاً.
6. **ربط SponsorBlock فعلياً**: تصحيح العنوان إلى `sponsor.ajay.app`، استخدام endpoint الـ hash-prefix للخصوصية، ثم منطق التخطي في المشغّل.
7. **تسجيل مسارات Shorts/Comments أو حذف الشاشتين**، وإصلاح كل الـ dead-end navigation.
8. **إصلاح الاختبارات لتعمل فعلاً** (mocks بدل الشبكة وmpv، goldens مولّدة، asserts حقيقية) وتشغيل `flutter test` بنجاح كدليل.
9. **البدء الفعلي بالتوطين العربي/RTL** أو إزالة `generate: true` مؤقتاً وتحديث الوثيقة بصدق.
10. **commit للكود على git** — لا يوجد أي إصدار محفوظ حالياً.
11. **تحديث README والوثيقة الاستراتيجية** لتطابق الواقع: حالة المراحل الفعلية هي "هيكل كود غير مُجرَّب" وليست "المرحلة 0–4 منفّذة ✅".

> **خلاصة للإدارة:** ما سُلِّم هو هيكل كود (scaffold) مكتوب دفعة واحدة دون أي محاولة ترجمة أو تشغيل، مع طبقة عرض تُخفي غياب الوظائف ببيانات ثابتة. بوابة القرار Go/No-Go للمرحلة 0 (تشغيل فيديو عالي الجودة بصوت وصورة) **لم تُختبر بعد إطلاقاً**، وكل مؤشرات "الاكتمال" في الوثيقة (نسب 70–80%، عدد الاختبارات، عدد الأسطر) غير مطابقة للواقع.

---

## ملحق: نتائج التشغيل الفعلي للفحوصات (نُفِّذت بتاريخ 2026-08-03)

جرى تشغيل بنود قائمة "ما لم يُختبر" فعلياً على Flutter 3.41.6. النتائج:

| البند | النتيجة | التفاصيل |
|---|---|---|
| `flutter pub get` | ❌ فشل 4 مرات ثم ✅ بعد إصلاحات | حزمتان **غير موجودتين على pub.dev أصلاً** (`regex: ^0.1.0`، `media_kit_libs_mpv_video`) + تعارض `intl` مع SDK + تعارض `custom_lint`/`rxdart` — دليل قاطع أن `pub get` لم يُنفَّذ من قبل إطلاقاً |
| `dart run build_runner build` | ❌ فشل مرتين ثم ✅ بعد إصلاحين إضافيين | تضارب `analyzer_plugin`/`analyzer` تطلّب إزالة `custom_lint`/`riverpod_lint` (غير مفعّلتين أصلاً) وتثبيت `analyzer: 7.3.0`. بعدها وُلِّد 158 ملفاً |
| `flutter analyze` | ❌ **691 مشكلة: 121 خطأ ترجمة، 51 تحذيراً، 519 info** | أبرز الأخطاء تطابق المراجعة: `SponsorCategory` غير معرّف (17 موضعاً)، 7 defaults غير قانونية في redirecting factories، 7 استيرادات لملفات غير موجودة، أخطاء API لمكتبة youtube_explode_dart (`Comment.id/thumbnail/isPinned` غير موجودة، `getComments(VideoId)` بدل `Video`، `ClosedCaptionManifest.map` غير موجودة، `MediaType` يعامَل كـ `String`)، `CardTheme` بدل `CardThemeData` |
| `flutter test` | ❌ **32 نجح / 10 فشلوا** | ملفا اختبار لم يُترجما أصلاً (mapper + player_controller — الأخير كشف استيراداً خاطئاً يشير إلى `lib/data/domain/...` غير الموجود)، وكل اختبارات `VideoCard` الستة فشلت بـ **RenderFlex overflow** — تأكيد عملي لخطأ الـ layout المذكور في المراجعة. معظم الناجحين اختبارات utilities بسيطة أو بلا asserts |
| `flutter run` على جهاز | ❌ **مستحيل حالياً** | (أ) لا توجد منصة صالحة: أندرويد ناقص الهيكل (لا gradle wrapper/settings.gradle/MainActivity) — أُضيف هيكل Windows بـ `flutter create` للتجربة؛ (ب) البناء يتطلب تفعيل Developer Mode في Windows (غير مفعّل)؛ (ج) **والأهم: 121 خطأ ترجمة تمنع البناء على أي منصة قبل الوصول للجهاز أصلاً** |
| اختبار فيديو 1080p+ بصوت | ❌ لم يُختبر | متعذّر ما دام التطبيق لا يُبنى. ويُذكَّر أنه حتى بعد إصلاح الترجمة، الكود الحالي يشغّل رابطاً واحداً (`bestFormat`) بلا ربط مسار الصوت — أي أن الاختبار سيفشل وظيفياً أيضاً |

### تعديلات أُجريت على `pubspec.yaml` أثناء الفحص (يجب اعتمادها أو مراجعتها)

1. حذف `regex: ^0.1.0` (غير موجودة على pub.dev وغير مستخدمة).
2. استبدال `media_kit_libs_mpv_video: any` بـ `media_kit_libs_video: ^1.0.0`.
3. رفع `intl` إلى `^0.20.2` (مثبّتة من SDK).
4. حذف `custom_lint` و`riverpod_lint` (تكسر build_runner وغير مفعّلتين في analysis_options).
5. تثبيت `analyzer: 7.3.0` في dev_dependencies لحل تضارب حزم التوليد.
6. أُضيف هيكل منصة Windows عبر `flutter create . --platforms=windows`.

### الخلاصة المحدّثة

أول أمر في دورة حياة أي مشروع Flutter (`pub get`) كان يفشل فوراً بحزمة غير موجودة — **إثبات نهائي أن المشروع سُلِّم دون تنفيذ أي أمر واحد عليه**. بعد 6 إصلاحات في التبعيات فقط أصبح بالإمكان الوصول إلى الصورة الحقيقية: 121 خطأ ترجمة يجب على المنفّذ إصلاحها قبل أي حديث عن ميزات أو نسب إنجاز.

---

## ملحق 2: التحقق من "الجلسة الثانية" للمنفّذ (2026-08-03)

أعيد تشغيل السلسلة كاملة على الكود المحدّث. **الحكم: الادعاء "بنية الكود صحيحة الآن ✅" غير صحيح** — النتائج:

| البند | الجلسة 1 | بعد "الجلسة 2" |
|---|---|---|
| `flutter pub get` | ✅ (بإصلاحاتنا السابقة) | ✅ |
| `build_runner` | ✅ | ❌ **عاد يفشل** — freezed يفشل على 3 كيانات جديدة + كان يفشل باستيراد `flutter_gen` القديم في `main.dart` (أصلحناه أثناء الفحص) |
| `flutter analyze` | 121 خطأ | ❌ **112 خطأ** (تحسّن 9 أخطاء فقط) |
| `flutter test` | 32✅ / 10❌ | ❌ 32✅ / 10❌ — بلا تغيير، **واختبارات VideoCard الستة ما زالت تفشل رغم ادعاء إصلاح الـ AspectRatio** |
| `flutter run` | مستحيل | ❌ ما زال مستحيلاً (112 خطأ ترجمة) |
| فيديو 1080p+ بصوت | لم يُختبر | ❌ ما زال متعذراً |

### إصلاحات حقيقية تم التحقق منها ✅
فصل الكيانات الثلاثة لملفاتها، `@Default` في `media_format`/`comment_item` (زالت الأخطاء السبعة القديمة)، تحويل `ThemeMode` عبر `AppThemeMode` صحيح، ملفات ARB + delegates + RTL builder موجودة فعلاً، تصحيح عنوان SponsorBlock إلى `sponsor.ajay.app`، حذف `google-services` من build.gradle، حذف `getTrendingVideos` غير الموجودة، إنشاء usecases والكيانات الأربعة الجديدة.

### لماذا بقيت 112 خطأ؟ ثلاثة أسباب جذرية:

1. **مسار استيراد خاطئ العمق واحد يسبب عشرات الأخطاء المتسلسلة:** `settings_repository_impl.dart:10-11` يستورد `../../domain/entities/...` من داخل `lib/data/local/preferences/` — وهذا يشير إلى `lib/data/domain/` غير الموجود. الصحيح `../../../domain/...`. هذا وحده مصدر أخطاء `SponsorCategory` (17 موضعاً) و`MediaFormatQuality` (7 مواضع) وسلسلة `const set` (10 أخطاء).
2. **نفس الخطأ الذي "أُصلح" أعيد ارتكابه في الملفات الجديدة:** الكيانات الجديدة تستخدم defaults غير قانونية في redirecting factories — `channel_info.dart:20` (`bool isVerified = false`)، `playlist_info.dart:20` (`bool isPublic = true`)، `search_options.dart:17` (`String query = ''`). يجب `@Default(...)`. بسببها يفشل freezed عليها → `_ChannelInfo`/`_PlaylistInfo`/`_SearchOptions` غير معرّفة → build_runner كله يفشل.
3. **أخطاء youtube_explode_dart لم تُمَس نهائياً:** `comments_service.dart` كما هو (`Comment.id/thumbnail/isPinned/totalReplyCount` غير موجودة، `getComments(VideoId)` بدل `Video`، `String` بدل `DateTime`)، `ClosedCaptionManifest.map` غير موجودة، `MediaType` يُعامل كـ `String` (`codec.split`)، `Framerate` يُمرر كـ `double`، إلخ — نحو 40 خطأً من هذه الفئة باقية كما كانت في المراجعة الأولى حرفياً.

### أخطاء متبقية أخرى ملحوظة
`CardTheme` بدل `CardThemeData` في `app_theme.dart`، دوال `_historyToMediaItem`/`_favoriteToMediaItem`... يستدعيها `local_library_providers` وهي private في صنف آخر، `localLibraryRepositoryProvider` غير معرّف حيث يُستخدم، `getStreamUrl` غير موجودة في الواجهة، `context.push` بلا استيراد go_router في أحد الملفات.

### تعديل أجريناه أثناء هذا التحقق
- `main.dart:12`: تصحيح `package:flutter_gen/gen_l10n/...` إلى `l10n/app_localizations.dart` (أسلوب flutter_gen القديم أُزيل من Flutter الحديث وكان يكسر build_runner بالكامل).
- حذف `test/widget_test.dart` الافتراضي (خلّفته هيكلة `flutter create` من فحصنا السابق، كان يضيف فشلاً زائفاً).

### الرسالة للمنفّذ
الإصلاح الأعلى مردوداً الآن: (1) تصحيح سطري الاستيراد في `settings_repository_impl.dart`، (2) تحويل defaults الكيانات الثلاثة الجديدة إلى `@Default`، (3) ثم معالجة كتلة youtube_explode_dart كاملة بفتح توثيق الإصدار 3.1.0 الفعلي بدل الكتابة من الذاكرة. **وقاعدة إلزامية من الآن: لا يُسلَّم عمل دون إرفاق مخرجات `flutter analyze` و`flutter test` الفعلية** — جلستان متتاليتان سُلِّمتا بادعاء "مُصلَح" دون تشغيل أمر واحد.

---

## ملحق 3: التحقق من الجلسة الثالثة (2026-08-03)

**تقدّم حقيقي وكبير هذه المرة.** النتائج الفعلية:

| البند | الجلسة 2 | الجلسة 3 |
|---|---|---|
| `flutter pub get` | ✅ | ✅ |
| `build_runner` | ❌ | ✅ **نجح — 68 ملفاً مولّداً** |
| `flutter analyze` | 112 خطأ | **4 أخطاء فقط** (+28 تحذيراً +491 info) |
| `flutter test` | 32✅/10❌ | **36✅ / 9❌** |
| `flutter run` | مستحيل | ❌ ما زال ممنوعاً بالأخطاء الأربعة |

### الأخطاء الأربعة المتبقية (كلها بسيطة)

1. `lib/data/dearrow/dearrow_service.dart:37` — إسناد `Object` إلى `List<dynamic>` (يحتاج cast صريح بعد فحص النوع).
2. `lib/data/repositories/content_repository_impl.dart:93` — `LocalSubscription` معرّف في ملفين (impl + الواجهة الجديدة في domain): استيراد غامض — احذف التعريف المكرر من الـ impl واستورد من domain فقط.
3. `lib/presentation/screens/player/player_screen.dart:86` — تمرير `dynamic` حيث يُتوقع `VideoControlsBuilder?`.
4. `lib/presentation/screens/player/player_screen.dart:154` — `context.push` بلا استيراد `package:go_router/go_router.dart`.

### الاختبارات الفاشلة التسعة

كتلة `VideoCard` (6 اختبارات): **RenderFlex overflow بمقدار 7.5px** في التخطيط العمودي — البطاقة أطول بقليل من المساحة المخصصة؛ خطأ layout صغير حقيقي (قصّ النصوص أو Flexible/Expanded أو تقليص paddings) وليس مشكلة بنيوية.

### الحكم

بعد إصلاح الأخطاء الأربعة (عمل دقائق) يصبح المشروع **قابلاً للبناء لأول مرة**، وتكون الخطوة التالية مباشرة: تشغيل على محاكي أندرويد واختبار فيديو 1080p+ بصوت وصورة (بوابة Go/No-Go). تذكير: تأكد أن المشغّل يستهلك `audioUrl` المنفصل قبل اختبار الجودة العالية وإلا سيكون الفيديو صامتاً.

---

## ملحق 4: التحقق من الجلسة الرابعة (2026-08-03)

### تحقق مطابق للادعاءات ✅

| البند | الادعاء | التحقق الفعلي |
|---|---|---|
| `flutter pub get` | ✅ | ✅ صحيح |
| `build_runner` | ✅ | ✅ صحيح |
| `flutter analyze` | 0 أخطاء / 28 تحذيراً | ✅ **مطابق تماماً: 0 أخطاء، 28 تحذيراً، 492 info** |
| `flutter test` | 48/48 | ✅ **مطابق: All tests passed (48)** |

**هذه أول جلسة يطابق فيها التسليم الواقع بنسبة 100%.** المشروع يُترجَم لأول مرة في تاريخه.

### 🔴 لكن: خطأ حرج في ربط الصوت — سيُفشل اختبار الـ PoC

`player_providers.dart:143-146` يستخدم:
```dart
await _player.open(Playlist([Media(resolved.videoUrl), Media(resolved.audioUrl!)]));
```
**`Playlist` في media_kit قائمة تشغيل تسلسلية وليست دمج مسارات**: سيشغّل الفيديو الصامت كاملاً أولاً، وبعد انتهائه يشغّل ملف الصوت وحده (شاشة سوداء بصوت). التعليق في الكود ("mpv merges them as separate tracks") غير صحيح واقعياً. الطريقة الصحيحة في media_kit لمسار صوت خارجي:
```dart
await _player.open(Media(resolved.videoUrl));
await _player.setAudioTrack(AudioTrack.uri(resolved.audioUrl!));
```
يجب إصلاح هذا **قبل** اختبار 1080p+ وإلا سيفشل الاختبار رغم سلامة كل شيء آخر.

### وضع منصة أندرويد

ادعاء المنفّذ بأن `android/` ناقصة (لا MainActivity ولا gradle wrapper ولا settings.gradle) **صحيح ومطابق لمراجعتنا الأولى** — فشل `flutter build apk` بـ "deleted Android v1 embedding" متوقع. المطلوب في جلسة المنصة: نقل `android/` الحالية جانباً، توليد `flutter create . --platforms=android`، ثم دمج الأذونات/الإعدادات المطلوبة من الملفات القديمة (بعد تنقيتها من الأخطاء الموثقة في المراجعة الأولى: cleartext، أذونات التحميل، إذن PiP الوهمي). مشكلة المحاكي (HAXM/Hyper-V) بيئية منفصلة.

### الحالة الإجمالية بعد 4 جلسات
- الترجمة: ✅ صفر أخطاء (كانت 121)
- الاختبارات: ✅ 48/48 (كانت غير قابلة للتشغيل)
- المتبقي لبوابة Go/No-Go: (1) إصلاح ربط الصوت أعلاه، (2) توليد منصة أندرويد ودمج الإعدادات، (3) تشغيل فعلي واختبار فيديو 1080p+ بصوت، (4) لاحقاً: تنظيف 28 تحذيراً وإعادة فحص الميزات الوهمية المتبقية من القسم "ثانياً" في المراجعة الأصلية.

---

## ملحق 5: أول تشغيل فعلي في تاريخ المشروع (2026-08-03)

### إنجازات هذه الجلسة (تحقق فعلي على محاكي)

| الخطوة | النتيجة |
|---|---|
| إصلاح ربط الصوت (`setAudioTrack(AudioTrack.uri(...))`) | ✅ نفّذه المنفّذ بشكل صحيح |
| منصة أندرويد الحقيقية (gradle wrapper + MainActivity + manifest نظيف) | ✅ مولّدة ومدموجة بشكل ممتاز — المانيفست عالج كل ملاحظات المراجعة الأولى |
| `flutter analyze` / `flutter test` | ✅ 0 أخطاء / 48-48 (بعد حذف `widget_test.dart` الافتراضي الذي أعاد `flutter create` توليده) |
| **`flutter build apk`** | ✅ **أول APK في تاريخ المشروع — بُني بنجاح** |
| المحاكي | ✅ محاكي `basma` أقلع بنجاح (Android 14) — **ادعاء "المحاكيات لا تعمل" غير دقيق**؛ فقط `basma_x86_api25` هو المعطوب |
| تثبيت وتشغيل التطبيق | ✅ التطبيق يعمل، والصفحة الرئيسية **تعرض بيانات يوتيوب حقيقية** (عناوين/قنوات/مدد فعلية) |
| **فرضية الـ PoC رقم 1 (الاستخراج)** | ✅ **مثبتة**: داخل التطبيق (feed حقيقي) + سكربت تشخيصي مستقل (`tool/poc_check.dart`) جلب manifest كامل في 1.7 ثانية: 22 مسار فيديو حتى 2160p و4 مسارات صوت |
| **فرضية الـ PoC رقم 2 (التشغيل)** | 🔴 **غير مثبتة بعد**: شاشة المشغّل تفتح والضوابط تعمل، لكن الفيديو أسود والعداد عالق 0:00/0:00 بعد دقيقتين+ |

### تشخيص مشكلة التشغيل (المهمة التالية للمنفّذ)

الأدلة المجموعة:
- لا توجد أي سجلات mpv/media_kit في logcat بعد إنشاء `VideoOutput` → على الأرجح `player.open()` لم يُستدعَ إطلاقاً، أو استُدعي وفشل بصمت.
- واجهة الضوابط ظاهرة (أي `isLoading=false`) بلا رسالة خطأ → سلسلة `loadVideo` إما علِقت في مرحلة الجلب المتسلسل (metadata → manifest → subtitles → sponsor، **كلها بلا timeouts**) أو أكملت وفشل mpv دون أن يعرض أحد الخطأ.
- الاستخراج نفسه سليم قطعاً (السكربت المستقل أثبته من نفس الجهاز/الشبكة).

خطوات التشخيص المطلوبة:
1. الاشتراك في `_player.stream.log` و`_player.stream.error` وطباعتهما — mpv لا يسجّل أخطاءه في logcat تلقائياً.
2. إضافة `debugPrint` قبل/بعد كل await في `loadVideo` لتحديد نقطة التعليق، و`timeout()` على كل جلب شبكي.
3. التأكد من عرض `state.error` في واجهة المشغّل (حالياً قد يضيع الخطأ بصمت).
4. إن كان mpv يرفض روابط googlevideo: جرّب تمرير `httpHeaders: {'User-Agent': ...}` في `Media(...)`.

### ملاحظات UI ظهرت في التشغيل الحي (للإصلاح بعد حل التشغيل)
1. **كل بطاقات الرئيسية الأفقية تعرض شريط "BOTTOM OVERFLOWED BY 23 PIXELS"** — إصلاح الـ overflow السابق عالج حاوية الاختبار (240→320) لا البطاقة نفسها؛ على الجهاز الحقيقي المشكلة أكبر (23px).
2. **كل الصور المصغرة سوداء/فارغة** — لا تُحمَّل أي thumbnail (مرشح قوي: `maxResUrl` يعيد 404 لمعظم الفيديوهات كما حذّرت المراجعة الأولى؛ استخدم `mediumResUrl` أو fallback متدرج).
3. الرئيسية تعرض قسم "Trending" مكرراً مرتين متطابقتين.

### الخلاصة
المشروع انتقل من "لا يُترجم" إلى "**يعمل على جهاز ويعرض بيانات حقيقية**" — أكبر قفزة منذ البداية. بوابة Go/No-Go متوقفة الآن على مشكلة واحدة: تشغيل الـ stream في mpv. أدوات التشخيص جاهزة (`tool/poc_check.dart` + خطة التشخيص أعلاه).

---

## ملحق 6: 🎉 بوابة الـ PoC اجتُيزت — تشغيل فيديو حقيقي بصوت وصورة (2026-08-03)

**تم إنجاز هذا بنفسي في هذه الجلسة.** التطبيق الآن يشغّل فيديوهات يوتيوب فعلياً على محاكي أندرويد.

### الدليل النهائي (لقطات + سجلات)
```
loadVideo: metadata done in 6887ms
loadVideo: stream resolved in 4255ms (2160p, audio: true)
loadVideo: opening video in mpv via http://127.0.0.1:39841/s0
loadVideo: external audio track attached
```
لقطة الشاشة: صورة الفيديو ظاهرة والعداد يتقدّم (4:29 / 37:30). قاعدة البيانات على الجهاز تحتوي سجلات مشاهدة ومواضع استئناف حقيقية.

### أربع مشاكل جذرية اكتُشفت وحُلّت (لم تكن معروفة سابقاً)

**1. خنق يوتيوب للروابط (السبب الجذري الأكبر)**
عميل `androidSdkless` الافتراضي في youtube_explode يعطي روابط تتوقف عن الخدمة بعد ~1 ميغابايت (مشكلة الـ n-param). قِسته تجريبياً: androidVr يسلّم 6MB كاملة بينما android/androidSdkless يتوقفان عند 1MB. الحل: `getManifest(ytClients: [androidVr, android, androidSdkless])` بسلسلة احتياطية — androidVr أولاً، والبقية عند فشله (بعض الفيديوهات "unplayable" على androidVr).

**2. فشل TLS في mpv + رفض النطاقات المفتوحة**
mpv يفشل في فتح روابط googlevideo (`mbedtls_ssl_read returned -0x0`)، ويوتيوب يرفض `Range: bytes=0-` المفتوح بـ403. الحل: **وسيط محلي جديد** [lib/core/network/stream_proxy.dart](flutter_poc/lib/core/network/stream_proxy.dart) يعمل على `127.0.0.1`، يجلب البيانات بمكدس Dart (يعمل حيث يفشل mpv)، ويقسّم الطلبات إلى شرائح محدودة مع **تفاوض تلقائي على الحجم** (1MB→512K→...→64K) لأن الحد يختلف بين الشبكات، ويدعم `&range=` كمعامل استعلام مع الترويسة كاحتياط. يمرّر Range للأمام فيبقى الـ seek يعمل.

**3. مخرَج فيديو mpv لا يُهيَّأ (`Could not create EGL context for GLES 2.x`)**
media_kit يفرض على المحاكي مساراً برمجياً يحتاج سياق EGL خاصاً يفشل إنشاؤه. جرّبت: swiftshader، host GPU، تعطيل Impeller — كلها فشلت. الحل الناجح: `VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')` — mpv يفك الترميز مباشرة إلى سطح أندرويد بلا GL خاص به. يعمل على المحاكي والأجهزة الحقيقية.

**4. اختيار الجودة كان محدوداً بـ720p**
الافتراضي `MediaFormatQuality.high` = سقف 720p في موضعين (الكيان وقارئ التفضيلات). رُفع إلى `highest` فصار يختار حتى 2160p فعلياً.

### إصلاحات إضافية أُنجزت وتُحقّق منها بصرياً
- **الصور المصغرة السوداء**: `maxResUrl` (404 لمعظم الفيديوهات) → `highResUrl`. الصور تظهر الآن.
- **overflow البطاقات (23px)**: التصحيح السابق عالج حاويات الاختبار فقط؛ الآن `Flexible` حول الصورة فاختفى الشريط الأصفر على الجهاز.
- **تكرار Trending**: الرئيسية كانت تستدعي نفس الدالة مرتين. الآن 4 أقسام موضوعية (Music/Gaming/Technology/News) تُجلب بالتوازي، وفشل قسم لا يُفرغ الشاشة.
- **هشاشة التحليل لدى يوتيوب**: `NoSuchMethodError: getT` كان يُفرغ الرئيسية؛ أُضيفت محاولات متعددة بعبارات بحث مختلفة + `whereType<Video>()`.
- **رصد أخطاء المشغّل**: إضافة الاستماع لـ `Player.stream.log/error` + timeouts على كل جلب شبكي (كانت الأخطاء تختفي بصمت).

### أدوات تركت في المشروع
[tool/poc_check.dart](flutter_poc/tool/poc_check.dart) — تشخيص مستقل: يجلب البيانات والـ manifest ويحمّل بايتات فعلية من روابط الفيديو والصوت. مفيد للتحقق السريع عند أي تغيير من يوتيوب مستقبلاً.

### الحالة النهائية (تحقق فعلي)
| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ **0 أخطاء** (27 تحذيراً أسلوبياً) |
| `flutter test` | ✅ **48/48** |
| `flutter build apk` | ✅ ناجح |
| تصفح + بحث + قنوات | ✅ بيانات حقيقية |
| **تشغيل فيديو بصوت وصورة** | ✅ **يعمل — حتى 2160p** |
| تاريخ المشاهدة + الاستئناف (Drift) | ✅ يُكتب فعلياً على الجهاز |

**النسبة المحدّثة: المنتج العامل ~60%** (كان 0%). المتبقي: PiP وBackground audio (كود native)، التنزيل، تسجيل الدخول، وتنظيف 27 تحذيراً.

---

## ملحق 7: تنفيذ الحزمة الكاملة — PiP، الخلفية، التنزيل، تسجيل الدخول، وواجهة يوتيوب (2026-08-03)

نُفِّذت كل البنود المطلوبة وجرى التحقق منها بالتشغيل الفعلي على محاكي أندرويد مع لقطات شاشة.

### 1. Picture-in-Picture ✅ (يعمل بصرياً)
- كود native جديد في [MainActivity.kt](flutter_poc/android/app/src/main/kotlin/com/smarttube/smarttube_poc/MainActivity.kt): `enterPictureInPictureMode` بنسبة عرض مضبوطة، مع ردّ `onPictureInPictureModeChanged` و`onUserLeaveHint` إلى Dart.
- [pip_manager.dart](flutter_poc/lib/services/pip_manager.dart) أُعيد كتابته: الدعم يُسأل عنه النظام (بدل الادعاء)، ومعالجات القنوات مثبتة.
- **مشكلة حُلّت أثناء الاختبار:** أول تجربة أعطت نافذة PiP سوداء — السبب أن الشاشة كانت تبني شجرة ودجت مختلفة عند الدخول، فيُهدَم سطح العرض الأصلي. الحل: شجرة واحدة لكل الأوضاع (عادي/ملء الشاشة/PiP) مع تغيير التخطيط فقط.

### 2. التشغيل بالخلفية ✅
- [audio_player_handler.dart](flutter_poc/lib/services/audio_player_handler.dart) أُعيد كتابته: يشارك نفس نسخة `Player` مع الواجهة، ويبثّ الموضع والتخزين المؤقت وحالة الانتظار والسرعة، ويعرض أزرار تحكم حقيقية.
- **مشكلة حُلّت:** التطبيق كان يعلق على شاشة البداية — `audio_service` يشترط أن يرث النشاط من `AudioServiceActivity` وليس `FlutterActivity`.
- **دليل التحقق:** إشعار وسائط كامل بصورة الفيديو والعنوان والقناة وأزرار التقديم/التشغيل بعد الضغط على Home، مع `category=transport` وخدمة أمامية نشطة في `dumpsys`.

### 3. التنزيلات ✅ (تعمل فعلياً)
- جدول Drift جديد `downloads_table` + ترقية المخطط إلى v3 بترحيل صحيح.
- [download_manager.dart](flutter_poc/lib/services/download_manager.dart) أُعيد كتابته بالكامل: **كان سيفشل حتماً** لأنه استخدم `dio.download` بطلب مفتوح، وقد أثبتنا سابقاً أن يوتيوب يرفض ذلك بـ403. الآن يمرّ عبر نفس منطق الشرائح المتفاوض عليها في الوسيط، ويحمّل الفيديو والصوت كملفين (لأن يوتيوب يفصلهما فوق 360p).
- شاشة [downloads_screen.dart](flutter_poc/lib/presentation/screens/downloads/downloads_screen.dart) + تشغيل محلي عبر `/player/:id?offline=1`.
- **دليل التحقق:** نسبة التقدم تظهر وتتقدم في الواجهة، والملف على القرص بلغ 42 ميغابايت أثناء المراقبة.

### 4. تسجيل الدخول ✅
- [oauth_client.dart](flutter_poc/lib/data/youtube/auth/oauth_client.dart): تدفق device code كما في SmartTube (رمز يُدخَل في جهاز آخر)، مع تجديد تلقائي للتوكن.
- [sign_in_screen.dart](flutter_poc/lib/presentation/screens/settings/sign_in_screen.dart): يعرض الرمز والرابط وحالة الانتظار، **مع تحذير صريح** بأن التطبيق غير رسمي وقد يعرّض الحساب للتقييد.
- التوكن يُخزَّن في keystore الجهاز عبر `flutter_secure_storage`.

### 5. واجهة المشغّل بنمط النظام المصدر ✅
جرى مسح مصدر SmartTube لمعرفة قوائمه الحقيقية، ثم بُنيت [player_settings_sheet.dart](flutter_poc/lib/presentation/screens/player/widgets/player_settings_sheet.dart) بالأقسام المقابلة:

| القسم | المحتوى |
|---|---|
| Quality | كل الارتفاعات المتاحة فعلياً من الـ manifest، مع إعادة تحميل تحافظ على الموضع |
| Playback speed | 0.25x → 3.0x |
| Subtitles / CC | مسارات الترجمة الحقيقية للفيديو (تمرّ عبر الوسيط أيضاً) |
| Repeat mode | إيقاف / تكرار / إيقاف مؤقت عند النهاية |
| Sleep timer | 15 → 120 دقيقة |
| SponsorBlock | تفعيل + تخطٍ تلقائي + الفئات التسع |
| Video zoom | Default / Fit width / Fit height / Stretch / Zoom |
| Seek interval | 1 → 60 ثانية (نفس قيم المصدر) |
| Stats for nerds | المعرّف، الدقة، الترميز، معدل البت، مسار الصوت، التخزين المؤقت |

وشاشة المشغّل نفسها أصبحت صفحة مشاهدة كاملة: مشغّل 16:9 بطبقة تحكّم تختفي تلقائياً، ثم العنوان والبيانات، وشريط أزرار (إعجاب/تعليقات/حفظ/تنزيل/مشاركة)، وصف قابل للتوسيع، صف القناة مع زر اشتراك، وقائمة "Up next".

### 6. إعادة تصميم الواجهة العامة ✅
- الرئيسية: شريط علوي بالشعار وأزرار (تنزيلات/بحث/إعدادات)، شرائط مواضيع أفقية، وتغذية عمودية ببطاقات كبيرة.
- البطاقات: تخطيط يوتيوب (صورة بعرض الشاشة + صورة القناة + عنوان سطرين + سطر بيانات موحّد).
- التنقّل السفلي: أُضيف تبويب Shorts (كانت الشاشة غير قابلة للوصول)، وحُذف زر البحث العائم الذي كان يغطي المحتوى.

### الحالة النهائية (تحقق فعلي)
| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ **0 أخطاء** (25 تحذيراً أسلوبياً) |
| `flutter test` | ✅ **48/48** |
| `flutter build apk` | ✅ ناجح |
| تشغيل فيديو بصوت وصورة | ✅ حتى 2160p |
| PiP | ✅ نافذة عائمة تعرض الفيديو |
| تشغيل بالخلفية + إشعار | ✅ |
| التنزيل | ✅ بايتات فعلية على القرص |
| تسجيل الدخول | ✅ الشاشة والتدفق جاهزان |

**النسبة المحدّثة: المنتج العامل ~80%.** المتبقي: تفعيل استخدام توكن الدخول في طلبات المحتوى (الاشتراكات الحقيقية)، ودعم PiP على iOS (يحتاج AVPlayerLayer)، وتنظيف الـ25 تحذيراً.

---

## ملحق 8: تفعيل الحساب الحقيقي وإزالة آخر البيانات الوهمية (2026-08-03)

سجّل المستخدم دخوله فعلياً بحساب Google، فرُبط التوكن بطلبات المحتوى وأُزيلت البيانات الوهمية المتبقية.

### 1. عميل InnerTube موثّق — [authenticated_client.dart](flutter_poc/lib/data/youtube/authenticated_client.dart)
`youtube_explode_dart` لا يعرف الحسابات إطلاقاً، فكل ما يعتمد على "من يشاهد" يمرّ الآن عبر InnerTube مباشرة بترويسة `Bearer` — نفس أسلوب SmartTube.

**قرار تصميمي:** الاستجابات تُحلَّل بمسح شجري (walk) بدل مسارات ثابتة، لأن يوتيوب يغيّر تخطيطه باستمرار بينما أشكال الـ renderers تبقى معروفة.

**ثلاث مشاكل حقيقية اكتُشفت أثناء الاختبار على الجهاز:**
1. **صفر نتائج رغم نجاح الطلب** — عميل التلفزيون (TVHTML5) يستخدم `tileRenderer` وليس `videoRenderer`؛ المعرّف داخل `onSelectCommand.watchEndpoint` والنصوص داخل `tileMetadataRenderer.lines`. أُضيف دعم للشكلين.
2. **معرّف فيديو غير صالح (16 حرفاً)** — الرفوف والقنوات بلاطات أيضاً؛ الآن يُشترط وجود watch endpoint أو معرّف بالشكل الصحيح (11 محرفاً).
3. **بيانات مشوّهة في البطاقات** — أسطر البلاطة مترجَمة ومرتّبة بشكل مختلف حسب السطح، فصارت القيم تُعرف بشكلها لا بموضعها (مشاهدات/تاريخ)، مع دعم اختصارات الأعداد بالعربية والإنجليزية (ألف/مليون/K/M)، وتاريخ مجهول يُخفى بدل عرض "just now".

**دليل التحقق من الجهاز:**
```
InnerTube home: 16 videos
InnerTube subscriptions: 44 videos
InnerTube like/like: sending authenticated request
```
ولقطات الشاشة تُظهر محتوى المستخدم العربي الحقيقي في الرئيسية والاشتراكات.

### 2. ما صار حقيقياً
| الميزة | قبل | بعد |
|---|---|---|
| الرئيسية | نتائج بحث عامة | **توصيات يوتيوب المخصّصة للحساب** |
| الاشتراكات | فارغة دائماً | **44 فيديو من اشتراكات الحساب** + تبويبان (Latest/Channels) + زر مزامنة القنوات |
| الإعجاب | محلي فقط | **يُرسل ليوتيوب فعلياً** (`like/like`) |
| الاشتراك بقناة | محلي فقط | **يُرسل ليوتيوب** (`subscription/subscribe`) |
| التعليقات | `[]` ثابتة | **مربوطة بـ CommentsService الحقيقي** |
| Shorts | `[]` ثابتة | **بحث حقيقي مُرشَّح على ≤90 ثانية** |
| اقتراحات البحث | 4 نصوص مكتوبة يدوياً | **اقتراحات يوتيوب الفعلية** أثناء الكتابة |

جميع الطلبات الموثّقة تسقط بأمان إلى المسار المحلي عند عدم تسجيل الدخول أو فشل الشبكة.

### 3. إصلاحات جانبية
- `ErrorView` كانت تتجاوز مساحتها بـ92 بكسل داخل مربع المشغّل — صارت متجاوبة مع الارتفاع المتاح.
- استعادة الجلسة كانت غير متزامنة فتفوّت أول طلب؛ الآن الطلب الموثّق يستعيد التوكن بنفسه من التخزين الآمن.

### الحالة النهائية
| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ 0 أخطاء (25 تحذيراً أسلوبياً) |
| `flutter test` | ✅ 48/48 |
| `flutter build apk` | ✅ |
| تسجيل دخول حقيقي + محتوى مخصّص | ✅ مُثبَت بلقطات |

**النسبة: المنتج العامل ~90%.** المتبقي: التعريب الفعلي للنصوص (ملفات ARB موجودة بلا استخدام)، PiP على iOS، وتنظيف التحذيرات.

---

## ملحق 9: مطابقة يوتيوب، التعريب الكامل، ونقل ميزات النظام المصدر (2026-08-03)

عمل مستقل بالكامل بينما المستخدم غير متاح. كل بند مُختبَر على المحاكي بلقطات.

### 1. الهوية البصرية — مرآة ليوتيوب الرسمي

بُني [app_theme.dart](flutter_poc/lib/presentation/theme/app_theme.dart) من رموز يوتيوب الفعلية بدل `ColorScheme.fromSeed` الذي كان يولّد ألواناً وردية عشوائية:

| الرمز | داكن | فاتح |
|---|---|---|
| الخلفية | `#0F0F0F` | `#FFFFFF` |
| الأسطح المرتفعة | `#212121` | `#F9F9F9` |
| الشرائح | `#272727` | `#F2F2F2` |
| الشريحة المختارة | `#F1F1F1` بنص أسود | `#0F0F0F` بنص أبيض |
| النص الثانوي | `#AAAAAA` | `#606060` |
| الفواصل | `#303030` | `#E5E5E5` |
| العلامة التجارية | `#FF0000` | |

الخط Roboto (خط يوتيوب)، وأُضيف `ThemeExtension` للرموز التي لا يملك Material خانة لها (خلفية أقراص الأزرار، لون النص الثانوي) فلا تكتب أي شاشة لوناً ثابتاً.

**المكوّنات:** شريط سفلي بلا مؤشر حبة وبأيقونات ممتلئة عند الاختيار، شرائح Stadium، زر اشتراك أسود/أبيض معكوس، شريط تقدّم أحمر، أوراق سفلية بحواف 16px.

**البطاقات** أُعيد بناؤها بمقاسات يوتيوب: صورة 16:9 بعرض الشاشة، صورة قناة 36px، عنوان 14sp بسطرين، سطر بيانات موحّد 12sp، وزر ⋮ — بدل بطاقة Material بحواف وظل.

**المشغّل:** صف الأزرار صار أقراصاً كما في يوتيوب، مع **قرص إعجاب/عدم إعجاب مدمج بفاصل** يعرض الأعداد الحقيقية.

### 2. التعريب الكامل
ملفات ARB ارتفعت من 59 إلى **119 مفتاحاً** بالعربية والإنجليزية، ورُبطت فعلياً بالشاشات (الرئيسية، التنقّل، المشغّل، الإعدادات). حُذف `Directionality` اليدوي لأن الاتجاه يتبع اللغة تلقائياً عبر الـ delegates. **مُختبَر:** الواجهة تنقلب كاملة إلى RTL وتُترجم فور اختيار العربية.

**قرار:** عناوين شرائح المواضيع مترجَمة لكن الاستعلام المُرسل ليوتيوب يبقى إنجليزياً، فالنتائج واحدة في كل اللغات.

### 3. ميزات نُقلت من النظام المصدر (بعد مسح شامل للكود)

| الميزة | الحالة |
|---|---|
| **فلترة المحتوى** (شورتس/مشاهَد/قادم/بث لكل سطح) | ✅ [content_filter.dart](flutter_poc/lib/domain/entities/content_filter.dart) — 9 مفاتيح + خوارزمية كشف الشورتس نفسها (≤90 ثانية، أو ≤3 دقائق مع #) والافتراضيات نفسها |
| **القنوات المحظورة** | ✅ لا تظهر فيديوهاتها في أي تغذية |
| **الصور المصغّرة البديلة** (hq1/hq2/hq3) | ✅ استبدال إطار من الفيديو بدل صورة الناشر — بإعادة كتابة الرابط فقط، بلا كلفة شبكة |
| **Return YouTube Dislike** | ✅ أعداد الإعجاب/عدم الإعجاب الحقيقية في المشغّل |
| **DeArrow** | ✅ أُعيدت كتابة الخدمة: العنوان الصحيح `sponsor.ajay.app/api/branding`، واختيار المدخل المقفول ثم الأعلى تصويتاً، والصور تُبنى من الطابع الزمني عبر خادم DeArrow (الكود السابق كان يفترض شكل استجابة خاطئاً فيرجع null دائماً) |
| **قائمة الانتظار** | ✅ إضافة/تشغيل تالياً/حذف + انتقال تلقائي عند انتهاء الفيديو |
| **تعزيز الصوت حتى 300%** | ✅ مع تحذير التشويه كما في المصدر |
| **الفصول (Chapters)** | ✅ علامات على شريط التقدّم + اسم الفصل الحالي تحت الشريط + صف فصول قابل للنقر |
| **إيماءات السطوع/الصوت** | ✅ سحب عمودي — السطوع يساراً والصوت يميناً مع مؤشر مؤقت |
| **مقدار التقديم** | ✅ 1→60 ثانية بنفس قيم المصدر |

### 4. تنظيف
التحذيرات من **26 إلى 1**: استيرادات غير مستخدمة، أنواع عامة ناقصة، مؤكدات null زائدة، وترتيب `catch` خاطئ كان يجعل `VideoUnavailableException` كوداً ميتاً.

### 5. PiP على iOS — قرار صريح
**لم يُنفَّذ، ولن يُنفَّذ بهذه البنية.** PiP على iOS يتطلب `AVPictureInPictureController` مربوطاً بـ `AVPlayerLayer`، بينما mpv يرسم في texture لا يملكه النظام. الخيارات: مشغّل ثانٍ لـ iOS، أو تمرير عيّنات إلى `AVSampleBufferDisplayLayer` (عمل كبير). يعمل على أندرويد بالكامل.

### الحالة النهائية
| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ **0 أخطاء · 1 تحذير** |
| `flutter test` | ✅ 48/48 |
| `flutter build apk` | ✅ |
| الوضع الداكن/الفاتح | ✅ مطابق ليوتيوب (لقطات) |
| العربية + RTL | ✅ مُختبَر على الجهاز |
| المحتوى المخصّص من الحساب | ✅ |

**النسبة: المنتج العامل ~95%.** المتبقي: PiP على iOS (قرار معماري)، ومجموعات القنوات، وتذكّر السرعة لكل قناة، والنسخ الاحتياطي للإعدادات.

---

# ملحق 10 — الملاحظات الخمس (تنفيذ وتحقق ميداني)

راجعتُ النقاط الخمس المرسلة. **ثلاث منها كشفت أخطاءً حقيقية في الكود** لا مجرد نقص ترجمة، ووجدتُ خطأين إضافيين أثناء الفحص.

## 1) التقطيع أثناء التشغيل — سببه ثلاثة أخطاء لا المحاكي

### أ. الجودة الافتراضية كانت تشغّل 4K دائماً (السبب الأكبر)
`MediaFormatQuality.highest` مكتوب في الواجهة أنه «1080p فأكثر» ويضبط `maxHeight = 1080`، لكن الكود كان يقفز فوق هذا السقف:

```dart
if (quality == best || quality == highest) return withResolution.first; // ← 2160p
```

فكل مقطع كان يُفتح بأعلى دقة متاحة مهما كان الإعداد. القياس على الجهاز:

| | قبل | بعد |
|---|---|---|
| سطح الفيديو | `3840×2160` | `1920×1080` |
| المخزون المؤقت أمام موضع التشغيل | **40 مللي ثانية** | **3.7 ثانية** |

`best` وحدها الآن بلا سقف.

### ب. المُرحِّل كان يتوقف بين كل شريحة وأخرى
`StreamProxy` كان يجلب شريحة ← يكتبها ← يجلب التالية، فيبقى mpv بلا بيانات طوال زمن كل رحلة شبكة. أعدت بناءه ليبدأ تنزيل الشريحة التالية **قبل** كتابة الحالية، مع تخزين حجم الملف ونوع صيغة النطاق التي يقبلها الخادم بدل إعادة اكتشافهما في كل طلب.

### ج. عند تغيير الجودة كان المُرحِّل القديم يستمر بالتنزيل
كل `register` كان يضيف مساراً جديداً دون إزالة القديم، فيتنافس تياران على النطاق. أضفت `retainOnly`.

**النتيجة النهائية المقيسة: 60 ثانية من المخزون المؤقت عند 720p** (كانت 40 مللي ثانية).

## 2) تغيير الجودة «ما فيه استجابة» — القائمة الفرعية لم تكن تفتح أصلاً

الخطأ في `player_settings_sheet.dart`:

```dart
Navigator.of(context).pop();          // أغلق الورقة
showModalBottomSheet(context: context) // ثم استخدم سياقها المُغلق
```

بعد `pop` يصبح الـ context ميتاً، فالورقة الجديدة لا تُفتح **بصمت** والنقرة تنفذ إلى الصفحة خلفها (كانت تنقلني إلى صفحة القناة). لذلك كان الضغط على «الجودة» يبدو بلا أثر.

أعدت البناء إلى **مسار واحد تُبدَّل صفحاته داخلياً** — وهو أيضاً سلوك يوتيوب نفسه.

وأصلحت ثلاثة أمور مرتبطة:
- تغيير الجودة كان يعيد تحميل **بيانات المقطع كاملة** (10 ثوانٍ إضافية بلا داع)؛ الآن يعيد حل الروابط فقط مع الحفاظ على الموضع والسرعة وحالة التشغيل.
- عند رفض الرابط المختار كان النظام يقفز إلى **أعلى دقة** — أي يتجاهل طلبك؛ الآن الترتيب البديل حسب القرب من اختيارك.
- ظهور مؤشر «جارٍ التحويل إلى 720p» وعلامة صح فورية على الاختيار.

**التحقق:** `VideoOutput.Resize {1280, 720}` والقائمة تعرض `720p` والتشغيل مستمر.

## 3) الترجمة

| الموضع | قبل | بعد |
|---|---|---|
| مفاتيح ARB | 119 | **145** |
| الإعدادات | عناوين فقط | كل شيء: الأوصاف، الفئات التسع لحظر الرعايات، مفاتيح إخفاء المحتوى، المظهر، الجودة، الصور المصغّرة |
| إعدادات المشغّل | إنجليزي بالكامل | عربي بالكامل (11 صفحة) |
| الاشتراكات، المكتبة، التنزيلات، التعليقات، القناة، تسجيل الدخول، الشورتس، البحث | إنجليزي | مترجَمة |
| التواريخ والمشاهدات | `years ago 16` | `قبل 16 سنة` بصيغ المثنى والجمع العربية |

نقلت نصوص الـ enums من طبقة الـ domain إلى `presentation/l10n/enum_labels.dart` وحذفت النسخ الإنجليزية، فلم يعد هناك مصدران للنص.

## 4) الشريط الجانبي من النظام المصدر

مسحت `BrowsePresenter` في المصدر واستخرجت أقسامه الثمانية عشر. الشريط الجانبي الآن موجود مع كل قسم له بيانات فعلية:

**نُفِّذ:** الرئيسية · شورتس · الاشتراكات · الرائج · موسيقى · ألعاب · أخبار · رياضة · بث مباشر · سجل المشاهدة · مشاهدة لاحقاً · المفضلة · التنزيلات · الإعدادات

**استُبعد عمداً** (لن يُحمَّل شيء):

| القسم | السبب |
|---|---|
| الإشعارات | يحتاج نقطة `notifications` من الحساب — غير منفَّذة |
| مقاطعي (My videos) | يحتاج قناة المستخدم من الحساب |
| Kids home | خدمة يوتيوب منفصلة |
| قوائم التشغيل | لا توجد شاشة قوائم تشغيل بعد — **مرشّح للإضافة، أخبرني** |
| القنوات المحظورة | موجود داخل الإعدادات |
| قائمة التشغيل | موجودة داخل المشغّل |

## 5) الرئيسية والاشتراكات

- **المكتبة كانت وهمية**: تعرض `Video 1` و`Video 2` و«Watched recently» بدل المقاطع الحقيقية. أعدت بناءها بالكامل ببطاقات حقيقية وتبويبات قابلة للربط المباشر.
- **الاشتراكات**: أضفت شريط صور القنوات الأفقي كما في يوتيوب مع الفلترة بالضغط على قناة، وترجمة كاملة.
- **البحث**: كان يعرض سجل بحث ملفَّق (`Flutter tutorial`, `Music`) لم يكتبه المستخدم — حُذف.
- **الرئيسية**: أضفت زر القائمة الجانبية.

## أخطاء إضافية وجدتها أثناء الفحص

| الخطأ | الأثر |
|---|---|
| **الترجمات مكرّرة خمس مرات** | يوتيوب يعيد المسار لكل صيغة (srv1/srv2/srv3/ttml/vtt)؛ الآن واحد لكل لغة بصيغة `vtt` |
| **مقاطع مقيّدة تتجمّد بصمت** | قِست بـ `tool/client_probe.dart`: بعض المقاطع يوقف يوتيوب بثها عند ~3 ميغابايت **مع كل العملاء** وحتى برابط جديد. الآن تظهر رسالة واضحة بدل التجمّد |
| **إعداد المحاكي نفسه** | `basma.avd` مضبوط على `320×640 @160dpi` داخل `config.ini` — لذلك لم يكن `wm size reset` يفلح. صُحِّح إلى `1080×2400 @420dpi` (نسخة احتياطية في `config.ini.bak`) |

## أدوات تشخيص أضفتها للمستودع

- `tool/client_probe.dart` — يقيس أي عميل يوتيوب يخدم البث بلا سقف، ولكل مقطع.
- `tool/range_probe.dart` — يحدد أين يتوقف الخادم وهل السبب صيغة النطاق أم الرابط أم المقطع.

## الحالة

| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ **0 أخطاء · 0 تحذيرات** |
| `flutter test` | ✅ 48/48 |
| `flutter build apk` | ✅ |
| تغيير الجودة | ✅ مُختبَر: 1080p ← 720p على الجهاز |
| المخزون المؤقت | ✅ 60 ثانية (كان 40 مللي ثانية) |
| الترجمة | ✅ لقطات لكل الشاشات |
| الشريط الجانبي | ✅ يعمل بالعربية RTL |

---

# ملحق 11 — قوائم التشغيل، تخصيص الرئيسية، الاشتراكات، ومزامنة السجل

## 1) قوائم التشغيل ✅

نقطة النهاية العاملة: `browse` مع `FEplaylist_aggregation` (جرّبتُ ثلاثة معرّفات ويُختار أولها الذي يُرجع بيانات). محتوى القائمة عبر `browse VL<playlistId>`.

**التحقق على الجهاز:** `InnerTube playlists: 8 via FEplaylist_aggregation` — ظهرت قوائمك الحقيقية (عراقي، add، المفضلة، ووو، بيتكوين، alfareszz) وفتحتُ «عراقي» فحمّلت **14 مقطعاً**. أضفتُ أيضاً «مشاهدة لاحقاً» و«المفضلة» لأن يوتيوب يحتفظ بهما ضمنياً ولا يدرجهما في القائمة.

الوصول: الشريط الجانبي ← قوائم التشغيل.

## 2) الرئيسية أقرب لليوتيوب الرسمي ✅

سببان جعلا الرئيسية مختلفة عن حسابك:

**أ. اللغة والبلد كانا مثبّتين على `en`/`US`.** يوتيوب يخصّص التوصيات باللغة والمنطقة، فكان الحساب العربي يستقبل خلاصة أمريكية عامة. الآن `hl` يتبع لغة التطبيق و`gl` يصبح `SA` عند العربية.

**ب. صفحة واحدة فقط.** كانت الخلاصة تتوقف عند أول استجابة. الآن تتبع رمز المتابعة (continuation) ثلاث صفحات.

**القياس: من 15 مقطعاً إلى 31.**

## 3) مشكلة الاشتراكات ✅ — تبيّن أن نقطة النهاية غير موجودة أصلاً

تبويب «القنوات» كان فارغاً حتى بعد الضغط على المزامنة. حقنتُ تشخيصاً يطبع أسماء الـ renderers الفعلية في الاستجابة، فظهر السبب:

| ما جرّبته | ما أعاده فعلاً |
|---|---|
| `guide` | `guideEntryRenderer` لكنها **عناصر تنقل**: بحث، الصفحة الرئيسية، رياضة — لا اشتراكات |
| `FEsubscriptions` | `avatarLockupRenderer` لكنها **شرائح تصفية**: «الأكثر صلة باهتماماتك»، «كلّ الاشتراكات»، Shorts |
| `FEchannels` | مقاطع فيديو، لا قنوات |

**واجهة التلفزيون لا تعرض قائمة القنوات إطلاقاً.** لذلك اشتققتُها من الخلاصة نفسها: كل بطاقة تحمل نقطة تصفّح قناتها. **النتيجة: 31 قناة**، مرتّبة حسب الأحدث نشراً.

وأصلح هذا خطأً ثانياً: بطاقات واجهة التلفزيون كانت تصل بـ `channelId` **فارغ**، فلو ضغطت على قناة في الشريط العلوي للاشتراكات لما رشّحت شيئاً.

كما أن مزامنة القنوات صارت **تلقائية** عند أول زيارة بدل انتظار ضغطة زر.

## 4) استكمال المقطع عبر الأجهزة ✅ — في الاتجاهين

كان الوضع: الموضع محفوظ **محلياً فقط**. لا يصل ما شاهدته على الكمبيوتر إلى هنا ولا العكس.

**السحب** — `browse FEhistory` يحمل مع كل مقطع نسبة ما شوهد منه (`thumbnailOverlayResumePlaybackRenderer.percentDurationWatched`). تُحوَّل إلى موضع زمني وتُكتب في قاعدة البيانات المحلية. لا تُستبدل قيمة محلية أحدث — الأبعد في المشاهدة يفوز.

**الدفع** — `api/stats/watchtime` مع `cpn` (معرّف جلسة تشغيل) و`cmt` (الموضع). يُرسَل كل 10 ثوانٍ مع الحفظ المحلي.

**التحقق على الجهاز:**

```
InnerTube history: 15 entries
HistorySync: pulled 15 entries, 14 positions applied
watchtime zDIK3jCtsTw @695s -> 204
```

ثم فتحتُ مقطعاً من الرئيسية **لم يُشغَّل في هذا التطبيق قط** فبدأ عند **11:57 من 49:57** — أي الموضع الذي تركته عليه في جهاز آخر. و`204` هي استجابة القبول لنقطة النهاية تلك.

⚠️ **ما لم أستطع التحقق منه بنفسي:** أن يوتيوب على الويب يعرض الموضع الذي دفعناه من هنا. تحقّقتُ من قبوله (204) ومن أن السحب يعمل، لكن رؤية الأثر في يوتيوب الرسمي تحتاج فتح حسابك — جرّبها: شغّل مقطعاً هنا لدقيقة، ثم افتحه على الكمبيوتر.

## أخطاء إضافية أُصلحت

- سجل المشاهدة كان يعرض «الآن» على كل صف لأن التاريخ المخزَّن هو وقت الكتابة لا وقت المشاهدة؛ الآن يُحذف التاريخ بدل عرض قيمة خاطئة (الترتيب يبقى بالأحدث).

## الحالة

| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ 0 أخطاء · 0 تحذيرات |
| `flutter test` | ✅ 48/48 |
| قوائم التشغيل | ✅ 8 قوائم، 14 مقطعاً في المفتوحة |
| الرئيسية | ✅ 15 ← 31 مقطعاً، باللغة والمنطقة الصحيحتين |
| الاشتراكات | ✅ 31 قناة |
| مزامنة السجل | ✅ سحب 15 مدخلاً، دفع مقبول (204)، استئناف عند 11:57 |

---

# ملحق 12 — أيقونة البث المباشر لا تفتح

الشاشة كانت **تفتح فعلاً**، لكن جلب المحتوى ينهار:

```
Exception: Search failed: NoSuchMethodError:
Class '_Map<String, dynamic>' has no instance method 'getT'
```

## المدى الحقيقي: أربعة من ستة أقسام، وشرائح الرئيسية معها

الأقسام كانت تُنفَّذ كـ**بحث نصي** عن اسم القسم عبر `youtube_explode`، وهو يقرأ صفحة النتائج بكشط HTML. اختبرتُ كل الاستعلامات على المضيف:

| الاستعلام | النتيجة |
|---|---|
| `music` | ✅ 20 نتيجة |
| `live` | ❌ NoSuchMethodError |
| `news` | ❌ NoSuchMethodError |
| `sports` | ❌ NoSuchMethodError |
| `gaming` | ❌ FormatException |
| `trending` | ❌ Redirect limit exceeded |

المحلّل ينهار على بطاقات البث المباشر والأرفف (shelves). ولأن **شرائح الرئيسية تستخدم نفس المزوّد**، كانت موسيقى وحدها تعمل من بينها أيضاً.

## الإصلاح: نطلب القسم من يوتيوب بدل البحث عن اسمه

أضفتُ `browse` و`search` و`guide` إلى عميل InnerTube المُوثَّق، وصار لكل قسم معرّف تصفّح حقيقي بسلسلة تراجع من أربع مراحل:

1. `browse` بمعرّف القسم (`FEtopics_live` وأخواته)
2. إن فشل: قراءة **دليل يوتيوب نفسه** ومطابقة القسم بأيقونته — المعرّفات تتغير، الأيقونات تبقى
3. إن فشل: `search` عبر InnerTube
4. إن فشل: البحث بالكشط (لغير المسجَّلين فقط)

**النتيجة على الجهاز:**

| القسم | قبل | بعد |
|---|---|---|
| بث مباشر | تعطُّل | ✅ 15 مقطعاً |
| موسيقى | يعمل بالبحث | ✅ 12 مقطعاً من `FEtopics_music` |
| ألعاب | تعطُّل | ✅ 72 مقطعاً |
| أخبار | تعطُّل | ✅ 14 مقطعاً |
| رياضة | تعطُّل | ✅ 20 مقطعاً |

## «الرائج» حُذف — يوتيوب ألغى القسم

جرّبتُ `FEtrending` و`FEtopics_trending` و`FEtopics_more` فكلها فارغة، و`search "trending"` أعاد صفراً. ودليل حسابك نفسه لم يعد يذكره:

```
WHAT_TO_WATCH=FEtopics  TROPHY=FEtopics_sports  GAMING=FEtopics_gaming
YOUTUBE_MUSIC=FEtopics_music  TAB_LIBRARY=FElibrary
SUBSCRIPTIONS=FEsubscriptions  TAB_MORE=FEtopics_more
```

فلا يوجد ما يُعرَض خلفه. **حذفتُه** بدل ترك أيقونة ميتة — وهي المشكلة التي أبلغتَ عنها أصلاً.

شرائح الرئيسية صارت مشتقّة من الأقسام نفسها، فما تراه في الشريط الجانبي وما تراه في الشرائح متطابقان ويعملان.

| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ 0 أخطاء · 0 تحذيرات |
| `flutter test` | ✅ 48/48 |

---

# ملحق 13 — تشغيل البث المباشر

القسم كان يفتح، لكن **تشغيل أي بث** ينتهي بـ«حدث خطأ ما». السبب معماري: كل مسار التشغيل مبني على **ملف بحجم ثابت يُجلب بمقاطع بايتية**، والبث المباشر ليس ملفاً — بل قائمة تشغيل متجددة.

## أربع مشكلات متتالية، كل واحدة كشفت التي بعدها

### 1. مكتبة الاستخراج لا تدعم البث أصلاً
`getManifest` ينهار بـ `Null check operator used on a null value`، و`getHttpLiveStreamUrl` يرفض البث الحيّ فعلياً بقوله «ليس بثاً جارياً». وكان انهيار جلب المسارات **يُسقط تحميل المقطع كله**، فلا تظهر حتى بياناته. الآن يُتجاوَز الخطأ للبث المباشر ويُكمَّل التحميل.

### 2. أي عميل يوتيوب يعطي رابط بث؟
قِستُ ذلك بـ `tool/live_player_probe.dart` على بث جارٍ:

| العميل | النتيجة |
|---|---|
| **ANDROID** | ✅ `hlsManifestUrl` + `dashManifestUrl` |
| IOS | SABR فقط، بلا قائمة تشغيل |
| WEB / MWEB | UNPLAYABLE |
| **TVHTML5** (عميلنا المسجَّل) | UNPLAYABLE — «يجب إعادة تحميل الصفحة» |
| ANDROID_VR | LOGIN_REQUIRED |

عميل التلفزيون الذي نستخدمه لكل شيء آخر **محجوب عن بيانات البث** ببوابة التصديق. فصار البث يمرّ عبر عميل أندرويد دون توثيق، والرابط يُسلَّم إلى mpv مباشرة بلا المُرحِّل المحلي — لأن المُرحِّل يمشي في ملف بمقاطع بايتية، وهو مفهوم لا وجود له في قائمة متجددة.

وأعدتُ `https` و`tls` إلى قائمة البروتوكولات المسموحة؛ كنتُ حذفتُهما حين صار كل شيء يمر عبر المُرحِّل.

### 3. رسائل mpv غير القاتلة كانت تُظهر شاشة خطأ
mpv يقول للبث «Cannot seek in this stream» و«Cannot reuse HTTP connection» و«ffurl_read returned…» — ولا شيء منها يعني فشل التشغيل. وكان المستمع لدينا يحوّل **أي** رسالة إلى شاشة خطأ، فيبدو البث معطلاً بينما هو على وشك العمل. الآن هناك قائمة بالرسائل غير القاتلة، والخطأ يُمسح تلقائياً بمجرد وصول أول إطار.

### 4. التشغيل يتجمد بعد أول مقطع
الصورة سوداء والوقت متوقف عند 0:01 رغم أن الحالة PLAYING. الرسالة التي كشفت السبب:

```
https: Cannot reuse HTTP connection for different host:
rr5---sn-hpa7znsz.googlevideo.com != rr8---sn-nuj-g0iez.googlevideo.com
```

يوتيوب يوزّع مقاطع البث على خوادم CDN مختلفة، وffmpeg يحاول إبقاء اتصال واحد عبرها فيفشل ويتوقف. الحل `http_persistent=0` مع إعادة المحاولة على أخطاء الشبكة.

## النتيجة

| القياس | قبل | بعد |
|---|---|---|
| بيانات المقطع | لا تُحمَّل | ✅ العنوان والقناة والإعجابات |
| رابط البث | لا يوجد | ✅ HLS عبر عميل أندرويد |
| الصورة | سوداء | ✅ 1920×1080 |
| الوقت | متجمد عند 0:01 | ✅ وصل 1:15 والمخزون المؤقت متقدم |

كما أُوقِف حفظ موضع التشغيل ورفعه إلى الحساب للبث المباشر — «أين توقفت» في بث حيّ هو دائماً «الآن».

## أدوات أُضيفت

- `tool/live_player_probe.dart` — يقارن سبعة عملاء يوتيوب ويطبع أيهم يعطي HLS/DASH لبث معيّن.
- `tool/live_probe.dart` — يفحص ما تستطيع مكتبة الاستخراج تقديمه لمقطع بث.

| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ 0 أخطاء · 0 تحذيرات |
| `flutter test` | ✅ 48/48 |

---

# ملحق 14 — تجهيز iOS

مشروع iOS **لم يكن موجوداً**: مجلد `ios/` فيه 7 ملفات مولَّدة فقط، بلا `Runner.xcodeproj` ولا `Podfile` ولا `AppDelegate`. جُهّز كل ما يمكن تجهيزه من ويندوز.

## عائق مؤكد كان سيعطي شاشة سوداء

مخرج الفيديو كان مثبّتاً على مفكّك أندرويد بلا أي شرط:

```dart
vo: 'mediacodec_embed', hwdec: 'mediacodec'   // لا وجود لهما على iOS
```

صار حسب المنصة: أندرويد كما هو، وiOS/macOS على `videotoolbox`، والباقي على الافتراضي. **تحققتُ أن أندرويد لم يتأثر** — التشغيل مستمر على 1920×1080.

## ما جُهّز

| العنصر | التفصيل |
|---|---|
| مشروع Xcode | وُلِّد بـ `flutter create --platforms=ios` |
| `Info.plist` | نجا من التوليد ولم يُدهس، وأُكمِلت نواقصه |
| `Podfile` | كُتِب يدوياً — Flutter يولّده على الماك فقط، فكانت أول خطوة على الماك ستفشل |
| هدف النشر | **13.0** في المشروع والـ Podfile والـ plist |

**نواقص `Info.plist` التي كانت ستوقف الإقلاع:** غياب `UILaunchStoryboardName` و`UIMainStoryboardFile` — المشروع المولَّد يشحن الـ storyboards لكن بلا هذين المفتاحين يقلع التطبيق على شاشة سوداء. وأُضيف `NSAllowsLocalNetworking` للمُرحِّل المحلي، و`UIFileSharingEnabled` لتظهر التنزيلات في تطبيق «الملفات»، ورُفِع `MinimumOSVersion` إلى 13.0 ليطابق المشروع.

**لماذا 13.0؟** مسحتُ أهداف النشر لكل الإضافات: `screen_brightness_ios` يشترط 13.0 وهو الأعلى، و`audio_service` و`just_audio` و`sqlite3_flutter_libs` تشترط 12.0. المشروع المولَّد كان بالفعل على 13.0.

**زر PiP** صار مخفياً على iOS بدل أن يظهر ويفشل دائماً — القيد المعماري (`AVPlayerLayer` مقابل texture) قائم كما هو.

## أثر جانبي من التوليد

`flutter create` أضاف `test/widget_test.dart` قالبياً يشير إلى صنف `MyApp` غير موجود في هذا المشروep، فكسر `flutter analyze` و`flutter test`. حُذِف.

## الباقي — لا يمكن عمله من ويندوز

`pod install` والتوقيع والبناء والاختبار الفعلي. الخطوات مكتوبة في [`ios/README_BUILD.md`](flutter_poc/ios/README_BUILD.md) مع ترتيب ما يجب اختباره أولاً حسب احتمال الفشل.

⚠️ **لم يُشغَّل أي شيء على iOS.** كل ما سبق تجهيز مبني على قراءة المتطلبات، لا على تشغيل.

| البند | النتيجة |
|---|---|
| `flutter analyze` | ✅ 0 أخطاء · 0 تحذيرات |
| `flutter test` | ✅ 48/48 |
| أندرويد بعد التغيير | ✅ يشتغل، 1920×1080 |
