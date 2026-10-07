import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/location_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_badges.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/location.dart';

/// Nationwide city browser.
///
/// This screen is how "another city can be activated through data" is visible to
/// a developer: every row comes from the location repository, and a city's
/// section is decided by its `launchStatus`. Flipping Thane to `active` moves it
/// from "Coming soon" to "Available now" with no change to this file.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialCityId});

  final String? initialCityId;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  bool _loading = true;
  List<City> _active = <City>[];
  List<City> _comingSoon = <City>[];
  final Map<String, String> _stateNames = <String, String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<City> cities = await dependencies.locations.availableCities();
    await _fillStateNames(dependencies, cities);
    if (!mounted) return;
    setState(() {
      _active = cities.where((City c) => c.isSelectable).toList();
      _comingSoon = cities
          .where((City c) => c.launchStatus == CityLaunchStatus.comingSoon)
          .toList();
      _loading = false;
    });
  }

  Future<void> _fillStateNames(
    AppDependencies dependencies,
    List<City> cities,
  ) async {
    for (final City city in cities) {
      if (_stateNames.containsKey(city.stateId)) continue;
      final StateRegion? state =
          await dependencies.locations.stateById(city.stateId);
      if (state != null) _stateNames[city.stateId] = state.name;
    }
  }

  Future<void> _search(String query) async {
    setState(() => _query = query);
    final AppDependencies dependencies = context.read<AppDependencies>();
    if (query.trim().isEmpty) {
      await _load();
      return;
    }
    final List<City> results = await dependencies.locations.searchCities(query);
    await _fillStateNames(dependencies, results);
    if (!mounted) return;
    setState(() {
      _active = results.where((City c) => c.isSelectable).toList();
      _comingSoon = results
          .where((City c) => c.launchStatus == CityLaunchStatus.comingSoon)
          .toList();
    });
  }

  Future<void> _selectCity(City city) async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final LocationController controller = context.read<LocationController>();
    final Locality? locality =
        await dependencies.locations.defaultLocality(city.id);
    if (!mounted || locality == null) return;

    final bool ok = await controller.select(
      cityId: city.id,
      localityId: locality.id,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${city.name} · ${locality.name}')),
      );
      Navigator.of(context).pop();
    }
  }

  /// The launch-availability message for a city that is not live, with the
  /// option to browse the active market instead or request the city.
  Future<void> _showNotActive(City city) async {
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
              '${city.name} · ${_stateNames[city.stateId] ?? ''}',
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
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _selectCity(activeCity);
            },
            child:
                Text(strings.browseActiveCityAnywayTemplate(activeCity.name)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationController controller = context.watch<LocationController>();
    final City? activeCity = controller.activeCity;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.chooseCity),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.requestCity),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(strings.requestMyCity),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(
                    hintText: strings.searchCityHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _search(''),
                          ),
                  ),
                  onChanged: _search,
                ),
                if (activeCity != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  AppBanner(
                    message:
                        strings.launchAvailabilityMessageTemplate(activeCity.name),
                    title: strings.launchAvailabilityTitle,
                    actionLabel: strings.browseActiveCityAnywayTemplate(
                      activeCity.name,
                    ),
                    onAction: () => Navigator.of(context).pop(),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoadingState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      0,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl,
                    ),
                    children: <Widget>[
                      if (_active.isNotEmpty) ...<Widget>[
                        SectionHeader(title: strings.activeMarkets),
                        for (final City city in _active)
                          _CityRow(
                            city: city,
                            stateName: _stateNames[city.stateId],
                            isSelected: city.id == controller.selection?.cityId,
                            onTap: () => _selectCity(city),
                          ),
                      ],
                      if (_comingSoon.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        SectionHeader(
                          title: strings.upcomingMarkets,
                          subtitle: strings.requestMyCityBody,
                        ),
                        for (final City city in _comingSoon)
                          _CityRow(
                            city: city,
                            stateName: _stateNames[city.stateId],
                            onTap: () => _showNotActive(city),
                          ),
                      ],
                      if (_active.isEmpty && _comingSoon.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                          child: AppEmptyState(
                            title: strings.errorNotFound,
                            body: strings.searchEmptyBody,
                            icon: Icons.location_off_outlined,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        strings.noDistanceDisclaimer,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.city,
    required this.stateName,
    required this.onTap,
    this.isSelected = false,
  });

  final City city;
  final String? stateName;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        city.isSelectable ? Icons.location_city : Icons.location_city_outlined,
      ),
      title: Text(city.name),
      subtitle: Text(
        <String>[
          if (stateName != null && stateName!.isNotEmpty) stateName!,
          if (!city.isSelectable) strings.cityNotActiveYet,
        ].join(' · '),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : (city.isSelectable
              ? const Icon(Icons.chevron_right)
              : AppBadgeInline.neutral(label: strings.comingSoon)),
    );
  }
}
