import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../access/application/access_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/datasources/billing_remote_data_source.dart';
import '../data/datasources/billing_seed_data_source.dart';
import '../data/repositories/billing_repository_impl.dart';
import '../domain/entities/billing_entities.dart';
import '../domain/repositories/billing_repository.dart';

// ---- DI graph ------------------------------------------------------------

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepositoryImpl(
    remoteSource: BillingRemoteDataSource(ref.watch(supabaseClientProvider)),
    seedSource: const BillingSeedDataSource(),
  );
});

// ---- Reads ---------------------------------------------------------------

final planTiersProvider = FutureProvider<List<PlanTier>>((ref) async {
  final result = await ref.watch(billingRepositoryProvider).fetchTiers();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The tier the school is currently on, matched against the price list.
final currentTierProvider = Provider<PlanTier?>((ref) {
  final tierId = ref.watch(accessSnapshotProvider).tierId;
  if (tierId == null) return null;
  final tiers = ref.watch(planTiersProvider).valueOrNull ?? const [];
  for (final tier in tiers) {
    if (tier.id == tierId) return tier;
  }
  return null;
});

/// The payment ledger. Re-read after a settlement so a fresh payment shows up
/// on the Invoices tab without a restart.
final invoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  ref.watch(authSessionStreamProvider);
  ref.watch(accessStateProvider);
  final result = await ref.watch(billingRepositoryProvider).fetchInvoices();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

final usageStatsProvider = FutureProvider<UsageStats>((ref) async {
  final result = await ref.watch(billingRepositoryProvider).fetchUsage();
  return result.when(success: (v) => v, failure: (f) => throw f);
});
