import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo.dart';
import '../account/account_screen.dart';
import '../categories/categories_screen.dart';
import '../saved/saved_providers_screen.dart';
import 'home_screen.dart';

/// Bottom navigation shell: Home, Categories, Saved, Account.
///
/// Each tab keeps its own state (an `IndexedStack`) so a customer who browses a
/// category and comes back does not lose their place, which matters on a slow
/// device where rebuilding a list is visible.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends HomeShellController<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  // The IndexedStack swaps tabs instantly (that is what keeps their state), so
  // the newly shown tab fades and settles in on its own: the incoming half of
  // Material's "fade through".
  late final AnimationController _tabIn = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
    value: 1,
  );
  static final Animatable<double> _fade = CurveTween(curve: AppCurves.enter);
  static final Animatable<double> _settle =
      Tween<double>(begin: 0.98, end: 1).chain(CurveTween(curve: AppCurves.enter));

  @override
  void dispose() {
    _tabIn.dispose();
    super.dispose();
  }

  @override
  void selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    if (!MediaQuery.disableAnimationsOf(context)) _tabIn.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final SessionController session = context.watch<SessionController>();
    final bool wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.wideBreakpoint;

    final List<Widget> tabs = <Widget>[
      const HomeScreen(),
      const CategoriesScreen(embedded: true),
      const SavedProvidersScreen(embedded: true),
      const AccountScreen(embedded: true),
    ];

    final List<(IconData, IconData, String)> destinations =
        <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, strings.navHome),
      (Icons.grid_view_outlined, Icons.grid_view, strings.navCategories),
      (Icons.bookmark_border, Icons.bookmark, strings.navSaved),
      (Icons.account_circle_outlined, Icons.account_circle, strings.navAccount),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.pagePadding,
        title: AppWordmark(subtitle: wide ? null : destinations[_index].$3),
        actions: <Widget>[
          // On a wide screen the app is a website: navigation sits in the
          // header like any other site instead of in a bottom bar.
          if (wide)
            for (int i = 0; i < destinations.length; i++)
              _TopNavLink(
                label: destinations[i].$3,
                selected: i == _index,
                onPressed: () => selectTab(i),
              ),
          if (session.hasProfile)
            IconButton(
              tooltip: strings.openProviderDashboard,
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRoutes.providerDashboard),
              icon: const Icon(Icons.storefront_outlined),
            )
          else if (wide)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRoutes.providerOnboarding),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                child: Text(strings.createFreeListing),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: FadeTransition(
        opacity: _tabIn.drive(_fade),
        child: ScaleTransition(
          scale: _tabIn.drive(_settle),
          child: IndexedStack(index: _index, children: tabs),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: selectTab,
                destinations: <Widget>[
                  for (final (IconData icon, IconData selected, String label)
                      in destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
            ),
    );
  }
}

class _TopNavLink extends StatelessWidget {
  const _TopNavLink({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        backgroundColor:
            selected ? theme.colorScheme.primaryContainer : null,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      child: Text(label),
    );
  }
}
