import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/location_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_card.dart';
import '../../core/widgets/responsive_grid.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';

/// Categories tab: every service group and its categories.
///
/// Purely data-driven — the taxonomy comes from the catalog repository, so a
/// new trade appears here as soon as it is added to the data. Counts are live:
/// providers serving the customer's locality, never a marketing number.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.embedded = false});

  /// True when hosted inside [HomeShell], which supplies the app bar.
  final bool embedded;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<_CatalogData> _future;
  String _query = '';

  /// Selected group filter; null is "All".
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CatalogData> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final LocationSelection? selection =
        context.read<LocationController>().selection;

    final List<CategoryWithGroup> all =
        await dependencies.catalog.categoriesWithGroup();
    List<CategoryWithGroup> items = all;
    if (_query.trim().isNotEmpty) {
      final Set<String> matches = <String>{
        for (final ServiceCategory c
            in await dependencies.catalog.searchCategories(_query))
          c.id,
      };
      items = all
          .where((CategoryWithGroup item) => matches.contains(item.category.id))
          .toList();
    }

    final Map<String, int> counts = <String, int>{};
    if (selection != null) {
      for (final ProviderProfile p
          in await dependencies.providers.publishedInCity(selection.cityId)) {
        if (!p.servesLocality(selection.localityId)) continue;
        for (final String id in p.categoryIds) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
    }
    return _CatalogData(items: items, counts: counts, hasCounts: selection != null);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    final Widget body = FutureBuilder<_CatalogData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_CatalogData> snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            message: strings.somethingWentWrong,
            onRetry: _reload,
          );
        }
        final _CatalogData? data = snapshot.data;

        // Group the rows so the list reads as a taxonomy rather than an
        // undifferentiated dump. Map preserves the catalogue's order.
        final Map<String, List<CategoryWithGroup>> byGroup =
            <String, List<CategoryWithGroup>>{};
        final List<ServiceGroup> groups = <ServiceGroup>[];
        for (final CategoryWithGroup item
            in data?.items ?? const <CategoryWithGroup>[]) {
          byGroup.putIfAbsent(item.group.id, () {
            groups.add(item.group);
            return <CategoryWithGroup>[];
          }).add(item);
        }
        final Iterable<ServiceGroup> shown = _groupId == null
            ? groups
            : groups.where((ServiceGroup g) => g.id == _groupId);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = cardColumnsFor(constraints.maxWidth);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.sm,
                AppSpacing.pagePadding,
                AppSpacing.huge,
              ),
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(
                    hintText: strings.searchByServiceNameArea,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: strings.clear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _query = '';
                              _reload();
                            },
                          ),
                  ),
                  onChanged: (String value) {
                    _query = value;
                    _reload();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (final ServiceGroup? group in <ServiceGroup?>[
                        null,
                        ...groups,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(group?.name ?? strings.all),
                            selected: _groupId == group?.id,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _groupId = group?.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == null)
                  const AppLoadingState(compact: true)
                else if (byGroup.isEmpty)
                  AppEmptyState(
                    title: strings.errorNotFound,
                    body: strings.noCategoriesMatch,
                    icon: Icons.category_outlined,
                  )
                else
                  for (final ServiceGroup group in shown) ...<Widget>[
                    _GroupHeader(
                      group: group,
                      count: byGroup[group.id]!.length,
                    ),
                    ResponsiveGrid(
                      columns: columns,
                      gap: AppSpacing.sm,
                      children: <Widget>[
                        for (final CategoryWithGroup item in byGroup[group.id]!)
                          CategoryListRow(
                            category: item.category,
                            providerCount: data!.hasCounts
                                ? data.counts[item.category.id] ?? 0
                                : null,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.search,
                              arguments: SearchArgs(
                                categoryIds: <String>[item.category.id],
                                title: item.category.name,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                AppSurfaceCard(
                  color: theme.colorScheme.secondaryContainer,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.inviteProvider),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.person_search_outlined,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              strings.cantFindWorkerTitle,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              strings.cantFindWorkerBody,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(strings.allCategoriesTitle)),
      body: body,
    );
  }
}

class _CatalogData {
  const _CatalogData({
    required this.items,
    required this.counts,
    required this.hasCounts,
  });

  final List<CategoryWithGroup> items;

  /// Providers serving the customer's locality, by category id.
  final Map<String, int> counts;
  final bool hasCounts;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});

  final ServiceGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(
            categoryIcon(group.iconKey),
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(group.name, style: theme.textTheme.titleLarge),
          ),
          Text(
            context.strings.servicesCount(count),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
