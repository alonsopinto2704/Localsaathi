import '../../domain/models/account.dart';
import '../../domain/models/location.dart';
import '../../domain/repositories/location_repository.dart';
import '../local/key_value_store.dart';
import '../supabase/data_gateway.dart';
import '../supabase/ref_cache.dart';
import '../supabase/wire.dart';

/// Locations from the backend (phase 063). Reads are public `SELECT`s of the
/// reference tables; a market going live is a data change and shows up here
/// within [ttl] without an app update.
///
/// Reference data is cached in memory with a [revision] (a content hash: the
/// backend has no revision column) and an expiry. If a refresh fails the last
/// copy is still served but [isStale] turns true so the UI can say so; with no
/// copy at all the error propagates. Nothing is ever substituted from seeds.
class LiveLocationRepository implements LocationRepository {
  LiveLocationRepository({
    required DataGateway gateway,
    required KeyValueStore store,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 15),
  })  : _gateway = gateway,
        _store = store,
        _now = now ?? DateTime.now;

  final DataGateway _gateway;
  final KeyValueStore _store;
  final DateTime Function() _now;
  final Duration ttl;

  late final RefCache<_Reference> _ref = RefCache<_Reference>(
    _fetch,
    now: _now,
    ttl: ttl,
  );
  final Map<String, RefCache<List<Locality>>> _localityCaches =
      <String, RefCache<List<Locality>>>{};

  /// True while the data served is older than [ttl] because a refresh failed.
  bool get isStale =>
      _ref.isStale || _localityCaches.values.any((RefCache<List<Locality>> c) => c.isStale);

  /// Changes whenever any city, state or launch status changes.
  String? get revision => _ref.value?.revision;

  Future<_Reference> _reference() => _ref.get();

  Future<_Reference> _fetch() async => _Reference(
        countries: (await _gateway.selectRows('countries', orderBy: 'name'))
            .map(_country)
            .toList(),
        states: (await _gateway.selectRows('state_regions', orderBy: 'name'))
            .map(_state)
            .toList(),
        cities: (await _gateway.selectRows('cities', orderBy: 'name'))
            .map(cityFromWire)
            .toList(),
      );

  // --------------------------------------------------------------- mapping
  static Country _country(Map<String, dynamic> r) => Country(
        id: reqString(r, 'id'),
        name: reqString(r, 'name'),
        isoCode: optString(r, 'iso_code') ?? '',
        dialCode: optString(r, 'dial_code') ?? '',
        isActive: boolOr(r, 'is_active', false),
      );

  static StateRegion _state(Map<String, dynamic> r) => StateRegion(
        id: reqString(r, 'id'),
        countryId: reqString(r, 'country_id'),
        name: reqString(r, 'name'),
        isUnionTerritory: boolOr(r, 'is_union_territory', false),
        isActive: boolOr(r, 'is_active', false),
      );

  /// Works for table rows (`launch_status`) and `search_cities` results
  /// (`launchStatus`). An unknown status is `inactive`, never `active`.
  static City cityFromWire(Map<String, dynamic> r) => City(
        id: reqString(r, 'id'),
        stateId:
            reqString(r, r.containsKey('state_id') ? 'state_id' : 'stateId'),
        name: reqString(r, 'name'),
        launchStatus: enumOr(CityLaunchStatus.values,
            r['launch_status'] ?? r['launchStatus'], CityLaunchStatus.inactive,),
        aliases: stringList(r, 'aliases'),
        isMetro: boolOr(
            r, r.containsKey('is_metro') ? 'is_metro' : 'isMetro', false,),
      );

  static Locality _locality(Map<String, dynamic> r) => Locality(
        id: reqString(r, 'id'),
        cityId: reqString(r, 'city_id'),
        name: reqString(r, 'name'),
        pinCode: optString(r, 'pin_code'),
        isPopular: boolOr(r, 'is_popular', false),
      );

  // ---------------------------------------------------------------- queries
  @override
  Future<List<Country>> countries() async =>
      (await _reference()).countries.where((Country c) => c.isActive).toList();

  @override
  Future<Country?> countryById(String id) async =>
      _first((await _reference()).countries.where((Country c) => c.id == id));

  @override
  Future<List<StateRegion>> states(String countryId) async =>
      (await _reference())
          .states
          .where((StateRegion s) => s.countryId == countryId)
          .toList();

  @override
  Future<StateRegion?> stateById(String id) async =>
      _first((await _reference()).states.where((StateRegion s) => s.id == id));

  @override
  Future<List<City>> citiesByState(String stateId) async =>
      (await _reference()).cities.where((City c) => c.stateId == stateId).toList();

  @override
  Future<City?> cityById(String id) async =>
      _first((await _reference()).cities.where((City c) => c.id == id));

  @override
  Future<List<City>> availableCities({
    String countryId = 'in',
    bool includeComingSoon = true,
  }) async {
    final _Reference ref = await _reference();
    final Set<String> stateIds = ref.states
        .where((StateRegion s) => s.countryId == countryId)
        .map((StateRegion s) => s.id)
        .toSet();
    return ref.cities
        .where((City c) =>
            stateIds.contains(c.stateId) &&
            (c.isActive ||
                (includeComingSoon &&
                    c.launchStatus == CityLaunchStatus.comingSoon)),)
        .toList();
  }

  @override
  Future<List<Locality>> localities(String cityId) =>
      (_localityCaches[cityId] ??= RefCache<List<Locality>>(
        () async => (await _gateway.selectRows('localities',
                eq: <String, String>{'city_id': cityId}, orderBy: 'name',))
            .map(_locality)
            .toList(),
        now: _now,
        ttl: ttl,
      ))
          .get();

  @override
  Future<Locality?> localityById(String id) async {
    for (final RefCache<List<Locality>> cached in _localityCaches.values) {
      for (final Locality l in cached.value ?? <Locality>[]) {
        if (l.id == id) return l;
      }
    }
    final List<Map<String, dynamic>> rows = await guarded(() =>
        _gateway.selectRows('localities', eq: <String, String>{'id': id}),);
    return rows.isEmpty ? null : _locality(rows.first);
  }

  /// First active city (name order; ponytail: add a backend sort column when a
  /// second market launches). Throws when no market is active.
  @override
  Future<City> activeLaunchCity({String? preferredCityId}) async {
    final List<City> active =
        (await _reference()).cities.where((City c) => c.isActive).toList();
    for (final City c in active) {
      if (c.id == preferredCityId) return c;
    }
    if (active.isEmpty) {
      throw const RepositoryException(
          RepositoryErrorCode.locationNotActive, 'no active market',);
    }
    return active.first;
  }

  @override
  Future<Locality?> defaultLocality(String cityId) async {
    final List<Locality> all = await localities(cityId);
    for (final Locality l in all) {
      if (l.isPopular) return l;
    }
    return all.isEmpty ? null : all.first;
  }

  /// Null unless the city is active and the locality belongs to it, so a
  /// deactivated market or removed locality is surfaced, not papered over.
  @override
  Future<LocationSelection?> resolveSelection({
    required String cityId,
    required String localityId,
  }) async {
    final _Reference ref = await _reference();
    final City? city = _first(ref.cities.where((City c) => c.id == cityId));
    if (city == null || !city.isSelectable) return null;
    final Locality? locality = _first(
        (await localities(cityId)).where((Locality l) => l.id == localityId),);
    final StateRegion? state =
        _first(ref.states.where((StateRegion s) => s.id == city.stateId));
    if (locality == null || state == null) return null;
    return LocationSelection(
      countryId: state.countryId,
      stateId: state.id,
      cityId: city.id,
      localityId: locality.id,
      cityName: city.name,
      stateName: state.name,
      localityName: locality.name,
      pinCode: locality.pinCode,
    );
  }

  @override
  Future<bool> isCityActive(String cityId) async =>
      _first((await _reference()).cities.where((City c) => c.id == cityId))
          ?.isActive ??
      false;

  /// Market activation is an administrator operation (a reasoned, audited RPC),
  /// never a client call.
  @override
  Future<void> setCityLaunchStatus(String cityId, CityLaunchStatus status) =>
      Future<void>.error(const RepositoryException(
          RepositoryErrorCode.notOwner, 'admin operation',),);

  // --------------------------------------------------- requests (on-device)
  @override
  Future<CityRequest> requestCity({
    required String cityName,
    String? stateName,
    String? note,
    String? submittedByPhone,
  }) async {
    final Object? receipt = await guarded(() => _gateway.rpc(
          'request_city',
          <String, dynamic>{
            'p_city_name': cityName,
            'p_state_name': stateName,
            'p_note': note,
          },
        ),);
    // The phone is set server-side from the session, never sent from here.
    final CityRequest request = CityRequest(
      id: optString(asMap(receipt), 'receiptId') ??
          'request-${_now().microsecondsSinceEpoch}',
      cityName: cityName,
      requestedAt: _now(),
      stateName: stateName,
      note: note,
    );
    final List<Map<String, dynamic>> stored =
        _store.getJsonList(StorageKeys.cityRequests)..add(request.toJson());
    await _store.setJsonList(StorageKeys.cityRequests, stored);
    return request;
  }

  @override
  Future<List<CityRequest>> pendingCityRequests() async => _store
      .getJsonList(StorageKeys.cityRequests)
      .map(CityRequest.fromJson)
      .toList();

  @override
  Future<bool> hasRequestedCity(String cityName) async {
    final String wanted = cityName.trim().toLowerCase();
    return (await pendingCityRequests())
        .any((CityRequest r) => r.cityName.trim().toLowerCase() == wanted);
  }

  @override
  Future<List<City>> searchCities(String query,
      {String countryId = 'in',}) async {
    final String text = query.trim();
    if (text.isEmpty) return <City>[];
    final Object? raw = await guarded(() => _gateway.rpc(
          'search_cities',
          <String, dynamic>{
            'p_text': text.length > 80 ? text.substring(0, 80) : text,
            'p_country_id': countryId,
          },
        ),);
    return asRows(raw).map(cityFromWire).toList();
  }

  static T? _first<T>(Iterable<T> items) => items.isEmpty ? null : items.first;
}

class _Reference {
  _Reference({
    required this.countries,
    required this.states,
    required this.cities,
  }) : revision = Object.hashAll(<Object>[
          for (final City c in cities) ...<Object>[c.id, c.launchStatus.name],
          for (final StateRegion s in states) ...<Object>[s.id, s.isActive],
        ]).toRadixString(16);

  final List<Country> countries;
  final List<StateRegion> states;
  final List<City> cities;
  final String revision;
}
