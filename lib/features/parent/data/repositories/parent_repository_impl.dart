import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/key_value_cache.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repository.dart';
import '../datasources/parent_seed_data_source.dart';

/// Parent data backed by the seed content plus anything written on this
/// device (sent messages, credited top-ups), which survives restarts.
class ParentRepositoryImpl implements ParentRepository {
  ParentRepositoryImpl({
    required ParentSeedDataSource seedSource,
    required KeyValueCache kvCache,
  }) : _seed = seedSource,
       _cache = kvCache;

  final ParentSeedDataSource _seed;
  final KeyValueCache _cache;

  static String _threadKey(String childId) => 'parent_thread_$childId';
  static const _creditsKey = 'parent_topup_credits';

  @override
  Future<Result<List<Child>>> fetchChildren() async =>
      Result.success(_seed.children());

  @override
  Future<Result<List<ParentMessage>>> fetchMessages(String childId) async {
    try {
      final sent = await _readSent(childId);
      final thread = [..._seed.messages(childId), ...sent]
        ..sort((a, b) => a.at.compareTo(b.at));
      return Result.success(thread);
    } catch (e) {
      return Result.failure(CacheFailure(cause: e));
    }
  }

  @override
  Future<Result<ParentMessage>> sendMessage({
    required String childId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(ValidationFailure('Write a message first.'));
    }
    final now = DateTime.now();
    final message = ParentMessage(
      id: 'sent-${now.microsecondsSinceEpoch}',
      from: 'You',
      text: trimmed,
      at: now,
      fromParent: true,
    );
    try {
      final sent = await _readSent(childId);
      await _cache.setJson(_threadKey(childId), [
        for (final m in [...sent, message])
          {'id': m.id, 'text': m.text, 'at': m.at.toIso8601String()},
      ]);
      return Result.success(message);
    } catch (e) {
      return Result.failure(CacheFailure(cause: e));
    }
  }

  @override
  Future<Result<ParentPlan>> fetchPlan() async => Result.success(_seed.plan());

  @override
  Future<Result<List<TopupPack>>> fetchTopupPacks() async =>
      Result.success(_seed.topups());

  @override
  Future<Result<void>> creditTopup({
    required TopupPack pack,
    required String paymentReference,
  }) async {
    if (paymentReference.trim().isEmpty) {
      // Refuse to credit sessions without a gateway reference — that is the
      // only proof money actually moved.
      return const Result.failure(
        ValidationFailure('Missing payment reference.'),
      );
    }
    try {
      final raw = await _cache.getJson(_creditsKey);
      final credits = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      // Idempotent: the gateway can be polled twice for the same reference.
      final already = credits.any(
        (c) => c is Map && c['reference'] == paymentReference,
      );
      if (already) return const Result.success(null);

      credits.add({
        'reference': paymentReference,
        'pack': pack.id,
        'sessions': pack.sessions,
        'amount_rwf': pack.priceRwf,
        'at': DateTime.now().toIso8601String(),
      });
      await _cache.setJson(_creditsKey, credits);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(CacheFailure(cause: e));
    }
  }

  Future<List<ParentMessage>> _readSent(String childId) async {
    final raw = await _cache.getJson(_threadKey(childId));
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) {
          return ParentMessage(
            id: m['id']?.toString() ?? '',
            from: 'You',
            text: m['text']?.toString() ?? '',
            at: DateTime.tryParse(m['at']?.toString() ?? '') ?? DateTime.now(),
            fromParent: true,
          );
        })
        .toList(growable: false);
  }
}
