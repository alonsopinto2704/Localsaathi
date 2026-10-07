import '../../domain/models/enums.dart';
import '../../domain/models/moderation.dart';
import '../../domain/repositories/engagement_repository.dart';
import '../../domain/repositories/report_repository.dart';
import '../local/key_value_store.dart';
import 'mock_data_store.dart';

/// Customer reports. Customers may create reports; nothing here lets them edit
/// a provider's information.
class MockReportRepository implements ReportRepository {
  MockReportRepository({required MockDataStore store}) : _store = store;

  final MockDataStore _store;

  @override
  Future<Report> submit({
    required String providerId,
    required ReportReason reason,
    String? details,
    String? reporterPhoneE164,
  }) async {
    final Report report = Report(
      id: _store.newId('report'),
      providerId: providerId,
      reason: reason,
      status: ReportStatus.submitted,
      createdAt: _store.now,
      details: (details ?? '').trim().isEmpty ? null : details!.trim(),
      reporterPhoneE164: reporterPhoneE164,
    );
    _store.reports.insert(0, report);
    await _store.persistReports();
    return report;
  }

  @override
  Future<List<Report>> myReports() async =>
      List<Report>.unmodifiable(_store.reports);

  @override
  Future<bool> hasReported(String providerId) async => _store.reports
      .any((Report r) => r.providerId == providerId);

  @override
  Future<List<Report>> queue({ReportStatus? status}) async {
    final List<Report> list = status == null
        ? List<Report>.from(_store.reports)
        : _store.reports.where((Report r) => r.status == status).toList();
    list.sort((Report a, Report b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

/// Engagement tracking.
///
/// Only button taps and profile views can be recorded: [EngagementEventType]
/// has no "call completed", "lead" or "job" member, which is the structural
/// guarantee behind the promise never to report those.
class MockEngagementRepository implements EngagementRepository {
  MockEngagementRepository({required MockDataStore store}) : _store = store;

  final MockDataStore _store;

  @override
  Future<void> record({
    required String providerId,
    required EngagementEventType type,
    String? cityId,
    String? localityId,
    String? categoryId,
  }) async {
    _store.engagementEvents.add(
      EngagementEvent(
        id: _store.newId('event'),
        providerId: providerId,
        type: type,
        occurredAt: _store.now,
        cityId: cityId,
        localityId: localityId,
        categoryId: categoryId,
      ),
    );
    await _store.persistEngagement();
  }

  @override
  Future<EngagementSummary> summaryFor(String providerId) async {
    final List<EngagementEvent> events = _store.engagementEvents
        .where((EngagementEvent e) => e.providerId == providerId)
        .toList();
    if (events.isEmpty) {
      return const EngagementSummary(
        profileViews: 0,
        callButtonTaps: 0,
        whatsappButtonTaps: 0,
        shareTaps: 0,
        // Zeroes are real: the provider genuinely has no taps yet, so this is
        // not sample data and must not be labelled as such.
        isSampleData: false,
      );
    }
    final bool sample = events.any((EngagementEvent e) => e.totalCount != null);
    return EngagementSummary.fromEvents(events, isSampleData: sample);
  }
}

/// Sponsored placements and monetization presentation.
///
/// This class decides *matching* only. It never touches verification labels,
/// never hides organic results, and has no payment path: [registerInterest]
/// records an intent and nothing else.
class MockPromotionRepository implements PromotionRepository {
  MockPromotionRepository({
    required MockDataStore store,
    required KeyValueStore keyValueStore,
  })  : _store = store,
        _kv = keyValueStore;

  final MockDataStore _store;
  final KeyValueStore _kv;

  @override
  Future<List<Promotion>> activePromotions({
    required String cityId,
    String? localityId,
    String? categoryId,
    PromotionPlacement? placement,
  }) async {
    final List<Promotion> list = _store.promotions
        .where((Promotion p) =>
            p.isActiveAt(_store.now) &&
            (placement == null || p.placement == placement) &&
            p.matches(
              cityId: cityId,
              localityId: localityId,
              categoryId: categoryId,
            ))
        .toList()
      ..sort((Promotion a, Promotion b) => b.priority.compareTo(a.priority));
    return list;
  }

  @override
  Future<List<SubscriptionPlan>> subscriptionPlans() async =>
      const <SubscriptionPlan>[
    SubscriptionPlan(
      id: 'plan-visibility',
      titleKey: 'planVisibility',
      featureKeys: <String>[
        'subscriptionFeaturePhotos',
        'subscriptionFeatureContent',
        'subscriptionFeatureServiceAreas',
      ],
    ),
    SubscriptionPlan(
      id: 'plan-insights',
      titleKey: 'planInsights',
      isRecommended: true,
      featureKeys: <String>[
        'subscriptionFeatureStats',
        'subscriptionFeatureContent',
        'subscriptionFeatureServiceAreas',
      ],
    ),
    SubscriptionPlan(
      id: 'plan-complete',
      titleKey: 'planComplete',
      featureKeys: <String>[
        'subscriptionFeaturePhotos',
        'subscriptionFeatureContent',
        'subscriptionFeatureStats',
        'subscriptionFeatureServiceAreas',
      ],
    ),
  ];

  @override
  Future<void> registerInterest({
    required String providerId,
    required String planId,
  }) async {
    _store.promotionInterest.add('$providerId::$planId');
    await _store.persistPromotionInterest();
  }

  /// Plans a provider has registered interest in, so the monetization screen can
  /// show a confirmed state rather than inviting a duplicate tap.
  @override
  Future<Set<String>> interestFor(String providerId) async => _store
      .promotionInterest
      .where((String entry) => entry.startsWith('$providerId::'))
      .map((String entry) => entry.split('::').last)
      .toSet();

  /// Wording version used by consent UI, re-exported so call sites do not need
  /// to reach into the store.
  static const String consentWordingVersion =
      MockDataStore.consentWordingVersion;

  /// Local key/value accessor kept for symmetry with the other repositories.
  KeyValueStore get keyValueStore => _kv;
}
