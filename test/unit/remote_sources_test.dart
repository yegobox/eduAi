import 'dart:convert';
import 'dart:typed_data';

import 'package:eduai/core/error/failure.dart';
import 'package:eduai/features/tutor/data/datasources/tutor_remote_data_source.dart';
import 'package:eduai/features/tutor/data/repositories/tutor_repository_impl.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_block.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_turn.dart';
import 'package:eduai/features/workbook/data/datasources/workbook_check_remote_data_source.dart';
import 'package:eduai/features/workbook/data/repositories/workbook_check_repository_impl.dart';
import 'package:eduai/features/workbook/domain/entities/workbook_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const base = 'http://localhost:8084';

  group('TutorRemoteDataSource', () {
    late RecordingHttpClient http;

    setUp(() => http = RecordingHttpClient());

    test('posts the question with history and parses the blocks', () async {
      http.onJson('/api/edu/tutor/chat', {
        'model_used': 'test-model',
        'blocks': [
          {'type': 'text', 'text': 'Because of scattering.'},
          {
            'type': 'followups',
            'items': ['Why is a sunset red?'],
          },
        ],
      });

      final answer = await TutorRemoteDataSource(http, base).chat(
        message: 'Why is the sky blue?',
        history: [
          {'role': 'user', 'content': 'earlier'},
        ],
        subject: 'Physics',
        level: 'O-Level',
      );

      expect(answer.modelUsed, 'test-model');
      expect(answer.blocks, hasLength(2));
      expect(answer.blocks.first, isA<TutorTextBlock>());

      final body = http.bodyOf('/api/edu/tutor/chat')!;
      expect(body['message'], 'Why is the sky blue?');
      expect(body['subject'], 'Physics');
      expect(body['level'], 'O-Level');
      expect(body['history'], hasLength(1));
    });

    test('omits blank subject and level rather than sending empties', () async {
      http.onJson('/api/edu/tutor/chat', {'blocks': []});
      await TutorRemoteDataSource(
        http,
        base,
      ).chat(message: 'hi', history: const [], subject: '  ', level: null);
      final body = http.bodyOf('/api/edu/tutor/chat')!;
      expect(body.containsKey('subject'), isFalse);
      expect(body.containsKey('level'), isFalse);
    });

    test('reports an unconfigured backend without calling out', () async {
      await expectLater(
        TutorRemoteDataSource(
          http,
          '   ',
        ).chat(message: 'hi', history: const []),
        throwsA(isA<TutorUnavailable>()),
      );
      expect(http.requests, isEmpty);
    });

    test('surfaces the server error message', () async {
      http.on(
        '/api/edu/tutor/chat',
        status: 500,
        responses: ['{"error":"model overloaded"}'],
      );
      await expectLater(
        TutorRemoteDataSource(
          http,
          base,
        ).chat(message: 'hi', history: const []),
        throwsA(
          isA<TutorApiException>()
              .having((e) => e.message, 'message', 'model overloaded')
              .having((e) => e.statusCode, 'status', 500),
        ),
      );
    });

    test('rejects a non-object body', () async {
      http.on('/api/edu/tutor/chat', responses: ['[1,2,3]']);
      await expectLater(
        TutorRemoteDataSource(
          http,
          base,
        ).chat(message: 'hi', history: const []),
        throwsA(isA<TutorApiException>()),
      );
    });

    test('an unparseable blocks field yields no blocks, not a crash', () async {
      http.onJson('/api/edu/tutor/chat', {'blocks': 'nope'});
      final answer = await TutorRemoteDataSource(
        http,
        base,
      ).chat(message: 'hi', history: const []);
      expect(answer.blocks, isEmpty);
      expect(answer.modelUsed, 'unknown');
    });
  });

  group('TutorRepositoryImpl', () {
    late RecordingHttpClient http;

    TutorRepositoryImpl repo([String url = base]) =>
        TutorRepositoryImpl(remoteSource: TutorRemoteDataSource(http, url));

    setUp(() => http = RecordingHttpClient());

    test('refuses an empty question before any network call', () async {
      final result = await repo().ask(message: '   ', history: const []);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(http.requests, isEmpty);
    });

    test('flattens the turn history for the backend', () async {
      http.onJson('/api/edu/tutor/chat', {'blocks': []});
      await repo().ask(
        message: 'and then?',
        history: const [
          TutorTurn.user('Why is the sky blue?'),
          TutorTurn.assistant(
            blocks: [TutorTextBlock('Scattering.')],
            modelUsed: 'm',
          ),
        ],
      );
      final history = http.bodyOf('/api/edu/tutor/chat')!['history'] as List;
      expect(history, hasLength(2));
      expect(history.first, {
        'role': 'user',
        'content': 'Why is the sky blue?',
      });
      expect((history[1] as Map)['role'], 'assistant');
    });

    test(
      'maps an unconfigured backend to an offline-unsupported failure',
      () async {
        final result = await repo('').ask(message: 'hi', history: const []);
        expect(result.failureOrNull, isA<OfflineUnsupportedFailure>());
      },
    );

    test(
      'maps a server error to an unknown failure with its message',
      () async {
        http.on(
          '/api/edu/tutor/chat',
          status: 503,
          responses: ['{"error":"try later"}'],
        );
        final result = await repo().ask(message: 'hi', history: const []);
        expect(result.failureOrNull, isA<UnknownFailure>());
        expect(result.failureOrNull?.message, 'try later');
      },
    );

    test('maps a transport error to a network failure', () async {
      final result = await TutorRepositoryImpl(
        remoteSource: TutorRemoteDataSource(ThrowingHttpClient(), base),
      ).ask(message: 'hi', history: const []);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('WorkbookCheckRemoteDataSource', () {
    late RecordingHttpClient http;

    setUp(() => http = RecordingHttpClient());

    final page = Uint8List.fromList(List.filled(64, 7));

    test('sends the page as base64 PNG and parses the verdict', () async {
      http.onJson('/api/edu/workbook/check', {
        'status': 'mistake',
        'verdict': 'Nice work',
        'tip': 'Check the sign.',
      });

      final feedback = await WorkbookCheckRemoteDataSource(
        http,
        base,
      ).check(page);
      expect(feedback.verdict, 'Nice work');
      expect(feedback.tip, 'Check the sign.');
      expect(feedback.status, WorkbookVerdictStatus.mistake);

      final body = http.bodyOf('/api/edu/workbook/check')!;
      expect(body['image_png_base64'], base64Encode(page));
    });

    test('treats 404 and 501 as "not deployed yet"', () async {
      for (final status in [404, 501]) {
        final client = RecordingHttpClient()
          ..on('/api/edu/workbook/check', status: status, responses: ['{}']);
        await expectLater(
          WorkbookCheckRemoteDataSource(client, base).check(page),
          throwsA(isA<WorkbookCheckUnavailable>()),
          reason: 'HTTP $status',
        );
      }
    });

    test('reports an unconfigured backend', () async {
      await expectLater(
        WorkbookCheckRemoteDataSource(http, '').check(page),
        throwsA(isA<WorkbookCheckUnavailable>()),
      );
    });

    test('surfaces other server errors', () async {
      http.on(
        '/api/edu/workbook/check',
        status: 500,
        responses: ['{"error":"vision model down"}'],
      );
      await expectLater(
        WorkbookCheckRemoteDataSource(http, base).check(page),
        throwsA(
          isA<WorkbookCheckException>().having(
            (e) => e.message,
            'message',
            'vision model down',
          ),
        ),
      );
    });

    test('rejects a non-object body', () async {
      http.on('/api/edu/workbook/check', responses: ['"just a string"']);
      await expectLater(
        WorkbookCheckRemoteDataSource(http, base).check(page),
        throwsA(isA<WorkbookCheckException>()),
      );
    });
  });

  group('WorkbookCheckRepositoryImpl', () {
    late RecordingHttpClient http;

    WorkbookCheckRepositoryImpl repo([String url = base]) =>
        WorkbookCheckRepositoryImpl(
          remoteSource: WorkbookCheckRemoteDataSource(http, url),
        );

    setUp(() => http = RecordingHttpClient());

    test('refuses an empty page', () async {
      final result = await repo().check(Uint8List(0));
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(http.requests, isEmpty);
    });

    test('returns the parsed feedback', () async {
      http.onJson('/api/edu/workbook/check', {
        'verdict': 'Looks right',
        'tip': 'Keep going.',
      });
      final result = await repo().check(Uint8List.fromList([1, 2, 3]));
      expect(result.valueOrNull?.verdict, 'Looks right');
    });

    test('maps a missing endpoint to an offline-unsupported failure', () async {
      final result = await repo('').check(Uint8List.fromList([1]));
      expect(result.failureOrNull, isA<OfflineUnsupportedFailure>());
      expect(result.failureOrNull?.message, contains('not available yet'));
    });

    test('maps a server error and a transport error apart', () async {
      http.on(
        '/api/edu/workbook/check',
        status: 500,
        responses: ['{"error":"boom"}'],
      );
      expect(
        (await repo().check(Uint8List.fromList([1]))).failureOrNull,
        isA<UnknownFailure>(),
      );

      final network = await WorkbookCheckRepositoryImpl(
        remoteSource: WorkbookCheckRemoteDataSource(ThrowingHttpClient(), base),
      ).check(Uint8List.fromList([1]));
      expect(network.failureOrNull, isA<NetworkFailure>());
    });
  });
}
