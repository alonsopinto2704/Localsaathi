import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/controllers/location_controller.dart';
import 'package:localsaathi/app/controllers/provider_search_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/data/repositories/mock_report_and_engagement_repositories.dart';
import 'package:localsaathi/data/repositories/mock_data_store.dart';
import 'package:localsaathi/data/supabase/auth_gateway.dart';
import 'package:localsaathi/data/live/live_location_repository.dart';
import 'package:localsaathi/data/live/live_provider_repository.dart';
import 'package:localsaathi/data/live/live_saved_provider_repository.dart';
import 'package:localsaathi/data/live/live_service_catalog_repository.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/models/location.dart';
import 'package:localsaathi/domain/models/provider.dart';
import 'package:localsaathi/domain/models/service_category.dart';
import 'package:localsaathi/domain/repositories/provider_repository.dart';

import 'support/fake_data_gateway.dart';

ProviderSession _session({String? profileId = kProviderId, String account = 'acct-1'}) =>
    ProviderSession(
      accountId: account,
      phoneE164: '+919800000001',
      signedInAt: DateTime(2026, 10, 8),
      profileId: profileId,
    );

Future<void> _expectCode(Future<Object?> f, RepositoryErrorCode code) =>
    expectLater(
      f,
      throwsA(
        isA<RepositoryException>()
            .having((RepositoryException e) => e.code, 'code', code),
      ),
    );

void main() {
  group('phase 063 live locations', () {
    late FakeDataGateway gateway;
    late DateTime clock;
    late LiveLocationRepository repo;

    setUp(() {
      gateway = FakeDataGateway();
      seedReference(gateway);
      clock = DateTime(2026, 10, 8, 9);
      repo = LiveLocationRepository(
        gateway: gateway,
        store: InMemoryKeyValueStore(),
        now: () => clock,
      );
    });

    test('loads cities from the backend; unknown launch status is inactive',
        () async {
      final List<City> cities = await repo.availableCities();
      expect(cities.map((City c) => c.id), <String>['city-a', 'city-b']);
      expect((await repo.cityById('city-c'))!.launchStatus,
          CityLaunchStatus.inactive,);
      expect(await repo.isCityActive('city-c'), isFalse);
      expect((await repo.activeLaunchCity()).id, 'city-a');
      expect((await repo.defaultLocality('city-a'))!.id, 'loc-a2'); // popular
    });

    test('market activation arrives by data after the cache expires, without an update',
        () async {
      expect(await repo.isCityActive('city-b'), isFalse);
      final String? before = repo.revision;
      gateway.tables['cities']![1]['launch_status'] = 'active';
      expect(await repo.isCityActive('city-b'), isFalse, reason: 'still cached');
      clock = clock.add(const Duration(minutes: 16));
      expect(await repo.isCityActive('city-b'), isTrue);
      expect(repo.revision, isNot(before));
      expect(repo.isStale, isFalse);
    });

    test('a failed refresh serves the last copy and says it is stale',
        () async {
      await repo.availableCities();
      clock = clock.add(const Duration(minutes: 16));
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      expect((await repo.availableCities()).length, 2);
      expect(repo.isStale, isTrue);
      gateway.failure = null;
      await repo.availableCities();
      expect(repo.isStale, isFalse);
    });

    test('with no copy at all a failure is an error, never seed data', () async {
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      await _expectCode(repo.availableCities(), RepositoryErrorCode.unavailable);
    });

    test('a malformed row fails the load instead of inventing a city', () async {
      gateway.tables['cities']!.add(<String, dynamic>{'id': 'x'});
      await _expectCode(repo.availableCities(), RepositoryErrorCode.unavailable);
    });

    test('a deactivated city no longer resolves a saved selection', () async {
      expect(
        await repo.resolveSelection(cityId: 'city-a', localityId: 'loc-a1'),
        isNotNull,
      );
      gateway.tables['cities']![0]['launch_status'] = 'inactive';
      clock = clock.add(const Duration(minutes: 16));
      expect(
        await repo.resolveSelection(cityId: 'city-a', localityId: 'loc-a1'),
        isNull,
      );
      expect(
        await repo.resolveSelection(cityId: 'city-b', localityId: 'loc-a1'),
        isNull,
      );
    });

    test('requesting a city sends no phone and is remembered on-device',
        () async {
      gateway.handlers['request_city'] =
          (_) => <String, dynamic>{'receiptId': 'r-1', 'status': 'received'};
      final CityRequest r = await repo.requestCity(
        cityName: 'Delta',
        submittedByPhone: '+919800000001',
      );
      expect(r.id, 'r-1');
      expect(gateway.rpcParams.single!.keys,
          <String>['p_city_name', 'p_state_name', 'p_note'],);
      expect(await repo.hasRequestedCity(' delta '), isTrue);
    });

    test('city activation is not client-callable', () async {
      await _expectCode(
        repo.setCityLaunchStatus('city-b', CityLaunchStatus.active),
        RepositoryErrorCode.notOwner,
      );
    });

    test('the location controller reports a no-longer-valid choice instead of hiding it',
        () async {
      final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
      final LocationController controller =
          LocationController(locations: repo, keyValueStore: kv);
      gateway.tables['localities']!.add(<String, dynamic>{
        'id': 'loc-b1',
        'city_id': 'city-b',
        'name': 'Beta One',
      });
      await controller.select(cityId: 'city-a', localityId: 'loc-a1');
      gateway.tables['cities']![0]['launch_status'] = 'inactive';
      gateway.tables['cities']![1]['launch_status'] = 'active';
      clock = clock.add(const Duration(minutes: 16));
      await controller.load();
      expect(controller.unavailableSelection?.cityId, 'city-a');
      expect(controller.selection?.cityId, 'city-b');
    });
  });

  group('phase 064 live service catalog', () {
    late FakeDataGateway gateway;
    late LiveServiceCatalogRepository repo;

    setUp(() {
      gateway = FakeDataGateway();
      gateway.tables['service_groups'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'g2', 'name': 'Second', 'icon_key': 'cleaning', 'sort_order': 2},
        <String, dynamic>{'id': 'g1', 'name': 'First', 'icon_key': 'plumbing', 'sort_order': 1},
      ];
      gateway.tables['service_categories'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'c-clean', 'group_id': 'g2', 'name': 'Cleaner', 'icon_key': 'brand_new_icon', 'sort_order': 1, 'keywords': <String>['maid'], 'is_approved_for_launch': true, 'is_popular': true},
        <String, dynamic>{'id': 'c-plumb', 'group_id': 'g1', 'name': 'Plumber', 'icon_key': 'plumbing', 'sort_order': 1, 'keywords': <String>['tap'], 'is_approved_for_launch': true},
        <String, dynamic>{'id': 'c-old', 'group_id': 'g1', 'name': 'Retired Trade', 'icon_key': 'other', 'sort_order': 2, 'is_approved_for_launch': false},
        <String, dynamic>{'id': 'c-dent', 'group_id': 'g1', 'name': 'Dentist', 'icon_key': 'dental', 'sort_order': 3, 'is_healthcare': true},
      ];
      gateway.handlers['search_categories'] = (Map<String, dynamic>? p) => <Map<String, dynamic>>[
            <String, dynamic>{'id': 'c-old', 'groupId': 'g1', 'name': 'Retired Trade'},
            <String, dynamic>{'id': 'c-plumb', 'groupId': 'g1', 'name': 'Plumber'},
          ];
      repo = LiveServiceCatalogRepository(gateway: gateway);
    });

    test('lists are ordered by group then category and exclude unapproved ones',
        () async {
      expect((await repo.groups()).map((ServiceGroup g) => g.id), <String>['g1', 'g2']);
      expect((await repo.categories()).map((ServiceCategory c) => c.id),
          <String>['c-plumb', 'c-clean'],);
      expect((await repo.popularCategories()).single.id, 'c-clean');
      expect(await repo.healthcareCategories(), isEmpty,
          reason: 'missing approval flag is not approved',);
      expect((await repo.categoriesWithGroup()).first.group.id, 'g1');
    });

    test('a retired category still resolves by id for old links but is not launchable',
        () async {
      final ServiceCategory? old = await repo.categoryById('c-old');
      expect(old?.name, 'Retired Trade');
      expect(old!.isApprovedForLaunch, isFalse);
      expect((await repo.categoriesByIds(<String>['c-old', 'nope'])).length, 1);
      expect(await repo.requiresHealthcareDetails(<String>['c-dent']), isTrue);
    });

    test('unknown icon keys pass through; missing ones become other', () async {
      expect((await repo.categoryById('c-clean'))!.iconKey, 'brand_new_icon');
      gateway.tables['service_groups']![0].remove('icon_key');
      repo = LiveServiceCatalogRepository(gateway: gateway);
      expect((await repo.groupById('g2'))!.iconKey, CategoryIconKeys.other);
    });

    test('search uses the bounded RPC and never returns a retired category',
        () async {
      final List<ServiceCategory> hits = await repo.searchCategories('tap');
      expect(hits.map((ServiceCategory c) => c.id), <String>['c-plumb']);
      await repo.searchCategories('x' * 200);
      expect((gateway.rpcParams.last!['p_text'] as String).length, 80);
    });

    test('catalog is cached; an outage after load keeps serving it as stale',
        () async {
      DateTime clock = DateTime(2026, 10, 8);
      repo = LiveServiceCatalogRepository(gateway: gateway, now: () => clock);
      await repo.categories();
      final int loads = gateway.selectCount;
      await repo.categories();
      expect(gateway.selectCount, loads);
      clock = clock.add(const Duration(minutes: 16));
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      expect(await repo.categories(), isNotEmpty);
      expect(repo.isStale, isTrue);
    });
  });

  group('phase 065 bounded search', () {
    late FakeDataGateway gateway;
    late LiveProviderRepository repo;

    setUp(() {
      gateway = FakeDataGateway();
      seedReference(gateway);
      repo = LiveProviderRepository(
        gateway: gateway,
        locations: LiveLocationRepository(
          gateway: gateway,
          store: InMemoryKeyValueStore(),
        ),
      );
    });

    test('filters and paging map to the RPC within its bounds', () async {
      gateway.handlers['search_providers'] =
          (_) => <String, dynamic>{'totalCount': 0, 'items': <Object>[]};
      await repo.search(
        ProviderQuery(
          cityId: 'city-a',
          localityId: 'loc-a1',
          text: ' ${'y' * 100} ',
          categoryIds: List<String>.generate(30, (int i) => 'c$i'),
          localityFilterIds: <String>['loc-a2'],
          openNowOnly: true,
          homeVisitsOnly: true,
          limit: 500,
        ),
      );
      final Map<String, dynamic> p = gateway.rpcParams.single!;
      expect(p['p_city_id'], 'city-a');
      expect((p['p_text'] as String).length, 80);
      expect((p['p_category_ids'] as List<dynamic>).length, 20);
      expect(p['p_locality_filter_ids'], <String>['loc-a2']);
      expect(p['p_open_now_only'], isTrue);
      expect(p['p_home_visits_only'], isTrue);
      expect(p['p_limit'], 50);
      expect(gateway.calls, <String>['rpc:search_providers'],
          reason: 'no table download for client-side filtering',);
    });

    test('server ranking and sponsored flags are preserved; bad or hidden items dropped',
        () async {
      gateway.handlers['search_providers'] = (_) => <String, dynamic>{
            'totalCount': 7,
            'items': <Object>[
              <String, dynamic>{'isSponsored': true, 'provider': wireProfile(id: kOtherId, name: 'Paid')},
              <String, dynamic>{'isSponsored': false, 'provider': wireProfile(name: 'Zed Organic')},
              <String, dynamic>{'isSponsored': false, 'provider': wireProfile(id: 'aaaaaaaa-0000-0000-0000-000000000001', name: 'Paused', status: 'paused')},
              <String, dynamic>{'isSponsored': false, 'provider': <String, dynamic>{'id': 'broken'}},
              'not an object',
            ],
          };
      final ProviderSearchResults r = await repo.search(
        const ProviderQuery(cityId: 'city-a', localityId: 'loc-a1'),
      );
      expect(r.items.map((ProviderResultItem i) => i.provider.displayName),
          <String>['Paid', 'Zed Organic'],);
      expect(r.items.map((ProviderResultItem i) => i.isSponsored), <bool>[true, false]);
      expect(r.totalCount, 7);
      expect(r.isSampleData, isFalse);
    });

    test('a malformed envelope or an outage is an error, not an empty result',
        () async {
      gateway.handlers['search_providers'] = (_) => 'oops';
      await _expectCode(
        repo.search(const ProviderQuery(cityId: 'a', localityId: 'b')),
        RepositoryErrorCode.unavailable,
      );
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      await _expectCode(
        repo.search(const ProviderQuery(cityId: 'a', localityId: 'b')),
        RepositoryErrorCode.unavailable,
      );
    });

    test('rapid edits: an older, slower search never overwrites the newer one',
        () async {
      final Completer<Object?> slow = Completer<Object?>();
      gateway.handlers['search_providers'] = (Map<String, dynamic>? p) {
        if (p!['p_text'] == 'pl') return slow.future;
        return <String, dynamic>{
          'totalCount': 1,
          'items': <Object>[
            <String, dynamic>{'isSponsored': false, 'provider': wireProfile(name: 'Newest')},
          ],
        };
      };
      final ProviderSearchController controller = ProviderSearchController(
        repository: repo,
        engagement: MockEngagementRepository(store: MockDataStore(seed: false)),
      );
      final Future<void> first = controller.search(
        const ProviderQuery(cityId: 'city-a', localityId: 'loc-a1', text: 'pl'),
      );
      await controller.search(
        const ProviderQuery(cityId: 'city-a', localityId: 'loc-a1', text: 'plumber'),
      );
      expect(controller.items.single.provider.displayName, 'Newest');
      slow.complete(<String, dynamic>{
        'totalCount': 1,
        'items': <Object>[
          <String, dynamic>{'isSponsored': false, 'provider': wireProfile(name: 'Stale')},
        ],
      });
      await first;
      expect(controller.items.single.provider.displayName, 'Newest');
      expect(controller.isLoading, isFalse);
    });
  });

  group('phase 066 public profile', () {
    late FakeDataGateway gateway;
    late LiveProviderRepository repo;

    setUp(() {
      gateway = FakeDataGateway();
      seedReference(gateway);
      repo = LiveProviderRepository(
        gateway: gateway,
        locations: LiveLocationRepository(
          gateway: gateway,
          store: InMemoryKeyValueStore(),
        ),
      );
    });

    test('a published profile is returned from the public projection only',
        () async {
      gateway.handlers['get_public_profile'] = (_) => wireProfile();
      final ProviderProfile? p = await repo.publicProfileById(kProviderId);
      expect(p?.id, kProviderId);
      expect(gateway.calls, <String>['rpc:get_public_profile']);
    });

    test('hidden, unknown and junk ids are unavailable, never another provider',
        () async {
      gateway.handlers['get_public_profile'] = (_) => null;
      expect(await repo.publicProfileById(kProviderId), isNull);
      gateway.handlers['get_public_profile'] =
          (_) => wireProfile(status: 'paused');
      expect(await repo.publicProfileById(kProviderId), isNull);
      gateway.handlers['get_public_profile'] =
          (_) => wireProfile(id: kOtherId);
      await _expectCode(
        repo.publicProfileById(kProviderId),
        RepositoryErrorCode.unavailable,
      );
      gateway.calls.clear();
      expect(await repo.publicProfileById('../etc/passwd'), isNull);
      expect(gateway.calls, isEmpty);
    });

    test('an outage is an error, not "not found"', () async {
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      await _expectCode(
        repo.publicProfileById(kProviderId),
        RepositoryErrorCode.unavailable,
      );
    });

    test('similar, city list and counts use public RPCs and filter hidden entries',
        () async {
      gateway.handlers['similar_providers'] = (_) => <Object>[
            wireProfile(),
            wireProfile(id: kOtherId, name: 'Other'),
            wireProfile(id: 'bbbbbbbb-0000-0000-0000-000000000002', status: 'draft'),
          ];
      final ProviderProfile self = ProviderProfile.fromJson(wireProfile());
      final List<ProviderProfile> similar = await repo.similarProviders(self);
      expect(similar.map((ProviderProfile p) => p.id), <String>[kOtherId]);

      gateway.handlers['providers_published_in_city'] =
          (_) => <Object>[wireProfile(), <String, dynamic>{}];
      expect((await repo.publishedInCity('city-a')).length, 1);

      gateway.handlers['provider_count_by_locality'] =
          (_) => <String, dynamic>{'loc-a1': 3, 'loc-a2': -1, 'x': 'many'};
      expect(await repo.providerCountByLocality('city-a'), <String, int>{'loc-a1': 3});
    });

    test('bookmarks refresh via the public profile; hidden ones drop out, outages surface',
        () async {
      final InMemoryKeyValueStore kv = InMemoryKeyValueStore();
      final LiveSavedProviderRepository saved =
          LiveSavedProviderRepository(keyValueStore: kv, providers: repo);
      await saved.save(kProviderId);
      await saved.save(kOtherId);
      gateway.handlers['get_public_profile'] = (Map<String, dynamic>? p) =>
          p!['p_id'] == kProviderId ? wireProfile() : null;
      expect((await saved.savedProfiles()).map((ProviderProfile p) => p.id),
          <String>[kProviderId],);
      expect(await saved.savedIds(), {kProviderId, kOtherId}, reason: 'ids stay on device');
      gateway.failure = const GatewayException(GatewayErrorKind.transient);
      await expectLater(saved.savedProfiles(), throwsA(isA<RepositoryException>()));
    });
  });

  group('phase 067 owner profile', () {
    late FakeDataGateway gateway;
    late LiveProviderRepository repo;

    setUp(() {
      gateway = FakeDataGateway();
      seedReference(gateway);
      repo = LiveProviderRepository(
        gateway: gateway,
        locations: LiveLocationRepository(
          gateway: gateway,
          store: InMemoryKeyValueStore(),
        ),
      );
    });

    test('a guessed profile id is refused before any request', () async {
      await _expectCode(
        repo.profileByIdForOwner(profileId: kOtherId, session: _session()),
        RepositoryErrorCode.notOwner,
      );
      await _expectCode(
        repo.profileByIdForOwner(profileId: kProviderId, session: _session(profileId: null)),
        RepositoryErrorCode.notOwner,
      );
      await _expectCode(
        repo.updateProfile(
          profile: ProviderProfile.fromJson(wireProfile(id: kOtherId)),
          session: _session(),
        ),
        RepositoryErrorCode.notOwner,
      );
      await _expectCode(
        repo.deleteListing(profileId: kOtherId, session: _session()),
        RepositoryErrorCode.notOwner,
      );
      expect(gateway.calls, isEmpty);
    });

    test('the server still decides: not_owner and a revoked session surface as domain errors',
        () async {
      gateway.handlers['get_owner_profile'] =
          (_) => throw const GatewayRpcException('not_owner');
      await _expectCode(
        repo.profileByIdForOwner(profileId: kProviderId, session: _session()),
        RepositoryErrorCode.notOwner,
      );
      gateway.handlers['get_owner_profile'] = (_) =>
          throw const GatewayException(GatewayErrorKind.sessionRevoked);
      await _expectCode(
        repo.profileByIdForOwner(profileId: kProviderId, session: _session()),
        RepositoryErrorCode.notAuthenticated,
      );
      gateway.handlers['get_owner_profile'] = (_) => null;
      expect(
        await repo.profileByIdForOwner(profileId: kProviderId, session: _session()),
        isNull,
      );
    });

    test('an owner read returns private status; the repository keeps nothing between calls',
        () async {
      gateway.handlers['get_owner_profile'] = (_) =>
          wireProfile(status: 'paused', extra: <String, dynamic>{'revision': 4});
      final ProviderProfile? p = await repo.profileByIdForOwner(
        profileId: kProviderId,
        session: _session(),
      );
      expect(p?.status, ListingStatus.paused);
      // A different account asking for the same id gets the server's answer,
      // not the earlier account's data.
      gateway.handlers['get_owner_profile'] = (_) => null;
      expect(
        await repo.profileByIdForOwner(
          profileId: kProviderId,
          session: _session(account: 'acct-2'),
        ),
        isNull,
      );
    });

    test('an edit sends only provider-editable keys', () async {
      gateway.handlers['update_profile_full'] = (_) => wireProfile(name: 'Edited');
      final ProviderProfile edited =
          ProviderProfile.fromJson(wireProfile(name: 'Edited'));
      final ProviderProfile saved =
          await repo.updateProfile(profile: edited, session: _session());
      expect(saved.displayName, 'Edited');
      final Map<String, dynamic> params = gateway.rpcParams.single!;
      expect(params['p_profile_id'], kProviderId);
      final Map<String, dynamic> patch = params['p_patch'] as Map<String, dynamic>;
      for (final String forbidden in <String>[
        'id', 'phoneE164', 'status', 'verification', 'createdAt',
        'isDemoProfile', 'moderationStatus', 'revision',
      ]) {
        expect(patch.containsKey(forbidden), isFalse, reason: forbidden);
      }
      expect(patch['displayName'], 'Edited');
    });

    test('status, availability and delete go through their RPCs', () async {
      gateway.handlers['set_listing_status'] =
          (Map<String, dynamic>? p) => wireProfile(status: p!['p_status'] as String);
      gateway.handlers['set_availability'] = (Map<String, dynamic>? p) =>
          wireProfile(extra: <String, dynamic>{'availability': p!['p_availability']});
      gateway.handlers['delete_listing'] = (_) => null;
      expect(
        (await repo.publish(profileId: kProviderId, session: _session())).status,
        ListingStatus.published,
      );
      expect(
        (await repo.setListingStatus(
          profileId: kProviderId,
          status: ListingStatus.paused,
          session: _session(),
        ))
            .status,
        ListingStatus.paused,
      );
      expect(
        (await repo.setAvailability(
          profileId: kProviderId,
          availability: AvailabilityStatus.busy,
          session: _session(),
        ))
            .availability,
        AvailabilityStatus.busy,
      );
      await repo.deleteListing(profileId: kProviderId, session: _session());
      await _expectCode(
        repo.setListingStatus(
          profileId: kProviderId,
          status: ListingStatus.deleted,
          session: _session(),
        ),
        RepositoryErrorCode.validationFailed,
      );
    });

    test('registration is not done here', () async {
      await _expectCode(
        repo.createProfile(
          phoneE164: '+919800000001',
          displayName: 'x',
          baseCityId: 'city-a',
          baseLocalityId: 'loc-a1',
          categoryIds: <String>[],
          serviceAreaIds: <String>[],
          session: _session(),
        ),
        RepositoryErrorCode.unavailable,
      );
    });
  });
}
