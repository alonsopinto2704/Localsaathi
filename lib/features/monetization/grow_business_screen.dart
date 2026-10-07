import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_badges.dart';
import '../../domain/models/moderation.dart';

/// "Grow your business".
///
/// A polished preview of two future revenue options and nothing more: no
/// checkout, no payment SDK, no entitlement. Prices are not shown because they
/// are not decided, and the screen says so. Three promises are stated on the
/// screen itself, because they are the ones a monetized directory most easily
/// breaks:
///
/// * sponsored placements are always labelled;
/// * organic results stay visible next to them;
/// * verification can never be bought, and paying guarantees no enquiries.
class GrowBusinessScreen extends StatefulWidget {
  const GrowBusinessScreen({super.key});

  @override
  State<GrowBusinessScreen> createState() => _GrowBusinessScreenState();
}

class _GrowBusinessScreenState extends State<GrowBusinessScreen> {
  bool _initialised = false;
  List<SubscriptionPlan> _plans = <SubscriptionPlan>[];
  Set<String> _interested = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _load();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<SubscriptionPlan> plans =
        await dependencies.promotions.subscriptionPlans();
    final String? profileId =
        context.read<SessionController>().profile?.id;
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _interested = <String>{};
    });
    if (profileId == null) return;
    final Set<String> existing =
        await dependencies.promotions.interestFor(profileId);
    if (!mounted) return;
    setState(() => _interested = existing);
  }

  Future<void> _registerInterest(SubscriptionPlan plan) async {
    final String? profileId = context.read<SessionController>().profile?.id;
    final AppDependencies dependencies = context.read<AppDependencies>();
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.providerSignIn)),
      );
      return;
    }
    await dependencies.promotions.registerInterest(
      providerId: profileId,
      planId: plan.id,
    );
    if (!mounted) return;
    setState(() => _interested = <String>{..._interested, plan.id});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.registerInterestDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.monetizationTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Text(strings.monetizationSubtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          AppBanner.development(
            message: strings.monetizationDisclaimer,
            title: strings.pricingComingSoon,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ------------------------------------------------- sponsored
          SectionHeader(
            title: strings.sponsoredListingsTitle,
            subtitle: strings.sponsoredListingsBody,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AppBadgeInline.sponsored(label: strings.sponsored),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        strings.sponsoredListingBulletOne,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Bullet(text: strings.sponsoredListingBulletTwo),
                  _Bullet(text: strings.sponsoredListingBulletThree),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  // A small mock of how a labelled slot appears, so the
                  // provider understands the format rather than just reading
                  // about it.
                  _SponsoredPreview(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.pricingComingSoon,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.subscriptionTitle,
            subtitle: strings.subscriptionBody,
          ),
          for (final SubscriptionPlan plan in _plans)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PlanCard(
                plan: plan,
                isInterested: _interested.contains(plan.id),
                onRegisterInterest: () => _registerInterest(plan),
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          AppBanner(
            message: strings.noVerificationForSale,
            tone: AppBannerTone.info,
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            message: strings.subscriptionDisclaimer,
            tone: AppBannerTone.caution,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.commissionNotTrackedNote,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Illustrates the sponsored slot format so "clearly labelled" is concrete.
class _SponsoredPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.sponsoredPreviewTitle,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppBadgeInline.sponsored(label: strings.sponsored),
              const SizedBox(height: AppSpacing.sm),
              Text(strings.sponsoredPreviewYourListing,
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(
            strings.sponsoredPreviewOrganic,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isInterested,
    required this.onRegisterInterest,
  });

  final SubscriptionPlan plan;
  final bool isInterested;
  final VoidCallback onRegisterInterest;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _title(context),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (plan.isRecommended)
                  AppBadgeInline(
                    label: strings.popularChoiceLabel,
                    foreground: theme.colorScheme.primary,
                    background: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Price is intentionally absent: it is not decided, and inventing
            // one would be a promise we cannot keep.
            Text(
              strings.pricingComingSoon,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final String key in plan.featureKeys)
              _Bullet(text: _featureLabel(context, key)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.notNow),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: isInterested ? null : onRegisterInterest,
                    child: Text(
                      isInterested
                          ? strings.registeredInterestLabel
                          : strings.registerInterest,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    final strings = context.strings;
    switch (plan.id) {
      case 'plan-visibility':
        return strings.planVisibilityTitle;
      case 'plan-insights':
        return strings.planInsightsTitle;
      default:
        return strings.planCompleteTitle;
    }
  }

  String _featureLabel(BuildContext context, String key) {
    final strings = context.strings;
    switch (key) {
      case 'subscriptionFeaturePhotos':
        return strings.subscriptionFeaturePhotos;
      case 'subscriptionFeatureContent':
        return strings.subscriptionFeatureContent;
      case 'subscriptionFeatureStats':
        return strings.subscriptionFeatureStats;
      case 'subscriptionFeatureServiceAreas':
        return strings.subscriptionFeatureServiceAreas;
      default:
        return key;
    }
  }
}
