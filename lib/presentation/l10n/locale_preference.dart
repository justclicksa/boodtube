// ============================================================
// Language preference → MaterialApp locale
// ============================================================
// "System default" is the app's real default: MaterialApp gets a null
// locale and Flutter matches the device against supportedLocales. The
// stored preference is a plain string so SettingsRepository needs no
// knowledge of it.
// ============================================================

import 'package:flutter/widgets.dart';

/// SharedPreferences key SettingsRepository stores the language under.
const languagePrefsKey = 'settings.language';

/// Stored value meaning "follow the device language".
const systemLanguageCode = 'system';

/// Every language the picker offers, in display order.
const supportedLanguageCodes = <String>[systemLanguageCode, 'en', 'ar'];

/// The locale to hand [WidgetsApp.locale], or `null` to follow the device.
///
/// Anything unrecognised — including the [systemLanguageCode] sentinel and
/// a preference written by a newer build — falls back to the device.
Locale? localeForLanguage(String language) => switch (language) {
      'ar' => const Locale('ar'),
      'en' => const Locale('en'),
      _ => null,
    };
