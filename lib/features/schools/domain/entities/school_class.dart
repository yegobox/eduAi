import 'package:equatable/equatable.dart';

/// A class (group of learners) that belongs to a [School].
class SchoolClass extends Equatable {
  const SchoolClass({
    required this.id,
    required this.schoolId,
    required this.name,
    this.grade,
    this.joinCode,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String schoolId;
  final String name;
  final String? grade;
  final String? joinCode;
  final String? createdBy;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'grade': grade,
        'join_code': joinCode,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        name: json['name'] as String,
        grade: json['grade'] as String?,
        joinCode: json['join_code'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [id, schoolId, name, grade, joinCode];
}
