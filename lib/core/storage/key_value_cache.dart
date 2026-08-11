import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small JSON key-value cache over SharedPreferences. Used to keep the
/// last-known catalog / memberships so an offline user still sees content.
/// Not for secrets — those live in [SecureStorage].
class KeyValueCache {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> setJson(String key, Object value) async {
    (await _p).setString(key, jsonEncode(value));
  }

  Future<Object?> getJson(String key) async {
    final raw = (await _p).getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async => (await _p).remove(key);
}

final keyValueCacheProvider = Provider<KeyValueCache>((ref) => KeyValueCache());
