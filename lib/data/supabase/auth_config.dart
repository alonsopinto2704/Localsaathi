import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Which identity backend a build talks to. Chosen once, at compile time, with
/// `--dart-define=LS_ENV=demo|staging|production`.
///
/// Only [demo] may use the simulated OTP. An unrecognised value is treated as
/// [production], so a typo fails closed instead of silently falling back to the
/// simulation.
enum AuthEnvironment {
  demo,
  staging,
  production;

  static AuthEnvironment parse(String raw) => switch (raw.trim().toLowerCase()) {
        'demo' => AuthEnvironment.demo,
        'staging' => AuthEnvironment.staging,
        _ => AuthEnvironment.production,
      };
}

/// Compile-time identity configuration (no secrets: the anon key is public by
/// design and is still validated so a service-role key can never be shipped).
class AuthConfig {
  const AuthConfig({
    required this.environment,
    this.supabaseUrl = '',
    this.anonKey = '',
    this.envUnset = false,
  });

  /// Pure form of the compile-time rule so tests can exercise it: an unset
  /// `LS_ENV` is demo in debug/profile, and a [problem] (never demo) in a
  /// release build, so a pipeline that forgets the define cannot ship the
  /// fixed-OTP demo.
  factory AuthConfig.resolve({
    required String rawEnv,
    required bool release,
    String supabaseUrl = '',
    String anonKey = '',
  }) {
    final bool unset = rawEnv.trim().isEmpty;
    return AuthConfig(
      environment: unset
          ? (release ? AuthEnvironment.production : AuthEnvironment.demo)
          : AuthEnvironment.parse(rawEnv),
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
      envUnset: unset && release,
    );
  }

  /// Reads `--dart-define` values. The default is [AuthEnvironment.demo] so
  /// `flutter run` and `flutter test` keep working with mocks (mock mode stays
  /// the default); release pipelines must pass `LS_ENV` explicitly.
  factory AuthConfig.fromEnvironment() => AuthConfig.resolve(
        rawEnv: const String.fromEnvironment('LS_ENV'),
        release: kReleaseMode,
        supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final AuthEnvironment environment;
  final String supabaseUrl;
  final String anonKey;
  final bool envUnset;

  bool get isDemo => environment == AuthEnvironment.demo;

  /// Why live auth cannot start, or null when the configuration is usable.
  /// Never includes the key or URL values.
  String? get problem {
    if (envUnset) return 'LS_ENV is not set in a release build';
    final Uri? uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return 'SUPABASE_URL is missing or not a URL';
    }
    final bool local = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            local &&
            environment != AuthEnvironment.production)) {
      return 'SUPABASE_URL must be https (http only for local non-production)';
    }
    if (anonKey.trim().isEmpty) return 'SUPABASE_ANON_KEY is missing';
    final String? role = JwtClaims.decode(anonKey)?['role'] as String?;
    // Legacy service-role JWTs and the newer sb_secret_ keys must never ship.
    if (role == 'service_role' || anonKey.trim().startsWith('sb_secret_')) {
      return 'SUPABASE_ANON_KEY is a service-role key; refusing to use it';
    }
    return null;
  }

  bool get hasLiveConfig => problem == null;
}

/// Minimal, unverified JWT payload reader. The server verifies tokens; the
/// client only reads claims it already holds (expiry, `amr`, `aal`).
class JwtClaims {
  const JwtClaims._();

  static Map<String, dynamic>? decode(String jwt) {
    final List<String> parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final String payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final Object? json = jsonDecode(payload);
      return json is Map<String, dynamic> ? json : null;
    } on Object {
      return null;
    }
  }
}
