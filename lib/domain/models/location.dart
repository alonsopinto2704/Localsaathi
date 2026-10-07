import 'enums.dart';
export 'enums.dart';

/// Country.
///
/// The product is India-first but not India-only: nothing in the location
/// hierarchy assumes a single country, and the dial code lives with the
/// country record rather than in screen code.
class Country {
  const Country({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.isActive,
  });

  final String id;
  final String name;

  /// ISO 3166-1 alpha-2, e.g. `IN`.
  final String isoCode;

  /// E.164 dialling code without `+`, e.g. `91`.
  final String dialCode;

  final bool isActive;

  @override
  String toString() => '$name ($isoCode)';
}

/// State or Union Territory. Purely a grouping level for cities.
class StateRegion {
  const StateRegion({
    required this.id,
    required this.countryId,
    required this.name,
    this.isUnionTerritory = false,
    this.isActive = true,
  });

  final String id;
  final String countryId;
  final String name;

  /// Union Territories are grouped with states for navigation simplicity, but
  /// the distinction is preserved because it is legally meaningful in India.
  final bool isUnionTerritory;

  /// Whether any city in this state is available yet. Used to sort the picker.
  final bool isActive;

  @override
  String toString() => name;
}

/// City and its launch status.
///
/// [launchStatus] is the single switch that turns a market on. The app reads it
/// at runtime; there is no `if (city == 'Mumbai')` anywhere in the UI.
class City {
  const City({
    required this.id,
    required this.stateId,
    required this.name,
    required this.launchStatus,
    this.aliases = const <String>[],
    this.isMetro = false,
  });

  final String id;
  final String stateId;
  final String name;
  final CityLaunchStatus launchStatus;

  /// Alternate names people actually type, used by city search.
  final List<String> aliases;

  final bool isMetro;

  bool get isActive => launchStatus == CityLaunchStatus.active;

  /// Whether this city can be selected as the browsing market right now.
  bool get isSelectable => launchStatus.isSelectable;

  /// True when the city is a separate market from any other city. Surrounding
  /// cities (Thane, Navi Mumbai, Vasai-Virar) are explicitly *not* folded into
  /// Mumbai; each has its own id and its own launch status.
  String get marketLabel => name;

  @override
  String toString() => name;
}

/// Locality inside a city, optionally tied to a PIN code.
class Locality {
  const Locality({
    required this.id,
    required this.cityId,
    required this.name,
    this.pinCode,
    this.isPopular = false,
  });

  final String id;
  final String cityId;
  final String name;

  /// Optional; a locality may span several PIN codes, so this is indicative
  /// only and never used as an identifier.
  final String? pinCode;

  /// Surfaced first in the picker.
  final bool isPopular;

  @override
  String toString() => name;
}

/// A province/city/locality triple resolved against the repository.
///
/// Everything the UI needs about "where am I" in one immutable value, so
/// screens never juggle three loose ids.
class LocationSelection {
  const LocationSelection({
    required this.countryId,
    required this.stateId,
    required this.cityId,
    required this.localityId,
    required this.cityName,
    required this.stateName,
    required this.localityName,
    this.pinCode,
  });

  final String countryId;
  final String stateId;
  final String cityId;
  final String localityId;
  final String cityName;
  final String stateName;
  final String localityName;
  final String? pinCode;

  /// "Andheri West, Mumbai" — used in the home app bar and provider cards.
  String get shortLabel => '$localityName, $cityName';

  String get fullLabel => '$localityName, $cityName, $stateName';

  LocationSelection copyWith({
    String? countryId,
    String? stateId,
    String? cityId,
    String? localityId,
    String? cityName,
    String? stateName,
    String? localityName,
    String? pinCode,
  }) {
    return LocationSelection(
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      cityId: cityId ?? this.cityId,
      localityId: localityId ?? this.localityId,
      cityName: cityName ?? this.cityName,
      stateName: stateName ?? this.stateName,
      localityName: localityName ?? this.localityName,
      pinCode: pinCode ?? this.pinCode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'countryId': countryId,
        'stateId': stateId,
        'cityId': cityId,
        'localityId': localityId,
        'cityName': cityName,
        'stateName': stateName,
        'localityName': localityName,
        'pinCode': pinCode,
      };

  static LocationSelection? fromJson(Map<String, dynamic> json) {
    final Object? cityId = json['cityId'];
    final Object? localityId = json['localityId'];
    if (cityId is! String || localityId is! String) return null;
    return LocationSelection(
      countryId: (json['countryId'] as String?) ?? 'in',
      stateId: (json['stateId'] as String?) ?? '',
      cityId: cityId,
      localityId: localityId,
      cityName: (json['cityName'] as String?) ?? '',
      stateName: (json['stateName'] as String?) ?? '',
      localityName: (json['localityName'] as String?) ?? '',
      pinCode: json['pinCode'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocationSelection &&
      other.cityId == cityId &&
      other.localityId == localityId;

  @override
  int get hashCode => Object.hash(cityId, localityId);
}

/// A city a user asked us to open next. Mock submission in this build.
class CityRequest {
  const CityRequest({
    required this.id,
    required this.cityName,
    required this.requestedAt,
    this.stateName,
    this.note,
    this.submittedByPhone,
  });

  final String id;
  final String cityName;
  final DateTime requestedAt;
  final String? stateName;
  final String? note;

  /// Null for guest submissions; that is expected and allowed.
  final String? submittedByPhone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cityName': cityName,
        'requestedAt': requestedAt.toIso8601String(),
        'stateName': stateName,
        'note': note,
        'submittedByPhone': submittedByPhone,
      };

  static CityRequest fromJson(Map<String, dynamic> json) => CityRequest(
        id: json['id'] as String,
        cityName: json['cityName'] as String,
        requestedAt:
            DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
                DateTime.now(),
        stateName: json['stateName'] as String?,
        note: json['note'] as String?,
        submittedByPhone: json['submittedByPhone'] as String?,
      );
}
