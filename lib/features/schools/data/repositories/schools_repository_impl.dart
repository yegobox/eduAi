import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/key_value_cache.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/school_class.dart';
import '../../domain/repositories/schools_repository.dart';
import '../datasources/schools_remote_data_source.dart';

class SchoolsRepositoryImpl implements SchoolsRepository {
  SchoolsRepositoryImpl({
    required SchoolsRemoteDataSource remoteSource,
    required KeyValueCache kvCache,
  })  : _remote = remoteSource,
        _cache = kvCache;

  final SchoolsRemoteDataSource _remote;
  final KeyValueCache _cache;

  static const _log = AppLogger('SchoolsRepo');
  static const _schoolsKey = 'cache.schools.v1';
  static const _mySchoolsKey = 'cache.my_schools.v1';
  static const _membershipsKey = 'cache.memberships.v1';

  // ---- Reads (network-first with offline cache fallback) ----------------

  @override
  Future<Result<List<School>>> fetchSchools({
    String? query,
    bool preferCache = false,
  }) async {
    // Only the unfiltered list is cached; a search always needs the network.
    final cacheable = query == null || query.trim().isEmpty;
    if (preferCache && cacheable) {
      final cached = await _readSchoolCache();
      if (cached != null) return Result.success(cached);
    }
    try {
      final schools = await _remote.fetchSchools(query: query);
      if (cacheable) await _writeCache(_schoolsKey, schools);
      return Result.success(schools);
    } catch (e, s) {
      _log.warn('fetchSchools failed: $e');
      if (cacheable) {
        final cached = await _readSchoolCache();
        if (cached != null) return Result.success(cached);
      }
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<List<School>>> fetchMySchools({bool preferCache = false}) async {
    final memberships = await fetchMyMemberships(preferCache: preferCache);
    final ids = memberships.valueOrNull?.map((m) => m.schoolId).toSet();
    if (ids == null) {
      return Result.failure(
        memberships.failureOrNull ?? const UnknownFailure(),
      );
    }
    if (ids.isEmpty) return const Result.success([]);
    try {
      final schools = await _remote.fetchSchoolsByIds(ids);
      await _writeCache(_mySchoolsKey, schools);
      return Result.success(schools);
    } catch (e, s) {
      _log.warn('fetchMySchools failed: $e');
      final cached = await _readSchoolCache(_mySchoolsKey);
      if (cached != null) return Result.success(cached);
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<List<SchoolClass>>> fetchClasses(String schoolId) async {
    try {
      return Result.success(await _remote.fetchClasses(schoolId));
    } catch (e, s) {
      _log.error('fetchClasses failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<List<Membership>>> fetchMyMemberships({
    bool preferCache = false,
  }) async {
    if (preferCache) {
      final cached = await _readMembershipCache();
      if (cached != null) return Result.success(cached);
    }
    try {
      final memberships = await _remote.fetchMyMemberships();
      await _writeCache(_membershipsKey, memberships);
      return Result.success(memberships);
    } catch (e, s) {
      _log.warn('fetchMyMemberships failed: $e');
      final cached = await _readMembershipCache();
      if (cached != null) return Result.success(cached);
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Joining -----------------------------------------------------------

  @override
  Future<Result<Membership>> joinSchool(String schoolId) =>
      _join(() => _remote.insertMembership(schoolId: schoolId));

  @override
  Future<Result<Membership>> joinClass({
    required String schoolId,
    required String classId,
  }) =>
      _join(() =>
          _remote.insertMembership(schoolId: schoolId, classId: classId));

  @override
  Future<Result<void>> joinByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(ValidationFailure('Enter a join code.'));
    }
    try {
      // Resolved and inserted server-side: the code is what authorises the
      // enrolment, so the client never gets to name the school itself.
      await _remote.enrolByCode(trimmed);
      return const Result.success(null);
    } catch (e, s) {
      _log.error('enrolByCode failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Membership>> _join(Future<Membership> Function() action) async {
    try {
      return Result.success(await action());
    } catch (e, s) {
      _log.error('join failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<void>> leave(String membershipId) async {
    try {
      await _remote.deleteMembership(membershipId);
      return const Result.success(null);
    } catch (e, s) {
      _log.error('leave failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Authoring ---------------------------------------------------------

  @override
  Future<Result<School>> createSchool({
    required String name,
    String? description,
    String? joinCode,
  }) async {
    if (name.trim().isEmpty) {
      return const Result.failure(ValidationFailure('School name is required.'));
    }
    try {
      final school = await _remote.insertSchool(
        name: name.trim(),
        description: description?.trim(),
        joinCode: _normalizeCode(joinCode),
      );
      // Best-effort: enrol the creator as the owner.
      try {
        await _remote.insertMembership(
          schoolId: school.id,
          role: MemberRole.owner,
        );
      } catch (e) {
        _log.warn('owner enrolment skipped: $e');
      }
      return Result.success(school);
    } catch (e, s) {
      _log.error('createSchool failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<SchoolClass>> createClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  }) async {
    if (name.trim().isEmpty) {
      return const Result.failure(ValidationFailure('Class name is required.'));
    }
    try {
      final klass = await _remote.insertClass(
        schoolId: schoolId,
        name: name.trim(),
        grade: grade?.trim(),
        joinCode: _normalizeCode(joinCode),
      );
      try {
        await _remote.insertMembership(
          schoolId: schoolId,
          classId: klass.id,
          role: MemberRole.teacher,
        );
      } catch (e) {
        _log.warn('teacher enrolment skipped: $e');
      }
      return Result.success(klass);
    } catch (e, s) {
      _log.error('createClass failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Cache helpers -----------------------------------------------------

  Future<void> _writeCache(String key, List<Object> items) async {
    await _cache.setJson(
      key,
      items.map((e) => (e as dynamic).toJson()).toList(),
    );
  }

  Future<List<School>?> _readSchoolCache([String key = _schoolsKey]) async {
    final raw = await _cache.getJson(key);
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => School.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<Membership>?> _readMembershipCache() async {
    final raw = await _cache.getJson(_membershipsKey);
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => Membership.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  String? _normalizeCode(String? code) {
    final c = code?.trim();
    return (c == null || c.isEmpty) ? null : c.toUpperCase();
  }

  // ---- Error mapping -----------------------------------------------------

  Failure _mapError(Object error) {
    if (error is SchoolsUnavailable || error is NotSignedIn) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is PostgrestException) {
      if (error.code == '23505') {
        // The same code covers two very different collisions: a duplicate
        // membership, and a join code somebody else already uses. Telling an
        // admin naming a class "You've already joined that" explains nothing.
        final duplicateCode = error.message.toLowerCase().contains('join_code');
        return ValidationFailure(
          duplicateCode
              ? 'That join code is already taken — try another.'
              : "You've already joined that.",
          cause: error,
        );
      }
      return AuthFailure(error.message, cause: error);
    }
    if (error is AuthException) {
      return AuthFailure(error.message, cause: error);
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('failed host lookup')) {
      return NetworkFailure(cause: error);
    }
    return UnknownFailure(cause: error);
  }
}
