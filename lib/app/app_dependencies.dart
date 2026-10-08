import '../data/local/key_value_store.dart';
import '../data/repositories/mock_auth_repository.dart';
import '../data/repositories/mock_data_store.dart';
import '../data/repositories/mock_location_repository.dart';
import '../data/repositories/mock_profile_support_repositories.dart';
import '../data/repositories/mock_provider_repository.dart';
import '../data/repositories/mock_report_and_engagement_repositories.dart';
import '../data/repositories/mock_service_catalog_repository.dart';
import '../data/supabase/auth_bootstrap.dart';
import '../data/supabase/auth_config.dart';
import '../data/live/live_location_repository.dart';
import '../data/live/live_provider_repository.dart';
import '../data/live/live_saved_provider_repository.dart';
import '../data/live/live_service_catalog_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/engagement_repository.dart';
import '../domain/repositories/location_repository.dart';
import '../domain/repositories/profile_support_repositories.dart';
import '../domain/repositories/provider_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/service_catalog_repository.dart';

/// A staging/production build has no usable backend. The app shows a blocked
/// screen with [reason]; it never falls back to the mocks. [reason] holds no
/// secret values.
class BackendBlockedException implements Exception {
  const BackendBlockedException(this.reason);

  final String reason;

  @override
  String toString() => 'BackendBlockedException($reason)';
}

/// Composition root.
///
/// One plain object wiring the concrete mock repositories to the domain
/// interfaces, so swapping in a real backend later is a change to this file
/// plus new implementations — no screen or controller edits.
///
/// No service locator package: a single explicit object is easier for one
/// developer to follow than global registration.
class AppDependencies {
  AppDependencies._({
    required this.keyValueStore,
    required this.dataStore,
    required this.locations,
    required this.catalog,
    required this.providers,
    required this.auth,
    required this.savedProviders,
    required this.drafts,
    required this.reports,
    required this.engagement,
    required this.promotions,
    required this.consents,
    required this.verification,
    required this.credentials,
  });

  /// Builds the mock-backed graph.
  ///
  /// [persist] is false in tests, which keeps every run independent.
  static Future<AppDependencies> mock({
    KeyValueStore? keyValueStore,
    bool persist = true,
    DateTime? now,
    ProviderAuthRepository? auth,
  }) async {
    final KeyValueStore kv = keyValueStore ?? InMemoryKeyValueStore();
    await kv.init();

    final MockDataStore dataStore = MockDataStore(
      store: kv,
      now: now,
      persist: persist,
    );

    final MockLocationRepository locations = MockLocationRepository(
      store: kv,
      now: now,
    );
    final MockServiceCatalogRepository catalog =
        MockServiceCatalogRepository();
    final MockProviderRepository providers = MockProviderRepository(
      store: dataStore,
      catalog: catalog,
      locations: locations,
      now: now,
    );
    // Warm locality names so a first search for "Bandra" already matches on
    // locality rather than needing a second keystroke.
    await providers.warmLocalityCache();

    return AppDependencies._(
      keyValueStore: kv,
      dataStore: dataStore,
      locations: locations,
      catalog: catalog,
      providers: providers,
      // A live (or fail-closed) repository replaces the simulation only when
      // the build asks for it; the default stays the mock.
      auth: auth ?? MockProviderAuthRepository(store: dataStore, now: now),
      savedProviders: MockSavedProviderRepository(
        store: dataStore,
        keyValueStore: kv,
      ),
      drafts: MockProviderDraftRepository(keyValueStore: kv),
      reports: MockReportRepository(store: dataStore),
      engagement: MockEngagementRepository(store: dataStore),
      promotions: MockPromotionRepository(store: dataStore, keyValueStore: kv),
      consents: MockConsentRepository(store: dataStore),
      verification: MockVerificationRepository(store: dataStore),
      credentials: MockCredentialRepository(store: dataStore),
    );
  }

  /// Picks the graph for a build (phase 061): `demo` is the mock graph (the
  /// default for `flutter run`/tests); `staging` and `production` are the live
  /// graph or a [BackendBlockedException]. A broken configuration or a failed
  /// SDK start never degrades to mocks, and [keyValueStore] only holds local
  /// preferences, so a storage failure cannot change which data is shown.
  static Future<AppDependencies> forEnvironment({
    required AuthConfig config,
    required KeyValueStore keyValueStore,
    bool persist = true,
    DateTime? now,
    Future<LiveBackend?> Function(AuthConfig, KeyValueStore)? startBackend,
  }) async {
    if (config.isDemo) {
      return mock(keyValueStore: keyValueStore, persist: persist, now: now);
    }
    final String? problem = config.problem;
    if (problem != null) throw BackendBlockedException(problem);
    await keyValueStore.init();
    final LiveBackend? backend =
        await (startBackend ?? startLiveBackend)(config, keyValueStore);
    if (backend == null) {
      throw const BackendBlockedException('the backend client failed to start');
    }
    return _live(keyValueStore, backend, now);
  }

  /// Live graph. Locations, catalog, discovery, owner profile, bookmarks and
  /// identity are backend-backed. The remaining repositories (reports,
  /// engagement, promotions, consents, verification, credentials) are still
  /// the mock implementations over an EMPTY, unseeded store until their
  /// phases land: they hold no fictional providers but also do not reach the
  /// backend yet.
  static AppDependencies _live(
    KeyValueStore kv,
    LiveBackend backend,
    DateTime? now,
  ) {
    final MockDataStore empty =
        MockDataStore(now: now, seed: false, persist: false);
    final LiveLocationRepository locations = LiveLocationRepository(
      gateway: backend.data,
      store: kv,
      now: now == null ? null : () => now,
    );
    final LiveProviderRepository providers =
        LiveProviderRepository(gateway: backend.data, locations: locations);
    return AppDependencies._(
      keyValueStore: kv,
      dataStore: empty,
      locations: locations,
      catalog: LiveServiceCatalogRepository(gateway: backend.data),
      providers: providers,
      auth: backend.auth,
      savedProviders: LiveSavedProviderRepository(
        keyValueStore: kv,
        providers: providers,
      ),
      drafts: MockProviderDraftRepository(keyValueStore: kv),
      reports: MockReportRepository(store: empty),
      engagement: MockEngagementRepository(store: empty),
      promotions: MockPromotionRepository(store: empty, keyValueStore: kv),
      consents: MockConsentRepository(store: empty),
      verification: MockVerificationRepository(store: empty),
      credentials: MockCredentialRepository(store: empty),
    );
  }

  final KeyValueStore keyValueStore;

  /// Exposed for tests that need to inspect or seed raw state. Screens and
  /// controllers must never use it.
  final MockDataStore dataStore;

  final LocationRepository locations;
  final ServiceCatalogRepository catalog;
  final ProviderRepository providers;
  final ProviderAuthRepository auth;
  final SavedProviderRepository savedProviders;
  final ProviderDraftRepository drafts;
  final ReportRepository reports;
  final EngagementRepository engagement;
  final PromotionRepository promotions;
  final ConsentRepository consents;
  final VerificationRepository verification;
  final CredentialRepository credentials;
}

/// Convenience so call sites read `repository.seedId` rather than poking at the
/// data layer.
extension AppDependenciesSeedIds on AppDependencies {
  /// Ids of the seeded non-published listings, used by tests and by the
  /// "sample data" explanation screen.
  String get pausedSeedProfileId => 'provider-seed-paused-001';
  String get draftSeedProfileId => 'provider-seed-draft-001';
}
