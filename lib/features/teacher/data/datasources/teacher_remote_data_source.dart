import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/teacher_class.dart';

/// Supabase reads for the teacher shell.
///
/// Both calls are `security definer` functions rather than table queries: a
/// teacher needs aggregates over their students, not the right to read raw
/// `learning_events` rows, so the authorisation and the rollup happen together
/// on the server.
class TeacherRemoteDataSource {
  TeacherRemoteDataSource(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const TeacherUnavailable();
    return c;
  }

  Future<List<TeacherClass>> fetchClasses() async {
    final raw = await _c.rpc('teacher_classes');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => TeacherClass.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<StudentProgress>> fetchClassProgress(
    String classId, {
    int days = 30,
  }) async {
    final raw = await _c.rpc(
      'class_progress',
      params: {'p_class_id': classId, 'p_days': days},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => StudentProgress.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// Supabase is not configured on this build.
class TeacherUnavailable implements Exception {
  const TeacherUnavailable();
  @override
  String toString() =>
      'Your classes need an internet connection and Supabase setup.';
}
