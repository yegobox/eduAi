import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/state/action_state.dart';
import '../domain/entities/membership.dart';
import '../domain/entities/school.dart';
import '../domain/entities/school_class.dart';
import 'schools_providers.dart';

/// Runs the schools commands (join / leave / create) and refreshes the
/// affected read providers on success. Owns only the busy/error state.
class SchoolsActionController extends AutoDisposeNotifier<ActionState> {
  @override
  ActionState build() => const ActionState.idle();

  Future<Result<Membership>> joinSchool(String schoolId) =>
      _runMembership(() =>
          ref.read(schoolsRepositoryProvider).joinSchool(schoolId));

  Future<Result<Membership>> joinClass({
    required String schoolId,
    required String classId,
  }) =>
      _runMembership(() => ref
          .read(schoolsRepositoryProvider)
          .joinClass(schoolId: schoolId, classId: classId));

  Future<Result<Membership>> joinByCode(String code) => _runMembership(
      () => ref.read(schoolsRepositoryProvider).joinByCode(code));

  Future<Result<void>> leave(String membershipId) async {
    state = const ActionState.loading();
    final result =
        await ref.read(schoolsRepositoryProvider).leave(membershipId);
    _settle(result.failureOrNull);
    if (result.isSuccess) _refreshMemberships();
    return result;
  }

  Future<Result<School>> createSchool({
    required String name,
    String? description,
    String? joinCode,
  }) async {
    state = const ActionState.loading();
    final result = await ref.read(schoolsRepositoryProvider).createSchool(
          name: name,
          description: description,
          joinCode: joinCode,
        );
    _settle(result.failureOrNull);
    if (result.isSuccess) {
      ref.invalidate(schoolsListProvider);
      _refreshMemberships();
    }
    return result;
  }

  Future<Result<SchoolClass>> createClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  }) async {
    state = const ActionState.loading();
    final result = await ref.read(schoolsRepositoryProvider).createClass(
          schoolId: schoolId,
          name: name,
          grade: grade,
          joinCode: joinCode,
        );
    _settle(result.failureOrNull);
    if (result.isSuccess) {
      ref.invalidate(classesProvider(schoolId));
      _refreshMemberships();
    }
    return result;
  }

  Future<Result<Membership>> _runMembership(
    Future<Result<Membership>> Function() action,
  ) async {
    state = const ActionState.loading();
    final result = await action();
    _settle(result.failureOrNull);
    if (result.isSuccess) _refreshMemberships();
    return result;
  }

  void _refreshMemberships() => ref.invalidate(myMembershipsProvider);

  void _settle(Failure? failure) {
    state = failure == null
        ? const ActionState.idle()
        : ActionState.error(failure);
  }
}

final schoolsActionControllerProvider =
    AutoDisposeNotifierProvider<SchoolsActionController, ActionState>(
  SchoolsActionController.new,
);
