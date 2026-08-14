import 'package:flutter/material.dart';

import '../platform/app_platform_style.dart';
import 'app_tokens.dart';

/// Builds the app's [ThemeData] from the redesign's [AppTokens].
///
/// One shared widget tree renders on every platform; only the tokens (radius,
/// type scale, control shape) and the navigation chrome differ. Font family is
/// deliberately left unset so Flutter picks the platform's system face
/// (SF Pro / Roboto / Segoe UI Variable).
class AppTheme {
  const AppTheme._();

  static ThemeData light(AppPlatformStyle platform) =>
      _base(Brightness.light, platform);

  static ThemeData dark(AppPlatformStyle platform) =>
      _base(Brightness.dark, platform);

  static ThemeData _base(Brightness brightness, AppPlatformStyle platform) {
    final t = AppTokens.of(brightness, platform);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.brand,
      onPrimary: t.onBrand,
      primaryContainer: t.brandSoft,
      onPrimaryContainer: t.brand,
      secondary: t.brand,
      onSecondary: t.onBrand,
      secondaryContainer: t.brandSoft,
      onSecondaryContainer: t.brand,
      tertiary: t.success,
      onTertiary: t.onBrand,
      tertiaryContainer: t.successSoft,
      onTertiaryContainer: t.success,
      error: t.danger,
      onError: t.onBrand,
      errorContainer: t.dangerSoft,
      onErrorContainer: t.danger,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerHigh: t.surfaceSunken,
      surfaceContainerHighest: t.surfaceSunken,
      outline: t.border,
      outlineVariant: t.border,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.surfaceAlt,
      extensions: [t],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, t),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: platform == AppPlatformStyle.ios,
        titleTextStyle: TextStyle(
          color: t.ink,
          fontSize: platform.isDesktop ? t.h2 : 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: t.ink2),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceSunken,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: t.ink2,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceSunken,
        hintStyle: TextStyle(color: t.ink3),
        border: OutlineInputBorder(
          borderRadius: t.controlBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: t.controlBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: t.controlBorderRadius,
          borderSide: BorderSide(color: t.brand),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: platform.isDesktop ? 10 : 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: t.onBrand,
          // Min HEIGHT with a sane min width. Do NOT use Size.fromHeight
          // (== Size(infinity, h)); an infinite min width blows up when the
          // button sits in a Row or a ListTile trailing slot.
          minimumSize: Size(64, platform.isDesktop ? 34 : 46),
          shape: RoundedRectangleBorder(borderRadius: t.controlBorderRadius),
          textStyle: TextStyle(
            fontSize: platform.isDesktop ? 13 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          side: BorderSide(color: t.border),
          minimumSize: Size(64, platform.isDesktop ? 34 : 46),
          shape: RoundedRectangleBorder(borderRadius: t.controlBorderRadius),
          textStyle: TextStyle(
            fontSize: platform.isDesktop ? 13 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: t.cardBorderRadius,
          side: t.flatCards ? t.hairline : BorderSide.none,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.brand : t.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.brandSoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand,
        linearTrackColor: t.surfaceSunken,
        circularTrackColor: t.surfaceSunken,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(color: t.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppTokens t) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: t.h1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: t.ink,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: t.h1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: t.ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: t.h2,
        fontWeight: FontWeight.w700,
        color: t.ink,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: t.body + 1,
        fontWeight: FontWeight.w700,
        color: t.ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: t.body, color: t.ink),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: t.body - 1.5,
        color: t.ink2,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: t.body - 2.5,
        color: t.ink3,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: t.body - 1,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
    );
  }
}
