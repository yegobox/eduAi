import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifiers for Supabase/PostgREST errors that more than one feature needs.
///
/// Lives in `core` because both the auth feature (reading `profiles.role`) and
/// the access feature (calling `access_state()`) have to tell "these objects do
/// not exist" apart from "something went wrong reaching them", and neither
/// should import the other.
abstract final class PostgrestErrors {
  /// Postgres' undefined_table / undefined_function, plus PostgREST's own
  /// schema-cache answers for an unknown function (`PGRST202`) and unknown
  /// table (`PGRST205`) — those carry no SQLSTATE, so both spellings matter.
  static const _missingSchemaCodes = {
    '42P01',
    '42883',
    'PGRST202',
    'PGRST205',
  };

  /// True when the server is saying the object does not exist, i.e. a migration
  /// has not been applied — not that the request failed.
  ///
  /// Worth distinguishing because the two want opposite handling: a transient
  /// failure should fall back and retry quietly, while a missing schema should
  /// be shouted about, since it silently switches roles and billing off.
  static bool isMissingSchema(PostgrestException e) {
    if (_missingSchemaCodes.contains(e.code)) return true;
    final text = '${e.message} ${e.details ?? ''}'.toLowerCase();
    return text.contains('could not find the function') ||
        text.contains('could not find the table') ||
        text.contains('does not exist');
  }
}
