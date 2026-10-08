# Phase 067 Evidence - Owner profile adapter

**Status:** Done locally. Staging check BLOCKED (no hosted project): server-side ownership enforcement was NOT exercised from the app. **Reviewer:** pending.

## Objective
Owner editor/dashboard data through authenticated owner RPCs, separate from public cards, ownership rechecked on every call, nothing retained for a later account.

## Changed paths
- lib/data/live/live_provider_repository.dart (`profileByIdForOwner`, `updateProfile`, `publish`, `setListingStatus`, `setAvailability`, `deleteListing`, `createProfile`)
- test/live_repositories_test.dart (group "phase 067")

## Behaviour
- `profileByIdForOwner` -> `get_owner_profile`; refused client-side with `notOwner` when `session.profileId` is not the requested id (same rule as the mock), and the server checks again. A server `not_owner`, a revoked session (`notAuthenticated`) or null all surface as such.
- Writes: `update_profile_full` with an allowlisted patch (displayName, description, languages, homeVisits, availability, whatsappEnabled, phoneDisplayConsented, pinCodes, categoryIds, serviceAreas, workingHours, startingPrices, healthcareDetails); never id, phone, status, verification, revision or moderation fields. `set_listing_status` (publish/pause/draft), `set_availability`, `delete_listing`. Responses are re-mapped with the owner mapper and must carry the same id.
- No owner cache: the repository keeps no profile between calls, so there is nothing to leak into a later account or to retain after permission loss; `SessionController` already clears its own copy on sign-out, deletion and revocation.
- `createProfile` is refused (`unavailable`): registration is the transactional `ProviderAuthRepository.registerProfile` path (phase 068).

## Commands run (actual results)
- `flutter test --no-pub test/live_repositories_test.dart --plain-name "phase 067" -r failures-only` -> `+6: All tests passed!`
- Final full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Guessed IDs cannot read/update another provider's records | tests: foreign id and missing `session.profileId` refused with zero requests; server `not_owner` mapped | Client Pass; server enforcement BLOCKED (not run from the app; relies on phase 039 pack, itself blocked) |
| Owner data separate from public cards | separate methods and RPCs, no shared cache | Pass |
| Permission loss mid-screen / account switch | no retained state; revoked session -> `notAuthenticated` | Pass (local) |
| Recheck ownership after recovery | every call goes to the server | Pass |
| Staging check | not performed | BLOCKED |

## Remaining uncertainty
- `updateProfile` sends no `expectedRevision` (the model has no revision), so edit conflicts are last-write-wins; `ponytail:` note in code.
- `SessionController.updateProfile` still records consents in the (empty) mock consent repository after the server already recorded them; harmless but redundant until the consent phase.
- `set_listing_status` / `set_availability` return an owner-shape profile per the migration signatures (`returns jsonb`), not exercised against a server.

## Next action
Add revision to the profile model and send `expectedRevision`; replace the consent/verification mocks; run the authz pack once Docker or a hosted project exists.
