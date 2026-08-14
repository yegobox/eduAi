import 'package:eduai/core/format/formatters.dart';
import 'package:eduai/core/router/app_routes.dart';
import 'package:eduai/core/state/app_language.dart';
import 'package:eduai/core/storage/key_value_cache.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/progress/application/mastery_providers.dart';
import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/progress/domain/entities/mastery_view.dart';
import 'package:eduai/features/progress/domain/entities/progress_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 8, 13);

  LearningEvent question(String subject, {int daysAgo = 0, String id = 'e'}) =>
      LearningEvent(
        id: '$id-$subject-$daysAgo-q',
        kind: LearningEventKind.question,
        subject: subject,
        createdAt: today.subtract(Duration(days: daysAgo)),
      );

  LearningEvent check(
    String subject, {
    required bool correct,
    int daysAgo = 0,
    String id = 'e',
  }) => LearningEvent(
    id: '$id-$subject-$daysAgo-c-$correct',
    kind: LearningEventKind.check,
    subject: subject,
    isCorrect: correct,
    createdAt: today.subtract(Duration(days: daysAgo)),
  );

  group('MasteryView', () {
    test('is empty when nothing has been recorded', () {
      final view = MasteryView.from(ProgressSummary.empty, today: today);
      expect(view.hasSubjects, isFalse);
      expect(view.subjects, isEmpty);
      expect(view.examReadiness, 0);
      expect(view.week, hasLength(7));
      expect(view.week.every((d) => !d.active), isTrue);
    });

    test('discounts mastery until a subject has been practised enough', () {
      // Two events, both correct: full accuracy but thin exposure.
      final thin = MasteryView.from(
        ProgressSummary.fromEvents([
          check('Mathematics', correct: true),
          check('Mathematics', correct: true, id: 'x'),
        ], today: today),
        today: today,
      );

      // Eight events, all correct: full exposure, so mastery == accuracy.
      final thick = MasteryView.from(
        ProgressSummary.fromEvents([
          for (var i = 0; i < kFullExposureEvents; i++)
            check('Mathematics', correct: true, id: 'i$i'),
        ], today: today),
        today: today,
      );

      expect(thin.subjects.single.mastery, lessThan(1.0));
      expect(thick.subjects.single.mastery, 1.0);
      expect(
        thin.subjects.single.mastery,
        lessThan(thick.subjects.single.mastery),
      );
    });

    test('asking questions never drops a ring below neutral', () {
      // Questions only — no check answered, so accuracy is unknown.
      final view = MasteryView.from(
        ProgressSummary.fromEvents([
          for (var i = 0; i < 8; i++) question('English', id: 'q$i'),
        ], today: today),
        today: today,
      );
      final english = view.subjects.single;
      expect(english.accuracy, isNull);
      // Neutral 0.5 at full exposure, not zero.
      expect(english.mastery, closeTo(0.5, 1e-9));
      expect(english.masteryPercent, 50);
    });

    test('orders subjects by how much they have been practised', () {
      final view = MasteryView.from(
        ProgressSummary.fromEvents([
          question('Science', id: 'a'),
          question('Mathematics', id: 'b'),
          question('Mathematics', id: 'c'),
          question('Mathematics', id: 'd'),
        ], today: today),
        today: today,
      );
      expect(view.subjects.first.name, 'Mathematics');
      expect(view.subjects.first.events, 3);
    });

    test('builds a Monday-first week ending today, marking active days', () {
      final view = MasteryView.from(
        ProgressSummary.fromEvents([
          question('Mathematics', id: 'a'),
          question('Mathematics', daysAgo: 2, id: 'b'),
        ], today: today),
        today: today,
      );

      expect(view.week, hasLength(7));
      expect(view.week.last.date, DateTime(2026, 8, 13));
      expect(view.week.first.date, DateTime(2026, 8, 7));
      expect(view.week.last.active, isTrue);
      expect(view.week[4].active, isTrue); // two days ago
      expect(view.week[5].active, isFalse);
      // 13 Aug 2026 is a Thursday.
      expect(view.week.last.label, 'T');
    });

    test('exam readiness blends mastery with curriculum coverage', () {
      final summary = ProgressSummary.fromEvents([
        for (var i = 0; i < kFullExposureEvents; i++)
          check('Mathematics', correct: true, id: 'i$i'),
      ], today: today);

      final noLessons = MasteryView.from(summary, today: today);
      final halfLessons = MasteryView.from(
        summary,
        completedLessons: 4,
        totalLessons: 8,
        today: today,
      );
      final allLessons = MasteryView.from(
        summary,
        completedLessons: 8,
        totalLessons: 8,
        today: today,
      );

      // 0.7 * 1.0 mastery, plus 0.3 * lesson ratio.
      expect(noLessons.examReadiness, closeTo(0.7, 1e-9));
      expect(halfLessons.examReadiness, closeTo(0.85, 1e-9));
      expect(allLessons.examReadiness, closeTo(1.0, 1e-9));
      expect(allLessons.examReadinessPercent, 100);
    });

    test('never divides by a zero lesson count', () {
      final view = MasteryView.from(
        ProgressSummary.empty,
        completedLessons: 3,
        totalLessons: 0,
        today: today,
      );
      expect(view.examReadiness, 0);
    });

    test('carries the current streak through', () {
      final view = MasteryView.from(
        ProgressSummary.fromEvents([
          question('Mathematics', id: 'a'),
          question('Mathematics', daysAgo: 1, id: 'b'),
        ], today: today),
        today: today,
      );
      expect(view.currentStreak, 2);
    });
  });

  group('Formatters', () {
    test('short dates read the way an invoice does', () {
      expect(Formatters.shortDate(DateTime(2026, 9, 1)), '1 Sep 2026');
      expect(Formatters.shortDate(DateTime(2026, 12, 25)), '25 Dec 2026');
    });

    test('relative times step from minutes to a date', () {
      final now = DateTime(2026, 8, 13, 12);
      expect(Formatters.relative(now, now: now), 'Just now');
      expect(
        Formatters.relative(
          now.subtract(const Duration(minutes: 20)),
          now: now,
        ),
        '20m ago',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(hours: 5)), now: now),
        '5h ago',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(days: 3)), now: now),
        '3 days ago',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(days: 30)), now: now),
        '14 Jul 2026',
      );
      // A clock-skewed future timestamp must not print "-5m ago".
      expect(
        Formatters.relative(now.add(const Duration(hours: 2)), now: now),
        'Just now',
      );
    });

    test('groups thousands and formats currency and percentages', () {
      expect(Formatters.thousands(0), '0');
      expect(Formatters.thousands(999), '999');
      expect(Formatters.thousands(1000), '1,000');
      expect(Formatters.thousands(960000), '960,000');
      expect(Formatters.thousands(-1500), '-1,500');
      expect(Formatters.rwf(1500), '1,500 RWF');
      expect(Formatters.percent(0.784), '78%');
      expect(Formatters.percent(1), '100%');
    });
  });

  group('AppRole and routes', () {
    test('parses wire values, defaulting unknown ones to student', () {
      expect(AppRole.fromWire('parent'), AppRole.parent);
      expect(AppRole.fromWire('school_admin'), AppRole.schoolAdmin);
      expect(AppRole.fromWire('admin'), AppRole.schoolAdmin);
      expect(AppRole.fromWire('SchoolAdmin'), AppRole.schoolAdmin);
      // An unrecognised role must never lock a learner out.
      expect(AppRole.fromWire('wizard'), AppRole.student);
      expect(AppRole.fromWire(null), AppRole.student);
    });

    test('round-trips through AppUser JSON', () {
      const user = AppUser(id: 'u1', role: AppRole.parent);
      expect(AppUser.fromJson(user.toJson()).role, AppRole.parent);
      // A legacy record with no role field still loads.
      expect(AppUser.fromJson(const {'id': 'u1'}).role, AppRole.student);
      expect(
        user.copyWith(role: AppRole.schoolAdmin).role,
        AppRole.schoolAdmin,
      );
    });

    test('sends each role to its own home', () {
      expect(AppRoutes.homeFor(AppRole.student), AppRoutes.home);
      expect(AppRoutes.homeFor(AppRole.parent), AppRoutes.parentOverview);
      expect(AppRoutes.homeFor(AppRole.schoolAdmin), AppRoutes.adminLicense);
    });

    test('detects a deep link into another role\'s shell', () {
      expect(
        AppRoutes.isForeignShell(AppRoutes.parentPlan, AppRole.student),
        isTrue,
      );
      expect(
        AppRoutes.isForeignShell(AppRoutes.tutor, AppRole.student),
        isFalse,
      );
      expect(
        AppRoutes.isForeignShell(AppRoutes.adminSeats, AppRole.parent),
        isTrue,
      );
      // Detail pages belong to no shell and must not be bounced.
      expect(
        AppRoutes.isForeignShell(AppRoutes.schools, AppRole.parent),
        isFalse,
      );
      expect(
        AppRoutes.isForeignShell(AppRoutes.lessonReader('l1'), AppRole.parent),
        isFalse,
      );
    });
  });

  group('AppLanguage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('parses codes and falls back to English', () {
      expect(AppLanguage.fromCode('rw'), AppLanguage.kinyarwanda);
      expect(AppLanguage.fromCode('fr'), AppLanguage.french);
      expect(AppLanguage.fromCode('zz'), AppLanguage.english);
      expect(AppLanguage.fromCode(null), AppLanguage.english);
    });

    test('persists the chosen language across launches', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(appLanguageProvider.future),
        AppLanguage.english,
      );
      await container
          .read(appLanguageProvider.notifier)
          .select(AppLanguage.kinyarwanda);
      expect(
        container.read(appLanguageProvider).valueOrNull,
        AppLanguage.kinyarwanda,
      );

      // A fresh container reads what the last one wrote.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(
        await next.read(appLanguageProvider.future),
        AppLanguage.kinyarwanda,
      );
    });
  });

  group('ProgressSharingController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to sharing on, and persists a change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(progressSharingProvider.future), isTrue);

      await container.read(progressSharingProvider.notifier).setShared(false);
      expect(container.read(progressSharingProvider).valueOrNull, isFalse);

      // The Parent Reports screen reads the same flag from a new scope.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(await next.read(progressSharingProvider.future), isFalse);
      expect(
        await KeyValueCache().getJson('progress_share_with_parent'),
        isFalse,
      );
    });
  });
}
