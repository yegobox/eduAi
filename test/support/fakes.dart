import 'dart:async';

import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/error/result.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/auth/domain/entities/phone_otp_challenge.dart';
import 'package:eduai/features/auth/domain/repositories/auth_repository.dart';
import 'package:eduai/features/schools/domain/entities/membership.dart';
import 'package:eduai/features/schools/domain/entities/school.dart';
import 'package:eduai/features/schools/domain/entities/school_class.dart';
import 'package:eduai/features/schools/domain/repositories/schools_repository.dart';

/// In-memory [AuthRepository] for deterministic E2E flows — no Supabase,
/// Firebase, secure storage or network. Behaviour mirrors the real repo's
/// contract (validation, offline unlock, sign-out → offline-locked, …).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    Map<String, String>? validLogins,
    this.initialSession,
    bool hasCredential = false,
    String? offlineLabel,
    String? offlinePin,
  })  : _validLogins =
            validLogins ?? const {'teacher@eduai.dev': 'password123'},
        _credentialStored = hasCredential,
        _label = offlineLabel,
        _pin = offlinePin;

  final Map<String, String> _validLogins;
  final AuthSession? initialSession;
  final _controller = StreamController<AuthSession?>.broadcast();

  bool _credentialStored;
  String? _label;
  String? _pin;

  AppUser _userFor(String email) =>
      AppUser(id: 'u-$email', email: email, displayName: 'Teacher');

  @override
  Stream<AuthSession?> authStateChanges() => _controller.stream;

  @override
  Future<AuthSession?> restoreSession() async => initialSession;

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@')) {
      return const Result.failure(
          ValidationFailure('Enter a valid email address.'));
    }
    if (password.length < 6) {
      return const Result.failure(
          ValidationFailure('Password must be at least 6 characters.'));
    }
    if (_validLogins[email.trim()] != password) {
      return const Result.failure(AuthFailure('Invalid login credentials.'));
    }
    final session = AuthSession(
      user: _userFor(email.trim()),
      provider: AuthProvider.supabaseEmail,
    );
    _credentialStored = true;
    _label = email.trim();
    _controller.add(session);
    return Result.success(session);
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      Result.success(_userFor(email.trim()));

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Result.success(null);

  @override
  Future<Result<PhoneOtpChallenge>> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
  }) async =>
      Result.success(
        PhoneOtpChallenge(phoneNumber: phoneNumber, verificationId: 'vid-1'),
      );

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required PhoneOtpChallenge challenge,
    required String smsCode,
  }) async {
    final session = AuthSession(
      user: AppUser(id: 'u-phone', phoneNumber: challenge.phoneNumber),
      provider: AuthProvider.firebasePhone,
    );
    _credentialStored = true;
    _label = challenge.phoneNumber;
    _controller.add(session);
    return Result.success(session);
  }

  @override
  Future<bool> hasOfflineCredential() async => _credentialStored;

  @override
  Future<String?> offlineAccountLabel() async => _label;

  @override
  Future<bool> hasOfflinePin() async => _pin != null;

  @override
  Future<Result<void>> setOfflinePin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return const Result.failure(ValidationFailure('PIN must be 4–8 digits.'));
    }
    _pin = pin;
    return const Result.success(null);
  }

  @override
  Future<Result<AuthSession>> unlockOffline(String pin) async {
    if (_pin == null) {
      return const Result.failure(
          AuthFailure('No offline PIN is set up on this device.'));
    }
    if (pin != _pin) {
      return const Result.failure(AuthFailure('Incorrect PIN. Try again.'));
    }
    final session = AuthSession(
      user: AppUser(id: 'u-offline', email: _label ?? 'user'),
      provider: AuthProvider.offline,
    );
    _controller.add(session);
    return Result.success(session);
  }

  @override
  Future<Result<void>> signOut({bool forgetDevice = false}) async {
    if (forgetDevice) {
      _credentialStored = false;
      _label = null;
      _pin = null;
    }
    _controller.add(null);
    return const Result.success(null);
  }
}

/// In-memory [SchoolsRepository] with a small seeded catalog.
class FakeSchoolsRepository implements SchoolsRepository {
  FakeSchoolsRepository({List<School>? schools, Map<String, List<SchoolClass>>? classes})
      : _schools = schools ?? List.of(_seedSchools),
        _classes = classes ??
            {
              for (final e in _seedClasses.entries) e.key: List.of(e.value),
            };

  final List<School> _schools;
  final Map<String, List<SchoolClass>> _classes;
  final List<Membership> _memberships = [];
  int _seq = 0;

  static const _seedSchools = [
    School(id: 's1', name: 'Kigali Modern Academy', description: 'Demo school'),
    School(id: 's2', name: 'Green Hills Secondary', joinCode: 'GHS24'),
  ];
  static final _seedClasses = {
    's1': const [
      SchoolClass(id: 'c1', schoolId: 's1', name: 'P5 — Maths', grade: 'P5'),
      SchoolClass(
          id: 'c2', schoolId: 's1', name: 'P6 — English', grade: 'P6', joinCode: 'ENG6'),
    ],
    's2': const [
      SchoolClass(id: 'c3', schoolId: 's2', name: 'S1 — Physics', grade: 'S1'),
    ],
  };

  Membership _add({
    required String schoolId,
    String? classId,
    MemberRole role = MemberRole.student,
  }) {
    final m = Membership(
      id: 'm${_seq++}',
      userId: 'u1',
      schoolId: schoolId,
      classId: classId,
      role: role,
    );
    _memberships.add(m);
    return m;
  }

  @override
  Future<Result<List<School>>> fetchSchools({
    String? query,
    bool preferCache = false,
  }) async {
    final q = query?.trim().toLowerCase();
    final list = (q == null || q.isEmpty)
        ? _schools
        : _schools.where((s) => s.name.toLowerCase().contains(q)).toList();
    return Result.success(List.of(list));
  }

  @override
  Future<Result<List<SchoolClass>>> fetchClasses(String schoolId) async =>
      Result.success(List.of(_classes[schoolId] ?? const []));

  @override
  Future<Result<List<Membership>>> fetchMyMemberships({
    bool preferCache = false,
  }) async =>
      Result.success(List.of(_memberships));

  @override
  Future<Result<Membership>> joinSchool(String schoolId) async =>
      Result.success(_add(schoolId: schoolId));

  @override
  Future<Result<Membership>> joinClass({
    required String schoolId,
    required String classId,
  }) async =>
      Result.success(_add(schoolId: schoolId, classId: classId));

  @override
  Future<Result<Membership>> joinByCode(String code) async {
    for (final s in _schools) {
      if (s.joinCode == code) return Result.success(_add(schoolId: s.id));
    }
    for (final entry in _classes.entries) {
      for (final c in entry.value) {
        if (c.joinCode == code) {
          return Result.success(_add(schoolId: c.schoolId, classId: c.id));
        }
      }
    }
    return const Result.failure(
        ValidationFailure('No school or class matches that code.'));
  }

  @override
  Future<Result<void>> leave(String membershipId) async {
    _memberships.removeWhere((m) => m.id == membershipId);
    return const Result.success(null);
  }

  @override
  Future<Result<School>> createSchool({
    required String name,
    String? description,
    String? joinCode,
  }) async {
    final s = School(
      id: 'school-$_seq',
      name: name,
      description: description,
      joinCode: joinCode,
    );
    _schools.add(s);
    _add(schoolId: s.id, role: MemberRole.owner);
    return Result.success(s);
  }

  @override
  Future<Result<SchoolClass>> createClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  }) async {
    final c = SchoolClass(
      id: 'class-$_seq',
      schoolId: schoolId,
      name: name,
      grade: grade,
      joinCode: joinCode,
    );
    (_classes[schoolId] ??= <SchoolClass>[]).add(c);
    _add(schoolId: schoolId, classId: c.id, role: MemberRole.teacher);
    return Result.success(c);
  }
}
