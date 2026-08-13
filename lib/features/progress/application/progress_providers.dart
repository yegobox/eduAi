import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/storage/key_value_cache.dart';
import '../../schools/application/schools_providers.dart' show isOfflineProvider;
import '../data/datasources/progress_remote_data_source.dart';
import '../data/repositories/progress_repository_impl.dart';
import '../domain/entities/progress_summary.dart';
import '../domain/repositories/progress_repository.dart';

// ---- DI graph ------------------------------------------------------------

final _progressRemoteProvider = Provider<ProgressRemoteDataSource>((ref) {
  return ProgressRemoteDataSource(ref.watch(supabaseClientProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl(
    remoteSource: ref.watch(_progressRemoteProvider),
    kvCache: ref.watch(keyValueCacheProvider),
  );
});

// ---- Read providers ------------------------------------------------------

/// The signed-in user's rolled-up progress. Falls back to the cached events
/// while offline, and is invalidated by [ProgressRecorder] after every write.
///
/// autoDispose (like the schools providers) so a sign-out can't leave one
/// user's numbers in memory for the next session — the screen refetches on
/// mount anyway.
final progressSummaryProvider =
    FutureProvider.autoDispose<ProgressSummary>((ref) async {
  final offline = ref.watch(isOfflineProvider);
  final result = await ref
      .watch(progressRepositoryProvider)
      .fetchSummary(preferCache: offline);
  return result.when(success: (v) => v, failure: (f) => throw f);
});

// ---- Recording -----------------------------------------------------------

/// Records learning events and refreshes [progressSummaryProvider].
///
/// This exists as its own object so that callers don't have to. The tutor
/// records from an `autoDispose` controller that can be torn down while the
/// insert is still in flight; invalidating through this provider's long-lived
/// ref keeps that safe.
class ProgressRecorder {
  ProgressRecorder(this._ref);

  final Ref _ref;

  Future<void> question({
    required String question,
    String? subject,
    String? level,
  }) async {
    final result = await _ref.read(progressRepositoryProvider).recordQuestion(
          question: question,
          subject: subject,
          level: level,
        );
    _refreshIfRecorded(result.isSuccess);
  }

  Future<void> check({
    required bool correct,
    required String question,
    String? subject,
    String? level,
  }) async {
    final result = await _ref.read(progressRepositoryProvider).recordCheck(
          correct: correct,
          question: question,
          subject: subject,
          level: level,
        );
    _refreshIfRecorded(result.isSuccess);
  }

  /// A failed write changes nothing server-side, so re-reading would only
  /// churn the network for the same numbers.
  void _refreshIfRecorded(bool recorded) {
    if (recorded) _ref.invalidate(progressSummaryProvider);
  }
}

final progressRecorderProvider =
    Provider<ProgressRecorder>(ProgressRecorder.new);
