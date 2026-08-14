import '../../../../core/error/result.dart';
import '../entities/access_state.dart';
import '../entities/payment_quote.dart';

/// Entitlement and the purchases that grant it.
///
/// One contract for both revenue lines — a school buying seats and a parent
/// subscribing directly — because both answer the same question: may this
/// account use the paid surface, and until when?
abstract interface class AccessRepository {
  /// The caller's entitlement. [preferCache] returns the last known state
  /// without a round trip, for offline starts.
  Future<Result<AccessState>> fetchState({bool preferCache = false});

  /// True when the server is quoting reduced amounts for testing. False on a
  /// build with no backend, where no charge can happen at all.
  Future<Result<bool>> isTestPricingOn();

  // ---- School licence (school-admin identities) --------------------------

  /// The server-priced amount the school owes. [seats] overrides the stored
  /// seat count for a "what would N seats cost?" preview.
  Future<Result<SchoolLicenseQuote>> schoolLicenseQuote({int? seats});

  /// Chooses a tier. Re-prices the licence; does not itself pay for it.
  Future<Result<AccessState>> selectSchoolTier(String tierId);

  /// Sets how many seats the school is buying.
  Future<Result<AccessState>> setSeatsPurchased(int seats);

  /// Records a settled Mobile Money payment against the licence and activates
  /// it. Idempotent per [reference] — replaying one never grants two periods.
  Future<Result<AccessState>> settleSchoolLicense({
    required String reference,
    required int amountRwf,
    int? seats,
  });

  // ---- Parent subscription (parents with no school) ----------------------

  /// The direct-to-parent price list.
  Future<Result<List<ParentPlanOption>>> fetchParentPlans();

  Future<Result<ParentPlanQuote>> parentPlanQuote({
    required String planId,
    int? children,
  });

  /// Same idempotency guarantee as [settleSchoolLicense].
  Future<Result<AccessState>> settleParentSubscription({
    required String reference,
    required String planId,
    required int amountRwf,
    int? children,
  });
}
