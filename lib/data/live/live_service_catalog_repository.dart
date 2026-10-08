import '../../domain/models/service_category.dart';
import '../../domain/repositories/service_catalog_repository.dart';
import '../supabase/data_gateway.dart';
import '../supabase/ref_cache.dart';
import '../supabase/wire.dart';

/// The service taxonomy from the backend (phase 064): groups and categories are
/// public-read tables, so adding or retiring a trade is a data change.
///
/// Lists (home, categories tab, onboarding, search) show only categories
/// approved for launch, in group then category order. Lookups by id still
/// resolve a retired category so old links and saved profiles keep their name;
/// `isApprovedForLaunch` stays false on it and the server refuses to publish
/// under it. Unknown icon keys pass through unchanged (the icon resolver falls
/// back to a generic icon). Names are single-language data for now.
class LiveServiceCatalogRepository implements ServiceCatalogRepository {
  LiveServiceCatalogRepository({
    required DataGateway gateway,
    DateTime Function()? now,
    Duration ttl = const Duration(minutes: 15),
  }) : _gateway = gateway {
    _catalog = RefCache<_Catalog>(_fetch, now: now, ttl: ttl);
  }

  final DataGateway _gateway;
  late final RefCache<_Catalog> _catalog;

  /// True while the catalog served is older than its expiry because a refresh
  /// failed.
  bool get isStale => _catalog.isStale;

  Future<_Catalog> _fetch() async {
    final List<ServiceGroup> groups =
        (await _gateway.selectRows('service_groups')).map(_group).toList()
          ..sort((ServiceGroup a, ServiceGroup b) =>
              a.sortOrder.compareTo(b.sortOrder),);
    final Map<String, int> order = <String, int>{
      for (final ServiceGroup g in groups) g.id: g.sortOrder,
    };
    final List<ServiceCategory> categories =
        (await _gateway.selectRows('service_categories'))
            .map(_category)
            .toList()
          ..sort((ServiceCategory a, ServiceCategory b) {
            final int byGroup = (order[a.groupId] ?? 999)
                .compareTo(order[b.groupId] ?? 999);
            return byGroup != 0 ? byGroup : a.sortOrder.compareTo(b.sortOrder);
          });
    return _Catalog(groups, categories);
  }

  static ServiceGroup _group(Map<String, dynamic> r) => ServiceGroup(
        id: reqString(r, 'id'),
        name: reqString(r, 'name'),
        iconKey: optString(r, 'icon_key') ?? CategoryIconKeys.other,
        sortOrder: intOr(r, 'sort_order', 999),
        description: optString(r, 'description'),
      );

  /// A category is launchable only when the backend says so explicitly.
  static ServiceCategory _category(Map<String, dynamic> r) => ServiceCategory(
        id: reqString(r, 'id'),
        groupId: reqString(r, 'group_id'),
        name: reqString(r, 'name'),
        iconKey: optString(r, 'icon_key') ?? CategoryIconKeys.other,
        sortOrder: intOr(r, 'sort_order', 999),
        keywords: stringList(r, 'keywords'),
        isHealthcare: boolOr(r, 'is_healthcare', false),
        isPopular: boolOr(r, 'is_popular', false),
        isApprovedForLaunch: boolOr(r, 'is_approved_for_launch', false),
      );

  @override
  Future<List<ServiceGroup>> groups() async => (await _catalog.get()).groups;

  @override
  Future<List<ServiceCategory>> categories() async =>
      (await _catalog.get()).launchable;

  @override
  Future<List<ServiceCategory>> categoriesByGroup(String groupId) async =>
      (await categories()).where((ServiceCategory c) => c.groupId == groupId).toList();

  @override
  Future<List<ServiceCategory>> popularCategories() async =>
      (await categories()).where((ServiceCategory c) => c.isPopular).toList();

  @override
  Future<List<ServiceCategory>> healthcareCategories() async =>
      (await categories()).where((ServiceCategory c) => c.isHealthcare).toList();

  @override
  Future<ServiceCategory?> categoryById(String id) async =>
      (await _catalog.get()).byId[id];

  @override
  Future<List<ServiceCategory>> categoriesByIds(Iterable<String> ids) async {
    final Map<String, ServiceCategory> byId = (await _catalog.get()).byId;
    return <ServiceCategory>[
      for (final String id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<ServiceGroup?> groupById(String id) async {
    for (final ServiceGroup g in (await _catalog.get()).groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  @override
  Future<List<CategoryWithGroup>> categoriesWithGroup() async {
    final _Catalog catalog = await _catalog.get();
    final Map<String, ServiceGroup> groups = <String, ServiceGroup>{
      for (final ServiceGroup g in catalog.groups) g.id: g,
    };
    return <CategoryWithGroup>[
      for (final ServiceCategory c in catalog.launchable)
        if (groups[c.groupId] != null)
          CategoryWithGroup(category: c, group: groups[c.groupId]!),
    ];
  }

  /// Bounded server search (`search_categories`: text <= 80, launch-approved
  /// only). Empty text lists the launchable categories without a request.
  @override
  Future<List<ServiceCategory>> searchCategories(String query) async {
    final String text = query.trim();
    if (text.isEmpty) return categories();
    final Object? raw = await guarded(() => _gateway.rpc(
          'search_categories',
          <String, dynamic>{
            'p_text': text.length > 80 ? text.substring(0, 80) : text,
          },
        ),);
    final Map<String, ServiceCategory> byId = (await _catalog.get()).byId;
    // Re-resolve against the catalog so a hit is never less strict than a list.
    return <ServiceCategory>[
      for (final Map<String, dynamic> row in asRows(raw))
        if (byId[reqString(row, 'id')]?.isApprovedForLaunch ?? false)
          byId[reqString(row, 'id')]!,
    ];
  }

  @override
  Future<bool> requiresHealthcareDetails(Iterable<String> categoryIds) async {
    final Map<String, ServiceCategory> byId = (await _catalog.get()).byId;
    return categoryIds.any((String id) => byId[id]?.isHealthcare ?? false);
  }
}

class _Catalog {
  _Catalog(this.groups, this.all)
      : byId = <String, ServiceCategory>{for (final ServiceCategory c in all) c.id: c},
        launchable = <ServiceCategory>[
          for (final ServiceCategory c in all)
            if (c.isApprovedForLaunch) c,
        ];

  final List<ServiceGroup> groups;
  final List<ServiceCategory> all;
  final Map<String, ServiceCategory> byId;
  final List<ServiceCategory> launchable;
}
