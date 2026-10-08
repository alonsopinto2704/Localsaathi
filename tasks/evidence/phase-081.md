# Phase 081 Evidence - Storage classification contract

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Define the media classes (quarantine original, public derivative, credential evidence, reserved AI attachment) with ownership, size/MIME limits, expiry, signed-link lifetime and upload/read/publish/delete authority; make buckets and policies follow that table; keep unclassified objects private.

## Changed paths
- backend/supabase/migrations/20261008000030_media_classes.sql (private.media_classes, media_derivatives, media_settings; buckets generated from the table; flags media_pipeline, media_cleanup; restrictive storage policy)
- backend/supabase/tests/database/0030_media_helpers.sql (test fixtures, setup only)
- backend/supabase/tests/database/0030_media_classes.test.sql (14 assertions)
- docs/media-storage.md (the authority matrix and flow)

## Commands run for this phase (actual results)
- `node backend/scripts/verify-db.mjs` (isolated) -> `ok   0030_media_classes.test.sql (14 tests)`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| A matrix explains upload/read/publish/delete authority for every media class | docs/media-storage.md section 1, generated from private.media_classes columns upload_authority/read_authority/publish_authority/delete_authority | Pass |
| Buckets follow the contract | test 1: every class has a bucket with equal public flag, size limit and MIME list; test 2: only provider-photos is public; test 3: no public bucket outside the classification | Pass (SQL level) |
| Unclassified objects stay private | test: an ad hoc bucket accepts no client write; media-quarantine and ai-attachments reject owner inserts with 42501 | Pass |
| Public provider-photos reassessed | with media_pipeline on, clients cannot insert, rename or delete public objects (restrictive policy); keys are uuid-based and only listed for published listings. Residual: a known key of a suspended/unpublished listing is still fetchable until the blob is deleted (documented in docs/media-storage.md section 4) | Partial, decision recorded |
| Actual storage/CDN access, revocation, cleanup | NOT TESTED: needs a hosted project | UNVERIFIED |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- Whether hosted Storage enforces `file_size_limit` / `allowed_mime_types` on signed-upload PUTs exactly as the table says is platform behaviour, unobserved.
- Whether a restrictive policy on `storage.objects` is accepted by the hosted Storage owner role when migrations run as `postgres` is not confirmed (the existing 0011/0022 policies are the precedent).
- Staged cutover: `media_pipeline` ships OFF so earlier suites remain valid; enabling `media_intake` while `media_pipeline` is off keeps the old client-write path. Order of enabling is documented.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Create the hosted project, run the HTTP pack probes for quarantine/public writes, then switch `media_pipeline` on in staging.
