import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/location_controller.dart';
import '../../app/controllers/saved_providers_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_icons.dart';
import '../../core/utils/phone_number.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_avatar.dart';
import '../../core/widgets/provider_badges.dart';
import '../../core/widgets/provider_card.dart';
import '../../core/widgets/provider_contact.dart';
import '../../core/widgets/provider_map.dart';
import '../../core/widgets/provider_photos.dart';
import '../../core/widgets/reveal.dart';
import '../../data/seed/locality_coordinates.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import 'report_listing_sheet.dart';

/// Public provider profile.
///
/// Ordering is deliberate: identity, then how to reach them, then what they do,
/// then the professional detail. Healthcare detail is fenced off in its own
/// section with an explicit "provided by the provider, not verified" note, so
/// the page can never read as a medical endorsement.
///
/// A paused or deleted listing renders [profileUnavailable] rather than a
/// partial profile: a saved link must not reveal a hidden listing.
class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key, required this.providerId});

  final String providerId;

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late Future<_ProfileData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData?> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final ProviderProfile? provider =
        await dependencies.providers.publicProfileById(widget.providerId);
    if (provider == null) return null;

    final List<ServiceCategory> categories =
        await dependencies.catalog.categoriesByIds(provider.categoryIds);
    final Locality? baseLocality =
        await dependencies.locations.localityById(provider.baseLocalityId);
    final City? city =
        await dependencies.locations.cityById(provider.baseCityId);

    final List<Locality> serviceAreas =
        await dependencies.providers.serviceAreaLocalities(provider);
    final List<ProviderProfile> similar =
        await dependencies.providers.similarProviders(provider);

    // Record a profile view. Only a view: nothing here claims a call or a job.
    try {
      await dependencies.engagement.record(
        providerId: provider.id,
        type: EngagementEventType.profileView,
        cityId: provider.baseCityId,
        localityId: provider.baseLocalityId,
      );
    } on Object {
      // Never block the profile on analytics.
    }

    return _ProfileData(
      provider: provider,
      categories: categories,
      baseLocality: baseLocality,
      city: city,
      serviceAreas: serviceAreas,
      similar: similar,
    );
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: FutureBuilder<_ProfileData?>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<_ProfileData?> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: AppErrorState(
                message: strings.somethingWentWrong,
                onRetry: _refresh,
              ),
            );
          }
          final _ProfileData? data = snapshot.data;
          if (data == null) {
            return Scaffold(
              appBar: AppBar(),
              body: AppEmptyState(
                title: strings.profileUnavailable,
                body: strings.profileUnavailableBody,
                icon: Icons.person_off_outlined,
                actionLabel: strings.browseProviders,
                onAction: () => Navigator.of(context).pop(),
              ),
            );
          }
          return _ProfileBody(data: data, onRefresh: _refresh);
        },
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.provider,
    required this.categories,
    required this.baseLocality,
    required this.city,
    required this.serviceAreas,
    required this.similar,
  });

  final ProviderProfile provider;
  final List<ServiceCategory> categories;
  final Locality? baseLocality;
  final City? city;
  final List<Locality> serviceAreas;
  final List<ProviderProfile> similar;
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data, required this.onRefresh});

  final _ProfileData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semantic;
    final ProviderProfile provider = data.provider;
    final SavedProvidersController saved =
        context.watch<SavedProvidersController>();
    final LocationSelection? selection =
        context.watch<LocationController>().selection;
    final bool isSaved = saved.isSaved(provider.id);
    final ContactAvailability availability = ContactAvailability.of(provider);
    final HealthcareDetails? healthcare = provider.healthcareDetails;
    final List<ProviderPhoto> photos =
        provider.photos.where((ProviderPhoto p) => p.hasImage).toList();
    final bool takingWork =
        provider.availability == AvailabilityStatus.available;

    final String categoryLine = data.categories
        .map((ServiceCategory c) => c.name)
        .join(' · ');
    final List<String> otherAreas = <String>[
      for (final Locality l in data.serviceAreas)
        if (l.id != provider.baseLocalityId) l.name,
    ];

    Widget infoRow(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return Scaffold(
      // The two ways to reach the provider stay on screen while reading.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D172B35),
              offset: Offset(0, -3),
              blurRadius: 12,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ProviderContactButtons(provider: provider),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.zeroCommission,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            title: Text(strings.providerDetails),
            actions: <Widget>[
              IconButton(
                tooltip:
                    isSaved ? strings.removeFromSaved : strings.saveProvider,
                onPressed: () async {
                  final bool nowSaved = await saved.toggle(provider.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nowSaved
                            ? strings.savedConfirmation
                            : strings.removedFromSaved,
                      ),
                    ),
                  );
                },
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
              ),
              IconButton(
                tooltip: strings.share,
                onPressed: () => ProviderContactActions(context)
                    .share(provider, cityName: data.city?.name),
                icon: const Icon(Icons.share_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) async {
                  if (value == 'report') {
                    await showReportListingSheet(
                      context,
                      providerId: provider.id,
                      providerName: provider.displayName,
                    );
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.flag_outlined, size: 18),
                        const SizedBox(width: AppSpacing.md),
                        Text(strings.report),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.sm,
                AppSpacing.pagePadding,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (provider.isDemoProfile) ...<Widget>[
                    AppBanner.sampleData(message: strings.demoProfileNotice),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 1. Who they are.
                  Reveal(
                    child: AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              GestureDetector(
                                onTap: photos.isEmpty
                                    ? null
                                    : () => showProviderPhotoViewer(
                                          context,
                                          photos,
                                          0,
                                        ),
                                child: ProviderThumbnail(
                                  provider: provider,
                                  size: 84,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (provider.isPhoneVerified) ...<Widget>[
                                      AppBadgeInline.verified(
                                        label: strings.verifiedPhoneLabel,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                    ],
                                    Text(
                                      provider.displayName,
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                    if (categoryLine.isNotEmpty)
                                      Text(
                                        categoryLine,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Column(
                              children: <Widget>[
                                infoRow(
                                  Icons.event_available_outlined,
                                  strings.detailsUpdated(
                                    formatShortDate(provider.updatedAt),
                                  ),
                                ),
                                infoRow(
                                  Icons.place_outlined,
                                  <String>[
                                    <String>[
                                      if (data.baseLocality != null)
                                        data.baseLocality!.name,
                                      if (data.city != null) data.city!.name,
                                    ].join(', '),
                                    if (otherAreas.isNotEmpty)
                                      '(${strings.servesLabel}: ${otherAreas.join(', ')})',
                                  ].join(' '),
                                ),
                                if (provider.languages.isNotEmpty)
                                  infoRow(
                                    Icons.translate,
                                    '${strings.speaksLabel}: ${provider.languages.join(', ')}',
                                  ),
                                infoRow(
                                  availability.canCall
                                      ? Icons.call_outlined
                                      : Icons.phone_disabled_outlined,
                                  availability.canCall
                                      ? (availability.isDemoProfile
                                          ? availability.maskedNumber
                                          : PhoneUtils.formatPretty(
                                              provider.phoneE164,
                                            ))
                                      : strings.contactNumberHidden,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Are they taking work, and when.
                  Reveal(
                    index: 1,
                    child: AppSurfaceCard(
                      color: takingWork
                          ? theme.colorScheme.primaryContainer
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: takingWork
                                    ? semantic.success
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _availabilityLabel(
                                    context,
                                    provider.availability,
                                  ),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              WorkingHoursChip(
                                status: availability.workingHoursStatus,
                              ),
                              AppBadgeInline(
                                label: provider.homeVisits
                                    ? strings.homeVisitsAvailable
                                    : strings.noHomeVisits,
                                icon: Icons.home_work_outlined,
                                foreground: semantic.info,
                                background: semantic.infoSurface,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Every provider: the exact pin if they opted in, otherwise
                  // the approximate area they work in.
                  _Section(
                    title: strings.locationTitle,
                    icon: Icons.map_outlined,
                    child: ProviderLocationMap(
                      exact: provider.mapLocation,
                      baseArea: centreFor(
                        localityId: provider.baseLocalityId,
                        cityId: provider.baseCityId,
                      ),
                      otherAreas: <GeoPoint>[
                        for (final Locality l in data.serviceAreas)
                          if (l.id != provider.baseLocalityId)
                            centreFor(localityId: l.id, cityId: l.cityId),
                      ],
                      baseAreaName:
                          data.baseLocality?.name ?? strings.areasServed,
                    ),
                  ),

                  // 3. What it costs.
                  if (provider.hasStartingPrice)
                    _Section(
                      title: strings.chargesTitle,
                      icon: Icons.payments_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              for (final StartingPrice price
                                  in provider.startingPrices)
                                Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 140),
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        data.categories
                                            .where(
                                              (ServiceCategory c) =>
                                                  c.id == price.categoryId,
                                            )
                                            .map((ServiceCategory c) => c.name)
                                            .join(),
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '${strings.startingFrom} ${formatRupees(price.amount)}',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            strings.startingPriceDisclaimer,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. What they do.
                  if (data.categories.isNotEmpty)
                    _Section(
                      title: strings.servicesOffered,
                      icon: Icons.handyman_outlined,
                      child: Column(
                        children: <Widget>[
                          for (final ServiceCategory category in data.categories)
                            Container(
                              margin:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    categoryIcon(category.iconKey),
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 5. Their work.
                  if (photos.isNotEmpty)
                    _Section(
                      title: strings.recentWork,
                      icon: Icons.photo_library_outlined,
                      trailing: strings.photoCount(photos.length),
                      child: ProviderPhotoStrip(photos: photos),
                    ),

                  _Section(
                    title: strings.workingHours,
                    icon: Icons.schedule,
                    child: _WorkingHoursTable(
                      hours: provider.workingHours,
                      status: availability.workingHoursStatus,
                    ),
                  ),

                  if ((provider.description ?? '').trim().isNotEmpty)
                    _Section(
                      title: strings.aboutProvider,
                      icon: Icons.person_outline,
                      child: Text(
                        provider.description!.trim(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),

                  _Section(
                    title: strings.areasServed,
                    icon: Icons.map_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            for (final Locality locality in data.serviceAreas)
                              AppBadgeInline.neutral(
                                label: locality.name,
                                icon: Icons.place_outlined,
                              ),
                          ],
                        ),
                        if (selection != null &&
                            !provider.servedLocalityIds
                                .contains(selection.localityId) &&
                            provider.baseLocalityId !=
                                selection.localityId) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            strings.doesNotServeYourArea,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          strings.localityOnlyPrivacyNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trust labels, in a fixed order, so phone verification can
                  // never be conflated with a credentials review.
                  _Section(
                    title: strings.verificationTitle,
                    icon: Icons.verified_user_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        VerificationBadgeRow(
                          phoneVerified: provider.isPhoneVerified,
                          credentialsVerified: provider.isCredentialsVerified,
                          claimsCredentials:
                              healthcare?.hasClaimedRegistration ?? false,
                          showNotVerified: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          strings.phoneVerifiedExplainer,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          strings.credentialsVerifiedExplainer,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Professional detail, fenced and labelled as claimed.
                  if (healthcare != null && healthcare.hasAnyDetail)
                    _Section(
                      title: strings.healthcareSectionTitle,
                      icon: Icons.medical_information_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AppBanner(
                            message: strings.healthcareCredentialsNotice,
                            tone: AppBannerTone.caution,
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _DetailRow(
                            label: strings.qualificationLabel,
                            value: healthcare.qualification,
                          ),
                          _DetailRow(
                            label: strings.specialtyLabel,
                            value: healthcare.specialty,
                          ),
                          _DetailRow(
                            label: strings.clinicNameLabel,
                            value: healthcare.clinicName,
                          ),
                          _DetailRow(
                            label: strings.clinicAddressLabel,
                            value: healthcare.clinicAddress,
                          ),
                          _DetailRow(
                            label: strings.consultationHoursLabel,
                            value: healthcare.consultationHoursNote,
                          ),
                          _DetailRow(
                            label: strings.registrationNumberLabel,
                            value: healthcare.registrationNumber,
                          ),
                          _DetailRow(
                            label: strings.registrationCouncilLabel,
                            value: healthcare.registrationCouncil,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            strings.healthcareDirectoryOnlyNotice,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),
                  AppBanner(
                    message: strings.reportNoteForCustomers,
                    actionLabel: strings.report,
                    onAction: () => showReportListingSheet(
                      context,
                      providerId: provider.id,
                      providerName: provider.displayName,
                    ),
                  ),

                  if (data.similar.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    SectionHeader(title: strings.similarProvidersTitle),
                    for (final ProviderProfile similar in data.similar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _SimilarRow(provider: similar),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _availabilityLabel(
    BuildContext context,
    AvailabilityStatus availability,
  ) {
    final strings = context.strings;
    switch (availability) {
      case AvailabilityStatus.available:
        return strings.availabilityAvailable;
      case AvailabilityStatus.busy:
        return strings.availabilityBusy;
      case AvailabilityStatus.unavailable:
        return strings.availabilityUnavailable;
    }
  }
}

/// A titled white card, one per topic, as in the design blueprint.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Weekly hours table.
///
/// When hours are absent the table is replaced by an explicit "not provided"
/// line, so a customer is never shown a misleading "closed".
class _WorkingHoursTable extends StatelessWidget {
  const _WorkingHoursTable({required this.hours, required this.status});

  final WorkingHours? hours;
  final bool? status;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    if (hours == null || !hours!.hasAnyHours) {
      return Text(
        strings.openingHoursUnknown,
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final DayHours day in hours!.days)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 110,
                  child: Text(
                    weekdayName(context, day.weekday),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Text(
                    day.isClosed
                        ? strings.closedAllDay
                        : '${TimeUtils.formatMinutes(day.openMinutes!)} – '
                            '${TimeUtils.formatMinutes(day.closeMinutes!)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          strings.hoursIndicatorNote,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SimilarRow extends StatelessWidget {
  const _SimilarRow({required this.provider});

  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).pushReplacementNamed(
          AppRoutes.providerProfile,
          arguments: provider.id,
        ),
        leading: ProviderAvatar(
          initials: provider.initials(),
          size: AppSpacing.avatarSm,
        ),
        title: Text(provider.displayName),
        subtitle: Text(
          formatWorkingHoursSummary(
            provider.workingHours,
            closedLabel: context.strings.closedAllDay,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
