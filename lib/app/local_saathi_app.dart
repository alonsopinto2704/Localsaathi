import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../app/app_dependencies.dart';
import '../app/controllers/app_settings_controller.dart';
import '../app/controllers/location_controller.dart';
import '../app/controllers/saved_providers_controller.dart';
import '../app/controllers/session_controller.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import 'app_routes.dart';

/// Root widget.
///
/// State management is a single deliberate choice — `provider` with
/// [ChangeNotifier] controllers — rather than a stack of libraries. Four
/// app-wide controllers are created here; screen-scoped controllers (search,
/// onboarding) are created by the screens that own them.
class LocalSaathiApp extends StatelessWidget {
  const LocalSaathiApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppDependencies>.value(value: dependencies),
        ChangeNotifierProvider<AppSettingsController>(
          create: (_) => AppSettingsController(
            keyValueStore: dependencies.keyValueStore,
          )..load(),
        ),
        ChangeNotifierProvider<LocationController>(
          create: (_) => LocationController(
            locations: dependencies.locations,
            keyValueStore: dependencies.keyValueStore,
          )..load(),
        ),
        ChangeNotifierProvider<SavedProvidersController>(
          create: (_) => SavedProvidersController(
            repository: dependencies.savedProviders,
          )..load(),
        ),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            auth: dependencies.auth,
            providers: dependencies.providers,
            consents: dependencies.consents,
          )..restore(),
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (BuildContext context, AppSettingsController settings, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: settings.locale,
            supportedLocales: settings.supportedLocales,
            localizationsDelegates: settings.localizationsDelegates,
            // A missing translation falls back to the reference locale instead
            // of failing, which a partially translated language relies on.
            localeResolutionCallback: (Locale? locale, Iterable<Locale> supported) {
              if (locale == null) return const Locale('en');
              for (final Locale candidate in supported) {
                if (candidate.languageCode == locale.languageCode) {
                  return candidate;
                }
              }
              return const Locale('en');
            },
            initialRoute: AppRoutes.root,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            // In a desktop browser the app reads like a website: one centred,
            // readable column rather than a phone layout stretched edge to edge.
            builder: (BuildContext context, Widget? child) => ColoredBox(
              color: AppColors.background,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
