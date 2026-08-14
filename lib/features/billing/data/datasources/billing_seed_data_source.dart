import '../../domain/entities/billing_entities.dart';

/// Fallback content for the school-admin shell.
///
/// Two very different jobs, kept apart on purpose:
///
/// * [tiers] mirrors the server's `plan_tiers` rows so a build with no Supabase
///   (design review, widget tests) can still lay the plan cards out. The
///   authoritative copy is in the database — these numbers are a stand-in for
///   *rendering*, never for charging.
/// * [usage] is genuinely seeded: the learning-analytics rollup that would feed
///   the Usage tab does not exist server-side yet. It is the one screen in the
///   admin shell still showing invented numbers, and it is display-only — no
///   money decision reads it.
class BillingSeedDataSource {
  const BillingSeedDataSource();

  List<PlanTier> tiers() => const [
    PlanTier(
      id: 'starter',
      name: 'Starter',
      pricePerSeatRwf: 900,
      maxSeats: 150,
      seatsLabel: 'Up to 150 students',
      features: ['AI Tutor', 'Lessons library', 'Offline access'],
    ),
    PlanTier(
      id: 'growth',
      name: 'Growth',
      pricePerSeatRwf: 1500,
      maxSeats: 800,
      seatsLabel: 'Up to 800 students',
      features: ['Everything in Starter', 'Stylus workbook', 'Parent reports'],
    ),
    PlanTier(
      id: 'district',
      name: 'District',
      pricePerSeatRwf: 1250,
      seatsLabel: '800+ students',
      features: [
        'Everything in Growth',
        'Multi-school admin',
        'Dedicated support',
      ],
    ),
  ];

  UsageStats usage() => const UsageStats(
    activeStudentRatio: 0.87,
    sessionsPerStudentPerWeek: 4.2,
    masteryLiftRatio: 0.23,
    topSubject: 'Mathematics',
  );
}
