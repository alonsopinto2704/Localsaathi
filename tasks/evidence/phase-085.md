# Phase 085 Evidence - Interrupted uploads and orphans

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Repeatable upload state with bounded retries and a grace period; reconcile crashes, processing failures and missing references; garbage-collect only after verifying ownership and references.

## Changed paths
- backend/supabase/migrations/20261008000034_media_orphans.sql (media_orphan_reason, expire_media_uploads, list_media_orphans, media_object_deletable)
- backend/supabase/functions/media-gc/{logic.ts,index.ts}
- backend/supabase/tests/database/0034_media_orphans.test.sql (19 assertions)
- backend/test/media-gc.test.mjs (6 tests)

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0034_media_orphans.test.sql (19 tests)`
- `node --test backend/test/media-gc.test.mjs` -> `pass 6`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Interrupted uploads create no public partial file | quarantine is private; derivatives are written only after validation and removed on any later failure (node test: putPublic/complete failures leave 0 public objects) | Pass |
| Eligible orphans eventually disappear | SQL lists no-row objects past grace, abandoned (expired + 2 h) uploads, finished originals past 1 h and unreferenced public objects past 2 h; media-gc removes them through the Storage API after a re-check. Actual blob removal is UNVERIFIED | Pass (selection), UNVERIFIED (removal) |
| Ownership and references verified before deletion | a photo row of another listing naming a path protects nothing; references from provider_photos and processing/approved uploads protect; odd shapes and credential-evidence are never listed; fresh objects wait out the grace period | Pass |
| Pause when uncertain | media_cleanup flag off -> paused, and re-check refuses; a sweep that would delete > half of >20 objects pauses (anomaly) until accepted; the loop stops after 5 delete failures | Pass |
| Bounded retries | max 3 attempts; stale processing reclaimed after 10 min; exhausted -> rejected processing_failed | Pass |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- list_media_orphans scans all objects of two buckets each run; fine for a pilot, add an index on storage.objects(bucket_id, created_at) or batch if slow (unmeasured).
- delete-account (not changed) does not list media-quarantine; its objects have no upload row after the listing cascade and fall to the no-row rule after the grace period.
- The existing private.storage_cleanup_queue still receives exact photo paths; media-gc does not read it, because reference-based orphan detection covers the same objects. Nothing marks the queue rows processed.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Schedule media-gc in staging, create orphans with the real flow, and confirm the blobs and storage.objects rows disappear.
