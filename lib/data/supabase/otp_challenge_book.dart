import 'dart:math';

import '../../domain/models/account.dart';

enum ChallengePurpose { signIn, phoneChange }

/// Bounded, in-memory bookkeeping that maps the opaque `challengeId` the UI
/// holds to the phone number a code was requested for.
///
/// Supabase's verify call takes a phone number, not a challenge, so this book
/// is the only thing that stops a stale or foreign challenge id from verifying
/// the wrong number (phase 044). Properties:
///
/// * ids are random and unguessable; they are not derived from the code;
/// * at most [maxEntries] are live, oldest evicted first;
/// * a challenge expires locally after [validity] and after [maxAttempts]
///   wrong codes (the server enforces its own limits independently);
/// * a challenge is bound to the user who was signed in when it was issued
///   (null for a signed-out sign-in); redeeming it under a different session
///   fails and discards it;
/// * it is never persisted: after process death the user simply requests a new
///   code, which the server rate-limits, so a restart cannot evade a limit;
/// * [clear] runs on sign-out and account change.
class OtpChallengeBook {
  OtpChallengeBook({
    DateTime Function()? now,
    Duration validity = const Duration(minutes: 10),
    this.maxEntries = 3,
    this.maxAttempts = 5,
    Random? random,
  })  : _now = now ?? DateTime.now,
        _validity = validity,
        _random = random ?? Random.secure();

  final DateTime Function() _now;
  final Duration _validity;
  final int maxEntries;
  final int maxAttempts;
  final Random _random;

  final Map<String, _Entry> _entries = <String, _Entry>{};

  int get length => _entries.length;

  /// Registers a challenge and returns the domain object for the UI.
  /// `simulatedCode` is empty: a live challenge never carries a code.
  OtpChallenge issue({
    required String phoneE164,
    required ChallengePurpose purpose,
    String? boundUserId,
    bool decoy = false,
  }) {
    _entries.removeWhere(
      (_, _Entry e) => e.phoneE164 == phoneE164 && e.purpose == purpose,
    );
    _evictExpired();
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    final DateTime issuedAt = _now();
    final String id = _newId();
    _entries[id] = _Entry(
      phoneE164: phoneE164,
      purpose: purpose,
      boundUserId: boundUserId,
      decoy: decoy,
      expiresAt: issuedAt.add(_validity),
    );
    return OtpChallenge(
      id: id,
      phoneE164: phoneE164,
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(_validity),
      simulatedCode: '',
    );
  }

  /// Looks up a challenge for verification. Throws [OtpException] and drops the
  /// entry when it is unknown, expired, for another purpose, or bound to a
  /// different session than [currentUserId].
  ChallengeLookup lookup({
    required String challengeId,
    required ChallengePurpose purpose,
    required String? currentUserId,
  }) {
    final _Entry? entry = _entries[challengeId];
    if (entry == null || entry.purpose != purpose) {
      throw const OtpException(OtpFailure.unknown);
    }
    if (!_now().isBefore(entry.expiresAt)) {
      _entries.remove(challengeId);
      throw const OtpException(OtpFailure.expired);
    }
    if (entry.boundUserId != currentUserId) {
      _entries.remove(challengeId);
      throw const OtpException(OtpFailure.unknown);
    }
    return ChallengeLookup(phoneE164: entry.phoneE164, decoy: entry.decoy);
  }

  /// Counts a wrong code. Throws `attemptsExceeded` (and drops the challenge)
  /// once the budget is spent; otherwise throws `invalid`.
  Never recordWrongCode(String challengeId) {
    final _Entry? entry = _entries[challengeId];
    if (entry != null) {
      entry.attempts++;
      if (entry.attempts >= maxAttempts) {
        _entries.remove(challengeId);
        throw const OtpException(OtpFailure.attemptsExceeded);
      }
    }
    throw const OtpException(OtpFailure.invalid);
  }

  /// Burns a challenge after a successful verification (replay protection).
  void consume(String challengeId) => _entries.remove(challengeId);

  void clear() => _entries.clear();

  void _evictExpired() {
    final DateTime now = _now();
    _entries.removeWhere((_, _Entry e) => !now.isBefore(e.expiresAt));
  }

  String _newId() {
    final StringBuffer b = StringBuffer('otp_');
    for (int i = 0; i < 16; i++) {
      b.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }
}

class ChallengeLookup {
  const ChallengeLookup({required this.phoneE164, required this.decoy});

  final String phoneE164;

  /// True when the server refused to send (e.g. the number belongs to another
  /// account) but the client pretended otherwise to avoid disclosing that.
  /// Verification then always fails without a network call.
  final bool decoy;
}

class _Entry {
  _Entry({
    required this.phoneE164,
    required this.purpose,
    required this.boundUserId,
    required this.decoy,
    required this.expiresAt,
  });

  final String phoneE164;
  final ChallengePurpose purpose;
  final String? boundUserId;
  final bool decoy;
  final DateTime expiresAt;
  int attempts = 0;
}
