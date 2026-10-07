import 'package:flutter/widgets.dart';

import 'app_strings.dart';
import 'app_strings_hi.dart';
import 'app_strings_mr.dart';

export 'app_strings.dart';

/// Wires [AppStrings] into Flutter's localization system.
///
/// Adding a language is a pure data change: create the `AppStrings` subclass,
/// add it to [supportedStrings], and it becomes selectable with no screen
/// changes.
class AppLocalizations {
  const AppLocalizations(this.strings);

  final AppStrings strings;

  /// Every locale the interface can render. Order is the order shown in the
  /// language picker, and it is derived from the bundles themselves so the two
  /// can never drift apart.
  static const List<AppStrings> supportedStrings = <AppStrings>[
    AppStringsEn(),
    AppStringsHi(),
    AppStringsMr(),
  ];

  static List<Locale> get supportedLocales =>
      supportedStrings.map((AppStrings s) => s.locale).toList();

  static AppStrings stringsFor(Locale? locale) {
    if (locale == null) return const AppStringsEn();
    for (final AppStrings candidate in supportedStrings) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
    return const AppStringsEn();
  }

  static AppStrings stringsForCode(String? languageCode) =>
      stringsFor(languageCode == null ? null : Locale(languageCode));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((Locale l) => l.languageCode == locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(AppLocalizations.stringsFor(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// `context.strings.searchHint` — the only way screens read copy.
extension AppLocalizationsX on BuildContext {
  AppStrings get strings {
    final AppLocalizations? localizations =
        Localizations.of<AppLocalizations>(this, AppLocalizations);
    return localizations?.strings ?? const AppStringsEn();
  }
}
