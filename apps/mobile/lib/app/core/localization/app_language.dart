import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:flutter/widgets.dart';

const appDisplaySettingsCacheKey = 'app_display_settings';

String normalizeAppLanguageCode(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == 'it' ? 'it' : 'en';
}

bool isItalianLanguageCode(String? value) {
  return normalizeAppLanguageCode(value) == 'it';
}

String appDateFormattingLocaleName(String? languageCode) {
  return isItalianLanguageCode(languageCode) ? 'it' : 'en';
}

String appLanguageCodeFromLocale(Locale locale) {
  return normalizeAppLanguageCode(locale.languageCode);
}

Future<String> readStoredAppLanguageCode(LocalDatabase localDatabase) async {
  final payload = await localDatabase.readCache(appDisplaySettingsCacheKey);
  if (payload == null || payload.trim().isEmpty) {
    return 'en';
  }

  try {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    return normalizeAppLanguageCode(decoded['language_preference']?.toString());
  } catch (_) {
    return 'en';
  }
}
