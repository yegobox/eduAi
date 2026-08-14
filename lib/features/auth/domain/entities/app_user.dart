import 'package:equatable/equatable.dart';

import 'app_role.dart';

/// A platform-agnostic identity. Deliberately decoupled from Supabase's `User`
/// and Firebase's `User` so the rest of the app never imports an SDK type.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.avatarUrl,
    this.role = AppRole.student,
  });

  final String id;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? avatarUrl;

  /// Which shell this identity lands in. Defaults to [AppRole.student]
  /// because that is the overwhelming majority of accounts.
  final AppRole role;

  /// Best label to greet the user with.
  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : (email ?? phoneNumber ?? 'there');

  AppUser copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? avatarUrl,
    AppRole? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phoneNumber': phoneNumber,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role.wireName,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    displayName: json['displayName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    role: AppRole.fromWire(json['role'] as String?),
  );

  @override
  List<Object?> get props => [
    id,
    email,
    phoneNumber,
    displayName,
    avatarUrl,
    role,
  ];
}
