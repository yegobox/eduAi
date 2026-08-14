import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../domain/entities/momo_payment.dart';
import '../../domain/momo_msisdn.dart';

/// HTTP client for the Mobile Money gateway.
///
/// The request and response shapes are copied from Flipper's `HttpApi`
/// (`packages/flipper_services/lib/HttpApi.dart`) because both products bill
/// through the same endpoints:
///
/// * `POST {momoApiUrl}/v2/api/payNow`
/// * `GET  {momoStatusBase}/v2/api/requesttopay/status/{reference}/{branchId}`
class MomoRemoteDataSource {
  MomoRemoteDataSource(this._client, this._config);

  final http.Client _client;
  final AppConfig _config;

  static const _timeout = Duration(seconds: 30);

  /// Where a collection is sent, and which branch it books against. Exposed so
  /// a failure can be logged with the endpoint it actually hit — "payment
  /// rejected" is useless without knowing which gateway rejected it.
  String get payNowEndpoint => '${_config.momoApiUrl}/v2/api/payNow';
  String get branchId => _config.momoBranchId;

  /// Matches an MTN reference embedded in a noisier string. The gateway has
  /// been seen echoing a reference wrapped in log formatting, and the status
  /// path only accepts the bare id.
  static final RegExp _uuid = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// Extracts the id used in the status URL path.
  static String? sanitizeReference(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final match = _uuid.firstMatch(trimmed);
    if (match != null) return match.group(0);
    return trimmed.isEmpty ? null : trimmed;
  }

  /// payNow returns the id as `paymentReference`, and older builds as
  /// `externalId`; both carry the same MTN reference.
  static String? referenceFrom(Map<String, dynamic> json) {
    final primary = sanitizeReference(json['paymentReference']?.toString());
    if (primary != null && primary.isNotEmpty) return primary;
    return sanitizeReference(json['externalId']?.toString());
  }

  Future<String> payNow({
    required String phoneNumber,
    required int amountRwf,
    required MomoPurpose purpose,
  }) async {
    if (!_config.hasMomo) throw const MomoUnavailable();
    if (amountRwf <= 0) {
      throw const MomoException('Enter an amount greater than zero.');
    }
    final partyId = MomoMsisdn.toPartyId(phoneNumber);
    if (partyId == null) {
      throw const MomoException(
        'Enter a valid MTN or Airtel number, e.g. 0788123456.',
      );
    }

    final response = await _client
        .post(
          Uri.parse('${_config.momoApiUrl}/v2/api/payNow'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'amount': amountRwf,
            'currency': 'RWF',
            'payer': {'partyIdType': 'MSISDN', 'partyId': partyId},
            'payerMessage': purpose.payerMessage,
            'payeeNote': purpose.payeeNote,
            'branchId': _config.momoBranchId,
            'paymentType': purpose.name,
            if (_config.momoBusinessId.isNotEmpty)
              'businessId': _config.momoBusinessId,
          }),
        )
        .timeout(_timeout);

    final status = response.statusCode;
    _throwForStatus(status, response.body);
    if (status != 200 && status != 202) {
      throw MomoException('Payment could not be started (HTTP $status).');
    }

    final decoded = _decodeObject(response.body);
    if (decoded == null) {
      throw const MomoException(
        'The payment gateway sent an unreadable reply.',
      );
    }
    final reference = referenceFrom(decoded);
    if (reference == null || reference.isEmpty) {
      throw const MomoException(
        'The payment started but no reference came back — check your MoMo '
        'statement before trying again.',
      );
    }
    return reference;
  }

  Future<MomoSettlement> requestToPayStatus(String reference) async {
    if (!_config.hasMomo) throw const MomoUnavailable();
    final id = sanitizeReference(reference);
    if (id == null || id.isEmpty) {
      throw const MomoException('Missing payment reference.');
    }

    final response = await _client
        .get(
          Uri.parse(
            '${_config.momoStatusBase}/v2/api/requesttopay/status/'
            '$id/${_config.momoBranchId}',
          ),
        )
        .timeout(_timeout);

    final decoded = _decodeObject(response.body);
    if (decoded == null) {
      throw const MomoException(
        'The payment gateway sent an unreadable reply.',
      );
    }
    // A non-2xx here means "no verdict yet", not "failed" — the caller keeps
    // polling until the deadline rather than telling the user it went wrong.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return MomoSettlement(
        reference: id,
        status: MomoPaymentStatus.pending,
        reason: decoded['message']?.toString(),
      );
    }
    return MomoSettlement.fromJson(id, decoded);
  }

  /// The gateway's own explanation for a refusal, when it gave one.
  ///
  /// data-connector answers every failure as `{"error": "…"}` and wraps *any*
  /// engine error into a 400 with the real cause in that field — a missing MTN
  /// credential, an amount over the configured ceiling, MTN's own rejection.
  /// Dropping it and substituting "rejected as invalid" threw away the only
  /// description of what went wrong, which is exactly what made a failed
  /// payment impossible to debug from the app.
  static String? gatewayMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final key in const ['error', 'message', 'detail', 'reason']) {
          final value = decoded[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
        return null;
      }
    } catch (_) {
      // Not JSON — a proxy or a framework-level rejection. The text itself is
      // still the most useful thing we have.
    }
    final text = body.trim();
    if (text.isEmpty) return null;
    // Keep it to one line so it fits a snackbar and a log line.
    final firstLine = text.split('\n').first.trim();
    return firstLine.length > 300 ? firstLine.substring(0, 300) : firstLine;
  }

  void _throwForStatus(int status, String body) {
    final fallback = switch (status) {
      400 => 'The payment request was rejected as invalid.',
      401 || 403 => 'This device is not authorised to take payments.',
      404 => 'The payment service could not be found.',
      409 => 'That payment has already been submitted.',
      500 ||
      502 ||
      503 ||
      504 => 'Mobile Money is unavailable right now. Please try again shortly.',
      _ => null,
    };
    if (fallback == null) return;

    // Lead with what the gateway said; keep the generic sentence only as a
    // fallback for an empty or unreadable body.
    final detail = gatewayMessage(body);
    throw MomoException(
      detail == null ? fallback : '$fallback $detail',
      statusCode: status,
      gatewayMessage: detail,
    );
  }

  Map<String, dynamic>? _decodeObject(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      // jsonDecode often yields a plain Map at runtime; always normalise.
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Mobile Money is not configured on this build.
class MomoUnavailable implements Exception {
  const MomoUnavailable();

  @override
  String toString() => 'Mobile Money payments are not set up on this app yet.';
}

/// The gateway was reached but refused or failed the request.
class MomoException implements Exception {
  const MomoException(this.message, {this.statusCode, this.gatewayMessage});

  final String message;
  final int? statusCode;

  /// Exactly what the gateway said, when it said anything. Kept separate from
  /// [message] so logs and support tickets can quote the server verbatim
  /// without the surrounding client-side wording.
  final String? gatewayMessage;

  @override
  String toString() => message;
}
