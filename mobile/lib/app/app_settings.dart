import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'preferences.dart';

/// The interface language chosen in More. [system] follows the phone.
enum LanguagePreference {
  system,
  en,
  ru;

  /// The locale to force, or null to follow the system.
  Locale? get locale => switch (this) {
    LanguagePreference.system => null,
    LanguagePreference.en => const Locale('en'),
    LanguagePreference.ru => const Locale('ru'),
  };
}

/// Appearance settings stored on the device.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.language = LanguagePreference.system,
  });

  /// Light by default; Dark and System are opt-in.
  final ThemeMode themeMode;
  final LanguagePreference language;

  AppSettings copyWith({ThemeMode? themeMode, LanguagePreference? language}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.language == language;

  @override
  int get hashCode => Object.hash(themeMode, language);
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const themeModeKey = 'settings.themeMode';
  static const languageKey = 'settings.language';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      themeMode:
          _byName(ThemeMode.values, prefs.getString(themeModeKey)) ??
          ThemeMode.light,
      language:
          _byName(LanguagePreference.values, prefs.getString(languageKey)) ??
          LanguagePreference.system,
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(themeModeKey, themeMode.name);
  }

  Future<void> setLanguage(LanguagePreference language) async {
    state = state.copyWith(language: language);
    await ref
        .read(sharedPreferencesProvider)
        .setString(languageKey, language.name);
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

/// The language code the UI is shown in (`en` or `ru`): the user's choice,
/// else the first supported system language, else English. Mirrors
/// Flutter's default locale resolution, which the app uses.
String effectiveLanguageCode(
  LanguagePreference preference,
  List<Locale> systemLocales,
) {
  final forced = preference.locale;
  if (forced != null) return forced.languageCode;
  final supported = AppLocalizations.supportedLocales
      .map((locale) => locale.languageCode)
      .toSet();
  for (final locale in systemLocales) {
    if (supported.contains(locale.languageCode)) return locale.languageCode;
  }
  return AppLocalizations.supportedLocales.first.languageCode;
}
