import '../../domain/models/enums.dart';
import '../../domain/models/moderation.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/profile_support_repositories.dart';
import '../local/key_value_store.dart';
import 'mock_data_store.dart';

/// Saved providers, persisted on-device.
///
/// Guests must be able to use this without an account, so there is no auth
/// check anywhere in this class. Unsaved listings are filtered out on read so a
/// deleted or paused provider cannot be reopened from the saved list.
class MockSavedProviderRepository implements SavedProviderRepository {
  MockSavedProviderRepository({
    required MockDataStore store,
    required KeyValueStore keyValueStore,
  })  : _store = store,
        _kv = keyValueStore;

  final MockDataStore _store;
  final KeyValueStore _kv;

  Set<String>? _cache;

  Set<String> get _ids =>
      _cache ??= _kv.getStringSet(StorageKeys.savedProviders);

  Future<void> _persist() async =>
      _kv.setStringSet(StorageKeys.savedProviders, _ids);

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
    final bool nowSaved = !_ids.contains(providerId);
    if (nowSaved) {
      _ids.add(providerId);
    } else {
      _ids.remove(providerId);
    }
    await _persist();
    return nowSaved;
  }

  @override
  Future<List<ProviderProfile>> savedProfiles() async {
    final List<ProviderProfile> profiles = <ProviderProfile>[];
    for (final String id in _ids) {
      final ProviderProfile? profile = _store.profilesById[id];
      // A saved provider that has since been paused or deleted is silently
      // dropped rather than shown as a dead entry.
      if (profile != null && _store.isListed(profile)) profiles.add(profile);
    }
    profiles.sort(
      (ProviderProfile a, ProviderProfile b) =>
          a.displayName.compareTo(b.displayName),
    );
    return profiles;
  }
}

/// Onboarding draft, persisted locally so a provider can finish later.
class MockProviderDraftRepository implements ProviderDraftRepository {
  MockProviderDraftRepository({required KeyValueStore keyValueStore})
      : _kv = keyValueStore;

  final KeyValueStore _kv;

  @override
  Future<ProviderDraft?> load() async {
    final Map<String, dynamic>? json = _kv.getJson(StorageKeys.providerDraft);
    if (json == null) return null;
    try {
      return ProviderDraft.fromJson(json);
    } on Object {
      // Corrupt draft: drop it rather than block the wizard.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(ProviderDraft draft) =>
      _kv.setJson(StorageKeys.providerDraft, draft.toJson());

  @override
  Future<void> clear() => _kv.remove(StorageKeys.providerDraft);
}

/// Consent records. Append-only in spirit: each call adds a new record with its
/// wording version rather than mutating history.
class MockConsentRepository implements ConsentRepository {
  MockConsentRepository({required MockDataStore store}) : _store = store;

  final MockDataStore _store;

  @override
  Future<ConsentRecord> record({
    required String providerId,
    required ConsentKind kind,
    required bool granted,
    String? phoneE164,
    String wordingVersion = MockDataStore.consentWordingVersion,
  }) async {
    final ConsentRecord record = ConsentRecord(
      id: _store.newId('consent'),
      providerId: providerId,
      kind: kind,
      granted: granted,
      recordedAt: _store.now,
      wordingVersion: wordingVersion,
      phoneE164: phoneE164,
    );
    _store.consents.add(record);
    await _store.persistConsents();
    return record;
  }

  @override
  Future<List<ConsentRecord>> forProvider(String providerId) async =>
      _store.consents
          .where((ConsentRecord c) => c.providerId == providerId)
          .toList();

  @override
  Future<Map<ConsentKind, bool>> currentState(String providerId) async {
    final Map<ConsentKind, bool> state = <ConsentKind, bool>{};
    for (final ConsentRecord record in _store.consents) {
      if (record.providerId != providerId) continue;
      // Records are appended chronologically, so the last write wins.
      state[record.kind] = record.isCurrentlyGranted;
    }
    return state;
  }
}

/// Verification records, with the two trails kept firmly apart.
class MockVerificationRepository implements VerificationRepository {
  MockVerificationRepository({required MockDataStore store}) : _store = store;

  final MockDataStore _store;

  @override
  Future<VerificationRecord> recordPhoneVerification({
    required String providerId,
    required VerificationStatus status,
    required String method,
  }) async {
    final VerificationRecord record = VerificationRecord(
      id: _store.newId('ver'),
      providerId: providerId,
      kind: VerificationKind.phone,
      status: status,
      createdAt: _store.now,
      method: method,
    );
    _store.verificationRecords.add(record);
    await _store.persistVerification();
    return record;
  }

  @override
  Future<List<VerificationRecord>> recordsFor(String providerId) async =>
      _store.verificationRecords
          .where((VerificationRecord v) => v.providerId == providerId)
          .toList();

  @override
  Future<Map<VerificationKind, VerificationStatus>> currentStatus(
    String providerId,
  ) async {
    final Map<VerificationKind, VerificationStatus> status =
        <VerificationKind, VerificationStatus>{};
    for (final VerificationRecord record in _store.verificationRecords) {
      if (record.providerId != providerId) continue;
      status[record.kind] = record.status;
    }
    return status;
  }

  @override
  Future<VerificationRecord> recordCredentialReview({
    required String providerId,
    required VerificationStatus status,
    required String reviewedBy,
    String? note,
  }) async {
    // Only a review process may produce a credentials-verified state. There is
    // no code path from OTP success to this method, by design.
    final VerificationRecord record = VerificationRecord(
      id: _store.newId('ver'),
      providerId: providerId,
      kind: VerificationKind.credentials,
      status: status,
      createdAt: _store.now,
      method: 'document_review',
      reviewedBy: reviewedBy,
      reviewedAt: _store.now,
      note: note,
    );
    _store.verificationRecords.add(record);
    await _store.persistVerification();
    return record;
  }
}

/// Professional credentials: provider-supplied claims awaiting review.
class MockCredentialRepository implements CredentialRepository {
  MockCredentialRepository({required MockDataStore store}) : _store = store;

  final MockDataStore _store;

  final Map<String, List<CredentialRecord>> _byProvider =
      <String, List<CredentialRecord>>{};

  @override
  Future<List<CredentialRecord>> forProvider(String providerId) async =>
      List<CredentialRecord>.unmodifiable(
        _byProvider[providerId] ?? const <CredentialRecord>[],
      );

  @override
  Future<CredentialRecord> saveClaimed(CredentialRecord record) async {
    // Force the claimed state: a provider can never self-approve. The app does
    // not invent credentials, it only stores what was typed in.
    final CredentialRecord claimed = CredentialRecord(
      id: record.id.isEmpty ? _store.newId('cred') : record.id,
      providerId: record.providerId,
      title: record.title,
      status: VerificationStatus.pending,
      issuingBody: record.issuingBody,
      registrationNumber: record.registrationNumber,
      validUntil: record.validUntil,
      evidenceReference: record.evidenceReference,
    );
    final List<CredentialRecord> list =
        _byProvider.putIfAbsent(record.providerId, () => <CredentialRecord>[]);
    final int index =
        list.indexWhere((CredentialRecord c) => c.id == claimed.id);
    if (index >= 0) {
      list[index] = claimed;
    } else {
      list.add(claimed);
    }
    return claimed;
  }

  @override
  Future<void> remove(String credentialId) async {
    for (final List<CredentialRecord> list in _byProvider.values) {
      list.removeWhere((CredentialRecord c) => c.id == credentialId);
    }
  }
}
