import '../../../../core/error/result.dart';
import '../entities/momo_payment.dart';

/// Mobile Money collection, against the same gateway Flipper uses.
///
/// Two steps, exactly as the gateway models it: `payNow` pushes a PIN prompt
/// to the payer's handset and returns a reference; the reference is then
/// polled until MTN reports a terminal status.
abstract interface class PaymentsRepository {
  /// Pushes a request-to-pay to [phoneNumber] and returns its reference.
  Future<Result<String>> initiate({
    required String phoneNumber,
    required int amountRwf,
    required MomoPurpose purpose,
  });

  /// One status read for [reference].
  Future<Result<MomoSettlement>> fetchStatus(String reference);
}
