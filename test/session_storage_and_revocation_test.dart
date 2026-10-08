import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/controllers/session_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/data/supabase/otp_cooldown.dart';
import 'package:localsaathi/data/supabase/secure_session_storage.dart';
import 'package:localsaathi/data/supabase/supabase_provider_auth_repository.dart';
import 'package:localsaathi/domain/models/provider.dart';

import 'support/fake_auth_gateway.dart';

// Phase 049 (secure session persistence) and the revocation wiring of
// phase 050. Tokens are opaque strings here; none is a real credential.
class _MemorySecrets implements SecretStore {
  final Map<String, String> values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keystore unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keystore unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('keystore unavailable');
    values.remove(key);
  }
}

void main() {
  group('SecureSessionStorage', () {
    test('persists, reads and removes through the secret store only', () async {
      final _MemorySecrets secrets = _MemorySecrets();
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession('session-of-A');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), 'session-of-A');
      await storage.removePersistedSession();
      expect(await storage.accessToken(), isNull);
      expect(secrets.values, isEmpty);
    });

    test('a second account cannot recover the first account\'s token', () async {
      final _MemorySecrets secrets = _MemorySecrets();
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      await storage.persistSession('session-of-A');
      await storage.removePersistedSession(); // A signs out
      await storage.persistSession('session-of-B'); // B signs in
      expect(await storage.accessToken(), 'session-of-B');
      expect(secrets.values.values, isNot(contains('session-of-A')));
    });

    test('an unreadable keystore fails closed: signed out, never plain storage', () async {
      final _MemorySecrets secrets = _MemorySecrets()..values['ls.auth.session'] = 'old';
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      secrets.failReads = true;
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
      expect(storage.isHealthy, isFalse);
    });

    test('an unwritable keystore keeps the session in memory only (nothing persisted)', () async {
      final _MemorySecrets secrets = _MemorySecrets()..failWrites = true;
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      await storage.persistSession('session-of-A'); // must not throw
      expect(storage.isHealthy, isFalse);
      expect(secrets.values, isEmpty);
    });

    test('a failed delete blanks the blob, so sign-out cannot fail open', () async {
      final _MemorySecrets secrets = _MemorySecrets();
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      await storage.persistSession('session-of-A');
      secrets.failDeletes = true;
      await storage.removePersistedSession();
      expect(await storage.accessToken(), isNull);
      expect(secrets.values.values, isNot(contains('session-of-A')));
      expect(storage.isHealthy, isFalse);
    });

    test('if neither delete nor overwrite works the error surfaces (no silent sign-out)', () async {
      final _MemorySecrets secrets = _MemorySecrets();
      final SecureSessionStorage storage = SecureSessionStorage(secrets);
      await storage.persistSession('session-of-A');
      secrets.failDeletes = true;
      secrets.failWrites = true;
      await expectLater(storage.removePersistedSession(), throwsStateError);
    });

    test('session code never uses the ordinary key-value store', () {
      final Iterable<File> files = Directory('lib/data/supabase')
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'));
      for (final File f in files) {
        final String src = f.readAsStringSync();
        final bool allowed = f.path.replaceAll('\\', '/').endsWith('otp_cooldown.dart') ||
            f.path.replaceAll('\\', '/').endsWith('auth_bootstrap.dart');
        if (!allowed) {
          expect(src.contains('key_value_store'), isFalse, reason: f.path);
          expect(src.contains('shared_preferences'), isFalse, reason: f.path);
        }
      }
      // The two allowed users store a timestamp / receive a handle, never a token.
      expect(File('lib/data/supabase/otp_cooldown.dart').readAsStringSync(),
          isNot(contains('accessToken')),);
    });
  });

  group('revocation reaches the UI without losing the draft', () {
    test('a revoked refresh signs the controller out but keeps the onboarding draft', () async {
      DateTime now = DateTime.utc(2026, 10, 7, 9);
      final FakeAuthGateway gateway = FakeAuthGateway(now: () => now);
      final AppDependencies deps = await AppDependencies.mock(
        keyValueStore: InMemoryKeyValueStore(),
        persist: false,
      );
      final SupabaseProviderAuthRepository repo = SupabaseProviderAuthRepository(
        gateway: gateway,
        cooldown: OtpCooldown(store: InMemoryKeyValueStore(), now: () => now),
        now: () => now,
      );
      final SessionController controller = SessionController(
        auth: repo,
        providers: deps.providers,
        consents: deps.consents,
        drafts: deps.drafts,
      );
      gateway.setSessionTo(gateway.addUser('+919000050001'));
      await controller.restore();
      expect(controller.status, SessionStatus.needsProfile);
      await deps.drafts.save(ProviderDraft(
        phoneE164: '+919000050001',
        updatedAt: now,
        displayName: 'Half-finished listing',
      ),);

      now = now.add(const Duration(hours: 2));
      gateway.revokeNextRefresh = true;
      await expectLater(repo.currentAccount(), throwsA(anything));

      expect(controller.status, SessionStatus.signedOut);
      expect(controller.sessionLost, isTrue);
      expect(controller.session, isNull);
      expect((await deps.drafts.load())?.displayName, 'Half-finished listing');
    });
  });
}
