import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/postgrest_errors.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/app_role.dart';

/// What `public.profiles` holds about an account beyond its identity.
class ProfileRecord {
  const ProfileRecord({required this.role, this.phone});

  final AppRole role;

  /// The Mobile Money number this account last paid with, when one is known.
  /// Null for an account that has never paid — the payment sheet then asks.
  final String? phone;
}

/// Reads the signed-in account's role from `public.profiles`.
///
/// The role is the one fact that decides which product surface an identity
/// gets, so it is deliberately *not* read from Supabase user metadata: a
/// client can write its own metadata at sign-up, and it stays writable
/// afterwards. `profiles.role` is set once by a trigger and pinned by another
/// (see `0003_identity_and_billing.sql`), which makes the server the authority.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final SupabaseClient? _client;

  static const _log = AppLogger('ProfileSource');

  bool get isConfigured => _client != null;

  /// The role for [userId], or null when it cannot be determined.
  Future<AppRole?> fetchRole(String userId) async =>
      (await fetchProfile(userId))?.role;

  /// The role and Mobile Money number on record for [userId], or null when the
  /// profile cannot be read (no Supabase on this build, no network, no row).
  ///
  /// Null means "do not change what you already believe" — never "student".
  /// Downgrading a school director to the student shell because a request
  /// timed out would look exactly like data loss to them.
  Future<ProfileRecord?> fetchProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client
          .from('profiles')
          // `phone` is read as well as written: an account created with an
          // email has no phone on its Supabase identity, so the number the
          // payer typed into the Mobile Money sheet is the only one we have.
          .select('role, phone')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        // The account predates the `handle_new_user` trigger and the backfill
        // has not run. Same treatment as an error: keep the cached role.
        _log.warn(
          'No profiles row for $userId — has migration 0003 been applied?',
        );
        return null;
      }
      return ProfileRecord(
        role: AppRole.fromWire(row['role'] as String?),
        phone: (row['phone'] as String?)?.trim(),
      );
    } on PostgrestException catch (e) {
      // A missing `profiles` table is a misconfiguration, not a blip: every
      // account silently becomes a student, so it is logged at error level
      // rather than swallowed. AccessNotice shows the user the same thing.
      if (PostgrestErrors.isMissingSchema(e)) {
        _log.error(
          'public.profiles is missing — roles cannot be read. '
          'Run supabase/migrations/0003_identity_and_billing.sql.',
        );
      } else {
        _log.warn('Could not read the role for $userId: ${e.message}');
      }
      return null;
    } catch (e) {
      // Transient. Callers treat it exactly like an unknown role.
      _log.warn('Could not read the role for $userId: $e');
      return null;
    }
  }

  /// Keeps the profile's display fields in step with the account. Best-effort:
  /// the trigger has already created the row, this only refreshes it.
  Future<void> syncDisplayFields({
    required String userId,
    String? displayName,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) return;
    final patch = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };
    if (patch.isEmpty) return;
    try {
      await client.from('profiles').update(patch).eq('id', userId);
    } catch (_) {
      // Cosmetic. A stale display name must never block a sign-in.
    }
  }
}
