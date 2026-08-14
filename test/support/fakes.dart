import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/error/result.dart';
import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/access/domain/entities/payment_quote.dart';
import 'package:eduai/features/access/domain/repositories/access_repository.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/auth/domain/entities/phone_otp_challenge.dart';
import 'package:eduai/features/auth/domain/repositories/auth_repository.dart';
import 'package:eduai/features/linking/domain/entities/family_link.dart';
import 'package:eduai/features/linking/domain/repositories/linking_repository.dart';
import 'package:eduai/features/schools/domain/entities/membership.dart';
import 'package:eduai/features/schools/domain/entities/school.dart';
import 'package:eduai/features/schools/domain/entities/school_class.dart';
import 'package:eduai/features/schools/domain/repositories/schools_repository.dart';
import 'package:eduai/features/teacher/domain/entities/teacher_class.dart';
import 'package:eduai/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_block.dart';
import 'package:eduai/features/tutor/domain/entities/tutor_turn.dart';
import 'package:eduai/features/tutor/domain/repositories/tutor_repository.dart';
import 'package:eduai/features/payments/domain/entities/momo_payment.dart';
import 'package:eduai/features/payments/domain/repositories/payments_repository.dart';
import 'package:eduai/features/workbook/domain/entities/workbook_feedback.dart';
import 'package:eduai/features/workbook/domain/repositories/workbook_check_repository.dart';

/// In-memory [AuthRepository] for deterministic E2E flows — no Supabase,
/// Firebase, secure storage or network. Behaviour mirrors the real repo's
/// contract (validation, offline unlock, sign-out → offline-locked, …).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    Map<String, String>? validLogins,
    this.initialSession,
    bool hasCredential = false,
    String? offlineLabel,
    String? offlinePin,
  }) : _validLogins = validLogins ?? const {'teacher@eduai.dev': 'password123'},
       _credentialStored = hasCredential,
       _label = offlineLabel,
       _pin = offlinePin;

  final Map<String, String> _validLogins;
  final AuthSession? initialSession;
  final _controller = StreamController<AuthSession?>.broadcast();

  bool _credentialStored;
  String? _label;
  String? _pin;

  AppUser _userFor(String email) =>
      AppUser(id: 'u-$email', email: email, displayName: 'Teacher');

  @override
  Stream<AuthSession?> authStateChanges() => _controller.stream;

  @override
  Future<AuthSession?> restoreSession() async => initialSession;

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@')) {
      return const Result.failure(
        ValidationFailure('Enter a valid email address.'),
      );
    }
    if (password.length < 6) {
      return const Result.failure(
        ValidationFailure('Password must be at least 6 characters.'),
      );
    }
    if (_validLogins[email.trim()] != password) {
      return const Result.failure(AuthFailure('Invalid login credentials.'));
    }
    final session = AuthSession(
      user: _userFor(email.trim()),
      provider: AuthProvider.supabaseEmail,
    );
    _credentialStored = true;
    _label = email.trim();
    _controller.add(session);
    return Result.success(session);
  }

  /// Records the role the form asked for, so a test can assert that the picker
  /// actually reaches the repository rather than defaulting to student.
  AppRole? lastSignUpRole;

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required AppRole role,
    String? displayName,
  }) async {
    lastSignUpRole = role;
    return Result.success(_userFor(email.trim()).copyWith(role: role));
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Result.success(null);

  /// The number remembered after a settled payment, so a test can prove an
  /// email-only account is not made to retype it every month.
  String? rememberedPayerPhone;

  @override
  Future<void> rememberPayerPhone(String phoneNumber) async =>
      rememberedPayerPhone = phoneNumber;

  @override
  Future<Result<PhoneOtpChallenge>> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
  }) async => Result.success(
    PhoneOtpChallenge(phoneNumber: phoneNumber, verificationId: 'vid-1'),
  );

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required PhoneOtpChallenge challenge,
    required String smsCode,
  }) async {
    final session = AuthSession(
      user: AppUser(id: 'u-phone', phoneNumber: challenge.phoneNumber),
      provider: AuthProvider.firebasePhone,
    );
    _credentialStored = true;
    _label = challenge.phoneNumber;
    _controller.add(session);
    return Result.success(session);
  }

  @override
  Future<bool> hasOfflineCredential() async => _credentialStored;

  @override
  Future<String?> offlineAccountLabel() async => _label;

  @override
  Future<bool> hasOfflinePin() async => _pin != null;

  @override
  Future<Result<void>> setOfflinePin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return const Result.failure(ValidationFailure('PIN must be 4–8 digits.'));
    }
    _pin = pin;
    return const Result.success(null);
  }

  @override
  Future<Result<AuthSession>> unlockOffline(String pin) async {
    if (_pin == null) {
      return const Result.failure(
        AuthFailure('No offline PIN is set up on this device.'),
      );
    }
    if (pin != _pin) {
      return const Result.failure(AuthFailure('Incorrect PIN. Try again.'));
    }
    final session = AuthSession(
      user: AppUser(id: 'u-offline', email: _label ?? 'user'),
      provider: AuthProvider.offline,
    );
    _controller.add(session);
    return Result.success(session);
  }

  @override
  Future<Result<void>> signOut({bool forgetDevice = false}) async {
    if (forgetDevice) {
      _credentialStored = false;
      _label = null;
      _pin = null;
    }
    _controller.add(null);
    return const Result.success(null);
  }
}

/// In-memory [SchoolsRepository] with a small seeded catalog.
class FakeSchoolsRepository implements SchoolsRepository {
  FakeSchoolsRepository({
    List<School>? schools,
    Map<String, List<SchoolClass>>? classes,
  }) : _schools = schools ?? List.of(_seedSchools),
       _classes =
           classes ??
           {for (final e in _seedClasses.entries) e.key: List.of(e.value)};

  final List<School> _schools;
  final Map<String, List<SchoolClass>> _classes;
  final List<Membership> _memberships = [];
  int _seq = 0;

  static const _seedSchools = [
    School(id: 's1', name: 'Kigali Modern Academy', description: 'Demo school'),
    School(id: 's2', name: 'Green Hills Secondary', joinCode: 'GHS24'),
  ];
  static final _seedClasses = {
    's1': const [
      SchoolClass(id: 'c1', schoolId: 's1', name: 'P5 — Maths', grade: 'P5'),
      SchoolClass(
        id: 'c2',
        schoolId: 's1',
        name: 'P6 — English',
        grade: 'P6',
        joinCode: 'ENG6',
      ),
    ],
    's2': const [
      SchoolClass(id: 'c3', schoolId: 's2', name: 'S1 — Physics', grade: 'S1'),
    ],
  };

  /// Enrolments that actually reached the repository. Lets a test prove that a
  /// blocked role never consumed a seat, rather than only that it saw an error.
  int joinCalls = 0;

  Membership _add({
    required String schoolId,
    String? classId,
    MemberRole role = MemberRole.student,
  }) {
    if (role == MemberRole.student) joinCalls++;
    final m = Membership(
      id: 'm${_seq++}',
      userId: 'u1',
      schoolId: schoolId,
      classId: classId,
      role: role,
    );
    _memberships.add(m);
    return m;
  }

  @override
  Future<Result<List<School>>> fetchSchools({
    String? query,
    bool preferCache = false,
  }) async {
    final q = query?.trim().toLowerCase();
    final list = (q == null || q.isEmpty)
        ? _schools
        : _schools.where((s) => s.name.toLowerCase().contains(q)).toList();
    return Result.success(List.of(list));
  }

  @override
  Future<Result<List<SchoolClass>>> fetchClasses(String schoolId) async =>
      Result.success(List.of(_classes[schoolId] ?? const []));

  @override
  Future<Result<List<Membership>>> fetchMyMemberships({
    bool preferCache = false,
  }) async => Result.success(List.of(_memberships));

  @override
  Future<Result<Membership>> joinSchool(String schoolId) async =>
      Result.success(_add(schoolId: schoolId));

  @override
  Future<Result<Membership>> joinClass({
    required String schoolId,
    required String classId,
  }) async => Result.success(_add(schoolId: schoolId, classId: classId));

  @override
  Future<Result<Membership>> joinByCode(String code) async {
    for (final s in _schools) {
      if (s.joinCode == code) return Result.success(_add(schoolId: s.id));
    }
    for (final entry in _classes.entries) {
      for (final c in entry.value) {
        if (c.joinCode == code) {
          return Result.success(_add(schoolId: c.schoolId, classId: c.id));
        }
      }
    }
    return const Result.failure(
      ValidationFailure('No school or class matches that code.'),
    );
  }

  @override
  Future<Result<void>> leave(String membershipId) async {
    _memberships.removeWhere((m) => m.id == membershipId);
    return const Result.success(null);
  }

  @override
  Future<Result<School>> createSchool({
    required String name,
    String? description,
    String? joinCode,
  }) async {
    // Mirrors the real repository's validation.
    if (name.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure('School name is required.'),
      );
    }
    final s = School(
      id: 'school-$_seq',
      name: name,
      description: description,
      joinCode: joinCode,
    );
    _schools.add(s);
    _add(schoolId: s.id, role: MemberRole.owner);
    return Result.success(s);
  }

  @override
  Future<Result<SchoolClass>> createClass({
    required String schoolId,
    required String name,
    String? grade,
    String? joinCode,
  }) async {
    // Mirrors the real repository's validation.
    if (name.trim().isEmpty) {
      return const Result.failure(ValidationFailure('Class name is required.'));
    }
    final c = SchoolClass(
      id: 'class-$_seq',
      schoolId: schoolId,
      name: name,
      grade: grade,
      joinCode: joinCode,
    );
    (_classes[schoolId] ??= <SchoolClass>[]).add(c);
    _add(schoolId: schoolId, classId: c.id, role: MemberRole.teacher);
    return Result.success(c);
  }
}

/// In-memory [TutorRepository]. Records every asked message so tests can
/// assert on conversation flow; returns a canned multi-block answer (or a
/// fixed [failure]) instead of calling data-connector.
class FakeTutorRepository implements TutorRepository {
  FakeTutorRepository({this.failure});

  final Failure? failure;
  final List<String> askedMessages = [];
  final List<List<TutorTurn>> historySeenPerCall = [];

  @override
  Future<Result<TutorAnswer>> ask({
    required String message,
    required List<TutorTurn> history,
    String? subject,
    String? level,
  }) async {
    askedMessages.add(message);
    historySeenPerCall.add(List.of(history));
    if (failure != null) return Result.failure(failure!);
    return Result.success(
      const TutorAnswer(
        blocks: [
          TutorTextBlock(
            'The sky looks blue because air molecules scatter **blue light** more than red light.',
          ),
          TutorCheckBlock(
            question: 'Which color scatters most in the atmosphere?',
            choices: ['Red', 'Blue', 'Green', 'Yellow'],
            correctIndex: 1,
            explanation:
                'Blue light has a shorter wavelength, so it scatters more.',
          ),
          TutorFollowupsBlock(['Why does the sunset look red?']),
        ],
        modelUsed: 'fake-model',
      ),
    );
  }
}

/// A scriptable [http.Client] that records every request.
///
/// Handlers are matched in registration order by a predicate on the request,
/// so a test can answer payNow and the status poll differently — including
/// answering the *same* URL differently on successive calls, which is how a
/// real request-to-pay behaves.
class RecordingHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<_Handler> _handlers = [];

  /// Answers requests whose URL contains [urlContains]. When [responses] has
  /// more than one entry they are returned in order, the last one repeating.
  void on(
    String urlContains, {
    int status = 200,
    List<String> responses = const ['{}'],
  }) {
    _handlers.add(_Handler(urlContains, status, responses));
  }

  /// Convenience: a single JSON body for every matching call.
  void onJson(String urlContains, Object json, {int status = 200}) {
    on(urlContains, status: status, responses: [jsonEncode(json)]);
  }

  int callsMatching(String urlContains) =>
      requests.where((r) => r.url.toString().contains(urlContains)).length;

  /// The decoded JSON body of the first request whose URL matches.
  Map<String, dynamic>? bodyOf(String urlContains) {
    final request = requests
        .whereType<http.Request>()
        .where((r) => r.url.toString().contains(urlContains))
        .firstOrNull;
    if (request == null) return null;
    final decoded = jsonDecode(request.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final url = request.url.toString();
    for (final handler in _handlers) {
      if (url.contains(handler.urlContains)) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(handler.next())),
          handler.status,
          headers: const {'content-type': 'application/json'},
        );
      }
    }
    // Unscripted call: 404 with a JSON body, which every data source treats as
    // "not available" rather than crashing.
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error":"unscripted: $url"}')),
      404,
    );
  }
}

class _Handler {
  _Handler(this.urlContains, this.status, this.responses);

  final String urlContains;
  final int status;
  final List<String> responses;
  int _index = 0;

  String next() {
    final body = responses[_index];
    if (_index < responses.length - 1) _index++;
    return body;
  }
}

/// In-memory [PaymentsRepository] for flows that must not hit the gateway.
class FakePaymentsRepository implements PaymentsRepository {
  FakePaymentsRepository({
    this.reference = 'ref-1',
    this.initiateFailure,
    this.settledAmountOverride,
    this.pendingReason,
    List<MomoPaymentStatus>? statuses,
  }) : _statuses = statuses ?? [MomoPaymentStatus.successful];

  /// What the gateway says while still reporting PENDING — how a gateway that
  /// cannot reach MTN actually answers.
  final String? pendingReason;

  final String reference;
  final Failure? initiateFailure;
  final List<MomoPaymentStatus> _statuses;

  /// Forces MTN to report a different amount than was requested — the
  /// under-payment case the server refuses to grant a period for.
  final int? settledAmountOverride;

  int initiateCalls = 0;
  int statusCalls = 0;
  int? lastAmount;
  String? lastPhone;

  @override
  Future<Result<String>> initiate({
    required String phoneNumber,
    required int amountRwf,
    required MomoPurpose purpose,
  }) async {
    initiateCalls++;
    lastAmount = amountRwf;
    lastPhone = phoneNumber;
    final failure = initiateFailure;
    if (failure != null) return Result.failure(failure);
    return Result.success(reference);
  }

  @override
  Future<Result<MomoSettlement>> fetchStatus(String reference) async {
    final status =
        _statuses[statusCalls < _statuses.length
            ? statusCalls
            : _statuses.length - 1];
    statusCalls++;
    return Result.success(
      MomoSettlement(
        reference: reference,
        status: status,
        financialTransactionId: status == MomoPaymentStatus.successful
            ? 'fin-1'
            : null,
        // A real gateway settles what it was asked for, so echo the requested
        // amount. Callers trust this figure over the one they asked for, which
        // a fixed value here would silently corrupt.
        settledAmountRwf: status == MomoPaymentStatus.successful
            ? (settledAmountOverride ?? lastAmount)
            : null,
        reason: status == MomoPaymentStatus.pending ? pendingReason : null,
      ),
    );
  }
}

/// A [WorkbookCheckRepository] that returns a scripted verdict.
class FakeWorkbookCheckRepository implements WorkbookCheckRepository {
  FakeWorkbookCheckRepository({this.feedback, this.failure});

  final WorkbookFeedback? feedback;
  final Failure? failure;

  int calls = 0;
  int lastImageBytes = 0;

  @override
  Future<Result<WorkbookFeedback>> check(Uint8List pageImage) async {
    calls++;
    lastImageBytes = pageImage.length;
    final f = failure;
    if (f != null) return Result.failure(f);
    return Result.success(
      feedback ??
          const WorkbookFeedback(
            verdict: 'Nice work — step 2 has a small slip',
            tip: 'Check the sign when you divide both sides by 2.',
          ),
    );
  }
}

/// An [http.Client] that always fails at the transport layer, for testing how
/// repositories classify "the network is gone" versus "the server said no".
class ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketExceptionStub();
  }
}

/// Stand-in for `dart:io`'s SocketException, which repositories detect by
/// message rather than by type so the same code runs on web.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketException: Failed host lookup';
}

/// In-memory [AccessRepository] so entitlement can be driven from a test
/// without a Supabase instance.
///
/// The real one answers from a `security definer` function; this one answers
/// from a field. Both are the single source the UI consults, which is the
/// property worth testing — that a screen locks or unlocks purely because
/// entitlement said so.
class FakeAccessRepository implements AccessRepository {
  FakeAccessRepository({
    AccessState? state,
    this.failure,
    this.testPricing = false,
    this.testChargeRwf = 100,
  }) : _state = state ?? const AccessState.unconfigured();

  /// Mirrors migration 0005's server-side price override.
  final bool testPricing;
  final int testChargeRwf;

  AccessState _state;
  final Failure? failure;

  /// Settlements recorded, newest last. Keyed by reference so a test can prove
  /// idempotency the same way the server does.
  final List<String> settledReferences = [];
  int? lastAmountRwf;
  String? lastPlanId;
  int? lastSeats;

  /// Swaps the entitlement a test is running against.
  void setState(AccessState state) => _state = state;

  @override
  Future<Result<AccessState>> fetchState({bool preferCache = false}) async {
    final f = failure;
    if (f != null) return Result.failure(f);
    return Result.success(_state);
  }

  @override
  Future<Result<bool>> isTestPricingOn() async => Result.success(testPricing);

  @override
  Future<Result<SchoolLicenseQuote>> schoolLicenseQuote({int? seats}) async {
    final billed = seats ?? _state.billableSeats;
    final seatCount = billed < 1 ? 1 : billed;
    final full = seatCount * 1500;
    return Result.success(
      SchoolLicenseQuote(
        schoolId: _state.schoolId ?? 's1',
        tierId: _state.tierId ?? 'growth',
        tierName: 'Growth',
        seats: seatCount,
        seatsUsed: _state.seatsUsed,
        pricePerSeatRwf: 1500,
        // The server substitutes the test amount here and settlement recomputes
        // it the same way, which is what keeps the two sides agreeing.
        amountRwf: testPricing ? testChargeRwf : full,
        fullAmountRwf: full,
        testMode: testPricing,
        periodDays: 30,
      ),
    );
  }

  @override
  Future<Result<AccessState>> selectSchoolTier(String tierId) async =>
      Result.success(_state);

  @override
  Future<Result<AccessState>> setSeatsPurchased(int seats) async {
    lastSeats = seats;
    return Result.success(_state);
  }

  @override
  Future<Result<AccessState>> settleSchoolLicense({
    required String reference,
    required int amountRwf,
    int? seats,
  }) async {
    lastAmountRwf = amountRwf;
    lastSeats = seats;
    // Idempotent per reference, exactly like settle_school_license.
    if (!settledReferences.contains(reference)) {
      settledReferences.add(reference);
    }
    return Result.success(_state);
  }

  @override
  Future<Result<List<ParentPlanOption>>> fetchParentPlans() async =>
      const Result.success([
        ParentPlanOption(
          id: 'family_monthly',
          name: 'Family — monthly',
          pricePerChildRwf: 3000,
          periodDays: 30,
          features: ['AI Tutor', 'Weekly reports'],
        ),
      ]);

  @override
  Future<Result<ParentPlanQuote>> parentPlanQuote({
    required String planId,
    int? children,
  }) async {
    final kids = children ?? (_state.childrenLinked < 1 ? 1 : _state.childrenLinked);
    final full = kids * 3000;
    return Result.success(
      ParentPlanQuote(
        planId: planId,
        planName: 'Family — monthly',
        children: kids,
        pricePerChildRwf: 3000,
        amountRwf: testPricing ? testChargeRwf : full,
        fullAmountRwf: full,
        testMode: testPricing,
        periodDays: 30,
      ),
    );
  }

  @override
  Future<Result<AccessState>> settleParentSubscription({
    required String reference,
    required String planId,
    required int amountRwf,
    int? children,
  }) async {
    lastAmountRwf = amountRwf;
    lastPlanId = planId;
    if (!settledReferences.contains(reference)) {
      settledReferences.add(reference);
    }
    return Result.success(_state);
  }
}

/// In-memory [TeacherRepository] with a couple of classes and rosters.
class FakeTeacherRepository implements TeacherRepository {
  FakeTeacherRepository({List<TeacherClass>? classes, this.progress = const {}})
    : classes = [...?classes];

  final List<TeacherClass> classes;

  /// classId → the roster returned for it.
  final Map<String, List<StudentProgress>> progress;

  /// Class ids a caller tried to read, so a test can assert scoping.
  final List<String> progressReads = [];

  @override
  Future<Result<List<TeacherClass>>> fetchClasses() async =>
      Result.success(classes);

  @override
  Future<Result<List<StudentProgress>>> fetchClassProgress(
    String classId, {
    int days = 30,
  }) async {
    progressReads.add(classId);
    // Mirrors the server, which raises rather than returning an empty roster
    // for a class that is not yours.
    if (!classes.any((c) => c.id == classId)) {
      return const Result.failure(ValidationFailure('that class is not yours'));
    }
    return Result.success(progress[classId] ?? const []);
  }
}

/// In-memory [LinkingRepository] holding one family's links and invites.
class FakeLinkingRepository implements LinkingRepository {
  FakeLinkingRepository({
    List<FamilyLink>? links,
    List<RosterEntry>? roster,
    this.failure,
  }) : links = [...?links],
       roster = [...?roster];

  final List<FamilyLink> links;
  final List<RosterEntry> roster;
  final List<PendingInvite> pending = [];

  /// When set, every call fails with it — for the error-path tests.
  final Failure? failure;

  int _codes = 0;
  String? lastRedeemedCode;
  String? lastInvitedStudentId;

  @override
  Future<Result<List<FamilyLink>>> fetchMyLinks() async =>
      failure == null ? Result.success(links) : Result.failure(failure!);

  @override
  Future<Result<List<PendingInvite>>> fetchMyPendingInvites() async =>
      failure == null ? Result.success(pending) : Result.failure(failure!);

  @override
  Future<Result<List<RosterEntry>>> fetchRoster() async =>
      failure == null ? Result.success(roster) : Result.failure(failure!);

  @override
  Future<Result<FamilyInvite>> inviteChild({String? contact}) async =>
      _mint(InviteKind.studentOfParent, contact: contact);

  @override
  Future<Result<FamilyInvite>> inviteParent({
    required String studentId,
    String? contact,
  }) async {
    lastInvitedStudentId = studentId;
    return _mint(
      InviteKind.parentOfStudent,
      contact: contact,
      studentId: studentId,
    );
  }

  Result<FamilyInvite> _mint(
    InviteKind kind, {
    String? contact,
    String? studentId,
  }) {
    final f = failure;
    if (f != null) return Result.failure(f);
    _codes++;
    final invite = FamilyInvite(
      id: 'i$_codes',
      code: 'CODE$_codes',
      kind: kind,
    );
    pending.add(
      PendingInvite(
        id: invite.id,
        code: invite.code,
        kind: kind,
        expiresAt: DateTime(2030),
        contact: contact,
        studentId: studentId,
      ),
    );
    return Result.success(invite);
  }

  @override
  Future<Result<FamilyInvite>> inviteTeacher({String? contact}) async =>
      _mint(InviteKind.teacherOfSchool, contact: contact);

  @override
  Future<Result<void>> redeemCode(String code) async {
    final f = failure;
    if (f != null) return Result.failure(f);
    if (code.trim().length < 4) {
      return const Result.failure(ValidationFailure('Enter the full code.'));
    }
    lastRedeemedCode = code.trim().toUpperCase();
    links.add(
      FamilyLink(
        id: 'l${links.length + 1}',
        parentId: 'p1',
        studentId: 's${links.length + 1}',
        createdBySchool: true,
        displayName: 'Linked child',
      ),
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unlink(String linkId) async {
    final f = failure;
    if (f != null) return Result.failure(f);
    links.removeWhere((l) => l.id == linkId);
    return const Result.success(null);
  }
}
