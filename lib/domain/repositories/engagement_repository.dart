import '../models/moderation.dart';

/// Engagement tracking.
///
/// Only button taps and profile views are recorded. There is deliberately no
/// way to record a completed call, a lead or a job: the app hands off to the
/// dialer or WhatsApp and cannot observe the outcome, so it must not claim to.
abstract class EngagementRepository {
  Future<void> record({
    required String providerId,
    required EngagementEventType type,
    String? cityId,
    String? localityId,
    String? categoryId,
  });

  /// Aggregated counts for the provider dashboard, including the
  /// sample-data flag the UI must display while the data is mocked.
  Future<EngagementSummary> summaryFor(String providerId);
}

/// Sponsored placements and monetization presentation.
///
/// No payment is collected in this build. The repository only decides *which*
/// clearly-labelled sponsored slots match a customer's category and locality.
abstract class PromotionRepository {
  /// Active promotions matching the customer's context, highest priority first.
  Future<List<Promotion>> activePromotions({
    required String cityId,
    String? localityId,
    String? categoryId,
    PromotionPlacement? placement,
  });

  /// Monetization options for the "Grow your business" screen. Always
  /// unpriced in this build.
  Future<List<SubscriptionPlan>> subscriptionPlans();

  /// Records a provider's interest in a future paid plan. No payment, no
  /// entitlement, no checkout.
  Future<void> registerInterest({
    required String providerId,
    required String planId,
  });

  /// Plan ids this provider has already registered interest in, so the screen
  /// can show a confirmed state instead of inviting a duplicate tap.
  Future<Set<String>> interestFor(String providerId);
}
