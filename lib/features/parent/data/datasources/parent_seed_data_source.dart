import '../../domain/entities/parent_entities.dart';

/// Seed content for the parent shell.
///
/// The parent-facing tables do not exist in Supabase yet. This source stands
/// in for them behind [ParentRepository] so the screens, controllers and
/// tests are all real; swapping in a remote source later touches one file.
class ParentSeedDataSource {
  const ParentSeedDataSource();

  List<Child> children({DateTime? now}) {
    final at = now ?? DateTime.now();
    return [
      Child(
        id: 'k1',
        name: 'Alice K.',
        grade: 'P6',
        minutesThisWeek: 210,
        questionsAsked: 34,
        streakDays: 5,
        attention: const ['Science — fractions of measurement'],
        subjectMastery: const {
          'Mathematics': 0.78,
          'English': 0.64,
          'Science': 0.52,
        },
        recentActivity: [
          ActivityEntry(
            kind: ActivityKind.tutor,
            text: 'Asked the AI Tutor about fractions',
            at: at.subtract(const Duration(hours: 2)),
          ),
          ActivityEntry(
            kind: ActivityKind.lesson,
            text: 'Completed "The water cycle" lesson',
            at: at.subtract(const Duration(days: 1)),
          ),
          ActivityEntry(
            kind: ActivityKind.workbook,
            text: 'Solved 4 problems in the Workbook',
            at: at.subtract(const Duration(days: 1, hours: 4)),
          ),
          ActivityEntry(
            kind: ActivityKind.check,
            text: 'Passed a quick check in Mathematics',
            at: at.subtract(const Duration(days: 2)),
          ),
        ],
      ),
      Child(
        id: 'k2',
        name: 'Jean P.',
        grade: 'P4',
        minutesThisWeek: 96,
        questionsAsked: 12,
        streakDays: 2,
        attention: const ['English — spelling'],
        subjectMastery: const {
          'Mathematics': 0.55,
          'English': 0.41,
          'Science': 0.62,
        },
        recentActivity: [
          ActivityEntry(
            kind: ActivityKind.lesson,
            text: 'Started "Building compound sentences"',
            at: at.subtract(const Duration(hours: 20)),
          ),
          ActivityEntry(
            kind: ActivityKind.tutor,
            text: 'Asked the AI Tutor about spelling rules',
            at: at.subtract(const Duration(days: 3)),
          ),
        ],
      ),
    ];
  }

  List<ParentMessage> messages(String childId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return [
      ParentMessage(
        id: '$childId-m1',
        from: 'Mrs. Uwase (Class teacher)',
        text:
            "Alice did great on this week's fractions quiz — keep "
            'encouraging 15 minutes of practice a night.',
        at: at.subtract(const Duration(days: 2)),
        fromParent: false,
      ),
      ParentMessage(
        id: '$childId-m2',
        from: 'You',
        text: "Thank you! We'll keep it up. Is there weekend homework?",
        at: at.subtract(const Duration(days: 2, hours: -3)),
        fromParent: true,
      ),
      ParentMessage(
        id: '$childId-m3',
        from: 'Mrs. Uwase (Class teacher)',
        text: 'Yes — REB worksheet 4, shared in Lessons.',
        at: at.subtract(const Duration(days: 1)),
        fromParent: false,
      ),
    ];
  }

  ParentPlan plan() => ParentPlan(
    schoolName: 'Kigali Modern Academy',
    tier: 'Growth',
    seats: 640,
    renewsOn: DateTime(2026, 9, 1),
  );

  List<TopupPack> topups() => const [
    TopupPack(id: 'small', label: 'Small top-up', sessions: 20, priceRwf: 500),
    TopupPack(id: 'family', label: 'Family pack', sessions: 60, priceRwf: 1200),
    TopupPack(id: 'term', label: 'Term pack', sessions: 150, priceRwf: 2500),
  ];
}
