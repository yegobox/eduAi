import 'package:collection/collection.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/key_value_cache.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/lessons_repository.dart';
import '../datasources/lessons_seed_data_source.dart';

/// Merges the bundled catalog with the device's download / completion flags.
///
/// Flags are two small id lists in [KeyValueCache] rather than a copy of each
/// lesson, so a catalog update never has to migrate user state.
class LessonsRepositoryImpl implements LessonsRepository {
  LessonsRepositoryImpl({
    required LessonsSeedDataSource seedSource,
    required KeyValueCache kvCache,
  }) : _seed = seedSource,
       _cache = kvCache;

  final LessonsSeedDataSource _seed;
  final KeyValueCache _cache;

  static const _downloadedKey = 'lessons_downloaded';
  static const _completedKey = 'lessons_completed';

  @override
  Future<Result<List<Lesson>>> fetchCatalog() async {
    try {
      final downloaded = await _readIds(_downloadedKey);
      final completed = await _readIds(_completedKey);
      final lessons = _seed
          .catalog()
          .map(
            (l) => l.copyWith(
              downloaded: downloaded.contains(l.id),
              completed: completed.contains(l.id),
            ),
          )
          .toList(growable: false);
      return Result.success(lessons);
    } catch (e) {
      return Result.failure(
        CacheFailure(
          message: 'Could not open the lesson library on this device.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Lesson>> setDownloaded(String lessonId, bool downloaded) =>
      _mutate(
        lessonId,
        key: _downloadedKey,
        add: downloaded,
        apply: (lesson, on) => lesson.copyWith(downloaded: on),
      );

  @override
  Future<Result<Lesson>> markComplete(String lessonId) => _mutate(
    lessonId,
    key: _completedKey,
    add: true,
    apply: (lesson, on) => lesson.copyWith(completed: on),
  );

  Future<Result<Lesson>> _mutate(
    String lessonId, {
    required String key,
    required bool add,
    required Lesson Function(Lesson lesson, bool on) apply,
  }) async {
    final lesson = _seed.catalog().where((l) => l.id == lessonId).firstOrNull;
    if (lesson == null) {
      return const Result.failure(
        ValidationFailure('That lesson is no longer in the library.'),
      );
    }
    try {
      final ids = await _readIds(key);
      add ? ids.add(lessonId) : ids.remove(lessonId);
      await _cache.setJson(key, ids.toList(growable: false));

      // Re-read the *other* flag so the returned lesson is fully current, not
      // just correct for the flag we happened to touch.
      final downloaded = await _readIds(_downloadedKey);
      final completed = await _readIds(_completedKey);
      final merged = lesson.copyWith(
        downloaded: downloaded.contains(lessonId),
        completed: completed.contains(lessonId),
      );
      return Result.success(apply(merged, add));
    } catch (e) {
      return Result.failure(
        CacheFailure(message: 'Could not save that on this device.', cause: e),
      );
    }
  }

  Future<Set<String>> _readIds(String key) async {
    final raw = await _cache.getJson(key);
    if (raw is! List) return <String>{};
    return raw.map((e) => e.toString()).toSet();
  }
}
