// ============================================================
// Subtitle styles — presets, live preview, preferred language
// ============================================================
// SmartTube ships a fixed list of caption looks (SubtitleManager
// .SubtitleStyle + PlayerData.initSubtitleStyles) rather than a colour
// picker: white or yellow text, over nothing / a translucent box / a
// solid box, with either a drop shadow or an outline. This file maps
// that list onto media_kit's `SubtitleViewConfiguration`.
//
// Kept widget-free so the mapping can be unit tested; the player screen
// and the settings sheet both build their configuration from here so the
// preview line and the real captions cannot drift apart.
// ============================================================

import 'package:flutter/painting.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../domain/entities/media_subtitle.dart';

/// Caption look. [custom] is the escape hatch that keeps honouring the
/// background-opacity slider in the player sheet.
enum SubtitleStyle {
  defaultStyle,
  white,
  whiteOnBlack,
  yellow,
  yellowOnBlack,
  custom,
}

/// How the glyph edges are drawn — SmartTube's `CaptionStyleCompat`
/// EDGE_TYPE_DROP_SHADOW / EDGE_TYPE_OUTLINE.
enum SubtitleEdge { dropShadow, outline }

/// SmartTube's `R.color.light_grey` for captions.
const subtitleWhite = Color(0xFFEEEEEE);

/// SmartTube's `R.color.yellow`.
const subtitleYellow = Color(0xFFFFFF00);

/// The translucent box the app has always drawn behind captions.
const defaultSubtitleBackgroundOpacity = 0.67;

/// Resolved colours for one preset.
class SubtitleStyleSpec {
  const SubtitleStyleSpec({
    required this.textColor,
    required this.backgroundColor,
    required this.edge,
  });

  final Color textColor;
  final Color backgroundColor;
  final SubtitleEdge edge;
}

/// Reads back a stored preset name, tolerating values written by an
/// older or a newer build.
SubtitleStyle subtitleStyleFromName(String? name) =>
    SubtitleStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => SubtitleStyle.defaultStyle,
    );

/// Colours for [style].
///
/// [customBackgroundOpacity] only reaches [SubtitleStyle.custom]; the
/// fixed presets ignore it on purpose, exactly like the native list.
SubtitleStyleSpec subtitleStyleSpec(
  SubtitleStyle style, {
  double customBackgroundOpacity = defaultSubtitleBackgroundOpacity,
}) {
  switch (style) {
    case SubtitleStyle.defaultStyle:
      // What BoodTube drew before presets existed, kept as the default
      // so upgrading does not change anyone's captions.
      return const SubtitleStyleSpec(
        textColor: Color(0xFFFFFFFF),
        backgroundColor: Color(0xAB000000),
        edge: SubtitleEdge.dropShadow,
      );
    case SubtitleStyle.white:
      return const SubtitleStyleSpec(
        textColor: subtitleWhite,
        backgroundColor: Color(0x00000000),
        edge: SubtitleEdge.dropShadow,
      );
    case SubtitleStyle.whiteOnBlack:
      return const SubtitleStyleSpec(
        textColor: subtitleWhite,
        backgroundColor: Color(0xFF000000),
        edge: SubtitleEdge.outline,
      );
    case SubtitleStyle.yellow:
      return const SubtitleStyleSpec(
        textColor: subtitleYellow,
        backgroundColor: Color(0x00000000),
        edge: SubtitleEdge.dropShadow,
      );
    case SubtitleStyle.yellowOnBlack:
      return const SubtitleStyleSpec(
        textColor: subtitleYellow,
        backgroundColor: Color(0xFF000000),
        edge: SubtitleEdge.outline,
      );
    case SubtitleStyle.custom:
      return SubtitleStyleSpec(
        textColor: const Color(0xFFFFFFFF),
        backgroundColor: const Color(0xFF000000).withValues(
          alpha: customBackgroundOpacity.clamp(0.0, 1.0),
        ),
        edge: SubtitleEdge.dropShadow,
      );
  }
}

/// media_kit paints captions with a plain `Text`, so the ExoPlayer edge
/// types have to be reproduced with `TextStyle.shadows`: one offset
/// shadow, or four hairline copies that read as an outline. `Shadow`
/// already defaults to opaque black, the edge colour SmartTube
/// hardcodes (`R.color.black`), so only the offsets differ here.
List<Shadow> subtitleEdgeShadows(SubtitleEdge edge) => switch (edge) {
      SubtitleEdge.dropShadow => const [
          Shadow(offset: Offset(1.6, 1.6), blurRadius: 3),
        ],
      SubtitleEdge.outline => const [
          Shadow(offset: Offset(-1.4, -1.4)),
          Shadow(offset: Offset(1.4, -1.4)),
          Shadow(offset: Offset(1.4, 1.4)),
          Shadow(offset: Offset(-1.4, 1.4)),
        ],
    };

/// Base caption size before the scale factor — the size the player has
/// always used at 1.0x.
const subtitleBaseFontSize = 28.0;

TextStyle subtitleTextStyleFor(
  SubtitleStyle style, {
  double scale = 1,
  double customBackgroundOpacity = defaultSubtitleBackgroundOpacity,
  double baseFontSize = subtitleBaseFontSize,
}) {
  final spec = subtitleStyleSpec(
    style,
    customBackgroundOpacity: customBackgroundOpacity,
  );
  return TextStyle(
    height: 1.35,
    fontSize: baseFontSize * scale,
    color: spec.textColor,
    fontWeight: FontWeight.w600,
    backgroundColor: spec.backgroundColor,
    shadows: subtitleEdgeShadows(spec.edge),
  );
}

/// The full configuration handed to media_kit's `Video`.
SubtitleViewConfiguration subtitleViewConfigurationFor(
  SubtitleStyle style, {
  double scale = 1,
  double bottomPadding = 24,
  double horizontalPadding = 24,
  double customBackgroundOpacity = defaultSubtitleBackgroundOpacity,
}) {
  return SubtitleViewConfiguration(
    style: subtitleTextStyleFor(
      style,
      scale: scale,
      customBackgroundOpacity: customBackgroundOpacity,
    ),
    padding: EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      bottomPadding,
    ),
  );
}

// ============================================================
// Preferred subtitle language
// ============================================================

/// Stored value meaning "follow the app language".
const appDefaultSubtitleLanguage = 'app';

/// Stored value meaning "never turn captions on by myself".
const noPreferredSubtitleLanguage = 'off';

/// Every option the settings picker offers, in display order.
const preferredSubtitleLanguageOptions = <String>[
  appDefaultSubtitleLanguage,
  noPreferredSubtitleLanguage,
  'en',
  'ar',
];

/// Turns the stored preference into a concrete language code, or `null`
/// when captions should stay off.
///
/// [appLanguage] is the app's own setting, which may itself be the
/// "system" sentinel — [deviceLanguage] resolves that.
String? resolvePreferredSubtitleLanguage(
  String preference, {
  required String appLanguage,
  required String deviceLanguage,
}) {
  if (preference == noPreferredSubtitleLanguage) return null;
  if (preference != appDefaultSubtitleLanguage) return preference;
  if (appLanguage == 'en' || appLanguage == 'ar') return appLanguage;
  return deviceLanguage.isEmpty ? null : deviceLanguage;
}

/// Picks the caption track to switch on for [languageCode].
///
/// Ranked the way a viewer would: an exact language match beats a
/// regional one ('en' over 'en-GB'), and a real caption track beats an
/// auto-generated transcript of the same language — SmartTube makes the
/// same distinction when it restores the last subtitle format.
MediaSubtitle? pickPreferredSubtitle(
  List<MediaSubtitle> subtitles,
  String? languageCode,
) {
  if (languageCode == null || languageCode.isEmpty) return null;
  final wanted = languageCode.toLowerCase();

  int rank(MediaSubtitle subtitle) {
    final code = subtitle.code.toLowerCase();
    final exact = code == wanted;
    final regional = !exact && code.split(RegExp('[-_]')).first == wanted;
    if (!exact && !regional) return -1;
    // 0 is the best match: exact language, human-authored.
    return (exact ? 0 : 2) + (subtitle.isAutoGenerated ? 1 : 0);
  }

  MediaSubtitle? best;
  var bestRank = -1;
  for (final subtitle in subtitles) {
    final candidate = rank(subtitle);
    if (candidate < 0) continue;
    if (best == null || candidate < bestRank) {
      best = subtitle;
      bestRank = candidate;
    }
  }
  return best;
}
