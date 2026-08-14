import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/momo_payment.dart';
import '../../domain/momo_msisdn.dart';
import '../../domain/repositories/payments_repository.dart';
import '../datasources/momo_remote_data_source.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl({required MomoRemoteDataSource remoteSource})
    : _remote = remoteSource;

  final MomoRemoteDataSource _remote;

  static const _log = AppLogger('Payments');

  @override
  Future<Result<String>> initiate({
    required String phoneNumber,
    required int amountRwf,
    required MomoPurpose purpose,
  }) async {
    // Enough context to reconstruct the attempt from a log alone: what was
    // asked for, and where it was sent. The payer's number is reduced to its
    // last three digits — a log is the wrong place for somebody's MSISDN, and
    // three digits is enough to match it against a support call.
    final target = _remote.payNowEndpoint;
    _log.info(
      'payNow → $target amount=$amountRwf RWF purpose=${purpose.name} '
      'branch=${_remote.branchId} payer=${MomoMsisdn.masked(phoneNumber)}',
    );
    try {
      final reference = await _remote.payNow(
        phoneNumber: phoneNumber,
        amountRwf: amountRwf,
        purpose: purpose,
      );
      // The reference is the only handle on real money moving; log it so a
      // support ticket can always be reconciled against the gateway.
      _log.info('payNow accepted, reference=$reference');
      return Result.success(reference);
    } catch (e, s) {
      // At error level, with the gateway's own words and the HTTP status: a
      // failed collection is not a warning, and "rejected as invalid" with no
      // detail is not something anybody can act on.
      // Self-contained on purpose: this one line has to be enough to act on,
      // because it is the line that reaches the terminal.
      final attempt =
          '$target amount=$amountRwf RWF purpose=${purpose.name} '
          'branch=${_remote.branchId} payer=${MomoMsisdn.masked(phoneNumber)}';
      if (e is MomoException) {
        _log.error(
          'payNow REJECTED (HTTP ${e.statusCode ?? '-'}) — gateway said: '
          '${e.gatewayMessage ?? '<no message in the response>'} '
          '[$attempt]',
          e,
          s,
        );
      } else {
        _log.error('payNow failed [$attempt]', e, s);
      }
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<MomoSettlement>> fetchStatus(String reference) async {
    try {
      return Result.success(await _remote.requestToPayStatus(reference));
    } catch (e, s) {
      _log.warn('requesttopay status failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  Failure _mapError(Object error) {
    if (error is MomoUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is MomoException) {
      // A rejected request is the caller's problem to fix (bad number,
      // bad amount); a gateway fault is not.
      return error.statusCode == 400 || error.statusCode == null
          ? ValidationFailure(error.message, cause: error)
          : UnknownFailure(message: error.message, cause: error);
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
