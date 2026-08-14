import '../../../../core/error/result.dart';
import '../entities/membership.dart';
import '../entities/school.dart';
import '../entities/school_class.dart';

/// Contract for the schools/classes catalog and the current user's
/// enrollments. Implementations talk to Supabase and a local cache.
abstract interface class SchoolsRepository {
  /// The public catalog, newest-relevant first. [query] filters by name.
  /// [preferCache] returns the last-known list without hitting the network
  /// (used while offline).
  Future<Result<List<School>>> fetchSchools({
    String? query,
    bool preferCache = false,
  });

  /// The schools this account actually belongs to. What a student sees.
  Future<Result<List<School>>> fetchMySchools({bool preferCache = false});

  Future<Result<List<SchoolClass>>> fetchClasses(String schoolId);

  /// The signed-in user's memberships.
  Future<Result<List<Membership>>> fetchMyMemberships({
    bool preferCache = false,
  });

  /// Join a school (no specific class).
  Future<Result<Membership>> joinSchool(String schoolId);

  /// Enrol in a specific class (also records school membership context).
  Future<Result<Membership>> joinClass({
    required String schoolId,
    required String classId,
  });

  /// Enrols with a join code, resolved and inserted server-side.
  ///
  /// The code is what authorises the enrolment: a client cannot name the school
  /// itself, because getting into a school consumes one of its paid seats.
  Future<Result<void>> joinByCode(String code);

  /// Leave a school/class by membership id.
  Future<Result<void>> leave(String membershipId);

  // --- Authoring (creator becomes owner) ---------------------------------

  Future<Result<School>> createSchool({
    required String name,
    String? description,
    String? joinCode,
  });

  Future<Result<SchoolClass>> createClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  });
}
