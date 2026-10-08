# Phase 083 Evidence - Quarantine and content validation

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Keep pending files private; validate magic bytes, decoded dimensions, size and format server-side before anything is public; refuse malformed and decompression-bomb images; give a clear processing state.

## Changed paths
- backend/supabase/migrations/20261008000032_media_quarantine.sql (begin_media_processing, reject_media_upload, get_media_upload)
- backend/supabase/functions/media-process/{image.ts,logic.ts,index.ts}
- backend/supabase/tests/database/0032_media_quarantine.test.sql (17 assertions)
- backend/test/media-process.test.mjs (19 tests, shared with 084/086)

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0032_media_quarantine.test.sql (17 tests)`
- `node --test backend/test/media-process.test.mjs` -> `pass 19, fail 0`
- Mutation check: making strip() keep comment/APP segments made 3 media-process tests fail (`pass 16, fail 3`); restored -> `pass 19`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Renamed executables never enter public delivery | bytes starting MZ, HTML, SVG and PDF declared as image/jpeg -> not_an_image; nothing written to public (node test) | Pass |
| Oversized / malformed images never enter public delivery | truncated JPEG, bad PNG CRC, missing IEND, wrong RIFF size, SOI+EOI only -> malformed; byte ceiling -> too_large; DB rejects an object above the authorised size (0032) | Pass |
| Decompression bombs | 60000x60000 PNG, 30000x30000 JPEG, 16000x16000 WebP rejected from the header (dimensions_too_large) and the codec was called 0 times | Pass |
| Declared type must match content | PNG bytes declared image/jpeg -> mime_mismatch | Pass |
| Pending files private with expiry and state | quarantine bucket has no client policy; expiry, stale-run reclaim, 3 bounded attempts and short failure codes tested; owner can read state via get_media_upload | Pass (SQL) |
| Isolated decoding | decoding only after header checks, under a timeout, inside the Edge isolate. Memory/CPU limits are the platform's; UNVERIFIED | Partial |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- Validation is structural: whether the compressed stream actually decodes is only known by the codec, which is a fake in tests. The real ImageMagick WASM wiring (index.ts) is unrun: cold start, memory for a 16 MP decode and WebP output size are unmeasured.
- Rejections return stable codes; the 3-attempt limit applies to transient faults only.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Deploy media-process to staging, upload the synthetic fixtures (build them with the generators in the node test) and confirm decode, rejection and timing.
