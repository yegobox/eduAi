import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/key_value_cache.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/entities/progress_summary.dart';
import '../../domain/repositories/progress_repository.dart';
import '../datasources/progress_remote_data_source.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl({
    required ProgressRemoteDataSource remoteSource,
    required KeyValueCache kvCache,
  })  : _remote = remoteSource,
        _cache = kvCache;

  final ProgressRemoteDataSource _remote;
  final KeyValueCache _cache;

  static const _log = AppLogger('ProgressRepo');
  static const _eventsKey = 'cache.learning_events.v1';

  /// Longest topic label derived from a question. Long enough to stay
  /// recognisable in the topic list, short enough not to be a transcript.
  static const _maxDerivedTopicLength = 60;

  // ---- Reads -------------------------------------------------------------

  @override
  Future<Result<ProgressSummary>> fetchSummary({bool preferCache = false}) async {
    if (preferCache) {
      final cached = await _readCache();
      if (cached != null) return Result.success(ProgressSummary.fromEvents(cached));
    }
    try {
      final events = await _remote.fetchEvents();
      await _writeCache(events);
      return Result.success(ProgressSummary.fromEvents(events));
    } catch (e, s) {
      _log.warn('fetchSummary failed: $e');
      final cached = await _readCache();
      if (cached != null) return Result.success(ProgressSummary.fromEvents(cached));
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Writes ------------------------------------------------------------

  @override
  Future<Result<void>> recordQuestion({
    required String question,
    String? subject,
    String? level,
  }) {
    return _record(
      kind: LearningEventKind.question,
      question: question,
      subject: subject,
      level: level,
    );
  }

  @override
  Future<Result<void>> recordCheck({
    required bool correct,
    required String question,
    String? subject,
    String? level,
  }) {
    return _record(
      kind: LearningEventKind.check,
      question: question,
      subject: subject,
      level: level,
      isCorrect: correct,
    );
  }

  Future<Result<void>> _record({
    required LearningEventKind kind,
    required String question,
    String? subject,
    String? level,
    bool? isCorrect,
  }) async {
    try {
      await _remote.insertEvent(
        kind: kind,
        subject: _clean(subject),
        level: _clean(level),
        topic: _topicFor(subject: subject, question: question),
        isCorrect: isCorrect,
      );
      return const Result.success(null);
    } catch (e, s) {
      // Callers treat recording as best-effort — never surfaced to the user
      // mid-conversation — so this only warns.
      _log.warn('record $kind failed: $e');
      _log.debug(s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Topic derivation --------------------------------------------------

  /// The explicit subject when the user set one, else a short normalised form
  /// of the question so topic coverage still works for unstructured chats.
  String? _topicFor({required String? subject, required String question}) {
    final explicit = _clean(subject);
    if (explicit != null) return explicit;

    final collapsed = question.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return null;
    if (collapsed.length <= _maxDerivedTopicLength) return collapsed;

    // Cut on a word boundary rather than mid-word.
    final cut = collapsed.substring(0, _maxDerivedTopicLength);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 0 ? cut.substring(0, lastSpace) : cut}…';
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  // ---- Cache helpers -----------------------------------------------------

  Future<void> _writeCache(List<LearningEvent> events) async {
    await _cache.setJson(_eventsKey, events.map((e) => e.toJson()).toList());
  }

  Future<List<LearningEvent>?> _readCache() async {
    final raw = await _cache.getJson(_eventsKey);
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => LearningEvent.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ---- Error mapping -----------------------------------------------------

  Failure _mapError(Object error) {
    if (error is ProgressUnavailable || error is ProgressNotSignedIn) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is PostgrestException) {
      return AuthFailure(error.message, cause: error);
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
