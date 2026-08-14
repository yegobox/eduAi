import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/family_link.dart';
import '../../domain/repositories/linking_repository.dart';
import '../datasources/linking_remote_data_source.dart';

class LinkingRepositoryImpl implements LinkingRepository {
  LinkingRepositoryImpl({required LinkingRemoteDataSource remoteSource})
    : _remote = remoteSource;

  final LinkingRemoteDataSource _remote;

  static const _log = AppLogger('LinkingRepo');

  @override
  Future<Result<List<FamilyLink>>> fetchMyLinks() =>
      _run(_remote.fetchMyLinks, whenUnconfigured: const []);

  @override
  Future<Result<List<PendingInvite>>> fetchMyPendingInvites() =>
      _run(_remote.fetchMyPendingInvites, whenUnconfigured: const []);

  @override
  Future<Result<List<RosterEntry>>> fetchRoster() =>
      _run(_remote.fetchRoster, whenUnconfigured: const []);

  @override
  Future<Result<FamilyInvite>> inviteChild({String? contact}) =>
      _run(() => _remote.inviteChild(contact: _clean(contact)));

  @override
  Future<Result<FamilyInvite>> inviteParent({
    required String studentId,
    String? contact,
  }) {
    if (studentId.trim().isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Pick a student first.')),
      );
    }
    return _run(
      () => _remote.inviteParent(
        studentId: studentId,
        contact: _clean(contact),
      ),
    );
  }

  @override
  Future<Result<FamilyInvite>> inviteTeacher({String? contact}) =>
      _run(() => _remote.inviteTeacher(contact: _clean(contact)));

  @override
  Future<Result<void>> redeemCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length < 4) {
      return Future.value(
        const Result.failure(ValidationFailure('Enter the full code.')),
      );
    }
    return _run(() => _remote.redeemCode(normalized));
  }

  @override
  Future<Result<void>> unlink(String linkId) =>
      _run(() => _remote.unlink(linkId));

  /// Runs a remote call, mapping transport errors to [Failure]s.
  ///
  /// [whenUnconfigured] lets the *reads* answer with an empty list on a build
  /// with no Supabase, so the linking screens render their empty state instead
  /// of an error. Writes have no such fallback: pretending to send an invite
  /// that no server ever saw would be worse than saying it cannot be done.
  Future<Result<T>> _run<T>(
    Future<T> Function() action, {
    T? whenUnconfigured,
  }) async {
    if (!_remote.isConfigured && whenUnconfigured != null) {
      return Result.success(whenUnconfigured);
    }
    try {
      return Result.success(await action());
    } catch (e, s) {
      _log.warn('linking call failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Failure _mapError(Object error) {
    if (error is LinkingUnavailable || error is LinkingNotSignedIn) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is PostgrestException) {
      // redeem_invite / invite_parent raise messages written for the user
      // ("that invite has expired — ask for a new code").
      return ValidationFailure(error.message, cause: error);
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
