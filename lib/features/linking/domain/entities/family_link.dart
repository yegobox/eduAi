import 'package:equatable/equatable.dart';

/// Which direction a family invite runs.
enum InviteKind {
  /// A school nominates the parent of one of its enrolled students. The school
  /// holds the code; the parent redeems it.
  parentOfStudent,

  /// A parent invites their own child. The parent holds the code; the student
  /// redeems it.
  studentOfParent,

  /// A school employs a teacher. The school holds the code; the teacher
  /// redeems it, which is the only way the teacher role is ever granted.
  teacherOfSchool;

  String get wireName => switch (this) {
    InviteKind.parentOfStudent => 'parent_of_student',
    InviteKind.studentOfParent => 'student_of_parent',
    InviteKind.teacherOfSchool => 'teacher_of_school',
  };

  static InviteKind fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'parent_of_student' => InviteKind.parentOfStudent,
        'teacher_of_school' => InviteKind.teacherOfSchool,
        _ => InviteKind.studentOfParent,
      };
}

/// A freshly-minted invite code, as the server returns it.
class FamilyInvite extends Equatable {
  const FamilyInvite({
    required this.id,
    required this.code,
    required this.kind,
  });

  final String id;

  /// The seven-character code the other party types in. Deliberately drawn
  /// from an alphabet with no 0/O or 1/I, because it gets read down a phone.
  final String code;

  final InviteKind kind;

  factory FamilyInvite.fromJson(Map<String, dynamic> json) => FamilyInvite(
    id: json['id'] as String? ?? '',
    code: (json['code'] as String? ?? '').toUpperCase(),
    kind: InviteKind.fromWire(json['kind'] as String?),
  );

  @override
  List<Object?> get props => [id, code, kind];
}

/// Who the invite was addressed to and whether it is still open — the parent
/// side of the school's roster, and the pending list on the parent's own page.
class PendingInvite extends Equatable {
  const PendingInvite({
    required this.id,
    required this.code,
    required this.kind,
    required this.expiresAt,
    this.contact,
    this.studentId,
  });

  final String id;
  final String code;
  final InviteKind kind;
  final DateTime expiresAt;

  /// Phone or email it was addressed to, when one was given. Never used to
  /// authorise anything — the code is what authorises.
  final String? contact;

  final String? studentId;

  bool isExpired({DateTime? now}) =>
      !expiresAt.isAfter(now ?? DateTime.now());

  factory PendingInvite.fromJson(Map<String, dynamic> json) => PendingInvite(
    id: json['id'] as String,
    code: (json['code'] as String? ?? '').toUpperCase(),
    kind: InviteKind.fromWire(json['kind'] as String?),
    expiresAt:
        DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    contact: json['contact'] as String?,
    studentId: json['student_id'] as String?,
  );

  @override
  List<Object?> get props => [id, code, kind, expiresAt, contact, studentId];
}

/// A confirmed parent ↔ student link, from whichever side is looking.
class FamilyLink extends Equatable {
  const FamilyLink({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.createdBySchool,
    this.displayName,
  });

  final String id;
  final String parentId;
  final String studentId;

  /// True when the school set the link up, false when a parent did. Shown so a
  /// parent can tell "the school added me" from "I added this child".
  final bool createdBySchool;

  /// The *other* person's name — the child's when a parent is looking.
  final String? displayName;

  factory FamilyLink.fromJson(Map<String, dynamic> json) => FamilyLink(
    id: json['id'] as String,
    parentId: json['parent_id'] as String,
    studentId: json['student_id'] as String,
    createdBySchool: (json['source'] as String?) == 'school',
    displayName: json['display_name'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    parentId,
    studentId,
    createdBySchool,
    displayName,
  ];
}

/// One student on a school's roster, with the state of their parent link.
class RosterEntry extends Equatable {
  const RosterEntry({
    required this.studentId,
    required this.studentName,
    required this.parentsLinked,
    required this.invitePending,
    this.classId,
    this.className,
  });

  final String studentId;
  final String studentName;

  /// How many parent accounts are linked to this student.
  final int parentsLinked;

  /// True when an unexpired invite is outstanding.
  final bool invitePending;

  final String? classId;
  final String? className;

  bool get hasParent => parentsLinked > 0;

  factory RosterEntry.fromJson(Map<String, dynamic> json) => RosterEntry(
    studentId: json['student_id'] as String,
    studentName: json['student_name'] as String? ?? 'Student',
    parentsLinked: (json['parents_linked'] as num?)?.round() ?? 0,
    invitePending: json['invite_pending'] == true,
    classId: json['class_id'] as String?,
    className: json['class_name'] as String?,
  );

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    parentsLinked,
    invitePending,
    classId,
    className,
  ];
}
