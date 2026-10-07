import 'enums.dart';
export 'enums.dart';

/// An explicit, timestamped consent from a provider.
///
/// Consents are records, not booleans, because "when did they agree, and to
/// what wording" is what matters if a dispute or a Play Store policy question
/// ever arises. [wordingVersion] pins the text they actually saw.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.providerId,
    required this.kind,
    required this.granted,
    required this.recordedAt,
    required this.wordingVersion,
    this.phoneE164,
    this.withdrawnAt,
  });

  final String id;
  final String providerId;
  final ConsentKind kind;
  final bool granted;
  final DateTime recordedAt;

  /// Version tag of the consent copy shown to the provider.
  final String wordingVersion;

  /// Normalised phone at the time of consent, for the audit trail.
  final String? phoneE164;

  final DateTime? withdrawnAt;

  bool get isCurrentlyGranted => granted && withdrawnAt == null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'kind': kind.name,
        'granted': granted,
        'recordedAt': recordedAt.toIso8601String(),
        'wordingVersion': wordingVersion,
        'phoneE164': phoneE164,
        'withdrawnAt': withdrawnAt?.toIso8601String(),
      };

  static ConsentRecord fromJson(Map<String, dynamic> json) => ConsentRecord(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        kind: _enumOr(
          ConsentKind.values,
          json['kind'],
          ConsentKind.publicProfile,
        ),
        granted: (json['granted'] as bool?) ?? false,
        recordedAt:
            DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
                DateTime.now(),
        wordingVersion: (json['wordingVersion'] as String?) ?? 'v1',
        phoneE164: json['phoneE164'] as String?,
        withdrawnAt: DateTime.tryParse(json['withdrawnAt'] as String? ?? ''),
      );
}

/// A customer report about a listing.
///
/// Customers can report but never edit. Resolution requires moderation tools
/// that are outside this build; the record and its queue semantics are modelled
/// now so the backend has somewhere to put them.
class Report {
  const Report({
    required this.id,
    required this.providerId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details,
    this.reporterPhoneE164,
    this.reviewedAt,
    this.resolutionNote,
  });

  final String id;
  final String providerId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? details;

  /// Optional: guests can report. Never used to identify a customer publicly.
  final String? reporterPhoneE164;

  final DateTime? reviewedAt;
  final String? resolutionNote;

  Report copyWith({
    ReportStatus? status,
    DateTime? reviewedAt,
    String? resolutionNote,
  }) =>
      Report(
        id: id,
        providerId: providerId,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
        details: details,
        reporterPhoneE164: reporterPhoneE164,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        resolutionNote: resolutionNote ?? this.resolutionNote,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'reason': reason.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'details': details,
        'reporterPhoneE164': reporterPhoneE164,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'resolutionNote': resolutionNote,
      };

  static Report fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        reason: _enumOr(ReportReason.values, json['reason'], ReportReason.other),
        status:
            _enumOr(ReportStatus.values, json['status'], ReportStatus.submitted),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        details: json['details'] as String?,
        reporterPhoneE164: json['reporterPhoneE164'] as String?,
        reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
        resolutionNote: json['resolutionNote'] as String?,
      );
}

/// A claimed or reviewed professional credential.
///
/// Only ever populated from provider input or a real review process. The app
/// must never generate one of these: no invented degrees, licences or numbers.
class CredentialRecord {
  const CredentialRecord({
    required this.id,
    required this.providerId,
    required this.title,
    required this.status,
    this.issuingBody,
    this.registrationNumber,
    this.validUntil,
    this.reviewedAt,
    this.evidenceReference,
  });

  final String id;
  final String providerId;
  final String title;
  final VerificationStatus status;
  final String? issuingBody;
  final String? registrationNumber;
  final DateTime? validUntil;
  final DateTime? reviewedAt;

  /// Pointer to stored evidence in the future backend. Never a public URL.
  final String? evidenceReference;

  bool get isVerified => status == VerificationStatus.approved;

  /// The label the UI is allowed to show. Claims are not verification.
  String get displayStatusName => status.name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'title': title,
        'status': status.name,
        'issuingBody': issuingBody,
        'registrationNumber': registrationNumber,
        'validUntil': validUntil?.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'evidenceReference': evidenceReference,
      };

  static CredentialRecord fromJson(Map<String, dynamic> json) =>
      CredentialRecord(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        title: (json['title'] as String?) ?? '',
        status: _enumOr(
          VerificationStatus.values,
          json['status'],
          VerificationStatus.pending,
        ),
        issuingBody: json['issuingBody'] as String?,
        registrationNumber: json['registrationNumber'] as String?,
        validUntil: DateTime.tryParse(json['validUntil'] as String? ?? ''),
        reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
        evidenceReference: json['evidenceReference'] as String?,
      );
}

/// The audit trail of a verification attempt.
///
/// [VerificationKind.phone] entries are created by OTP success.
/// [VerificationKind.credentials] entries only by a human/back-office review.
/// Keeping one trail makes it auditable that OTP did not set credentials.
class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.providerId,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.method,
    this.reviewedBy,
    this.reviewedAt,
    this.note,
  });

  final String id;
  final String providerId;
  final VerificationKind kind;
  final VerificationStatus status;
  final DateTime createdAt;

  /// e.g. `otp_sms`, `otp_simulated`, `document_review`.
  final String? method;

  /// Moderator identifier. Only present for credential reviews.
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'kind': kind.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'method': method,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'note': note,
      };

  static VerificationRecord fromJson(Map<String, dynamic> json) =>
      VerificationRecord(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        kind: _enumOr(
          VerificationKind.values,
          json['kind'],
          VerificationKind.phone,
        ),
        status: _enumOr(
          VerificationStatus.values,
          json['status'],
          VerificationStatus.pending,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        method: json['method'] as String?,
        reviewedBy: json['reviewedBy'] as String?,
        reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
        note: json['note'] as String?,
      );
}

/// A sponsored placement.
///
/// Matching is explicit: a promotion targets categories and localities, and the
/// repository only returns it when the customer's selected category/locality
/// matches. It never changes a trust label.
class Promotion {
  const Promotion({
    required this.id,
    required this.providerId,
    required this.state,
    required this.placement,
    required this.startsAt,
    required this.endsAt,
    this.categoryIds = const <String>[],
    this.localityIds = const <String>[],
    this.cityId,
    this.priority = 0,
  });

  final String id;
  final String providerId;
  final PromotionState state;
  final PromotionPlacement placement;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Empty means "all categories".
  final List<String> categoryIds;

  /// Empty means "all localities in [cityId]".
  final List<String> localityIds;

  final String? cityId;

  /// Higher wins when several promotions match.
  final int priority;

  bool isActiveAt(DateTime now) =>
      state == PromotionState.active &&
      !now.isBefore(startsAt) &&
      now.isBefore(endsAt);

  bool matches({
    required String cityId,
    String? localityId,
    String? categoryId,
  }) {
    if (this.cityId != null && this.cityId != cityId) return false;
    if (localityIds.isNotEmpty &&
        (localityId == null || !localityIds.contains(localityId))) {
      return false;
    }
    if (categoryIds.isNotEmpty &&
        (categoryId == null || !categoryIds.contains(categoryId))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'state': state.name,
        'placement': placement.name,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'categoryIds': categoryIds,
        'localityIds': localityIds,
        'cityId': cityId,
        'priority': priority,
      };

  static Promotion fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        state: _enumOr(
          PromotionState.values,
          json['state'],
          PromotionState.draft,
        ),
        placement: _enumOr(
          PromotionPlacement.values,
          json['placement'],
          PromotionPlacement.searchTop,
        ),
        startsAt:
            DateTime.tryParse(json['startsAt'] as String? ?? '') ?? DateTime.now(),
        endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
        categoryIds: (json['categoryIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        localityIds: (json['localityIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(),
        cityId: json['cityId'] as String?,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

/// A monetization option shown on "Grow your business".
///
/// Presentation-only in this build: no price, no checkout, no entitlement.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.titleKey,
    required this.featureKeys,
    this.isRecommended = false,
    this.priceLabel,
  });

  final String id;
  final String titleKey;

  /// String keys resolved by the UI; plans stay data, copy stays localizable.
  final List<String> featureKeys;
  final bool isRecommended;

  /// Always null in this build: prices are not decided and Play billing is not
  /// wired. The UI shows "Pricing coming soon".
  final String? priceLabel;
}

/// One tracked in-app interaction.
///
/// Records taps and views only. There is deliberately no `callCompleted`,
/// `lead` or `job` type, because the app cannot observe those.
class EngagementEvent {
  const EngagementEvent({
    required this.id,
    required this.providerId,
    required this.type,
    required this.occurredAt,
    this.cityId,
    this.localityId,
    this.categoryId,
    this.totalCount,
  });

  final String id;
  final String providerId;
  final EngagementEventType type;
  final DateTime occurredAt;

  /// Context, so providers can see where interest came from without any
  /// customer-identifying data.
  final String? cityId;
  final String? localityId;
  final String? categoryId;

  /// For seeded sample events: how many taps this single record represents.
  /// Real events would always be 1 and aggregated server-side.
  final int? totalCount;

  int get count => totalCount ?? 1;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'type': type.name,
        'occurredAt': occurredAt.toIso8601String(),
        'cityId': cityId,
        'localityId': localityId,
        'categoryId': categoryId,
        'totalCount': totalCount,
      };

  static EngagementEvent fromJson(Map<String, dynamic> json) =>
      EngagementEvent(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        type: _enumOr(
          EngagementEventType.values,
          json['type'],
          EngagementEventType.profileView,
        ),
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
                DateTime.now(),
        cityId: json['cityId'] as String?,
        localityId: json['localityId'] as String?,
        categoryId: json['categoryId'] as String?,
        totalCount: (json['totalCount'] as num?)?.toInt(),
      );
}

/// Aggregated engagement shown on the provider dashboard.
///
/// Named for what it actually measures: button taps. Not calls, not leads.
class EngagementSummary {
  const EngagementSummary({
    required this.profileViews,
    required this.callButtonTaps,
    required this.whatsappButtonTaps,
    required this.shareTaps,
    required this.isSampleData,
    this.periodStart,
    this.periodEnd,
  });

  const EngagementSummary.empty()
      : profileViews = 0,
        callButtonTaps = 0,
        whatsappButtonTaps = 0,
        shareTaps = 0,
        isSampleData = false,
        periodStart = null,
        periodEnd = null;

  final int profileViews;
  final int callButtonTaps;
  final int whatsappButtonTaps;
  final int shareTaps;

  /// True while the numbers come from seeded/mock data. The dashboard labels
  /// them accordingly.
  final bool isSampleData;

  final DateTime? periodStart;
  final DateTime? periodEnd;

  static EngagementSummary fromEvents(
    List<EngagementEvent> events, {
    bool isSampleData = false,
  }) {
    int views = 0;
    int calls = 0;
    int whatsapps = 0;
    int shares = 0;
    DateTime? start;
    DateTime? end;
    for (final EngagementEvent event in events) {
      switch (event.type) {
        case EngagementEventType.profileView:
          views += event.count;
        case EngagementEventType.callButtonTap:
          calls += event.count;
        case EngagementEventType.whatsappButtonTap:
          whatsapps += event.count;
        case EngagementEventType.shareTap:
          shares += event.count;
        case EngagementEventType.sponsorImpression:
        case EngagementEventType.sponsorTap:
          break;
      }
      if (start == null || event.occurredAt.isBefore(start)) {
        start = event.occurredAt;
      }
      if (end == null || event.occurredAt.isAfter(end)) {
        end = event.occurredAt;
      }
    }
    return EngagementSummary(
      profileViews: views,
      callButtonTaps: calls,
      whatsappButtonTaps: whatsapps,
      shareTaps: shares,
      isSampleData: isSampleData,
      periodStart: start,
      periodEnd: end,
    );
  }
}

/// Shared tolerant enum parser for the hand-written JSON codecs above.
T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    // Accepts camelCase (local JSON) and snake_case (Postgres wire tokens).
    final String wanted = name.replaceAll('_', '').toLowerCase();
    for (final T value in values) {
      if (value.name.toLowerCase() == wanted) return value;
    }
  }
  return fallback;
}
