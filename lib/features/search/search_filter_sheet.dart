import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/location.dart';
import '../../domain/models/service_category.dart';

/// Result of the filter sheet.
class SearchFilterResult {
  const SearchFilterResult({
    required this.categoryIds,
    required this.localityIds,
    required this.openNowOnly,
    required this.homeVisitsOnly,
  });

  final List<String> categoryIds;
  final List<String> localityIds;
  final bool openNowOnly;
  final bool homeVisitsOnly;
}

/// Filters: locality, service category, open now, home visits.
///
/// "Open now" can only ever be satisfied by a provider whose working hours are
/// recorded; the sheet states that so the filter's behaviour is not a surprise.
Future<SearchFilterResult?> showSearchFilterSheet(
  BuildContext context, {
  required String cityId,
  required List<String> selectedCategoryIds,
  required List<String> selectedLocalityIds,
  required bool openNowOnly,
  required bool homeVisitsOnly,
  required Map<String, String> categoryNames,
  required Map<String, String> localityNames,
}) {
  return showModalBottomSheet<SearchFilterResult>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _SearchFilterSheet(
      cityId: cityId,
      selectedCategoryIds: selectedCategoryIds,
      selectedLocalityIds: selectedLocalityIds,
      openNowOnly: openNowOnly,
      homeVisitsOnly: homeVisitsOnly,
      categoryNames: categoryNames,
      localityNames: localityNames,
    ),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({
    required this.cityId,
    required this.selectedCategoryIds,
    required this.selectedLocalityIds,
    required this.openNowOnly,
    required this.homeVisitsOnly,
    required this.categoryNames,
    required this.localityNames,
  });

  final String cityId;
  final List<String> selectedCategoryIds;
  final List<String> selectedLocalityIds;
  final bool openNowOnly;
  final bool homeVisitsOnly;
  final Map<String, String> categoryNames;
  final Map<String, String> localityNames;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late Set<String> _categories = <String>{...widget.selectedCategoryIds};
  late Set<String> _localities = <String>{...widget.selectedLocalityIds};
  late bool _openNow = widget.openNowOnly;
  late bool _homeVisits = widget.homeVisitsOnly;

  List<ServiceCategory> _allCategories = <ServiceCategory>[];
  List<Locality> _allLocalities = <Locality>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<ServiceCategory> categories =
        await dependencies.catalog.categories();
    final List<Locality> localities =
        await dependencies.locations.localities(widget.cityId);
    if (!mounted) return;
    setState(() {
      _allCategories = categories;
      _allLocalities = localities;
      _loading = false;
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
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(strings.filters, style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _categories = <String>{};
                      _localities = <String>{};
                      _openNow = false;
                      _homeVisits = false;
                    }),
                    child: Text(strings.reset),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _openNow,
                      onChanged: (bool value) =>
                          setState(() => _openNow = value),
                      title: Text(strings.filterOpenNow),
                      subtitle: Text(strings.openNowFilterNote),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _homeVisits,
                      onChanged: (bool value) =>
                          setState(() => _homeVisits = value),
                      title: Text(strings.filterHomeVisits),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(strings.filterLocality, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final Locality locality in _allLocalities)
                          FilterChip(
                            label: Text(locality.name),
                            selected: _localities.contains(locality.id),
                            onSelected: (bool selected) => setState(() {
                              if (selected) {
                                _localities.add(locality.id);
                              } else {
                                _localities.remove(locality.id);
                              }
                            }),
                          ),
                      ],
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      strings.filterCategory,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final ServiceCategory category in _allCategories)
                          FilterChip(
                            label: Text(category.name),
                            selected: _categories.contains(category.id),
                            onSelected: (bool selected) => setState(() {
                              if (selected) {
                                _categories.add(category.id);
                              } else {
                                _categories.remove(category.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
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
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    SearchFilterResult(
                      categoryIds: _categories.toList(),
                      localityIds: _localities.toList(),
                      openNowOnly: _openNow,
                      homeVisitsOnly: _homeVisits,
                    ),
                  ),
                  child: Text(strings.apply),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
