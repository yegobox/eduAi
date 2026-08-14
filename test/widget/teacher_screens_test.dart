import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/schools/application/schools_action_controller.dart';
import 'package:eduai/features/teacher/domain/entities/teacher_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _teacherSession = AuthSession(
  user: AppUser(id: 't1', displayName: 'Mrs Uwase', role: AppRole.teacher),
  provider: AuthProvider.supabaseEmail,
);

const _covered = AccessState(
  status: AccessStatus.entitled,
  source: AccessSource.schoolLicense,
  role: AppRole.teacher,
  schoolId: 's1',
  schoolName: 'Kigali Modern Academy',
  tierId: 'growth',
  licenseStatus: LicenseStatus.active,
);

final _classes = [
  const TeacherClass(
    id: 'c1',
    schoolId: 's1',
    name: 'Primary 6 — English',
    grade: 'P6',
    joinCode: 'ENGSIX',
    studentCount: 3,
  ),
  const TeacherClass(
    id: 'c2',
    schoolId: 's1',
    name: 'Primary 5 — Maths',
    studentCount: 1,
  ),
];

/// One of each state the Progress tab sorts on.
final _progress = {
  'c1': [
    // 1 of 5 right → struggling.
    StudentProgress(
      studentId: 'st1',
      studentName: 'Alice K.',
      questions: 8,
      checks: 5,
      correct: 1,
      parentsLinked: 1,
      lastActive: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    // Nothing at all → not started, which is a different problem.
    const StudentProgress(
      studentId: 'st2',
      studentName: 'Jean P.',
      questions: 0,
      checks: 0,
      correct: 0,
      parentsLinked: 0,
    ),
    // 4 of 5 right → fine.
    StudentProgress(
      studentId: 'st3',
      studentName: 'Chantal M.',
      questions: 4,
      checks: 5,
      correct: 4,
      parentsLinked: 0,
      lastActive: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ],
  'c2': const <StudentProgress>[],
};

Future<AppUnderTest> pumpTeacher(
  WidgetTester tester, {
  List<TeacherClass>? classes,
  AccessState? access,
  AppPlatformStyle platform = AppPlatformStyle.android,
  Size size = desktopSize,
}) {
  return pumpApp(
    tester,
    auth: FakeAuthRepository(initialSession: _teacherSession),
    access: FakeAccessRepository(state: access ?? _covered),
    teacher: FakeTeacherRepository(
      classes: classes ?? _classes,
      progress: _progress,
    ),
    platform: platform,
    size: size,
  );
}

void main() {
  group('Teacher shell', () {
    testWidgets('a teacher lands on their classes', (tester) async {
      await pumpTeacher(tester);

      // Two tabs, not the student's five or the admin's four.
      for (final label in ['Classes', 'Progress']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('License'), findsNothing);
      expect(find.text('Tutor'), findsNothing);
    });

    testWidgets('classes show their join codes and student counts', (
      tester,
    ) async {
      await pumpTeacher(tester);

      expect(find.text('Primary 6 — English'), findsOneWidget);
      expect(find.text('3 students · P6'), findsOneWidget);
      expect(find.byKey(const Key('teacher-class-code-c1')), findsOneWidget);
      expect(find.text('ENGSIX'), findsOneWidget);
      // Singular reads properly.
      expect(find.text('1 student'), findsOneWidget);
    });

    testWidgets('a class with no code is flagged, not left blank', (
      tester,
    ) async {
      await pumpTeacher(tester);
      // c2 has no join code, so nobody can join it.
      expect(find.text('NO CODE'), findsOneWidget);
    });

    testWidgets('no classes yet explains how one gets filled', (tester) async {
      await pumpTeacher(tester, classes: const []);

      expect(find.text('No classes yet'), findsOneWidget);
      expect(find.byKey(const Key('teacher-add-class')), findsOneWidget);
    });

    testWidgets('a teacher who has not redeemed a code is told to', (
      tester,
    ) async {
      await pumpTeacher(
        tester,
        access: const AccessState(
          status: AccessStatus.needsSetup,
          source: AccessSource.none,
          role: AppRole.teacher,
        ),
      );

      expect(find.byKey(const Key('access-notice')), findsOneWidget);
      expect(
        find.textContaining('Enter the teacher code your school gave you'),
        findsOneWidget,
      );
    });

    for (final platform in AppPlatformStyle.values) {
      testWidgets('renders on ${platform.name}', (tester) async {
        await pumpTeacher(tester, platform: platform);
        expect(tester.takeException(), isNull);
        expect(find.text('My classes'), findsOneWidget);
      });
    }
  });

  group('Teacher progress', () {
    Future<void> openProgress(WidgetTester tester) async {
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
    }

    testWidgets('separates struggling from never-started', (tester) async {
      await pumpTeacher(tester);
      await openProgress(tester);

      // Absent and struggling need different responses, so they are never one
      // "needs attention" bucket.
      expect(find.text('Getting things wrong'), findsOneWidget);
      expect(find.text('Not started yet'), findsOneWidget);
      expect(find.text('Doing fine'), findsOneWidget);
      expect(find.textContaining('absent, not struggling'), findsOneWidget);
    });

    testWidgets('counts each group', (tester) async {
      await pumpTeacher(tester);
      await openProgress(tester);

      expect(find.text('need a hand'), findsOneWidget);
      expect(find.text('not started'), findsOneWidget);
      expect(find.text('doing fine'), findsOneWidget);
      // One of each, from the seeded rosters.
      expect(find.text('1'), findsNWidgets(3));
    });

    testWidgets('shows an accuracy, and a dash when there is nothing to score', (
      tester,
    ) async {
      await pumpTeacher(tester);
      await openProgress(tester);

      // Alice: 1 of 5. Chantal: 4 of 5.
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      // Jean answered no checks — "0%" would be a different claim entirely.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('says so plainly when there is no activity anywhere', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _teacherSession),
        access: FakeAccessRepository(state: _covered),
        teacher: FakeTeacherRepository(classes: _classes),
      );
      await openProgress(tester);

      expect(find.text('Nothing to show yet'), findsOneWidget);
    });
  });

  group('Teacher class page', () {
    testWidgets('opens a roster with the join code and parent state', (
      tester,
    ) async {
      await pumpTeacher(tester);

      await tester.tap(find.text('Primary 6 — English'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('class-detail-join-code')), findsOneWidget);
      expect(find.text('3 ENROLLED'), findsOneWidget);
      expect(find.text('Alice K.'), findsOneWidget);
      // Alice already has a parent; Jean does not.
      expect(find.text('PARENT LINKED'), findsOneWidget);
      expect(
        find.byKey(const Key('teacher-invite-parent-st2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacher-invite-parent-st1')),
        findsNothing,
      );
    });

    testWidgets('a teacher can invite their student’s parent', (tester) async {
      final app = await pumpTeacher(tester);

      await tester.tap(find.text('Primary 6 — English'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teacher-invite-parent-st2')));
      await tester.pumpAndSettle();

      expect(app.linking.lastInvitedStudentId, 'st2');
      expect(
        find.byKey(const Key('teacher-parent-invite-code')),
        findsOneWidget,
      );
      expect(find.textContaining('sign up as a parent'), findsOneWidget);
    });

    testWidgets('a class with no code says nobody can enrol', (tester) async {
      await pumpTeacher(tester);

      await tester.tap(find.text('Primary 5 — Maths'));
      await tester.pumpAndSettle();

      expect(find.text('This class has no join code'), findsOneWidget);
      expect(find.text('Nobody has joined yet'), findsOneWidget);
    });
  });

  group('A teacher is not a customer, and not a student', () {
    testWidgets('the sign-up form never offers the teacher role', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Granted by redeeming a school's code only — a self-declared teacher is
      // a stranger asking to read children's progress.
      expect(find.byKey(const Key('signup-role-student')), findsOneWidget);
      expect(find.byKey(const Key('signup-role-parent')), findsOneWidget);
      expect(find.byKey(const Key('signup-role-school_admin')), findsOneWidget);
      expect(find.byKey(const Key('signup-role-teacher')), findsNothing);
    });

    testWidgets('a teacher cannot enrol as a student', (tester) async {
      final app = await pumpTeacher(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      final result = await container
          .read(schoolsActionControllerProvider.notifier)
          .joinSchool('s2');

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.message,
        contains('added by their school'),
      );
      expect(app.schools.joinCalls, 0);
    });
  });
}
