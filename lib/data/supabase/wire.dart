import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../domain/models/account.dart';
import '../../domain/models/provider.dart';
import 'auth_gateway.dart';

/// Backend wire mapping shared by every live repository (phase 062).
///
/// Naming boundary: RPC arguments (`p_city_id`), table names and `selectRows`
/// rows are snake_case; RPC JSON results (`baseCityId`, `isSponsored`) are
/// camelCase; enum labels are snake_case (`coming_soon`). Everything here is
/// strict about shape and conservative about meaning: a malformed payload is a
/// [RepositoryErrorCode.unavailable] error (never a guessed object), and an
/// unknown enum label can never read as active, published or verified.

RepositoryException malformed([String? why]) =>
    RepositoryException(RepositoryErrorCode.unavailable, why ?? 'malformed response');

Map<String, dynamic> asMap(Object? raw) =>
    raw is Map<String, dynamic> ? raw : throw malformed('expected an object');

List<Map<String, dynamic>> asRows(Object? raw) => raw is List
    ? <Map<String, dynamic>>[
        for (final Object? row in raw) asMap(row),
      ]
    : throw malformed('expected a list');

/// Non-empty string, or a malformed-response error.
String reqString(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is String && v.trim().isNotEmpty ? v : throw malformed('missing $key');
}

/// Absent, null, blank or non-string all read as "not provided".
String? optString(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is String && v.trim().isNotEmpty ? v : null;
}

bool boolOr(Map<String, dynamic> m, String key, bool fallback) =>
    m[key] is bool ? m[key] as bool : fallback;

int intOr(Map<String, dynamic> m, String key, int fallback) =>
    m[key] is num ? (m[key] as num).toInt() : fallback;

DateTime reqTime(Map<String, dynamic> m, String key) =>
    DateTime.tryParse(m[key] is String ? m[key] as String : '') ??
    (throw malformed('bad $key'));

List<String> stringList(Map<String, dynamic> m, String key) =>
    m[key] is List ? (m[key] as List<dynamic>).whereType<String>().toList() : <String>[];

/// Matches a wire label (`coming_soon`) to an enum by name, ignoring case and
/// underscores. [fallback] is returned for anything unrecognised; callers pass
/// the most restrictive value.
T enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    final String wanted = raw.replaceAll('_', '').toLowerCase();
    for (final T v in values) {
      if (v.name.toLowerCase() == wanted) return v;
    }
  }
  return fallback;
}

/// Maps a profile payload (public or owner shape) to the domain model.
///
/// * live data is never a demo profile (contact actions stay real);
/// * a phone that is missing or not E.164 clears display/WhatsApp consent, so
///   no Call button can appear for it;
/// * an unknown availability reads as `unavailable`, an unknown status as
///   `draft` (not visible), unknown verification entries are dropped;
/// * negative or non-numeric prices are dropped;
/// * missing id/timestamps or wrongly typed fields reject the whole payload.
ProviderProfile profileFromWire(Object? raw) {
  final Map<String, dynamic> m = Map<String, dynamic>.of(asMap(raw));
  reqString(m, 'id');
  reqTime(m, 'createdAt');
  reqTime(m, 'updatedAt');
  m['isDemoProfile'] = false;
  final Object? phone = m['phoneE164'];
  if (phone is! String || !_e164.hasMatch(phone)) {
    m['phoneE164'] = '';
    m['phoneDisplayConsented'] = false;
    m['whatsappEnabled'] = false;
  }
  if (m['availability'] != null) {
    m['availability'] = enumOr(AvailabilityStatus.values, m['availability'],
            AvailabilityStatus.unavailable,)
        .name;
  }
  if (m['startingPrices'] is List) {
    m['startingPrices'] = (m['startingPrices'] as List<dynamic>)
        .where((Object? p) =>
            p is Map && p['amount'] is num && (p['amount'] as num) >= 0,)
        .toList();
  }
  try {
    return ProviderProfile.fromJson(m);
  } on TypeError {
    throw malformed('bad profile');
  } on FormatException {
    throw malformed('bad profile');
  }
}

final RegExp _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');

/// Stable error prefixes (backend-contract.md section 11) -> domain errors.
RepositoryException repositoryErrorForRpc(GatewayRpcException error) =>
    switch (error.prefix) {
      'not_authenticated' =>
        const RepositoryException(RepositoryErrorCode.notAuthenticated),
      'reauth_required' =>
        const RepositoryException(RepositoryErrorCode.reauthRequired),
      'not_owner' => const RepositoryException(RepositoryErrorCode.notOwner),
      'not_found' => const RepositoryException(RepositoryErrorCode.notFound),
      'validation_failed' =>
        const RepositoryException(RepositoryErrorCode.validationFailed),
      'conflict' => const RepositoryException(RepositoryErrorCode.conflict),
      'location_not_active' =>
        const RepositoryException(RepositoryErrorCode.locationNotActive),
      'listing_not_publishable' =>
        const RepositoryException(RepositoryErrorCode.listingNotPublishable),
      'category_not_allowed' =>
        const RepositoryException(RepositoryErrorCode.categoryNotAllowed),
      'suspended' => const RepositoryException(RepositoryErrorCode.suspended),
      'rate_limited' =>
        const RepositoryException(RepositoryErrorCode.rateLimited),
      'feature_disabled' =>
        const RepositoryException(RepositoryErrorCode.featureDisabled),
      'consent_required' =>
        const RepositoryException(RepositoryErrorCode.consentRequired),
      _ => const RepositoryException(RepositoryErrorCode.unavailable),
    };

RepositoryException repositoryErrorForGateway(GatewayException error) =>
    switch (error.kind) {
      GatewayErrorKind.sessionRevoked =>
        const RepositoryException(RepositoryErrorCode.notAuthenticated),
      GatewayErrorKind.reauthRequired =>
        const RepositoryException(RepositoryErrorCode.reauthRequired),
      GatewayErrorKind.forbidden =>
        const RepositoryException(RepositoryErrorCode.notOwner),
      GatewayErrorKind.phoneConflict =>
        const RepositoryException(RepositoryErrorCode.conflict),
      GatewayErrorKind.rateLimited =>
        const RepositoryException(RepositoryErrorCode.rateLimited),
      GatewayErrorKind.transient => const TransientException(),
      _ => const RepositoryException(RepositoryErrorCode.unavailable),
    };

/// No answer from the backend (offline, 5xx, deadline): the outcome is unknown.
/// Distinct from other `unavailable` errors so the UI can say "you appear to be
/// offline" and so only these are ever retried (phase 077).
class TransientException extends RepositoryException {
  const TransientException()
      : super(RepositoryErrorCode.unavailable, 'network');
}

/// One deadline for every backend call, so nothing spins forever (phase 077).
const Duration backendDeadline = Duration(seconds: 15);

/// Runs a gateway call and rethrows only [RepositoryException]s, so nothing
/// above the data layer ever sees gateway types, bodies or tokens.
Future<T> guarded<T>(Future<T> Function() op) async {
  try {
    return await op().timeout(backendDeadline);
  } on RepositoryException {
    rethrow;
  } on GatewayRpcException catch (error) {
    throw repositoryErrorForRpc(error);
  } on GatewayException catch (error) {
    throw repositoryErrorForGateway(error);
  } on TimeoutException {
    throw const TransientException();
  } on Object {
    throw const RepositoryException(RepositoryErrorCode.unavailable);
  }
}

@visibleForTesting
Duration retryBackoff = const Duration(milliseconds: 400);

/// [guarded] plus up to [attempts] tries, only for a [TransientException] and
/// only for operations that are safe to repeat: reads, and writes the server
/// de-duplicates itself. Any other error, and the last transient one, surfaces.
Future<T> guardedRetry<T>(Future<T> Function() op, {int attempts = 3}) async {
  for (int attempt = 1;; attempt++) {
    try {
      return await guarded(op);
    } on TransientException {
      if (attempt >= attempts) rethrow;
      await Future<void>.delayed(retryBackoff * attempt);
    }
  }
}
