import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/backend_blocked_app.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/data/repositories/mock_location_repository.dart';
import 'package:localsaathi/data/repositories/mock_provider_repository.dart';
import 'package:localsaathi/data/supabase/auth_bootstrap.dart';
import 'package:localsaathi/data/supabase/auth_config.dart';
import 'package:localsaathi/data/supabase/auth_selection.dart';
import 'package:localsaathi/data/live/live_location_repository.dart';
import 'package:localsaathi/data/live/live_provider_repository.dart';
import 'package:localsaathi/data/live/live_service_catalog_repository.dart';
import 'package:localsaathi/domain/models/provider.dart';
import 'package:localsaathi/domain/repositories/provider_repository.dart';

import 'support/fake_data_gateway.dart';

// Phase 061: which graph each environment gets.
void main() {
  const AuthConfig goodProduction = AuthConfig(
    environment: AuthEnvironment.production,
    supabaseUrl: 'https://example-project.supabase.co',
    anonKey: 'sb_publishable_synthetic',
  );
  const FailClosedAuthRepository stubAuth = FailClosedAuthRepository('stub');

  Future<AppDependencies> build(
    AuthConfig config, {
    LiveBackend? backend,
    bool persist = true,
  }) =>
      AppDependencies.forEnvironment(
        config: config,
        keyValueStore: InMemoryKeyValueStore(),
        persist: persist,
        startBackend: (AuthConfig c, KeyValueStore s) async => backend,
      );

  group('phase 061 composition root', () {
    test('demo builds get the mock graph', () async {
      final AppDependencies deps = await build(
        const AuthConfig(environment: AuthEnvironment.demo),
        persist: false,
      );
      expect(deps.providers, isA<MockProviderRepository>());
      expect(deps.locations, isA<MockLocationRepository>());
    });

    test('staging and production with bad config are blocked, never mock',
        () async {
      final LiveBackend backend =
          LiveBackend(data: FakeDataGateway(), auth: stubAuth);
      for (final AuthEnvironment env in <AuthEnvironment>[
        AuthEnvironment.staging,
        AuthEnvironment.production,
      ]) {
        for (final AuthConfig config in <AuthConfig>[
          AuthConfig(environment: env),
          AuthConfig(
            environment: env,
            supabaseUrl: 'http://example.com',
            anonKey: 'k',
          ),
          AuthConfig(environment: env, supabaseUrl: 'https://x.supabase.co'),
        ]) {
          await expectLater(
            build(config, backend: backend),
            throwsA(isA<BackendBlockedException>()),
            reason: '${env.name} ${config.supabaseUrl}',
          );
        }
      }
    });

    test('a release build with LS_ENV unset is blocked, even with a good URL',
        () async {
      final LiveBackend backend =
          LiveBackend(data: FakeDataGateway(), auth: stubAuth);
      await expectLater(
        build(
          AuthConfig.resolve(
            rawEnv: '',
            release: true,
            supabaseUrl: 'https://example-project.supabase.co',
            anonKey: 'sb_publishable_synthetic',
          ),
          backend: backend,
        ),
        throwsA(isA<BackendBlockedException>()
            .having((BackendBlockedException e) => e.reason, 'reason', contains('LS_ENV')),),
      );
    });

    test('good config but the client fails to start is blocked', () async {
      await expectLater(
        build(goodProduction),
        throwsA(
          isA<BackendBlockedException>().having(
            (BackendBlockedException e) => e.reason,
            'reason',
            contains('failed to start'),
          ),
        ),
      );
    });

    test('the blocked reason never contains the configured values', () async {
      try {
        await build(
          const AuthConfig(
            environment: AuthEnvironment.production,
            supabaseUrl: 'https://example-project.supabase.co',
            anonKey: 'sb_secret_leaked',
          ),
        );
        fail('should be blocked');
      } on BackendBlockedException catch (e) {
        expect(e.reason, isNot(contains('sb_secret_leaked')));
        expect(e.reason, isNot(contains('example-project')));
      }
    });

    test('a started backend gets live repositories and no fictional providers',
        () async {
      final FakeDataGateway gateway = FakeDataGateway()
        ..handlers['search_providers'] = (_) => <String, dynamic>{
              'totalCount': 1,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'isSponsored': false,
                  'provider': wireProfile(name: 'Server Provider'),
                },
              ],
            };
      final AppDependencies deps = await build(
        goodProduction,
        backend: LiveBackend(data: gateway, auth: stubAuth),
      );
      expect(deps.providers, isA<LiveProviderRepository>());
      expect(deps.locations, isA<LiveLocationRepository>());
      expect(deps.catalog, isA<LiveServiceCatalogRepository>());
      expect(deps.auth, same(stubAuth));
      expect(deps.dataStore.profilesById, isEmpty);
      expect(gateway.calls, isEmpty, reason: 'building makes no request');

      final ProviderSearchResults r = await deps.providers.search(
        const ProviderQuery(cityId: 'city-a', localityId: 'loc-a1'),
      );
      expect(
        r.providers.map((ProviderProfile p) => p.displayName),
        <String>['Server Provider'],
      );
      expect(r.providers.single.isDemoProfile, isFalse);
    });

    test('a failing backend is an error, not seeded providers', () async {
      final FakeDataGateway gateway = FakeDataGateway()
        ..failure = StateError('down');
      final AppDependencies deps = await build(
        goodProduction,
        backend: LiveBackend(data: gateway, auth: stubAuth),
      );
      await expectLater(
        deps.providers
            .search(const ProviderQuery(cityId: 'a', localityId: 'b')),
        throwsA(isA<Object>()),
      );
      await expectLater(
        deps.locations.activeLaunchCity(),
        throwsA(isA<Object>()),
      );
    });

    test('in-memory preferences (storage failure) still give a live graph',
        () async {
      // main() hands a live build an in-memory store when storage cannot open.
      final AppDependencies deps = await build(
        goodProduction,
        backend: LiveBackend(data: FakeDataGateway(), auth: stubAuth),
        persist: false,
      );
      expect(deps.providers, isA<LiveProviderRepository>());
    });
  });

  testWidgets('blocked screen explains what to fix and shows no providers',
      (WidgetTester tester) async {
    await tester
        .pumpWidget(const BackendBlockedApp(reason: 'SUPABASE_URL is missing'));
    expect(find.textContaining('missing its backend configuration'),
        findsOneWidget,);
    expect(find.byKey(const Key('blocked-reason')), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsWidgets);
  });
}
