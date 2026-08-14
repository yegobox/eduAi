import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_cache.dart';

/// The three languages EduAI ships for Rwandan classrooms.
enum AppLanguage {
  english('en', 'English'),
  kinyarwanda('rw', 'Kinyarwanda'),
  french('fr', 'Français');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage.english,
  );
}

/// The user's chosen interface language, persisted across launches.
///
/// The preference is stored and surfaced today; wiring it to
/// `MaterialApp.locale` waits on the translated ARB bundles — switching the
/// locale before then would only strip Material's own localisations
/// (`flutter_localizations` ships no `rw`) without translating any EduAI copy.
class AppLanguageController extends AsyncNotifier<AppLanguage> {
  static const _cacheKey = 'app_language';

  @override
  Future<AppLanguage> build() async {
    final raw = await ref.read(keyValueCacheProvider).getJson(_cacheKey);
    return AppLanguage.fromCode(raw is String ? raw : null);
  }

  Future<void> select(AppLanguage language) async {
    state = AsyncData(language);
    await ref.read(keyValueCacheProvider).setJson(_cacheKey, language.code);
  }
}

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );
