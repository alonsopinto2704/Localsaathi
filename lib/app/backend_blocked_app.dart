import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

/// Shown instead of the app when a staging/production build has no usable
/// backend configuration (phase 061). Deliberately plain and English: it is an
/// operator-facing state that real users should never see in a released build,
/// and it must work with no data, localisation or repositories loaded.
class BackendBlockedApp extends StatelessWidget {
  const BackendBlockedApp({super.key, required this.reason});

  /// Developer-facing, contains no secret values.
  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "${AppConfig.appName} can't start",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This build is missing its backend configuration, so it '
                    'will not show sample providers. Install a correctly '
                    'configured build, or ask the release owner to set '
                    'SUPABASE_URL and SUPABASE_ANON_KEY for this LS_ENV.',
                  ),
                  const SizedBox(height: 12),
                  Text('Details: $reason', key: const Key('blocked-reason')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
