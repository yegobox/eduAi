import 'package:equatable/equatable.dart';

/// One class a teacher runs, with the count that matters day to day.
class TeacherClass extends Equatable {
  const TeacherClass({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.studentCount,
    this.grade,
    this.joinCode,
  });

  final String id;
  final String schoolId;
  final String name;

  /// Students enrolled in this class, counted server-side from memberships.
  final int studentCount;

  final String? grade;

  /// What a student types once to enrol. Null when the class was created
  /// without one, in which case nobody can join it.
  final String? joinCode;

  bool get isJoinable => joinCode != null && joinCode!.isNotEmpty;

  factory TeacherClass.fromJson(Map<String, dynamic> json) => TeacherClass(
    id: json['id'] as String,
    schoolId: json['school_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Class',
    studentCount: (json['student_count'] as num?)?.round() ?? 0,
    grade: (json['grade'] as String?)?.trim(),
    joinCode: (json['join_code'] as String?)?.trim(),
  );

  @override
  List<Object?> get props => [
    id,
    schoolId,
    name,
    studentCount,
    grade,
    joinCode,
  ];
}

/// One student's activity in a class, as `class_progress()` reports it.
///
/// Counts and an accuracy — never the questions themselves. A child's tutor
/// conversation is theirs; a teacher needs to know who is struggling, not what
/// they typed.
class StudentProgress extends Equatable {
  const StudentProgress({
    required this.studentId,
    required this.studentName,
    required this.questions,
    required this.checks,
    required this.correct,
    required this.parentsLinked,
    this.lastActive,
  });

  final String studentId;
  final String studentName;

  /// Questions asked of the AI Tutor in the window.
  final int questions;

  /// Concept checks answered, and how many were right.
  final int checks;
  final int correct;

  final int parentsLinked;
  final DateTime? lastActive;

  bool get hasParent => parentsLinked > 0;

  /// Anything at all in the window.
  bool get isActive => questions > 0 || checks > 0;

  /// Share of checks answered correctly, or null when none were answered —
  /// 0% and "no checks yet" mean very different things to a teacher.
  double? get accuracy => checks == 0 ? null : correct / checks;

  /// Who to look at first: nobody who has done nothing is "struggling", they
  /// are simply absent, and the two need different responses. Lower sorts
  /// first.
  ///
  /// Order: has checks and is getting them wrong → never started → doing fine.
  int get attentionRank {
    if (checks > 0 && (accuracy ?? 1) < 0.6) return 0;
    if (!isActive) return 1;
    return 2;
  }

  factory StudentProgress.fromJson(Map<String, dynamic> json) {
    final last = json['last_active'] as String?;
    return StudentProgress(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String? ?? 'Student',
      questions: (json['questions'] as num?)?.round() ?? 0,
      checks: (json['checks'] as num?)?.round() ?? 0,
      correct: (json['correct'] as num?)?.round() ?? 0,
      parentsLinked: (json['parents_linked'] as num?)?.round() ?? 0,
      lastActive: last == null ? null : DateTime.tryParse(last)?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    questions,
    checks,
    correct,
    parentsLinked,
    lastActive,
  ];
}
