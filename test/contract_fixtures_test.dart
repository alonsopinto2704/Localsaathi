import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/models/enums.dart';
import 'package:localsaathi/domain/models/moderation.dart';
import 'package:localsaathi/domain/models/provider.dart';

// Phase 014: replays the docs/contracts/fixtures wire payloads through the
// client decoders. Known decoder defects (phase-014.md #1, #4) are kept as
// skipped cases so the gap stays visible; remove `skip` when fixing them.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('docs/contracts/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

dynamic _at(Map<String, dynamic> json, String path) =>
    path.split('.').fold<dynamic>(json, (dynamic v, String k) => (v as Map<String, dynamic>)[k]);

Iterable<String> _normalizedCodes(dynamic node) sync* {
  if (node is Map<String, dynamic>) {
    final dynamic error = (node['normalized'] as Map<String, dynamic>?)?['error'] ??
        ((node['normalized'] as Map<String, dynamic>?)?['body'] as Map<String, dynamic>?)?['error'];
    if (error is Map<String, dynamic>) yield error['code'] as String;
    for (final dynamic v in node.values) {
      yield* _normalizedCodes(v);
    }
  } else if (node is List<dynamic>) {
    for (final dynamic v in node) {
      yield* _normalizedCodes(v);
    }
  }
}

void main() {
  final Map<String, String> profileBodies = <String, String>{
    'public-profile': 'success.response.body',
    'registration': 'success.response.body',
    'profile-edit': 'success.response.body',
  };

  for (final MapEntry<String, String> e in profileBodies.entries) {
    test('${e.key}: success body decodes as ProviderProfile', () {
      final Map<String, dynamic> body = _at(_fixture(e.key), e.value) as Map<String, dynamic>;
      final ProviderProfile profile = ProviderProfile.fromJson(body);
      expect(profile.id, body['id']);
      expect(profile.displayName, body['displayName']);
      expect(profile.categoryIds, body['categoryIds']);
    });
  }

  test('search: every item decodes as ProviderProfile', () {
    final List<dynamic> items = _at(_fixture('search'), 'success.response.body.items') as List<dynamic>;
    expect(items, isNotEmpty);
    for (final dynamic item in items) {
      final Map<String, dynamic> raw = (item as Map<String, dynamic>)['provider'] as Map<String, dynamic>;
      expect(ProviderProfile.fromJson(raw).id, raw['id']);
    }
  });

  test('registration: new registrant is phone verified (#5)', () {
    final Map<String, dynamic> body =
        _at(_fixture('registration'), 'success.response.body') as Map<String, dynamic>;
    expect(ProviderProfile.fromJson(body).isPhoneVerified, isTrue);
  });

  test('search: photo remoteUrl survives decoding (#4)', () {
    final List<dynamic> items = _at(_fixture('search'), 'success.response.body.items') as List<dynamic>;
    final Map<String, dynamic> photo = (items
            .map((dynamic i) => (i as Map<String, dynamic>)['provider'] as Map<String, dynamic>)
            .expand((Map<String, dynamic> p) => p['photos'] as List<dynamic>)
            .first) as Map<String, dynamic>;
    expect(jsonEncode(ProviderPhoto.fromJson(photo).toJson()), contains(photo['remoteUrl'] as String));
  });

  test('report: snake_case SQL reason decodes (#1)', () {
    final Map<String, dynamic> body =
        _at(_fixture('report'), 'success.request.body') as Map<String, dynamic>;
    final Report report = Report.fromJson(<String, dynamic>{
      'id': 'r1',
      'providerId': body['p_provider_id'],
      'reason': body['p_reason'],
    });
    expect(report.reason, ReportReason.wrongPhoneNumber);
  });

  test('every normalized error code maps to a RepositoryErrorCode', () {
    final List<dynamic> catalogue = _fixture('error-codes')['codes'] as List<dynamic>;
    final Map<String, String?> dartEnumByCode = <String, String?>{
      for (final dynamic c in catalogue)
        (c as Map<String, dynamic>)['code'] as String: c['dartEnum'] as String?,
    };
    final Set<String> enumNames =
        RepositoryErrorCode.values.map((RepositoryErrorCode c) => 'RepositoryErrorCode.${c.name}').toSet();
    for (final String name in <String>['search', 'public-profile', 'registration', 'profile-edit', 'report', 'deletion']) {
      for (final String code in _normalizedCodes(_fixture(name))) {
        expect(dartEnumByCode.containsKey(code), isTrue, reason: '$name: $code missing from error-codes.json');
        final String? dartEnum = dartEnumByCode[code];
        // Some codes map to an exception type (e.g. DuplicatePhoneNumberException).
        if (dartEnum != null && dartEnum.startsWith('RepositoryErrorCode.')) {
          expect(enumNames, contains(dartEnum), reason: '$name: $code');
        }
      }
    }
  });
}
