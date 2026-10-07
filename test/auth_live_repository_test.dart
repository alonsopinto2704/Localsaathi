import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/controllers/session_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/data/supabase/auth_gateway.dart';
import 'package:localsaathi/data/supabase/otp_challenge_book.dart';
import 'package:localsaathi/data/supabase/otp_cooldown.dart';
import 'package:localsaathi/data/supabase/session_refresher.dart';
import 'package:localsaathi/data/supabase/supabase_provider_auth_repository.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/models/provider.dart';
import 'package:localsaathi/domain/repositories/auth_repository.dart';

import 'support/fake_auth_gateway.dart';

// Phases 041, 044-046, 048, 050-052, 057, 059: the live repository against a
// fake that behaves like GoTrue/PostgREST. All numbers are synthetic
// (+91900000xxxx). Codes are fetched from the fake and never printed.

const String kA = '+919000040001';
const String kB = '+919000040002';
const String kC = '+919000040003';

Map<String, dynamic> _profileJson({String id = 'prov-1', String? phone}) {
  final Map<String, dynamic> body = (jsonDecode(
    File('docs/contracts/fixtures/registration.json').readAsStringSync(),
  ) as Map<String, dynamic>)['success']['response']['body'] as Map<String, dynamic>;
  return <String, dynamic>{
    ...body,
    'id': id,
    if (phone != null) 'phoneE164': phone,
  };
}

class Harness {
  Harness() {
    gateway = FakeAuthGateway(now: () => now);
    kv = InMemoryKeyValueStore();
    cooldown = OtpCooldown(store: kv, now: () => now);
    refresher = SessionRefresher(
      gateway: gateway,
      now: () => now,
      sleep: (Duration d) async => sleeps.add(d),
      onRevoked: () => revoked++,
    );
    repo = SupabaseProviderAuthRepository(
      gateway: gateway,
      cooldown: cooldown,
      refresher: refresher,
      book: OtpChallengeBook(now: () => now),
      now: () => now,
    );
  }

  DateTime now = DateTime.utc(2026, 10, 7, 9);
  late final FakeAuthGateway gateway;
  late final InMemoryKeyValueStore kv;
  late final OtpCooldown cooldown;
  late final SessionRefresher refresher;
  late final SupabaseProviderAuthRepository repo;
  final List<Duration> sleeps = <Duration>[];
  int revoked = 0;

  /// Request + verify with the right code; returns the verification result.
  Future<PhoneVerificationResult> signIn(String phone) async {
    final OtpChallengeResult r = await repo.requestOtp(phone);
    expect(r.isSuccess, isTrue);
    now = now.add(const Duration(minutes: 2)); // clear the resend cooldown
    return repo.verifyOtp(
      challengeId: r.challenge!.id,
      code: gateway.codeFor(phone),
    );
  }
}

Future<void> _expectOtp(Future<Object?> f, OtpFailure reason) async {
  try {
    await f;
    fail('expected OtpException($reason)');
  } on OtpException catch (e) {
    expect(e.reason, reason);
  }
}

void main() {
  group('041 selection of live auth behaves like the contract', () {
    test('live challenge never carries a code and verifies end to end', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp('90000 40001');
      expect(r.isSuccess, isTrue);
      expect(r.challenge!.simulatedCode, isEmpty);
      expect(r.challenge!.phoneE164, kA);
      h.now = h.now.add(const Duration(minutes: 2));
      final PhoneVerificationResult v = await h.repo.verifyOtp(
        challengeId: r.challenge!.id,
        code: h.gateway.codeFor(kA),
      );
      expect(v.phoneVerified, isTrue);
      expect(v.isNewAccount, isTrue);
      expect(v.hasExistingProfile, isFalse);
      expect(v.session.phoneE164, kA);
    });

    test('invalid input is rejected before any network call', () async {
      final Harness h = Harness();
      for (final String bad in <String>['', '123', '+1 202 555 0100', 'abc']) {
        final OtpChallengeResult r = await h.repo.requestOtp(bad);
        expect(r.isSuccess, isFalse, reason: bad);
      }
      expect(h.gateway.sendCount, 0);
    });
  });

  group('044 challenge bookkeeping', () {
    test('an expired challenge cannot verify', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      h.now = h.now.add(const Duration(minutes: 11));
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: h.gateway.codeFor(kA)),
        OtpFailure.expired,
      );
      expect(h.gateway.currentSession, isNull);
    });

    test('a challenge issued before another user signed in is not trusted', () async {
      final Harness h = Harness();
      final OtpChallengeResult mine = await h.repo.requestOtp(kA);
      h.gateway.setSessionTo(h.gateway.addUser(kB)); // someone else signs in
      await _expectOtp(
        h.repo.verifyOtp(
          challengeId: mine.challenge!.id,
          code: h.gateway.codeFor(kA),
        ),
        OtpFailure.unknown,
      );
      expect(h.gateway.currentSession!.phoneE164, kB, reason: 'session untouched');
    });

    test('unknown, wrong-purpose and cleared challenges fail', () async {
      final Harness h = Harness();
      await _expectOtp(
        h.repo.verifyOtp(challengeId: 'otp_nope', code: '123456'),
        OtpFailure.unknown,
      );
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      await h.repo.signOut(); // clears the book
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: h.gateway.codeFor(kA)),
        OtpFailure.unknown,
      );
    });

    test('the book is bounded and the code for B cannot open A', () async {
      final Harness h = Harness();
      final OtpChallengeBook book = OtpChallengeBook(now: () => h.now);
      final List<String> ids = <String>[
        for (final String p in <String>[kA, kB, kC, '+919000040004'])
          book.issue(phoneE164: p, purpose: ChallengePurpose.signIn).id,
      ];
      expect(book.length, 3);
      expect(
        () => book.lookup(
          challengeId: ids.first,
          purpose: ChallengePurpose.signIn,
          currentUserId: null,
        ),
        throwsA(isA<OtpException>()),
      );
      // A challenge for kA with the (valid) code of kB is just a wrong code.
      final OtpChallengeResult a = await h.repo.requestOtp(kA);
      h.now = h.now.add(const Duration(minutes: 2));
      final OtpChallengeResult b = await h.repo.requestOtp(kB);
      expect(b.isSuccess, isTrue);
      await _expectOtp(
        h.repo.verifyOtp(challengeId: a.challenge!.id, code: h.gateway.codeFor(kB)),
        OtpFailure.invalid,
      );
      expect(h.gateway.currentSession, isNull);
    });
  });

  group('045 verification and replay', () {
    test('wrong codes create no session and are counted; 5th ends the challenge', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      for (int i = 0; i < 4; i++) {
        await _expectOtp(
          h.repo.verifyOtp(challengeId: r.challenge!.id, code: '000000'),
          OtpFailure.invalid,
        );
      }
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: '000000'),
        OtpFailure.attemptsExceeded,
      );
      // The correct code no longer works on the discarded challenge.
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: h.gateway.codeFor(kA)),
        OtpFailure.unknown,
      );
      expect(h.gateway.currentSession, isNull);
    });

    test('a consumed code fails on replay, locally and on the server', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      final String code = h.gateway.codeFor(kA);
      await h.repo.verifyOtp(challengeId: r.challenge!.id, code: code);
      await h.repo.signOut();
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: code),
        OtpFailure.unknown,
      );
      // Even a fresh challenge cannot reuse the burned server-side code.
      h.now = h.now.add(const Duration(minutes: 2));
      final OtpChallengeResult r2 = await h.repo.requestOtp(kA);
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r2.challenge!.id, code: code),
        // gateway issued a NEW code for r2, so the old one is simply wrong
        OtpFailure.invalid,
      );
      expect(h.gateway.currentSession, isNull);
    });

    test('offline during verification is never treated as success', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      h.gateway.offline = true;
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: h.gateway.codeFor(kA)),
        OtpFailure.unknown,
      );
      expect(h.gateway.currentSession, isNull);
      h.gateway.offline = false;
      final PhoneVerificationResult v = await h.repo.verifyOtp(
        challengeId: r.challenge!.id,
        code: h.gateway.codeFor(kA),
      );
      expect(v.phoneVerified, isTrue, reason: 'challenge survived the outage');
    });

    test('pasted Devanagari digits and spaces are accepted as the code', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      final String code = h.gateway.codeFor(kA);
      const List<String> deva = <String>['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
      final String pasted =
          code.split('').map((String d) => deva[int.parse(d)]).join(' ');
      final PhoneVerificationResult v =
          await h.repo.verifyOtp(challengeId: r.challenge!.id, code: pasted);
      expect(v.phoneVerified, isTrue);
    });

    test('a code of the wrong length never reaches the server', () async {
      final Harness h = Harness();
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      await _expectOtp(
        h.repo.verifyOtp(challengeId: r.challenge!.id, code: '12345'),
        OtpFailure.invalid,
      );
      expect(h.gateway.verifyCalls, 0);
    });
  });

  group('046 resend pacing', () {
    test('rapid taps send once; a second request waits out the cooldown', () async {
      final Harness h = Harness();
      final List<OtpChallengeResult> results = await Future.wait(
        <Future<OtpChallengeResult>>[
          h.repo.requestOtp(kA),
          h.repo.requestOtp(kA),
          h.repo.requestOtp(kA),
        ],
      );
      expect(h.gateway.sendCount, 1);
      expect(results.every((OtpChallengeResult r) => r.isSuccess), isTrue);
      final OtpChallengeResult again = await h.repo.requestOtp(kA);
      expect(again.error, PhoneInputError.rateLimited);
      expect(again.retryAfter, greaterThan(Duration.zero));
      h.now = h.now.add(const Duration(seconds: 61));
      expect((await h.repo.requestOtp(kA)).isSuccess, isTrue);
      expect(h.gateway.sendCount, 2);
    });

    test('an app restart cannot reset the visible wait (state in storage)', () async {
      final Harness h = Harness();
      await h.repo.requestOtp(kA);
      // "Restart": new repository and book sharing only the key-value store.
      final SupabaseProviderAuthRepository restarted =
          SupabaseProviderAuthRepository(
        gateway: h.gateway,
        cooldown: OtpCooldown(store: h.kv, now: () => h.now),
        now: () => h.now,
      );
      final OtpChallengeResult r = await restarted.requestOtp(kA);
      expect(r.error, PhoneInputError.rateLimited);
      expect(h.gateway.sendCount, 1);
      expect(h.kv.getString('auth.otpNextAllowedAt'), isNot(contains('9000')),
          reason: 'only a timestamp is stored, never a number or code',);
    });

    test('a server rate limit stretches the wait to its retry-after', () async {
      final Harness h = Harness();
      h.gateway
        ..rateLimitSends = true
        ..rateLimitRetryAfter = const Duration(minutes: 5);
      final OtpChallengeResult r = await h.repo.requestOtp(kA);
      expect(r.error, PhoneInputError.rateLimited);
      expect(r.retryAfter, greaterThanOrEqualTo(const Duration(minutes: 5)));
      h.now = h.now.add(const Duration(minutes: 2));
      h.gateway.rateLimitSends = false;
      expect((await h.repo.requestOtp(kA)).error, PhoneInputError.rateLimited,
          reason: 'still inside the server-provided window',);
      h.now = h.now.add(const Duration(minutes: 4));
      expect((await h.repo.requestOtp(kA)).isSuccess, isTrue);
    });
  });

  group('048 enumeration resistance', () {
    test('new and existing numbers get the same unverified response', () async {
      final Harness h = Harness();
      h.gateway.addUser(kB, profile: _profileJson());
      final OtpChallengeResult fresh = await h.repo.requestOtp(kA);
      h.now = h.now.add(const Duration(minutes: 2));
      final OtpChallengeResult existing = await h.repo.requestOtp(kB);
      expect(fresh.isSuccess, isTrue);
      expect(existing.isSuccess, isTrue);
      expect(existing.error, fresh.error);
      expect(existing.challenge!.simulatedCode, fresh.challenge!.simulatedCode);
      expect(
        existing.challenge!.expiresAt.difference(existing.challenge!.issuedAt),
        fresh.challenge!.expiresAt.difference(fresh.challenge!.issuedAt),
      );
      expect(h.gateway.rpcCalls, isEmpty,
          reason: 'requesting a code reads no account or profile data',);
    });

    test('ownership is revealed only after the code is verified', () async {
      final Harness h = Harness();
      h.gateway.addUser(kB, profile: _profileJson(id: 'prov-b'));
      final PhoneVerificationResult v = await h.signIn(kB);
      expect(v.hasExistingProfile, isTrue);
      expect(v.existingProfileId, 'prov-b');
    });

    test('a suspended account is visible only after verification', () async {
      final Harness h = Harness();
      h.gateway.addUser(kB, profile: _profileJson()).suspended = true;
      final OtpChallengeResult r = await h.repo.requestOtp(kB);
      expect(r.isSuccess, isTrue);
      expect(h.gateway.rpcCalls, isEmpty);
      h.now = h.now.add(const Duration(minutes: 2));
      await h.repo.verifyOtp(
        challengeId: r.challenge!.id,
        code: h.gateway.codeFor(kB),
      );
      expect((await h.repo.currentAccount())!.isSuspended, isTrue);
    });

    test('phone-change to a number someone else owns looks like a normal send', () async {
      final Harness h = Harness();
      h.gateway.addUser(kB, profile: _profileJson(id: 'prov-b'));
      await h.signIn(kA);
      final OtpChallengeResult r = await h.repo.requestPhoneNumberChange(kB);
      expect(r.isSuccess, isTrue, reason: 'no "number taken" signal');
      // Any code fails, locally, as an ordinary wrong code.
      await _expectOtp(
        h.repo.confirmPhoneNumberChange(
          challengeId: r.challenge!.id,
          code: '123456',
        ),
        OtpFailure.invalid,
      );
      expect(h.gateway.currentSession!.phoneE164, kA);
      expect(h.gateway.usersByPhone[kB]!.profile!['id'], 'prov-b');
    });
  });

  group('050 refresh and revocation', () {
    test('concurrent protected calls share one refresh', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      h.now = h.now.add(const Duration(hours: 2)); // token expired
      h.gateway.refreshGate = Completer<void>();
      final List<Future<ProviderAccount?>> calls = <Future<ProviderAccount?>>[
        for (int i = 0; i < 8; i++) h.repo.currentAccount(),
      ];
      await Future<void>.delayed(Duration.zero);
      h.gateway.refreshGate!.complete();
      await Future.wait(calls);
      expect(h.gateway.refreshCalls, 1);
    });

    test('a revoked session cannot write and does not fall back to guest', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      h.now = h.now.add(const Duration(hours: 2));
      h.gateway.revokeNextRefresh = true;
      await expectLater(
        h.repo.currentAccount(),
        throwsA(isA<RepositoryException>().having(
          (RepositoryException e) => e.code,
          'code',
          RepositoryErrorCode.notAuthenticated,
        ),),
      );
      expect(h.revoked, 1);
      expect(h.gateway.currentSession, isNull);
      await expectLater(
        h.repo.registerProfile(
          submission: _submission(kA),
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(h.gateway.rpcCalls.where((String c) => c == 'register_profile'),
          isEmpty,);
    });

    test('transient failures retry a bounded number of times then stop', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      h.now = h.now.add(const Duration(hours: 2));
      h.gateway.offline = true;
      await expectLater(
        h.repo.currentAccount(),
        throwsA(isA<RepositoryException>().having(
          (RepositoryException e) => e.code,
          'code',
          RepositoryErrorCode.unavailable,
        ),),
      );
      expect(h.gateway.refreshCalls, 3);
      expect(h.sleeps.length, 2, reason: 'backoff between attempts, none after the last');
      // Offline recovery: the session was not discarded.
      h.gateway.offline = false;
      expect(await h.repo.currentAccount(), isNotNull);
    });

    test('signing out while a refresh is in flight discards its result', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      h.now = h.now.add(const Duration(hours: 2));
      h.gateway.refreshGate = Completer<void>();
      final Future<ProviderAccount?> pending = h.repo.currentAccount();
      await Future<void>.delayed(Duration.zero);
      await h.repo.signOut();
      h.gateway.refreshGate!.complete();
      await expectLater(pending, throwsA(isA<RepositoryException>()));
      expect(h.gateway.currentSession, isNull);
    });
  });

  group('051 owner-state restoration through the controller', () {
    Future<SessionController> controller(Harness h) async {
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      return SessionController(
        auth: h.repo,
        providers: deps.providers,
        consents: deps.consents,
        drafts: deps.drafts,
      );
    }

    test('guest when nothing is stored', () async {
      final Harness h = Harness();
      final SessionController c = await controller(h);
      await c.restore();
      expect(c.status, SessionStatus.signedOut);
    });

    test('new, published, suspended and deleted accounts route correctly', () async {
      final Harness h = Harness();
      final SessionController c = await controller(h);

      final FakeUser fresh = h.gateway.addUser(kA);
      h.gateway.setSessionTo(fresh);
      await c.restore();
      expect(c.status, SessionStatus.needsProfile);
      expect(c.profile, isNull);

      fresh.profile = _profileJson(id: 'prov-a');
      await c.restore();
      expect(c.status, SessionStatus.active);
      expect(c.profile!.id, 'prov-a');

      fresh.suspended = true;
      await c.restore();
      expect(c.status, SessionStatus.suspended);
      expect(c.isSignedIn, isTrue);

      // Deleted elsewhere: the token is still held but the user is gone.
      h.gateway.usersByPhone.remove(kA);
      await c.restore();
      expect(c.status, SessionStatus.signedOut);
      expect(c.profile, isNull);
      expect(c.account, isNull);
    });

    test("a restore never shows the previous account's profile", () async {
      final Harness h = Harness();
      final SessionController c = await controller(h);
      final FakeUser a = h.gateway.addUser(kA, profile: _profileJson(id: 'prov-a'));
      h.gateway.setSessionTo(a);
      await c.restore();
      expect(c.profile!.id, 'prov-a');
      final FakeUser b = h.gateway.addUser(kB); // switched, no profile
      h.gateway.setSessionTo(b);
      await c.restore();
      expect(c.profile, isNull);
      expect(c.status, SessionStatus.needsProfile);
    });

    test('offline start-up degrades to guest and recovers later', () async {
      final Harness h = Harness();
      final SessionController c = await controller(h);
      h.gateway.setSessionTo(h.gateway.addUser(kA));
      h.gateway.offline = true;
      await c.restore();
      expect(c.status, SessionStatus.signedOut);
      h.gateway.offline = false;
      await c.restore();
      expect(c.status, SessionStatus.needsProfile);
    });

    test('session loss keeps the draft; sign-out clears it', () async {
      final Harness h = Harness();
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      final SessionController c = SessionController(
        auth: h.repo,
        providers: deps.providers,
        consents: deps.consents,
        drafts: deps.drafts,
      );
      await deps.drafts.save(ProviderDraft(
        phoneE164: kA,
        updatedAt: h.now,
        displayName: 'Draft',
      ),);
      c.handleSessionLost();
      expect(c.sessionLost, isTrue);
      expect(c.status, SessionStatus.signedOut);
      expect(await deps.drafts.load(), isNotNull);
      await c.signOut();
      expect(await deps.drafts.load(), isNull);
    });

    test("verifying a different number drops the previous person's draft", () async {
      final Harness h = Harness();
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      final SessionController c = SessionController(
        auth: h.repo,
        providers: deps.providers,
        consents: deps.consents,
        drafts: deps.drafts,
      );
      await deps.drafts.save(ProviderDraft(
        phoneE164: kA,
        updatedAt: h.now,
        displayName: 'A draft',
      ),);
      expect(await c.requestCode(kB), isTrue);
      h.now = h.now.add(const Duration(minutes: 2));
      expect(await c.verifyCode(h.gateway.codeFor(kB)), isTrue);
      expect(await deps.drafts.load(), isNull);
      expect(c.developmentCodeHint, isNull);
    });
  });

  group('052 verified phone change', () {
    test('success moves the number; the profile stays attached', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson(id: 'prov-a'));
      await h.signIn(kA);
      final OtpChallengeResult r = await h.repo.requestPhoneNumberChange(kB);
      expect(r.isSuccess, isTrue);
      final ProviderAccount account = await h.repo.confirmPhoneNumberChange(
        challengeId: r.challenge!.id,
        code: h.gateway.codeFor(kB),
      );
      expect(account.phoneE164, kB);
      expect(account.profileId, 'prov-a');
    });

    test('a number taken between send and verify raises the duplicate error, unchanged owner', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson(id: 'prov-a'));
      await h.signIn(kA);
      final OtpChallengeResult r = await h.repo.requestPhoneNumberChange(kB);
      final String code = h.gateway.codeFor(kB);
      h.gateway.addUser(kB, profile: _profileJson(id: 'prov-b')); // race
      await expectLater(
        h.repo.confirmPhoneNumberChange(challengeId: r.challenge!.id, code: code),
        throwsA(isA<DuplicatePhoneNumberException>()),
      );
      expect(h.gateway.usersByPhone[kA]!.profile!['id'], 'prov-a');
      expect(h.gateway.usersByPhone[kB]!.profile!['id'], 'prov-b');
    });

    test('interruption (wrong codes, outage) leaves the original number', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson(id: 'prov-a'));
      await h.signIn(kA);
      final OtpChallengeResult r = await h.repo.requestPhoneNumberChange(kB);
      await _expectOtp(
        h.repo.confirmPhoneNumberChange(challengeId: r.challenge!.id, code: '000000'),
        OtpFailure.invalid,
      );
      h.gateway.offline = true;
      await _expectOtp(
        h.repo.confirmPhoneNumberChange(
          challengeId: r.challenge!.id,
          code: h.gateway.codeFor(kB),
        ),
        OtpFailure.unknown,
      );
      h.gateway.offline = false;
      expect(h.gateway.currentSession!.phoneE164, kA);
      expect((await h.repo.currentAccount())!.phoneE164, kA);
    });

    test('a stale session needs re-authentication and no SMS is sent', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA);
      await h.signIn(kA);
      h.gateway.rpcHandlers['request_sensitive_action'] =
          (_) => throw const GatewayRpcException('reauth_required', 'sign in again');
      final int before = h.gateway.sendCount;
      final OtpChallengeResult r = await h.repo.requestPhoneNumberChange(kB);
      expect(r.error, PhoneInputError.reauthRequired);
      expect(h.gateway.sendCount, before);
    });

    test('changing to the current number is refused without sending', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      final int before = h.gateway.sendCount;
      expect((await h.repo.requestPhoneNumberChange(kA)).isSuccess, isFalse);
      expect(h.gateway.sendCount, before);
    });
  });

  group('057 account deletion from the client', () {
    test('retries reuse one idempotency key and end in a signed-out state', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson());
      await h.signIn(kA);
      h.gateway.offline = true;
      await expectLater(h.repo.deleteAccount(), throwsA(isA<RepositoryException>()));
      h.gateway.offline = false;
      expect(h.gateway.currentSession, isNotNull, reason: 'nothing lost on failure');
      await h.repo.deleteAccount();
      expect(h.gateway.currentSession, isNull);
      expect(h.gateway.usersByPhone.containsKey(kA), isFalse);
      expect(h.gateway.deleteKeys.toSet().length, lessThanOrEqualTo(1));
    });

    test('a failed request is retried with the same key and no second grant', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson());
      await h.signIn(kA);
      h.gateway.failNextDelete = true;
      await expectLater(h.repo.deleteAccount(), throwsA(isA<RepositoryException>()));
      await h.repo.deleteAccount();
      expect(h.gateway.deleteKeys.length, 2);
      expect(h.gateway.deleteKeys.toSet().length, 1, reason: 'same key on retry');
      expect(h.gateway.rpcCalls.where((String c) => c == 'request_sensitive_action').length, 1);
      expect(h.gateway.currentSession, isNull);
    });

    test('a success whose response was lost completes on retry instead of failing', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA, profile: _profileJson());
      await h.signIn(kA);
      h.gateway.loseNextDeleteResponse = true;
      await expectLater(h.repo.deleteAccount(), throwsA(isA<RepositoryException>()));
      expect(h.gateway.usersByPhone.containsKey(kA), isFalse, reason: 'server did delete');
      await h.repo.deleteAccount(); // user gone -> 401 -> treated as done
      expect(h.gateway.currentSession, isNull);
    });

    test('a recent sign-in is required and surfaces as reauthRequired', () async {
      final Harness h = Harness();
      h.gateway.addUser(kA);
      await h.signIn(kA);
      h.gateway.rpcHandlers['request_sensitive_action'] =
          (_) => throw const GatewayRpcException('reauth_required');
      await expectLater(
        h.repo.deleteAccount(),
        throwsA(isA<RepositoryException>().having(
          (RepositoryException e) => e.code,
          'code',
          RepositoryErrorCode.reauthRequired,
        ),),
      );
      expect(h.gateway.currentSession, isNotNull);
      expect(h.gateway.deleteKeys, isEmpty);
    });
  });

  group('059 account-boundary scenarios', () {
    Future<SessionController> controller(Harness h, AppDependencies deps) async =>
        SessionController(
          auth: h.repo,
          providers: deps.providers,
          consents: deps.consents,
          drafts: deps.drafts,
        );

    test('sign-out during an in-flight verification keeps the user signed out', () async {
      final Harness h = Harness();
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      final SessionController c = await controller(h, deps);
      await c.requestCode(kA);
      h.now = h.now.add(const Duration(minutes: 2));
      h.gateway.verifyGate = Completer<void>();
      final Future<bool> verifying = c.verifyCode(h.gateway.codeFor(kA));
      await Future<void>.delayed(Duration.zero);
      await c.signOut();
      h.gateway.verifyGate!.complete();
      expect(await verifying, isFalse);
      expect(c.status, SessionStatus.signedOut);
      expect(c.session, isNull);
    });

    test('sign-out during an in-flight registration does not attach the profile', () async {
      final Harness h = Harness();
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      final SessionController c = await controller(h, deps);
      await h.signIn(kA);
      await c.restore();
      final Completer<void> gate = Completer<void>();
      h.gateway.rpcHandlers['register_profile'] = (_) {
        return gate.future.then((_) => _profileJson(id: 'prov-late'));
      };
      final Future<ProviderProfile?> creating =
          c.createProfile(_submission(kA, session: c.session!));
      await Future<void>.delayed(Duration.zero);
      await c.signOut();
      gate.complete();
      expect(await creating, isNull);
      expect(c.profile, isNull);
      expect(c.status, SessionStatus.signedOut);
    });

    test('two sign-ins racing never produce a mixed identity', () async {
      final Harness h = Harness();
      final OtpChallengeResult a = await h.repo.requestOtp(kA);
      h.now = h.now.add(const Duration(minutes: 2));
      final OtpChallengeResult b = await h.repo.requestOtp(kB);
      final String codeA = h.gateway.codeFor(kA);
      final String codeB = h.gateway.codeFor(kB);
      final PhoneVerificationResult va =
          await h.repo.verifyOtp(challengeId: a.challenge!.id, code: codeA);
      expect(va.session.phoneE164, kA);
      // B's challenge was requested while signed out; A is now the session.
      await _expectOtp(
        h.repo.verifyOtp(challengeId: b.challenge!.id, code: codeB),
        OtpFailure.unknown,
      );
      expect(h.gateway.currentSession!.phoneE164, kA);
      expect(h.gateway.usersByPhone.length, 1, reason: 'no duplicate identity created');
    });

    test('a session that ends mid-edit stops protected writes', () async {
      final Harness h = Harness();
      await h.signIn(kA);
      h.now = h.now.add(const Duration(hours: 2));
      h.gateway.revokeNextRefresh = true;
      await expectLater(
        h.repo.registerProfile(submission: _submission(kA)),
        throwsA(isA<RepositoryException>()),
      );
      expect(h.gateway.rpcCalls.contains('register_profile'), isFalse);
    });
  });
}

RegistrationSubmission _submission(String phone, {ProviderSession? session}) =>
    RegistrationSubmission(
      phoneE164: phone,
      session: session ??
          ProviderSession(
            accountId: 'x',
            phoneE164: phone,
            signedInAt: DateTime.utc(2026, 10, 7),
          ),
      displayName: 'Demo Listing',
      baseCityId: 'mh-mumbai',
      baseLocalityId: 'mh-mumbai-powai',
      categoryIds: const <String>['electrical'],
      serviceAreaIds: const <String>['mh-mumbai-powai'],
    );
