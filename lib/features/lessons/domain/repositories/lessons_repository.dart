import '../../../../core/error/result.dart';
import '../entities/lesson.dart';

/// The curriculum library. Offline-first: the catalog itself always resolves,
/// and per-lesson download / completion flags live on the device.
abstract interface class LessonsRepository {
  /// The full catalog with each lesson's local download / completion state
  /// already merged in.
  Future<Result<List<Lesson>>> fetchCatalog();

  /// Adds or removes a lesson from the offline cache. Returns the updated
  /// lesson so callers can reconcile optimistic UI.
  Future<Result<Lesson>> setDownloaded(String lessonId, bool downloaded);

  /// Marks a lesson complete. Idempotent — completing twice is not an error.
  Future<Result<Lesson>> markComplete(String lessonId);
}
