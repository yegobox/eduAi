import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/membership.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/school_class.dart';

/// All Supabase access for the schools feature. Throws on failure; the
/// repository maps exceptions to `Failure`s. When [_client] is null (Supabase
/// not configured) every method throws [SchoolsUnavailable].
class SchoolsRemoteDataSource {
  SchoolsRemoteDataSource(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const SchoolsUnavailable();
    return c;
  }

  String get _uid {
    final id = _client?.auth.currentUser?.id;
    if (id == null) throw const NotSignedIn();
    return id;
  }

  // ---- Reads -------------------------------------------------------------

  Future<List<School>> fetchSchools({String? query}) async {
    final builder = _c.from('schools').select();
    final rows = await (query == null || query.trim().isEmpty
        ? builder.order('name')
        : builder.ilike('name', '%${query.trim()}%').order('name'));
    return rows.map((r) => School.fromJson(r)).toList();
  }

  /// Just the schools with these ids — what a student's own list needs.
  ///
  /// Fetching the whole catalog to filter it client-side would still pull every
  /// school in the country onto the device to show the one they belong to.
  Future<List<School>> fetchSchoolsByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const [];
    final rows = await _c
        .from('schools')
        .select()
        .inFilter('id', list)
        .order('name');
    return rows.map((r) => School.fromJson(r)).toList();
  }

  Future<List<SchoolClass>> fetchClasses(String schoolId) async {
    final rows =
        await _c.from('classes').select().eq('school_id', schoolId).order('name');
    return rows.map((r) => SchoolClass.fromJson(r)).toList();
  }

  Future<List<Membership>> fetchMyMemberships() async {
    final rows = await _c.from('memberships').select().eq('user_id', _uid);
    return rows.map((r) => Membership.fromJson(r)).toList();
  }

  Future<School?> findSchoolByCode(String code) async {
    final row = await _c
        .from('schools')
        .select()
        .eq('join_code', code)
        .maybeSingle();
    return row == null ? null : School.fromJson(row);
  }

  Future<SchoolClass?> findClassByCode(String code) async {
    final row =
        await _c.from('classes').select().eq('join_code', code).maybeSingle();
    return row == null ? null : SchoolClass.fromJson(row);
  }

  // ---- Writes ------------------------------------------------------------

  /// Enrols with a join code through `enrol_by_code`.
  ///
  /// A `security definer` function rather than a client insert: getting into a
  /// school must require the code, or anybody could enrol into a school they
  /// found in the catalog and consume one of its paid seats.
  Future<void> enrolByCode(String code) async {
    await _c.rpc('enrol_by_code', params: {'p_code': code});
  }

  Future<Membership> insertMembership({
    required String schoolId,
    String? classId,
    MemberRole role = MemberRole.student,
  }) async {
    final row = await _c
        .from('memberships')
        .insert({
          'user_id': _uid,
          'school_id': schoolId,
          'class_id': classId,
          'role': role.name,
        })
        .select()
        .single();
    return Membership.fromJson(row);
  }

  Future<void> deleteMembership(String membershipId) async {
    await _c.from('memberships').delete().eq('id', membershipId);
  }

  Future<School> insertSchool({
    required String name,
    String? description,
    String? joinCode,
  }) async {
    final row = await _c
        .from('schools')
        .insert({
          'name': name,
          'description': description,
          'join_code': joinCode,
          'created_by': _uid,
        })
        .select()
        .single();
    return School.fromJson(row);
  }

  Future<SchoolClass> insertClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  }) async {
    final row = await _c
        .from('classes')
        .insert({
          'school_id': schoolId,
          'name': name,
          'grade': grade,
          'join_code': joinCode,
          'created_by': _uid,
        })
        .select()
        .single();
    return SchoolClass.fromJson(row);
  }
}

/// Supabase not configured on this build.
class SchoolsUnavailable implements Exception {
  const SchoolsUnavailable();
  @override
  String toString() => 'Schools need an internet connection and Supabase setup.';
}

/// No authenticated user (or offline-only session) for a server action.
class NotSignedIn implements Exception {
  const NotSignedIn();
  @override
  String toString() => 'Sign in online to do that.';
}
