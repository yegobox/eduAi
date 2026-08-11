import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/phone_otp_challenge.dart';

/// Firebase phone (SMS) verification, adapted from Firebase's callback API to
/// simple `Future`s.
///
/// Availability: Android, iOS and Web (Web needs reCAPTCHA setup). On desktop
/// Firebase phone auth is not supported, so [ready] is false there and every
/// method throws [PhoneAuthUnavailable].
class FirebasePhoneAuthDataSource {
  FirebasePhoneAuthDataSource({required this.ready});

  /// Whether Firebase initialised successfully on this platform.
  final bool ready;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  AppUser _mapUser(fb.User u) => AppUser(
        id: u.uid,
        phoneNumber: u.phoneNumber,
        email: u.email,
        displayName: u.displayName,
        avatarUrl: u.photoURL,
      );

  /// Dispatches an SMS code. Resolves once `codeSent` fires (or errors on
  /// `verificationFailed`). Auto-retrieval (Android) is intentionally ignored
  /// so the UI stays a single, explicit "enter the code" step.
  Future<PhoneOtpChallenge> sendOtp({
    required String phoneNumber,
    int? resendToken,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!ready) throw const PhoneAuthUnavailable();

    final completer = Completer<PhoneOtpChallenge>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: resendToken,
      verificationCompleted: (_) {
        // Android may auto-verify; we still require the user to submit a code
        // via [verifyOtp] to keep one unified flow. No-op here.
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? token) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpChallenge(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
              resendToken: token,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<AuthSession> verifyOtp({
    required PhoneOtpChallenge challenge,
    required String smsCode,
  }) async {
    if (!ready) throw const PhoneAuthUnavailable();

    final credential = fb.PhoneAuthProvider.credential(
      verificationId: challenge.verificationId,
      smsCode: smsCode.trim(),
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'no-user',
        message: 'Verification succeeded but no user was returned.',
      );
    }
    return AuthSession(
      user: _mapUser(user),
      provider: AuthProvider.firebasePhone,
    );
  }

  AuthSession? get currentSession {
    if (!ready) return null;
    final u = _auth.currentUser;
    if (u == null) return null;
    return AuthSession(user: _mapUser(u), provider: AuthProvider.firebasePhone);
  }

  Future<void> signOut() async {
    if (!ready) return;
    await _auth.signOut();
  }
}

/// Thrown when Firebase phone auth is not available on this platform/build.
class PhoneAuthUnavailable implements Exception {
  const PhoneAuthUnavailable();
  @override
  String toString() =>
      'SMS sign-in is not available on this device. Use email or offline PIN.';
}
