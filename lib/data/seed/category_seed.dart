import '../../domain/models/service_category.dart';

/// Seed data for the service taxonomy.
///
/// Categories are data so that adding a trade later — or enabling one only in
/// certain markets — needs no screen changes. The `keywords` list is what makes
/// search work in everyday language ("fridge", "leak", "nurse") rather than
/// requiring customers to know our category names.
class CategorySeed {
  const CategorySeed._();

  static const List<ServiceGroup> groups = <ServiceGroup>[
    ServiceGroup(
      id: 'home-repairs',
      name: 'Home repairs',
      iconKey: CategoryIconKeys.plumbing,
      sortOrder: 1,
      description: 'Plumbers, electricians, carpenters, painters, masons, welders, AC and appliance repair, locksmiths',
    ),
    ServiceGroup(
      id: 'home-services',
      name: 'Home services',
      iconKey: CategoryIconKeys.cleaning,
      sortOrder: 2,
      description: 'Cleaning, pest control, laundry and ironing',
    ),
    ServiceGroup(
      id: 'daily-workers',
      name: 'Daily workers',
      iconKey: CategoryIconKeys.labour,
      sortOrder: 3,
      description: 'General helpers, construction labourers, loading and unloading workers',
    ),
    ServiceGroup(
      id: 'vehicle-services',
      name: 'Vehicle services',
      iconKey: CategoryIconKeys.mechanic,
      sortOrder: 4,
      description: 'Two-wheeler mechanics, car mechanics, puncture repair, towing',
    ),
    ServiceGroup(
      id: 'healthcare',
      name: 'Healthcare',
      iconKey: CategoryIconKeys.medical,
      sortOrder: 5,
      description: 'General physicians, dentists, paediatricians, physiotherapists, diagnostic centres',
    ),
    ServiceGroup(
      id: 'other-services',
      name: 'Other services',
      iconKey: CategoryIconKeys.other,
      sortOrder: 6,
      description: 'Computer and laptop repair, network technicians, tutors, packers and movers',
    ),
  ];

  static const List<ServiceCategory> categories = <ServiceCategory>[
    // ------------------------------------------------------- home repairs
    ServiceCategory(
      id: 'plumbing',
      groupId: 'home-repairs',
      name: 'Plumber',
      iconKey: CategoryIconKeys.plumbing,
      sortOrder: 1,
      keywords: <String>['pipe', 'tap', 'leak', 'drain', 'tap repair', 'nal', 'fitting'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'electrical',
      groupId: 'home-repairs',
      name: 'Electrician',
      iconKey: CategoryIconKeys.electrical,
      sortOrder: 2,
      keywords: <String>['wiring', 'fan', 'light', 'switch', 'short circuit', 'inverter'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'carpentry',
      groupId: 'home-repairs',
      name: 'Carpenter',
      iconKey: CategoryIconKeys.carpentry,
      sortOrder: 3,
      keywords: <String>['furniture', 'door', 'wardrobe', 'bed', 'modular', 'shelf'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'painting',
      groupId: 'home-repairs',
      name: 'Painter',
      iconKey: CategoryIconKeys.painting,
      sortOrder: 4,
      keywords: <String>['paint', 'wall paint', 'distemper', 'putty', 'texture'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'masonry',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Mason',
      iconKey: CategoryIconKeys.masonry,
      sortOrder: 5,
      keywords: <String>['mistri', 'brick', 'cement', 'plaster', 'wall'],
    ),
    ServiceCategory(
      id: 'welding-fabrication',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Welding and fabrication',
      iconKey: CategoryIconKeys.masonry,
      sortOrder: 6,
      keywords: <String>['grill', 'gate', 'iron', 'steel', 'railing', 'welder'],
    ),
    ServiceCategory(
      id: 'ac-repair',
      groupId: 'home-repairs',
      name: 'AC repair and service',
      iconKey: CategoryIconKeys.appliance,
      sortOrder: 7,
      keywords: <String>['air conditioner', 'ac service', 'ac gas', 'cooling', 'split ac'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'appliance-repair',
      groupId: 'home-repairs',
      name: 'Appliance repair',
      iconKey: CategoryIconKeys.appliance,
      sortOrder: 8,
      keywords: <String>['fridge', 'refrigerator', 'washing machine', 'microwave', 'geyser', 'water purifier'],
    ),
    ServiceCategory(
      id: 'locksmith',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Locksmith and key maker',
      iconKey: CategoryIconKeys.lock,
      sortOrder: 9,
      keywords: <String>['key', 'lock', 'duplicate key', 'door lock'],
    ),
    ServiceCategory(
      id: 'tv-repair',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'TV and electronics repair',
      iconKey: CategoryIconKeys.appliance,
      sortOrder: 10,
      keywords: <String>['television', 'led tv', 'screen', 'speaker'],
    ),
    ServiceCategory(
      id: 'tiles-marble',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Tiles and marble work',
      iconKey: CategoryIconKeys.masonry,
      sortOrder: 11,
      keywords: <String>['tile', 'marble', 'flooring', 'granite'],
    ),
    ServiceCategory(
      id: 'waterproofing',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Waterproofing',
      iconKey: CategoryIconKeys.masonry,
      sortOrder: 12,
      keywords: <String>['seepage', 'leakage', 'damp', 'terrace'],
    ),
    ServiceCategory(
      id: 'interior-work',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-repairs',
      name: 'Interior and false ceiling',
      iconKey: CategoryIconKeys.masonry,
      sortOrder: 13,
      keywords: <String>['false ceiling', 'pop', 'interior', 'pvc panel'],
    ),

    // ------------------------------------------------------- home services
    ServiceCategory(
      id: 'home-cleaning',
      groupId: 'home-services',
      name: 'Home deep cleaning',
      iconKey: CategoryIconKeys.cleaning,
      sortOrder: 1,
      keywords: <String>['cleaning', 'deep clean', 'bathroom cleaning', 'kitchen cleaning', 'safai'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'pest-control',
      groupId: 'home-services',
      name: 'Pest control',
      iconKey: CategoryIconKeys.pest,
      sortOrder: 2,
      keywords: <String>['cockroach', 'termite', 'mosquito', 'rats', 'bed bugs'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'laundry-ironing',
      groupId: 'home-services',
      name: 'Laundry and ironing',
      iconKey: CategoryIconKeys.laundry,
      sortOrder: 3,
      keywords: <String>['laundry', 'ironing', 'dry clean', 'wash', 'clothes', 'dhobi', 'press'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'sofa-carpet-cleaning',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'home-services',
      name: 'Sofa and carpet cleaning',
      iconKey: CategoryIconKeys.cleaning,
      sortOrder: 4,
      keywords: <String>['sofa', 'carpet', 'mattress', 'shampoo'],
    ),
    ServiceCategory(
      id: 'water-tank-cleaning',
      groupId: 'home-services',
      name: 'Water tank cleaning',
      iconKey: CategoryIconKeys.cleaning,
      sortOrder: 5,
      keywords: <String>['tank', 'water tank', 'sump'],
    ),

    // -------------------------------------------------------- daily workers
    ServiceCategory(
      id: 'daily-worker',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'daily-workers',
      name: 'General helper',
      iconKey: CategoryIconKeys.labour,
      sortOrder: 1,
      keywords: <String>['helper', 'kaam wala', 'labour', 'daily wage', 'bai'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'construction-labourer',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'daily-workers',
      name: 'Construction labourer',
      iconKey: CategoryIconKeys.labour,
      sortOrder: 2,
      keywords: <String>['construction labour', 'mazdoor', 'cement labour', 'beldar', 'building worker'],
    ),
    ServiceCategory(
      id: 'loading-unloading',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'daily-workers',
      name: 'Loading and unloading worker',
      iconKey: CategoryIconKeys.labour,
      sortOrder: 3,
      keywords: <String>['loader', 'hamali', 'shifting labour', 'coolie'],
    ),
    ServiceCategory(
      id: 'gardening',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'daily-workers',
      name: 'Gardening',
      iconKey: CategoryIconKeys.gardening,
      sortOrder: 4,
      keywords: <String>['mali', 'garden', 'plants', 'lawn', 'tree cutting'],
    ),
    ServiceCategory(
      id: 'security-guard',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'daily-workers',
      name: 'Security guard',
      iconKey: CategoryIconKeys.security,
      sortOrder: 5,
      keywords: <String>['guard', 'watchman', 'security'],
    ),

    // ----------------------------------------------------- vehicle services
    ServiceCategory(
      id: 'mechanic',
      groupId: 'vehicle-services',
      name: 'Two-wheeler mechanic',
      iconKey: CategoryIconKeys.mechanic,
      sortOrder: 1,
      keywords: <String>['bike', 'scooter', 'servicing', 'clutch', 'brake'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'car-mechanic',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'vehicle-services',
      name: 'Car mechanic',
      iconKey: CategoryIconKeys.mechanic,
      sortOrder: 2,
      keywords: <String>['car', 'car service', 'engine', 'battery'],
    ),
    ServiceCategory(
      id: 'puncture-repair',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'vehicle-services',
      name: 'Puncture repair',
      iconKey: CategoryIconKeys.mechanic,
      sortOrder: 3,
      keywords: <String>['tyre', 'puncture', 'tire', 'air'],
    ),
    ServiceCategory(
      id: 'towing',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'vehicle-services',
      name: 'Towing service',
      iconKey: CategoryIconKeys.towing,
      sortOrder: 4,
      keywords: <String>['tow', 'breakdown', 'recovery', 'crane'],
    ),
    ServiceCategory(
      id: 'driver',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'vehicle-services',
      name: 'Driver',
      iconKey: CategoryIconKeys.driver,
      sortOrder: 5,
      keywords: <String>['chauffeur', 'car driver', 'outstation'],
    ),

    // ----------------------------------------------------------- healthcare
    ServiceCategory(
      id: 'general-physician',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'General physician',
      iconKey: CategoryIconKeys.medical,
      sortOrder: 1,
      keywords: <String>['doctor', 'mbbs', 'clinic', 'physician', 'consultation'],
      isHealthcare: true,
      isPopular: true,
    ),
    ServiceCategory(
      id: 'dentist',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Dentist',
      iconKey: CategoryIconKeys.dental,
      sortOrder: 2,
      keywords: <String>['dental', 'tooth', 'teeth', 'dentist clinic'],
      isHealthcare: true,
      isPopular: true,
    ),
    ServiceCategory(
      id: 'paediatrician',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Paediatrician',
      iconKey: CategoryIconKeys.paediatric,
      sortOrder: 3,
      keywords: <String>['pediatrician', 'paediatrician', 'child doctor', 'baby doctor', 'infant', 'children'],
      isHealthcare: true,
      isPopular: true,
    ),
    ServiceCategory(
      id: 'physiotherapist',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Physiotherapist',
      iconKey: CategoryIconKeys.physio,
      sortOrder: 4,
      keywords: <String>['physio', 'pain', 'rehab', 'back pain'],
      isHealthcare: true,
    ),
    ServiceCategory(
      id: 'diagnostic-centre',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Diagnostic centre',
      iconKey: CategoryIconKeys.diagnostics,
      sortOrder: 5,
      keywords: <String>['lab', 'blood test', 'pathology', 'x-ray', 'sonography', 'sample collection'],
      isHealthcare: true,
    ),
    ServiceCategory(
      id: 'home-nursing',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Home nursing and attendant',
      iconKey: CategoryIconKeys.medical,
      sortOrder: 6,
      keywords: <String>['nurse', 'attendant', 'elder care', 'injection', 'dressing'],
      isHealthcare: true,
    ),
    ServiceCategory(
      id: 'veterinary',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'healthcare',
      name: 'Veterinary doctor',
      iconKey: CategoryIconKeys.medical,
      sortOrder: 7,
      keywords: <String>['vet', 'pet doctor', 'animal'],
      isHealthcare: true,
    ),

    // ------------------------------------------------------- other services
    ServiceCategory(
      id: 'computer-repair',
      groupId: 'other-services',
      name: 'Computer and laptop repair',
      iconKey: CategoryIconKeys.computer,
      sortOrder: 1,
      keywords: <String>['laptop', 'pc', 'desktop', 'format', 'virus', 'hardware', 'printer'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'network-technician',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Network technician',
      iconKey: CategoryIconKeys.network,
      sortOrder: 2,
      keywords: <String>['wifi', 'router', 'broadband', 'network', 'cctv', 'lan', 'internet'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'tutor',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Tutor',
      iconKey: CategoryIconKeys.tutor,
      sortOrder: 3,
      keywords: <String>['tuition', 'teacher', 'coaching', 'maths', 'science', 'english'],
      isPopular: true,
    ),
    ServiceCategory(
      id: 'packers-movers',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Packers and movers',
      iconKey: CategoryIconKeys.moving,
      sortOrder: 4,
      keywords: <String>['shifting', 'house shifting', 'movers', 'packers', 'transport'],
    ),
    ServiceCategory(
      id: 'it-support',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Internet and WiFi setup',
      iconKey: CategoryIconKeys.computer,
      sortOrder: 5,
      keywords: <String>['wifi', 'router', 'broadband', 'network', 'cctv'],
    ),
    ServiceCategory(
      id: 'mobile-repair',
      groupId: 'other-services',
      name: 'Mobile repair',
      iconKey: CategoryIconKeys.computer,
      sortOrder: 6,
      keywords: <String>['phone', 'screen replacement', 'battery', 'display'],
    ),
    ServiceCategory(
      id: 'beauty-at-home',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Beauty services at home',
      iconKey: CategoryIconKeys.beauty,
      sortOrder: 7,
      keywords: <String>['parlour', 'salon', 'facial', 'haircut', 'mehendi'],
    ),
    ServiceCategory(
      id: 'tailoring',
      groupId: 'other-services',
      name: 'Tailoring and alteration',
      iconKey: CategoryIconKeys.tailoring,
      sortOrder: 8,
      keywords: <String>['darzi', 'stitching', 'blouse', 'alteration'],
    ),
    ServiceCategory(
      id: 'event-help',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Event and catering help',
      iconKey: CategoryIconKeys.events,
      sortOrder: 9,
      keywords: <String>['cook', 'catering', 'waiter', 'party help', 'decoration'],
    ),
    ServiceCategory(
      id: 'other-services',
      isApprovedForLaunch: false, // wave 2 / healthcare (phase-009)
      groupId: 'other-services',
      name: 'Other local services',
      iconKey: CategoryIconKeys.other,
      sortOrder: 10,
      keywords: <String>['misc', 'other', 'general'],
    ),
  ];
}
