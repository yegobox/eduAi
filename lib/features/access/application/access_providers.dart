import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/error/result.dart';
import '../../../core/storage/key_value_cache.dart';
import '../../auth/application/auth_providers.dart';
import '../data/datasources/access_remote_data_source.dart';
import '../data/repositories/access_repository_impl.dart';
import '../domain/entities/access_state.dart';
import '../domain/entities/payment_quote.dart';
import '../domain/repositories/access_repository.dart';

// ---- DI graph ------------------------------------------------------------

final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  return AccessRepositoryImpl(
    remoteSource: AccessRemoteDataSource(ref.watch(supabaseClientProvider)),
    kvCache: ref.watch(keyValueCacheProvider),
  );
});

// ---- Reads ---------------------------------------------------------------

/// The signed-in account's entitlement.
///
/// Re-resolved whenever the session changes, because signing in as a different
/// identity must never inherit the previous one's access.
final accessStateProvider = FutureProvider<AccessState>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref.watch(accessRepositoryProvider).fetchState();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The entitlement as a plain value, defaulting to "unknown" while it loads.
///
/// Screens that gate content use this rather than the `AsyncValue`: a spinner
/// where a lesson should be is worse than a brief unlocked frame, and the
/// server is the real gate anyway.
final accessSnapshotProvider = Provider<AccessState>((ref) {
  return ref.watch(accessStateProvider).valueOrNull ??
      const AccessState.unknown();
});

/// Whether the paid surface (AI Tutor, workbook checking) may be used.
///
/// Unknown counts as allowed: the state resolves in milliseconds and the
/// server rejects unentitled work regardless, so flashing a lock at every
/// cold start would punish paying users for their network latency.
final hasPaidAccessProvider = Provider<bool>((ref) {
  final access = ref.watch(accessSnapshotProvider);
  return access.status == AccessStatus.unknown || access.grantsAccess;
});

/// Whether this project charges reduced amounts for testing. Watched by the
/// billing screens so a discounted charge is never presented as a full one.
final billingTestModeProvider = FutureProvider<bool>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref.watch(accessRepositoryProvider).isTestPricingOn();
  return result.valueOrNull ?? false;
});

final parentPlansProvider = FutureProvider<List<ParentPlanOption>>((ref) async {
  final result = await ref.watch(accessRepositoryProvider).fetchParentPlans();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// What the school owes right now, priced by the server.
final schoolLicenseQuoteProvider = FutureProvider<SchoolLicenseQuote>((
  ref,
) async {
  // Re-quote after any licence change (tier switch, seat change, payment).
  ref.watch(accessStateProvider);
  final result = await ref.watch(accessRepositoryProvider).schoolLicenseQuote();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

// ---- Writes --------------------------------------------------------------

/// Licence and subscription changes. Every one of them re-reads entitlement,
/// because every one of them can change what the account is allowed to do.
class AccessActionController {
  AccessActionController(this._ref);

  final Ref _ref;

  AccessRepository get _repo => _ref.read(accessRepositoryProvider);

  /// Seats move in steps of [seatStep] on the admin screen.
  static const int seatStep = 5;

  Future<String?> selectSchoolTier(String tierId) =>
      _apply(() => _repo.selectSchoolTier(tierId));

  Future<String?> setSeatsPurchased(int seats) =>
      _apply(() => _repo.setSeatsPurchased(seats));

  Future<String?> settleSchoolLicense({
    required String reference,
    required int amountRwf,
    int? seats,
  }) => _apply(
    () => _repo.settleSchoolLicense(
      reference: reference,
      amountRwf: amountRwf,
      seats: seats,
    ),
  );

  Future<String?> settleParentSubscription({
    required String reference,
    required String planId,
    required int amountRwf,
    int? children,
  }) => _apply(
    () => _repo.settleParentSubscription(
      reference: reference,
      planId: planId,
      amountRwf: amountRwf,
      children: children,
    ),
  );

  /// Runs [action] and refreshes entitlement. Returns null on success, or the
  /// message to show the user — the RPCs phrase their own errors for display.
  ///
  /// Entitlement is invalidated either way: a failed seat change still leaves
  /// the screen showing whatever the server actually holds.
  Future<String?> _apply(Future<Result<AccessState>> Function() action) async {
    final result = await action();
    _ref.invalidate(accessStateProvider);
    return result.failureOrNull?.message;
  }
}

final accessActionControllerProvider = Provider<AccessActionController>(
  AccessActionController.new,
);
