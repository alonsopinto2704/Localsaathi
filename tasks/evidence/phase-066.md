# Phase 066 Evidence - Public profile adapter

**Status:** Done locally. Staging check BLOCKED (no hosted project). **Reviewer:** pending.

## Objective
Details, similar profiles, city lists and bookmark refresh use only the public projection; hidden records are "unavailable", and a missing profile is never replaced by another provider.

## Changed paths
- lib/data/live/live_provider_repository.dart (`publicProfileById`, `publishedInCity`, `providerCountByLocality`, `similarProviders`, `serviceAreaLocalities`)
- lib/data/live/live_saved_provider_repository.dart (new: ids on-device, refresh through `publicProfileById`)
- test/live_repositories_test.dart (group "phase 066")

## Behaviour
- `get_public_profile`: JSON null (draft, paused, suspended, deleted, unknown) -> `null`; a payload whose id differs from the requested one is rejected as malformed (never shown); a payload that is not `published` -> `null`; a non-UUID id returns null without a request.
- `similar_providers`, `providers_published_in_city`: same per-item check, the source profile is excluded, hidden/malformed entries dropped.
- Network failure is an error, distinct from "unavailable".
- Bookmarks: unavailable listings drop out of `savedProfiles()`; an outage throws instead of showing an empty list. No profile data is cached locally, so a stale link cannot show cached private fields.

## Commands run (actual results)
- `flutter test --no-pub test/live_repositories_test.dart --plain-name "phase 066" -r failures-only` -> `+5: All tests passed!`
- Final full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Stale links cannot reveal hidden listings or cached private fields | tests: null, paused, id mismatch, junk id, no local profile cache | Pass (local) |
| Paused/suspended/deleted/revoked -> unavailable | server returns null; client re-checks status | Pass (local) |
| Demo identities never launch a real contact action | live profiles can never be demo; a profile without a valid phone has no call/WhatsApp (phase 062) | Pass (local) |
| Staging check | not performed | BLOCKED |

## Remaining uncertainty
- The screen layer was not changed: a null public profile uses whatever "not available" state the existing profile screen has (not re-verified against a live build). The `unavailable` vs `network error` distinction depends on screens catching `RepositoryException`.
- Bookmark refresh does one RPC per saved id (parallel); fine for tens of bookmarks, add a batch RPC if the list grows.

## Next action
Check the profile screen shows its unavailable state for `null` and an error state for `RepositoryException`; add a batch public-profile RPC.
