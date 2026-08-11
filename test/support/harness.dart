import 'package:eduai/app/app.dart';
import 'package:eduai/core/network/connectivity_service.dart';
import 'package:eduai/features/auth/application/auth_providers.dart';
import 'package:eduai/features/schools/application/schools_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Handle to the fakes backing a pumped app, so tests can seed/inspect state.
class AppUnderTest {
  AppUnderTest(this.auth, this.schools);
  final FakeAuthRepository auth;
  final FakeSchoolsRepository schools;
}

/// Boots the REAL [EduAiApp] (real router, theme, screens, controllers) with
/// only the data layer faked and the network status forced. Deterministic and
/// free of platform channels, so it runs headless or on a device.
Future<AppUnderTest> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeSchoolsRepository? schools,
  NetworkStatus network = NetworkStatus.online,
  Size size = const Size(1400, 1000),
}) async {
  final fakeAuth = auth ?? FakeAuthRepository();
  final fakeSchools = schools ?? FakeSchoolsRepository();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        schoolsRepositoryProvider.overrideWithValue(fakeSchools),
        networkStatusProvider.overrideWith((ref) => Stream.value(network)),
      ],
      child: const EduAiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return AppUnderTest(fakeAuth, fakeSchools);
}

/// Common desktop / mobile viewport sizes for cross-layout checks.
const desktopSize = Size(1400, 1000);
const mobileSize = Size(420, 900);
