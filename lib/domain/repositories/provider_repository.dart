import '../models/account.dart';
import '../models/enums.dart';
import '../models/location.dart';
import '../models/provider.dart';

/// Filters and text query for provider discovery.
///
/// Location is always applied: a customer only ever sees providers who serve
/// their selected locality (either as their base or as a declared service
/// area). The remaining filters are optional.
class ProviderQuery {
  const ProviderQuery({
    required this.cityId,
    required this.localityId,
    this.text = '',
    this.categoryIds = const <String>[],
    this.localityFilterIds = const <String>[],
    this.openNowOnly = false,
    this.homeVisitsOnly = false,
    this.limit,
  });

  /// The active market.
  final String cityId;

  /// The customer's selected locality. Never optional.
  final String localityId;

  /// Matches service names, category keywords, business names and localities.
  final String text;

  /// Multi-select: a provider matching any of these is included. An empty list
  /// means "all categories".
  final List<String> categoryIds;

  /// Restricts results to these localities. Empty means the selected locality
  /// only.
  final List<String> localityFilterIds;

  /// Only meaningful when the provider has working hours; providers without
  /// hours are excluded rather than assumed open.
  final bool openNowOnly;

  final bool homeVisitsOnly;

  final int? limit;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasFilters =>
      categoryIds.isNotEmpty ||
      localityFilterIds.isNotEmpty ||
      openNowOnly ||
      homeVisitsOnly;

  ProviderQuery copyWith({
    String? cityId,
    String? localityId,
    String? text,
    List<String>? categoryIds,
    List<String>? localityFilterIds,
    bool? openNowOnly,
    bool? homeVisitsOnly,
    int? limit,
  }) =>
      ProviderQuery(
        cityId: cityId ?? this.cityId,
        localityId: localityId ?? this.localityId,
        text: text ?? this.text,
        categoryIds: categoryIds ?? this.categoryIds,
        localityFilterIds: localityFilterIds ?? this.localityFilterIds,
        openNowOnly: openNowOnly ?? this.openNowOnly,
        homeVisitsOnly: homeVisitsOnly ?? this.homeVisitsOnly,
        limit: limit ?? this.limit,
      );

  ProviderQuery cleared() => ProviderQuery(
        cityId: cityId,
        localityId: localityId,
        text: text,
      );
}

/// One entry in a result list: a provider, and whether it is a paid placement.
///
/// Sponsorship travels with the item so a card can render its "Sponsored" label
/// and so organic items can never be silently reordered into a paid slot.
class ProviderResultItem {
  const ProviderResultItem({
    required this.provider,
    required this.isSponsored,
  });

  final ProviderProfile provider;

  /// Always rendered as "Sponsored". Never used to imply higher trust.
  final bool isSponsored;

  String get providerId => provider.id;
}

/// Search results.
class ProviderSearchResults {
  const ProviderSearchResults({
    required this.items,
    required this.totalCount,
    this.isSampleData = false,
  });

  const ProviderSearchResults.empty()
      : items = const <ProviderResultItem>[],
        totalCount = 0,
        isSampleData = false;

  /// Sponsored items first, then organic results. Never mixed silently.
  final List<ProviderResultItem> items;

  /// Total organic + sponsored count before [ProviderQuery.limit] was applied.
  final int totalCount;

  /// True while the directory is seeded fictional data. Demo contact behaviour
  /// depends on this.
  final bool isSampleData;

  bool get isEmpty => items.isEmpty;

  List<ProviderProfile> get providers =>
      items.map((ProviderResultItem i) => i.provider).toList();

  List<ProviderProfile> get sponsoredProviders => items
      .where((ProviderResultItem i) => i.isSponsored)
      .map((ProviderResultItem i) => i.provider)
      .toList();

  List<ProviderProfile> get organicProviders => items
      .where((ProviderResultItem i) => !i.isSponsored)
      .map((ProviderResultItem i) => i.provider)
      .toList();
}

/// Provider discovery.
abstract class ProviderRepository {
  /// Public search. Only published listings are ever returned; a paused
  /// listing disappears from every customer surface.
  Future<ProviderSearchResults> search(ProviderQuery query);

  /// Published provider by id. Returns null for draft, paused, deleted or
  /// suspended listings so a stale link cannot surface a hidden profile.
  Future<ProviderProfile?> publicProfileById(String id);

  /// Raw provider by id, ignoring publication status.
  ///
  /// Owner-only in the production backend. Provided here for the dashboard.
  Future<ProviderProfile?> profileByIdForOwner({
    required String profileId,
    required ProviderSession session,
  });

  /// All published providers in a city, used for counts and the categories tab.
  Future<List<ProviderProfile>> publishedInCity(String cityId);

  /// Number of published providers serving each locality, for picker hints.
  Future<Map<String, int>> providerCountByLocality(String cityId);

  /// Creates a profile for a freshly verified phone number.
  ///
  /// Fails with [RepositoryErrorCode.conflict] when the number already owns a
  /// profile, and [RepositoryErrorCode.locationNotActive] when the city is not
  /// an active market.
  Future<ProviderProfile> createProfile({
    required String phoneE164,
    required String displayName,
    required String baseCityId,
    required String baseLocalityId,
    required List<String> categoryIds,
    required List<String> serviceAreaIds,
    required ProviderSession session,
    String? description,
    List<String> languages,
    WorkingHours? workingHours,
    bool homeVisits,
    bool phoneDisplayConsented,
    bool whatsappEnabled,
    HealthcareDetails? healthcareDetails,
    List<String> photoCaptions,
    List<StartingPrice> startingPrices,
  });

  /// Saves provider-authored changes.
  ///
  /// Ownership is enforced here against [session] and must be enforced again
  /// server-side. Clients are never trusted.
  Future<ProviderProfile> updateProfile({
    required ProviderProfile profile,
    required ProviderSession session,
  });

  /// Publishes a listing. Requires phone consent and at least one category and
  /// service area.
  Future<ProviderProfile> publish({
    required String profileId,
    required ProviderSession session,
  });

  Future<ProviderProfile> setListingStatus({
    required String profileId,
    required ListingStatus status,
    required ProviderSession session,
  });

  Future<ProviderProfile> setAvailability({
    required String profileId,
    required AvailabilityStatus availability,
    required ProviderSession session,
  });

  /// Soft-deletes a listing, which also releases the phone number.
  Future<void> deleteListing({
    required String profileId,
    required ProviderSession session,
  });

  /// Localities a provider serves, resolved for display.
  Future<List<Locality>> serviceAreaLocalities(ProviderProfile profile);

  /// Providers in the same city and locality, excluding [providerId].
  Future<List<ProviderProfile>> similarProviders(
    ProviderProfile provider, {
    int limit = 6,
  });
}
