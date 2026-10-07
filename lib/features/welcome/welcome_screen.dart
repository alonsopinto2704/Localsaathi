import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/app_settings_controller.dart';
import '../../app/controllers/location_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/provider_badges.dart';
import '../../core/widgets/provider_card.dart';
import '../../core/widgets/reveal.dart';
import '../../domain/models/location.dart';
import '../legal/legal_screen.dart';
import '../location/location_sheets.dart';

/// Welcome and location step.
///
/// One short screen instead of an onboarding carousel: a sentence about what the
/// app does, the live market named explicitly, a locality choice, and a continue
/// button. The "I offer services" path is visible but secondary, because the
/// common case is a customer looking for help.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _cityId;
  String? _localityId;
  bool _isSubmitting = false;

  List<Locality> _localities = <Locality>[];
  int? _providerCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeFromController());
  }

  void _primeFromController() {
    final LocationController controller = context.read<LocationController>();
    final LocationSelection? selection = controller.selection;
    final City? activeCity = controller.activeCity;
    setState(() {
      _cityId = selection?.cityId ?? activeCity?.id;
      _localityId = selection?.localityId;
    });
    if (_cityId != null) {
      _loadLocalities(_cityId!, keepSelection: true);
    }
  }

  Future<void> _loadLocalities(
    String cityId, {
    bool keepSelection = false,
  }) async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<Locality> localities =
        await dependencies.locations.localities(cityId);
    final int providerCount =
        (await dependencies.providers.publishedInCity(cityId)).length;
    if (!mounted) return;
    setState(() {
      _localities = localities;
      _providerCount = providerCount;
      if (!keepSelection) {
        _localityId = null;
      } else if (_localityId != null &&
          !localities.any((Locality l) => l.id == _localityId)) {
        _localityId = null;
      }
    });
  }

  Future<void> _continue() async {
    final String? cityId = _cityId;
    final String? localityId = _localityId;
    if (cityId == null || localityId == null) return;

    setState(() => _isSubmitting = true);
    final LocationController controller = context.read<LocationController>();
    final AppSettingsController settings =
        context.read<AppSettingsController>();

    final bool ok = await controller.select(
      cityId: cityId,
      localityId: localityId,
    );
    if (!mounted) return;
    if (ok) {
      await settings.markWelcomeSeen();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (Route<dynamic> r) => false);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.somethingWentWrong)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationController location = context.watch<LocationController>();

    if (location.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final City? activeCity = location.activeCity;
    final int? count = _providerCount;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Even in a wide browser this stays a focused, single column.
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.xxl,
                AppSpacing.pagePadding,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                const Reveal(child: Center(child: AppLogo(size: 72))),
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  index: 1,
                  child: Column(
                    children: <Widget>[
                      Text(
                        strings.appName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        strings.welcomeTagline.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        strings.welcomeHeadline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        strings.welcomeSubhead,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Reveal(
                  index: 2,
                  child: AppSurfaceCard(
                    color: theme.colorScheme.primaryContainer,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.handshake_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.directDiscovery,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              // A real count from the data, never a marketing
                              // number.
                              if (count != null && activeCity != null)
                                Text(
                                  strings.providersListedIn(
                                    count,
                                    activeCity.name,
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  index: 3,
                  child: AppSurfaceCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.location_on_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                strings.chooseYourArea,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (activeCity != null)
                              AppBadgeInline.verified(
                                label: strings.activeCity,
                                icon: Icons.circle,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SelectField(
                          label: strings.cityLabel,
                          value: activeCity?.name,
                          icon: Icons.location_city,
                          onTap: _pickCity,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SelectField(
                          label: strings.localityLabel,
                          value: _localityId == null
                              ? null
                              : _localityName(_localityId!),
                          icon: Icons.explore_outlined,
                          onTap: _pickLocality,
                          enabled: _localities.isNotEmpty,
                        ),
                        if (_localities.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          // Quick picks: the first few localities, one tap each.
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              for (final Locality l in _localities.take(6))
                                ChoiceChip(
                                  label: Text(l.name),
                                  selected: l.id == _localityId,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _localityId = l.id),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.locationPicker),
                            icon: const Icon(Icons.travel_explore, size: 18),
                            label: Text(strings.seeUpcomingCities),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed:
                      _cityId != null && _localityId != null && !_isSubmitting
                          ? _continue
                          : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: Text(strings.findServices),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        strings.orLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSurfaceCard(
                  color: theme.colorScheme.secondaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: const Icon(Icons.handyman_outlined),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  strings.areYouProTitle,
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  strings.areYouProBody,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.providerOnboarding),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(strings.offerServicesCta),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        strings.browseNoSignIn,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  strings.legalAgreementLine,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const LegalLinks(center: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localityName(String localityId) {
    for (final Locality locality in _localities) {
      if (locality.id == localityId) return locality.name;
    }
    return context.read<LocationController>().selection?.localityName ?? '';
  }

  Future<void> _pickCity() async {
    final LocationController controller = context.read<LocationController>();
    final AppDependencies dependencies = context.read<AppDependencies>();
    final City? activeCity = controller.activeCity;

    final City? chosen = await showCityPickerSheet(
      context,
      activeCityId: activeCity?.id,
    );
    if (chosen == null || !mounted) return;

    // Choosing a non-active city is allowed here so the availability message is
    // reachable through normal use, but it cannot become the browsing market.
    if (!chosen.isSelectable) {
      await _showNotActiveYet(chosen);
      return;
    }
    setState(() => _cityId = chosen.id);
    await _loadLocalities(chosen.id);
    if (!mounted) return;
    final Locality? fallback =
        await dependencies.locations.defaultLocality(chosen.id);
    if (fallback != null && mounted) {
      setState(() => _localityId = fallback.id);
    }
  }

  Future<void> _pickLocality() async {
    final String? cityId = _cityId;
    if (cityId == null) return;
    final Locality? chosen = await showLocalityPickerSheet(
      context,
      cityId: cityId,
      selectedId: _localityId,
    );
    if (chosen == null || !mounted) return;
    setState(() => _localityId = chosen.id);
  }

  /// The launch-availability message for a city that is not live yet, with the
  /// escape hatches the product requires: browse the live market, or request
  /// your own city.
  Future<void> _showNotActiveYet(City city) async {
    final strings = context.strings;
    final LocationController controller = context.read<LocationController>();
    final City activeCity = await controller.launchCity();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: Text(strings.launchAvailabilityTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.launchAvailabilityMessageTemplate(activeCity.name)),
            const SizedBox(height: AppSpacing.md),
            Text(
              city.name,
              style: Theme.of(dialogContext).textTheme.titleSmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed(AppRoutes.requestCity);
            },
            child: Text(strings.requestMyCity),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                Text(strings.browseActiveCityAnywayTemplate(activeCity.name)),
          ),
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      value ??
                          (enabled
                              ? strings.notSet
                              : strings.noLocalitiesAvailable),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
