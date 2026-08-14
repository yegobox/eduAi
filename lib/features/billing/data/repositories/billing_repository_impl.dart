import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/billing_entities.dart';
import '../../domain/repositories/billing_repository.dart';
import '../datasources/billing_remote_data_source.dart';
import '../datasources/billing_seed_data_source.dart';

/// Billing reads from Supabase, falling back to the seed price list when there
/// is no backend to ask.
///
/// The payment ledger has no fallback: an empty list is the honest answer for a
/// school that has not paid, and inventing three "Paid" invoices — which is
/// what this screen used to do — tells a director their licence is settled when
/// nothing has been collected.
class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl({
    required BillingRemoteDataSource remoteSource,
    required BillingSeedDataSource seedSource,
  }) : _remote = remoteSource,
       _seed = seedSource;

  final BillingRemoteDataSource _remote;
  final BillingSeedDataSource _seed;

  static const _log = AppLogger('BillingRepo');

  @override
  Future<Result<List<PlanTier>>> fetchTiers() async {
    if (!_remote.isConfigured) return Result.success(_seed.tiers());
    try {
      final tiers = await _remote.fetchTiers();
      // An empty price list would render three blank cards; the seed copy is a
      // better answer than a broken screen.
      return Result.success(tiers.isEmpty ? _seed.tiers() : tiers);
    } catch (e, s) {
      _log.warn('fetchTiers failed, using the built-in price list: $e');
      _log.debug(s);
      return Result.success(_seed.tiers());
    }
  }

  @override
  Future<Result<List<Invoice>>> fetchInvoices() async {
    if (!_remote.isConfigured) return const Result.success([]);
    try {
      return Result.success(await _remote.fetchLicensePayments());
    } catch (e, s) {
      _log.error('fetchInvoices failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<UsageStats>> fetchUsage() async =>
      Result.success(_seed.usage());

  Failure _mapError(Object error) {
    if (error is BillingUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('failed host lookup')) {
      return NetworkFailure(cause: error);
    }
    return UnknownFailure(cause: error);
  }
}
