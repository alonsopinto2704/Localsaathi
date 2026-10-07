import 'package:flutter/foundation.dart';

import '../../domain/repositories/auth_repository.dart';
import '../local/key_value_store.dart';
import 'auth_config.dart';
import 'auth_selection.dart';
import 'otp_cooldown.dart';
import 'supabase_auth_gateway.dart';
import 'supabase_provider_auth_repository.dart';

/// Builds the identity repository for non-demo builds (phase 041).
///
/// Returns null for a demo build, which keeps the mock graph (mock mode stays
/// the default). For staging/production it returns the live repository when the
/// configuration is usable and a [FailClosedAuthRepository] otherwise, so a
/// missing or malformed configuration, or a failed SDK start-up, can never
/// fall back to the simulated OTP. Guest browsing is unaffected either way.
Future<ProviderAuthRepository?> buildLiveAuth(
  AuthConfig config,
  KeyValueStore store,
) async {
  if (config.isDemo) return null;
  SupabaseAuthGateway? gateway;
  if (config.hasLiveConfig) {
    try {
      gateway = SupabaseAuthGateway(await initializeSupabase(config));
    } on Object catch (error) {
      // Type only: the message could carry the URL or key.
      debugPrint('LocalSaathi: Supabase start-up failed (${error.runtimeType})');
    }
  }
  return selectAuthRepository(
    config: config,
    demo: () => throw StateError('demo auth is never built for ${config.environment.name}'),
    live: () => gateway == null
        ? const FailClosedAuthRepository('Supabase failed to start')
        : SupabaseProviderAuthRepository(
            gateway: gateway,
            cooldown: OtpCooldown(store: store),
          ),
  );
}
