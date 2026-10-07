# Phase 028 — Market activation authorization

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
City and category activation must be admin-only, audited, and honoured by every discovery path. Owners keep their drafts, and the app never claims a deactivated market is live.

## Changed paths
- Migration `…13`: no client writes to reference tables.
- Migration `…15`: `set_city_launch_status` and `set_category_launch_approval`. Both require an admin, a non-empty reason, and write an audit row.
- Migration `…16`: all discovery paths are gated.

## Discovery paths covered
- `search_providers` joins on `cities.launch_status='active'` and on approved categories.
- These six paths all call `is_publicly_listed`: `search_providers`, `get_public_profile`, `similar_providers`, `provider_count_by_locality`, `providers_published_in_city`, `active_promotions`.
- `search_categories` returns approved categories only.
- `search_cities` hides `inactive` cities.

## Owner experience
The owner JSON still returns the profile, with `isPubliclyListed: false`, so the app can say "not visible right now" instead of claiming the market is live. Drafts and edits keep working.

## Verification
- `0010_market_activation` (13 assertions):
  - an empty reason returns `validation_failed`;
  - a non-admin gets `not_owner`;
  - a coming_soon city and an un-approved category each hide the listing from all six paths;
  - the owner still sees the listing, with `isPubliclyListed=false`;
  - audit rows are written.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Rollback
Restore only the intended configuration, through the same audited RPCs.
