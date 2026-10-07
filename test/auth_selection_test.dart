import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/data/repositories/mock_auth_repository.dart';
import 'package:localsaathi/data/supabase/auth_config.dart';
import 'package:localsaathi/data/supabase/auth_selection.dart';
import 'package:localsaathi/data/supabase/otp_cooldown.dart';
import 'package:localsaathi/data/supabase/supabase_provider_auth_repository.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/repositories/auth_repository.dart';

import 'support/fake_auth_gateway.dart';

// Phases 041, 056, 060: the build environment decides the identity backend,
// production can never end up on the simulation, and nothing a reviewer or
// attacker can type authenticates without a server-issued code.

String _jwt(Map<String, dynamic> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part(<String, String>{'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  late AppDependencies deps;
  late FakeAuthGateway gateway;

  setUp(() async {
    deps = await AppDependencies.mock(
      keyValueStore: InMemoryKeyValueStore(),
      persist: false,
    );
    gateway = FakeAuthGateway();
  });

  ProviderAuthRepository demo() => deps.auth;
  ProviderAuthRepository live() => SupabaseProviderAuthRepository(
        gateway: gateway,
        cooldown: OtpCooldown(store: InMemoryKeyValueStore()),
      );

  final String goodKey = _jwt(<String, String>{'role': 'anon'});
  const String https = 'https://example-project.supabase.co';

  test('LS_ENV parsing: only demo/staging are recognised, anything else is production', () {
    expect(AuthEnvironment.parse('demo'), AuthEnvironment.demo);
    expect(AuthEnvironment.parse(' Staging '), AuthEnvironment.staging);
    expect(AuthEnvironment.parse('production'), AuthEnvironment.production);
    expect(AuthEnvironment.parse(''), AuthEnvironment.production);
    expect(AuthEnvironment.parse('prod-ish'), AuthEnvironment.production);
    expect(AuthEnvironment.parse('DEMO!'), AuthEnvironment.production);
  });

  test('the default build (no dart-defines) is demo with the mock', () {
    final AuthConfig config = AuthConfig.fromEnvironment();
    expect(config.environment, AuthEnvironment.demo);
    expect(selectAuthRepository(config: config, demo: demo, live: live),
        isA<MockProviderAuthRepository>(),);
  });

  test('demo uses the mock even when live config is present', () {
    final AuthConfig config = AuthConfig(
      environment: AuthEnvironment.demo,
      supabaseUrl: https,
      anonKey: goodKey,
    );
    expect(selectAuthRepository(config: config, demo: demo, live: live),
        isA<MockProviderAuthRepository>(),);
  });

  test('staging and production with valid config use the live repository', () {
    for (final AuthEnvironment env in <AuthEnvironment>[
      AuthEnvironment.staging,
      AuthEnvironment.production,
    ]) {
      final AuthConfig config =
          AuthConfig(environment: env, supabaseUrl: https, anonKey: goodKey);
      expect(config.problem, isNull);
      expect(selectAuthRepository(config: config, demo: demo, live: live),
          isA<SupabaseProviderAuthRepository>(),);
    }
  });

  group('missing or unsafe production configuration fails closed', () {
    final Map<String, AuthConfig> bad = <String, AuthConfig>{
      'no url': AuthConfig(environment: AuthEnvironment.production, anonKey: goodKey),
      'no key': const AuthConfig(environment: AuthEnvironment.production, supabaseUrl: https),
      'http url': AuthConfig(
        environment: AuthEnvironment.production,
        supabaseUrl: 'http://example-project.supabase.co',
        anonKey: goodKey,
      ),
      'local http in production': AuthConfig(
        environment: AuthEnvironment.production,
        supabaseUrl: 'http://localhost:54321',
        anonKey: goodKey,
      ),
      'service-role key': AuthConfig(
        environment: AuthEnvironment.production,
        supabaseUrl: https,
        anonKey: _jwt(<String, String>{'role': 'service_role'}),
      ),
      'secret-format key': const AuthConfig(
        environment: AuthEnvironment.production,
        supabaseUrl: https,
        anonKey: 'sb_secret_synthetic_not_real',
      ),
      'empty staging': const AuthConfig(environment: AuthEnvironment.staging),
    };
    for (final MapEntry<String, AuthConfig> e in bad.entries) {
      test(e.key, () async {
        expect(e.value.hasLiveConfig, isFalse);
        final ProviderAuthRepository repo =
            selectAuthRepository(config: e.value, demo: demo, live: live);
        expect(repo, isA<FailClosedAuthRepository>());
        expect(repo, isNot(isA<MockProviderAuthRepository>()));
        // Guests are unaffected; sign-in simply cannot succeed.
        expect(await repo.restoreSession(), isNull);
        expect((await repo.requestOtp('9000012345')).isSuccess, isFalse);
        await expectLater(
          repo.verifyOtp(challengeId: 'x', code: '123456'),
          throwsA(isA<OtpException>()),
        );
        await expectLater(
          repo.registerProfile(
            submission: RegistrationSubmission(
              phoneE164: '+919000040001',
              session: ProviderSession(
                accountId: 'x',
                phoneE164: '+919000040001',
                signedInAt: DateTime.utc(2026, 10, 7),
              ),
              displayName: 'X',
              baseCityId: 'c',
              baseLocalityId: 'l',
              categoryIds: const <String>[],
              serviceAreaIds: const <String>[],
            ),
          ),
          throwsA(isA<RepositoryException>()),
        );
      });
    }

    test('local http is allowed for staging only', () {
      final AuthConfig config = AuthConfig(
        environment: AuthEnvironment.staging,
        supabaseUrl: 'http://127.0.0.1:54321',
        anonKey: goodKey,
      );
      expect(config.problem, isNull);
    });

    test('the reason never contains the configured values', () {
      final AuthConfig config = AuthConfig(
        environment: AuthEnvironment.production,
        supabaseUrl: 'http://secret-host.example',
        anonKey: _jwt(<String, String>{'role': 'service_role'}),
      );
      final String reason = FailClosedAuthRepository(config.problem!).reason;
      expect(reason, isNot(contains('secret-host')));
      expect(reason, isNot(contains(config.anonKey)));
    });
  });

  group('the demo code cannot authenticate against a live backend', () {
    test('the fixed development code is not accepted by the live repository', () async {
      final ProviderAuthRepository repo = live();
      final OtpChallengeResult r = await repo.requestOtp('9000040001');
      expect(r.isSuccess, isTrue);
      expect(r.challenge!.simulatedCode, isEmpty);
      await expectLater(
        repo.verifyOtp(challengeId: r.challenge!.id, code: '123456'),
        throwsA(isA<OtpException>()),
      );
      expect(gateway.currentSession, isNull);
    });

    test('the demo repository is only reachable through a demo config', () {
      for (final AuthEnvironment env in <AuthEnvironment>[
        AuthEnvironment.staging,
        AuthEnvironment.production,
      ]) {
        for (final AuthConfig config in <AuthConfig>[
          AuthConfig(environment: env),
          AuthConfig(environment: env, supabaseUrl: https, anonKey: goodKey),
        ]) {
          expect(
            selectAuthRepository(config: config, demo: demo, live: live),
            isNot(isA<MockProviderAuthRepository>()),
          );
        }
      }
    });
  });
}
