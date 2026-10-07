import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_dependencies.dart';
import 'app/local_saathi_app.dart';
import 'core/config/app_config.dart';
import 'data/local/key_value_store.dart';

/// Entry point.
///
/// The dependency graph is built before the first frame so the app opens with a
/// resolved location instead of flashing an empty shell. Persistence failures
/// degrade to in-memory storage rather than crashing on start-up, which matters
/// on low-end devices where storage can be evicted.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicences();

  final AppDependencies dependencies = await _buildDependencies();

  runApp(LocalSaathiApp(dependencies: dependencies));
}

Future<AppDependencies> _buildDependencies() async {
  try {
    final SharedPreferencesStore store = await SharedPreferencesStore.open();
    return await AppDependencies.mock(keyValueStore: store);
  } on Object catch (error, stack) {
    // Never block the app on local storage. The user gets a working directory
    // that simply forgets between launches, which is far better than a crash.
    debugPrint(
      '${AppConfig.appName}: falling back to in-memory storage '
      '($error)\n$stack',
    );
    return AppDependencies.mock(
      keyValueStore: InMemoryKeyValueStore(),
      persist: false,
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
