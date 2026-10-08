import '../../domain/models/account.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/provider_repository.dart';
import '../supabase/data_gateway.dart';
import '../supabase/wire.dart';

/// Provider discovery and owner access over the backend RPCs (phases 065-067).
///
/// * Public paths (`search`, `publicProfileById`, `publishedInCity`,
///   `similarProviders`, bookmark refresh) call only the public-projection RPCs
///   and re-check that every profile returned is published. A stale link to a
///   paused, suspended, deleted or unknown listing is `null`; a failed request
///   is an error. Neither ever yields a different provider.
/// * Search sends the filters and paging to `search_providers`; ranking and the
///   sponsored flag are preserved exactly as the server returned them. Nothing
///   is downloaded to filter on the client.
/// * Owner paths use the owner RPCs, which the server restricts to the owner.
///   The repository keeps no profile data between calls, so there is no owner
///   cache that could leak into a later account, and ownership is re-checked
///   by the server on every read and write.
class LiveProviderRepository implements ProviderRepository {
  LiveProviderRepository({
    required DataGateway gateway,
    required LocationRepository locations,
  })  : _gateway = gateway,
        _locations = locations;

  final DataGateway _gateway;
  final LocationRepository _locations;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Server bounds (backend-contract.md section 8): text 80, lists 20,
  /// limit 1-50.
  static Map<String, dynamic> searchParams(ProviderQuery q) => <String, dynamic>{
        'p_city_id': q.cityId,
        'p_locality_id': q.localityId,
        'p_text': q.text.trim().length > 80
            ? q.text.trim().substring(0, 80)
            : q.text.trim(),
        'p_category_ids': q.categoryIds.take(20).toList(),
        'p_locality_filter_ids': q.localityFilterIds.take(20).toList(),
        'p_open_now_only': q.openNowOnly,
        'p_home_visits_only': q.homeVisitsOnly,
        'p_limit': (q.limit ?? 20).clamp(1, 50),
      };

  // ------------------------------------------------------------- discovery
  @override
  Future<ProviderSearchResults> search(ProviderQuery query) async {
    final Map<String, dynamic> body = asMap(await guarded(
        () => _gateway.rpc('search_providers', searchParams(query)),),);
    final List<ProviderResultItem> items = <ProviderResultItem>[];
    for (final Object? raw
        in body['items'] is List ? body['items'] as List : <Object?>[]) {
      // One unreadable or non-published item is dropped, never guessed at.
      if (raw is! Map<String, dynamic>) continue;
      final ProviderProfile? p = _publicOrNull(raw['provider']);
      if (p != null) {
        items.add(ProviderResultItem(
          provider: p,
          isSponsored: boolOr(raw, 'isSponsored', false),
        ),);
      }
    }
    return ProviderSearchResults(
      items: items,
      totalCount: intOr(body, 'totalCount', items.length),
    );
  }

  @override
  Future<ProviderProfile?> publicProfileById(String id) async {
    if (!_uuid.hasMatch(id)) return null; // a junk link cannot be a listing
    final Object? raw = await guarded(
        () => _gateway.rpc('get_public_profile', <String, dynamic>{'p_id': id}),);
    if (raw == null) return null;
    final ProviderProfile profile = profileFromWire(raw);
    if (profile.id != id) throw malformed('profile id mismatch');
    return profile.isPubliclyVisible ? profile : null;
  }

  @override
  Future<List<ProviderProfile>> publishedInCity(String cityId) async =>
      _publicList(await guarded(() => _gateway.rpc(
          'providers_published_in_city', <String, dynamic>{'p_city_id': cityId},),),);

  @override
  Future<Map<String, int>> providerCountByLocality(String cityId) async {
    final Map<String, dynamic> raw = asMap(await guarded(() => _gateway.rpc(
        'provider_count_by_locality', <String, dynamic>{'p_city_id': cityId},),),);
    return <String, int>{
      for (final MapEntry<String, dynamic> e in raw.entries)
        if (e.value is num && (e.value as num) >= 0) e.key: (e.value as num).toInt(),
    };
  }

  @override
  Future<List<ProviderProfile>> similarProviders(
    ProviderProfile provider, {
    int limit = 6,
  }) async {
    final List<ProviderProfile> all = _publicList(await guarded(() =>
        _gateway.rpc('similar_providers', <String, dynamic>{
          'p_provider_id': provider.id,
          'p_limit': limit.clamp(1, 50),
        }),),);
    return all.where((ProviderProfile p) => p.id != provider.id).toList();
  }

  @override
  Future<List<Locality>> serviceAreaLocalities(ProviderProfile profile) async {
    final List<Locality> result = <Locality>[];
    for (final ProviderServiceArea area in profile.serviceAreas) {
      for (final Locality l in await _locations.localities(area.cityId)) {
        if (l.id == area.localityId) result.add(l);
      }
    }
    return result;
  }

  ProviderProfile? _publicOrNull(Object? raw) {
    try {
      final ProviderProfile p = profileFromWire(raw);
      return p.isPubliclyVisible ? p : null;
    } on RepositoryException {
      return null;
    }
  }

  List<ProviderProfile> _publicList(Object? raw) => <ProviderProfile>[
        for (final Object? item in raw is List ? raw : throw malformed('expected a list'))
          if (_publicOrNull(item) case final ProviderProfile p) p,
      ];

  // ----------------------------------------------------------------- owner
  /// Owner-only read. A profile id that is not the signed-in provider's own is
  /// refused before any request (and the server refuses it again).
  @override
  Future<ProviderProfile?> profileByIdForOwner({
    required String profileId,
    required ProviderSession session,
  }) async {
    if (session.profileId != profileId) {
      throw const RepositoryException(RepositoryErrorCode.notOwner);
    }
    final Object? raw = await guarded(() =>
        _gateway.rpc('get_owner_profile', <String, dynamic>{'p_id': profileId}),);
    return raw == null ? null : _owned(raw, profileId);
  }

  ProviderProfile _owned(Object? raw, String profileId) {
    final ProviderProfile profile = profileFromWire(raw);
    if (profile.id != profileId) throw malformed('profile id mismatch');
    return profile;
  }

  void _requireOwner(String profileId, ProviderSession session) {
    if (session.profileId != profileId || !_uuid.hasMatch(profileId)) {
      throw const RepositoryException(RepositoryErrorCode.notOwner);
    }
  }

  /// Registration is the identity flow (`ProviderAuthRepository.registerProfile`,
  /// one transactional RPC); this repository never creates profiles.
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
  }) =>
      Future<ProviderProfile>.error(const RepositoryException(
          RepositoryErrorCode.unavailable, 'use ProviderAuthRepository.registerProfile',),);

  /// Fields a provider may change (the `update_profile_full` patch keys).
  /// Identity, status, verification and moderation are deliberately absent.
  static const List<String> _patchKeys = <String>[
    'displayName',
    'description',
    'languages',
    'homeVisits',
    'availability',
    'whatsappEnabled',
    'phoneDisplayConsented',
    'pinCodes',
    'categoryIds',
    'serviceAreas',
    'workingHours',
    'startingPrices',
    'healthcareDetails',
  ];

  // ponytail: no expectedRevision yet (ProviderProfile carries no revision);
  // add it with the next profile-model change to get edit-conflict detection.
  @override
  Future<ProviderProfile> updateProfile({
    required ProviderProfile profile,
    required ProviderSession session,
  }) async {
    _requireOwner(profile.id, session);
    final Map<String, dynamic> json = profile.toJson();
    final Object? raw = await guarded(() => _gateway.rpc(
          'update_profile_full',
          <String, dynamic>{
            'p_profile_id': profile.id,
            'p_patch': <String, dynamic>{
              for (final String k in _patchKeys) k: json[k],
            },
          },
        ),);
    return _owned(raw, profile.id);
  }

  @override
  Future<ProviderProfile> publish({
    required String profileId,
    required ProviderSession session,
  }) =>
      setListingStatus(
        profileId: profileId,
        status: ListingStatus.published,
        session: session,
      );

  @override
  Future<ProviderProfile> setListingStatus({
    required String profileId,
    required ListingStatus status,
    required ProviderSession session,
  }) async {
    _requireOwner(profileId, session);
    // `deleted` is a row delete (backend-contract.md 4.6), not a status.
    if (status == ListingStatus.deleted) {
      throw const RepositoryException(RepositoryErrorCode.validationFailed);
    }
    return _owned(
      await guarded(() => _gateway.rpc('set_listing_status', <String, dynamic>{
            'p_profile_id': profileId,
            'p_status': status.name,
          }),),
      profileId,
    );
  }

  @override
  Future<ProviderProfile> setAvailability({
    required String profileId,
    required AvailabilityStatus availability,
    required ProviderSession session,
  }) async {
    _requireOwner(profileId, session);
    return _owned(
      await guarded(() => _gateway.rpc('set_availability', <String, dynamic>{
            'p_profile_id': profileId,
            'p_availability': availability.name,
          }),),
      profileId,
    );
  }

  @override
  Future<void> deleteListing({
    required String profileId,
    required ProviderSession session,
  }) async {
    _requireOwner(profileId, session);
    await guarded(() => _gateway
        .rpc('delete_listing', <String, dynamic>{'p_profile_id': profileId}),);
  }
}
