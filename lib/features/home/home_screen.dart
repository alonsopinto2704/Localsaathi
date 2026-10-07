import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/location_controller.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_card.dart';
import '../../core/widgets/responsive_grid.dart';
import '../../core/widgets/reveal.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import '../../domain/repositories/provider_repository.dart';
import '../legal/legal_screen.dart';
import '../location/location_sheets.dart';

/// Home.
///
/// The whole screen is driven by the selected location and by data: there is no
/// city name in this file, and the provider list comes from a query built from
/// the customer's locality. Activating another market changes this screen's
/// contents without a single edit here.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload whenever the customer changes locality. Reading (not watching)
    // here avoids a redundant rebuild; the build method already watches.
    final LocationSelection? selection =
        context.read<LocationController>().selection;
    if (_lastSelection != selection) {
      _lastSelection = selection;
      if (selection != null) {
        setState(() { _future = _load(); });
      }
    }
  }

  LocationSelection? _lastSelection;

  Future<_HomeData> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final LocationSelection? selection =
        context.read<LocationController>().selection;
    if (selection == null) {
      return const _HomeData.empty();
    }

    final List<ServiceCategory> popular =
        await dependencies.catalog.popularCategories();
    final ProviderSearchResults results =
        await dependencies.providers.search(
      ProviderQuery(
        cityId: selection.cityId,
        localityId: selection.localityId,
        limit: 10,
      ),
    );

    final List<_ResolvedProvider> resolved =
        await _resolve(results.items, dependencies);
    final int totalInLocality =
        (await dependencies.providers.providerCountByLocality(selection.cityId))[
                selection.localityId] ??
            results.totalCount;

    return _HomeData(
      popular: popular.take(8).toList(),
      sponsored: resolved.where((_ResolvedProvider r) => r.isSponsored).toList(),
      organic: resolved.where((_ResolvedProvider r) => !r.isSponsored).toList(),
      totalInLocality: totalInLocality,
      isSampleData: results.isSampleData,
    );
  }

  Future<List<_ResolvedProvider>> _resolve(
    List<ProviderResultItem> items,
    AppDependencies dependencies,
  ) async {
    final List<_ResolvedProvider> resolved = <_ResolvedProvider>[];
    for (final ProviderResultItem item in items) {
      final ProviderProfile provider = item.provider;
      final ServiceCategory? category = provider.categoryIds.isEmpty
          ? null
          : await dependencies.catalog.categoryById(provider.categoryIds.first);
      final Locality? locality =
          await dependencies.locations.localityById(provider.baseLocalityId);
      final City? city =
          await dependencies.locations.cityById(provider.baseCityId);
      resolved.add(
        _ResolvedProvider(
          provider: provider,
          categoryName: category?.name ?? '',
          localityName: locality?.name ?? '',
          cityName: city?.name,
          isSponsored: item.isSponsored,
        ),
      );
    }
    return resolved;
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  Future<void> _changeLocality() async {
    final LocationController controller = context.read<LocationController>();
    final LocationSelection? selection = controller.selection;
    if (selection == null) return;
    final Locality? chosen = await showLocalityPickerSheet(
      context,
      cityId: selection.cityId,
      selectedId: selection.localityId,
    );
    if (chosen == null) return;
    await controller.select(cityId: selection.cityId, localityId: chosen.id);
  }

  void _openCategoriesTab() {
    // The shell owns the tab index; a callback keeps the home screen from
    // knowing about the shell's internals.
    context
        .findAncestorStateOfType<HomeShellController<StatefulWidget>>()
        ?.selectTab(1);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final LocationController location = context.watch<LocationController>();
    final SessionController session = context.watch<SessionController>();
    final LocationSelection? selection = location.selection;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_HomeData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: strings.somethingWentWrong,
              onRetry: _refresh,
            );
          }
          final _HomeData data = snapshot.data ?? const _HomeData.empty();

          // The blueprint places the paid card after the first two organic
          // results. It stays labelled "Sponsored · Promoted by the provider",
          // and organic results are never dropped to make room for it.
          final List<_FeedItem> feed = <_FeedItem>[
            for (final _ResolvedProvider p in data.organic.take(2))
              _FeedItem(p, sponsored: false),
            for (final _ResolvedProvider p in data.sponsored)
              _FeedItem(p, sponsored: true),
            for (final _ResolvedProvider p in data.organic.skip(2))
              _FeedItem(p, sponsored: false),
          ];

          // Entrance order follows reading order; the whole page is built in
          // one go (at most ten providers), so each block reveals only once.
          int reveal = 0;

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= AppSpacing.wideBreakpoint;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.huge,
                ),
                children: <Widget>[
                  Reveal(
                    index: reveal++,
                    child: _AreaBar(
                      selection: selection,
                      onTap: _changeLocality,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Reveal(
                    index: reveal++,
                    child: _SearchBar(
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.search),
                    ),
                  ),
                  if (data.isSampleData) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    AppBanner.sampleData(message: strings.sampleStatsNotice),
                  ],
                  if (data.popular.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.section),
                    Reveal(
                      index: reveal++,
                      child: _CategoryGrid(
                        categories: data.popular,
                        columns: wide ? 8 : 4,
                        onViewAll: _openCategoriesTab,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  Reveal(
                    index: reveal++,
                    child: SectionHeader(
                      icon: Icons.verified_user_outlined,
                      title: strings.providersInLocality(
                        selection?.localityName ?? strings.chooseLocality,
                      ),
                      subtitle: strings.verifiedAndActive,
                      actionLabel: strings.seeAll,
                      onAction: () =>
                          Navigator.of(context).pushNamed(AppRoutes.search),
                    ),
                  ),
                  if (feed.isEmpty)
                    AppEmptyState(
                      title: strings.noProvidersInAreaTitle,
                      body: strings.noProvidersInAreaBody,
                      icon: Icons.location_searching,
                      compact: true,
                      actionLabel: strings.changeLocation,
                      onAction: () => Navigator.of(context)
                          .pushNamed(AppRoutes.locationPicker),
                    )
                  else
                    ResponsiveGrid(
                      columns: wide ? 2 : 1,
                      children: <Widget>[
                        for (final _FeedItem item in feed)
                          Reveal(
                            index: reveal++,
                            child: _card(
                              context,
                              item.provider,
                              selection,
                              isSponsored: item.sponsored,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.section),
                  ResponsiveGrid(
                    columns: wide ? 2 : 1,
                    children: <Widget>[
                      _OfferServiceCard(
                        hasProfile: session.hasProfile,
                        onTap: () => Navigator.of(context).pushNamed(
                          session.hasProfile
                              ? AppRoutes.providerDashboard
                              : AppRoutes.providerOnboarding,
                        ),
                      ),
                      _InviteCard(
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.inviteProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  const LegalLinks(center: true),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _card(
    BuildContext context,
    _ResolvedProvider item,
    LocationSelection? selection, {
    bool isSponsored = false,
  }) {
    return ProviderCard(
      provider: item.provider,
      categoryName: item.categoryName,
      localityName: item.localityName,
      cityName: item.cityName,
      isSponsored: isSponsored,
      showServesYourArea: selection != null &&
          item.provider.baseLocalityId != selection.localityId,
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.providerProfile,
        arguments: item.provider.id,
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem(this.provider, {required this.sponsored});

  final _ResolvedProvider provider;
  final bool sponsored;
}

class _HomeData {
  const _HomeData({
    required this.popular,
    required this.sponsored,
    required this.organic,
    required this.totalInLocality,
    required this.isSampleData,
  });

  const _HomeData.empty()
      : popular = const <ServiceCategory>[],
        sponsored = const <_ResolvedProvider>[],
        organic = const <_ResolvedProvider>[],
        totalInLocality = 0,
        isSampleData = false;

  final List<ServiceCategory> popular;
  final List<_ResolvedProvider> sponsored;
  final List<_ResolvedProvider> organic;
  final int totalInLocality;
  final bool isSampleData;
}

class _ResolvedProvider {
  const _ResolvedProvider({
    required this.provider,
    required this.categoryName,
    required this.localityName,
    required this.cityName,
    required this.isSponsored,
  });

  final ProviderProfile provider;
  final String categoryName;
  final String localityName;
  final String? cityName;
  final bool isSponsored;
}

/// "Serving area" selector with the live-market pill.
class _AreaBar extends StatelessWidget {
  const _AreaBar({required this.selection, required this.onTap});

  final LocationSelection? selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationSelection? s = selection;
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.servingArea.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                s == null
                                    ? strings.chooseLocality
                                    : '${s.localityName}, ${s.cityName}',
                                style: theme.textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (s != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          const _LivePill(),
        ],
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            context.strings.liveArea,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppSurfaceCard(
      onTap: onTap,
      radius: AppSpacing.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + AppSpacing.xxs,
        vertical: AppSpacing.md + AppSpacing.xxs,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search, color: theme.colorScheme.outline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.strings.searchHint,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// "What do you need help with?" and its grid of popular services.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.columns,
    required this.onViewAll,
  });

  final List<ServiceCategory> categories;
  final int columns;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // Tile height = padding + icon well + gap + two lines of label, scaled with
    // the reader's text size so large system fonts never clip the label.
    final double line = MediaQuery.textScalerOf(context).scale(13) * 1.3;
    final double tileHeight = 24 + 48 + 8 + line * 2 + 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: strings.whatDoYouNeed,
          actionLabel: strings.viewAllCategories,
          onAction: onViewAll,
        ),
        GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm + AppSpacing.xxs,
            crossAxisSpacing: AppSpacing.sm + AppSpacing.xxs,
            mainAxisExtent: tileHeight,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            for (final ServiceCategory category in categories)
              CategoryTile(
                category: category,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.search,
                  arguments: SearchArgs(
                    categoryIds: <String>[category.id],
                    title: category.name,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Warm call-out inviting providers to list themselves.
class _OfferServiceCard extends StatelessWidget {
  const _OfferServiceCard({required this.hasProfile, required this.onTap});

  final bool hasProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return AppSurfaceCard(
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: 20,
                  color: theme.colorScheme.onSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.offerServiceTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      strings.offerServiceBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onTap,
            icon: Icon(
              hasProfile ? Icons.dashboard_outlined : Icons.add_circle_outline,
              size: 20,
            ),
            label: Text(
              hasProfile
                  ? strings.openProviderDashboard
                  : strings.createFreeListing,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    return AppSurfaceCard(
      color: theme.colorScheme.primaryContainer,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(Icons.person_add_alt_1_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(strings.knowHelperTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  strings.knowHelperBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: theme.colorScheme.surface,
            ),
            child: Text(strings.invite),
          ),
        ],
      ),
    );
  }
}

/// Allows the home screen to ask the shell to switch tabs without importing the
/// shell's widget tree. It is a [State] so `findAncestorStateOfType` can find it.
abstract class HomeShellController<T extends StatefulWidget> extends State<T> {
  void selectTab(int index);
}
