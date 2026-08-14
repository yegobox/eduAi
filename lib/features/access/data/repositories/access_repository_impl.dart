import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/key_value_cache.dart';
import '../../domain/entities/access_state.dart';
import '../../domain/entities/payment_quote.dart';
import '../../domain/repositories/access_repository.dart';
import '../datasources/access_remote_data_source.dart';

/// Server-decided entitlement, with a device cache so a lapsed licence still
/// locks and a paid one still opens while the plane is in the air.
///
/// Three distinct "no answer" cases, deliberately handled differently:
///
/// * **No Supabase on this build** — entitlement is unenforceable, so the app
///   opens up with `enforced: false`. Locking every screen behind a paywall
///   the build cannot satisfy would make a demo or a design review useless.
/// * **Configured but offline** — the last known state is replayed, with its
///   status recomputed against the clock so a cached "entitled" cannot
///   outlive the period it was entitled for.
/// * **Configured, online, and the call failed** — a real failure, surfaced.
class AccessRepositoryImpl implements AccessRepository {
  AccessRepositoryImpl({
    required AccessRemoteDataSource remoteSource,
    required KeyValueCache kvCache,
  }) : _remote = remoteSource,
       _cache = kvCache;

  final AccessRemoteDataSource _remote;
  final KeyValueCache _cache;

  static const _log = AppLogger('AccessRepo');
  static const _stateKey = 'cache.access_state.v1';

  /// The price list is small and changes rarely, so it is cached too — a
  /// parent should not see an empty plan list because the tunnel dropped.
  static const _plansKey = 'cache.parent_plans.v1';

  @override
  Future<Result<AccessState>> fetchState({bool preferCache = false}) async {
    if (!_remote.isConfigured) {
      return const Result.success(AccessState.unconfigured());
    }
    if (preferCache) {
      final cached = await _readCachedState();
      if (cached != null) return Result.success(cached);
    }
    try {
      final state = await _remote.fetchState();
      await _cache.setJson(_stateKey, state.toJson());
      return Result.success(state);
    } on BillingSchemaMissing catch (e) {
      // Not a transient failure and not something a retry fixes: the project is
      // missing migration 0003. Falling back to a cached state (or to "unknown",
      // which grants access) would hide a misconfiguration in which *nobody is
      // being charged* — so this is reported as its own state and shouted about.
      _log.error('$e');
      return const Result.success(AccessState.schemaMissing());
    } catch (e, s) {
      _log.warn('access_state failed: $e');
      final cached = await _readCachedState();
      if (cached != null) return Result.success(cached);
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<bool>> isTestPricingOn() async {
    if (!_remote.isConfigured) return const Result.success(false);
    try {
      return Result.success(await _remote.fetchTestMode());
    } catch (e) {
      // A project that predates 0005 has no such function. Absence of the flag
      // means normal pricing, which is the safe assumption either way.
      _log.warn('billing_test_mode unavailable: $e');
      return const Result.success(false);
    }
  }

  // ---- School licence ----------------------------------------------------

  @override
  Future<Result<SchoolLicenseQuote>> schoolLicenseQuote({int? seats}) =>
      _read(() => _remote.schoolLicenseQuote(seats: seats));

  @override
  Future<Result<AccessState>> selectSchoolTier(String tierId) =>
      _write(() => _remote.selectSchoolTier(tierId));

  @override
  Future<Result<AccessState>> setSeatsPurchased(int seats) {
    if (seats < 0) {
      return Future.value(
        const Result.failure(ValidationFailure('Seats cannot be negative.')),
      );
    }
    return _write(() => _remote.setSeatsPurchased(seats));
  }

  @override
  Future<Result<AccessState>> settleSchoolLicense({
    required String reference,
    required int amountRwf,
    int? seats,
  }) {
    if (reference.trim().isEmpty) {
      return Future.value(
        const Result.failure(
          ValidationFailure('A payment reference is required.'),
        ),
      );
    }
    return _write(
      () => _remote.settleSchoolLicense(
        reference: reference.trim(),
        amountRwf: amountRwf,
        seats: seats,
      ),
    );
  }

  // ---- Parent subscription ----------------------------------------------

  @override
  Future<Result<List<ParentPlanOption>>> fetchParentPlans() async {
    if (!_remote.isConfigured) return Result.success(_seedParentPlans);
    try {
      final plans = await _remote.fetchParentPlans();
      await _cache.setJson(
        _plansKey,
        plans
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'price_per_child_rwf': p.pricePerChildRwf,
                'period_days': p.periodDays,
                'features': p.features,
              },
            )
            .toList(),
      );
      return Result.success(plans);
    } catch (e, s) {
      _log.warn('fetchParentPlans failed: $e');
      final raw = await _cache.getJson(_plansKey);
      if (raw is List && raw.isNotEmpty) {
        return Result.success(
          raw
              .whereType<Map>()
              .map(
                (m) => ParentPlanOption.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList(growable: false),
        );
      }
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<ParentPlanQuote>> parentPlanQuote({
    required String planId,
    int? children,
  }) => _read(
    () => _remote.parentPlanQuote(planId: planId, children: children),
  );

  @override
  Future<Result<AccessState>> settleParentSubscription({
    required String reference,
    required String planId,
    required int amountRwf,
    int? children,
  }) {
    if (reference.trim().isEmpty) {
      return Future.value(
        const Result.failure(
          ValidationFailure('A payment reference is required.'),
        ),
      );
    }
    return _write(
      () => _remote.settleParentSubscription(
        reference: reference.trim(),
        planId: planId,
        amountRwf: amountRwf,
        children: children,
      ),
    );
  }

  // ---- Plumbing ----------------------------------------------------------

  Future<Result<T>> _read<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } catch (e, s) {
      _log.error('billing read failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  /// A write returns the fresh [AccessState], which is also cached so the next
  /// cold start already knows about the payment that just settled.
  Future<Result<AccessState>> _write(Future<AccessState> Function() action) async {
    try {
      final state = await action();
      await _cache.setJson(_stateKey, state.toJson());
      return Result.success(state);
    } catch (e, s) {
      _log.error('billing write failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  Future<AccessState?> _readCachedState() async {
    final raw = await _cache.getJson(_stateKey);
    if (raw is! Map) return null;
    try {
      return AccessState.fromCache(Map<String, dynamic>.from(raw));
    } catch (e) {
      _log.warn('Could not restore cached access state: $e');
      return null;
    }
  }

  /// Used only on builds with no Supabase, where the real price list is
  /// unreachable. Kept in sync with `parent_plans` in 0003.
  static const _seedParentPlans = <ParentPlanOption>[
    ParentPlanOption(
      id: 'family_monthly',
      name: 'Family — monthly',
      pricePerChildRwf: 3000,
      periodDays: 30,
      features: [
        'AI Tutor',
        'Lessons library',
        'Stylus workbook',
        'Weekly reports',
      ],
    ),
    ParentPlanOption(
      id: 'family_termly',
      name: 'Family — one term',
      pricePerChildRwf: 7500,
      periodDays: 90,
      features: [
        'Everything monthly',
        'Save 17%',
        'Covers a full school term',
      ],
    ),
  ];

  Failure _mapError(Object error) {
    if (error is AccessUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is PostgrestException) {
      // The RPCs raise plain-language exceptions ("the Growth tier covers at
      // most 800 students"), which are written to be shown as-is.
      return ValidationFailure(error.message, cause: error);
    }
    if (error is AuthException) {
      return AuthFailure(error.message, cause: error);
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
