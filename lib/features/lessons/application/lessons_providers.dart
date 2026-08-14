import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_cache.dart';
import '../data/datasources/lessons_seed_data_source.dart';
import '../data/repositories/lessons_repository_impl.dart';
import '../domain/entities/lesson.dart';
import '../domain/repositories/lessons_repository.dart';

// ---- DI graph ------------------------------------------------------------

final lessonsRepositoryProvider = Provider<LessonsRepository>((ref) {
  return LessonsRepositoryImpl(
    seedSource: const LessonsSeedDataSource(),
    kvCache: ref.watch(keyValueCacheProvider),
  );
});

// ---- Read providers ------------------------------------------------------

/// The whole catalog, with local download / completion state merged in.
final lessonsCatalogProvider = FutureProvider<List<Lesson>>((ref) async {
  final result = await ref.watch(lessonsRepositoryProvider).fetchCatalog();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// The grade band currently selected in the catalog's filter row.
final gradeFilterProvider = StateProvider<GradeBand>(
  (ref) => GradeBand.primary,
);

/// The catalog narrowed to the selected band.
final filteredLessonsProvider = Provider<AsyncValue<List<Lesson>>>((ref) {
  final band = ref.watch(gradeFilterProvider);
  return ref
      .watch(lessonsCatalogProvider)
      .whenData(
        (lessons) =>
            lessons.where((l) => l.band == band).toList(growable: false),
      );
});

/// A single lesson by id — used by the reader, which is deep-linkable.
final lessonByIdProvider = Provider.family<AsyncValue<Lesson?>, String>((
  ref,
  id,
) {
  return ref
      .watch(lessonsCatalogProvider)
      .whenData((lessons) => lessons.where((l) => l.id == id).firstOrNull);
});

/// Number of completed lessons — the Progress screen folds this into mastery.
final completedLessonCountProvider = Provider<int>((ref) {
  final lessons = ref.watch(lessonsCatalogProvider).valueOrNull ?? const [];
  return lessons.where((l) => l.completed).length;
});

// ---- Writes --------------------------------------------------------------

/// Download-toggle and mark-complete actions.
///
/// Both write through the repository and then refresh the catalog, so the
/// grid, the reader and Progress can never disagree about a lesson's state.
class LessonsActionController {
  LessonsActionController(this._ref);

  final Ref _ref;

  Future<bool> toggleDownload(Lesson lesson) async {
    final result = await _ref
        .read(lessonsRepositoryProvider)
        .setDownloaded(lesson.id, !lesson.downloaded);
    if (result.isSuccess) _ref.invalidate(lessonsCatalogProvider);
    return result.isSuccess;
  }

  Future<bool> markComplete(String lessonId) async {
    final result = await _ref
        .read(lessonsRepositoryProvider)
        .markComplete(lessonId);
    if (result.isSuccess) _ref.invalidate(lessonsCatalogProvider);
    return result.isSuccess;
  }
}

final lessonsActionControllerProvider = Provider<LessonsActionController>(
  LessonsActionController.new,
);
