import 'dart:math';

import '../../core/config/app_config.dart';
import '../../domain/models/location.dart';
import '../../domain/repositories/location_repository.dart';
import '../local/key_value_store.dart';
import '../seed/location_seed.dart';

/// In-memory location repository backed by the seed data.
///
/// Launch status and city requests mutate in memory and are mirrored to local
/// storage so a restart keeps them. In production these reads come from the
/// backend and [setCityLaunchStatus] becomes an admin-only operation — the
/// interface stays identical, so no screen changes.
class MockLocationRepository implements LocationRepository {
  MockLocationRepository({KeyValueStore? store, DateTime? now})
      : _store = store,
        _now = now ?? DateTime.now();

  /// Overridable clock, so tests are deterministic.
  final DateTime _now;

  final KeyValueStore? _store;

  /// Mutable copy of the seeded launch statuses, keyed by city id.
  Map<String, CityLaunchStatus>? _statusOverrides;

  List<CityRequest>? _requests;

  static const String _statusKey = '${StorageKeys.prefix}city_status_overrides';
  static const String _requestsKey = StorageKeys.cityRequests;

  // ------------------------------------------------------------- lazy state
  Map<String, CityLaunchStatus> get _statuses {
    final Map<String, CityLaunchStatus>? existing = _statusOverrides;
    if (existing != null) return existing;

    final Map<String, CityLaunchStatus> statuses = <String, CityLaunchStatus>{
      for (final City city in LocationSeed.cities) city.id: city.launchStatus,
    };

    final Map<String, dynamic>? stored = _store?.getJson(_statusKey);
    if (stored != null) {
      stored.forEach((String key, Object? value) {
        if (value is! String) return;
        final CityLaunchStatus? parsed = _parseStatus(value);
        if (parsed != null && statuses.containsKey(key)) {
          statuses[key] = parsed;
        }
      });
    }

    _statusOverrides = statuses;
    return statuses;
  }

  List<CityRequest> get _requestList {
    final List<CityRequest>? existing = _requests;
    if (existing != null) return existing;
    final List<CityRequest> loaded = _store
            ?.getJsonList(_requestsKey)
            .map(CityRequest.fromJson)
            .toList() ??
        <CityRequest>[];
    _requests = loaded;
    return loaded;
  }

  static CityLaunchStatus? _parseStatus(String raw) {
    for (final CityLaunchStatus status in CityLaunchStatus.values) {
      if (status.name == raw) return status;
    }
    return null;
  }

  /// Applies the current launch-status overrides to a seeded city.
  City _applyStatus(City city) {
    final CityLaunchStatus? override = _statuses[city.id];
    if (override == null || override == city.launchStatus) return city;
    return City(
      id: city.id,
      stateId: city.stateId,
      name: city.name,
      launchStatus: override,
      aliases: city.aliases,
      isMetro: city.isMetro,
    );
  }

  Future<void> _persistStatuses() async {
    final KeyValueStore? store = _store;
    if (store == null) return;
    await store.setJson(
      _statusKey,
      _statuses.map(
        (String key, CityLaunchStatus value) =>
            MapEntry<String, String>(key, value.name),
      ),
    );
  }

  Future<void> _persistRequests() async {
    final KeyValueStore? store = _store;
    if (store == null) return;
    await store.setJsonList(
      _requestsKey,
      _requestList.map((CityRequest r) => r.toJson()).toList(),
    );
  }

  // ---------------------------------------------------------------- queries
  @override
  Future<List<Country>> countries() async => <Country>[LocationSeed.india];

  @override
  Future<Country?> countryById(String id) async =>
      id == LocationSeed.india.id ? LocationSeed.india : null;

  @override
  Future<List<StateRegion>> states(String countryId) async {
    if (countryId != LocationSeed.india.id) return <StateRegion>[];
    // Active states first, then alphabetical: the picker should open on the
    // markets that actually work without hiding the rest.
    final List<StateRegion> list = LocationSeed.states
        .where((StateRegion s) => s.countryId == countryId)
        .toList();
    list.sort((StateRegion a, StateRegion b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<StateRegion?> stateById(String id) async {
    for (final StateRegion state in LocationSeed.states) {
      if (state.id == id) return state;
    }
    return null;
  }

  @override
  Future<List<City>> citiesByState(String stateId) async {
    final List<City> list = LocationSeed.cities
        .where((City c) => c.stateId == stateId)
        .map(_applyStatus)
        .toList();
    list.sort((City a, City b) {
      if (a.launchStatus != b.launchStatus) {
        return a.launchStatus.index.compareTo(b.launchStatus.index);
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<City?> cityById(String id) async {
    for (final City city in LocationSeed.cities) {
      if (city.id == id) return _applyStatus(city);
    }
    return null;
  }

  @override
  Future<List<City>> availableCities({
    String countryId = 'in',
    bool includeComingSoon = true,
  }) async {
    final Set<String> stateIds = LocationSeed.states
        .where((StateRegion s) => s.countryId == countryId)
        .map((StateRegion s) => s.id)
        .toSet();

    final List<City> list = LocationSeed.cities
        .where((City c) =>
            stateIds.contains(c.stateId) &&
            _applyStatus(c).launchStatus.isVisibleInPicker &&
            (includeComingSoon ||
                _applyStatus(c).launchStatus == CityLaunchStatus.active))
        .map(_applyStatus)
        .toList();

    list.sort((City a, City b) {
      // Active markets first, metros before smaller cities inside each band.
      if (a.launchStatus != b.launchStatus) {
        return a.launchStatus.index.compareTo(b.launchStatus.index);
      }
      if (a.isMetro != b.isMetro) return a.isMetro ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<List<Locality>> localities(String cityId) async {
    final List<Locality> list = LocationSeed.localities
        .where((Locality l) => l.cityId == cityId)
        .toList();
    list.sort((Locality a, Locality b) {
      if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<Locality?> localityById(String id) async {
    for (final Locality locality in LocationSeed.localities) {
      if (locality.id == id) return locality;
    }
    return null;
  }

  @override
  Future<City> activeLaunchCity({String? preferredCityId}) async {
    if (preferredCityId != null) {
      final City? preferred = await cityById(preferredCityId);
      if (preferred != null && preferred.isSelectable) return preferred;
    }
    for (final City city in LocationSeed.cities) {
      final City applied = _applyStatus(city);
      if (applied.isSelectable) return applied;
    }
    // Defensive: a build configured with no active city must still start. It
    // falls back to the configured default market rather than throwing.
    final City? fallback = await cityById(AppConfig.defaultCityId);
    if (fallback != null) return fallback;
    return _applyStatus(LocationSeed.cities.first);
  }

  @override
  Future<Locality?> defaultLocality(String cityId) async {
    final List<Locality> list = await localities(cityId);
    if (list.isEmpty) return null;
    for (final Locality locality in list) {
      if (locality.isPopular) return locality;
    }
    return list.first;
  }

  @override
  Future<LocationSelection?> resolveSelection({
    required String cityId,
    required String localityId,
  }) async {
    final City? city = await cityById(cityId);
    final Locality? locality = await localityById(localityId);
    if (city == null || locality == null) return null;
    if (locality.cityId != city.id) return null;
    final StateRegion? state = await stateById(city.stateId);
    return LocationSelection(
      countryId: state?.countryId ?? LocationSeed.india.id,
      stateId: city.stateId,
      cityId: city.id,
      localityId: locality.id,
      cityName: city.name,
      stateName: state?.name ?? '',
      localityName: locality.name,
      pinCode: locality.pinCode,
    );
  }

  @override
  Future<bool> isCityActive(String cityId) async {
    final City? city = await cityById(cityId);
    return city?.isSelectable ?? false;
  }

  @override
  Future<void> setCityLaunchStatus(
    String cityId,
    CityLaunchStatus status,
  ) async {
    if (!_statuses.containsKey(cityId)) return;
    _statuses[cityId] = status;
    await _persistStatuses();
  }

  // -------------------------------------------------------- city requests
  @override
  Future<CityRequest> requestCity({
    required String cityName,
    String? stateName,
    String? note,
    String? submittedByPhone,
  }) async {
    final String trimmed = cityName.trim();
    final CityRequest request = CityRequest(
      id: 'cityreq-${_now.microsecondsSinceEpoch}-${_randomSuffix()}',
      cityName: trimmed,
      requestedAt: _now,
      stateName: stateName,
      note: note,
      submittedByPhone: submittedByPhone,
    );
    _requestList.insert(0, request);
    await _persistRequests();
    return request;
  }

  @override
  Future<List<CityRequest>> pendingCityRequests() async =>
      List<CityRequest>.unmodifiable(_requestList);

  @override
  Future<bool> hasRequestedCity(String cityName) async {
    final String needle = cityName.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return _requestList
        .any((CityRequest r) => r.cityName.trim().toLowerCase() == needle);
  }

  @override
  Future<List<City>> searchCities(
    String query, {
    String countryId = 'in',
  }) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return <City>[];

    final Set<String> stateIds = LocationSeed.states
        .where((StateRegion s) => s.countryId == countryId)
        .map((StateRegion s) => s.id)
        .toSet();

    final List<City> list = LocationSeed.cities
        .where((City c) =>
            stateIds.contains(c.stateId) &&
            _applyStatus(c).launchStatus.isVisibleInPicker)
        .map(_applyStatus)
        .where((City c) =>
            c.name.toLowerCase().contains(needle) ||
            c.aliases.any((String a) => a.toLowerCase().contains(needle)))
        .toList();

    list.sort((City a, City b) {
      // Prefix matches first: typing "mum" should surface Mumbai above Salem.
      final bool aPrefix = a.name.toLowerCase().startsWith(needle);
      final bool bPrefix = b.name.toLowerCase().startsWith(needle);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      if (a.launchStatus != b.launchStatus) {
        return a.launchStatus.index.compareTo(b.launchStatus.index);
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  static final Random _random = Random(20260105);

  static String _randomSuffix() =>
      _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
}
