import 'dart:convert';

import 'package:clindiary/app/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguagePreference { en, it }

enum AppThemePreference { system, light, dark }

class AppDisplaySettings {
  const AppDisplaySettings({
    this.language = AppLanguagePreference.en,
    this.themePreference = AppThemePreference.system,
    this.textScale = 1.0,
  });

  factory AppDisplaySettings.fromJson(Map<String, dynamic> json) {
    return AppDisplaySettings(
      language: AppLanguagePreference.values.firstWhere(
        (value) => value.name == json['language_preference'],
        orElse: () => AppLanguagePreference.en,
      ),
      themePreference: AppThemePreference.values.firstWhere(
        (value) => value.name == json['theme_preference'],
        orElse: () => AppThemePreference.system,
      ),
      textScale: (json['text_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  final AppLanguagePreference language;
  final AppThemePreference themePreference;
  final double textScale;

  Locale get locale => Locale(language.name);

  ThemeMode get themeMode {
    switch (themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  AppDisplaySettings copyWith({
    AppLanguagePreference? language,
    AppThemePreference? themePreference,
    double? textScale,
  }) {
    return AppDisplaySettings(
      language: language ?? this.language,
      themePreference: themePreference ?? this.themePreference,
      textScale: textScale ?? this.textScale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_preference': language.name,
      'theme_preference': themePreference.name,
      'text_scale': textScale,
    };
  }
}

class AppDisplaySettingsController extends AsyncNotifier<AppDisplaySettings> {
  static const _cacheKey = 'app_display_settings';

  @override
  Future<AppDisplaySettings> build() async {
    final payload = await ref.watch(localDatabaseProvider).readCache(_cacheKey);
    if (payload == null || payload.isEmpty) {
      return const AppDisplaySettings();
    }

    try {
      final settings = AppDisplaySettings.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      return settings;
    } catch (_) {
      return const AppDisplaySettings();
    }
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    final current = state.valueOrNull ?? const AppDisplaySettings();
    await _persist(current.copyWith(themePreference: value));
  }

  Future<void> setLanguage(AppLanguagePreference value) async {
    final current = state.valueOrNull ?? const AppDisplaySettings();
    await _persist(current.copyWith(language: value));
  }

  Future<void> setTextScale(double value) async {
    final current = state.valueOrNull ?? const AppDisplaySettings();
    final normalized = value.clamp(0.85, 1.4).toDouble();
    await _persist(current.copyWith(textScale: normalized));
  }

  Future<void> reset() async {
    await _persist(const AppDisplaySettings());
  }

  Future<void> _persist(AppDisplaySettings next) async {
    state = AsyncData(next);
    await ref
        .read(localDatabaseProvider)
        .putCache(key: _cacheKey, payload: jsonEncode(next.toJson()));
  }
}

final appDisplaySettingsControllerProvider =
    AsyncNotifierProvider<AppDisplaySettingsController, AppDisplaySettings>(
      AppDisplaySettingsController.new,
    );
