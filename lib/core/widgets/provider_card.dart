import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controllers/saved_providers_controller.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/category_icons.dart';
import 'provider_badges.dart';
import 'provider_contact.dart';
import 'provider_photos.dart';

/// White, hairline-bordered surface with the blueprint's level-1 shadow.
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.radius = AppSpacing.radiusLg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: color == null ? AppTheme.cardShadow : null,
      ),
      child: Material(
        color: color ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Provider result card.
///
/// Shows exactly what a customer needs to choose someone: name, service,
/// locality, working-hours status where we actually know it, honest
/// verification labels, and the contact actions. It deliberately shows **no**
/// rating, review count or distance, because the app has no reviews and no
/// coordinates — inventing any of them would be a lie.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.provider,
    required this.categoryName,
    required this.localityName,
    this.cityName,
    this.isSponsored = false,
    this.showServesYourArea = false,
    this.onTap,
  });

  final ProviderProfile provider;

  /// Resolved by the caller: categories and localities are data, so the card
  /// must not look them up itself.
  final String categoryName;
  final String localityName;
  final String? cityName;

  final bool isSponsored;

  /// True when the provider's base locality differs from the customer's but
  /// they serve the customer's locality. Surfaced so "based elsewhere" is
  /// explicit rather than confusing.
  final bool showServesYourArea;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semantic;

    final SavedProvidersController saved =
        context.watch<SavedProvidersController>();
    final bool isSaved = saved.isSaved(provider.id);
    final ContactAvailability availability = ContactAvailability.of(provider);
    final int extraAreas = provider.serviceAreas
        .where(
          (ProviderServiceArea a) => a.localityId != provider.baseLocalityId,
        )
        .length;

    return AppSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isSponsored) ...<Widget>[
            Row(
              children: <Widget>[
                AppBadgeInline.sponsored(label: strings.sponsored),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    strings.promotedByProvider,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProviderThumbnail(provider: provider, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.displayName,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (categoryName.isNotEmpty)
                      Text(
                        categoryName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            <String>[
                              localityName,
                              if (extraAreas > 0) strings.servesMoreAreas(extraAreas),
                            ].join(' · '),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _BookmarkButton(provider: provider, isSaved: isSaved),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (provider.isPhoneVerified)
                AppBadgeInline.verified(label: strings.verifiedPhoneLabel),
              if (provider.isCredentialsVerified)
                AppBadgeInline.verified(
                  label: strings.verifiedCredentialsLabel,
                  icon: Icons.school_outlined,
                )
              else if (provider.healthcareDetails?.hasClaimedRegistration ??
                  false)
                AppBadgeInline.claimed(label: strings.registrationClaimedLabel),
              WorkingHoursChip(status: availability.workingHoursStatus),
              if (provider.homeVisits)
                AppBadgeInline(
                  label: strings.homeVisitsAvailable,
                  icon: Icons.home_work_outlined,
                  foreground: semantic.info,
                  background: semantic.infoSurface,
                ),
              if (showServesYourArea)
                AppBadgeInline(
                  label: strings.servingYourArea,
                  icon: Icons.near_me_outlined,
                  foreground: semantic.info,
                  background: semantic.infoSurface,
                ),
            ],
          ),
          if (provider.hasStartingPrice) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    strings.indicativeRate,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      text: '${strings.startingFromLabel} ',
                      children: <InlineSpan>[
                        TextSpan(
                          text: '₹${provider.startingPrices.first.amount}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ProviderContactButtons(provider: provider, compact: true),
          if (provider.isDemoProfile) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.demoProfileNotice,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The provider's first real photo, or their initials on the primary tint.
class ProviderThumbnail extends StatelessWidget {
  const ProviderThumbnail({super.key, required this.provider, this.size = 56});

  final ProviderProfile provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    ProviderPhoto? cover;
    for (final ProviderPhoto photo in provider.photos) {
      if (photo.hasImage) {
        cover = photo;
        break;
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child: cover != null
            ? ProviderPhotoImage(photo: cover)
            : ColoredBox(
                color: theme.colorScheme.primaryContainer,
                child: Center(
                  child: Text(
                    provider.initials(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.provider, required this.isSaved});

  final ProviderProfile provider;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return IconButton(
      onPressed: () async {
        final bool nowSaved =
            await context.read<SavedProvidersController>().toggle(provider.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nowSaved ? strings.savedConfirmation : strings.removedFromSaved,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      tooltip: isSaved ? strings.removeFromSaved : strings.saveProvider,
      icon: AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: AppCurves.press,
        transitionBuilder: (Widget child, Animation<double> a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          key: ValueKey<bool>(isSaved),
          color: isSaved ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }
}

/// The rounded icon well used by category tiles and rows.
class CategoryIconWell extends StatelessWidget {
  const CategoryIconWell({super.key, required this.iconKey, this.size = 48});

  final String iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(
        categoryIcon(iconKey),
        size: size * 0.5,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// Square tile for the home screen's "What do you need help with?" grid.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    this.onTap,
  });

  final ServiceCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppSurfaceCard(
      onTap: onTap,
      radius: AppSpacing.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CategoryIconWell(iconKey: category.iconKey),
          const SizedBox(height: AppSpacing.sm),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row for the categories tab: icon well, name, live provider count.
class CategoryListRow extends StatelessWidget {
  const CategoryListRow({
    super.key,
    required this.category,
    this.onTap,
    this.providerCount,
  });

  final ServiceCategory category;
  final VoidCallback? onTap;
  final int? providerCount;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semantic;
    final int? count = providerCount;
    return AppSurfaceCard(
      onTap: onTap,
      radius: AppSpacing.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xxs,
      ),
      child: Row(
        children: <Widget>[
          CategoryIconWell(iconKey: category.iconKey, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(category.name, style: theme.textTheme.titleSmall),
                if (count != null)
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.circle,
                        size: 7,
                        color: count > 0
                            ? semantic.success
                            : theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        strings.providersNearbyCount(count),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
