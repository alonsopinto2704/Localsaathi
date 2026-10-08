# Phase 062 Evidence - Shared mapping and error types

**Status:** Done locally. Staging response-shape check BLOCKED (no hosted project). **Reviewer:** pending.

## Objective
One strict, conservative mapping layer between backend payloads and domain objects, and one error mapping, used by every live repository.

## Changed paths
- lib/data/supabase/wire.dart (new)
- lib/data/supabase/supabase_provider_auth_repository.dart (its two private error mappers removed; it now calls the shared `repositoryErrorForRpc` / `repositoryErrorForGateway`, behaviour identical)
- test/wire_mapping_test.dart

## Rules implemented
- Naming boundary (documented at the top of wire.dart): RPC arguments, tables and `selectRows` rows are snake_case; RPC JSON results are camelCase; enum labels are snake_case.
- Helpers: `asMap`, `asRows`, `reqString`, `optString`, `boolOr`, `intOr`, `reqTime`, `stringList`, `enumOr(values, raw, fallback)`; malformed input throws `RepositoryException(unavailable, ...)`.
- `profileFromWire` (public and owner shape): requires id and both timestamps; forces `isDemoProfile=false`; a missing/non-E.164 phone clears phone and WhatsApp consent; unknown availability -> `unavailable`; unknown status -> `draft` (never published); unknown/unapproved verification entries are dropped (never verified); negative or non-numeric prices dropped; wrongly typed nested fields reject the payload.
- Unknown city launch status -> `inactive` (phase 063); category approval defaults to false when the flag is missing (phase 064).
- Errors: stable prefixes (`not_owner`, `not_found`, `validation_failed`, `conflict`, `location_not_active`, ...) map to `RepositoryErrorCode`; unknown prefixes and gateway/transport failures map to `unavailable` ("outcome unknown"); `guarded()` ensures nothing above the data layer sees gateway types or arbitrary exceptions.

## Commands run (actual results)
- `flutter test --no-pub test/wire_mapping_test.dart -r failures-only` -> `+11: All tests passed!`
- `flutter test --no-pub test/auth_live_repository_test.dart` (refactored mapper) is covered by the full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73, all info)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Fixtures cover nulls, missing optionals, unknown states, malformed responses | wire_mapping_test: shared public-profile contract fixture, null/absent optionals, unknown status/availability/verification, bad phone, bad prices, 9 malformed payloads rejected | Pass |
| Unknown enum never verified/active/published | tests above plus unknown city status (063) | Pass |
| snake_case/camelCase boundary documented | wire.dart header | Done |
| Staging response shapes | not performed | BLOCKED |

## Remaining uncertainty
- Mapping follows docs/backend-contract.md and the contract fixtures, not a live server. `ProviderProfile.fromJson` (shared with local JSON) is unchanged; `profileFromWire` pre-sanitises instead.
- `rate_limited`, `feature_disabled`, `consent_required` have no `RepositoryErrorCode` yet and map to `unavailable` (same as before).

## Next action
Add `rateLimited`/`featureDisabled` codes when a screen needs to distinguish them; compare payloads with a real project.
