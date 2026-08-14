import 'package:equatable/equatable.dart';

/// A child linked to the signed-in parent account.
class Child extends Equatable {
  const Child({
    required this.id,
    required this.name,
    required this.grade,
    this.minutesThisWeek = 0,
    this.questionsAsked = 0,
    this.streakDays = 0,
    this.attention = const [],
    this.subjectMastery = const {},
    this.recentActivity = const [],
  });

  final String id;
  final String name;
  final String grade;

  final int minutesThisWeek;
  final int questionsAsked;
  final int streakDays;

  /// Topics that need encouragement. Phrased as subjects, never as failures.
  final List<String> attention;

  /// Subject → mastery 0..1, shown as trend bars in Reports.
  final Map<String, double> subjectMastery;

  final List<ActivityEntry> recentActivity;

  /// Initials for the child-switcher avatar. One name yields two letters
  /// ("Alice" → AL); two or more yield first + last ("Alice K." → AK).
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String take(String word, int n) =>
        word.substring(0, n > word.length ? word.length : n).toUpperCase();
    if (parts.length == 1) return take(parts.first, 2);
    return '${take(parts.first, 1)}${take(parts.last, 1)}';
  }

  /// The first name, for copy like "Alice's lessons keep working".
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  @override
  List<Object?> get props => [
    id,
    name,
    grade,
    minutesThisWeek,
    questionsAsked,
    streakDays,
    attention,
    subjectMastery,
    recentActivity,
  ];
}

/// One line in the child's recent-activity list.
class ActivityEntry extends Equatable {
  const ActivityEntry({
    required this.kind,
    required this.text,
    required this.at,
  });

  final ActivityKind kind;
  final String text;
  final DateTime at;

  @override
  List<Object?> get props => [kind, text, at];
}

enum ActivityKind { tutor, lesson, workbook, check }

/// A message in the parent ↔ class-teacher thread.
class ParentMessage extends Equatable {
  const ParentMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.at,
    required this.fromParent,
  });

  final String id;

  /// Display name of the sender ("Mrs. Uwase (Class teacher)" / "You").
  final String from;

  final String text;
  final DateTime at;

  /// True when the signed-in parent wrote it — drives bubble alignment.
  final bool fromParent;

  @override
  List<Object?> get props => [id, from, text, at, fromParent];
}

/// The school plan that covers this parent's children, read-only to them.
class ParentPlan extends Equatable {
  const ParentPlan({
    required this.schoolName,
    required this.tier,
    required this.seats,
    required this.renewsOn,
  });

  final String schoolName;
  final String tier;
  final int seats;
  final DateTime renewsOn;

  @override
  List<Object?> get props => [schoolName, tier, seats, renewsOn];
}

/// An optional Mobile Money top-up pack. Never required to keep learning.
class TopupPack extends Equatable {
  const TopupPack({
    required this.id,
    required this.label,
    required this.sessions,
    required this.priceRwf,
  });

  final String id;
  final String label;
  final int sessions;
  final int priceRwf;

  @override
  List<Object?> get props => [id, label, sessions, priceRwf];
}
