# Phase 063 Evidence - Live location repository

**Status:** Done locally. Staging check BLOCKED (no hosted project). UI explanation of a deactivated market is NOT built (controller exposes the state only). **Reviewer:** pending.

## Objective
Cities, localities and activation status from the backend, cached with a revision and expiry, no silent relocation.

## Changed paths
- lib/data/live/live_location_repository.dart (new)
- lib/data/supabase/ref_cache.dart (new: TTL cache, stale-on-failure; shared with the catalog)
- lib/app/controllers/location_controller.dart (`unavailableSelection`)
- test/live_repositories_test.dart (group "phase 063")

## Behaviour
- Reads `countries`, `state_regions`, `cities` once (15 minute expiry) and `localities` per city; `revision` is a content hash of city ids/statuses and state flags (the backend has no revision column).
- A failed refresh serves the last copy and sets `isStale`; with no copy the error propagates. No seed data anywhere.
- Unknown `launch_status` -> inactive. `resolveSelection` is null for an inactive/coming-soon city or a locality not in the city.
- `requestCity` calls `request_city` (no phone sent); receipt stored on-device; `searchCities` uses the bounded `search_cities` RPC; `setCityLaunchStatus` is refused (admin operation).
- `LocationController.load()` still falls back to the launch market default when the stored choice no longer resolves, but now exposes the old choice as `unavailableSelection` so the UI can explain it.

## Commands run (actual results)
- `flutter test --no-pub test/live_repositories_test.dart --plain-name "phase 063" -r failures-only` -> `+9: All tests passed!`
- Final full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Market activation changes the app through data, no update | test: status flipped in the fake table appears after expiry, revision changes | Pass (local) |
| Preserve valid locality; deactivation is explained not hidden | test: stored choice kept when valid; `unavailableSelection` set when the market is deactivated | Controller done; screen copy NOT done |
| Offline / error / empty | test: stale copy + `isStale`; no copy -> error; malformed row fails the load | Pass (local) |
| Staging check | not performed | BLOCKED |

## Remaining uncertainty
- Cache is in memory only: a cold start offline has no reference data and shows an error (no persisted "safe stale" copy yet).
- "First active city" uses name order; add an explicit sort column when a second market launches.
- PostgREST's default 1000-row cap is not paged; fine for one city's localities, revisit at national scale.

## Next action
Add the deactivation banner/picker prompt using `unavailableSelection`; persist the reference cache with its revision for offline start.
