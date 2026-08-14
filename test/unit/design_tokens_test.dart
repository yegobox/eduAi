import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPlatformStyle', () {
    test('maps every TargetPlatform, defaulting the unix-likes to Android', () {
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.iOS),
        AppPlatformStyle.ios,
      );
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.macOS),
        AppPlatformStyle.macos,
      );
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.windows),
        AppPlatformStyle.windows,
      );
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.android),
        AppPlatformStyle.android,
      );
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.linux),
        AppPlatformStyle.android,
      );
      expect(
        AppPlatformStyle.fromTarget(TargetPlatform.fuchsia),
        AppPlatformStyle.android,
      );
    });

    test('classifies mobile vs desktop and card elevation', () {
      expect(AppPlatformStyle.ios.isMobile, isTrue);
      expect(AppPlatformStyle.android.isMobile, isTrue);
      expect(AppPlatformStyle.macos.isDesktop, isTrue);
      expect(AppPlatformStyle.windows.isDesktop, isTrue);

      // Desktop cards are flat with a hairline; mobile cards carry a shadow.
      expect(AppPlatformStyle.macos.usesFlatCards, isTrue);
      expect(AppPlatformStyle.ios.usesFlatCards, isFalse);

      expect(AppPlatformStyle.ios.isApple, isTrue);
      expect(AppPlatformStyle.macos.isApple, isTrue);
      expect(AppPlatformStyle.windows.isApple, isFalse);
    });
  });

  group('AppTokens', () {
    test('carries the handoff radii and type scale per platform', () {
      final ios = AppTokens.of(Brightness.light, AppPlatformStyle.ios);
      expect(ios.cardRadius, 20);
      expect(ios.controlRadius, 14);
      expect(ios.h1, 30);

      final android = AppTokens.of(Brightness.light, AppPlatformStyle.android);
      expect(android.cardRadius, 16);
      // Android buttons are pills.
      expect(android.controlRadius, 100);

      final macos = AppTokens.of(Brightness.light, AppPlatformStyle.macos);
      expect(macos.cardRadius, 12);
      expect(macos.body, 13.5);

      final windows = AppTokens.of(Brightness.light, AppPlatformStyle.windows);
      expect(windows.cardRadius, 8);
      expect(windows.h1, 20);
    });

    test('light and dark use the pinned brand hexes', () {
      final light = AppTokens.of(Brightness.light, AppPlatformStyle.ios);
      expect(light.brand, const Color(0xFF4A54E8));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.isDark, isFalse);

      final dark = AppTokens.of(Brightness.dark, AppPlatformStyle.ios);
      expect(dark.brand, const Color(0xFF8992FF));
      expect(dark.surface, const Color(0xFF1D1E27));
      expect(dark.isDark, isTrue);
    });

    test('mobile cards get a shadow, desktop cards get a border instead', () {
      final mobile = AppTokens.of(Brightness.light, AppPlatformStyle.ios);
      expect(mobile.cardShadow, hasLength(2));
      expect(mobile.flatCards, isFalse);

      final desktop = AppTokens.of(Brightness.light, AppPlatformStyle.windows);
      expect(desktop.cardShadow, isEmpty);
      expect(desktop.hairline.color, desktop.border);
    });

    test('copyWith replaces only what it is given', () {
      final base = AppTokens.of(Brightness.light, AppPlatformStyle.ios);
      final copy = base.copyWith(brand: const Color(0xFF000000), h1: 40);
      expect(copy.brand, const Color(0xFF000000));
      expect(copy.h1, 40);
      expect(copy.surface, base.surface);
      expect(copy.cardRadius, base.cardRadius);
    });

    test('lerp interpolates colours and sizes, and flips flags at halfway', () {
      final light = AppTokens.of(Brightness.light, AppPlatformStyle.ios);
      final dark = AppTokens.of(Brightness.dark, AppPlatformStyle.windows);

      final start = light.lerp(dark, 0);
      expect(start.cardRadius, light.cardRadius);
      expect(start.flatCards, light.flatCards);

      final end = light.lerp(dark, 1);
      expect(end.cardRadius, dark.cardRadius);
      expect(end.flatCards, dark.flatCards);

      final mid = light.lerp(dark, 0.5);
      expect(mid.cardRadius, (light.cardRadius + dark.cardRadius) / 2);

      // A non-AppTokens argument leaves the receiver untouched.
      expect(light.lerp(null, 0.5), same(light));
    });
  });

  group('AppTheme', () {
    testWidgets('publishes tokens on the theme and honours the platform', (
      tester,
    ) async {
      late AppTokens read;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppPlatformStyle.macos),
          home: Builder(
            builder: (context) {
              read = AppTokens.read(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(read.cardRadius, 12);
      expect(read.flatCards, isTrue);
    });

    testWidgets('AppTokens.read falls back when no extension is installed', (
      tester,
    ) async {
      late AppTokens read;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              read = AppTokens.read(context);
              return const SizedBox();
            },
          ),
        ),
      );
      // Falls back to the dark palette rather than throwing.
      expect(read.isDark, isTrue);
    });

    test('dark theme carries the dark tokens', () {
      final theme = AppTheme.dark(AppPlatformStyle.ios);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.isDark, isTrue);
      expect(theme.colorScheme.primary, tokens.brand);
      expect(theme.scaffoldBackgroundColor, tokens.surfaceAlt);
    });
  });
}
