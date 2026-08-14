import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/entities/workbook_feedback.dart';

/// Client for data-connector's handwriting-check endpoint,
/// `POST /api/edu/workbook/check` — see data-connector/README.md.
///
/// A build with no `dataConnectorUrl`, an instance running an older binary
/// (404), or one with no vision-capable model configured (501) all report the
/// same "not available yet" rather than an error the student can act on.
class WorkbookCheckRemoteDataSource {
  WorkbookCheckRemoteDataSource(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 45);

  Future<WorkbookFeedback> check(Uint8List pageImage) async {
    final base = _baseUrl.trim();
    if (base.isEmpty) throw const WorkbookCheckUnavailable();

    final response = await _client
        .post(
          Uri.parse('$base/api/edu/workbook/check'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'image_png_base64': base64Encode(pageImage)}),
        )
        .timeout(_timeout);

    if (response.statusCode == 404 || response.statusCode == 501) {
      throw const WorkbookCheckUnavailable();
    }

    final decoded = _decode(response.body);
    if (response.statusCode != 200) {
      throw WorkbookCheckException(
        (decoded is Map ? decoded['error']?.toString() : null) ??
            'The check failed (${response.statusCode}).',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WorkbookCheckException(
        'The checker returned an unexpected response.',
      );
    }
    return WorkbookFeedback.fromJson(decoded);
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

/// The handwriting checker is not configured / not deployed on this build.
class WorkbookCheckUnavailable implements Exception {
  const WorkbookCheckUnavailable();

  @override
  String toString() =>
      'Handwriting check is not available yet — ask the AI Tutor instead.';
}

/// The checker was reached but returned an error.
class WorkbookCheckException implements Exception {
  const WorkbookCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}
