import 'dart:math';

import '../../domain/models/account.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moderation.dart';
import '../../domain/models/provider.dart';
import '../local/key_value_store.dart';
import '../../domain/models/service_category.dart';
import '../seed/category_seed.dart';
import '../seed/provider_seed.dart';

/// The single in-memory database behind the mock repositories.
///
/// Deliberately one object rather than per-repository state, because the rules
/// that matter are cross-cutting:
///
/// * **unique normalised phone numbers** — one number, one account, one profile;
/// * **profile ownership** — a session may only touch its own profile;
/// * **publication status** — only published listings are discoverable.
///
/// Centralising them here means those rules cannot be bypassed by going through
/// a different repository, and it mirrors how a real backend would enforce them
/// in one place (a unique index plus row-level authorization).
///
/// Everything mutates in memory and is mirrored to local storage so the demo
/// survives a restart. The production implementation replaces this class with
/// HTTP calls plus server-side constraints.
class MockDataStore {
  MockDataStore({
    KeyValueStore? store,
    DateTime? now,
    bool seed = true,
    bool persist = true,
  })  : _store = store,
        _persistEnabled = persist && store != null,
        _now = now ?? DateTime.now() {
    if (seed) _seedData();
    _restore();
  }

  final KeyValueStore? _store;
  final bool _persistEnabled;
  final DateTime _now;

  final Random _random = Random(20260105);

  // ------------------------------------------------------------- in-memory
  final Map<String, PhoneIdentity> phonesByE164 = <String, PhoneIdentity>{};
  final Map<String, ProviderAccount> accountsById = <String, ProviderAccount>{};
  final Map<String, String> accountIdByPhone = <String, String>{};
  final Map<String, ProviderProfile> profilesById = <String, ProviderProfile>{};
  final Map<String, String> profileIdByPhone = <String, String>{};
  final List<ConsentRecord> consents = <ConsentRecord>[];
  final List<VerificationRecord> verificationRecords = <VerificationRecord>[];
  final List<Report> reports = <Report>[];
  final List<EngagementEvent> engagementEvents = <EngagementEvent>[];
  final List<Promotion> promotions = <Promotion>[];
  final Set<String> promotionInterest = <String>{};

  /// In-flight OTP challenges, keyed by challenge id. Never persisted: a
  /// production challenge lives in the backend with a short TTL.
  final Map<String, OtpChallenge> pendingChallenges = <String, OtpChallenge>{};

  /// Current session. Persisted, because the demo should stay signed in.
  ProviderSession? session;

  /// Pending phone-number change, set while a provider verifies a new number.
  String? pendingPhoneChangeE164;

  // ------------------------------------------------------------- accessors
  ProviderProfile? profileForPhone(String e164) {
    final String? id = profileIdByPhone[e164];
    return id == null ? null : profilesById[id];
  }

  ProviderAccount? accountForPhone(String e164) {
    final String? id = accountIdByPhone[e164];
    return id == null ? null : accountsById[id];
  }

  /// Every listed listing. The only source customer surfaces read from.
  List<ProviderProfile> get publishedProfiles =>
      profilesById.values.where(isListed).toList();

  /// Mirrors the server's is_publicly_listed: published and offering at least
  /// one category that is open for listings at launch.
  static final Set<String> _approvedCategoryIds = <String>{
    for (final ServiceCategory c in CategorySeed.categories)
      if (c.isApprovedForLaunch) c.id,
  };
  bool isListed(ProviderProfile p) =>
      p.isPubliclyVisible && p.categoryIds.any(_approvedCategoryIds.contains);

  // -------------------------------------------------------------- seeding
  void _seedData() {
    final List<ProviderProfile> seeded = <ProviderProfile>[
      ...ProviderSeed.build(),
      ...ProviderSeed.buildNonPublished(reference: _now),
    ];
    for (final ProviderProfile profile in seeded) {
      profilesById[profile.id] = profile;
      profileIdByPhone[profile.phoneE164] = profile.id;
      phonesByE164[profile.phoneE164] = PhoneIdentity(
        e164: profile.phoneE164,
        createdAt: profile.createdAt,
        lastVerifiedAt: profile.createdAt,
        verified: profile.isPhoneVerified,
      );
      verificationRecords.add(
        VerificationRecord(
          id: 'ver-phone-${profile.id}',
          providerId: profile.id,
          kind: VerificationKind.phone,
          status: profile.verification[VerificationKind.phone] ??
              VerificationStatus.pending,
          createdAt: profile.createdAt,
          method: 'otp_simulated',
          note: 'Seeded development verification.',
        ),
      );
      consents
        ..add(
          ConsentRecord(
            id: 'consent-phone-${profile.id}',
            providerId: profile.id,
            kind: ConsentKind.displayPhoneNumber,
            granted: profile.phoneDisplayConsented,
            recordedAt: profile.createdAt,
            wordingVersion: consentWordingVersion,
            phoneE164: profile.phoneE164,
          ),
        )
        ..add(
          ConsentRecord(
            id: 'consent-public-${profile.id}',
            providerId: profile.id,
            kind: ConsentKind.publicProfile,
            granted: profile.isPubliclyVisible,
            recordedAt: profile.createdAt,
            wordingVersion: consentWordingVersion,
            phoneE164: profile.phoneE164,
          ),
        )
        ..add(
          ConsentRecord(
            id: 'consent-whatsapp-${profile.id}',
            providerId: profile.id,
            kind: ConsentKind.whatsappContact,
            granted: profile.whatsappEnabled,
            recordedAt: profile.createdAt,
            wordingVersion: consentWordingVersion,
            phoneE164: profile.phoneE164,
          ),
        );
    }

    // Sample engagement. Marked as sample everywhere it is shown; these are
    // in-app button taps only, never calls, leads or jobs.
    int index = 0;
    for (final ProviderProfile profile
        in profilesById.values.where((ProviderProfile p) => p.isPubliclyVisible)) {
      engagementEvents.add(
        EngagementEvent(
          id: ProviderSeed.seedId('ev-view', index),
          providerId: profile.id,
          type: EngagementEventType.profileView,
          occurredAt: _now.subtract(Duration(days: index % 30)),
          cityId: profile.baseCityId,
          localityId: profile.baseLocalityId,
          totalCount: 18 + (index * 7) % 240,
        ),
      );
      engagementEvents.add(
        EngagementEvent(
          id: ProviderSeed.seedId('ev-call', index),
          providerId: profile.id,
          type: EngagementEventType.callButtonTap,
          occurredAt: _now.subtract(Duration(days: index % 30)),
          cityId: profile.baseCityId,
          localityId: profile.baseLocalityId,
          totalCount: 4 + (index * 3) % 46,
        ),
      );
      if (profile.whatsappEnabled) {
        engagementEvents.add(
          EngagementEvent(
            id: ProviderSeed.seedId('ev-wa', index),
            providerId: profile.id,
            type: EngagementEventType.whatsappButtonTap,
            occurredAt: _now.subtract(Duration(days: index % 30)),
            cityId: profile.baseCityId,
            localityId: profile.baseLocalityId,
            totalCount: 2 + (index * 5) % 28,
          ),
        );
      }
      index++;
    }

    // One active sponsored placement, so the "Sponsored" label and the
    // organic-results-stay-visible rule are both demonstrable.
    const String sponsorId = 'provider-seed-000';
    if (profilesById.containsKey(sponsorId)) {
      promotions.add(
        Promotion(
          id: 'promo-seed-001',
          providerId: sponsorId,
          state: PromotionState.active,
          placement: PromotionPlacement.searchTop,
          startsAt: _now.subtract(const Duration(days: 7)),
          endsAt: _now.add(const Duration(days: 23)),
          categoryIds: const <String>['plumbing'],
          localityIds: const <String>[],
          cityId: 'mh-mumbai',
          priority: 10,
        ),
      );
    }
  }

  // ------------------------------------------------------------ persistence
  void _restore() {
    final KeyValueStore? store = _store;
    if (store == null) return;

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.profiles,
    )) {
      try {
        final ProviderProfile profile = ProviderProfile.fromJson(json);
        profilesById[profile.id] = profile;
        profileIdByPhone[profile.phoneE164] = profile.id;
      } on Object {
        // A corrupt record is skipped rather than breaking start-up.
      }
    }

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.providerAccounts,
    )) {
      try {
        final ProviderAccount account = ProviderAccount.fromJson(json);
        accountsById[account.id] = account;
        accountIdByPhone[account.phoneE164] = account.id;
      } on Object {
        continue;
      }
    }

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.consents,
    )) {
      try {
        consents.add(ConsentRecord.fromJson(json));
      } on Object {
        continue;
      }
    }

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.verificationRecords,
    )) {
      try {
        verificationRecords.add(VerificationRecord.fromJson(json));
      } on Object {
        continue;
      }
    }

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.reports,
    )) {
      try {
        reports.add(Report.fromJson(json));
      } on Object {
        continue;
      }
    }

    for (final Map<String, dynamic> json in store.getJsonList(
      StorageKeys.engagementEvents,
    )) {
      try {
        engagementEvents.add(EngagementEvent.fromJson(json));
      } on Object {
        continue;
      }
    }

    promotionInterest.addAll(store.getStringSet(StorageKeys.promotionInterest));

    final Map<String, dynamic>? sessionJson =
        store.getJson(StorageKeys.providerSession);
    if (sessionJson != null) {
      session = ProviderSession.fromJson(sessionJson);
    }
  }

  Future<void> persistProfiles() => _persist(
        StorageKeys.profiles,
        profilesById.values
            .where((ProviderProfile p) => _isMutable(p))
            .map((ProviderProfile p) => p.toJson())
            .toList(),
      );

  Future<void> persistAccounts() => _persist(
        StorageKeys.providerAccounts,
        accountsById.values.map((ProviderAccount a) => a.toJson()).toList(),
      );

  Future<void> persistConsents() => _persist(
        StorageKeys.consents,
        consents.map((ConsentRecord c) => c.toJson()).toList(),
      );

  Future<void> persistVerification() => _persist(
        StorageKeys.verificationRecords,
        verificationRecords
            .map((VerificationRecord v) => v.toJson())
            .toList(),
      );

  Future<void> persistReports() => _persist(
        StorageKeys.reports,
        reports.map((Report r) => r.toJson()).toList(),
      );

  Future<void> persistEngagement() => _persist(
        StorageKeys.engagementEvents,
        engagementEvents.map((EngagementEvent e) => e.toJson()).toList(),
      );

  Future<void> persistSession() async {
    final KeyValueStore? store = _store;
    if (store == null || !_persistEnabled) return;
    if (session == null) {
      await store.remove(StorageKeys.providerSession);
    } else {
      await store.setJson(StorageKeys.providerSession, session!.toJson());
    }
  }

  Future<void> persistPromotionInterest() async {
    final KeyValueStore? store = _store;
    if (store == null || !_persistEnabled) return;
    await store.setStringSet(StorageKeys.promotionInterest, promotionInterest);
  }

  /// Seeded demo listings are never persisted: they are regenerated identically
  /// on every launch, so writing them would only bloat storage.
  bool _isMutable(ProviderProfile profile) => !profile.id.contains('-seed-');

  Future<void> _persist(String key, List<Map<String, dynamic>> value) async {
    final KeyValueStore? store = _store;
    if (store == null || !_persistEnabled) return;
    await store.setJsonList(key, value);
  }

  // -------------------------------------------------------------- utilities
  /// Wording version stamped onto consent records. Bump when consent copy
  /// changes so the audit trail shows what the provider actually agreed to.
  static const String consentWordingVersion = 'consent-v1';

  String newId(String prefix) =>
      '$prefix-${_now.microsecondsSinceEpoch}-${_suffix()}';

  String _suffix() =>
      _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');

  /// Generates a simulated OTP.
  ///
  /// DEVELOPMENT ONLY. Replace with a backend challenge; see README
  /// "Before production".
  String newSimulatedCode() {
    final int value = 100000 + _random.nextInt(900000);
    return value.toString();
  }

  DateTime get now => _now;
}
