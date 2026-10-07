import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/saved_providers_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_card.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';

/// Saved providers.
///
/// Stored on the device, so a guest can use this with no account — which is the
/// reason it is a local repository rather than a server-side favourite. A saved
/// listing that has since been paused or deleted is dropped on read rather than
/// shown as a dead entry.
class SavedProvidersScreen extends StatefulWidget {
  const SavedProvidersScreen({super.key, this.embedded = false});

  /// True when hosted inside [HomeShell].
  final bool embedded;

  @override
  State<SavedProvidersScreen> createState() => _SavedProvidersScreenState();
}

class _SavedProvidersScreenState extends State<SavedProvidersScreen> {
  final Map<String, String> _categoryNames = <String, String>{};
  final Map<String, String> _localityNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepare();
      if (!mounted) return;
      // Refresh on entry so a provider paused elsewhere disappears from here.
      await context.read<SavedProvidersController>().refresh();
    });
  }

  Future<void> _prepare() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<ServiceCategory> categories =
        await dependencies.catalog.categories();
    final List<ProviderProfile> savedProfiles =
        context.read<SavedProvidersController>().profiles;
    final Map<String, String> localities = <String, String>{};
    for (final ProviderProfile provider in savedProfiles) {
      final dynamic locality =
          await dependencies.locations.localityById(provider.baseLocalityId);
      final String? name = locality?.name as String?;
      if (name != null) localities[provider.baseLocalityId] = name;
    }
    if (!mounted) return;
    setState(() {
      for (final ServiceCategory category in categories) {
        _categoryNames[category.id] = category.name;
      }
      _localityNames.addAll(localities);
    });
  }

  /// Resolves a locality name on demand for a provider saved after [_prepare]
  /// ran, and caches it.
  Future<String> _localityNameFor(
    AppDependencies dependencies,
    String localityId,
  ) async {
    final String? cached = _localityNames[localityId];
    if (cached != null) return cached;
    final dynamic locality = await dependencies.locations.localityById(localityId);
    final String name = (locality?.name as String?) ?? localityId;
    _localityNames[localityId] = name;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final SavedProvidersController saved =
        context.watch<SavedProvidersController>();
    final AppDependencies dependencies = context.read<AppDependencies>();

    final Widget body = saved.isLoading
        ? const AppLoadingState()
        : saved.isEmpty
            ? AppEmptyState(
                title: strings.savedEmptyTitle,
                body: strings.savedEmptyBody,
                icon: Icons.bookmark_border,
                actionLabel: strings.browseProviders,
                onAction: () => Navigator.of(context).pop(),
              )
            : RefreshIndicator(
                onRefresh: saved.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.md,
                    AppSpacing.pagePadding,
                    AppSpacing.xxxl,
                  ),
                  children: <Widget>[
                    Text(
                      strings.savedExplainer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final ProviderProfile provider in saved.profiles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: FutureBuilder<String>(
                          future: _localityNameFor(
                            dependencies,
                            provider.baseLocalityId,
                          ),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<String> snapshot,
                          ) {
                            return ProviderCard(
                              provider: provider,
                              categoryName: provider.categoryIds.isEmpty
                                  ? ''
                                  : (_categoryNames[provider.categoryIds.first] ??
                                      provider.categoryIds.first),
                              localityName: snapshot.data ?? '',
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.providerProfile,
                                arguments: provider.id,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(strings.savedTitle)),
      body: body,
    );
  }
}
