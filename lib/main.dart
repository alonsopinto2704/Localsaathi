import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_dependencies.dart';
import 'app/backend_blocked_app.dart';
import 'app/local_saathi_app.dart';
import 'core/config/app_config.dart';
import 'data/local/key_value_store.dart';
import 'data/supabase/auth_config.dart';

/// Entry point.
///
/// The dependency graph is built before the first frame so the app opens with a
/// resolved location instead of flashing an empty shell. Persistence failures
/// degrade to in-memory storage rather than crashing on start-up, which matters
/// on low-end devices where storage can be evicted. A staging/production build
/// without a usable backend shows a blocked screen, never mock data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicences();

  runApp(await _buildApp());
}

Future<Widget> _buildApp() async {
  final AuthConfig config = AuthConfig.fromEnvironment();
  // Local preferences are separate from the backend: if storage cannot open,
  // preferences live in memory for this run, in every environment.
  KeyValueStore store;
  bool persist = true;
  try {
    store = await SharedPreferencesStore.open();
  } on Object catch (error, stack) {
    debugPrint(
      '${AppConfig.appName}: falling back to in-memory storage '
      '($error)\n$stack',
    );
    store = InMemoryKeyValueStore();
    persist = false;
  }
  try {
    return LocalSaathiApp(
      dependencies: await AppDependencies.forEnvironment(
        config: config,
        keyValueStore: store,
        persist: persist,
      ),
    );
  } on BackendBlockedException catch (blocked) {
    return BackendBlockedApp(reason: blocked.reason);
  } on Object catch (error) {
    // Demo keeps working from memory; a live build never falls back to mocks.
    if (!config.isDemo) {
      return BackendBlockedApp(reason: 'start-up failed (${error.runtimeType})');
    }
    return LocalSaathiApp(
      dependencies: await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      ),
    );
  }
}

/// Licences that Flutter cannot discover on its own (packages are listed
/// automatically): the bundled font and the map data shown on maps.
void _registerLicences() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      <String>['Plus Jakarta Sans'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['OpenStreetMap'],
      'Map data © OpenStreetMap contributors, available under the Open '
      'Database License (ODbL) 1.0: https://www.openstreetmap.org/copyright. '
      'Map tiles are provided by the OpenStreetMap Foundation and are subject '
      'to its tile usage policy.',
    );
  });
}
