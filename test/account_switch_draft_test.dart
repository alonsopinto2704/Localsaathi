import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/controllers/session_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/domain/models/provider.dart';

// Phase 003 (shared device): provider A's onboarding draft, including A's
// phone number, must not survive A signing out or deleting the account, or the
// next person to open the wizard on that device is offered A's draft.
void main() {
  late AppDependencies deps;
  late SessionController session;

  setUp(() async {
    deps = await AppDependencies.mock(keyValueStore: InMemoryKeyValueStore(), persist: false);
    session = SessionController(
      auth: deps.auth,
      providers: deps.providers,
      consents: deps.consents,
      drafts: deps.drafts,
    );
    await deps.drafts.save(
      ProviderDraft(
        phoneE164: '+919000000001',
        updatedAt: DateTime(2026, 10, 6),
        displayName: 'Provider A',
      ),
    );
  });

  test("signing out does not leave the previous provider's draft on the device", () async {
    await session.signOut();
    expect(await deps.drafts.load(), isNull);
  });

  test("deleting the account does not leave the provider's draft on the device", () async {
    await session.deleteAccount();
    expect(await deps.drafts.load(), isNull);
  });
}
