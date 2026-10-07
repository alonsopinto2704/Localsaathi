import '../../domain/models/enums.dart';
import '../../domain/models/provider.dart';

import 'locality_coordinates.dart';

/// Seeded, entirely fictional provider listings for the Mumbai launch market.
///
/// Ground rules this file follows, and must keep following:
///
/// * **No real people.** Every name is invented for a demo, not scraped,
///   imported or adapted from a real directory.
/// * **No usable phone numbers.** Numbers are generated locally from a
///   non-routable pattern and are rendered masked in the UI
///   ([ProviderProfile.isDemoProfile] is true for all of them). The app never
///   dials them.
/// * **No fake trust signals.** No reviews, no ratings, no completed-job
///   counts, no invented qualifications or registration numbers. Healthcare
///   entries carry a specialty only where a provider would obviously state one,
///   and are labelled as provider-supplied.
/// * **Enough variety to exercise the UI:** several localities, multiple
///   categories, multi-locality service areas, varying working hours (including
///   a 24-hour provider and one with no hours at all), home-visit and
///   workshop-only providers, and two non-published listings so the "paused
///   listings disappear" rule is demonstrable.
class ProviderSeed {
  const ProviderSeed._();

  static const int _seedCount = 70;

  /// Builds the seeded provider list. Deterministic: same output every run, so
  /// tests can assert on it.
  static List<ProviderProfile> build() {
    final DateTime today = DateTime(2026, 1, 5, 10, 0);
    final List<_Entry> entries = _entries;
    final List<ProviderProfile> profiles = <ProviderProfile>[];
    for (int i = 0; i < entries.length; i++) {
      profiles.add(entries[i].toProfile(
        index: i,
        reference: today,
        phone: _phoneFor(i),
      ));
    }
    return profiles;
  }

  /// Generates a demo number that is obviously not a live subscriber line.
  ///
  /// Uses the 999 range plus a zero-heavy tail, and is masked before display.
  static String _phoneFor(int index) {
    final int a = (index * 37 + 11) % 1000;
    final int b = (index * 91 + 7) % 1000;
    final String block = a.toString().padLeft(3, '0');
    final String tail = b.toString().padLeft(3, '0');
    return '+91999$block$tail';
  }

  /// Deterministic id generator, shared with the repository when a badge is
  /// needed for a seeded record.
  static String seedId(String prefix, int index) =>
      '$prefix-seed-${index.toString().padLeft(3, '0')}';

  static const List<_Entry> _entries = <_Entry>[
    // ====================================================== Home repair
    _Entry(
      name: 'Sharma Plumbing Works',
      categories: <String>['plumbing'],
      base: 'mh-mumbai-andheri-west',
      areas: <String>['mh-mumbai-andheri-west', 'mh-mumbai-andheri-east', 'mh-mumbai-jogeshwari', 'mh-mumbai-goregaon'],
      description:
          'Leaking taps, blocked drains, bathroom fittings and concealed pipe work. Same-day visits across Andheri and Goregaon.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'plumbing': 249},
    ),
    _Entry(
      name: 'Iqbal Plumbing Service',
      categories: <String>['plumbing'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-sion', 'mh-mumbai-mankhurd'],
      description:
          'Twenty years of plumbing work in the Kurla–Chembur belt. Overhead tank cleaning, motor fitting and pipeline repair.',
      languages: <String>['Hindi', 'Urdu', 'Marathi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'plumbing': 199},
    ),
    _Entry(
      name: 'Nair Pipe and Drain Solutions',
      categories: <String>['plumbing', 'waterproofing'],
      base: 'mh-mumbai-powai',
      areas: <String>['mh-mumbai-powai', 'mh-mumbai-vikhroli', 'mh-mumbai-ghatkopar', 'mh-mumbai-kanjurmarg'],
      description:
          'Drainage and seepage specialists. We handle society-level pipeline work and bathroom leakage treatment.',
      languages: <String>['Malayalam', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Ravi Electricals',
      categories: <String>['electrical'],
      base: 'mh-mumbai-borivali-west',
      areas: <String>['mh-mumbai-borivali-west', 'mh-mumbai-borivali-east', 'mh-mumbai-kandivali', 'mh-mumbai-dahisar'],
      description:
          'House wiring, fan and light fitting, MCB and inverter installation. Licensed wireman for residential societies.',
      languages: <String>['Hindi', 'Marathi', 'Gujarati'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'electrical': 299},
    ),
    _Entry(
      name: 'Sana Electric Works',
      categories: <String>['electrical'],
      base: 'mh-mumbai-bandra-east',
      areas: <String>['mh-mumbai-bandra-east', 'mh-mumbai-bandra-west', 'mh-mumbai-khar', 'mh-mumbai-santacruz', 'mh-mumbai-mahim'],
      description:
          'Emergency electrical fault finding, switchboard replacement and complete flat rewiring. Late evening slots available.',
      languages: <String>['Hindi', 'English', 'Marathi'],
      hours: _Hours.late,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Deshmukh Electrical Contractors',
      categories: <String>['electrical', 'it-support'],
      base: 'mh-mumbai-dadar-west',
      areas: <String>['mh-mumbai-dadar-west', 'mh-mumbai-dadar-east', 'mh-mumbai-parel', 'mh-mumbai-matunga', 'mh-mumbai-wadala'],
      description:
          'Electrical contracting for homes and small offices, plus CCTV and network cabling.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: false,
    ),
    _Entry(
      name: 'Khan Carpentry Works',
      categories: <String>['carpentry'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-ghatkopar', 'mh-mumbai-bhandup'],
      description:
          'Modular kitchen, wardrobes, beds and door repair. Site measurement is free.',
      languages: <String>['Hindi', 'Urdu', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'carpentry': 499},
    ),
    _Entry(
      name: 'Vishwakarma Furniture and Repairs',
      categories: <String>['carpentry', 'interior-work'],
      base: 'mh-mumbai-malad',
      areas: <String>['mh-mumbai-malad', 'mh-mumbai-kandivali', 'mh-mumbai-goregaon', 'mh-mumbai-borivali-east'],
      description:
          'Furniture repair, polishing and false ceiling work. Small jobs accepted.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Saifee Key Makers and Locksmith',
      categories: <String>['locksmith'],
      base: 'mh-mumbai-byculla',
      areas: <String>['mh-mumbai-byculla', 'mh-mumbai-mazgaon', 'mh-mumbai-dadar-east', 'mh-mumbai-wadala-sewri'],
      description:
          'Duplicate keys, main door lock fitting and lock opening service. Shop-based with visiting service on request.',
      languages: <String>['Hindi', 'Urdu', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
      prices: <String, int>{'locksmith': 99},
    ),
    _Entry(
      name: 'Cool Care AC Services',
      categories: <String>['ac-repair'],
      base: 'mh-mumbai-andheri-east',
      areas: <String>['mh-mumbai-andheri-east', 'mh-mumbai-andheri-west', 'mh-mumbai-santacruz', 'mh-mumbai-vile-parle', 'mh-mumbai-juhu'],
      description:
          'Split and window AC service, gas charging, installation and uninstallation. Annual maintenance contracts for societies.',
      languages: <String>['Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'ac-repair': 399},
      photoCaptions: <String>['AC service van', 'Split unit cleaning'],
    ),
    _Entry(
      name: 'Shree Appliance Care',
      categories: <String>['appliance-repair', 'tv-repair'],
      base: 'mh-mumbai-borivali-west',
      areas: <String>['mh-mumbai-borivali-west', 'mh-mumbai-dahisar', 'mh-mumbai-kandivali'],
      description:
          'Refrigerator, washing machine, microwave and LED TV repair. Genuine spares with a service warranty.',
      languages: <String>['Gujarati', 'Hindi', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Sai Appliance Solutions',
      categories: <String>['appliance-repair'],
      base: 'mh-mumbai-ghatkopar',
      areas: <String>['mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-bhandup', 'mh-mumbai-mulund', 'mh-mumbai-powai'],
      description:
          'Washing machine and water purifier service. We also do annual servicing plans.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: false,
    ),
    _Entry(
      name: 'Sundaram Electronics',
      categories: <String>['tv-repair', 'computer-repair'],
      base: 'mh-mumbai-lower-parel',
      areas: <String>['mh-mumbai-lower-parel', 'mh-mumbai-parel', 'mh-mumbai-worli', 'mh-mumbai-prabhadevi'],
      description:
          'TV panel and laptop repair at our workshop. Pickup and drop available in the Lower Parel area.',
      languages: <String>['Tamil', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
    ),

    // ================================================== Construction
    _Entry(
      name: 'Ansari Painting Contractors',
      categories: <String>['painting'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-mankhurd', 'mh-mumbai-sion'],
      description:
          'Interior and exterior painting, putty and texture finishes. Free colour consultation.',
      languages: <String>['Hindi', 'Urdu'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'painting': 18},
    ),
    _Entry(
      name: 'ColourCraft Painters',
      categories: <String>['painting'],
      base: 'mh-mumbai-bandra-west',
      areas: <String>['mh-mumbai-bandra-west', 'mh-mumbai-khar', 'mh-mumbai-juhu', 'mh-mumbai-santacruz'],
      description:
          'Flat repainting with dust-free sanding. We cover furniture and clean up daily.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Jadhav Masonry Works',
      categories: <String>['masonry', 'tiles-marble'],
      base: 'mh-mumbai-dadar-east',
      areas: <String>['mh-mumbai-dadar-east', 'mh-mumbai-dadar-west', 'mh-mumbai-matunga', 'mh-mumbai-wadala-sewri', 'mh-mumbai-mahim'],
      description:
          'Brickwork, plastering, tiling and marble flooring. Team of four available for larger jobs.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Pawar Tile and Marble Fixing',
      categories: <String>['tiles-marble', 'waterproofing'],
      base: 'mh-mumbai-andheri-east',
      areas: <String>['mh-mumbai-andheri-east', 'mh-mumbai-andheri-west', 'mh-mumbai-jogeshwari'],
      description:
          'Tile laying, skirting and bathroom waterproofing with a leak test.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: false,
    ),
    _Entry(
      name: 'Om Sai Waterproofing',
      categories: <String>['waterproofing'],
      base: 'mh-mumbai-chembur',
      areas: <String>['mh-mumbai-chembur', 'mh-mumbai-mankhurd', 'mh-mumbai-kurla', 'mh-mumbai-ghatkopar'],
      description:
          'Terrace, bathroom and external wall waterproofing. Seepage diagnosis and five-year workmanship assurance.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Shaikh Welding and Fabrication',
      categories: <String>['welding-fabrication'],
      base: 'mh-mumbai-mankhurd',
      areas: <String>['mh-mumbai-mankhurd', 'mh-mumbai-chembur', 'mh-mumbai-kurla'],
      description:
          'Window grills, gates, railings and shed fabrication. On-site welding available.',
      languages: <String>['Hindi', 'Urdu', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Skyline False Ceiling',
      categories: <String>['interior-work'],
      base: 'mh-mumbai-malad',
      areas: <String>['mh-mumbai-malad', 'mh-mumbai-goregaon', 'mh-mumbai-kandivali', 'mh-mumbai-borivali-west'],
      description:
          'POP and gypsum false ceiling, PVC panelling and cove lighting for homes and shops.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),

    // ====================================================== Cleaning
    _Entry(
      name: 'Shine Home Deep Cleaning',
      categories: <String>['home-cleaning'],
      base: 'mh-mumbai-powai',
      areas: <String>['mh-mumbai-powai', 'mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-mulund', 'mh-mumbai-bhandup'],
      description:
          'Full home deep cleaning including kitchen degreasing, bathroom scrubbing and window cleaning. Team of three with machines.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'home-cleaning': 1499},
      photoCaptions: <String>['Cleaning team at work'],
    ),
    _Entry(
      name: 'Sparkle Cleaning Services',
      categories: <String>['home-cleaning', 'sofa-carpet-cleaning'],
      base: 'mh-mumbai-borivali-west',
      areas: <String>['mh-mumbai-borivali-west', 'mh-mumbai-borivali-east', 'mh-mumbai-dahisar', 'mh-mumbai-kandivali', 'mh-mumbai-malad'],
      description:
          'Deep cleaning and sofa or mattress shampooing with extraction machines.',
      languages: <String>['Hindi', 'Gujarati'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'PestFree Mumbai',
      categories: <String>['pest-control'],
      base: 'mh-mumbai-bandra-east',
      areas: <String>['mh-mumbai-bandra-east', 'mh-mumbai-bandra-west', 'mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-mahim'],
      description:
          'Cockroach, termite, rodent and bed bug treatment with odourless, child-safe chemicals.',
      languages: <String>['Hindi', 'English', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'pest-control': 899},
    ),
    _Entry(
      name: 'Guardian Pest Solutions',
      categories: <String>['pest-control'],
      base: 'mh-mumbai-ghatkopar',
      areas: <String>['mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-bhandup', 'mh-mumbai-powai'],
      description:
          'Society-level pest management with quarterly contracts. Termite pre-construction treatment available.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: false,
    ),
    _Entry(
      name: 'CleanSofa Care',
      categories: <String>['sofa-carpet-cleaning', 'home-cleaning'],
      base: 'mh-mumbai-juhu',
      areas: <String>['mh-mumbai-juhu', 'mh-mumbai-vile-parle', 'mh-mumbai-santacruz', 'mh-mumbai-andheri-west'],
      description:
          'Sofa, carpet and mattress cleaning at your home using low-moisture extraction.',
      languages: <String>['Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'JalShuddhi Tank Cleaning',
      categories: <String>['water-tank-cleaning'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-sion', 'mh-mumbai-wadala', 'mh-mumbai-mankhurd'],
      description:
          'Overhead and underground water tank cleaning with draining, scrubbing and disinfection.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'water-tank-cleaning': 999},
    ),

    // ===================================================== Transport
    _Entry(
      name: 'Rafiq Two Wheeler Workshop',
      categories: <String>['mechanic'],
      base: 'mh-mumbai-bandra-east',
      areas: <String>['mh-mumbai-bandra-east', 'mh-mumbai-kurla', 'mh-mumbai-sion', 'mh-mumbai-mahim'],
      description:
          'General servicing, clutch and brake work, engine repair for scooters and motorcycles.',
      languages: <String>['Hindi', 'Urdu', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
    ),
    _Entry(
      name: 'Highway Puncture and Tyre Service',
      categories: <String>['puncture-repair'],
      base: 'mh-mumbai-chembur',
      areas: <String>['mh-mumbai-chembur', 'mh-mumbai-mankhurd', 'mh-mumbai-kurla', 'mh-mumbai-vikhroli'],
      description:
          'Puncture repair and tyre replacement for cars and two-wheelers. Roadside assistance within the area.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.roundTheClock,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'puncture-repair': 150},
    ),
    _Entry(
      name: 'Murthy Car Care',
      categories: <String>['car-mechanic'],
      base: 'mh-mumbai-andheri-east',
      areas: <String>['mh-mumbai-andheri-east', 'mh-mumbai-andheri-west', 'mh-mumbai-jogeshwari', 'mh-mumbai-goregaon'],
      description:
          'Car servicing, AC repair, battery replacement and pre-owned vehicle inspection.',
      languages: <String>['Tamil', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
    ),
    _Entry(
      name: 'Mumbai Towing Assistance',
      categories: <String>['towing'],
      base: 'mh-mumbai-dadar-east',
      areas: <String>['mh-mumbai-dadar-east', 'mh-mumbai-dadar-west', 'mh-mumbai-parel', 'mh-mumbai-worli', 'mh-mumbai-lower-parel'],
      description:
          'Flatbed towing and breakdown recovery for cars and two-wheelers. Available all night.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.roundTheClock,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Shree Ganesh Packers and Movers',
      categories: <String>['packers-movers', 'loading-unloading'],
      base: 'mh-mumbai-malad',
      areas: <String>['mh-mumbai-malad', 'mh-mumbai-kandivali', 'mh-mumbai-borivali-west', 'mh-mumbai-goregaon'],
      description:
          'Local and outstation house shifting with packing material, loading labour and a closed container.',
      languages: <String>['Hindi', 'Marathi', 'Gujarati'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'packers-movers': 4999},
      photoCaptions: <String>['Loading container'],
    ),
    _Entry(
      name: 'Sai Loading and Shifting Labour',
      categories: <String>['loading-unloading', 'daily-worker'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-sion', 'mh-mumbai-mankhurd', 'mh-mumbai-wadala'],
      description:
          'Loading and unloading labour for household shifting, shop stock and godown work. Hourly or daily.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'loading-unloading': 600},
    ),
    _Entry(
      name: 'Prakash Driver Service',
      categories: <String>['driver'],
      base: 'mh-mumbai-borivali-east',
      areas: <String>['mh-mumbai-borivali-east', 'mh-mumbai-borivali-west', 'mh-mumbai-dahisar', 'mh-mumbai-malad'],
      description:
          'Experienced driver for daily office runs, monthly packages and outstation trips. Valid commercial licence.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.flexibleNoHours,
      homeVisits: false,
      whatsapp: true,
    ),

    // ======================================================== Health
    _Entry(
      name: 'Dr. Meera Joshi',
      categories: <String>['general-physician'],
      base: 'mh-mumbai-bandra-west',
      areas: <String>['mh-mumbai-bandra-west', 'mh-mumbai-khar', 'mh-mumbai-santacruz', 'mh-mumbai-juhu'],
      description:
          'General practice clinic seeing adults and children for everyday illnesses and preventive check-ups.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.clinicEvening,
      homeVisits: false,
      whatsapp: false,
      healthcare: const HealthcareDetails(
        qualification: 'MBBS',
        specialty: 'General physician',
        clinicName: 'Sunshine Family Clinic',
        clinicAddress: '2nd floor, Linking Road, Bandra West (near the station road junction)',
        consultationHoursNote: 'Mon–Sat 10am–1pm and 6pm–9pm',
        acceptsWalkIns: true,
      ),
      prices: <String, int>{'general-physician': 500},
    ),
    _Entry(
      name: 'Dr. Anil Kulkarni',
      categories: <String>['general-physician'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-sion'],
      description:
          'Family physician with an interest in diabetes and blood pressure management.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.clinicMorning,
      homeVisits: false,
      whatsapp: false,
      healthcare: const HealthcareDetails(
        qualification: 'MBBS, MD (General Medicine)',
        specialty: 'General physician',
        clinicName: 'Kulkarni Clinic',
        clinicAddress: 'LBS Marg, Kurla West',
        consultationHoursNote: 'Mon–Sat 9am–12pm',
      ),
      prices: <String, int>{'general-physician': 400},
    ),
    _Entry(
      name: 'Dr. Farah Sheikh',
      categories: <String>['dentist'],
      base: 'mh-mumbai-andheri-west',
      areas: <String>['mh-mumbai-andheri-west', 'mh-mumbai-andheri-east', 'mh-mumbai-jogeshwari', 'mh-mumbai-vile-parle'],
      description:
          'Dental clinic offering check-ups, fillings, root canal treatment and cleaning.',
      languages: <String>['English', 'Hindi', 'Marathi'],
      hours: _Hours.clinicEvening,
      homeVisits: false,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        qualification: 'BDS',
        specialty: 'Dentist',
        clinicName: 'Smile Studio Dental Clinic',
        clinicAddress: 'SV Road, Andheri West',
        consultationHoursNote: 'Tue–Sun 11am–2pm and 5pm–9pm',
      ),
      prices: <String, int>{'dentist': 300},
      photoCaptions: <String>['Clinic reception'],
    ),
    _Entry(
      name: 'Dr. Rohit Pawar',
      categories: <String>['physiotherapist'],
      base: 'mh-mumbai-powai',
      areas: <String>['mh-mumbai-powai', 'mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-kandivali'],
      description:
          'Physiotherapy for back pain, sports injuries and post-surgical rehabilitation. Home sessions on request.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        qualification: 'BPT (Bachelor of Physiotherapy)',
        specialty: 'Musculoskeletal physiotherapy',
        clinicName: 'MoveWell Physiotherapy',
        clinicAddress: 'Hiranandani Gardens, Powai',
        consultationHoursNote: 'Mon–Sat 8am–8pm',
      ),
    ),
    _Entry(
      name: 'Dr. Kavita Rao',
      categories: <String>['physiotherapist'],
      base: 'mh-mumbai-borivali-west',
      areas: <String>['mh-mumbai-borivali-west', 'mh-mumbai-kandivali', 'mh-mumbai-malad', 'mh-mumbai-dahisar'],
      description:
          'Home-visit physiotherapy for elderly patients and post-operative recovery.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        qualification: 'BPT, MPT (Orthopaedics)',
        specialty: 'Geriatric and orthopaedic physiotherapy',
        consultationHoursNote: 'Mon–Sat 9am–7pm, home visits by appointment',
      ),
    ),
    _Entry(
      name: 'Precision Diagnostics Centre',
      categories: <String>['diagnostic-centre'],
      base: 'mh-mumbai-ghatkopar',
      areas: <String>['mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-bhandup', 'mh-mumbai-powai', 'mh-mumbai-mulund'],
      description:
          'Pathology lab and imaging centre with home sample collection in the surrounding localities.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.clinicMorning,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        specialty: 'Pathology and diagnostic imaging',
        clinicName: 'Precision Diagnostics Centre',
        clinicAddress: 'MG Road, Ghatkopar East',
        consultationHoursNote: 'Mon–Sat 7am–9pm, Sunday 7am–1pm',
        isDiagnosticCentre: true,
      ),
      photoCaptions: <String>['Sample collection room'],
    ),
    _Entry(
      name: 'Wellness Path Labs',
      categories: <String>['diagnostic-centre'],
      base: 'mh-mumbai-dadar-west',
      areas: <String>['mh-mumbai-dadar-west', 'mh-mumbai-dadar-east', 'mh-mumbai-parel', 'mh-mumbai-matunga', 'mh-mumbai-mahim'],
      description:
          'Blood tests, health packages and ECG with free home collection in Dadar and nearby areas.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        specialty: 'Clinical pathology',
        clinicName: 'Wellness Path Labs',
        clinicAddress: 'Ranade Road, Dadar West',
        consultationHoursNote: 'Daily 6am–8pm',
        isDiagnosticCentre: true,
      ),
    ),
    _Entry(
      name: 'Seva Home Nursing',
      categories: <String>['home-nursing'],
      base: 'mh-mumbai-chembur',
      areas: <String>['mh-mumbai-chembur', 'mh-mumbai-kurla', 'mh-mumbai-mankhurd', 'mh-mumbai-ghatkopar', 'mh-mumbai-sion'],
      description:
          'Trained nursing attendants for home care, including injection, dressing and post-surgery assistance.',
      languages: <String>['Hindi', 'Marathi', 'Malayalam'],
      hours: _Hours.roundTheClock,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        specialty: 'Home nursing and attendant care',
        consultationHoursNote: '24-hour and 12-hour shifts',
      ),
    ),
    _Entry(
      name: 'Dr. Nikhil Menon',
      categories: <String>['veterinary'],
      base: 'mh-mumbai-andheri-west',
      areas: <String>['mh-mumbai-andheri-west', 'mh-mumbai-andheri-east', 'mh-mumbai-juhu', 'mh-mumbai-goregaon'],
      description:
          'Small animal practice with clinic consultations and home visits for pets.',
      languages: <String>['English', 'Hindi', 'Malayalam'],
      hours: _Hours.clinicEvening,
      homeVisits: true,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        qualification: 'BVSc and AH',
        specialty: 'Small animal practice',
        clinicName: 'Paws and Claws Veterinary Clinic',
        clinicAddress: 'Lokhandwala Complex, Andheri West',
        consultationHoursNote: 'Mon–Sat 4pm–9pm',
      ),
    ),

    // ========================================= Learning and digital
    _Entry(
      name: 'Bright Minds Tuition',
      categories: <String>['tutor'],
      base: 'mh-mumbai-andheri-west',
      areas: <String>['mh-mumbai-andheri-west', 'mh-mumbai-andheri-east', 'mh-mumbai-vile-parle', 'mh-mumbai-jogeshwari'],
      description:
          'Maths and science tuition for classes 8 to 10, at home or at our study centre. Small batches.',
      languages: <String>['English', 'Hindi', 'Marathi'],
      hours: _Hours.afternoon,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'tutor': 500},
    ),
    _Entry(
      name: 'Fatima English Classes',
      categories: <String>['tutor'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-mankhurd'],
      description:
          'Spoken English and school English tuition for children and adults. Weekend batches available.',
      languages: <String>['English', 'Hindi', 'Urdu'],
      hours: _Hours.afternoon,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Sunrise Coaching for Maths',
      categories: <String>['tutor'],
      base: 'mh-mumbai-dadar-west',
      areas: <String>['mh-mumbai-dadar-west', 'mh-mumbai-dadar-east', 'mh-mumbai-matunga', 'mh-mumbai-parel', 'mh-mumbai-wadala'],
      description:
          'Maths coaching for classes 6 to 12, including board exam preparation and doubt-clearing sessions.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.afternoon,
      homeVisits: false,
      whatsapp: true,
    ),
    _Entry(
      name: 'TechFix Computer Care',
      categories: <String>['computer-repair'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-ghatkopar', 'mh-mumbai-sion'],
      description:
          'Laptop and desktop repair, Windows installation, virus removal, data recovery and printer service.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'computer-repair': 350},
      photoCaptions: <String>['Workshop bench'],
    ),
    _Entry(
      name: 'ByteCare Laptop Services',
      categories: <String>['computer-repair', 'it-support'],
      base: 'mh-mumbai-andheri-east',
      areas: <String>['mh-mumbai-andheri-east', 'mh-mumbai-andheri-west', 'mh-mumbai-santacruz', 'mh-mumbai-vile-parle'],
      description:
          'Laptop screen and keyboard replacement, SSD upgrades and small-office IT support.',
      languages: <String>['English', 'Hindi', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Mobile Doctor Mumbai',
      categories: <String>['mobile-repair'],
      base: 'mh-mumbai-borivali-west',
      areas: <String>['mh-mumbai-borivali-west', 'mh-mumbai-kandivali', 'mh-mumbai-dahisar', 'mh-mumbai-malad'],
      description:
          'Phone screen replacement, battery change and software repair. Most models done the same day.',
      languages: <String>['Hindi', 'Gujarati', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
      prices: <String, int>{'mobile-repair': 250},
    ),
    _Entry(
      name: 'NetConnect WiFi and CCTV',
      categories: <String>['it-support'],
      base: 'mh-mumbai-ghatkopar',
      areas: <String>['mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-bhandup', 'mh-mumbai-powai'],
      description:
          'Broadband and mesh WiFi setup, CCTV installation and network cabling for homes and shops.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),

    // ========================================= Personal and daily
    _Entry(
      name: 'Sunita Home Help Services',
      categories: <String>['daily-worker', 'home-cleaning'],
      base: 'mh-mumbai-powai',
      areas: <String>['mh-mumbai-powai', 'mh-mumbai-ghatkopar', 'mh-mumbai-vikhroli', 'mh-mumbai-bhandup', 'mh-mumbai-kanjurmarg'],
      description:
          'Daily household help for cleaning, utensils and cooking assistance. Monthly and part-time placements.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'daily-worker': 8000},
    ),
    _Entry(
      name: 'Ramesh General Labour',
      categories: <String>['daily-worker', 'loading-unloading'],
      base: 'mh-mumbai-mankhurd',
      areas: <String>['mh-mumbai-mankhurd', 'mh-mumbai-chembur', 'mh-mumbai-kurla'],
      description:
          'General labour for shifting, cleaning, painting assistance and site work. Available daily.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.flexibleNoHours,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Green Thumb Gardening',
      categories: <String>['gardening'],
      base: 'mh-mumbai-borivali-east',
      areas: <String>['mh-mumbai-borivali-east', 'mh-mumbai-borivali-west', 'mh-mumbai-dahisar', 'mh-mumbai-kandivali'],
      description:
          'Garden maintenance, tree pruning, pot preparation and monthly mali visits for societies.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'SecureWatch Guards',
      categories: <String>['security-guard'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-sion', 'mh-mumbai-wadala', 'mh-mumbai-mankhurd'],
      description:
          'Trained security guards for housing societies, shops and events. Day and night shifts.',
      languages: <String>['Hindi', 'Marathi', 'Nepali'],
      hours: _Hours.roundTheClock,
      homeVisits: false,
      whatsapp: true,
    ),
    _Entry(
      name: 'Glamour Beauty at Home',
      categories: <String>['beauty-at-home'],
      base: 'mh-mumbai-andheri-west',
      areas: <String>['mh-mumbai-andheri-west', 'mh-mumbai-andheri-east', 'mh-mumbai-goregaon', 'mh-mumbai-juhu', 'mh-mumbai-vile-parle'],
      description:
          'Beauty services at your home: facial, waxing, threading, pedicure and party makeup. Bridal packages on request.',
      languages: <String>['Hindi', 'English', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'beauty-at-home': 599},
      photoCaptions: <String>['Bridal makeup sample'],
    ),
    _Entry(
      name: 'Zara Beauty Studio',
      categories: <String>['beauty-at-home'],
      base: 'mh-mumbai-bandra-west',
      areas: <String>['mh-mumbai-bandra-west', 'mh-mumbai-khar', 'mh-mumbai-santacruz', 'mh-mumbai-mahim'],
      description:
          'Salon-quality beauty treatments at home with sterilised tools and branded products.',
      languages: <String>['Hindi', 'English'],
      hours: _Hours.late,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Perfect Fit Tailoring',
      categories: <String>['tailoring'],
      base: 'mh-mumbai-dadar-east',
      areas: <String>['mh-mumbai-dadar-east', 'mh-mumbai-dadar-west', 'mh-mumbai-matunga', 'mh-mumbai-mahim'],
      description:
          'Blouse stitching, kurta and shirt tailoring, and all kinds of alteration work.',
      languages: <String>['Marathi', 'Hindi'],
      hours: _Hours.standard,
      homeVisits: false,
      whatsapp: true,
      prices: <String, int>{'tailoring': 400},
    ),
    _Entry(
      name: 'Annapurna Catering and Event Help',
      categories: <String>['event-help'],
      base: 'mh-mumbai-chembur',
      areas: <String>['mh-mumbai-chembur', 'mh-mumbai-kurla', 'mh-mumbai-ghatkopar', 'mh-mumbai-mankhurd'],
      description:
          'Cooks, waiters and serving staff for small functions and house parties. Decorations arranged on request.',
      languages: <String>['Marathi', 'Hindi', 'English'],
      hours: _Hours.flexibleNoHours,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Deepa Home Services',
      categories: <String>['other-services', 'daily-worker'],
      base: 'mh-mumbai-colaba',
      areas: <String>['mh-mumbai-colaba', 'mh-mumbai-fort', 'mh-mumbai-churchgate', 'mh-mumbai-marine-lines', 'mh-mumbai-malabar-hill'],
      description:
          'General household services: minor repairs, errands, packing and help with shifting within South Mumbai.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
    ),
    _Entry(
      name: 'Fort Handyman Services',
      categories: <String>['other-services', 'electrical', 'plumbing'],
      base: 'mh-mumbai-fort',
      areas: <String>['mh-mumbai-fort', 'mh-mumbai-colaba', 'mh-mumbai-churchgate', 'mh-mumbai-charni-road', 'mh-mumbai-byculla'],
      description:
          'One call for small jobs around the house: electrical points, taps, furniture and fittings.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'other-services': 350},
    ),
    _Entry(
      name: 'BrightWash Laundry and Ironing',
      categories: <String>['laundry-ironing', 'home-cleaning'],
      base: 'mh-mumbai-dadar-west',
      areas: <String>['mh-mumbai-dadar-west', 'mh-mumbai-dadar-east', 'mh-mumbai-matunga', 'mh-mumbai-prabhadevi', 'mh-mumbai-mahim'],
      description:
          'Daily wash and fold, steam ironing, and delicate dry cleaning with doorstep pickup and drop.',
      languages: <String>['Hindi', 'Marathi', 'English'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'laundry-ironing': 150},
    ),
    _Entry(
      name: 'Dr. Meera Kulkarni Clinic',
      categories: <String>['paediatrician', 'general-physician'],
      base: 'mh-mumbai-bandra-west',
      areas: <String>['mh-mumbai-bandra-west', 'mh-mumbai-bandra-east', 'mh-mumbai-khar', 'mh-mumbai-santacruz'],
      description:
          'Paediatrician providing child healthcare, routine vaccination, infant feeding and growth monitoring.',
      languages: <String>['English', 'Hindi', 'Marathi'],
      hours: _Hours.clinicEvening,
      homeVisits: false,
      whatsapp: true,
      healthcare: const HealthcareDetails(
        qualification: 'MBBS, MD (Paediatrics)',
        specialty: 'Paediatrician',
        clinicName: 'Little Stars Clinic',
        clinicAddress: '102 Sunrise Arcade, Hill Road, Bandra West',
        consultationHoursNote: 'Mon–Sat 4pm–8pm',
        acceptsWalkIns: true,
      ),
      prices: <String, int>{'paediatrician': 700},
    ),
    _Entry(
      name: 'Powai Network and WiFi Solutions',
      categories: <String>['network-technician', 'computer-repair', 'it-support'],
      base: 'mh-mumbai-powai',
      areas: <String>['mh-mumbai-powai', 'mh-mumbai-vikhroli', 'mh-mumbai-ghatkopar', 'mh-mumbai-bhandup'],
      description:
          'WiFi router installation, speed troubleshooting, optical fiber cabling, LAN setup and home CCTV.',
      languages: <String>['Hindi', 'English', 'Marathi'],
      hours: _Hours.standard,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'network-technician': 400},
    ),
    _Entry(
      name: 'Kurla Construction Labour Services',
      categories: <String>['construction-labourer', 'daily-worker', 'loading-unloading'],
      base: 'mh-mumbai-kurla',
      areas: <String>['mh-mumbai-kurla', 'mh-mumbai-chembur', 'mh-mumbai-ghatkopar', 'mh-mumbai-sion'],
      description:
          'Construction labourers for debris removal, cement and brick shifting, site cleanup and loading.',
      languages: <String>['Hindi', 'Marathi'],
      hours: _Hours.early,
      homeVisits: true,
      whatsapp: true,
      prices: <String, int>{'construction-labourer': 600},
    ),
  ];

  // ---------------------------------------------------------------------
  // Non-published listings.
  //
  // Kept in the seed so the "paused listings disappear from public results"
  // and "draft is never public" rules are demonstrable without touching code.
  // They are appended after the published entries.
  // ---------------------------------------------------------------------

  /// Provider id of the seeded paused listing.
  static const String pausedProviderName = 'Verma Plumbing (paused listing)';

  /// Provider id of the seeded draft listing.
  static const String draftProviderName = 'New Age Electricals (unpublished draft)';

  static List<ProviderProfile> buildNonPublished({
    required DateTime reference,
  }) {
    return <ProviderProfile>[
      ProviderProfile(
        id: 'provider-seed-paused-001',
        phoneE164: _phoneFor(_seedCount + 1),
        displayName: pausedProviderName,
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-andheri-west',
        status: ListingStatus.paused,
        createdAt: reference.subtract(const Duration(days: 120)),
        updatedAt: reference.subtract(const Duration(days: 3)),
        categoryIds: const <String>['plumbing'],
        serviceAreas: const <ProviderServiceArea>[
          ProviderServiceArea(
            cityId: 'mh-mumbai',
            localityId: 'mh-mumbai-andheri-west',
            isPrimary: true,
          ),
        ],
        description:
            'Seeded paused listing. It must never appear in customer results.',
        languages: const <String>['Hindi'],
        workingHours: WorkingHours.standardWeek(),
        phoneDisplayConsented: true,
        verification: const <VerificationKind, VerificationStatus>{
          VerificationKind.phone: VerificationStatus.approved,
        },
        isDemoProfile: true,
      ),
      ProviderProfile(
        id: 'provider-seed-draft-001',
        phoneE164: _phoneFor(_seedCount + 2),
        displayName: draftProviderName,
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-borivali-west',
        status: ListingStatus.draft,
        createdAt: reference.subtract(const Duration(days: 4)),
        updatedAt: reference.subtract(const Duration(days: 1)),
        categoryIds: const <String>['electrical'],
        serviceAreas: const <ProviderServiceArea>[
          ProviderServiceArea(
            cityId: 'mh-mumbai',
            localityId: 'mh-mumbai-borivali-west',
            isPrimary: true,
          ),
        ],
        phoneDisplayConsented: false,
        isDemoProfile: true,
      ),
    ];
  }

  /// Total seeded listings, including non-published ones.
  static int get totalSeeded => _entries.length + 2;

  /// Number of published seeded listings.
  static int get publishedSeeded => _entries.length;
}

/// Working-hour presets used by the seed entries.
enum _Hours {
  /// Mon–Sat 9am–8pm, Sunday closed.
  standard,

  /// Mon–Sat 7am–5pm, Sunday closed (trades that start early).
  early,

  /// Mon–Sat 10am–10pm, Sunday closed.
  late,

  /// Mon–Sat 2pm–9pm, Sunday closed (tuition after school).
  afternoon,

  /// Open 24 hours, every day.
  roundTheClock,

  /// Mon–Sat 10am–1pm and 6pm–9pm (clinic split hours).
  clinicEvening,

  /// Mon–Sat 8am–1pm, Sunday closed.
  clinicMorning,

  /// Deliberately no hours recorded, so "Open now" must be suppressed rather
  /// than guessed.
  flexibleNoHours,
}

/// Compact seed definition. Expanded into a full [ProviderProfile] by
/// [_Entry.toProfile].
class _Entry {
  const _Entry({
    required this.name,
    required this.categories,
    required this.base,
    required this.areas,
    required this.description,
    required this.languages,
    required this.hours,
    this.homeVisits = true,
    this.whatsapp = false,
    this.healthcare,
    this.prices = const <String, int>{},
    this.photoCaptions = const <String>[],
  });

  final String name;
  final List<String> categories;
  final String base;
  final List<String> areas;
  final String description;
  final List<String> languages;
  final _Hours hours;
  final bool homeVisits;
  final bool whatsapp;
  final HealthcareDetails? healthcare;
  final Map<String, int> prices;
  final List<String> photoCaptions;

  ProviderProfile toProfile({
    required int index,
    required DateTime reference,
    required String phone,
  }) {
    return ProviderProfile(
      id: ProviderSeed.seedId('provider', index),
      phoneE164: phone,
      displayName: name,
      baseCityId: 'mh-mumbai',
      baseLocalityId: base,
      status: ListingStatus.published,
      createdAt: reference.subtract(Duration(days: 30 + index)),
      updatedAt: reference.subtract(Duration(days: index % 17)),
      categoryIds: categories,
      serviceAreas: <ProviderServiceArea>[
        for (int i = 0; i < areas.length; i++)
          ProviderServiceArea(
            cityId: 'mh-mumbai',
            localityId: areas[i],
            isPrimary: areas[i] == base,
          ),
      ],
      description: description,
      languages: languages,
      workingHours: _workingHours(),
      photos: <ProviderPhoto>[
        for (int i = 0; i < photoCaptions.length; i++)
          ProviderPhoto(
            id: '${ProviderSeed.seedId('photo', index)}-$i',
            caption: photoCaptions[i],
            isPlaceholder: true,
          ),
      ],
      startingPrices: <StartingPrice>[
        for (final MapEntry<String, int> entry in prices.entries)
          StartingPrice(categoryId: entry.key, amount: entry.value),
      ],
      healthcareDetails: healthcare,
      homeVisits: homeVisits,
      availability: AvailabilityStatus.available,
      whatsappEnabled: whatsapp,
      phoneDisplayConsented: true,
      verification: const <VerificationKind, VerificationStatus>{
        VerificationKind.phone: VerificationStatus.approved,
      },
      isDemoProfile: true,
      pinCodes: const <String>[],
      mapLocation: homeVisits ? null : _demoPin(index),
    );
  }

  /// Fictional listings that work from premises (clinics, workshops) opt in
  /// to the map, pinned a few hundred metres from their locality centre. The
  /// offset is derived from the index so pins are stable between launches.
  GeoPoint _demoPin(int index) {
    final GeoPoint centre = centreFor(localityId: base, cityId: 'mh-mumbai');
    final double dLat = ((index * 37) % 9 - 4) * 0.0009;
    final double dLng = ((index * 53) % 9 - 4) * 0.0009;
    return GeoPoint(centre.latitude + dLat, centre.longitude + dLng);
  }

  WorkingHours _workingHours() {
    switch (hours) {
      case _Hours.standard:
        return WorkingHours.standardWeek();
      case _Hours.early:
        return WorkingHours.standardWeek(
          openMinutes: 7 * 60,
          closeMinutes: 17 * 60,
        );
      case _Hours.late:
        return WorkingHours.standardWeek(
          openMinutes: 10 * 60,
          closeMinutes: 22 * 60,
        );
      case _Hours.afternoon:
        return WorkingHours.standardWeek(
          openMinutes: 14 * 60,
          closeMinutes: 21 * 60,
        );
      case _Hours.roundTheClock:
        return WorkingHours.uniform(openMinutes: 0, closeMinutes: 1439);
      case _Hours.clinicEvening:
        return WorkingHours(
          List<DayHours>.generate(7, (int i) {
            final int weekday = i + 1;
            if (weekday == DateTime.sunday) return DayHours.closed(weekday);
            return DayHours(
              weekday: weekday,
              openMinutes: 10 * 60,
              closeMinutes: 21 * 60,
            );
          }),
        );
      case _Hours.clinicMorning:
        return WorkingHours.standardWeek(
          openMinutes: 8 * 60,
          closeMinutes: 13 * 60,
        );
      case _Hours.flexibleNoHours:
        return WorkingHours.none();
    }
  }
}
