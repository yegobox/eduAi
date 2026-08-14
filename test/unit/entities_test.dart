import 'package:eduai/features/auth/data/models/offline_credential.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/auth/domain/entities/phone_otp_challenge.dart';
import 'package:eduai/features/billing/domain/entities/billing_entities.dart';
import 'package:eduai/features/parent/domain/entities/parent_entities.dart';
import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/schools/domain/entities/membership.dart';
import 'package:eduai/features/schools/domain/entities/school.dart';
import 'package:eduai/features/schools/domain/entities/school_class.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_block.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_turn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorBlock.fromJson', () {
    test('parses a text block', () {
      final block = TutorBlock.fromJson(const {
        'type': 'text',
        'text': 'Photosynthesis is how plants make food.',
      });
      expect(block, isA<TutorTextBlock>());
      expect(block.asHistoryText, contains('Photosynthesis'));
    });

    test('parses an example block, defaulting its title', () {
      final block =
          TutorBlock.fromJson(const {
                'type': 'example',
                'body': 'A leaf is a solar-powered kitchen.',
              })
              as TutorExampleBlock;
      expect(block.title, 'Example');
      expect(
        block.asHistoryText,
        'Example: A leaf is a solar-powered kitchen.',
      );
    });

    test('parses a concept check and grades answers', () {
      final block =
          TutorBlock.fromJson(const {
                'type': 'check',
                'question': 'What gas do plants release?',
                'choices': ['Carbon dioxide', 'Oxygen', 'Nitrogen'],
                'correct_index': 1,
                'explanation': 'Oxygen is the byproduct.',
              })
              as TutorCheckBlock;

      expect(block.choices, hasLength(3));
      expect(block.isCorrect(1), isTrue);
      expect(block.isCorrect(0), isFalse);
      expect(block.asHistoryText, startsWith('Concept check:'));
    });

    test('defaults a check with no choices rather than throwing', () {
      final block =
          TutorBlock.fromJson(const {'type': 'check'}) as TutorCheckBlock;
      expect(block.choices, isEmpty);
      expect(block.correctIndex, 0);
      expect(block.question, isEmpty);
    });

    test('parses followups and drops blank suggestions', () {
      final block =
          TutorBlock.fromJson(const {
                'type': 'followups',
                'items': [
                  'What is chlorophyll?',
                  '   ',
                  'Why are leaves green?',
                ],
              })
              as TutorFollowupsBlock;
      expect(block.items, hasLength(2));
      // Followups add no context to the next request.
      expect(block.asHistoryText, isEmpty);
    });

    test('absorbs a block type the client does not know', () {
      // Prompt drift must render nothing, not crash the chat.
      final block =
          TutorBlock.fromJson(const {'type': 'diagram'}) as TutorUnknownBlock;
      expect(block.type, 'diagram');
      expect(block.asHistoryText, isEmpty);

      final missing = TutorBlock.fromJson(const {}) as TutorUnknownBlock;
      expect(missing.type, 'unknown');
    });
  });

  group('TutorTurn', () {
    test('a user turn is sent back verbatim as history', () {
      const turn = TutorTurn.user('Why is the sky blue?');
      expect(turn.role, 'user');
      expect(turn.historyContent, 'Why is the sky blue?');
    });

    test('an assistant turn flattens its blocks, skipping empty ones', () {
      const turn = TutorTurn.assistant(
        blocks: [
          TutorTextBlock('Light scatters.'),
          TutorFollowupsBlock(['More?']),
          TutorExampleBlock(title: 'Example', body: 'Rayleigh scattering.'),
        ],
        modelUsed: 'test-model',
      );
      expect(turn.role, 'assistant');
      expect(
        turn.historyContent,
        'Light scatters. Example: Rayleigh scattering.',
      );
    });
  });

  group('Schools entities', () {
    test('School round-trips through JSON', () {
      final school = School.fromJson(const {
        'id': 's1',
        'name': 'Kigali Modern Academy',
        'description': 'A demo school',
        'join_code': 'KMA24',
        'created_by': 'u1',
        'created_at': '2026-01-02T03:04:05.000Z',
      });
      expect(school.name, 'Kigali Modern Academy');
      expect(school.joinCode, 'KMA24');
      expect(school.createdAt?.year, 2026);
      expect(School.fromJson(school.toJson()), school);
    });

    test('SchoolClass round-trips and tolerates missing optionals', () {
      final klass = SchoolClass.fromJson(const {
        'id': 'c1',
        'school_id': 's1',
        'name': 'P6 — English',
      });
      expect(klass.grade, isNull);
      expect(klass.createdAt, isNull);
      expect(SchoolClass.fromJson(klass.toJson()), klass);
    });

    test('Membership distinguishes a class member from a school member', () {
      final schoolOnly = Membership.fromJson(const {
        'id': 'm1',
        'user_id': 'u1',
        'school_id': 's1',
        'role': 'owner',
      });
      expect(schoolOnly.isClassMember, isFalse);
      expect(schoolOnly.role, MemberRole.owner);

      final inClass = Membership.fromJson(const {
        'id': 'm2',
        'user_id': 'u1',
        'school_id': 's1',
        'class_id': 'c1',
        'role': 'nonsense',
      });
      expect(inClass.isClassMember, isTrue);
      // An unknown role degrades to the least-privileged one.
      expect(inClass.role, MemberRole.student);
      expect(Membership.fromJson(inClass.toJson()), inClass);
    });
  });

  group('LearningEvent', () {
    test('labels a topic by subject, then by question text', () {
      final withSubject = LearningEvent(
        id: 'e1',
        kind: LearningEventKind.question,
        subject: 'Biology',
        topic: 'cells',
        createdAt: DateTime(2026),
      );
      expect(withSubject.topicLabel, 'Biology');

      final topicOnly = LearningEvent(
        id: 'e2',
        kind: LearningEventKind.question,
        subject: '   ',
        topic: 'cells',
        createdAt: DateTime(2026),
      );
      expect(topicOnly.topicLabel, 'cells');

      final neither = LearningEvent(
        id: 'e3',
        kind: LearningEventKind.question,
        createdAt: DateTime(2026),
      );
      expect(neither.topicLabel, isNull);
    });

    test('round-trips through JSON and defaults an unknown kind', () {
      final event = LearningEvent(
        id: 'e1',
        kind: LearningEventKind.check,
        subject: 'Maths',
        level: 'P6',
        isCorrect: true,
        createdAt: DateTime.utc(2026, 5, 4, 3, 2, 1),
      );
      final restored = LearningEvent.fromJson(event.toJson());
      expect(restored.kind, LearningEventKind.check);
      expect(restored.isCorrect, isTrue);
      expect(restored.createdAt.toUtc(), event.createdAt);

      final unknown = LearningEvent.fromJson(const {
        'id': 'e2',
        'kind': 'telepathy',
        'created_at': 'not a date',
      });
      expect(unknown.kind, LearningEventKind.question);
      expect(unknown.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('Auth entities', () {
    test('an offline session is flagged as such', () {
      const online = AuthSession(
        user: AppUser(id: 'u1'),
        provider: AuthProvider.supabaseEmail,
      );
      expect(online.isOffline, isFalse);
      expect(online.isExpired, isFalse);

      const offline = AuthSession(
        user: AppUser(id: 'u1'),
        provider: AuthProvider.offline,
      );
      expect(offline.isOffline, isTrue);
    });

    test('an expired session reports it', () {
      final expired = AuthSession(
        user: const AppUser(id: 'u1'),
        provider: AuthProvider.supabaseEmail,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(expired.isExpired, isTrue);
    });

    test('AppUser greets by the best label it has', () {
      expect(const AppUser(id: 'u1', displayName: 'Mura').label, 'Mura');
      expect(const AppUser(id: 'u1', displayName: '  ').label, 'there');
      expect(const AppUser(id: 'u1', email: 'a@b.dev').label, 'a@b.dev');
      expect(const AppUser(id: 'u1', phoneNumber: '+250788').label, '+250788');
      expect(const AppUser(id: 'u1').label, 'there');
    });

    test('PhoneOtpChallenge carries the resend token', () {
      const challenge = PhoneOtpChallenge(
        phoneNumber: '+250788123456',
        verificationId: 'vid',
        resendToken: 7,
      );
      expect(challenge.props, contains(7));
      expect(
        challenge,
        const PhoneOtpChallenge(
          phoneNumber: '+250788123456',
          verificationId: 'vid',
          resendToken: 7,
        ),
      );
    });

    test('OfflineCredential round-trips and never stores a plaintext PIN', () {
      final credential = OfflineCredential(
        user: const AppUser(id: 'u1', email: 'a@b.dev'),
        originalProvider: AuthProvider.firebasePhone,
        salt: 'c2FsdA==',
        pinHash: 'aGFzaA==',
        refreshToken: 'rt',
        cachedAt: DateTime.utc(2026, 3, 2),
      );

      final json = credential.toJson();
      expect(json.containsValue('1234'), isFalse);

      final restored = OfflineCredential.fromJson(json);
      expect(restored.user.email, 'a@b.dev');
      expect(restored.originalProvider, AuthProvider.firebasePhone);
      expect(restored.pinIterations, 120000);
      expect(restored.hasPin, isTrue);
      expect(restored.cachedAt, credential.cachedAt);
    });

    test(
      'OfflineCredential without a PIN reports it, and copyWith adds one',
      () {
        final credential = OfflineCredential(
          user: const AppUser(id: 'u1'),
          originalProvider: AuthProvider.supabaseEmail,
          salt: 's',
          cachedAt: DateTime.utc(2026),
        );
        expect(credential.hasPin, isFalse);
        expect(credential.copyWith(pinHash: 'h').hasPin, isTrue);
      },
    );

    test('OfflineCredential tolerates a damaged record', () {
      final restored = OfflineCredential.fromJson({
        'user': const AppUser(id: 'u1').toJson(),
        'originalProvider': 'martian',
        'salt': 's',
        'cachedAt': 'nonsense',
      });
      expect(restored.originalProvider, AuthProvider.supabaseEmail);
      expect(restored.cachedAt.millisecondsSinceEpoch, 0);
    });
  });

  group('Billing entities', () {
    test('a tier knows the roster it cannot hold', () {
      const growth = PlanTier(
        id: 'growth',
        name: 'Growth',
        pricePerSeatRwf: 1500,
        maxSeats: 800,
        seatsLabel: 'Up to 800 students',
        features: [],
      );
      expect(growth.exceededBy(800), isFalse);
      expect(growth.exceededBy(801), isTrue);
    });

    test('an unlimited tier is never exceeded', () {
      const district = PlanTier(
        id: 'district',
        name: 'District',
        pricePerSeatRwf: 1250,
        seatsLabel: '800+',
        features: [],
      );
      expect(district.exceededBy(100000), isFalse);
    });

    test('payment states carry display labels', () {
      expect(PaymentState.settled.label, 'Paid');
      expect(PaymentState.pending.label, 'Pending');
      expect(PaymentState.disputed.label, 'Check');
      expect(PaymentState.failed.label, 'Failed');
    });

    test('an unrecognised payment status reads as pending, never as paid', () {
      expect(PaymentState.fromWire('refunded'), PaymentState.pending);
      expect(PaymentState.fromWire(null), PaymentState.pending);
      expect(PaymentState.fromWire('SETTLED'), PaymentState.settled);
    });

    test('an invoice prefers what MTN settled over what was quoted', () {
      final invoice = Invoice.fromJson({
        'reference': 'abcdef0123456789',
        'created_at': '2026-08-01T10:00:00Z',
        'settled_at': '2026-08-01T10:02:00Z',
        'amount_expected_rwf': 202500,
        'amount_reported_rwf': 202500,
        'status': 'settled',
        'metadata': {'seats': 135, 'tier_name': 'Growth'},
      });
      expect(invoice.amountRwf, 202500);
      expect(invoice.seats, 135);
      expect(invoice.tierName, 'Growth');
      expect(invoice.state, PaymentState.settled);
      // The row is identified by MTN's own reference, shortened for the table.
      expect(invoice.shortReference, '\u202623456789');
    });

    test('an invoice falls back to the quoted amount when none was reported', () {
      final invoice = Invoice.fromJson({
        'reference': 'ref-1',
        'created_at': '2026-08-01T10:00:00Z',
        'amount_expected_rwf': 5000,
        'status': 'pending',
      });
      expect(invoice.amountRwf, 5000);
      expect(invoice.shortReference, 'ref-1');
    });
  });

  group('Parent entities', () {
    test('derives initials from one, two or no names', () {
      expect(
        const Child(id: 'k', name: 'Alice K.', grade: 'P6').initials,
        'AK',
      );
      expect(const Child(id: 'k', name: 'Alice', grade: 'P6').initials, 'AL');
      expect(const Child(id: 'k', name: '   ', grade: 'P6').initials, '?');
      expect(const Child(id: 'k', name: 'A', grade: 'P6').initials, 'A');
    });

    test('exposes a first name for possessive copy', () {
      expect(
        const Child(id: 'k', name: 'Jean P.', grade: 'P4').firstName,
        'Jean',
      );
    });
  });
}
