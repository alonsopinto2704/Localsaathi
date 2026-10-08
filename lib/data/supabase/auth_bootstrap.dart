import 'package:flutter/foundation.dart';

import '../../domain/repositories/auth_repository.dart';
import '../local/key_value_store.dart';
import 'auth_config.dart';
import 'auth_selection.dart';
import 'data_gateway.dart';
import 'otp_cooldown.dart';
import 'supabase_auth_gateway.dart';
import 'supabase_provider_auth_repository.dart';

/// What a live (staging/production) build runs on: one started backend client
/// shared by the identity repository and the data repositories.
class LiveBackend {
  const LiveBackend({required this.data, required this.auth});

  final DataGateway data;
  final ProviderAuthRepository auth;
}

/// Starts the Supabase client for a non-demo build (phases 041, 061).
///
/// Returns null when the configuration is unusable or the SDK fails to start.
/// The caller must then show the blocked state; there is no fallback to the
/// simulation or to fictional data. Only the error type is logged: a message
/// could carry the URL or key.
Future<LiveBackend?> startLiveBackend(
  AuthConfig config,
  KeyValueStore store,
) async {
  if (config.isDemo || !config.hasLiveConfig) return null;
  try {
    final SupabaseAuthGateway gateway =
        SupabaseAuthGateway(await initializeSupabase(config));
    return LiveBackend(
      data: gateway,
      auth: selectAuthRepository(
        config: config,
        demo: () => throw StateError('demo auth is never built for ${config.environment.name}'),
        live: () => SupabaseProviderAuthRepository(
          gateway: gateway,
          cooldown: OtpCooldown(store: store),
        ),
      ),
    );
  } on Object catch (error) {
    debugPrint('LocalSaathi: Supabase start-up failed (${error.runtimeType})');
    return null;
  }
}
