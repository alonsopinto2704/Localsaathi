import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/controllers/app_settings_controller.dart';
import '../app/controllers/location_controller.dart';
import '../domain/models/moderation.dart';
import '../features/account/account_screen.dart';
import '../features/account/language_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/home/home_shell.dart';
import '../features/invite/invite_provider_screen.dart';
import '../features/legal/legal_documents.dart';
import '../features/legal/legal_screen.dart';
import '../features/location/location_picker_screen.dart';
import '../features/location/request_city_screen.dart';
import '../features/monetization/grow_business_screen.dart';
import '../features/provider/onboarding/provider_onboarding_screen.dart';
import '../features/provider/provider_dashboard_screen.dart';
import '../features/provider/provider_profile_editor_screen.dart';
import '../features/provider_profile/provider_profile_screen.dart';
import '../features/saved/saved_providers_screen.dart';
import '../features/search/search_results_screen.dart';
import '../features/welcome/welcome_screen.dart';

/// Route table.
///
/// A plain `onGenerateRoute` switch rather than a router package: the app has a
/// handful of screens and one developer, and this keeps deep links and argument
/// validation in one readable place.
class AppRoutes {
  const AppRoutes._();

  static const String root = '/';
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String categoryPicker = '/location/category-picker';
  static const String locationPicker = '/location/picker';
  static const String requestCity = '/location/request-city';
  static const String categories = '/categories';
  static const String search = '/search';
  static const String providerProfile = '/provider';
  static const String saved = '/saved';
  static const String account = '/account';
  static const String language = '/account/language';
  static const String providerOnboarding = '/provider/onboarding';
  static const String providerDashboard = '/provider/dashboard';
  static const String providerEdit = '/provider/edit';
  static const String growBusiness = '/provider/grow';
  static const String inviteProvider = '/invite';
  static const String privacy = '/legal/privacy';
  static const String terms = '/legal/terms';
  static const String guidelines = '/legal/guidelines';
  static const String grievance = '/legal/grievance';

  /// Entry point: sends first-run users to the welcome/location step and
  /// everyone else straight to home.
  static Widget rootScreen() => const _RootGate();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;

    Widget builder(BuildContext context) {
      switch (settings.name) {
        case root:
          return const _RootGate();
        case welcome:
          return const WelcomeScreen();
        case home:
          return const HomeShell();
        case locationPicker:
          return LocationPickerScreen(initialCityId: args is String ? args : null);
        case requestCity:
          return const RequestCityScreen();
        case categories:
          return const CategoriesScreen();
        case search:
          return SearchResultsScreen(initialQuery: args is SearchArgs ? args : null);
        case providerProfile:
          final String? providerId = args is String ? args : null;
          return ProviderProfileScreen(providerId: providerId ?? '');
        case saved:
          return const SavedProvidersScreen();
        case account:
          return const AccountScreen();
        case language:
          return const LanguageScreen();
        case providerOnboarding:
          return const ProviderOnboardingScreen();
        case providerDashboard:
          return const ProviderDashboardScreen();
        case providerEdit:
          return const ProviderProfileEditorScreen();
        case growBusiness:
          return const GrowBusinessScreen();
        case inviteProvider:
          return const InviteProviderScreen();
        case privacy:
          return const LegalScreen(doc: LegalDoc.privacy);
        case terms:
          return const LegalScreen(doc: LegalDoc.terms);
        case guidelines:
          return const LegalScreen(doc: LegalDoc.guidelines);
        case grievance:
          return const LegalScreen(doc: LegalDoc.grievance);
        default:
          return const _UnknownRouteScreen();
      }
    }

    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: builder,
    );
  }

  // --------------------------------------------------------------- helpers
  /// Opens the provider profile for [providerId].
  static Future<void> openProvider(
    BuildContext context,
    String providerId,
  ) =>
      Navigator.of(context).pushNamed(providerProfile, arguments: providerId);

  static Future<void> openLocationPicker(BuildContext context) =>
      Navigator.of(context).pushNamed(locationPicker);

  static Future<void> openSearch(BuildContext context, {String? text}) =>
      Navigator.of(context).pushNamed(
        search,
        arguments: SearchArgs(text: text ?? ''),
      );

  /// A reported listing needs the id of the provider being reported.
  static Future<void> openProviderWithReport(
    BuildContext context,
    String providerId,
    ReportReason reason,
  ) =>
      Navigator.of(context).pushNamed(
        providerProfile,
        arguments: providerId,
      );
}

/// Arguments for the search route.
class SearchArgs {
  const SearchArgs({
    this.text = '',
    this.categoryIds = const <String>[],
    this.localityFilterIds = const <String>[],
    this.openNowOnly = false,
    this.homeVisitsOnly = false,
    this.title,
  });

  final String text;
  final List<String> categoryIds;
  final List<String> localityFilterIds;
  final bool openNowOnly;
  final bool homeVisitsOnly;

  /// Optional heading override, e.g. the category name when browsing a
  /// category rather than searching.
  final String? title;
}

/// Decides between welcome and home on cold start.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final LocationController location =
        context.watch<LocationController>();
    final AppSettingsController settings =
        context.watch<AppSettingsController>();

    if (location.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // The welcome screen doubles as the location step, so it is shown until a
    // location has been chosen once. No carousel, no forced account.
    if (!settings.hasSeenWelcome || !location.hasSelection) {
      return const WelcomeScreen();
    }
    return const HomeShell();
  }
}

/// Anything unroutable lands here rather than crashing.
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'This screen is not available',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (Route<dynamic> r) => false),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
