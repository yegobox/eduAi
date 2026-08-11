import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/schools/application/schools_providers.dart';
import 'package:eduai/features/schools/domain/entities/school.dart';
import 'package:eduai/features/schools/domain/entities/school_class.dart';
import 'package:eduai/features/schools/presentation/screens/school_detail_screen.dart';
import 'package:eduai/features/schools/presentation/screens/schools_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const schools = [
    School(id: 's1', name: 'Kigali Modern Academy', description: 'Demo'),
  ];
  const classes = [
    SchoolClass(id: 'c1', schoolId: 's1', name: 'P5 — Maths', grade: 'P5'),
  ];

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router =
        GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => screen)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolsListProvider.overrideWith((ref) async => schools),
          myMembershipsProvider.overrideWith((ref) async => const []),
          classesProvider.overrideWith((ref, arg) async => classes),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('SchoolsListScreen lays out', (tester) async {
    await pump(tester, const SchoolsListScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Kigali Modern Academy'), findsOneWidget);
  });

  testWidgets('SchoolDetailScreen lays out', (tester) async {
    await pump(
      tester,
      SchoolDetailScreen(schoolId: 's1', school: schools[0]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('P5 — Maths'), findsOneWidget);
  });
}
