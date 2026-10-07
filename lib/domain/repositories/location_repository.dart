import '../models/location.dart';

/// Read/write access to the location hierarchy.
///
/// The UI only ever asks this repository what exists and what is active, so
/// activating a new city never touches screen code. The mock implementation
/// returns seeded data; the production implementation will call the backend and
/// the interface stays the same.
abstract class LocationRepository {
  /// Countries the product supports.
  Future<List<Country>> countries();

  Future<Country?> countryById(String id);

  /// States / Union Territories of [countryId].
  Future<List<StateRegion>> states(String countryId);

  Future<StateRegion?> stateById(String id);

  /// Every city in [stateId], including inactive ones, so the model is
  /// nationwide rather than launch-only.
  Future<List<City>> citiesByState(String stateId);

  Future<City?> cityById(String id);

  /// Cities that are pickable today. `includeComingSoon` powers the
  /// "coming soon" section of the picker.
  Future<List<City>> availableCities({
    String countryId = 'in',
    bool includeComingSoon = true,
  });

  /// Localities of [cityId]. May be empty for a coming-soon city.
  Future<List<Locality>> localities(String cityId);

  Future<Locality?> localityById(String id);

  /// The active market the app opens on, resolved from launch status rather
  /// than hardcoded. Returns the first active city when
  /// [preferredCityId] is null or not active.
  Future<City> activeLaunchCity({String? preferredCityId});

  /// First locality of a city, used to give a fresh install a complete
  /// selection.
  Future<Locality?> defaultLocality(String cityId);

  /// Resolves ids into a display-ready [LocationSelection].
  Future<LocationSelection?> resolveSelection({
    required String cityId,
    required String localityId,
  });

  /// True when the city is active and may be browsed or registered into.
  Future<bool> isCityActive(String cityId);

  /// Toggles a city's launch status.
  ///
  /// Exposed because "another city can be activated through data without
  /// rewriting the UI" is a requirement we verify in tests. In production this
  /// is an admin/backend operation and would not be client-callable.
  Future<void> setCityLaunchStatus(String cityId, CityLaunchStatus status);

  /// Records a "please open my city" request. Mock submission: it is stored
  /// locally, not sent anywhere.
  Future<CityRequest> requestCity({
    required String cityName,
    String? stateName,
    String? note,
    String? submittedByPhone,
  });

  /// Requests already made from this device.
  Future<List<CityRequest>> pendingCityRequests();

  /// Case-insensitive check so a user cannot spam the same request.
  Future<bool> hasRequestedCity(String cityName);

  /// Free-text search across city names and aliases.
  Future<List<City>> searchCities(String query, {String countryId = 'in'});
}
