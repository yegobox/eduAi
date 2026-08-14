import 'dart:math';

/// Suggests a class join code.
///
/// A class without a code cannot be joined, so the create-class dialog offers
/// one rather than leaving the field blank — an admin who skips it would
/// otherwise end up with a class nobody can enter and no obvious reason why.
/// It is only a suggestion: the field stays editable, because a school that
/// already prints "P5MATH" on its notice board should keep using it.
abstract final class JoinCode {
  /// Excludes the characters that get misread off a printed slip or a
  /// whiteboard: 0/O, 1/I/L, 5/S, 8/B, 2/Z.
  static const _alphabet = 'ACDEFGHJKMNPQRTUVWXY34679';

  static final _random = Random();

  /// A six-character suggestion. Short enough for a child to type, long enough
  /// that two classes in one school are unlikely to collide — and the database
  /// has a unique index as the real guard.
  static String suggest({int length = 6}) {
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ),
    );
  }

  /// True when [code] only uses characters this generator would produce, so a
  /// hand-typed code can be checked for the confusable ones before it is
  /// printed on anything.
  static bool isUnambiguous(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty) return false;
    return upper.split('').every(_alphabet.contains);
  }
}
