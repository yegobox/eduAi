import '../../../../core/error/result.dart';
import '../entities/teacher_class.dart';

/// What a teacher's shell reads.
///
/// Everything here is scoped server-side to the school that employs the caller,
/// so there is no school id to pass and no way to ask about somebody else's
/// class by guessing an id.
abstract interface class TeacherRepository {
  /// The classes in the caller's school.
  Future<Result<List<TeacherClass>>> fetchClasses();

  /// Per-student activity for one class over the last [days].
  ///
  /// Rejected by the server when the class belongs to another school.
  Future<Result<List<StudentProgress>>> fetchClassProgress(
    String classId, {
    int days = 30,
  });
}
