import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/billing_entities.dart';

/// Supabase reads for the school-admin billing screens.
class BillingRemoteDataSource {
  BillingRemoteDataSource(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const BillingUnavailable();
    return c;
  }

  Future<List<PlanTier>> fetchTiers() async {
    final rows = await _c.from('plan_tiers').select().order('sort_order');
    return rows
        .map((r) => PlanTier.fromJson(Map<String, dynamic>.from(r)))
        .toList(growable: false);
  }

  /// The licence payments for the caller's school. RLS on `payments` limits
  /// this to rows the caller paid or rows belonging to a school they own.
  Future<List<Invoice>> fetchLicensePayments() async {
    final rows = await _c
        .from('payments')
        .select()
        .eq('purpose', 'school_license')
        .order('created_at', ascending: false);
    return rows
        .map((r) => Invoice.fromJson(Map<String, dynamic>.from(r)))
        .toList(growable: false);
  }
}

/// Supabase is not configured on this build.
class BillingUnavailable implements Exception {
  const BillingUnavailable();
  @override
  String toString() => 'Billing needs an internet connection and Supabase setup.';
}
