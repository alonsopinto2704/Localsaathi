import 'package:flutter/foundation.dart';

import '../../domain/models/provider.dart';
import '../../domain/repositories/profile_support_repositories.dart';

/// Locally saved providers.
///
/// Works for guests: there is no account requirement anywhere in this path,
/// because requiring sign-up to bookmark someone would contradict the product
/// rule that customers browse freely.
class SavedProvidersController extends ChangeNotifier {
  SavedProvidersController({required SavedProviderRepository repository})
      : _repository = repository;

  final SavedProviderRepository _repository;

  Set<String> _ids = <String>{};
  List<ProviderProfile> _profiles = <ProviderProfile>[];
  bool _isLoading = true;

  Set<String> get savedIds => Set<String>.unmodifiable(_ids);

  List<ProviderProfile> get profiles => List<ProviderProfile>.unmodifiable(_profiles);

  bool get isLoading => _isLoading;

  bool get isEmpty => _profiles.isEmpty;

  int get count => _profiles.length;

  bool isSaved(String providerId) => _ids.contains(providerId);

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await refresh();
  }

  /// Re-reads both the id set and the resolved profiles. Called after any
  /// change and when the saved tab becomes visible, so a provider that was
  /// paused elsewhere drops out.
  Future<void> refresh() async {
    _ids = await _repository.savedIds();
    _profiles = await _repository.savedProfiles();
    _isLoading = false;
    notifyListeners();
  }

  /// Toggles and returns the new state so the caller can show the right
  /// confirmation message.
  Future<bool> toggle(String providerId) async {
    final bool nowSaved = await _repository.toggle(providerId);
    // Update the id set immediately: the bookmark icon must respond on the same
    // frame, without waiting for a full refresh.
    if (nowSaved) {
      _ids = <String>{..._ids, providerId};
    } else {
      _ids = <String>{..._ids}..remove(providerId);
    }
    notifyListeners();
    await refresh();
    return nowSaved;
  }

  Future<void> remove(String providerId) async {
    await _repository.remove(providerId);
    _ids = <String>{..._ids}..remove(providerId);
    _profiles = _profiles
        .where((ProviderProfile p) => p.id != providerId)
        .toList();
    notifyListeners();
  }
}
