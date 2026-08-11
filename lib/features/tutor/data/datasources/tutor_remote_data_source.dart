import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/tutor_block.dart';
import '../../domain/repositories/tutor_repository.dart';

/// All HTTP access for the tutor feature. Throws on failure; the repository
/// maps exceptions to `Failure`s. Talks to data-connector's
/// `POST /api/edu/tutor/chat` — see data-connector/README.md.
class TutorRemoteDataSource {
  TutorRemoteDataSource(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 30);

  Future<TutorAnswer> chat({
    required String message,
    required List<Map<String, String>> history,
    String? subject,
    String? level,
  }) async {
    final base = _baseUrl.trim();
    if (base.isEmpty) throw const TutorUnavailable();

    final uri = Uri.parse('$base/api/edu/tutor/chat');
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'history': history,
            if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
            if (level != null && level.trim().isNotEmpty) 'level': level.trim(),
          }),
        )
        .timeout(_timeout);

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['error']?.toString() : null;
      throw TutorApiException(
        message ?? 'Tutor request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const TutorApiException('Tutor returned an unexpected response.');
    }

    final blocksJson = decoded['blocks'];
    final blocks = blocksJson is List
        ? blocksJson
            .whereType<Map>()
            .map((b) => TutorBlock.fromJson(Map<String, dynamic>.from(b)))
            .toList()
        : <TutorBlock>[];

    return TutorAnswer(
      blocks: blocks,
      modelUsed: decoded['model_used'] as String? ?? 'unknown',
    );
  }

  Object? _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

/// data-connector URL not configured on this build.
class TutorUnavailable implements Exception {
  const TutorUnavailable();
  @override
  String toString() => 'The AI tutor needs a configured backend and internet.';
}

/// The tutor backend reached but returned an error.
class TutorApiException implements Exception {
  const TutorApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
