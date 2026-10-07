import '../../domain/models/service_category.dart';
import '../../domain/repositories/service_catalog_repository.dart';
import '../seed/category_seed.dart';

/// In-memory service catalog.
///
/// The taxonomy is seeded data on the client because it changes rarely and must
/// be available offline on a slow connection. A production build would sync it
/// from the backend and cache it; the interface is unchanged either way.
class MockServiceCatalogRepository implements ServiceCatalogRepository {
  static final List<ServiceGroup> _groups = List<ServiceGroup>.unmodifiable(
    (List<ServiceGroup>.from(CategorySeed.groups))
      ..sort((ServiceGroup a, ServiceGroup b) =>
          a.sortOrder.compareTo(b.sortOrder)),
  );

  static final Map<String, ServiceGroup> _groupsById = <String, ServiceGroup>{
    for (final ServiceGroup group in _groups) group.id: group,
  };

  static final List<ServiceCategory> _categories =
      List<ServiceCategory>.unmodifiable(
    (List<ServiceCategory>.from(CategorySeed.categories))
      ..sort((ServiceCategory a, ServiceCategory b) {
        final int byGroup = _groupOrder(a.groupId).compareTo(
          _groupOrder(b.groupId),
        );
        if (byGroup != 0) return byGroup;
        return a.sortOrder.compareTo(b.sortOrder);
      }),
  );

  static int _groupOrder(String groupId) =>
      _groupsById[groupId]?.sortOrder ?? 999;

  static final Map<String, ServiceCategory> _byId = <String, ServiceCategory>{
    for (final ServiceCategory category in _categories) category.id: category,
  };

  @override
  Future<List<ServiceGroup>> groups() async => _groups;

  @override
  Future<List<ServiceCategory>> categories() async => _launchCategories;

  /// Customer and onboarding lists show only categories open for listings;
  /// lookups by id still resolve every category (old saved data, editors).
  static final List<ServiceCategory> _launchCategories =
      List<ServiceCategory>.unmodifiable(
    _categories.where((ServiceCategory c) => c.isApprovedForLaunch),
  );

  @override
  Future<List<ServiceCategory>> categoriesByGroup(String groupId) async =>
      _launchCategories.where((ServiceCategory c) => c.groupId == groupId).toList();

  @override
  Future<List<ServiceCategory>> popularCategories() async => _launchCategories
      .where((ServiceCategory c) => c.isPopular)
      .toList();

  @override
  Future<List<ServiceCategory>> healthcareCategories() async =>
      _launchCategories.where((ServiceCategory c) => c.isHealthcare).toList();

  @override
  Future<ServiceCategory?> categoryById(String id) async => _byId[id];

  @override
  Future<List<ServiceCategory>> categoriesByIds(Iterable<String> ids) async {
    final List<ServiceCategory> result = <ServiceCategory>[];
    for (final String id in ids) {
      final ServiceCategory? category = _byId[id];
      if (category != null) result.add(category);
    }
    return result;
  }

  @override
  Future<ServiceGroup?> groupById(String id) async => _groupsById[id];

  @override
  Future<List<CategoryWithGroup>> categoriesWithGroup() async =>
      <CategoryWithGroup>[
        for (final ServiceCategory category in _launchCategories)
          if (_groupsById[category.groupId] != null)
            CategoryWithGroup(
              category: category,
              group: _groupsById[category.groupId]!,
            ),
      ];

  @override
  Future<List<ServiceCategory>> searchCategories(String query) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return _categories;

    final List<ServiceCategory> matches = _categories.where((
      ServiceCategory category,
    ) {
      if (category.name.toLowerCase().contains(needle)) return true;
      // Everyday words: "fridge" should find appliance repair.
      return category.keywords.any(
        (String keyword) => keyword.toLowerCase().contains(needle),
      );
    }).toList();

    // Name matches rank above keyword-only matches.
    matches.sort((ServiceCategory a, ServiceCategory b) {
      final bool aName = a.name.toLowerCase().contains(needle);
      final bool bName = b.name.toLowerCase().contains(needle);
      if (aName != bName) return aName ? -1 : 1;
      final bool aStarts = a.name.toLowerCase().startsWith(needle);
      final bool bStarts = b.name.toLowerCase().startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return matches;
  }

  @override
  Future<bool> requiresHealthcareDetails(Iterable<String> categoryIds) async {
    for (final String id in categoryIds) {
      if (_byId[id]?.isHealthcare ?? false) return true;
    }
    return false;
  }

  /// Group name for a category id. Convenience for cards, avoids a second
  /// lookup in the widget tree.
  Future<String?> groupNameForCategory(String categoryId) async =>
      _byId[categoryId] == null
          ? null
          : _groupsById[_byId[categoryId]!.groupId]?.name;
}
