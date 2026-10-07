import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../data/local/key_value_store.dart';

/// App-wide preferences: interface language and the "welcome seen" flag.
///
/// Kept deliberately small. Language lives here rather than in each screen
/// because switching it must rebuild the whole app.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({required KeyValueStore keyValueStore}) : _kv = keyValueStore;

  final KeyValueStore _kv;

  Locale _locale = const Locale('en');
  bool _hasSeenWelcome = false;

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  /// Localizations delegates for `MaterialApp`.
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates =>
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ];

  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

  /// True once the customer has picked a location, which is what "seen the
  /// welcome screen" means. There is no long carousel to skip.
  bool get hasSeenWelcome => _hasSeenWelcome;

  void load() {
    final String? code = _kv.getString(StorageKeys.languageCode);
    if (code != null && code.isNotEmpty) _locale = Locale(code);
    _hasSeenWelcome = _kv.getString(StorageKeys.onboardingCompleted) == 'true';
    notifyListeners();
  }

  /// Switches the interface language and persists the choice.
  Future<void> setLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    await _kv.setString(StorageKeys.languageCode, languageCode);
    notifyListeners();
  }

  Future<void> markWelcomeSeen() async {
    if (_hasSeenWelcome) return;
    _hasSeenWelcome = true;
    await _kv.setString(StorageKeys.onboardingCompleted, 'true');
    notifyListeners();
  }

  /// Language options for the picker, taken from the localization layer so the
  /// list cannot drift out of sync with the available translations.
  List<({String code, String name})> get languageOptions => AppLocalizations
      .supportedStrings
      .map((AppStrings strings) =>
          (code: strings.languageCode, name: strings.languageName))
      .toList();
}
