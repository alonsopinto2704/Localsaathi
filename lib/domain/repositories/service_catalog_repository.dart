import '../models/service_category.dart';

/// Read access to the service taxonomy.
///
/// Categories drive the home screen, the categories tab, provider onboarding
/// and search. Because they are data, adding a trade later is a data change.
abstract class ServiceCatalogRepository {
  Future<List<ServiceGroup>> groups();

  Future<List<ServiceCategory>> categories();

  Future<List<ServiceCategory>> categoriesByGroup(String groupId);

  /// Categories flagged for the home screen's popular row.
  Future<List<ServiceCategory>> popularCategories();

  /// Categories that require the healthcare detail form (qualification,
  /// specialty, clinic, registration).
  Future<List<ServiceCategory>> healthcareCategories();

  Future<ServiceCategory?> categoryById(String id);

  Future<List<ServiceCategory>> categoriesByIds(Iterable<String> ids);

  Future<ServiceGroup?> groupById(String id);

  /// Every category paired with its group, for grouped list rendering.
  Future<List<CategoryWithGroup>> categoriesWithGroup();

  /// Matches on name and the category's everyday-language keywords, so
  /// "fridge" finds appliance repair and "nurse" finds home nursing.
  Future<List<ServiceCategory>> searchCategories(String query);

  /// True when any selected category requires healthcare fields.
  Future<bool> requiresHealthcareDetails(Iterable<String> categoryIds);
}
