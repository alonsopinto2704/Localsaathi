import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/controllers/app_settings_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';

// Regression: with only DefaultMaterialLocalizations registered, choosing
// Hindi or Marathi left Material widgets (back button, navigation bar) without
// MaterialLocalizations and they rendered as error boxes.
void main() {
  for (final String code in <String>['en', 'hi', 'mr']) {
    test('Material and Widgets localizations support "$code"', () {
      final AppSettingsController settings =
          AppSettingsController(keyValueStore: InMemoryKeyValueStore());
      final Locale locale = Locale(code);
      for (final Type type in <Type>[MaterialLocalizations, WidgetsLocalizations]) {
        expect(
          settings.localizationsDelegates
              .any((LocalizationsDelegate<dynamic> d) => d.type == type && d.isSupported(locale)),
          isTrue,
          reason: '$type has no delegate for $code',
        );
      }
    });
  }
}
