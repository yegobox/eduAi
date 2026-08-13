import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/learning_event.dart';

/// All Supabase access for the progress feature. Throws on failure; the
/// repository maps exceptions to `Failure`s. When [_client] is null (Supabase
/// not configured) every method throws [ProgressUnavailable].
class ProgressRemoteDataSource {
  ProgressRemoteDataSource(this._client);

  final SupabaseClient? _client;

  /// How far back the summary looks. A year covers every streak and topic
  /// figure the UI shows without unbounded growth in the response.
  static const historyWindow = Duration(days: 365);

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const ProgressUnavailable();
    return c;
  }

  String get _uid {
    final id = _client?.auth.currentUser?.id;
    if (id == null) throw const ProgressNotSignedIn();
    return id;
  }

  Future<List<LearningEvent>> fetchEvents() async {
    final since = DateTime.now().toUtc().subtract(historyWindow);
    final rows = await _c
        .from('learning_events')
        .select()
        .eq('user_id', _uid)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false);
    return rows.map((r) => LearningEvent.fromJson(r)).toList();
  }

  Future<void> insertEvent({
    required LearningEventKind kind,
    String? subject,
    String? level,
    String? topic,
    bool? isCorrect,
  }) async {
    await _c.from('learning_events').insert({
      'user_id': _uid,
      'kind': kind.name,
      'subject': subject,
      'level': level,
      'topic': topic,
      // The table's check constraint requires null for non-check kinds.
      'is_correct': kind == LearningEventKind.check ? isCorrect : null,
    });
  }
}

/// Supabase not configured on this build.
class ProgressUnavailable implements Exception {
  const ProgressUnavailable();
  @override
  String toString() => 'Progress needs an internet connection and Supabase setup.';
}

/// No authenticated user (or offline-only session) for a server action.
class ProgressNotSignedIn implements Exception {
  const ProgressNotSignedIn();
  @override
  String toString() => 'Sign in online to track your progress.';
}
