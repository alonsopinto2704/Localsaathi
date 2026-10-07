import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/controllers/session_controller.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/domain/models/provider.dart';

// Phase 003 reproduction (shared device): provider A's onboarding draft,
// including A's phone number, survives A signing out, so the next person to
// open the wizard on that device is offered A's draft.
// Skipped until the fix lands in phase 049/051; remove `skip` then.
void main() {
  test(
    "signing out does not leave the previous provider's draft on the device",
    () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final AppDependencies deps = await AppDependencies.mock(keyValueStore: store);
      final SessionController session = SessionController(
        auth: deps.auth,
        providers: deps.providers,
        consents: deps.consents,
      );

      await deps.drafts.save(
        ProviderDraft(
          phoneE164: '+919000000001',
          updatedAt: DateTime(2026, 10, 6),
          displayName: 'Provider A',
        ),
      );
      await session.signOut();

      expect(await deps.drafts.load(), isNull);
    },
    skip: 'Known defect recorded in tasks/evidence/phase-003.md; fix in phase 049/051',
  );
}
