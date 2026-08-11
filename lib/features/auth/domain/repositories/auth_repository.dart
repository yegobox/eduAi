import '../../../../core/error/result.dart';
import '../entities/app_user.dart';
import '../entities/auth_session.dart';
import '../entities/phone_otp_challenge.dart';

/// The single contract the presentation layer talks to. Implementations
/// orchestrate Supabase, Firebase and the local offline cache; callers never
/// see those details.
abstract interface class AuthRepository {
  /// Emits the current session (or null) whenever it changes — sign-in,
  /// sign-out, token refresh, offline unlock.
  Stream<AuthSession?> authStateChanges();

  /// Best-effort session resolution at startup. Returns a live provider
  /// session if one is valid, otherwise null. Does NOT perform offline
  /// unlock (that needs the PIN) — see [hasOfflineCredential].
  Future<AuthSession?> restoreSession();

  // ---- Online: Supabase email/password ----------------------------------

  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<Result<void>> sendPasswordReset(String email);

  // ---- Online: Firebase phone (SMS) -------------------------------------

  /// Dispatches an SMS code. Completes when the code has been sent.
  Future<Result<PhoneOtpChallenge>> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
  });

  Future<Result<AuthSession>> verifyPhoneOtp({
    required PhoneOtpChallenge challenge,
    required String smsCode,
  });

  // ---- Offline unlock ----------------------------------------------------

  /// True when a credential for offline unlock is stored on this device.
  Future<bool> hasOfflineCredential();

  /// The account label (email/phone) cached for offline unlock, for the UI.
  Future<String?> offlineAccountLabel();

  /// Whether the cached credential has an offline PIN configured.
  Future<bool> hasOfflinePin();

  /// Sets (or replaces) the offline PIN for the currently signed-in user.
  Future<Result<void>> setOfflinePin(String pin);

  /// Verifies [pin] against the local cache and returns an offline session.
  Future<Result<AuthSession>> unlockOffline(String pin);

  // ---- Session end -------------------------------------------------------

  /// Signs out of live providers. When [forgetDevice] is true, also wipes the
  /// offline credential so this device can no longer unlock offline.
  Future<Result<void>> signOut({bool forgetDevice = false});
}
