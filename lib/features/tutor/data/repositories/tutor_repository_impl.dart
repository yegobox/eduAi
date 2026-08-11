import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/tutor_turn.dart';
import '../../domain/repositories/tutor_repository.dart';
import '../datasources/tutor_remote_data_source.dart';

class TutorRepositoryImpl implements TutorRepository {
  TutorRepositoryImpl({required TutorRemoteDataSource remoteSource})
      : _remote = remoteSource;

  final TutorRemoteDataSource _remote;

  static const _log = AppLogger('TutorRepo');

  @override
  Future<Result<TutorAnswer>> ask({
    required String message,
    required List<TutorTurn> history,
    String? subject,
    String? level,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(ValidationFailure('Ask a question first.'));
    }
    try {
      final answer = await _remote.chat(
        message: trimmed,
        history: history
            .map((t) => {'role': t.role, 'content': t.historyContent})
            .toList(),
        subject: subject,
        level: level,
      );
      return Result.success(answer);
    } catch (e, s) {
      _log.warn('tutor ask failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  Failure _mapError(Object error) {
    if (error is TutorUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is TutorApiException) {
      return UnknownFailure(message: error.message, cause: error);
    }
    if (error is TimeoutException) {
      return NetworkFailure(cause: error);
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
