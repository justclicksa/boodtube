// ============================================================
// AppTheme — YouTube's design tokens
// ============================================================
// Colours, type scale and component shapes are taken from the
// official YouTube mobile app so screens read as the same product.
// Everything here is a token; screens should not hardcode colours.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's spacing scale.
///
/// Padding and gaps come from here rather than from an inline number, so
/// the same rhythm holds across screens and one change moves all of it.
class AppSpacing {
  const AppSpacing._();

  /// 4 — hairline gaps inside a text block.
  static const double xs = 4;

  /// 8 — between related widgets in a row.
  static const double sm = 8;

  /// 12 — list row insets, avatar to text.
  static const double md = 12;

  /// 16 — the default screen and card inset.
  static const double lg = 16;

  /// 24 — between sections.
  static const double xl = 24;

  /// 32 — around a centred empty or error state.
  static const double xxl = 32;

  /// Smallest tap target that passes the accessibility guidance on both
  /// stores. Anything interactive should be at least this on both axes.
  static const double minTapTarget = 48;
}

class YouTubeColors {
  const YouTubeColors._();

  /// Brand red — play button, progress bar, active states.
  static const red = Color(0xFFFF0000);

  // Dark surfaces
  static const darkBackground = Color(0xFF0F0F0F);
  static const darkElevated = Color(0xFF212121);
  static const darkChip = Color(0xFF272727);
  static const darkChipSelected = Color(0xFFF1F1F1);
  static const darkSecondaryText = Color(0xFFAAAAAA);
  static const darkDivider = Color(0xFF303030);

  // Light surfaces
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFF9F9F9);
  static const lightChip = Color(0xFFF2F2F2);
  static const lightChipSelected = Color(0xFF0F0F0F);
  static const lightSecondaryText = Color(0xFF606060);
  static const lightDivider = Color(0xFFE5E5E5);
}

/// Extra tokens the Material scheme has no slot for.
@immutable
class YouTubeTokens extends ThemeExtension<YouTubeTokens> {
  const YouTubeTokens({
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.chipSelectedForeground,
    required this.secondaryText,
    required this.actionPillBackground,
  });

  final Color chipBackground;
  final Color chipSelectedBackground;
  final Color chipSelectedForeground;
  final Color secondaryText;

  /// Background of the Like / Share / Download pills under a video.
  final Color actionPillBackground;

  static const dark = YouTubeTokens(
    chipBackground: YouTubeColors.darkChip,
    chipSelectedBackground: YouTubeColors.darkChipSelected,
    chipSelectedForeground: YouTubeColors.darkBackground,
    secondaryText: YouTubeColors.darkSecondaryText,
    actionPillBackground: YouTubeColors.darkChip,
  );

  static const light = YouTubeTokens(
    chipBackground: YouTubeColors.lightChip,
    chipSelectedBackground: YouTubeColors.lightChipSelected,
    chipSelectedForeground: YouTubeColors.lightBackground,
    secondaryText: YouTubeColors.lightSecondaryText,
    actionPillBackground: YouTubeColors.lightChip,
  );

  @override
  YouTubeTokens copyWith({
    Color? chipBackground,
    Color? chipSelectedBackground,
    Color? chipSelectedForeground,
    Color? secondaryText,
    Color? actionPillBackground,
  }) {
    return YouTubeTokens(
      chipBackground: chipBackground ?? this.chipBackground,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      chipSelectedForeground:
          chipSelectedForeground ?? this.chipSelectedForeground,
      secondaryText: secondaryText ?? this.secondaryText,
      actionPillBackground: actionPillBackground ?? this.actionPillBackground,
    );
  }

  @override
  YouTubeTokens lerp(YouTubeTokens? other, double t) {
    if (other == null) return this;
    return YouTubeTokens(
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipSelectedBackground:
          Color.lerp(chipSelectedBackground, other.chipSelectedBackground, t)!,
      chipSelectedForeground:
          Color.lerp(chipSelectedForeground, other.chipSelectedForeground, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      actionPillBackground:
          Color.lerp(actionPillBackground, other.actionPillBackground, t)!,
    );
  }
}

extension YouTubeThemeX on ThemeData {
  YouTubeTokens get yt => extension<YouTubeTokens>() ?? YouTubeTokens.dark;
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: YouTubeColors.darkBackground,
        elevated: YouTubeColors.darkElevated,
        onBackground: Colors.white,
        secondaryText: YouTubeColors.darkSecondaryText,
        divider: YouTubeColors.darkDivider,
        tokens: YouTubeTokens.dark,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: YouTubeColors.lightBackground,
        elevated: YouTubeColors.lightElevated,
        onBackground: YouTubeColors.darkBackground,
        secondaryText: YouTubeColors.lightSecondaryText,
        divider: YouTubeColors.lightDivider,
        tokens: YouTubeTokens.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color elevated,
    required Color onBackground,
    required Color secondaryText,
    required Color divider,
    required YouTubeTokens tokens,
  }) {
    // YouTube ships Roboto on every platform.
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.robotoTextTheme(base.textTheme).apply(
      bodyColor: onBackground,
      displayColor: onBackground,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      extensions: [tokens],
      colorScheme: base.colorScheme.copyWith(
        primary: YouTubeColors.red,
        onPrimary: Colors.white,
        surface: background,
        onSurface: onBackground,
        surfaceContainerHighest: elevated,
        outlineVariant: divider,
      ),
      textTheme: textTheme.copyWith(
        // Feed card title: 14sp medium, two lines.
        titleSmall: textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        // Metadata line: 12sp, secondary colour.
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: secondaryText,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      hintColor: secondaryText,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 56,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontSize: 10, color: onBackground),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: onBackground,
            fill: states.contains(WidgetState.selected) ? 1 : 0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.chipBackground,
        selectedColor: tokens.chipSelectedBackground,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onBackground,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tokens.chipSelectedForeground,
        ),
        showCheckmark: false,
      ),
      // Subscribe button: solid pill, inverted against the background.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: onBackground,
          foregroundColor: background,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minimumSize: const Size(0, 36),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brightness == Brightness.dark
            ? YouTubeColors.darkElevated
            : YouTubeColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onBackground,
        textColor: onBackground,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: YouTubeColors.red,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: YouTubeColors.red,
        thumbColor: YouTubeColors.red,
        inactiveTrackColor: secondaryText.withValues(alpha: 0.3),
        trackHeight: 3,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onBackground,
        unselectedLabelColor: secondaryText,
        indicatorColor: onBackground,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: divider,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? YouTubeColors.darkChipSelected
            : YouTubeColors.darkElevated,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? YouTubeColors.darkBackground
              : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
