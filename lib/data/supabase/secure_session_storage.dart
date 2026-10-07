import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where session secrets live (phase 049). Deliberately not [KeyValueStore]:
/// bookmarks, location and drafts use shared preferences; tokens must never.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Android Keystore / iOS Keychain backed store.
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Plugs [SecretStore] into the Supabase SDK in place of its default
/// SharedPreferences storage.
///
/// **Fail closed:** if the secure store cannot be read, the stored value is
/// treated as absent and the user signs in again. If it cannot be written the
/// session lives in memory only (it will not survive a restart). Neither case
/// falls back to plain storage.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._store, {this.key = 'ls.auth.session'});

  final SecretStore _store;
  final String key;

  /// Last value written, so [hasAccessToken] stays cheap and consistent.
  bool _healthy = true;

  bool get isHealthy => _healthy;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() async {
    try {
      final String? value = await _store.read(key);
      return (value == null || value.isEmpty) ? null : value;
    } on Object {
      _healthy = false;
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _store.write(key, persistSessionString);
      _healthy = true;
    } on Object {
      _healthy = false;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _store.delete(key);
    } on Object {
      _healthy = false;
    }
  }
}
