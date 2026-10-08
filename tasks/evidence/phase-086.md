# Phase 086 Evidence - Image derivatives and byte budgets

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
A small defined derivative set, versioned URLs, measured low-bandwidth budgets, no original-resolution media in cards, no excess variants.

## Changed paths
- backend/supabase/migrations/20261008000035_media_budgets.sql (media_policy)
- backend/supabase/migrations/20261008000030_media_classes.sql (private.media_derivatives: thumb 320 px / 40 KB / q70, full 1280 px / 300 KB / q80)
- backend/supabase/migrations/20261008000033_media_approval.sql (budget enforcement at approval)
- backend/supabase/tests/database/0035_media_budgets.test.sql (6 assertions)
- backend/supabase/tests/database/0033_media_approval.test.sql
- backend/test/media-process.test.mjs

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0035_media_budgets.test.sql (6 tests)`

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Small defined set | exactly two derivatives (test); no others generated | Pass |
| Budgets enforced | database refuses a thumb over 40960 B, a full over 307200 B or dimensions above 1280 px (0033); the encoder retries once at quality-20 then rejects over_budget (node test) and the Edge Function reads the same numbers from media_policy() | Pass |
| Cards never load originals | cards need only the thumb; declared page ceiling 20 x 40 KB = 800 KB (asserted from the table). Clients derive the thumb key by replacing -full. with -thumb. in the stored full path (convention; the projection is unchanged) | Pass (declared); client use needs a Flutter follow-up |
| Versioned URLs; replacements invalidate old revisions | keys contain the upload id, written once (upsert false, immutable cache-control); replacing a photo swaps to a new key and retires the old upload (0036). CDN behaviour UNVERIFIED | Pass (logic), UNVERIFIED (CDN) |
| Representative browsing meets the budget (measured) | NOT MEASURED: no hosted project, no device or throttled network | UNVERIFIED |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- Placeholders (blur hash / dominant colour) are not implemented.
- Budgets are declared, not measured; 300 KB for a 1280 px WebP at q80 is typical but unconfirmed for the real codec.
- The public projection still returns storagePath only (the full image); thumb path needs the naming convention or a later projection change.

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Measure real derivative sizes from the deployed codec on representative images; set budgets from the data; add a thumb field to the projection.
