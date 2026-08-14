import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_cache.dart';
import '../../lessons/application/lessons_providers.dart';
import '../domain/entities/mastery_view.dart';
import 'progress_providers.dart';

/// The Progress screen's derived view: mastery rings, the 7-day streak row and
/// REB exam readiness.
final masteryViewProvider = Provider<AsyncValue<MasteryView>>((ref) {
  final lessons = ref.watch(lessonsCatalogProvider).valueOrNull ?? const [];
  return ref
      .watch(progressSummaryProvider)
      .whenData(
        (summary) => MasteryView.from(
          summary,
          completedLessons: lessons.where((l) => l.completed).length,
          totalLessons: lessons.length,
        ),
      );
});

/// Whether the student shares their weekly report with a parent.
///
/// One flag, owned by the student. The Parent Reports screen reads it; there
/// is deliberately no parent-side override — the learner controls what a
/// parent sees.
class ProgressSharingController extends AsyncNotifier<bool> {
  static const _cacheKey = 'progress_share_with_parent';

  @override
  Future<bool> build() async {
    final raw = await ref.read(keyValueCacheProvider).getJson(_cacheKey);
    // Defaults to on: schools buy EduAI partly for the parent loop, and the
    // report shows trends, never individual mistakes.
    return raw is bool ? raw : true;
  }

  Future<void> setShared(bool shared) async {
    state = AsyncData(shared);
    await ref.read(keyValueCacheProvider).setJson(_cacheKey, shared);
  }
}

final progressSharingProvider =
    AsyncNotifierProvider<ProgressSharingController, bool>(
      ProgressSharingController.new,
    );
