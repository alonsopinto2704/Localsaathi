# Phase 065 Evidence - Bounded search adapter

**Status:** Done locally. Staging check BLOCKED (no hosted project). **Reviewer:** pending.

## Objective
Map `ProviderQuery` to the authorized `search_providers` RPC with server bounds, preserve ranking and sponsored flags, and make sure a superseded response cannot overwrite a newer one.

## Changed paths
- lib/data/live/live_provider_repository.dart (new; `search`, shared with 066/067)
- lib/app/controllers/provider_search_controller.dart (request counter: only the latest request may write results/loading/error)
- test/live_repositories_test.dart (group "phase 065")

## Behaviour
- Params: `p_city_id`, `p_locality_id`, `p_text` (trimmed, <= 80), `p_category_ids` and `p_locality_filter_ids` (<= 20 each), `p_open_now_only`, `p_home_visits_only`, `p_limit` (clamped 1..50, default 20). The only call made is the RPC: nothing is downloaded for client-side filtering, no general-purpose profile fetch.
- Items keep server order and `isSponsored`; `totalCount` is the server's. Items that are malformed or not published are dropped; a malformed envelope or an outage throws (never an empty list).
- `isSampleData` is always false.
- `ProviderQuery` has no offset yet (proposal in backend-contract.md section 8); not added here.

## Commands run (actual results)
- `flutter test --no-pub test/live_repositories_test.dart --plain-name "phase 065" -r failures-only` -> `+4: All tests passed!`
- Final full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Rapid edits never let an older request overwrite newer results | test: slow "pl" request completes after "plumber"; results, loading flag unchanged | Pass (local) |
| Server ranking + sponsored preserved | test | Pass |
| No client-side download / private fields | test asserts the call list is exactly `rpc:search_providers`; every profile goes through the public mapper | Pass |
| Offline / error / empty | outage and malformed envelope throw; empty list returns empty results | Pass (local) |
| Staging check | not performed | BLOCKED |

## Remaining uncertainty
- Silent truncation of text > 80 and lists > 20 (instead of a validation error) is a client choice; UI should cap input.
- Other screens that call `search` directly (not via the controller) have no staleness guard; only the controller was found to need it.

## Next action
Add `offset` to `ProviderQuery` and paging UI; run against a seeded staging DB to compare ranking.
