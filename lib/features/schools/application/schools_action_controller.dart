import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/state/action_state.dart';
import '../../access/application/access_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/entities/app_role.dart';
import '../domain/entities/membership.dart';
import '../domain/entities/school.dart';
import '../domain/entities/school_class.dart';
import 'schools_providers.dart';

/// Runs the schools commands (join / leave / create) and refreshes the
/// affected read providers on success. Owns only the busy/error state.
class SchoolsActionController extends AutoDisposeNotifier<ActionState> {
  @override
  ActionState build() => const ActionState.idle();

  /// Enrolling consumes a seat on the school's licence, so it belongs to
  /// student accounts only. A director joining another school would take a seat
  /// there and land their own admin identity inside somebody else's roster; a
  /// parent follows a child through a family link, not an enrolment.
  ///
  /// Read from the signed-in session rather than [activeRoleProvider] on
  /// purpose: this is an authorisation decision, and the debug "View as"
  /// override must not be able to move it. The server enforces the same rule
  /// in `may_enrol()` — this only saves a round trip and gives a better message.
  Failure? _enrolmentBlock() {
    final role =
        ref.read(authControllerProvider).session?.user.role ?? AppRole.student;
    return switch (role) {
      AppRole.student => null,
      AppRole.schoolAdmin => const ValidationFailure(
        'A school account cannot enrol as a student. Manage your own school '
        'from the Licence tab.',
      ),
      AppRole.parent => const ValidationFailure(
        'Parent accounts do not join schools. Link your child instead, and '
        'their school comes with them.',
      ),
      AppRole.teacher => const ValidationFailure(
        'Teacher accounts are added by their school, not by enrolling. Ask '
        'your director for a teacher code.',
      ),
    };
  }

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

  Future<Result<void>> joinByCode(String code) async {
    final blocked = _enrolmentBlock();
    if (blocked != null) {
      state = ActionState.error(blocked);
      return Result.failure(blocked);
    }
    state = const ActionState.loading();
    final result = await ref.read(schoolsRepositoryProvider).joinByCode(code);
    _settle(result.failureOrNull);
    if (result.isSuccess) {
      _refreshMemberships();
      ref.invalidate(mySchoolsProvider);
      ref.invalidate(schoolsListProvider);
    }
    return result;
  }

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
      // Creating a school starts its trial licence (by trigger, server-side),
      // which is a change of entitlement — the admin shell must see it without
      // a restart.
      ref.invalidate(accessStateProvider);
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

  /// Every enrolment path funnels through here, so the role check cannot be
  /// bypassed by adding a fourth way to join.
  Future<Result<Membership>> _runMembership(
    Future<Result<Membership>> Function() action,
  ) async {
    final blocked = _enrolmentBlock();
    if (blocked != null) {
      state = ActionState.error(blocked);
      return Result.failure(blocked);
    }
    state = const ActionState.loading();
    final result = await action();
    _settle(result.failureOrNull);
    if (result.isSuccess) _refreshMemberships();
    return result;
  }

  /// Memberships are what a student's entitlement is derived from — joining a
  /// licensed school grants access, leaving it takes access away — so the two
  /// are always refreshed together.
  void _refreshMemberships() {
    ref.invalidate(myMembershipsProvider);
    ref.invalidate(mySchoolsProvider);
    ref.invalidate(accessStateProvider);
  }

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
