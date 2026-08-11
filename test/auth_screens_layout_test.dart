import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/auth/presentation/screens/login_screen.dart';
import 'package:eduai/features/auth/presentation/screens/offline_unlock_screen.dart';
import 'package:eduai/features/auth/presentation/screens/set_pin_screen.dart';
import 'package:eduai/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the "RenderFlex was not laid out" crash: the auth
/// forms live inside AuthScaffold's SingleChildScrollView (unbounded height),
/// so their Columns must be mainAxisSize.min. A build can't catch this — only
/// laying the widgets out can. We pump each screen at a desktop window size
/// and assert no layout exception is thrown.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    // Let the auth controller resolve its initial state.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('LoginScreen lays out with no exception', (tester) async {
    await pumpScreen(tester, const LoginScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('SignUpScreen lays out with no exception', (tester) async {
    await pumpScreen(tester, const SignUpScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('OfflineUnlockScreen lays out with no exception', (tester) async {
    await pumpScreen(tester, const OfflineUnlockScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('SetPinScreen lays out with no exception', (tester) async {
    await pumpScreen(tester, const SetPinScreen());
    expect(tester.takeException(), isNull);
  });
}
