import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/postgrest_errors.dart';
import '../../domain/entities/access_state.dart';
import '../../domain/entities/payment_quote.dart';

/// Every entitlement read and purchase write, as Supabase RPC calls.
///
/// All of these are `security definer` functions rather than table access:
/// activating a licence or extending a subscription must not be something a
/// client can do with an UPDATE, so no table policy allows it.
class AccessRemoteDataSource {
  AccessRemoteDataSource(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const AccessUnavailable();
    return c;
  }

  bool get isSignedIn => _client?.auth.currentUser != null;

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const AccessUnavailable();
  }

  // ---- Entitlement -------------------------------------------------------

  Future<AccessState> fetchState() async {
    try {
      final raw = await _c.rpc('access_state');
      return AccessState.fromJson(_asMap(raw));
    } on PostgrestException catch (e) {
      if (PostgrestErrors.isMissingSchema(e)) {
        throw const BillingSchemaMissing();
      }
      rethrow;
    }
  }

  /// Whether the project is quoting reduced amounts for testing.
  ///
  /// Read separately from a quote because the parent plan grid prices several
  /// cards from the static price list and never loads a quote until one is
  /// tapped — without this it would advertise the list price and then charge
  /// the test amount.
  Future<bool> fetchTestMode() async {
    final raw = await _c.rpc('billing_test_mode');
    return raw == true;
  }

  // ---- School licence ----------------------------------------------------

  Future<SchoolLicenseQuote> schoolLicenseQuote({int? seats}) async {
    final raw = await _c.rpc(
      'school_license_quote',
      params: {'p_seats': seats},
    );
    return SchoolLicenseQuote.fromJson(_asMap(raw));
  }

  Future<AccessState> selectSchoolTier(String tierId) async {
    final raw = await _c.rpc(
      'select_school_tier',
      params: {'p_tier_id': tierId},
    );
    return AccessState.fromJson(_asMap(raw));
  }

  Future<AccessState> setSeatsPurchased(int seats) async {
    final raw = await _c.rpc(
      'set_seats_purchased',
      params: {'p_seats': seats},
    );
    return AccessState.fromJson(_asMap(raw));
  }

  Future<AccessState> settleSchoolLicense({
    required String reference,
    required int amountRwf,
    int? seats,
  }) async {
    final raw = await _c.rpc(
      'settle_school_license',
      params: {
        'p_reference': reference,
        'p_amount_reported': amountRwf,
        'p_seats': seats,
      },
    );
    return AccessState.fromJson(_asMap(raw));
  }

  // ---- Parent subscription ----------------------------------------------

  Future<List<ParentPlanOption>> fetchParentPlans() async {
    final rows = await _c.from('parent_plans').select().order('sort_order');
    return rows
        .map((r) => ParentPlanOption.fromJson(Map<String, dynamic>.from(r)))
        .toList(growable: false);
  }

  Future<ParentPlanQuote> parentPlanQuote({
    required String planId,
    int? children,
  }) async {
    final raw = await _c.rpc(
      'parent_plan_quote',
      params: {'p_plan_id': planId, 'p_children': children},
    );
    return ParentPlanQuote.fromJson(_asMap(raw));
  }

  Future<AccessState> settleParentSubscription({
    required String reference,
    required String planId,
    required int amountRwf,
    int? children,
  }) async {
    final raw = await _c.rpc(
      'settle_parent_subscription',
      params: {
        'p_reference': reference,
        'p_plan_id': planId,
        'p_amount_reported': amountRwf,
        'p_children': children,
      },
    );
    return AccessState.fromJson(_asMap(raw));
  }
}

/// Supabase is not configured on this build, so entitlement cannot be
/// resolved (or enforced) at all.
class AccessUnavailable implements Exception {
  const AccessUnavailable();
  @override
  String toString() => 'Billing needs an internet connection and Supabase setup.';
}

/// Supabase answered, but the billing objects are not there — migration 0003
/// has not been applied to this project.
class BillingSchemaMissing implements Exception {
  const BillingSchemaMissing();
  @override
  String toString() =>
      'The billing schema is not installed. Run '
      'supabase/migrations/0003_identity_and_billing.sql (then 0004).';
}
