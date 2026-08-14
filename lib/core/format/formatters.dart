/// Small, dependency-free formatters shared across screens.
///
/// Deliberately not `intl`: the app ships three languages but has no
/// translated bundles yet, and these forms are short enough to localise by
/// hand when it does.
abstract final class Formatters {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `1 Sep 2026`.
  static String shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// `2h ago`, `Yesterday`, `3 days ago`, then a date.
  static String relative(DateTime at, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(at);

    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return shortDate(at);
  }

  /// `960,000` — thousands separated, no currency symbol.
  static String thousands(num value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  /// `960,000 RWF`.
  static String rwf(num value) => '${thousands(value)} RWF';

  /// `78%` from a 0..1 ratio.
  static String percent(double ratio) => '${(ratio * 100).round()}%';
}
