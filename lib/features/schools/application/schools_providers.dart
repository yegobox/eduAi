import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/key_value_cache.dart';
import '../../auth/application/auth_controller.dart';
import '../data/datasources/schools_remote_data_source.dart';
import '../data/repositories/schools_repository_impl.dart';
import '../domain/entities/membership.dart';
import '../domain/entities/school.dart';
import '../domain/entities/school_class.dart';
import '../domain/repositories/schools_repository.dart';

// ---- DI graph ------------------------------------------------------------

final _schoolsRemoteProvider = Provider<SchoolsRemoteDataSource>((ref) {
  return SchoolsRemoteDataSource(ref.watch(supabaseClientProvider));
});

final schoolsRepositoryProvider = Provider<SchoolsRepository>((ref) {
  return SchoolsRepositoryImpl(
    remoteSource: ref.watch(_schoolsRemoteProvider),
    kvCache: ref.watch(keyValueCacheProvider),
  );
});

/// True when we should read from cache: no network, or an offline-only session.
final isOfflineProvider = Provider<bool>((ref) {
  final net = ref.watch(networkStatusProvider).valueOrNull;
  final session = ref.watch(authControllerProvider).session;
  return net == NetworkStatus.offline || (session?.isOffline ?? false);
});

// ---- Read providers ------------------------------------------------------

/// The public catalog. Falls back to the cached list while offline.
final schoolsListProvider = FutureProvider.autoDispose<List<School>>((ref) async {
  final offline = ref.watch(isOfflineProvider);
  final result =
      await ref.watch(schoolsRepositoryProvider).fetchSchools(preferCache: offline);
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// Classes for a given school id.
final classesProvider = FutureProvider.autoDispose
    .family<List<SchoolClass>, String>((ref, schoolId) async {
  final result =
      await ref.watch(schoolsRepositoryProvider).fetchClasses(schoolId);
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The signed-in user's memberships. Falls back to cache while offline.
final myMembershipsProvider =
    FutureProvider.autoDispose<List<Membership>>((ref) async {
  final offline = ref.watch(isOfflineProvider);
  final result = await ref
      .watch(schoolsRepositoryProvider)
      .fetchMyMemberships(preferCache: offline);
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// Convenience: the set of school ids the user already belongs to (for the UI
/// to show "Joined" instead of a join button).
final joinedSchoolIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const [];
  return memberships.map((m) => m.schoolId).toSet();
});
