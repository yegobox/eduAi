import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/datasources/teacher_remote_data_source.dart';
import '../data/repositories/teacher_repository_impl.dart';
import '../domain/entities/teacher_class.dart';
import '../domain/repositories/teacher_repository.dart';

// ---- DI graph ------------------------------------------------------------

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepositoryImpl(
    remoteSource: TeacherRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

// ---- Reads ---------------------------------------------------------------

final teacherClassesProvider = FutureProvider<List<TeacherClass>>((ref) async {
  ref.watch(authSessionStreamProvider);
  final result = await ref.watch(teacherRepositoryProvider).fetchClasses();
  return result.when(success: (v) => v, failure: (f) => throw f);
});

/// Per-student activity for one class.
final classProgressProvider = FutureProvider.family<List<StudentProgress>, String>(
  (ref, classId) async {
    final result = await ref
        .watch(teacherRepositoryProvider)
        .fetchClassProgress(classId);
    return result.when(success: (v) => v, failure: (f) => throw f);
  },
);

/// Everyone across every class the teacher runs, worst first.
///
/// Sorted by [StudentProgress.attentionRank] so the answer to "who do I help
/// on Monday" is the top of the list rather than something to scroll for.
final teacherAttentionListProvider =
    FutureProvider<List<({TeacherClass klass, StudentProgress student})>>((
  ref,
) async {
  final classes = await ref.watch(teacherClassesProvider.future);
  final rows = <({TeacherClass klass, StudentProgress student})>[];
  for (final klass in classes) {
    final students = await ref.watch(classProgressProvider(klass.id).future);
    for (final student in students) {
      rows.add((klass: klass, student: student));
    }
  }
  rows.sort((a, b) {
    final byRank = a.student.attentionRank.compareTo(b.student.attentionRank);
    if (byRank != 0) return byRank;
    return a.student.studentName.compareTo(b.student.studentName);
  });
  return rows;
});
