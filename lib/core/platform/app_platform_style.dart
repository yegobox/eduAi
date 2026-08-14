import 'package:flutter/foundation.dart';
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
