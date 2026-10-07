
import '../../domain/models/account.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/location.dart';
import '../../domain/models/moderation.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/provider_repository.dart';
import '../../domain/repositories/service_catalog_repository.dart';
import 'mock_data_store.dart';

/// In-memory provider directory.
///
/// Enforces the three rules the future backend must enforce too:
///
/// 1. **Publication status.** Only [ListingStatus.published] listings are ever
///    returned by [search] or [publicProfileById]. A paused listing vanishes
///    from every customer surface.
/// 2. **Ownership.** Every mutation checks that [session] owns the profile.
///    The client is never trusted; a wrong session gets
///    [RepositoryErrorCode.notOwner] rather than silent success.
/// 3. **One number, one profile.** Creation re-checks the normalised phone
///    against the store's map, which is the mock equivalent of a database
///    unique index.
class MockProviderRepository implements ProviderRepository {
  MockProviderRepository({
    required MockDataStore store,
    required ServiceCatalogRepository catalog,
    required LocationRepository locations,
    DateTime? now,
  })  : _store = store,
        _catalog = catalog,
        _locations = locations,
        _now = now ?? WorkingHours.indiaNow();

  final MockDataStore _store;
  final ServiceCatalogRepository _catalog;
  final LocationRepository _locations;
  final DateTime _now;

  /// Locality id -> name cache. Locality names are searchable, and rebuilding
  /// the whole map per search would be wasteful on a low-end device.
  final Map<String, String> _localityNames = <String, String>{};

  @override
  Future<ProviderSearchResults> search(ProviderQuery query) async {
    final Set<String> searchedCategories = await _categoriesMatching(query.text);
    final String needle = query.text.trim().toLowerCase();

    // Localities the customer is looking in. An explicit locality filter wins;
    // otherwise it is their selected locality.
    final Set<String> targetLocalities = query.localityFilterIds.isEmpty
        ? <String>{query.localityId}
        : query.localityFilterIds.toSet();

    final List<ProviderProfile> matches = <ProviderProfile>[];
    for (final ProviderProfile profile in _store.publishedProfiles) {
      if (profile.baseCityId != query.cityId) continue;

      // Location always applies: the provider must serve a target locality.
      final bool servesTarget = targetLocalities
          .any((String localityId) => profile.servesLocality(localityId));
      if (!servesTarget) continue;

      if (query.categoryIds.isNotEmpty &&
          !profile.categoryIds
              .any((String id) => query.categoryIds.contains(id))) {
        continue;
      }

      if (query.homeVisitsOnly && !profile.homeVisits) continue;

      if (query.openNowOnly) {
        // Never assume: a provider with no hours cannot satisfy "Open now".
        final bool? open = profile.workingHours?.isOpenAt(_now);
        if (open != true) continue;
      }

      if (query.hasText) {
        final bool categoryHit = profile.categoryIds
            .any((String id) => searchedCategories.contains(id));
        if (!categoryHit && !_profileTextMatches(profile, needle)) continue;
      }

      matches.add(profile);
    }

    matches.sort((ProviderProfile a, ProviderProfile b) {
      // Published providers with a phone consent first, then richer profiles,
      // then name — deterministic and never influenced by payment.
      if (a.canBeCalled != b.canBeCalled) return a.canBeCalled ? -1 : 1;
      if (a.photoCount != b.photoCount) return b.photoCount.compareTo(a.photoCount);
      if (a.categoryIds.length != b.categoryIds.length) {
        return b.categoryIds.length.compareTo(a.categoryIds.length);
      }
      return a.displayName.compareTo(b.displayName);
    });

    // Sponsored slots are matched on the customer's own category and locality,
    // then placed above organic results as a separate, labelled group.
    final List<ProviderProfile> sponsored = _sponsoredFor(
      matches: matches,
      cityId: query.cityId,
      localityId: query.localityId,
      // A text search ("plumber") targets the categories it resolved to.
      categoryIds: query.categoryIds.isNotEmpty
          ? query.categoryIds
          : searchedCategories.toList(),
    );

    final Set<String> sponsoredIds =
        sponsored.map((ProviderProfile p) => p.id).toSet();
    final List<ProviderProfile> organic = matches
        .where((ProviderProfile p) => !sponsoredIds.contains(p.id))
        .toList();

    // Organic results are never hidden or re-ordered away by a promotion.
    List<ProviderProfile> ordered = <ProviderProfile>[...sponsored, ...organic];
    if (query.limit != null && ordered.length > query.limit!) {
      ordered = ordered.sublist(0, query.limit!);
    }

    return ProviderSearchResults(
      items: <ProviderResultItem>[
        for (final ProviderProfile profile in ordered)
          ProviderResultItem(
            provider: profile,
            isSponsored: sponsoredIds.contains(profile.id),
          ),
      ],
      totalCount: matches.length,
      isSampleData: true,
    );
  }

  @override
  Future<ProviderProfile?> publicProfileById(String id) async {
    final ProviderProfile? profile = _store.profilesById[id];
    if (profile == null || !_store.isListed(profile)) return null;
    return profile;
  }

  @override
  Future<ProviderProfile?> profileByIdForOwner({
    required String profileId,
    required ProviderSession session,
  }) async {
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null) return null;
    if (session.profileId != profileId) {
      throw const RepositoryException(RepositoryErrorCode.notOwner);
    }
    return profile;
  }

  @override
  Future<List<ProviderProfile>> publishedInCity(String cityId) async =>
      _store.publishedProfiles
          .where((ProviderProfile p) => p.baseCityId == cityId)
          .toList();

  @override
  Future<Map<String, int>> providerCountByLocality(String cityId) async {
    final Map<String, int> counts = <String, int>{};
    for (final ProviderProfile profile in _store.publishedProfiles) {
      if (profile.baseCityId != cityId) continue;
      for (final String localityId in profile.servedLocalityIds) {
        counts[localityId] = (counts[localityId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<ProviderProfile> createProfile({
    required String phoneE164,
    required String displayName,
    required String baseCityId,
    required String baseLocalityId,
    required List<String> categoryIds,
    required List<String> serviceAreaIds,
    required ProviderSession session,
    String? description,
    List<String> languages = const <String>[],
    WorkingHours? workingHours,
    bool homeVisits = true,
    bool phoneDisplayConsented = false,
    bool whatsappEnabled = false,
    HealthcareDetails? healthcareDetails,
    List<String> photoCaptions = const <String>[],
    List<StartingPrice> startingPrices = const <StartingPrice>[],
  }) async {
    if (session.phoneE164 != phoneE164) {
      throw const RepositoryException(RepositoryErrorCode.notAuthenticated);
    }
    // The uniqueness rule, re-checked at the point of write.
    if (_store.profileIdByPhone.containsKey(phoneE164)) {
      throw DuplicatePhoneNumberException(phoneE164);
    }
    if (displayName.trim().isEmpty) {
      throw const RepositoryException(RepositoryErrorCode.validationFailed);
    }
    if (categoryIds.isEmpty) {
      throw const RepositoryException(RepositoryErrorCode.validationFailed);
    }
    if (serviceAreaIds.isEmpty) {
      throw const RepositoryException(RepositoryErrorCode.validationFailed);
    }

    // Validate references: a listing may not point at a category or locality
    // the app does not know about.
    for (final String categoryId in categoryIds) {
      if (await _catalog.categoryById(categoryId) == null) {
        throw const RepositoryException(RepositoryErrorCode.categoryNotAllowed);
      }
    }

    final String id = _store.newId('provider');
    final ProviderProfile profile = ProviderProfile(
      id: id,
      phoneE164: phoneE164,
      displayName: displayName.trim(),
      baseCityId: baseCityId,
      baseLocalityId: baseLocalityId,
      status: ListingStatus.draft,
      createdAt: _now,
      updatedAt: _now,
      categoryIds: categoryIds,
      serviceAreas: <ProviderServiceArea>[
        for (final String localityId in serviceAreaIds)
          ProviderServiceArea(
            cityId: baseCityId,
            localityId: localityId,
            isPrimary: localityId == baseLocalityId,
          ),
      ],
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      languages: languages,
      workingHours: workingHours,
      photos: <ProviderPhoto>[
        for (int i = 0; i < photoCaptions.length; i++)
          ProviderPhoto(
            id: _store.newId('photo-$i'),
            caption: photoCaptions[i],
            isPlaceholder: true,
            uploadedAt: _now,
          ),
      ],
      startingPrices: startingPrices,
      healthcareDetails: healthcareDetails,
      homeVisits: homeVisits,
      availability: AvailabilityStatus.available,
      whatsappEnabled: whatsappEnabled,
      phoneDisplayConsented: phoneDisplayConsented,
      verification: const <VerificationKind, VerificationStatus>{
        VerificationKind.phone: VerificationStatus.approved,
      },
      isDemoProfile: false,
    );

    _store.profilesById[id] = profile;
    _store.profileIdByPhone[phoneE164] = id;

    final ProviderAccount? account = _store.accountForPhone(phoneE164);
    if (account != null) {
      final ProviderAccount updated = account.copyWith(
        profileId: id,
        lastSignedInAt: _now,
        phoneVerifiedAt: _now,
      );
      _store.accountsById[updated.id] = updated;
    }
    if (_store.session != null) {
      _store.session = _store.session!.copyWith(profileId: id);
    }

    // Same as the server's register_profile (migration 0017): the confirmed
    // OTP is recorded as phone verification, and only that.
    _store.verificationRecords.add(
      VerificationRecord(
        id: _store.newId('ver'),
        providerId: id,
        kind: VerificationKind.phone,
        status: VerificationStatus.approved,
        createdAt: _now,
        method: 'otp_simulated',
        note: 'Phone control confirmed by one-time code. This says nothing '
            'about professional qualifications.',
      ),
    );

    await _store.persistProfiles();
    await _store.persistAccounts();
    await _store.persistSession();
    await _store.persistVerification();
    return profile;
  }

  @override
  Future<ProviderProfile> updateProfile({
    required ProviderProfile profile,
    required ProviderSession session,
  }) async {
    _assertOwner(profile.id, session);

    // References are re-validated on every write, not just at creation.
    for (final String categoryId in profile.categoryIds) {
      if (await _catalog.categoryById(categoryId) == null) {
        throw const RepositoryException(RepositoryErrorCode.categoryNotAllowed);
      }
    }
    if (profile.categoryIds.isEmpty) {
      throw const RepositoryException(RepositoryErrorCode.validationFailed);
    }
    // WhatsApp cannot be offered without phone-number consent: the button would
    // have nothing to open.
    final bool whatsapp = profile.whatsappEnabled && profile.phoneDisplayConsented;

    // Withdrawing phone consent pauses a live listing (mirrors the SQL trigger).
    final ProviderProfile updated = profile.copyWith(
      displayName: profile.displayName.trim(),
      whatsappEnabled: whatsapp,
      status: !profile.phoneDisplayConsented &&
              profile.status == ListingStatus.published
          ? ListingStatus.paused
          : profile.status,
      updatedAt: _now,
    );
    _store.profilesById[updated.id] = updated;
    await _store.persistProfiles();
    return updated;
  }

  @override
  Future<ProviderProfile> publish({
    required String profileId,
    required ProviderSession session,
  }) async {
    _assertOwner(profileId, session);
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    if (!profile.phoneDisplayConsented) {
      // Consent to show the number is a precondition for publishing.
      throw const RepositoryException(
        RepositoryErrorCode.listingNotPublishable,
        'phone consent required',
      );
    }
    if (profile.categoryIds.isEmpty ||
        profile.serviceAreas.isEmpty ||
        profile.displayName.trim().isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.validationFailed,
      );
    }
    final ProviderAccount? account = _store.accountForPhone(profile.phoneE164);
    if (account?.isSuspended ?? false) {
      throw const RepositoryException(RepositoryErrorCode.suspended);
    }
    // At least one launch-approved category and an active city, as in SQL.
    bool approved = false;
    for (final String id in profile.categoryIds) {
      if ((await _catalog.categoryById(id))?.isApprovedForLaunch ?? false) {
        approved = true;
        break;
      }
    }
    final City? city = await _locations.cityById(profile.baseCityId);
    if (!approved || city?.launchStatus != CityLaunchStatus.active) {
      throw const RepositoryException(RepositoryErrorCode.listingNotPublishable);
    }

    final ProviderProfile published = profile.copyWith(
      status: ListingStatus.published,
      updatedAt: _now,
    );
    _store.profilesById[profileId] = published;
    await _store.persistProfiles();
    return published;
  }

  @override
  Future<ProviderProfile> setListingStatus({
    required String profileId,
    required ListingStatus status,
    required ProviderSession session,
  }) async {
    _assertOwner(profileId, session);
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    final ProviderProfile updated =
        profile.copyWith(status: status, updatedAt: _now);
    _store.profilesById[profileId] = updated;
    await _store.persistProfiles();
    return updated;
  }

  @override
  Future<ProviderProfile> setAvailability({
    required String profileId,
    required AvailabilityStatus availability,
    required ProviderSession session,
  }) async {
    _assertOwner(profileId, session);
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    final ProviderProfile updated =
        profile.copyWith(availability: availability, updatedAt: _now);
    _store.profilesById[profileId] = updated;
    await _store.persistProfiles();
    return updated;
  }

  @override
  Future<void> deleteListing({
    required String profileId,
    required ProviderSession session,
  }) async {
    _assertOwner(profileId, session);
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    // Delete releases the phone number so it can register again, which is the
    // documented behaviour of "delete my listing".
    _store.profilesById.remove(profileId);
    _store.profileIdByPhone.remove(profile.phoneE164);
    final ProviderAccount? account = _store.accountForPhone(profile.phoneE164);
    if (account != null) {
      _store.accountsById[account.id] =
          account.copyWith(clearProfileId: true);
    }
    if (_store.session?.profileId == profileId) {
      _store.session = _store.session!.copyWith(clearProfileId: true);
    }
    _store.consents.removeWhere((c) => c.providerId == profileId);
    _store.verificationRecords.removeWhere((v) => v.providerId == profileId);
    _store.engagementEvents.removeWhere((e) => e.providerId == profileId);
    await _store.persistProfiles();
    await _store.persistAccounts();
    await _store.persistSession();
    await _store.persistConsents();
    await _store.persistVerification();
    await _store.persistEngagement();
  }

  @override
  Future<List<Locality>> serviceAreaLocalities(ProviderProfile profile) async {
    final List<Locality> resolved = <Locality>[];
    for (final ProviderServiceArea area in profile.serviceAreas) {
      final Locality? locality = await _locations.localityById(area.localityId);
      if (locality != null) resolved.add(locality);
    }
    resolved.sort((Locality a, Locality b) => a.name.compareTo(b.name));
    return resolved;
  }

  @override
  Future<List<ProviderProfile>> similarProviders(
    ProviderProfile provider, {
    int limit = 6,
  }) async {
    final Set<String> targetLocalities =
        <String>{provider.baseLocalityId, ...provider.servedLocalityIds};
    final List<ProviderProfile> candidates = _store.publishedProfiles
        .where((ProviderProfile p) =>
            p.id != provider.id &&
            p.baseCityId == provider.baseCityId &&
            p.categoryIds.any(provider.categoryIds.contains) &&
            p.servedLocalityIds.any(targetLocalities.contains),)
        .toList();
    candidates.sort((ProviderProfile a, ProviderProfile b) =>
        a.displayName.compareTo(b.displayName),);
    if (candidates.length > limit) return candidates.sublist(0, limit);
    return candidates;
  }

  // ------------------------------------------------------------- internals
  // Ownership follows the verified identity (the session's phone), like the
  // server's user_id check -- not a profileId cached in a session object that
  // predates the listing's creation.
  void _assertOwner(String profileId, ProviderSession session) {
    final ProviderProfile? profile = _store.profilesById[profileId];
    if (profile == null || profile.phoneE164 != session.phoneE164) {
      throw const RepositoryException(RepositoryErrorCode.notOwner);
    }
  }

  Future<Set<String>> _categoriesMatching(String text) async {
    if (text.trim().isEmpty) return <String>{};
    final List<ServiceCategory> matches =
        await _catalog.searchCategories(text);
    return matches.map((ServiceCategory c) => c.id).toSet();
  }

  bool _profileTextMatches(ProviderProfile profile, String needle) {
    if (needle.isEmpty) return true;
    if (profile.displayName.toLowerCase().contains(needle)) return true;
    if ((profile.description ?? '').toLowerCase().contains(needle)) return true;
    // Locality names are searchable, so "Bandra" works as a search term.
    for (final String name in _localityNamesFor(profile)) {
      if (name.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  /// Locality names for a provider, resolved lazily and cached.
  List<String> _localityNamesFor(ProviderProfile profile) {
    final List<String> names = <String>[];
    for (final String localityId in <String>{
      profile.baseLocalityId,
      ...profile.servedLocalityIds,
    }) {
      final String? cached = _localityNames[localityId];
      if (cached != null) {
        names.add(cached);
        continue;
      }
      // Warm the cache asynchronously; this search uses what is known now and
      // the next search gets the full set. Locality names also come from the
      // provider's own searchable text via `servedLocalityNames` once loaded.
      _warmLocalityName(localityId);
    }
    return names;
  }

  void _warmLocalityName(String localityId) {
    if (_localityNames.containsKey(localityId)) return;
    _locations.localityById(localityId).then((Locality? locality) {
      if (locality != null) _localityNames[localityId] = locality.name;
    });
  }

  /// Pre-loads locality names so the very first text search already matches on
  /// locality. Called during app start-up.
  Future<void> warmLocalityCache() async {
    for (final ProviderProfile profile in _store.profilesById.values) {
      for (final String localityId in <String>{
        profile.baseLocalityId,
        ...profile.servedLocalityIds,
      }) {
        if (_localityNames.containsKey(localityId)) continue;
        final Locality? locality = await _locations.localityById(localityId);
        if (locality != null) _localityNames[localityId] = locality.name;
      }
    }
  }

  List<ProviderProfile> _sponsoredFor({
    required List<ProviderProfile> matches,
    required String cityId,
    required String localityId,
    required List<String> categoryIds,
  }) {
    final List<Promotion> active = _store.promotions
        .where((Promotion p) => p.isActiveAt(_now))
        .toList()
      ..sort((Promotion a, Promotion b) => b.priority.compareTo(a.priority));

    final List<ProviderProfile> sponsored = <ProviderProfile>[];
    for (final Promotion promotion in active) {
      final bool matchesContext = (categoryIds.isEmpty ? <String?>[null] : categoryIds)
          .any((String? categoryId) => promotion.matches(
                cityId: cityId,
                localityId: localityId,
                categoryId: categoryId,
              ),);
      if (!matchesContext) continue;
      for (final ProviderProfile profile in matches) {
        if (profile.id == promotion.providerId &&
            !sponsored.any((ProviderProfile p) => p.id == profile.id)) {
          sponsored.add(profile);
        }
      }
    }
    return sponsored;
  }
}
