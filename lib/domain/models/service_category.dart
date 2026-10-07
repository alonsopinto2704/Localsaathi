/// Icon identifiers used by categories.
///
/// Categories are data, so they cannot hold an `IconData` directly without
/// coupling the data layer to Flutter. They store a key and the presentation
/// layer resolves it through [IconKeys]/`categoryIcon()`.
class CategoryIconKeys {
  const CategoryIconKeys._();

  static const String plumbing = 'plumbing';
  static const String electrical = 'electrical';
  static const String carpentry = 'carpentry';
  static const String painting = 'painting';
  static const String masonry = 'masonry';
  static const String appliance = 'appliance';
  static const String lock = 'lock';
  static const String cleaning = 'cleaning';
  static const String pest = 'pest';
  static const String labour = 'labour';
  static const String mechanic = 'mechanic';
  static const String towing = 'towing';
  static const String medical = 'medical';
  static const String dental = 'dental';
  static const String physio = 'physio';
  static const String diagnostics = 'diagnostics';
  static const String computer = 'computer';
  static const String tutor = 'tutor';
  static const String moving = 'moving';
  static const String laundry = 'laundry';
  static const String paediatric = 'paediatric';
  static const String network = 'network';
  static const String beauty = 'beauty';
  static const String tailoring = 'tailoring';
  static const String security = 'security';
  static const String driver = 'driver';
  static const String gardening = 'gardening';
  static const String events = 'events';
  static const String other = 'other';
}

/// A top-level grouping shown on the Categories tab.
class ServiceGroup {
  const ServiceGroup({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    this.description,
  });

  final String id;
  final String name;
  final String iconKey;
  final int sortOrder;
  final String? description;
}

/// A service that can be searched, filtered and attached to a provider.
///
/// [isHealthcare] is the switch that turns on the healthcare-specific form
/// fields (qualifications, specialty, clinic, registration). This keeps
/// category-specific forms data-driven instead of special-casing doctors in
/// screen code.
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.groupId,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    this.keywords = const <String>[],
    this.isHealthcare = false,
    this.isPopular = false,
    this.isApprovedForLaunch = true,
  });

  final String id;
  final String groupId;
  final String name;
  final String iconKey;
  final int sortOrder;

  /// Extra search terms ("nurse", "injection", "fridge") that map a customer's
  /// everyday words onto the right category.
  final List<String> keywords;

  /// Requires the healthcare detail fields.
  final bool isHealthcare;

  /// Shown on the home screen's popular row.
  final bool isPopular;

  /// Whether providers may publish under this category in the launch market.
  final bool isApprovedForLaunch;

  /// True when this category may only be offered by a provider who visits the
  /// customer; informational only in this build.
  bool get needsHealthcareDetails => isHealthcare;

  @override
  String toString() => name;
}

/// A resolved category plus the group it belongs to, for display.
class CategoryWithGroup {
  const CategoryWithGroup({required this.category, required this.group});

  final ServiceCategory category;
  final ServiceGroup group;

  String get label => category.name;
}
