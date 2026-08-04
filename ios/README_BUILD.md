# بناء التطبيق على iOS

كل ما يمكن تجهيزه من ويندوز مُجهَّز. هذا الملف هو خطوات الماك فقط.

---

## ما هو جاهز بالفعل

| العنصر | الحالة |
|---|---|
| مشروع Xcode (`Runner.xcodeproj` / `.xcworkspace`) | ✅ مولَّد |
| `AppDelegate.swift` وتسجيل الإضافات | ✅ |
| `Podfile` | ✅ مكتوب يدوياً (Flutter يولّده على الماك فقط) |
| هدف النشر (Deployment target) | ✅ **13.0** في المشروع والـ Podfile و`Info.plist` |
| التشغيل في الخلفية | ✅ `UIBackgroundModes: audio` |
| أوصاف الخصوصية | ✅ |
| ATS + الشبكة المحلية للمُرحِّل | ✅ `NSAllowsLocalNetworking` |
| ظهور التنزيلات في تطبيق «الملفات» | ✅ `UIFileSharingEnabled` |
| مفكِّك الفيديو حسب المنصة | ✅ `videotoolbox` على iOS بدل `mediacodec` |
| إخفاء زر PiP على iOS | ✅ |
| أيقونات التطبيق وشاشة البدء | ⚠️ الافتراضية من Flutter — استبدلها لاحقاً |

**لماذا 13.0؟** أعلى ما تطلبه الإضافات: `screen_brightness_ios` يشترط 13.0،
و`audio_service` و`just_audio` و`sqlite3_flutter_libs` تشترط 12.0.

---

## خطوات الماك

### 1. المتطلبات

```bash
xcode-select --install          # أدوات سطر الأوامر
sudo gem install cocoapods      # أو: brew install cocoapods
flutter doctor                  # يجب أن يكون قسم Xcode أخضر
```

### 2. جلب الحزم وتثبيت الـ Pods

```bash
cd flutter_poc
flutter pub get
cd ios && pod install && cd ..
```

أول `pod install` يحمّل مكتبات mpv (كبيرة الحجم) — امنحه وقتاً.

### 3. التوقيع

افتح **`ios/Runner.xcworkspace`** — وليس `.xcodeproj` — ثم:

1. `Runner` ← `Signing & Capabilities`
2. فعّل **Automatically manage signing**
3. اختر فريقك في **Team** (حساب Apple ID عادي يكفي)
4. غيّر **Bundle Identifier** إلى قيمة فريدة لك، مثل
   `com.<اسمك>.smarttube` — القيمة الحالية `com.smarttube.smarttubePoc`
   قد تكون مأخوذة
5. تأكد من وجود **Background Modes → Audio, AirPlay, and Picture in
   Picture** (موجود في `Info.plist`، وXcode يعرضه هنا)

### 4. التشغيل على جهازك

```bash
flutter devices                 # تأكد أن الآيفون ظاهر
flutter run --release -d <device-id>
```

استخدم `--release`: بناء الـ debug على iOS بطيء جداً في التشغيل بسبب
JIT، وقد يوهمك أن المشغّل نفسه بطيء.

---

## ما يجب اختباره أولاً (وبهذا الترتيب)

هذه المسارات لم تُختبر على iOS إطلاقاً. رتّبتها من الأعلى احتمالاً للفشل:

1. **تشغيل مقطع عادي** — mpv على iOS مسار مختلف كلياً عن أندرويد.
   إن ظهرت شاشة سوداء فالمشكلة في `hwdec`؛ جرّب إزالة `videotoolbox`
   من `_videoOutputConfiguration` في `player_screen.dart` ليعود إلى
   فك التشفير البرمجي.
2. **المُرحِّل المحلي** — يستمع على `127.0.0.1`. إن فشل الاتصال فراجع
   `NSAllowsLocalNetworking`.
3. **البث المباشر** — يذهب إلى mpv عبر https مباشرة بلا مُرحِّل.
4. **الصوت في الخلفية وشاشة القفل** — يعتمد على `audio_service`.
5. **تسجيل الدخول** — يفتح المتصفح عبر `url_launcher`.
6. **التنزيلات** — تُكتب في مجلد Documents.

---

## المعروف أنه لن يعمل

**صورة داخل صورة (PiP).** يتطلب iOS ربط `AVPictureInPictureController`
بـ `AVPlayerLayer` يملكه النظام، وmpv يرسم في texture لا يملكه. الزر
مخفي على iOS بدل أن يظهر ويفشل. الحل يحتاج إما مشغّلاً ثانياً خاصاً
بـ iOS أو تمرير العيّنات إلى `AVSampleBufferDisplayLayer` — عمل معماري
كبير.

---

## التوزيع

آبل ترفض تطبيقات يوتيوب غير الرسمية (بند 5.2). **متجر التطبيقات
وTestFlight مستبعدان عملياً.** يبقى:

| الطريقة | المدة قبل انتهاء التوقيع |
|---|---|
| حساب Apple مجاني | **7 أيام**، ثم إعادة تثبيت |
| حساب مطوّر ($99/سنة) | سنة كاملة |
| AltStore / Sideloadly | يجدّد التوقيع تلقائياً |
