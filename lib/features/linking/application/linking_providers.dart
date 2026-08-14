import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/error/result.dart';
import '../../../core/state/action_state.dart';
import '../../access/application/access_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/datasources/linking_remote_data_source.dart';
import '../data/repositories/linking_repository_impl.dart';
import '../domain/entities/family_link.dart';
import '../domain/repositories/linking_repository.dart';

// ---- DI graph ------------------------------------------------------------

final linkingRepositoryProvider = Provider<LinkingRepository>((ref) {
  return LinkingRepositoryImpl(
    remoteSource: LinkingRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

// ---- Reads ---------------------------------------------------------------

/// The signed-in account's family links — children for a parent, parents for
/// a student. Re-read when the session changes.
final familyLinksProvider = FutureProvider<List<FamilyLink>>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref.watch(linkingRepositoryProvider).fetchMyLinks();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

final pendingInvitesProvider = FutureProvider<List<PendingInvite>>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref
      .watch(linkingRepositoryProvider)
      .fetchMyPendingInvites();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The admin's school roster with parent-link state.
final schoolRosterProvider = FutureProvider<List<RosterEntry>>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref.watch(linkingRepositoryProvider).fetchRoster();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

// ---- Writes --------------------------------------------------------------

/// Invite and redeem actions, owning only the busy/error state.
///
/// Redeeming a code can change entitlement — a parent who links a child at a
/// licensed school stops owing anything — so it invalidates the access state
/// as well as the link lists.
class LinkingActionController extends AutoDisposeNotifier<ActionState> {
  @override
  ActionState build() => const ActionState.idle();

  LinkingRepository get _repo => ref.read(linkingRepositoryProvider);

  Future<Result<FamilyInvite>> inviteChild({String? contact}) =>
      _run(() => _repo.inviteChild(contact: contact));

  Future<Result<FamilyInvite>> inviteParent({
    required String studentId,
    String? contact,
  }) => _run(
    () => _repo.inviteParent(studentId: studentId, contact: contact),
  );

  Future<Result<void>> redeemCode(String code) =>
      _run(() => _repo.redeemCode(code));

  Future<Result<void>> unlink(String linkId) =>
      _run(() => _repo.unlink(linkId));

  Future<Result<T>> _run<T>(Future<Result<T>> Function() action) async {
    state = const ActionState.loading();
    final result = await action();
    state = result.failureOrNull == null
        ? const ActionState.idle()
        : ActionState.error(result.failureOrNull!);
    if (result.isSuccess) {
      ref.invalidate(familyLinksProvider);
      ref.invalidate(pendingInvitesProvider);
      ref.invalidate(schoolRosterProvider);
      ref.invalidate(accessStateProvider);
    }
    return result;
  }
}

final linkingActionControllerProvider =
    AutoDisposeNotifierProvider<LinkingActionController, ActionState>(
      LinkingActionController.new,
    );
