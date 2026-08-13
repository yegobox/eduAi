import '../../../../core/error/result.dart';
import '../entities/progress_summary.dart';

/// Reads and appends the signed-in user's learning history.
abstract interface class ProgressRepository {
  /// Records that the user asked the tutor something.
  ///
  /// Recording is best-effort: a failure here must never interrupt the
  /// conversation, so callers may ignore the result.
  Future<Result<void>> recordQuestion({
    required String question,
    String? subject,
    String? level,
  });

  /// Records the answer to a concept check.
  Future<Result<void>> recordCheck({
    required bool correct,
    required String question,
    String? subject,
    String? level,
  });

  /// The user's rolled-up progress. [preferCache] serves the last known
  /// summary without hitting the network (used while offline).
  Future<Result<ProgressSummary>> fetchSummary({bool preferCache = false});
}
