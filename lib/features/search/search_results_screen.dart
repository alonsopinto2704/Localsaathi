import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/location_controller.dart';
import '../../app/controllers/provider_search_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_card.dart';
import '../../core/widgets/provider_map.dart';
import '../../core/widgets/responsive_grid.dart';
import '../../data/seed/locality_coordinates.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import '../../domain/repositories/provider_repository.dart';
import 'search_filter_sheet.dart';

/// Search and category results.
///
/// One screen serves three entry points — the home search bar, a category tile
/// and a locality filter — because they differ only in the initial query. The
/// location is always part of that query, so results are always providers who
/// actually serve the customer's selected locality.
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, this.initialQuery});

  final SearchArgs? initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late ProviderSearchController _controller;
  final TextEditingController _textController = TextEditingController();

  List<String> _categoryIds = <String>[];
  List<String> _localityFilterIds = <String>[];
  bool _openNowOnly = false;
  bool _homeVisitsOnly = false;

  /// Resolved display names, cached so the list does not await per row.
  final Map<String, String> _categoryNames = <String, String>{};
  final Map<String, String> _localityNames = <String, String>{};
  String? _titleOverride;

  /// Results as a map of providers who chose to show their location.
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    final SearchArgs? args = widget.initialQuery;
    _textController.text = args?.text ?? '';
    _categoryIds = <String>[...?args?.categoryIds];
    _localityFilterIds = <String>[...?args?.localityFilterIds];
    _openNowOnly = args?.openNowOnly ?? false;
    _homeVisitsOnly = args?.homeVisitsOnly ?? false;
    _titleOverride = args?.title;

    _controller = ProviderSearchController(
      repository: context.read<AppDependencies>().providers,
      engagement: context.read<AppDependencies>().engagement,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch({String? text}) async {
    final LocationSelection? selection =
        context.read<LocationController>().selection;
    if (selection == null) return;

    await _prepareNames();
    if (!mounted) return;
    // The filter chips sit outside the results builder; redraw them now that
    // category and locality names are known.
    setState(() {});

    await _controller.search(
      ProviderQuery(
        cityId: selection.cityId,
        localityId: selection.localityId,
        text: text ?? _textController.text,
        categoryIds: _categoryIds,
        localityFilterIds: _localityFilterIds,
        openNowOnly: _openNowOnly,
        homeVisitsOnly: _homeVisitsOnly,
      ),
    );
  }

  /// Resolves the display names for the categories and localities that can
  /// appear in the results, once per screen.
  Future<void> _prepareNames() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final LocationSelection? selection =
        context.read<LocationController>().selection;
    if (selection == null) return;

    final List<Locality> localities =
        await dependencies.locations.localities(selection.cityId);
    for (final Locality locality in localities) {
      _localityNames[locality.id] = locality.name;
    }
    final List<ServiceCategory> categories =
        await dependencies.catalog.categories();
    for (final ServiceCategory category in categories) {
      _categoryNames[category.id] = category.name;
    }
  }

  String _categoryNameFor(ProviderProfile provider) {
    if (provider.categoryIds.isEmpty) return '';
    final String first = provider.categoryIds.first;
    final String name = _categoryNames[first] ?? first;
    final int extra = provider.categoryIds.length - 1;
    return extra > 0 ? '$name +$extra' : name;
  }

  String _localityNameFor(ProviderProfile provider) =>
      _localityNames[provider.baseLocalityId] ?? '';

  Future<void> _openFilters() async {
    final LocationSelection? selection =
        context.read<LocationController>().selection;
    if (selection == null) return;

    final SearchFilterResult? result = await showSearchFilterSheet(
      context,
      cityId: selection.cityId,
      selectedCategoryIds: _categoryIds,
      selectedLocalityIds: _localityFilterIds,
      openNowOnly: _openNowOnly,
      homeVisitsOnly: _homeVisitsOnly,
      categoryNames: _categoryNames,
      localityNames: _localityNames,
    );
    if (result == null || !mounted) return;

    setState(() {
      _categoryIds = result.categoryIds;
      _localityFilterIds = result.localityIds;
      _openNowOnly = result.openNowOnly;
      _homeVisitsOnly = result.homeVisitsOnly;
    });
    await _runSearch();
  }

  bool get _hasFilters =>
      _categoryIds.isNotEmpty ||
      _localityFilterIds.isNotEmpty ||
      _openNowOnly ||
      _homeVisitsOnly;

  int get _filterCount =>
      _categoryIds.length +
      _localityFilterIds.length +
      (_openNowOnly ? 1 : 0) +
      (_homeVisitsOnly ? 1 : 0);

  Future<void> _clearFilters() async {
    setState(() {
      _categoryIds = <String>[];
      _localityFilterIds = <String>[];
      _openNowOnly = false;
      _homeVisitsOnly = false;
    });
    await _runSearch();
  }

  /// Removes one filter and re-runs the search.
  Future<void> _drop(VoidCallback change) async {
    setState(change);
    await _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationSelection? selection =
        context.watch<LocationController>().selection;

    Widget chip(String label, VoidCallback onDeleted) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InputChip(
            label: Text(label),
            onDeleted: () => _drop(onDeleted),
            deleteIconColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primaryContainer,
            side: BorderSide.none,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleOverride ?? strings.searchResults),
        actions: <Widget>[
          IconButton(
            tooltip: _showMap ? strings.showList : strings.showMap,
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.view_agenda_outlined : Icons.map_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.xs,
              AppSpacing.pagePadding,
              AppSpacing.sm,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: strings.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: strings.clear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _textController.clear();
                              _runSearch(text: '');
                            },
                          ),
                  ),
                  onSubmitted: (String value) => _runSearch(text: value),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilledButton.icon(
                          onPressed: _openFilters,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            _filterCount == 0
                                ? strings.filters
                                : '${strings.filters} · $_filterCount',
                          ),
                        ),
                      ),
                      for (final String id in _categoryIds)
                        chip(
                          _categoryNames[id] ?? id,
                          () => _categoryIds = <String>[..._categoryIds]
                            ..remove(id),
                        ),
                      for (final String id in _localityFilterIds)
                        chip(
                          _localityNames[id] ?? id,
                          () => _localityFilterIds =
                              <String>[..._localityFilterIds]..remove(id),
                        ),
                      if (_openNowOnly)
                        chip(strings.openNow, () => _openNowOnly = false),
                      if (_homeVisitsOnly)
                        chip(
                          strings.homeVisitsAvailable,
                          () => _homeVisitsOnly = false,
                        ),
                      if (_filterCount > 1)
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(strings.clearFilters),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) {
                if (_controller.isLoading) {
                  return const AppLoadingState();
                }
                if (_controller.hasError) {
                  return AppErrorState(
                    message: strings.somethingWentWrong,
                    onRetry: _runSearch,
                  );
                }
                if (_controller.isEmpty) {
                  return AppEmptyState(
                    title: _hasFilters
                        ? strings.noProvidersForFilters
                        : strings.searchEmptyTitle,
                    body: _hasFilters
                        ? strings.noProvidersInAreaBody
                        : strings.searchEmptyBody,
                    icon: Icons.search_off,
                    actionLabel: _hasFilters ? strings.clearFilters : null,
                    onAction: _hasFilters ? _clearFilters : null,
                  );
                }

                // Paid placements first, each labelled on the card; organic
                // results are never removed to make room for them.
                final List<ProviderResultItem> items = <ProviderResultItem>[
                  ..._controller.items.where((i) => i.isSponsored),
                  ..._controller.items.where((i) => !i.isSponsored),
                ];

                if (_showMap && selection != null) {
                  return ProvidersMapView(
                    totalResults: items.length,
                    fallbackCentre: centreFor(
                      localityId: selection.localityId,
                      cityId: selection.cityId,
                    ),
                    listings: <MapListing>[
                      for (final ProviderResultItem item in items)
                        MapListing(
                          provider: item.provider,
                          subtitle:
                              '${_categoryNameFor(item.provider)} · ${_localityNameFor(item.provider)}',
                          onOpen: () => _openProvider(item.provider.id),
                        ),
                    ],
                  );
                }

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.md,
                        AppSpacing.pagePadding,
                        AppSpacing.huge,
                      ),
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                selection == null
                                    ? '${_controller.totalCount} ${strings.resultsCount}'
                                    : strings.resultsServing(
                                        _controller.totalCount,
                                        selection.localityName,
                                      ),
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              strings.verifiedAndActive,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ResponsiveGrid(
                          columns: cardColumnsFor(constraints.maxWidth),
                          children: <Widget>[
                            for (final ProviderResultItem item in items)
                              ProviderCard(
                                provider: item.provider,
                                categoryName: _categoryNameFor(item.provider),
                                localityName: _localityNameFor(item.provider),
                                isSponsored: item.isSponsored,
                                showServesYourArea: selection != null &&
                                    item.provider.baseLocalityId !=
                                        selection.localityId,
                                onTap: () => _openProvider(item.provider.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.section),
                        AppSurfaceCard(
                          color: theme.colorScheme.primaryContainer,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: <Widget>[
                              Icon(
                                Icons.handshake_outlined,
                                size: 32,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                strings.cantFindRegularTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                strings.cantFindRegularBody,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.inviteProvider),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface,
                                  minimumSize: const Size(0, 48),
                                ),
                                icon: const Icon(Icons.person_add_alt_1_outlined),
                                label: Text(strings.inviteServiceProvider),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProvider(String providerId) async {
    await _controller.recordProfileView(providerId);
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.providerProfile,
      arguments: providerId,
    );
  }
}
