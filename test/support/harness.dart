import 'package:eduai/app/app.dart';
import 'package:eduai/core/config/app_config.dart';
import 'package:eduai/core/config/config_providers.dart';
import 'package:eduai/core/network/connectivity_service.dart';
import 'package:eduai/core/network/http_client_provider.dart';
import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/access/application/access_providers.dart';
import 'package:eduai/features/auth/application/auth_providers.dart';
import 'package:eduai/features/auth/application/role_providers.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/linking/application/linking_providers.dart';
import 'package:eduai/features/payments/application/momo_payment_controller.dart';
import 'package:eduai/features/schools/application/schools_providers.dart';
import 'package:eduai/features/tutor/application/tutor_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Handle to the fakes backing a pumped app, so tests can seed/inspect state.
class AppUnderTest {
  AppUnderTest(
    this.auth,
    this.schools,
    this.tutor,
    this.http,
    this.access,
    this.linking,
  );

  final FakeAuthRepository auth;
  final FakeSchoolsRepository schools;
  final FakeTutorRepository tutor;
  final RecordingHttpClient http;
  final FakeAccessRepository access;
  final FakeLinkingRepository linking;
}

/// Config with Mobile Money and the tutor backend wired to loopback hosts.
/// Nothing reaches the network — [RecordingHttpClient] answers every call.
const testConfig = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  enablePhoneAuth: true,
  flavor: 'test',
  dataConnectorUrl: 'http://localhost:8084',
  momoApiUrl: 'http://localhost:9000',
  momoStatusApiUrl: 'http://localhost:9001',
  momoBranchId: 'branch-test',
  momoBusinessId: 'biz-test',
);

/// Every provider override the app needs to run headless, with only the data
/// layer faked. Shared by [pumpApp] and by screen-level tests.
List<Override> testOverrides({
  required FakeAuthRepository auth,
  required FakeSchoolsRepository schools,
  required FakeTutorRepository tutor,
  required RecordingHttpClient httpClient,
  FakeAccessRepository? access,
  FakeLinkingRepository? linking,
  NetworkStatus network = NetworkStatus.online,
  AppPlatformStyle platform = AppPlatformStyle.android,
  AppRole? role,
  AppConfig config = testConfig,
}) {
  return [
    appConfigProvider.overrideWithValue(config),
    authRepositoryProvider.overrideWithValue(auth),
    schoolsRepositoryProvider.overrideWithValue(schools),
    tutorRepositoryProvider.overrideWithValue(tutor),
    httpClientProvider.overrideWithValue(httpClient),
    accessRepositoryProvider.overrideWithValue(
      access ?? FakeAccessRepository(),
    ),
    linkingRepositoryProvider.overrideWithValue(
      linking ?? FakeLinkingRepository(),
    ),
    networkStatusProvider.overrideWith((ref) => Stream.value(network)),
    appPlatformStyleProvider.overrideWithValue(platform),
    if (role != null) roleOverrideProvider.overrideWith((ref) => role),
    // Poll fast so payment tests finish in milliseconds instead of minutes.
    momoPollIntervalProvider.overrideWithValue(
      const Duration(milliseconds: 10),
    ),
    momoPollTimeoutProvider.overrideWithValue(const Duration(seconds: 1)),
  ];
}

/// Boots the REAL [EduAiApp] (real router, theme, shells, screens,
/// controllers) with only the data layer faked and the network status forced.
/// Deterministic and free of platform channels, so it runs headless.
Future<AppUnderTest> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeSchoolsRepository? schools,
  FakeTutorRepository? tutor,
  RecordingHttpClient? httpClient,
  FakeAccessRepository? access,
  FakeLinkingRepository? linking,
  NetworkStatus network = NetworkStatus.online,
  AppPlatformStyle platform = AppPlatformStyle.android,
  AppRole? role,
  AppConfig config = testConfig,
  Size size = desktopSize,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});

  final fakeAuth = auth ?? FakeAuthRepository();
  final fakeSchools = schools ?? FakeSchoolsRepository();
  final fakeTutor = tutor ?? FakeTutorRepository();
  final fakeHttp = httpClient ?? RecordingHttpClient();
  // Defaults to the unconfigured entitlement, which is what a build with no
  // Supabase really has — so screens are inspectable and nothing claims a plan
  // was paid for.
  final fakeAccess = access ?? FakeAccessRepository();
  final fakeLinking = linking ?? FakeLinkingRepository();

  setSurfaceSize(tester, size);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(
          auth: fakeAuth,
          schools: fakeSchools,
          tutor: fakeTutor,
          httpClient: fakeHttp,
          access: fakeAccess,
          linking: fakeLinking,
          network: network,
          platform: platform,
          role: role,
          config: config,
        ),
        ...extraOverrides,
      ],
      child: const EduAiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return AppUnderTest(
    fakeAuth,
    fakeSchools,
    fakeTutor,
    fakeHttp,
    fakeAccess,
    fakeLinking,
  );
}

/// Pumps one widget inside the real theme (and a Riverpod scope), for tests
/// that do not need the router or a session.
Future<void> pumpWidgetInApp(
  WidgetTester tester,
  Widget child, {
  AppPlatformStyle platform = AppPlatformStyle.android,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
  Size size = desktopSize,
}) async {
  SharedPreferences.setMockInitialValues({});
  setSurfaceSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPlatformStyleProvider.overrideWithValue(platform),
        ...overrides,
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark(platform)
            : AppTheme.light(platform),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

void setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A no-op HTTP client for suites that never exercise a network path.
http.Client get offlineHttpClient => RecordingHttpClient();

/// Common desktop / mobile viewport sizes for cross-layout checks.
const desktopSize = Size(1400, 1000);
const mobileSize = Size(420, 900);
