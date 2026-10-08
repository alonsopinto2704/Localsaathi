import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key/value persistence contract.
///
/// The repositories depend on this rather than on `shared_preferences`
/// directly, which keeps the storage choice swappable and — importantly — lets
/// tests run against [InMemoryKeyValueStore] with no plugin binding.
abstract class KeyValueStore {
  Future<void> init();

  String? getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);

  /// Wipes only the keys this app owns, never the whole platform store.
  Future<void> clearAppKeys();

  // ------------------------------------------------------------- JSON sugar
  Map<String, dynamic>? getJson(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // A corrupt entry must never crash start-up: treat it as absent.
      return null;
    }
    return null;
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } on FormatException {
      return <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      setString(key, jsonEncode(value));

  Set<String> getStringSet(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
    return <String>{};
  }

  Future<void> setStringSet(String key, Set<String> value) =>
      setString(key, jsonEncode(value.toList()));
}

/// Namespaced keys, so every key the app owns is greppable in one place and
/// [KeyValueStore.clearAppKeys] can never delete someone else's data.
class StorageKeys {
  const StorageKeys._();

  static const String prefix = 'localsaathi.';

  static const String selectedLocation = '${prefix}selected_location';
  static const String languageCode = '${prefix}language_code';
  static const String savedProviders = '${prefix}saved_providers';
  static const String providerDraft = '${prefix}provider_draft';
  static const String providerSession = '${prefix}provider_session';
  static const String providerAccounts = '${prefix}provider_accounts';
  static const String profiles = '${prefix}provider_profiles';
  static const String consents = '${prefix}consents';
  static const String verificationRecords = '${prefix}verification_records';
  static const String reports = '${prefix}reports';
  static const String cityRequests = '${prefix}city_requests';
  static const String engagementEvents = '${prefix}engagement_events';
  static const String promotionInterest = '${prefix}promotion_interest';
  static const String recentSearches = '${prefix}recent_searches';
  static const String onboardingCompleted = '${prefix}onboarding_completed';
  static const String publicRefCache = '${prefix}public_ref_cache';

  /// Explicit list so [KeyValueStore.clearAppKeys] is exhaustive rather than
  /// prefix-guessing on a platform API that has no prefix delete.
  static const List<String> all = <String>[
    selectedLocation,
    languageCode,
    savedProviders,
    providerDraft,
    providerSession,
    providerAccounts,
    profiles,
    consents,
    verificationRecords,
    reports,
    cityRequests,
    engagementEvents,
    promotionInterest,
    recentSearches,
    onboardingCompleted,
    publicRefCache,
  ];
}

/// `shared_preferences`-backed store: the production path for on-device data.
class SharedPreferencesStore extends KeyValueStore {
  SharedPreferencesStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesStore> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStore._(prefs);
  }

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clearAppKeys() async {
    for (final String key in StorageKeys.all) {
      await _prefs.remove(key);
    }
  }
}

/// In-memory store for tests and for the `--dart-define` "ephemeral" mode.
///
/// Also the fallback when platform storage is unavailable, so a storage
/// failure degrades to "nothing is remembered" rather than a crash.
class InMemoryKeyValueStore extends KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
      : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clearAppKeys() async {
    for (final String key in StorageKeys.all) {
      _values.remove(key);
    }
  }
}
