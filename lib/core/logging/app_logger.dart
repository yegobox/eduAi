import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal structured logger. Swap the sink for Sentry/Crashlytics later
/// without touching call sites.
class AppLogger {
  const AppLogger(this._tag);

  final String _tag;

  void debug(Object? message) => _log('DEBUG', message);
  void info(Object? message) => _log('INFO', message);
  void warn(Object? message) => _log('WARN', message);

  void error(Object? message, [Object? error, StackTrace? stack]) {
    _log('ERROR', message, error: error, stack: stack);
  }

  void _log(String level, Object? message, {Object? error, StackTrace? stack}) {
    // Keep noise out of release builds; ship a real sink in production.
    if (kReleaseMode && level == 'DEBUG') return;
    developer.log(
      '$message',
      name: '$_tag/$level',
      error: error,
      stackTrace: stack,
    );

    // `developer.log` alone reaches the VM service — DevTools' Logging tab —
    // but not the `flutter run` terminal, which is where anybody debugging a
    // failed payment is actually looking. Mirroring warnings and errors to
    // debugPrint makes them visible there and in the browser console, at the
    // cost of a duplicate line in DevTools.
    if (kReleaseMode || level == 'DEBUG' || level == 'INFO') return;
    debugPrint('[$_tag/$level] $message');
    if (error != null) debugPrint('[$_tag/$level]   cause: $error');
  }
}
