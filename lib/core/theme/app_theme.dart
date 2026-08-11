import 'package:flutter/material.dart';

/// Central Material 3 theme. Seeded from a single brand colour so light/dark
/// stay in sync; tweak [_seed] to rebrand.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF3D5AFE); // indigo/education blue

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Min HEIGHT of 52 with a sane min width. Do NOT use
          // Size.fromHeight (== Size(infinity, 52)); an infinite min width
          // blows up when the button is a non-stretched child of a Row or a
          // ListTile trailing slot (unbounded width). Full-width form buttons
          // get their width from a stretch Column instead.
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
