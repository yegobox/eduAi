import '../../../../core/error/result.dart';
import '../entities/parent_entities.dart';

/// Everything the parent shell reads and writes, scoped to the signed-in
/// parent account.
abstract interface class ParentRepository {
  /// Children linked to this parent.
  Future<Result<List<Child>>> fetchChildren();

  /// The class-teacher thread for [childId], oldest message first.
  Future<Result<List<ParentMessage>>> fetchMessages(String childId);

  /// Appends a parent message to the thread and returns it as stored.
  Future<Result<ParentMessage>> sendMessage({
    required String childId,
    required String text,
  });

  /// The school plan covering this parent's children — read-only to them.
  Future<Result<ParentPlan>> fetchPlan();

  /// Optional Mobile Money top-up packs.
  Future<Result<List<TopupPack>>> fetchTopupPacks();

  /// Credits [pack] after a Mobile Money payment has settled.
  ///
  /// [paymentReference] is the gateway's request-to-pay id, so a support
  /// query can always be traced back to real money.
  Future<Result<void>> creditTopup({
    required TopupPack pack,
    required String paymentReference,
  });
}
