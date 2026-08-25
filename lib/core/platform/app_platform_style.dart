import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which native design language the chrome and tokens follow.
///
/// This is *not* a user-facing setting. It defaults from the real OS; tests
/// and the debug device previewer override the provider to inspect a layout
/// they aren't running on.
enum AppPlatformStyle {
  ios,
  android,
  macos,
  windows;

  bool get isMobile => this == ios || this == android;
  bool get isDesktop => !isMobile;
  bool get isApple => this == ios || this == macos;

  /// Cards on desktop are flat with a hairline border; on mobile they carry a
  /// soft shadow. Matches the handoff's elevation rule.
  bool get usesFlatCards => isDesktop;

  static AppPlatformStyle fromTarget(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS => AppPlatformStyle.ios,
      TargetPlatform.macOS => AppPlatformStyle.macos,
      TargetPlatform.windows => AppPlatformStyle.windows,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux => AppPlatformStyle.android,
    };
  }
}

/// The platform style the whole app renders in. Overridden in tests to pump a
/// screen under every chrome without touching `debugDefaultTargetPlatform`.
final appPlatformStyleProvider = Provider<AppPlatformStyle>((ref) {
  return AppPlatformStyle.fromTarget(defaultTargetPlatform);
});

/// Window width below which the navigation chrome collapses to its mobile
/// shape — a bottom tab bar and bottom-sheet menus — whatever design language
/// is active.
///
/// A desktop toolbar cannot hold a title, a tab strip and the status actions in
/// a phone-width window, and a resized macOS window (or a phone frame in the
/// device previewer) is exactly that. Tabs belong at the bottom there.
const double kCompactChromeWidth = 700;

/// Whether the chrome around [context] should use the compact (bottom tab bar)
/// shape. Reads the *simulated* size under the device previewer, which is what
/// makes a phone frame on a Mac look like a phone.
bool isCompactChrome(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactChromeWidth;
