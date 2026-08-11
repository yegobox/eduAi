import 'package:equatable/equatable.dart';

/// A school in the catalog.
class School extends Equatable {
  const School({
    required this.id,
    required this.name,
    this.description,
    this.joinCode,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? joinCode;
  final String? createdBy;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'join_code': joinCode,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };

  factory School.fromJson(Map<String, dynamic> json) => School(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        joinCode: json['join_code'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [id, name, description, joinCode];
}
