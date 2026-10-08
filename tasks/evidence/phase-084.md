# Phase 084 Evidence - Server-side metadata stripping

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Keep client stripping as an optimisation but enforce server-side stripping and re-encoding; remove GPS, names, comments, device identifiers; preserve orientation; keep originals only briefly.

## Changed paths
- backend/supabase/functions/media-process/image.ts (strip, isClean, tiffOrientation; port of lib/core/utils/image_metadata.dart extended to WebP and trailing bytes)
- backend/supabase/migrations/20261008000033_media_approval.sql (complete_media_upload: approval gate)
- backend/supabase/tests/database/0033_media_approval.test.sql (14 assertions)
- backend/test/media-process.test.mjs

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0033_media_approval.test.sql (14 tests)`
- `node --test backend/test/media-process.test.mjs` -> `pass 19`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Known EXIF/PNG metadata fixtures disappear from every public derivative | planted markers (GPS string, camera serial, owner comment, JFIF thumbnail, trailing payload, PNG tEXt/tIME/eXIf, WebP ICCP/EXIF/XMP) are asserted present in the fixture and absent from stripped output and from every byte passed to putPublic, including when the fake codec leaks metadata | Pass (fixtures) |
| Orientation preserved | JPEG keeps an orientation-only EXIF (read back = 6); PNG/WebP with a non-default orientation are routed through the codec (pixels rotated) and never passed through | Pass (logic); pixel result UNVERIFIED |
| Every public derivative is verified clean | strip() is idempotent on derivatives (isClean) before writing; complete_media_upload refuses approval unless the caller attests clean and both objects exist under keys generated for this upload | Pass |
| Originals private for a short window | original deleted right after approval/rejection; sweep backstop 60 minutes (0034 tests) | Pass (logic); blob deletion UNVERIFIED |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- Stripping is a container rewrite with an allow-list, not a pixel re-encode; the full image of a small JPEG is the original pixel stream. The thumbnail and any oversize/rotated image are re-encoded by the codec.
- ICC profiles are dropped (as the Dart client does): wide-gamut photos can shift colour. PNG ancillary chunks other than tRNS/sRGB/gAMA/cHRM and APNG frames are dropped.
- Dart `stripImageMetadata` stays unchanged; no Flutter change required for this phase.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Run the planted-marker fixtures through the deployed function and byte-search the CDN responses.
