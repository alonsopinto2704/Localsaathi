# Phase 091 Evidence - Precise location consent

**Status:** Done locally (database); consent screen and settings UI not built. **Reviewer:** pending **Human sign-off:** pending

## Objective
Distinguish public business address, approximate service locality and residential coordinates; require explicit consent for any pin; offer locality-only discovery; one disclosure policy for all public surfaces.

## Changed paths
- backend/supabase/migrations/20261008000042_location_consent.sql (`provider_profiles.location_mode/location_consent_version/location_consented_at`, `private.location_overlay`, `set_location_disclosure`, `get_location_settings`, `set_map_location` reduced to "clear only")
- backend/supabase/tests/database/0042_location_consent.test.sql
- backend/supabase/tests/database/0007_public_projection.test.sql (one line: its fixture pin now also sets `location_mode = 'approximate_pin'`, because a pin without consent is no longer public; **outside my test range, needed**)
- docs/trust-and-credentials.md (section 4); docs/contracts/column-classification.json

## Policy implemented
Default `locality_only`: no coordinates in any public output. `approximate_pin` needs wording `location-v2`, the `precise_location` flag, an in-India point, and is **stored and published at 2 decimals (~1 km)** - an exact residential coordinate is never kept. Opting out deletes the coordinates and records the withdrawal. Existing pins are hidden until re-consent. Business address is provider-typed text, never derived from coordinates.

## Commands run (actual results, 2026-10-08)
`ok 0042_location_consent.test.sql (27 tests)`; `ok 0007_public_projection.test.sql (9 tests)` (after the one-line edit; before it: `public mapLocation is rounded to 2 decimals have: null`); full `Tests: 38/38 files passed, 582/582 assertions passed. PASS`; `Rehearsal: 41/41 checks passed`. Baseline in phase-088.md.

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Locality-only reveals no coordinates publicly | 0042: profile, search items and city list for a locality-only listing carry `mapLocation: null`; list output contains no `19.076`/`72.877`/`map_lat` | Pass |
| Explicit consent required | missing or old wording -> `consent_required`; flag off -> `feature_disabled`; other user -> `not_owner`; guest -> 42501 | Pass |
| Stored precision minimised | stored 19.07612 becomes 19.08; owner sees 19.08 | Pass |
| Withdrawal | coordinates deleted, consent row `granted = false`, area search unaffected | Pass |
| Re-consent on wording change | `get_location_settings.needsReconsent` true for `location-v1` | Pass |
| Rollback switch | flag off hides every pin at once | Pass |
| Maps / APIs / exports / AI context | all consume the one public projection; no separate map endpoint exists in the repo | Pass for the server; export/AI features do not exist yet - they must use the public shape |
| Image metadata (EXIF GPS) | not in this phase's code; the upload pipeline (083-084) must strip GPS from stored images | Not done / contract in docs |
| Real map rendering | BLOCKED (no Flutter run per instructions) | Not done |

## Flutter follow-ups
1. Location screen with the three-way explanation (area only / approximate pin / business address text) and the `location-v2` consent text; call `set_location_disclosure` (replace `setMapLocation` with coordinates, which now errors).
2. Read `get_location_settings` (`mode`, `needsReconsent`) and prompt re-consent.
3. Never show an owner their pin as "exact": it is the ~1 km value.
4. Copy: "Residential coordinates are never shown more precisely than about 1 km."

## Assumptions and uncertainty
- India bounding box (lat 6-38, lng 68-98) is a coarse sanity check, not a geofence.
- Consent text itself (client) is a draft decision for the product owner.

## Rollback / safe stop
Turn the `precise_location` flag off (instant, keeps consent records), or `update ... set location_mode = 'locality_only', map_lat = null, map_lng = null` to remove pins while keeping area search.

## Next action
Build the consent UI; make the storage pipeline strip GPS EXIF; apply the same projection to any future export/AI context.
