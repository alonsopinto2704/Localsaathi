import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/data/supabase/auth_gateway.dart';
import 'package:localsaathi/data/supabase/wire.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/models/provider.dart';

import 'support/fake_data_gateway.dart';

// Phase 062: payload fixtures through the shared wire mapping.
void main() {
  RepositoryErrorCode? codeOf(void Function() f) {
    try {
      f();
    } on RepositoryException catch (e) {
      return e.code;
    }
    return null;
  }

  group('phase 062 profileFromWire', () {
    test('the shared public-profile contract fixture decodes', () {
      final Map<String, dynamic> body = (jsonDecode(
        File('docs/contracts/fixtures/public-profile.json').readAsStringSync(),
      ) as Map<String, dynamic>)['success']['response']['body']
          as Map<String, dynamic>;
      final ProviderProfile p = profileFromWire(body);
      expect(p.id, body['id']);
      expect(p.isPubliclyVisible, isTrue);
      expect(p.isDemoProfile, isFalse);
    });

    test('optional fields may be null or absent', () {
      final ProviderProfile p = profileFromWire(
        wireProfile(extra: <String, dynamic>{
          'description': null,
          'workingHours': null,
          'healthcareDetails': null,
          'mapLocation': null,
        },),
      );
      expect(p.description, isNull);
      expect(p.workingHours, isNull);
      expect(p.photos, isEmpty);
      expect(p.verification, isEmpty);
    });

    test('live data is never a demo profile, even if the payload says so', () {
      final ProviderProfile p = profileFromWire(
        wireProfile(extra: <String, dynamic>{'isDemoProfile': true}),
      );
      expect(p.isDemoProfile, isFalse);
    });

    test('unknown status is not published; unknown availability is not available',
        () {
      final ProviderProfile p = profileFromWire(
        wireProfile(
          status: 'reinstated',
          extra: <String, dynamic>{'availability': 'on_holiday'},
        ),
      );
      expect(p.isPubliclyVisible, isFalse);
      expect(p.availability, AvailabilityStatus.unavailable);
    });

    test('unknown or unapproved verification entries never read as verified',
        () {
      final ProviderProfile p = profileFromWire(
        wireProfile(
          extra: <String, dynamic>{
            'verification': <String, String>{
              'phone': 'approved',
              'credentials': 'granted_by_aliens',
              'retina': 'approved',
            },
          },
        ),
      );
      expect(p.isPhoneVerified, isTrue);
      expect(p.isCredentialsVerified, isFalse);
    });

    test('a missing or non-E.164 phone removes every contact action', () {
      for (final Object? phone in <Object?>[null, '', '9800000001', '+0123', 42]) {
        final ProviderProfile p = profileFromWire(
          wireProfile(
            extra: <String, dynamic>{'phoneE164': phone, 'whatsappEnabled': true},
          ),
        );
        expect(p.canBeCalled, isFalse, reason: '$phone');
        expect(p.canWhatsApp, isFalse, reason: '$phone');
      }
    });

    test('negative or non-numeric prices are dropped, valid ones kept', () {
      final ProviderProfile p = profileFromWire(
        wireProfile(
          extra: <String, dynamic>{
            'startingPrices': <Object>[
              <String, dynamic>{'categoryId': 'plumbing', 'amount': 250},
              <String, dynamic>{'categoryId': 'plumbing', 'amount': -5},
              <String, dynamic>{'categoryId': 'plumbing', 'amount': 'free'},
            ],
          },
        ),
      );
      expect(p.startingPrices.map((StartingPrice s) => s.amount), <int>[250]);
    });

    test('impossible payloads are rejected, not guessed', () {
      final List<Object?> bad = <Object?>[
        null,
        'text',
        <Object>[],
        <String, dynamic>{},
        wireProfile(extra: <String, dynamic>{'id': 7}),
        wireProfile(extra: <String, dynamic>{'id': ' '}),
        wireProfile(extra: <String, dynamic>{'createdAt': 'yesterday'}),
        wireProfile(extra: <String, dynamic>{'updatedAt': null}),
        wireProfile(
          extra: <String, dynamic>{
            'serviceAreas': <Object>[
              <String, dynamic>{'cityId': 3},
            ],
          },
        ),
      ];
      for (final Object? payload in bad) {
        expect(
          codeOf(() => profileFromWire(payload)),
          RepositoryErrorCode.unavailable,
          reason: '$payload',
        );
      }
    });
  });

  group('phase 062 helpers and errors', () {
    test('enumOr accepts snake_case and falls back conservatively', () {
      expect(enumOr(ListingStatus.values, 'published', ListingStatus.draft),
          ListingStatus.published,);
      expect(enumOr(ListingStatus.values, 'PUBLISHED', ListingStatus.draft),
          ListingStatus.published,);
      expect(enumOr(ListingStatus.values, 'live', ListingStatus.draft),
          ListingStatus.draft,);
      expect(enumOr(ListingStatus.values, 3, ListingStatus.draft),
          ListingStatus.draft,);
    });

    test('stable error prefixes map to domain codes; unknown is unavailable',
        () {
      const Map<String, RepositoryErrorCode> expected =
          <String, RepositoryErrorCode>{
        'not_owner': RepositoryErrorCode.notOwner,
        'not_found': RepositoryErrorCode.notFound,
        'validation_failed': RepositoryErrorCode.validationFailed,
        'location_not_active': RepositoryErrorCode.locationNotActive,
        'rate_limited': RepositoryErrorCode.unavailable,
        'brand_new_code': RepositoryErrorCode.unavailable,
      };
      expected.forEach((String prefix, RepositoryErrorCode code) {
        expect(repositoryErrorForRpc(GatewayRpcException(prefix)).code, code);
      });
      expect(
        repositoryErrorForGateway(
          const GatewayException(GatewayErrorKind.sessionRevoked),
        ).code,
        RepositoryErrorCode.notAuthenticated,
      );
    });

    test('guarded hides gateway and arbitrary exceptions behind domain errors',
        () async {
      await expectLater(
        guarded<void>(
          () async => throw const GatewayException(GatewayErrorKind.transient),
        ),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        guarded<void>(() async => throw StateError('socket body with token')),
        throwsA(
          isA<RepositoryException>().having(
            (RepositoryException e) => e.code,
            'code',
            RepositoryErrorCode.unavailable,
          ),
        ),
      );
    });
  });
}
