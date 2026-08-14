/// Phone-number handling for MTN / Airtel Rwanda Mobile Money.
///
/// Mirrors Flipper's rules exactly, because both apps hit the same gateway:
/// payNow wants MSISDN digits only (no `+`, spaces or separators), and the
/// gateway rejects anything that is not a Rwandan mobile number.
abstract final class MomoMsisdn {
  /// Rwandan mobile prefixes after the country code: MTN 78/79, Airtel 72/73.
  static final RegExp _rwandaMobile = RegExp(r'^7[2389]\d{7}$');
  static final RegExp _nonDigits = RegExp(r'\D');

  /// Strips every separator and the leading `+`, leaving digits only.
  ///
  /// The fullwidth plus (U+FF0B) is handled too — some phone keyboards emit
  /// it and it is invisible in a text field.
  static String normalise(String phone) {
    return phone.replaceAll('＋', '').replaceAll(_nonDigits, '');
  }

  /// The nine significant digits, country code and leading zero removed.
  /// Returns an empty string when the input has no plausible subscriber part.
  static String subscriberDigits(String phone) {
    var digits = normalise(phone);
    if (digits.startsWith('250')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  /// True for a Rwandan mobile number in any of the usual shapes:
  /// `0788123456`, `788123456`, `+250788123456`, `250788123456`.
  static bool isValid(String phone) {
    if (phone.trim().isEmpty) return false;
    return _rwandaMobile.hasMatch(subscriberDigits(phone));
  }

  /// The value payNow's `payer.partyId` expects: `250` + nine digits.
  /// Returns null when [phone] is not a valid Rwandan mobile number, so a
  /// malformed number can never reach the gateway.
  static String? toPartyId(String phone) {
    final digits = subscriberDigits(phone);
    if (!_rwandaMobile.hasMatch(digits)) return null;
    return '250$digits';
  }

  /// Local display form, `0788123456`.
  static String toLocal(String phone) {
    final digits = subscriberDigits(phone);
    return digits.isEmpty ? '' : '0$digits';
  }

  /// Log-safe form, `…456`.
  ///
  /// A payer's MSISDN is personal data and a log file is the wrong place for
  /// it, but a payment that failed still has to be traceable — three digits is
  /// enough to match a log line against the person who rang about it.
  static String masked(String phone) {
    final digits = subscriberDigits(phone);
    if (digits.length < 3) return '…';
    return '…${digits.substring(digits.length - 3)}';
  }
}
