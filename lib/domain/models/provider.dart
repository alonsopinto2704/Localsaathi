import 'enums.dart';
export 'enums.dart';

/// Opening hours for one weekday.
///
/// A `null` [openMinutes] means the provider is closed that day. The app never
/// guesses hours: if a provider has not set them, "Open now" is hidden rather
/// than assumed.
class DayHours {
  const DayHours({
    required this.weekday,
    this.openMinutes,
    this.closeMinutes,
  });

  const DayHours.closed(this.weekday)
      : openMinutes = null,
        closeMinutes = null;

  /// `DateTime.monday` … `DateTime.sunday` (1–7).
  final int weekday;

  /// Minutes since local midnight.
  final int? openMinutes;
  final int? closeMinutes;

  bool get isClosed => openMinutes == null || closeMinutes == null;

  /// True when the window spans midnight (e.g. 22:00–02:00).
  bool get crossesMidnight =>
      !isClosed && closeMinutes! <= openMinutes!;

  /// Whether [minutes] falls in the part of this window on its own day.
  /// An overnight window's after-midnight tail belongs to the next day (see
  /// [WorkingHours.isOpenAt]); a close of 23:59 means "until midnight".
  /// Same rule as `search_providers` open-now in the database.
  bool containsMinutes(int minutes) {
    if (isClosed) return false;
    final int open = openMinutes!;
    final int close = closeMinutes!;
    if (crossesMidnight) return minutes >= open;
    return minutes >= open && (minutes < close || close == 1439);
  }

  DayHours copyWith({
    int? openMinutes,
    int? closeMinutes,
    bool clear = false,
  }) {
    if (clear) {
      return DayHours(weekday: weekday);
    }
    return DayHours(
      weekday: weekday,
      openMinutes: openMinutes ?? this.openMinutes,
      closeMinutes: closeMinutes ?? this.closeMinutes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'weekday': weekday,
        'open': openMinutes,
        'close': closeMinutes,
      };

  static DayHours fromJson(Map<String, dynamic> json) => DayHours(
        weekday: (json['weekday'] as num).toInt(),
        openMinutes: (json['open'] as num?)?.toInt(),
        closeMinutes: (json['close'] as num?)?.toInt(),
      );
}

/// The full weekly schedule. Seven entries, always present, so "Open now" can
/// be computed deterministically.
class WorkingHours {
  const WorkingHours(this.days);

  final List<DayHours> days;

  /// All days closed. Used as the "not provided" sentinel: when a provider has
  /// no hours at all the UI suppresses Open now entirely.
  static WorkingHours none() => WorkingHours(
        List<DayHours>.generate(7, (int i) => DayHours.closed(i + 1)),
      );

  static WorkingHours uniform({
    required int openMinutes,
    required int closeMinutes,
  }) =>
      WorkingHours(
        List<DayHours>.generate(
          7,
          (int i) => DayHours(
            weekday: i + 1,
            openMinutes: openMinutes,
            closeMinutes: closeMinutes,
          ),
        ),
      );

  /// Mon–Sat open, Sunday closed. The most common Indian small-business week.
  static WorkingHours standardWeek({
    int openMinutes = 9 * 60,
    int closeMinutes = 20 * 60,
  }) =>
      WorkingHours(
        List<DayHours>.generate(7, (int i) {
          final int weekday = i + 1;
          if (weekday == DateTime.sunday) return DayHours.closed(weekday);
          return DayHours(
            weekday: weekday,
            openMinutes: openMinutes,
            closeMinutes: closeMinutes,
          );
        }),
      );

  /// Current wall-clock time in India (IST, UTC+5:30, no DST), whatever the
  /// device's timezone -- listings' hours are local Indian hours.
  static DateTime indiaNow() => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  /// Whether the provider supplied any hours at all.
  bool get hasAnyHours => days.any((DayHours d) => !d.isClosed);

  DayHours forWeekday(int weekday) => days.firstWhere(
        (DayHours d) => d.weekday == weekday,
        orElse: () => DayHours.closed(weekday),
      );

  /// Whether a provider is open at [moment].
  ///
  /// Returns `null` when we genuinely cannot tell (no hours recorded), which
  /// the UI renders as "hours not provided" instead of "closed".
  /// [moment]'s wall-clock fields are read as India time; pass [indiaNow].
  bool? isOpenAt(DateTime moment) {
    if (!hasAnyHours) return null;
    final DayHours today = forWeekday(moment.weekday);
    final int minutes = moment.hour * 60 + moment.minute;
    if (today.containsMinutes(minutes)) return true;
    // The previous day's overnight window spills into this morning.
    final int previousWeekday = moment.weekday == 1 ? 7 : moment.weekday - 1;
    final DayHours previous = forWeekday(previousWeekday);
    if (previous.crossesMidnight && minutes < previous.closeMinutes!) {
      return true;
    }
    return false;
  }

  bool get isOpenAroundTheClock =>
      hasAnyHours && days.every((DayHours d) => !d.isClosed && d.openMinutes == 0 && d.closeMinutes! >= 1439);

  WorkingHours copyWithDay(DayHours day) => WorkingHours(
        days.map((DayHours d) => d.weekday == day.weekday ? day : d).toList(),
      );

  WorkingHours copyWithAllDays(DayHours template) => WorkingHours(
        List<DayHours>.generate(
          7,
          (int i) => template.isClosed
              ? DayHours.closed(i + 1)
              : DayHours(
                  weekday: i + 1,
                  openMinutes: template.openMinutes,
                  closeMinutes: template.closeMinutes,
                ),
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'days': days.map((DayHours d) => d.toJson()).toList(),
      };

  static WorkingHours fromJson(Map<String, dynamic> json) {
    final Object? raw = json['days'];
    final List<DayHours> parsed = <DayHours>[];
    if (raw is List) {
      for (final Object? item in raw) {
        if (item is Map<String, dynamic>) parsed.add(DayHours.fromJson(item));
      }
    }
    final Map<int, DayHours> byWeekday = <int, DayHours>{
      for (final DayHours d in parsed) d.weekday: d,
    };
    return WorkingHours(
      List<DayHours>.generate(
        7,
        (int i) => byWeekday[i + 1] ?? DayHours.closed(i + 1),
      ),
    );
  }
}

/// A provider photo.
///
/// [isPlaceholder] marks entries created by the mocked picker in this build so
/// the UI can render a neutral tile instead of trying to load a missing file.
class ProviderPhoto {
  const ProviderPhoto({
    required this.id,
    required this.caption,
    this.assetPath,
    this.remoteUrl,
    this.imageBase64,
    this.isPlaceholder = false,
    this.uploadedAt,
  });

  final String id;
  final String caption;

  /// Bundled sample image, if any.
  final String? assetPath;

  /// Production: signed URL from object storage.
  final String? remoteUrl;

  /// A photo picked on this device, compressed JPEG bytes. The mock build keeps
  /// it with the profile; production uploads it and stores [remoteUrl] instead.
  // ponytail: images live inside the persisted profile JSON (a few hundred KB
  // each, capped at 6); move to file/object storage before real traffic.
  final String? imageBase64;

  final bool isPlaceholder;
  final DateTime? uploadedAt;

  bool get hasImage =>
      assetPath != null || remoteUrl != null || imageBase64 != null;

  ProviderPhoto copyWith({
    String? caption,
    String? assetPath,
    String? remoteUrl,
    bool? isPlaceholder,
  }) =>
      ProviderPhoto(
        id: id,
        caption: caption ?? this.caption,
        assetPath: assetPath ?? this.assetPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        imageBase64: imageBase64,
        isPlaceholder: isPlaceholder ?? this.isPlaceholder,
        uploadedAt: uploadedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'caption': caption,
        'isPlaceholder': isPlaceholder,
        if (imageBase64 != null) 'image': imageBase64,
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
        if (uploadedAt != null) 'uploadedAt': uploadedAt!.toIso8601String(),
      };

  static ProviderPhoto fromJson(Map<String, dynamic> json) => ProviderPhoto(
        id: json['id'] as String,
        caption: (json['caption'] as String?) ?? '',
        isPlaceholder: (json['isPlaceholder'] as bool?) ?? false,
        imageBase64: json['image'] as String?,
        remoteUrl: json['remoteUrl'] as String?,
        uploadedAt: DateTime.tryParse((json['uploadedAt'] as String?) ?? ''),
      );
}

/// A point on the map, in WGS84 degrees.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
      };

  /// Null for anything malformed or out of range, so a bad record can never
  /// put a pin in the ocean.
  static GeoPoint? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? lat = json['lat'];
    final Object? lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A locality a provider is willing to serve, plus the optional PIN codes that
/// narrow it.
///
/// Service areas are stored separately from the provider's base locality on
/// purpose: a Bandra-based electrician can serve Andheri and Kurla, and
/// customers in Andheri must still find them.
class ProviderServiceArea {
  const ProviderServiceArea({
    required this.cityId,
    required this.localityId,
    this.pinCodes = const <String>[],
    this.isPrimary = false,
  });

  final String cityId;
  final String localityId;

  /// Optional PIN-code granularity inside the locality.
  final List<String> pinCodes;

  /// Marks the base locality.
  final bool isPrimary;

  ProviderServiceArea copyWith({
    List<String>? pinCodes,
    bool? isPrimary,
  }) =>
      ProviderServiceArea(
        cityId: cityId,
        localityId: localityId,
        pinCodes: pinCodes ?? this.pinCodes,
        isPrimary: isPrimary ?? this.isPrimary,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cityId': cityId,
        'localityId': localityId,
        'pinCodes': pinCodes,
        'isPrimary': isPrimary,
      };

  static ProviderServiceArea fromJson(Map<String, dynamic> json) =>
      ProviderServiceArea(
        cityId: json['cityId'] as String,
        localityId: json['localityId'] as String,
        pinCodes: (json['pinCodes'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        isPrimary: (json['isPrimary'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is ProviderServiceArea &&
      other.cityId == cityId &&
      other.localityId == localityId;

  @override
  int get hashCode => Object.hash(cityId, localityId);
}

/// Indicative starting price for one category.
///
/// Explicitly indicative: the app never quotes a firm price and never collects
/// payment.
class StartingPrice {
  const StartingPrice({
    required this.categoryId,
    required this.amount,
    this.note,
  });

  final String categoryId;

  /// Whole rupees.
  final int amount;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'categoryId': categoryId,
        'amount': amount,
        'note': note,
      };

  static StartingPrice fromJson(Map<String, dynamic> json) => StartingPrice(
        categoryId: json['categoryId'] as String,
        amount: (json['amount'] as num).toInt(),
        note: json['note'] as String?,
      );
}

/// Healthcare-specific professional details.
///
/// These are *claimed* by the provider. In this build they are displayed as
/// provided and never as verified. `CredentialRecord` is what would eventually
/// hold a reviewed, verified state.
class HealthcareDetails {
  const HealthcareDetails({
    this.qualification,
    this.specialty,
    this.clinicName,
    this.clinicAddress,
    this.consultationHoursNote,
    this.registrationNumber,
    this.registrationCouncil,
    this.isDiagnosticCentre = false,
    this.acceptsWalkIns = true,
  });

  final String? qualification;
  final String? specialty;
  final String? clinicName;

  /// A clinic's public address is fine to show; this is *not* used for
  /// home-based practitioners, whose residential address is never collected.
  final String? clinicAddress;
  final String? consultationHoursNote;
  final String? registrationNumber;
  final String? registrationCouncil;
  final bool isDiagnosticCentre;
  final bool acceptsWalkIns;

  bool get hasAnyDetail =>
      _has(qualification) ||
      _has(specialty) ||
      _has(clinicName) ||
      _has(clinicAddress) ||
      _has(registrationNumber);

  bool get hasClaimedRegistration =>
      _has(registrationNumber) || _has(registrationCouncil);

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  HealthcareDetails copyWith({
    String? qualification,
    String? specialty,
    String? clinicName,
    String? clinicAddress,
    String? consultationHoursNote,
    String? registrationNumber,
    String? registrationCouncil,
    bool? isDiagnosticCentre,
    bool? acceptsWalkIns,
  }) =>
      HealthcareDetails(
        qualification: qualification ?? this.qualification,
        specialty: specialty ?? this.specialty,
        clinicName: clinicName ?? this.clinicName,
        clinicAddress: clinicAddress ?? this.clinicAddress,
        consultationHoursNote: consultationHoursNote ?? this.consultationHoursNote,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        registrationCouncil: registrationCouncil ?? this.registrationCouncil,
        isDiagnosticCentre: isDiagnosticCentre ?? this.isDiagnosticCentre,
        acceptsWalkIns: acceptsWalkIns ?? this.acceptsWalkIns,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'qualification': qualification,
        'specialty': specialty,
        'clinicName': clinicName,
        'clinicAddress': clinicAddress,
        'consultationHoursNote': consultationHoursNote,
        'registrationNumber': registrationNumber,
        'registrationCouncil': registrationCouncil,
        'isDiagnosticCentre': isDiagnosticCentre,
        'acceptsWalkIns': acceptsWalkIns,
      };

  static HealthcareDetails fromJson(Map<String, dynamic> json) =>
      HealthcareDetails(
        qualification: json['qualification'] as String?,
        specialty: json['specialty'] as String?,
        clinicName: json['clinicName'] as String?,
        clinicAddress: json['clinicAddress'] as String?,
        consultationHoursNote: json['consultationHoursNote'] as String?,
        registrationNumber: json['registrationNumber'] as String?,
        registrationCouncil: json['registrationCouncil'] as String?,
        isDiagnosticCentre: (json['isDiagnosticCentre'] as bool?) ?? false,
        acceptsWalkIns: (json['acceptsWalkIns'] as bool?) ?? true,
      );
}

/// The verified-phone identity.
///
/// Kept as its own concept so the uniqueness rule has one obvious home:
/// one [PhoneIdentity] owns at most one provider profile, enforced by the
/// repository on the normalised [+e164] value.
class PhoneIdentity {
  const PhoneIdentity({
    required this.e164,
    required this.createdAt,
    this.lastVerifiedAt,
    this.verified = false,
  });

  /// Canonical E.164 form. This is the uniqueness key.
  final String e164;

  final DateTime createdAt;
  final DateTime? lastVerifiedAt;
  final bool verified;

  PhoneIdentity copyWith({DateTime? lastVerifiedAt, bool? verified}) =>
      PhoneIdentity(
        e164: e164,
        createdAt: createdAt,
        lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
        verified: verified ?? this.verified,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'e164': e164,
        'createdAt': createdAt.toIso8601String(),
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'verified': verified,
      };

  static PhoneIdentity fromJson(Map<String, dynamic> json) => PhoneIdentity(
        e164: json['e164'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastVerifiedAt:
            DateTime.tryParse(json['lastVerifiedAt'] as String? ?? ''),
        verified: (json['verified'] as bool?) ?? false,
      );
}

/// A complete provider listing.
///
/// One profile per verified phone number. A provider offering several services
/// adds categories to this single profile rather than creating another one.
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.phoneE164,
    required this.displayName,
    required this.baseCityId,
    required this.baseLocalityId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.categoryIds = const <String>[],
    this.serviceAreas = const <ProviderServiceArea>[],
    this.description,
    this.languages = const <String>[],
    this.workingHours,
    this.photos = const <ProviderPhoto>[],
    this.startingPrices = const <StartingPrice>[],
    this.healthcareDetails,
    this.homeVisits = true,
    this.availability = AvailabilityStatus.available,
    this.whatsappEnabled = false,
    this.phoneDisplayConsented = false,
    this.verification = const <VerificationKind, VerificationStatus>{},
    this.isDemoProfile = false,
    this.pinCodes = const <String>[],
    this.mapLocation,
    this.revision,
    this.isModerationSuspended = false,
    this.isPubliclyListed,
  });

  final String id;

  /// Unique per profile, enforced on this exact normalised value.
  final String phoneE164;

  final String displayName;

  /// Where the provider is based. Shown as a locality only, never an address.
  final String baseCityId;
  final String baseLocalityId;

  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Multiple categories on one profile: this is how a multi-service provider
  /// stays a single listing.
  final List<String> categoryIds;

  /// Localities (in [baseCityId] for this build) the provider will travel to.
  final List<ProviderServiceArea> serviceAreas;

  final String? description;
  final List<String> languages;
  final WorkingHours? workingHours;
  final List<ProviderPhoto> photos;
  final List<StartingPrice> startingPrices;
  final HealthcareDetails? healthcareDetails;

  final bool homeVisits;

  /// A self-reported availability hint, not a live signal.
  final AvailabilityStatus availability;

  final bool whatsappEnabled;

  /// Explicit consent to publish the number. Without this the listing cannot be
  /// published and the UI never renders a Call button.
  final bool phoneDisplayConsented;

  final Map<VerificationKind, VerificationStatus> verification;

  /// True for seeded fictional providers. Their contact actions explain that
  /// the profile is fictional instead of dialling.
  final bool isDemoProfile;

  /// Optional PIN codes covered by this listing.
  final List<String> pinCodes;

  /// Business premises the provider chose to show on the map (a shop, clinic
  /// or workshop). Null means "not shown": the default, and what withdrawing
  /// consent restores. The coordinates are deleted, not just hidden.
  final GeoPoint? mapLocation;

  /// Server row revision, present only in the owner shape. Sent back as
  /// `expectedRevision` so an edit made from stale state is refused instead of
  /// overwriting a newer change or a moderation decision (phase 069).
  final int? revision;

  /// Owner shape only: moderation (not the owner) has suspended the listing.
  /// The owner cannot lift this; "resume" must not be offered (phase 070).
  final bool isModerationSuspended;

  /// Owner shape only: the server's own verdict on whether customers can see
  /// this listing right now (null = not known, e.g. public/mock profiles).
  final bool? isPubliclyListed;

  // ------------------------------------------------------------- derived
  bool get isPubliclyVisible => status.isPubliclyVisible;

  bool get isPhoneVerified =>
      verification[VerificationKind.phone] == VerificationStatus.approved;

  /// Careful: this is a separate review. OTP never sets this.
  bool get isCredentialsVerified =>
      verification[VerificationKind.credentials] ==
      VerificationStatus.approved;

  bool get isHealthcare => healthcareDetails != null;

  /// Whether a Call button may be shown at all.
  bool get canBeCalled => isPubliclyVisible && phoneDisplayConsented;

  bool get canWhatsApp => canBeCalled && whatsappEnabled;

  /// `Phone verified` label state, kept separate from credentials on purpose.
  bool get showsVerifiedPhoneLabel => isPhoneVerified;

  bool get hasStartingPrice => startingPrices.isNotEmpty;

  int get photoCount => photos.length;

  /// Service area locality ids, for filter matching.
  Set<String> get servedLocalityIds =>
      serviceAreas.map((ProviderServiceArea a) => a.localityId).toSet();

  bool servesLocality(String localityId) =>
      localityId == baseLocalityId || servedLocalityIds.contains(localityId);

  String initials() {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  ProviderProfile copyWith({
    String? displayName,
    String? baseCityId,
    String? baseLocalityId,
    ListingStatus? status,
    DateTime? updatedAt,
    List<String>? categoryIds,
    List<ProviderServiceArea>? serviceAreas,
    String? description,
    List<String>? languages,
    WorkingHours? workingHours,
    List<ProviderPhoto>? photos,
    List<StartingPrice>? startingPrices,
    HealthcareDetails? healthcareDetails,
    bool? homeVisits,
    AvailabilityStatus? availability,
    bool? whatsappEnabled,
    bool? phoneDisplayConsented,
    Map<VerificationKind, VerificationStatus>? verification,
    List<String>? pinCodes,
    GeoPoint? mapLocation,
    bool clearMapLocation = false,
  }) {
    return ProviderProfile(
      id: id,
      phoneE164: phoneE164,
      displayName: displayName ?? this.displayName,
      baseCityId: baseCityId ?? this.baseCityId,
      baseLocalityId: baseLocalityId ?? this.baseLocalityId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryIds: categoryIds ?? this.categoryIds,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      description: description ?? this.description,
      languages: languages ?? this.languages,
      workingHours: workingHours ?? this.workingHours,
      photos: photos ?? this.photos,
      startingPrices: startingPrices ?? this.startingPrices,
      healthcareDetails: healthcareDetails ?? this.healthcareDetails,
      homeVisits: homeVisits ?? this.homeVisits,
      availability: availability ?? this.availability,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      phoneDisplayConsented:
          phoneDisplayConsented ?? this.phoneDisplayConsented,
      verification: verification ?? this.verification,
      isDemoProfile: isDemoProfile,
      pinCodes: pinCodes ?? this.pinCodes,
      mapLocation:
          clearMapLocation ? null : (mapLocation ?? this.mapLocation),
      revision: revision,
      isModerationSuspended: isModerationSuspended,
      isPubliclyListed: isPubliclyListed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'phoneE164': phoneE164,
        'displayName': displayName,
        'baseCityId': baseCityId,
        'baseLocalityId': baseLocalityId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'categoryIds': categoryIds,
        'serviceAreas':
            serviceAreas.map((ProviderServiceArea a) => a.toJson()).toList(),
        'description': description,
        'languages': languages,
        'workingHours': workingHours?.toJson(),
        'photos': photos.map((ProviderPhoto p) => p.toJson()).toList(),
        'startingPrices':
            startingPrices.map((StartingPrice p) => p.toJson()).toList(),
        'healthcareDetails': healthcareDetails?.toJson(),
        'homeVisits': homeVisits,
        'availability': availability.name,
        'whatsappEnabled': whatsappEnabled,
        'phoneDisplayConsented': phoneDisplayConsented,
        'verification': verification.map(
          (VerificationKind k, VerificationStatus v) =>
              MapEntry<String, String>(k.name, v.name),
        ),
        'isDemoProfile': isDemoProfile,
        'pinCodes': pinCodes,
        if (mapLocation != null) 'mapLocation': mapLocation!.toJson(),
      };

  static ProviderProfile fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      id: json['id'] as String,
      phoneE164: json['phoneE164'] as String,
      displayName: (json['displayName'] as String?) ?? '',
      baseCityId: (json['baseCityId'] as String?) ?? '',
      baseLocalityId: (json['baseLocalityId'] as String?) ?? '',
      status: _enumByName(
            ListingStatus.values,
            json['status'],
          ) ??
          ListingStatus.draft,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      categoryIds: (json['categoryIds'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      serviceAreas: (json['serviceAreas'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ProviderServiceArea.fromJson)
          .toList(),
      description: json['description'] as String?,
      languages: (json['languages'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      workingHours: json['workingHours'] is Map<String, dynamic>
          ? WorkingHours.fromJson(json['workingHours'] as Map<String, dynamic>)
          : null,
      photos: (json['photos'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ProviderPhoto.fromJson)
          .toList(),
      startingPrices: (json['startingPrices'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StartingPrice.fromJson)
          .toList(),
      healthcareDetails: json['healthcareDetails'] is Map<String, dynamic>
          ? HealthcareDetails.fromJson(
              json['healthcareDetails'] as Map<String, dynamic>)
          : null,
      homeVisits: (json['homeVisits'] as bool?) ?? true,
      availability: _enumByName(
            AvailabilityStatus.values,
            json['availability'],
          ) ??
          AvailabilityStatus.available,
      whatsappEnabled: (json['whatsappEnabled'] as bool?) ?? false,
      phoneDisplayConsented: (json['phoneDisplayConsented'] as bool?) ?? false,
      verification: _verificationFromJson(json['verification']),
      isDemoProfile: (json['isDemoProfile'] as bool?) ?? false,
      pinCodes: (json['pinCodes'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      mapLocation: GeoPoint.fromJson(json['mapLocation']),
      revision: (json['revision'] as num?)?.toInt(),
      isModerationSuspended: json['moderationStatus'] == 'suspended',
      isPubliclyListed: json['isPubliclyListed'] as bool?,
    );
  }

  static Map<VerificationKind, VerificationStatus> _verificationFromJson(
    Object? raw,
  ) {
    final Map<VerificationKind, VerificationStatus> result =
        <VerificationKind, VerificationStatus>{};
    if (raw is Map) {
      raw.forEach((Object? key, Object? value) {
        final VerificationKind? kind =
            _enumByName(VerificationKind.values, key);
        final VerificationStatus? status =
            _enumByName(VerificationStatus.values, value);
        if (kind != null && status != null) result[kind] = status;
      });
    }
    return result;
  }

  /// Small local enum parser so models do not depend on a serialization
  /// package. Returns null for anything unrecognised.
  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    // Accepts camelCase (local JSON) and snake_case (Postgres wire tokens).
    final String wanted = name.replaceAll('_', '').toLowerCase();
    for (final T value in values) {
      if (value.name.toLowerCase() == wanted) return value;
    }
    return null;
  }
}

/// A draft provider profile plus onboarding progress.
///
/// Persisted locally so a provider can leave the wizard and resume. Drafts are
/// anonymous: they hold a phone number but are not a published listing.
class ProviderDraft {
  const ProviderDraft({
    required this.phoneE164,
    required this.updatedAt,
    this.displayName,
    this.categoryIds = const <String>[],
    this.cityId,
    this.baseLocalityId,
    this.serviceAreaIds = const <String>[],
    this.description,
    this.languages = const <String>[],
    this.workingHours,
    this.homeVisits = true,
    this.phoneDisplayConsented = false,
    this.whatsappEnabled = false,
    this.photoCaptions = const <String>[],
    this.startingPrices = const <StartingPrice>[],
    this.healthcareDetails,
    this.lastStepIndex = 0,
  });

  final String phoneE164;
  final DateTime updatedAt;
  final String? displayName;
  final List<String> categoryIds;
  final String? cityId;
  final String? baseLocalityId;
  final List<String> serviceAreaIds;
  final String? description;
  final List<String> languages;
  final WorkingHours? workingHours;
  final bool homeVisits;
  final bool phoneDisplayConsented;
  final bool whatsappEnabled;
  final List<String> photoCaptions;
  final List<StartingPrice> startingPrices;
  final HealthcareDetails? healthcareDetails;

  /// Resume point for the wizard.
  final int lastStepIndex;

  bool get isResumable =>
      (displayName?.trim().isNotEmpty ?? false) ||
      categoryIds.isNotEmpty ||
      serviceAreaIds.isNotEmpty;

  ProviderDraft copyWith({
    String? phoneE164,
    DateTime? updatedAt,
    String? displayName,
    List<String>? categoryIds,
    String? cityId,
    String? baseLocalityId,
    List<String>? serviceAreaIds,
    String? description,
    List<String>? languages,
    WorkingHours? workingHours,
    bool? homeVisits,
    bool? phoneDisplayConsented,
    bool? whatsappEnabled,
    List<String>? photoCaptions,
    List<StartingPrice>? startingPrices,
    HealthcareDetails? healthcareDetails,
    int? lastStepIndex,
  }) =>
      ProviderDraft(
        phoneE164: phoneE164 ?? this.phoneE164,
        updatedAt: updatedAt ?? this.updatedAt,
        displayName: displayName ?? this.displayName,
        categoryIds: categoryIds ?? this.categoryIds,
        cityId: cityId ?? this.cityId,
        baseLocalityId: baseLocalityId ?? this.baseLocalityId,
        serviceAreaIds: serviceAreaIds ?? this.serviceAreaIds,
        description: description ?? this.description,
        languages: languages ?? this.languages,
        workingHours: workingHours ?? this.workingHours,
        homeVisits: homeVisits ?? this.homeVisits,
        phoneDisplayConsented:
            phoneDisplayConsented ?? this.phoneDisplayConsented,
        whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
        photoCaptions: photoCaptions ?? this.photoCaptions,
        startingPrices: startingPrices ?? this.startingPrices,
        healthcareDetails: healthcareDetails ?? this.healthcareDetails,
        lastStepIndex: lastStepIndex ?? this.lastStepIndex,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'phoneE164': phoneE164,
        'updatedAt': updatedAt.toIso8601String(),
        'displayName': displayName,
        'categoryIds': categoryIds,
        'cityId': cityId,
        'baseLocalityId': baseLocalityId,
        'serviceAreaIds': serviceAreaIds,
        'description': description,
        'languages': languages,
        'workingHours': workingHours?.toJson(),
        'homeVisits': homeVisits,
        'phoneDisplayConsented': phoneDisplayConsented,
        'whatsappEnabled': whatsappEnabled,
        'photoCaptions': photoCaptions,
        'startingPrices':
            startingPrices.map((StartingPrice p) => p.toJson()).toList(),
        'healthcareDetails': healthcareDetails?.toJson(),
        'lastStepIndex': lastStepIndex,
      };

  static ProviderDraft fromJson(Map<String, dynamic> json) => ProviderDraft(
        phoneE164: (json['phoneE164'] as String?) ?? '',
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
                DateTime.now(),
        displayName: json['displayName'] as String?,
        categoryIds: (json['categoryIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        cityId: json['cityId'] as String?,
        baseLocalityId: json['baseLocalityId'] as String?,
        serviceAreaIds: (json['serviceAreaIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        description: json['description'] as String?,
        languages: (json['languages'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        workingHours: json['workingHours'] is Map<String, dynamic>
            ? WorkingHours.fromJson(json['workingHours'] as Map<String, dynamic>)
            : null,
        homeVisits: (json['homeVisits'] as bool?) ?? true,
        phoneDisplayConsented: (json['phoneDisplayConsented'] as bool?) ?? false,
        whatsappEnabled: (json['whatsappEnabled'] as bool?) ?? false,
        photoCaptions: (json['photoCaptions'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        startingPrices: (json['startingPrices'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(StartingPrice.fromJson)
            .toList(),
        healthcareDetails: json['healthcareDetails'] is Map<String, dynamic>
            ? HealthcareDetails.fromJson(
                json['healthcareDetails'] as Map<String, dynamic>)
            : null,
        lastStepIndex: (json['lastStepIndex'] as num?)?.toInt() ?? 0,
      );
}
