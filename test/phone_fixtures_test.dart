import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/utils/phone_number.dart';

// Phase 042: docs/contracts/fixtures/phone-cases.json is shared with the
// server test (backend/test/phone-fixtures.test.mjs), which checks the same
// numbers against private.is_supported_mobile. Both must agree.
void main() {
  final Map<String, dynamic> fixture = jsonDecode(
    File('docs/contracts/fixtures/phone-cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final List<Map<String, dynamic>> cases =
      (fixture['cases'] as List<dynamic>).cast<Map<String, dynamic>>();

  test('fixture is non-trivial', () {
    expect(cases.length, greaterThan(25));
    expect(cases.where((Map<String, dynamic> c) => c['e164'] == null), isNotEmpty);
  });

  for (final Map<String, dynamic> c in cases) {
    final String input = c['input'] as String;
    final String? expected = c['e164'] as String?;
    test('normalises ${jsonEncode(input)} -> ${expected ?? 'rejected'}', () {
      PhoneValidationError? error;
      final NormalizedPhone? phone =
          PhoneUtils.tryNormalize(input, onError: (PhoneValidationError e) => error = e);
      expect(phone?.e164, expected);
      if (expected == null) {
        expect(error?.name, c['error'], reason: 'error kind for ${jsonEncode(input)}');
      }
    });
  }

  test('every accepted number is canonical: +91, ten digits, first digit 6-9', () {
    final RegExp canonical = RegExp(r'^\+91[6-9][0-9]{9}$');
    for (final Map<String, dynamic> c in cases) {
      final String? e164 = c['e164'] as String?;
      if (e164 != null) expect(canonical.hasMatch(e164), isTrue, reason: e164);
    }
  });

  test('digit scripts used on Indian keyboards map to ASCII', () {
    expect(PhoneUtils.asciiDigits('०१२३४५६७८९'), '0123456789');
    expect(PhoneUtils.asciiDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(PhoneUtils.asciiDigits('０１２３４５６７８９'), '0123456789');
    expect(PhoneUtils.asciiDigits('a1'), 'a1');
  });

  test('server-facing values agree with the Dart verdict', () {
    final RegExp server = RegExp(r'^\+91[6-9][0-9]{9}$');
    for (final Map<String, dynamic> c in cases) {
      final String? raw = c['server'] as String?;
      if (raw == null) continue;
      final String e164 = raw.startsWith('+') ? raw : '+$raw';
      expect(server.hasMatch(e164), c['e164'] != null, reason: e164);
    }
  });
}
