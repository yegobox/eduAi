import 'package:equatable/equatable.dart';

enum MemberRole { student, teacher, owner }

MemberRole _roleFrom(String? raw) => MemberRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => MemberRole.student,
    );

/// A user's enrollment. [classId] is null when the user joined a school but
/// not a specific class yet.
class Membership extends Equatable {
  const Membership({
    required this.id,
    required this.userId,
    required this.schoolId,
    this.classId,
    this.role = MemberRole.student,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String schoolId;
  final String? classId;
  final MemberRole role;
  final DateTime? createdAt;

  bool get isClassMember => classId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'school_id': schoolId,
        'class_id': classId,
        'role': role.name,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        schoolId: json['school_id'] as String,
        classId: json['class_id'] as String?,
        role: _roleFrom(json['role'] as String?),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [id, userId, schoolId, classId, role];
}
