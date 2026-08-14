import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/storage/key_value_cache.dart';
import '../../linking/application/linking_providers.dart';
import '../data/datasources/parent_seed_data_source.dart';
import '../data/repositories/parent_repository_impl.dart';
import '../domain/entities/parent_entities.dart';
import '../domain/repositories/parent_repository.dart';

// ---- DI graph ------------------------------------------------------------

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepositoryImpl(
    seedSource: const ParentSeedDataSource(),
    kvCache: ref.watch(keyValueCacheProvider),
  );
});

// ---- Reads ---------------------------------------------------------------

/// The children this parent can see.
///
/// With a backend, these are the accounts actually linked through
/// `parent_students` — so a parent who has linked nobody sees the empty state
/// and a way to fix it, rather than two invented children. Their *metrics* are
/// still zero until the per-child progress rollup exists server-side; the
/// Overview says so rather than showing blanks as if they were real.
///
/// Without a backend (design review, widget tests) the seed family stands in,
/// because there is no link table to read and an empty parent shell cannot be
/// reviewed or tested.
final parentChildrenProvider = FutureProvider<List<Child>>((ref) async {
  final hasBackend = ref.watch(supabaseClientProvider) != null;
  if (!hasBackend) {
    final result = await ref.watch(parentRepositoryProvider).fetchChildren();
    return result.when(success: (v) => v, failure: (f) => throw f);
  }
  final links = await ref.watch(familyLinksProvider.future);
  return [
    for (final link in links)
      Child(
        id: link.studentId,
        name: link.displayName ?? 'Your child',
        grade: '',
      ),
  ];
});

/// Which child the parent is looking at. Shared by Overview and Reports so
/// switching on one tab carries to the other.
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// The selected child, falling back to the first one.
final selectedChildProvider = Provider<Child?>((ref) {
  final children = ref.watch(parentChildrenProvider).valueOrNull ?? const [];
  if (children.isEmpty) return null;
  final id = ref.watch(selectedChildIdProvider);
  return children.firstWhereOrNull((c) => c.id == id) ?? children.first;
});

final parentPlanProvider = FutureProvider<ParentPlan>((ref) async {
  final result = await ref.watch(parentRepositoryProvider).fetchPlan();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

final topupPacksProvider = FutureProvider<List<TopupPack>>((ref) async {
  final result = await ref.watch(parentRepositoryProvider).fetchTopupPacks();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The class-teacher thread for the selected child.
final parentMessagesProvider = FutureProvider<List<ParentMessage>>((ref) async {
  final child = ref.watch(selectedChildProvider);
  if (child == null) return const [];
  final result = await ref
      .watch(parentRepositoryProvider)
      .fetchMessages(child.id);
  return result.when(success: (v) => v, failure: (f) => throw f);
});

// ---- Writes --------------------------------------------------------------

class ParentActionController {
  ParentActionController(this._ref);

  final Ref _ref;

  Future<bool> sendMessage(String text) async {
    final child = _ref.read(selectedChildProvider);
    if (child == null) return false;
    final result = await _ref
        .read(parentRepositoryProvider)
        .sendMessage(childId: child.id, text: text);
    if (result.isSuccess) _ref.invalidate(parentMessagesProvider);
    return result.isSuccess;
  }

  /// Called only after Mobile Money confirms settlement.
  Future<bool> creditTopup({
    required TopupPack pack,
    required String paymentReference,
  }) async {
    final result = await _ref
        .read(parentRepositoryProvider)
        .creditTopup(pack: pack, paymentReference: paymentReference);
    return result.isSuccess;
  }
}

final parentActionControllerProvider = Provider<ParentActionController>(
  ParentActionController.new,
);
