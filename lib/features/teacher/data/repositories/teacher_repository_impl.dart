import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/teacher_class.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../datasources/teacher_remote_data_source.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  TeacherRepositoryImpl({required TeacherRemoteDataSource remoteSource})
    : _remote = remoteSource;

  final TeacherRemoteDataSource _remote;

  static const _log = AppLogger('TeacherRepo');

  @override
  Future<Result<List<TeacherClass>>> fetchClasses() =>
      _run(_remote.fetchClasses);

  @override
  Future<Result<List<StudentProgress>>> fetchClassProgress(
    String classId, {
    int days = 30,
  }) => _run(() => _remote.fetchClassProgress(classId, days: days));

  /// Reads answer with an empty list on a build with no Supabase, so the shell
  /// renders its empty state rather than an error nobody can act on.
  Future<Result<List<T>>> _run<T>(Future<List<T>> Function() action) async {
    if (!_remote.isConfigured) return const Result.success([]);
    try {
      return Result.success(await action());
    } catch (e, s) {
      _log.warn('teacher read failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  Failure _mapError(Object error) {
    if (error is TeacherUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is PostgrestException) {
      // class_progress raises "that class is not yours" in its own words.
      return ValidationFailure(error.message, cause: error);
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
