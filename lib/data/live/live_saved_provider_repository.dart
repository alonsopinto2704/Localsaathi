import '../../domain/models/provider.dart';
import '../../domain/repositories/profile_support_repositories.dart';
import '../../domain/repositories/provider_repository.dart';
import '../local/key_value_store.dart';

/// Bookmarks stay on the device (backend-contract.md section 10); only the ids
/// are stored. Refreshing them goes through the public projection, so a saved
/// listing that was paused, suspended or deleted simply drops out and no
/// cached private field can resurface. A failed refresh is an error, not an
/// empty list.
class LiveSavedProviderRepository implements SavedProviderRepository {
  LiveSavedProviderRepository({
    required KeyValueStore keyValueStore,
    required ProviderRepository providers,
  })  : _kv = keyValueStore,
        _providers = providers;

  final KeyValueStore _kv;
  final ProviderRepository _providers;

  Set<String>? _cache;

  Set<String> get _ids => _cache ??= _kv.getStringSet(StorageKeys.savedProviders);

  Future<void> _persist() => _kv.setStringSet(StorageKeys.savedProviders, _ids);

  @override
  Future<Set<String>> savedIds() async => Set<String>.unmodifiable(_ids);

  @override
  Future<bool> isSaved(String providerId) async => _ids.contains(providerId);

  @override
  Future<void> save(String providerId) async {
    if (_ids.add(providerId)) await _persist();
  }

  @override
  Future<void> remove(String providerId) async {
    if (_ids.remove(providerId)) await _persist();
  }

  @override
  Future<bool> toggle(String providerId) async {
    final bool nowSaved = _ids.add(providerId);
    if (!nowSaved) _ids.remove(providerId);
    await _persist();
    return nowSaved;
  }

  @override
  Future<List<ProviderProfile>> savedProfiles() async {
    final List<ProviderProfile?> found = await Future.wait(
      _ids.toList().map(_providers.publicProfileById),
    );
    return found.whereType<ProviderProfile>().toList()
      ..sort((ProviderProfile a, ProviderProfile b) =>
          a.displayName.compareTo(b.displayName),);
  }
}
