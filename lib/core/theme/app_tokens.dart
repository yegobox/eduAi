import 'package:flutter/material.dart';

import '../platform/app_platform_style.dart';

/// Every colour, radius and type size from the redesign handoff, exposed as a
/// [ThemeExtension] so widgets read them through `Theme.of(context)` instead of
/// importing a palette file. Light/dark are hand-tuned (not seed-derived) —
/// the handoff pins exact hexes.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.onBrand,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.cardRadius,
    required this.controlRadius,
    required this.h1,
    required this.h2,
    required this.body,
    required this.flatCards,
  });

  // ---- colour ------------------------------------------------------------
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color onBrand;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  /// Primary / secondary / tertiary text.
  final Color ink;
  final Color ink2;
  final Color ink3;

  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;
  final Color border;

  // ---- shape & type ------------------------------------------------------
  final double cardRadius;
  final double controlRadius;
  final double h1;
  final double h2;
  final double body;

  /// Desktop cards are flat with a border; mobile cards carry a shadow.
  final bool flatCards;

  /// The mobile card shadow. Empty on desktop, where [flatCards] is true.
  List<BoxShadow> get cardShadow => flatCards
      ? const []
      : [
          BoxShadow(
            color: _shadowColor.withValues(alpha: _shadowNearAlpha),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: _shadowColor.withValues(alpha: _shadowFarAlpha),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ];

  Color get _shadowColor =>
      isDark ? const Color(0xFF000000) : const Color(0xFF14142D);
  double get _shadowNearAlpha => isDark ? 0.30 : 0.04;
  double get _shadowFarAlpha => isDark ? 0.35 : 0.07;

  /// Dark palettes put light ink on a dark surface; used for shadow strength
  /// and for picking overlay tints.
  bool get isDark => surface.computeLuminance() < 0.5;

  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get controlBorderRadius => BorderRadius.circular(controlRadius);

  /// Border side used instead of a shadow on desktop cards.
  BorderSide get hairline => BorderSide(color: border);

  // ---- construction ------------------------------------------------------

  /// Builds the token set for a brightness + platform pair.
  factory AppTokens.of(Brightness brightness, AppPlatformStyle platform) {
    final shape = _shapeFor(platform);
    return brightness == Brightness.dark
        ? AppTokens(
            brand: const Color(0xFF8992FF),
            brandStrong: const Color(0xFFA6ADFF),
            brandSoft: const Color(0xFF252A57),
            onBrand: const Color(0xFF12132B),
            success: const Color(0xFF3FCB90),
            successSoft: const Color(0xFF12301F),
            warning: const Color(0xFFE3A23A),
            warningSoft: const Color(0xFF3A2B10),
            danger: const Color(0xFFF17685),
            dangerSoft: const Color(0xFF3A1620),
            ink: const Color(0xFFF1F2F7),
            ink2: const Color(0xFFC4C6D6),
            ink3: const Color(0xFF82849A),
            surface: const Color(0xFF1D1E27),
            surfaceAlt: const Color(0xFF15161D),
            surfaceSunken: const Color(0xFF262733),
            border: const Color(0xFF33343F),
            cardRadius: shape.card,
            controlRadius: shape.control,
            h1: shape.h1,
            h2: shape.h2,
            body: shape.body,
            flatCards: platform.usesFlatCards,
          )
        : AppTokens(
            brand: const Color(0xFF4A54E8),
            brandStrong: const Color(0xFF333DC9),
            brandSoft: const Color(0xFFEDEFFE),
            onBrand: const Color(0xFFFFFFFF),
            success: const Color(0xFF1E9D6C),
            successSoft: const Color(0xFFE3F6EC),
            warning: const Color(0xFFB5720E),
            warningSoft: const Color(0xFFFBF0DC),
            danger: const Color(0xFFD6455A),
            dangerSoft: const Color(0xFFFCE9EB),
            ink: const Color(0xFF15161B),
            ink2: const Color(0xFF50525F),
            ink3: const Color(0xFF8A8CA0),
            surface: const Color(0xFFFFFFFF),
            surfaceAlt: const Color(0xFFF6F7FB),
            surfaceSunken: const Color(0xFFEDEFF6),
            border: const Color(0xFFE4E6EF),
            cardRadius: shape.card,
            controlRadius: shape.control,
            h1: shape.h1,
            h2: shape.h2,
            body: shape.body,
            flatCards: platform.usesFlatCards,
          );
  }

  static _Shape _shapeFor(AppPlatformStyle platform) => switch (platform) {
    AppPlatformStyle.ios => const _Shape(
      card: 20,
      control: 14,
      h1: 30,
      h2: 20,
      body: 16,
    ),
    // Android uses fully-rounded ("pill") controls per Material 3.
    AppPlatformStyle.android => const _Shape(
      card: 16,
      control: 100,
      h1: 26,
      h2: 19,
      body: 15,
    ),
    AppPlatformStyle.macos => const _Shape(
      card: 12,
      control: 8,
      h1: 22,
      h2: 16,
      body: 13.5,
    ),
    AppPlatformStyle.windows => const _Shape(
      card: 8,
      control: 5,
      h1: 20,
      h2: 15,
      body: 13.5,
    ),
  };

  /// Reads the tokens off the ambient theme. Falls back to light/iOS rather
  /// than throwing, so a widget pumped without [AppTheme] still renders.
  static AppTokens read(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppTokens>() ??
        AppTokens.of(theme.brightness, AppPlatformStyle.ios);
  }

  @override
  AppTokens copyWith({
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? onBrand,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? border,
    double? cardRadius,
    double? controlRadius,
    double? h1,
    double? h2,
    double? body,
    bool? flatCards,
  }) {
    return AppTokens(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      body: body ?? this.body,
      flatCards: flatCards ?? this.flatCards,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return AppTokens(
      brand: c(brand, other.brand),
      brandStrong: c(brandStrong, other.brandStrong),
      brandSoft: c(brandSoft, other.brandSoft),
      onBrand: c(onBrand, other.onBrand),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      cardRadius: d(cardRadius, other.cardRadius),
      controlRadius: d(controlRadius, other.controlRadius),
      h1: d(h1, other.h1),
      h2: d(h2, other.h2),
      body: d(body, other.body),
      flatCards: t < 0.5 ? flatCards : other.flatCards,
    );
  }
}

class _Shape {
  const _Shape({
    required this.card,
    required this.control,
    required this.h1,
    required this.h2,
    required this.body,
  });

  final double card;
  final double control;
  final double h1;
  final double h2;
  final double body;
}
