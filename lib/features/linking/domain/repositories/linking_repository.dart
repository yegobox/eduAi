import '../../../../core/error/result.dart';
import '../entities/family_link.dart';

/// Parent ↔ student links, and the invites that create them.
///
/// Both directions live behind one contract because they produce the same
/// thing — a row in `parent_students` — and are redeemed by the same call.
abstract interface class LinkingRepository {
  /// The confirmed links for the signed-in account: children when a parent is
  /// asking, parents when a student is.
  Future<Result<List<FamilyLink>>> fetchMyLinks();

  /// Invites this account created that nobody has redeemed yet.
  Future<Result<List<PendingInvite>>> fetchMyPendingInvites();

  /// Parent side: mint a code for this parent's own child to type in.
  /// [contact] is recorded for the pending list only.
  Future<Result<FamilyInvite>> inviteChild({String? contact});

  /// School side: mint a code for the parent of an enrolled student.
  /// Rejected by the server unless the caller is that school's admin.
  Future<Result<FamilyInvite>> inviteParent({
    required String studentId,
    String? contact,
  });

  /// Redeems either kind of code. Which side of the link the signed-in account
  /// supplies is decided by the invite, not by the caller.
  Future<Result<void>> redeemCode(String code);

  /// Removes a link. Parent-side only — a school cannot unlink a family.
  Future<Result<void>> unlink(String linkId);

  /// The school's roster with parent-link state, for the admin People tab.
  Future<Result<List<RosterEntry>>> fetchRoster();
}
