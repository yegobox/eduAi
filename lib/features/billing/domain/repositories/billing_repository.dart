import '../../../../core/error/result.dart';
import '../entities/billing_entities.dart';

/// The school-admin billing surface: what can be bought, what has been paid,
/// and how the licence is being used.
///
/// Entitlement itself is not here — that lives behind `AccessRepository`, so
/// there is exactly one answer to "may this account use EduAI" rather than one
/// per screen.
abstract interface class BillingRepository {
  /// The licence price list.
  Future<Result<List<PlanTier>>> fetchTiers();

  /// The school's Mobile Money payment history, newest first.
  Future<Result<List<Invoice>>> fetchInvoices();

  Future<Result<UsageStats>> fetchUsage();
}
