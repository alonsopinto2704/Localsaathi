import 'package:flutter/foundation.dart';

import '../../data/local/key_value_store.dart';
import '../../domain/models/location.dart';
import '../../domain/repositories/location_repository.dart';

/// Where the customer is browsing, for the whole app.
///
/// The selection is persisted locally and restored on start-up. Manual
/// selection is the default everywhere; location permission is optional and
/// never required, so nothing here depends on a GPS fix.
class LocationController extends ChangeNotifier {
  LocationController({
    required LocationRepository locations,
    required KeyValueStore keyValueStore,
  })  : _locations = locations,
        _kv = keyValueStore;

  final LocationRepository _locations;
  final KeyValueStore _kv;

  LocationSelection? _selection;
  City? _activeCity;
  bool _isLoading = true;
  String? _errorMessage;

  /// The customer's chosen locality and city, once resolved.
  LocationSelection? get selection => _selection;

  /// The live market the app is currently browsing.
  City? get activeCity => _activeCity;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasSelection => _selection != null;

  /// True as soon as a selection exists, even if the market is coming soon.
  bool get isReady => !_isLoading && _selection != null;

  /// Loads the persisted selection, falling back to the active launch market.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final City activeCity = await _locations.activeLaunchCity();
      _activeCity = activeCity;

      final Map<String, dynamic>? stored =
          _kv.getJson(StorageKeys.selectedLocation);
      LocationSelection? restored =
          stored == null ? null : LocationSelection.fromJson(stored);

      // A stored selection is only honoured if it still resolves: a locality
      // can be renamed or a city deactivated between releases.
      if (restored != null) {
        final LocationSelection? verified = await _locations.resolveSelection(
          cityId: restored.cityId,
          localityId: restored.localityId,
        );
        restored = verified;
      }

      if (restored == null) {
        final Locality? locality =
            await _locations.defaultLocality(activeCity.id);
        if (locality != null) {
          restored = await _locations.resolveSelection(
            cityId: activeCity.id,
            localityId: locality.id,
          );
        }
      }

      _selection = restored;
    } on Object catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a locality and persists it.
  ///
  /// Returns false when the pair does not resolve, which is what the caller
  /// shows as a validation message rather than silently keeping the old value.
  Future<bool> select({
    required String cityId,
    required String localityId,
  }) async {
    final LocationSelection? resolved = await _locations.resolveSelection(
      cityId: cityId,
      localityId: localityId,
    );
    if (resolved == null) return false;

    _selection = resolved;
    _activeCity = await _locations.cityById(cityId);
    await _kv.setJson(StorageKeys.selectedLocation, resolved.toJson());
    notifyListeners();
    return true;
  }

  /// Records a "please open my city" request. Mock submission: it is stored on
  /// this device and never sent anywhere yet.
  Future<CityRequestResult> requestCity({
    required String cityName,
    String? stateName,
    String? note,
    String? submittedByPhone,
  }) async {
    final String trimmed = cityName.trim();
    if (trimmed.isEmpty) return CityRequestResult.emptyInput;
    if (await _locations.hasRequestedCity(trimmed)) {
      return CityRequestResult.alreadyRequested;
    }
    await _locations.requestCity(
      cityName: trimmed,
      stateName: stateName,
      note: note,
      submittedByPhone: submittedByPhone,
    );
    return CityRequestResult.submitted;
  }

  Future<List<CityRequest>> cityRequests() => _locations.pendingCityRequests();

  /// The active launch market, for copy that must name it without hardcoding.
  Future<City> launchCity() => _locations.activeLaunchCity();
}

enum CityRequestResult { submitted, alreadyRequested, emptyInput }
