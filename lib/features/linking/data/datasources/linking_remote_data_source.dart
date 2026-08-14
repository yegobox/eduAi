import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/family_link.dart';

/// Supabase access for parent ↔ student links.
///
/// Reads go against the tables (RLS scopes them to the two sides of the link);
/// every write goes through a `security definer` function, because creating a
/// link is exactly the operation a client must not be able to perform directly.
class LinkingRemoteDataSource {
  LinkingRemoteDataSource(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const LinkingUnavailable();
    return c;
  }

  String get _uid {
    final id = _client?.auth.currentUser?.id;
    if (id == null) throw const LinkingNotSignedIn();
    return id;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const LinkingUnavailable();
  }

  // ---- Reads -------------------------------------------------------------

  /// Both directions in one query: rows where this account is the parent, and
  /// rows where it is the student. The joined profile gives the other party's
  /// name — RLS on `profiles` permits reading it because the link exists.
  Future<List<FamilyLink>> fetchMyLinks() async {
    final uid = _uid;
    final rows = await _c
        .from('parent_students')
        .select('id, parent_id, student_id, source, '
            'student:profiles!parent_students_student_id_fkey(display_name), '
            'parent:profiles!parent_students_parent_id_fkey(display_name)')
        .or('parent_id.eq.$uid,student_id.eq.$uid');

    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw);
      // Show the other side of the link, whichever side we are on.
      final iAmParent = row['parent_id'] == uid;
      final other = iAmParent ? row['student'] : row['parent'];
      return FamilyLink.fromJson({
        ...row,
        'display_name': other is Map ? other['display_name'] : null,
      });
    }).toList(growable: false);
  }

  Future<List<PendingInvite>> fetchMyPendingInvites() async {
    final rows = await _c
        .from('invites')
        .select()
        .eq('created_by', _uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows
        .map((r) => PendingInvite.fromJson(Map<String, dynamic>.from(r)))
        .toList(growable: false);
  }

  Future<List<RosterEntry>> fetchRoster() async {
    final raw = await _c.rpc('school_roster');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => RosterEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  // ---- Writes ------------------------------------------------------------

  Future<FamilyInvite> inviteChild({String? contact}) async {
    final raw = await _c.rpc('invite_child', params: {'p_contact': contact});
    return FamilyInvite.fromJson(_asMap(raw));
  }

  Future<FamilyInvite> inviteParent({
    required String studentId,
    String? contact,
  }) async {
    final raw = await _c.rpc(
      'invite_parent',
      params: {'p_student_id': studentId, 'p_contact': contact},
    );
    return FamilyInvite.fromJson(_asMap(raw));
  }

  Future<void> redeemCode(String code) async {
    await _c.rpc('redeem_invite', params: {'p_code': code});
  }

  Future<void> unlink(String linkId) async {
    await _c.from('parent_students').delete().eq('id', linkId);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _c.from('invites').update({'status': 'revoked'}).eq('id', inviteId);
  }
}

/// Supabase is not configured on this build.
class LinkingUnavailable implements Exception {
  const LinkingUnavailable();
  @override
  String toString() =>
      'Linking a family needs an internet connection and Supabase setup.';
}

/// No online identity (an offline-unlocked session cannot create links).
class LinkingNotSignedIn implements Exception {
  const LinkingNotSignedIn();
  @override
  String toString() => 'Sign in online to link a family account.';
}
