import 'dart:async';
import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/workbook_feedback.dart';
import '../../domain/repositories/workbook_check_repository.dart';
import '../datasources/workbook_check_remote_data_source.dart';

class WorkbookCheckRepositoryImpl implements WorkbookCheckRepository {
  WorkbookCheckRepositoryImpl({
    required WorkbookCheckRemoteDataSource remoteSource,
  }) : _remote = remoteSource;

  final WorkbookCheckRemoteDataSource _remote;

  static const _log = AppLogger('WorkbookCheck');

  @override
  Future<Result<WorkbookFeedback>> check(Uint8List pageImage) async {
    if (pageImage.isEmpty) {
      return const Result.failure(
        ValidationFailure('Write some working on the page first.'),
      );
    }
    try {
      return Result.success(await _remote.check(pageImage));
    } catch (e, s) {
      _log.warn('workbook check failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  Failure _mapError(Object error) {
    if (error is WorkbookCheckUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is WorkbookCheckException) {
      return UnknownFailure(message: error.message, cause: error);
    }
    if (error is TimeoutException) return NetworkFailure(cause: error);
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
