import 'package:eduai/core/config/app_config.dart';
import 'package:eduai/core/error/failure.dart';
import 'package:eduai/features/payments/application/momo_payment_controller.dart';
import 'package:eduai/features/payments/data/datasources/momo_remote_data_source.dart';
import 'package:eduai/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:eduai/features/payments/domain/entities/momo_payment.dart';
import 'package:eduai/features/payments/domain/momo_msisdn.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// A build with no Mobile Money credentials wired in.
const unconfiguredMomo = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  enablePhoneAuth: true,
  flavor: 'test',
  dataConnectorUrl: '',
);

void main() {
  group('MomoMsisdn', () {
    test('accepts every shape a Rwandan number is typed in', () {
      for (final input in [
        '0788123456',
        '788123456',
        '+250788123456',
        '250788123456',
        '+250 788 123 456',
        '078-812-3456',
      ]) {
        expect(MomoMsisdn.isValid(input), isTrue, reason: input);
        expect(MomoMsisdn.toPartyId(input), '250788123456', reason: input);
        expect(MomoMsisdn.toLocal(input), '0788123456', reason: input);
      }
    });

    test('accepts MTN and Airtel prefixes only', () {
      for (final prefix in ['72', '73', '78', '79']) {
        expect(MomoMsisdn.isValid('0${prefix}1234567'), isTrue, reason: prefix);
      }
      // 70 / 71 are not mobile prefixes in Rwanda.
      expect(MomoMsisdn.isValid('0701234567'), isFalse);
      expect(MomoMsisdn.isValid('0711234567'), isFalse);
    });

    test('rejects wrong lengths, empties and non-numbers', () {
      expect(MomoMsisdn.isValid(''), isFalse);
      expect(MomoMsisdn.isValid('   '), isFalse);
      expect(MomoMsisdn.isValid('078812345'), isFalse); // one digit short
      expect(MomoMsisdn.isValid('07881234567'), isFalse); // one too many
      expect(MomoMsisdn.isValid('not a phone'), isFalse);
      expect(MomoMsisdn.toPartyId('078812345'), isNull);
      expect(MomoMsisdn.toLocal('abc'), '');
    });

    test('strips the fullwidth plus some keyboards emit', () {
      // U+FF0B is invisible in a text field but breaks the gateway.
      expect(MomoMsisdn.normalise('＋250788123456'), '250788123456');
      expect(MomoMsisdn.isValid('＋250788123456'), isTrue);
    });
  });

  group('MomoRemoteDataSource', () {
    late RecordingHttpClient http;

    setUp(() => http = RecordingHttpClient());

    MomoRemoteDataSource source() => MomoRemoteDataSource(http, testConfig);

    test(
      'posts the gateway payload Flipper sends and returns the reference',
      () async {
        http.onJson('/v2/api/payNow', {'paymentReference': 'abc-123'});

        final reference = await source().payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        );

        expect(reference, 'abc-123');
        final body = http.bodyOf('/v2/api/payNow')!;
        expect(body['amount'], 500);
        expect(body['currency'], 'RWF');
        expect(body['payer'], {
          'partyIdType': 'MSISDN',
          'partyId': '250788123456',
        });
        expect(body['branchId'], testConfig.momoBranchId);
        expect(body['businessId'], testConfig.momoBusinessId);
        expect(body['payerMessage'], MomoPurpose.tutorTopUp.payerMessage);
      },
    );

    test('accepts HTTP 202 and falls back to externalId', () async {
      http.on(
        '/v2/api/payNow',
        status: 202,
        responses: ['{"externalId":"ext-9"}'],
      );
      expect(
        await source().payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        'ext-9',
      );
    });

    test('digs the reference out of a noisier value', () {
      const noisy = '[32m 7bd1f0a2-1e2b-4c3d-9f10-aabbccddeeff [0m';
      expect(
        MomoRemoteDataSource.sanitizeReference(noisy),
        '7bd1f0a2-1e2b-4c3d-9f10-aabbccddeeff',
      );
      expect(MomoRemoteDataSource.sanitizeReference('plain-id'), 'plain-id');
      expect(MomoRemoteDataSource.sanitizeReference(null), isNull);
      expect(MomoRemoteDataSource.sanitizeReference('   '), isNull);
    });

    test('prefers paymentReference over externalId', () {
      expect(
        MomoRemoteDataSource.referenceFrom({
          'paymentReference': 'primary',
          'externalId': 'secondary',
        }),
        'primary',
      );
      expect(
        MomoRemoteDataSource.referenceFrom({'externalId': 'secondary'}),
        'secondary',
      );
      expect(MomoRemoteDataSource.referenceFrom({}), isNull);
    });

    test('refuses to call the gateway with a bad number or amount', () async {
      await expectLater(
        source().payNow(
          phoneNumber: '123',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(isA<MomoException>()),
      );
      await expectLater(
        source().payNow(
          phoneNumber: '0788123456',
          amountRwf: 0,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(isA<MomoException>()),
      );
      // Nothing left the device.
      expect(http.requests, isEmpty);
    });

    test('reports "not set up" when MoMo is unconfigured', () async {
      final s = MomoRemoteDataSource(http, unconfiguredMomo);
      await expectLater(
        s.payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(isA<MomoUnavailable>()),
      );
      await expectLater(
        s.requestToPayStatus('ref'),
        throwsA(isA<MomoUnavailable>()),
      );
    });

    test('maps gateway HTTP errors to readable messages', () async {
      for (final entry in {
        400: 'rejected as invalid',
        401: 'not authorised',
        409: 'already been submitted',
        503: 'unavailable right now',
      }.entries) {
        final client = RecordingHttpClient()
          ..on('/v2/api/payNow', status: entry.key, responses: ['{}']);
        await expectLater(
          MomoRemoteDataSource(client, testConfig).payNow(
            phoneNumber: '0788123456',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          ),
          throwsA(
            isA<MomoException>().having(
              (e) => e.message,
              'message',
              contains(entry.value),
            ),
          ),
          reason: 'HTTP ${entry.key}',
        );
      }
    });

    test('throws when the gateway accepts but sends no reference', () async {
      http.onJson('/v2/api/payNow', {'status': 'ok'});
      await expectLater(
        source().payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(
          isA<MomoException>().having(
            (e) => e.message,
            'message',
            contains('no reference'),
          ),
        ),
      );
    });

    test('throws on an unreadable body', () async {
      http.on('/v2/api/payNow', responses: ['not json at all']);
      await expectLater(
        source().payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(isA<MomoException>()),
      );
    });

    test('parses a settled request-to-pay', () async {
      http.onJson('/requesttopay/status/', {
        'status': 'SUCCESSFUL',
        'financialTransactionId': 'fin-77',
        'externalId': 'ext-77',
        'amount': '500',
      });

      final settlement = await source().requestToPayStatus('ref-1');
      expect(settlement.isSuccessful, isTrue);
      expect(settlement.financialTransactionId, 'fin-77');
      expect(settlement.settledAmountRwf, 500);
      // Branch id must match the payNow call or MTN 404s.
      expect(
        http.requests.single.url.toString(),
        contains('/requesttopay/status/ref-1/${testConfig.momoBranchId}'),
      );
    });

    test(
      'treats a non-2xx status read as "no verdict yet", not a failure',
      () async {
        http.on(
          '/requesttopay/status/',
          status: 500,
          responses: ['{"message":"gateway busy"}'],
        );
        final settlement = await source().requestToPayStatus('ref-1');
        expect(settlement.status, MomoPaymentStatus.pending);
        expect(settlement.reason, 'gateway busy');
      },
    );

    test('rejects an empty reference', () async {
      await expectLater(
        source().requestToPayStatus('   '),
        throwsA(isA<MomoException>()),
      );
    });
  });

  group('MomoPaymentStatus.fromWire', () {
    test('maps MTN verdicts, defaulting unknown values to pending', () {
      expect(
        MomoPaymentStatus.fromWire('SUCCESSFUL'),
        MomoPaymentStatus.successful,
      );
      expect(
        MomoPaymentStatus.fromWire('successful'),
        MomoPaymentStatus.successful,
      );
      for (final failed in ['FAILED', 'REJECTED', 'TIMEOUT', 'EXPIRED']) {
        expect(
          MomoPaymentStatus.fromWire(failed),
          MomoPaymentStatus.failed,
          reason: failed,
        );
      }
      // An unfamiliar string must never be read as "the money vanished".
      expect(MomoPaymentStatus.fromWire('WEIRD'), MomoPaymentStatus.pending);
      expect(MomoPaymentStatus.fromWire(null), MomoPaymentStatus.pending);
    });

    test('parses a numeric or string amount', () {
      expect(
        MomoSettlement.fromJson('r', {'amount': 1200}).settledAmountRwf,
        1200,
      );
      expect(
        MomoSettlement.fromJson('r', {'amount': '1200'}).settledAmountRwf,
        1200,
      );
      expect(MomoSettlement.fromJson('r', const {}).settledAmountRwf, isNull);
    });
  });

  group('A refused payment says why', () {
    // data-connector wraps every engine failure as 400 {"error": "..."} — a
    // missing MTN credential, an amount over the ceiling, MTN's own rejection.
    // Swallowing that text is what made a failed payment undebuggable.
    test('the gateway\'s own words reach the message', () async {
      final client = RecordingHttpClient()
        ..on(
          '/v2/api/payNow',
          status: 400,
          responses: [
            '{"error":"no MTN collection branch: set MTN_COLLECTION_BRANCH_ID"}',
          ],
        );
      await expectLater(
        MomoRemoteDataSource(client, testConfig).payNow(
          phoneNumber: '0788123456',
          amountRwf: 7500,
          purpose: MomoPurpose.schoolLicense,
        ),
        throwsA(
          isA<MomoException>()
              .having(
                (e) => e.message,
                'message',
                contains('set MTN_COLLECTION_BRANCH_ID'),
              )
              .having(
                (e) => e.gatewayMessage,
                'gatewayMessage',
                'no MTN collection branch: set MTN_COLLECTION_BRANCH_ID',
              )
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('reads the other shapes a gateway might use', () {
      expect(
        MomoRemoteDataSource.gatewayMessage('{"message":"amount too large"}'),
        'amount too large',
      );
      expect(
        MomoRemoteDataSource.gatewayMessage('{"detail":"bad branch"}'),
        'bad branch',
      );
      // A proxy or framework rejection is not JSON, and its text is still the
      // most useful thing available.
      expect(
        MomoRemoteDataSource.gatewayMessage('Failed to deserialize the JSON body'),
        'Failed to deserialize the JSON body',
      );
      expect(MomoRemoteDataSource.gatewayMessage(''), isNull);
      expect(MomoRemoteDataSource.gatewayMessage('{}'), isNull);
    });

    test('a long body is trimmed to something loggable', () {
      final long = 'x' * 900;
      expect(MomoRemoteDataSource.gatewayMessage(long)!.length, 300);
    });

    test('falls back to the generic sentence when the body says nothing', () async {
      final client = RecordingHttpClient()
        ..on('/v2/api/payNow', status: 400, responses: ['{}']);
      await expectLater(
        MomoRemoteDataSource(client, testConfig).payNow(
          phoneNumber: '0788123456',
          amountRwf: 500,
          purpose: MomoPurpose.tutorTopUp,
        ),
        throwsA(
          isA<MomoException>()
              .having((e) => e.message, 'message', contains('rejected as invalid'))
              .having((e) => e.gatewayMessage, 'gatewayMessage', isNull),
        ),
      );
    });

    test('a payer number is never logged in full', () {
      // Masked, not omitted: a failed payment still has to be traceable to the
      // person who rang about it.
      expect(MomoMsisdn.masked('0788123456'), '…456');
      expect(MomoMsisdn.masked('+250788123456'), '…456');
      expect(MomoMsisdn.masked(''), '…');
      expect(MomoMsisdn.masked('0788123456'), isNot(contains('788123')));
    });
  });

  group('PaymentsRepositoryImpl', () {
    test('classifies a bad request as the caller\'s problem', () async {
      final client = RecordingHttpClient()
        ..on('/v2/api/payNow', status: 400, responses: ['{}']);
      final repo = PaymentsRepositoryImpl(
        remoteSource: MomoRemoteDataSource(client, testConfig),
      );
      final result = await repo.initiate(
        phoneNumber: '0788123456',
        amountRwf: 500,
        purpose: MomoPurpose.tutorTopUp,
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('classifies a gateway fault as not-the-user\'s-fault', () async {
      final client = RecordingHttpClient()
        ..on('/v2/api/payNow', status: 503, responses: ['{}']);
      final repo = PaymentsRepositoryImpl(
        remoteSource: MomoRemoteDataSource(client, testConfig),
      );
      final result = await repo.initiate(
        phoneNumber: '0788123456',
        amountRwf: 500,
        purpose: MomoPurpose.tutorTopUp,
      );
      expect(result.failureOrNull, isA<UnknownFailure>());
    });

    test('surfaces an unconfigured gateway as unsupported-offline', () async {
      final repo = PaymentsRepositoryImpl(
        remoteSource: MomoRemoteDataSource(
          RecordingHttpClient(),
          unconfiguredMomo,
        ),
      );
      final result = await repo.initiate(
        phoneNumber: '0788123456',
        amountRwf: 500,
        purpose: MomoPurpose.tutorTopUp,
      );
      expect(result.failureOrNull, isA<OfflineUnsupportedFailure>());
      expect(
        (await repo.fetchStatus('ref')).failureOrNull,
        isA<OfflineUnsupportedFailure>(),
      );
    });

    test('returns a parsed settlement on the happy path', () async {
      final client = RecordingHttpClient()
        ..onJson('/requesttopay/status/', {'status': 'SUCCESSFUL'});
      final repo = PaymentsRepositoryImpl(
        remoteSource: MomoRemoteDataSource(client, testConfig),
      );
      final result = await repo.fetchStatus('ref-1');
      expect(result.valueOrNull?.isSuccessful, isTrue);
    });
  });

  group('MomoPaymentController', () {
    ProviderContainer containerWith(FakePaymentsRepository payments) {
      final container = ProviderContainer(
        overrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
          momoPollIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 1),
          ),
          momoPollTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 60),
          ),
        ],
      );
      addTearDown(container.dispose);
      // The controller is autoDispose: without a live listener it would be
      // torn down between reads and drop its own state updates — exactly what
      // happens in the app when the payment sheet is closed mid-poll.
      container.listen(momoPaymentControllerProvider, (_, _) {});
      return container;
    }

    test('refuses an invalid number before any network call', () async {
      final payments = FakePaymentsRepository();
      final container = containerWith(payments);
      await container
          .read(momoPaymentControllerProvider.notifier)
          .pay(
            phoneNumber: '12345',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          );
      final state = container.read(momoPaymentControllerProvider);
      expect(state.stage, MomoStage.failed);
      expect(state.failure, isA<ValidationFailure>());
      expect(payments.initiateCalls, 0);
    });

    test('confirms once MTN reports SUCCESSFUL', () async {
      final payments = FakePaymentsRepository(
        reference: 'ref-42',
        statuses: [MomoPaymentStatus.pending, MomoPaymentStatus.successful],
      );
      final container = containerWith(payments);
      await container
          .read(momoPaymentControllerProvider.notifier)
          .pay(
            phoneNumber: '0788123456',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          );

      final state = container.read(momoPaymentControllerProvider);
      expect(state.stage, MomoStage.confirmed);
      expect(state.reference, 'ref-42');
      expect(state.settlement?.financialTransactionId, 'fin-1');
      expect(state.amountRwf, 500);
      // Polled through the pending reading before confirming.
      expect(payments.statusCalls, 2);
      expect(payments.lastPhone, '0788123456');
    });

    test('stops on a terminal failure from the gateway', () async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.failed],
      );
      final container = containerWith(payments);
      await container
          .read(momoPaymentControllerProvider.notifier)
          .pay(
            phoneNumber: '0788123456',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          );
      final state = container.read(momoPaymentControllerProvider);
      expect(state.stage, MomoStage.failed);
      expect(state.failure?.message, contains('not completed'));
      expect(payments.statusCalls, 1);
    });

    test('times out without ever claiming the payment failed', () async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.pending],
      );
      final container = containerWith(payments);
      await container
          .read(momoPaymentControllerProvider.notifier)
          .pay(
            phoneNumber: '0788123456',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          );
      expect(
        container.read(momoPaymentControllerProvider).stage,
        MomoStage.timedOut,
      );
      expect(payments.statusCalls, greaterThan(1));
    });

    test('surfaces an initiate failure and never polls', () async {
      final payments = FakePaymentsRepository(
        initiateFailure: const NetworkFailure(),
      );
      final container = containerWith(payments);
      await container
          .read(momoPaymentControllerProvider.notifier)
          .pay(
            phoneNumber: '0788123456',
            amountRwf: 500,
            purpose: MomoPurpose.tutorTopUp,
          );
      final state = container.read(momoPaymentControllerProvider);
      expect(state.stage, MomoStage.failed);
      expect(state.failure, isA<NetworkFailure>());
      expect(payments.statusCalls, 0);
    });

    test('reset returns the sheet to its entry state', () async {
      final payments = FakePaymentsRepository(
        initiateFailure: const NetworkFailure(),
      );
      final container = containerWith(payments);
      final notifier = container.read(momoPaymentControllerProvider.notifier);
      await notifier.pay(
        phoneNumber: '0788123456',
        amountRwf: 500,
        purpose: MomoPurpose.tutorTopUp,
      );
      notifier.reset();
      expect(
        container.read(momoPaymentControllerProvider),
        const MomoPaymentState(),
      );
    });
  });
}
