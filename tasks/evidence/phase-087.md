# Phase 087 Evidence - Atomic gallery updates

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Bind approved objects to owned profile records; atomic ordering, replacement, deletion; configurable server-side photo limit under concurrency; rejected objects cannot appear via a manually supplied URL.

## Changed paths
- backend/supabase/migrations/20261008000036_gallery_atomic.sql (add_provider_photo/delete_provider_photo redefined; replace_provider_photo, set_photo_order, check_photo_limit reads max_photos, private.take_approved_upload)
- backend/supabase/tests/database/0036_gallery_atomic.test.sql (28 assertions)

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0036_gallery_atomic.test.sql (28 tests)`
- Earlier suites that call add_provider_photo/delete_provider_photo (0008, 0014, 0015) still pass unchanged in the same run: `Tests: 30/30 files passed, 411/411 assertions passed. PASS`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Approved objects bound to owned records with readiness checks | pipeline on: add_provider_photo accepts only the caller's approved, unattached upload for that listing; hand-made path, quarantine path, processing/rejected/other-account/already-attached uploads all refused | Pass |
| Rejected objects cannot appear via a manual URL | rejected path refused at attach and at replace; the public profile JSON never contains it; clients cannot write the public bucket (0030) | Pass |
| Concurrent additions respect limits | every gallery RPC locks the listing row first; the limit is read from private.media_settings (changed to 2 in a test) and enforced by trigger. PGlite is single-connection, so only the sequential "limit reached" case ran; true parallel sessions did NOT run | Partial: sequential only |
| Failed replacements preserve the previous gallery | a replacement with a rejected upload throws and the gallery and old upload are unchanged; a valid one swaps in place (position kept), retires the old revision | Pass |
| Ordering and deletion | set_photo_order requires a full permutation (partial/duplicate refused, other account refused); delete retires the upload so blobs become orphans | Pass |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- Ordering is stored in uploaded_at (the projection sorts on it); a position column plus projection change is the clean fix and belongs to whoever owns public_profile_json.
- Parallel-session behaviour of the row lock must be re-run on a hosted database.
- Flutter follow-ups: use authorize -> upload -> media-process -> add_provider_photo(fullPath); call replace_provider_photo / set_photo_order; show processing/rejected states from get_media_upload; derive thumbnail URLs.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Wire the Flutter provider photo screen to the pipeline (outside this workstream) and run the concurrency test with two sessions on staging.
