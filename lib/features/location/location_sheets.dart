import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/location.dart';

/// Sheet that lets a user choose a city.
///
/// Active markets are listed first; coming-soon cities remain tappable so the
/// launch-availability message and the "request my city" path are reachable in
/// normal use. Only cities whose status is `inactive` are ever hidden, and that
/// is driven by data, not by a hardcoded list.
Future<City?> showCityPickerSheet(
  BuildContext context, {
  String? activeCityId,
}) {
  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _CitySheet(activeCityId: activeCityId),
  );
}

/// Sheet that lets a user choose a locality in a city.
Future<Locality?> showLocalityPickerSheet(
  BuildContext context, {
  required String cityId,
  String? selectedId,
}) {
  return showModalBottomSheet<Locality>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _LocalitySheet(
      cityId: cityId,
      selectedId: selectedId,
    ),
  );
}

/// Multi-select sheet for provider service areas.
Future<List<String>?> showLocalityMultiPickerSheet(
  BuildContext context, {
  required String cityId,
  required Set<String> selectedIds,
  String? baseLocalityId,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _LocalityMultiSheet(
      cityId: cityId,
      selectedIds: selectedIds,
      baseLocalityId: baseLocalityId,
    ),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({this.activeCityId});

  final String? activeCityId;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  List<City> _active = <City>[];
  List<City> _comingSoon = <City>[];
  bool _loading = true;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<City> cities = await dependencies.locations.availableCities();
    if (!mounted) return;
    _apply(cities, hasQuery: false);
  }

  Future<void> _search(String query) async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    if (query.trim().isEmpty) {
      await _loadAll();
      return;
    }
    final List<City> cities = await dependencies.locations.searchCities(query);
    if (!mounted) return;
    _apply(cities, hasQuery: true);
  }

  void _apply(List<City> cities, {required bool hasQuery}) {
    setState(() {
      _active = cities
          .where((City c) => c.launchStatus == CityLaunchStatus.active)
          .toList();
      _comingSoon = cities
          .where((City c) => c.launchStatus == CityLaunchStatus.comingSoon)
          .toList();
      _hasQuery = hasQuery;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(strings.chooseCity, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: strings.searchCityHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: _search,
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    if (_active.isNotEmpty) ...<Widget>[
                      _SectionLabel(label: strings.activeMarkets),
                      for (final City city in _active)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(city.name),
                          subtitle: Text(_stateNameFor(context, city)),
                          trailing: Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          onTap: () => Navigator.of(context).pop(city),
                        ),
                    ],
                    if (_comingSoon.isNotEmpty) ...<Widget>[
                      _SectionLabel(label: strings.upcomingMarkets),
                      for (final City city in _comingSoon)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(city.name),
                          subtitle: Text(strings.cityNotActiveYet),
                          trailing: const Icon(Icons.schedule, size: 18),
                          onTap: () => Navigator.of(context).pop(city),
                        ),
                    ],
                    if (_active.isEmpty && _comingSoon.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Text(
                          _hasQuery
                              ? strings.errorNotFound
                              : strings.somethingWentWrong,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _stateNameFor(BuildContext context, City city) {
    // The state name is resolved asynchronously by the picker screen when it
    // needs it; the sheet shows the metro hint instead to avoid an extra await
    // per row.
    return city.isMetro ? 'Metro city' : '';
  }
}

class _LocalitySheet extends StatefulWidget {
  const _LocalitySheet({required this.cityId, this.selectedId});

  final String cityId;
  final String? selectedId;

  @override
  State<_LocalitySheet> createState() => _LocalitySheetState();
}

class _LocalitySheetState extends State<_LocalitySheet> {
  List<Locality> _all = <Locality>[];
  List<Locality> _filtered = <Locality>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<Locality> localities =
        await dependencies.locations.localities(widget.cityId);
    if (!mounted) return;
    setState(() {
      _all = localities;
      _filtered = localities;
      _loading = false;
    });
  }

  void _filter(String query) {
    final String needle = query.trim().toLowerCase();
    setState(() {
      _filtered = needle.isEmpty
          ? _all
          : _all
              .where((Locality l) => l.name.toLowerCase().contains(needle))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.chooseLocality,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: InputDecoration(
                      hintText: strings.localityLabel,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: _filter,
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              Expanded(
                child: Center(child: Text(strings.noLocalitiesAvailable)),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Locality locality = _filtered[index];
                    final bool selected = locality.id == widget.selectedId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(locality.name),
                      subtitle: locality.pinCode == null
                          ? null
                          : Text(locality.pinCode!),
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? theme.colorScheme.primary : null,
                      ),
                      onTap: () => Navigator.of(context).pop(locality),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LocalityMultiSheet extends StatefulWidget {
  const _LocalityMultiSheet({
    required this.cityId,
    required this.selectedIds,
    this.baseLocalityId,
  });

  final String cityId;
  final Set<String> selectedIds;
  final String? baseLocalityId;

  @override
  State<_LocalityMultiSheet> createState() => _LocalityMultiSheetState();
}

class _LocalityMultiSheetState extends State<_LocalityMultiSheet> {
  late Set<String> _selected = <String>{...widget.selectedIds};
  List<Locality> _all = <Locality>[];
  List<Locality> _filtered = <Locality>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<Locality> localities =
        await dependencies.locations.localities(widget.cityId);
    if (!mounted) return;
    setState(() {
      _all = localities;
      _filtered = localities;
      _loading = false;
    });
  }

  void _filter(String query) {
    final String needle = query.trim().toLowerCase();
    setState(() {
      _filtered = needle.isEmpty
          ? _all
          : _all
              .where((Locality l) => l.name.toLowerCase().contains(needle))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.serviceAreasLabel,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.serviceAreasBody,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: InputDecoration(
                      hintText: strings.localityLabel,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: _filter,
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Locality locality = _filtered[index];
                    final bool selected = _selected.contains(locality.id);
                    final bool isBase =
                        locality.id == widget.baseLocalityId;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      title: Text(locality.name),
                      subtitle: isBase ? Text(strings.baseLocality) : null,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(locality.id);
                          } else {
                            _selected.remove(locality.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_selected.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_selected.toList()),
                        child: Text(strings.done),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
