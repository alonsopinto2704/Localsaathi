# Phase 082 Evidence - Owner-bound upload authorization

**Status:** Done locally (SQL, pure logic and fakes only). Real Supabase Storage / CDN / codec behaviour is UNVERIFIED (blocked on a hosted project and Docker). **Reviewer:** chief engineer review pending. **Not committed.**

## Objective
Issue uploads only for the current account and its active listing, with a generated object key, an approved bucket and a bounded size; reject caller-chosen prefixes and cross-account use; expire the authorization.

## Changed paths
- backend/supabase/migrations/20261008000031_media_upload_auth.sql (private.media_uploads, request_media_upload, private.media_setting)
- backend/supabase/functions/media-upload-authorize/{logic.ts,index.ts}
- backend/supabase/tests/database/0031_media_upload_auth.test.sql (17 assertions)
- backend/test/media-upload-authorize.test.mjs (5 tests)

## Commands run for this phase (actual results)
- `verify-db` (isolated) -> `ok   0031_media_upload_auth.test.sql (17 tests)`
- `node --test backend/test/media-upload-authorize.test.mjs` -> `pass 5` (in the combined run below `tests 71, pass 71`)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Authorize for current account, generated key, approved bucket, bounded size | request_media_upload has no path/name/key parameter (asserted via pg_get_function_arguments); path = <profile>/<uuid>; bucket from the class; MIME and 1..8388608 byte checks; 15 min expiry (asserted) | Pass |
| Reject caller-chosen ownership prefixes and cross-account overwrites | another account gets not_owner for the listing and null for the upload state; Edge body fields path/bucket/class/userId are ignored (node test) | Pass |
| Expired authorization fails at API | database: 0032 tests (expired window, late object); Edge: DB refusal mapped to stable statuses | Pass (API/DB) |
| Expired authorization / changed destination fails at the storage boundary | No client storage policy exists for quarantine (owner insert -> 42501), and the path is not a client input. Storage honouring the signed token only for that path and lifetime is UNVERIFIED | Partial, UNVERIFIED |
| Abuse limits | 30 issues/hour per account, 10 pending per listing, suspended listing refused, pipeline/intake flags off -> feature_disabled | Pass |

## Verification run (2026-10-08)
Baseline before any edit: `npm --prefix backend test` -> `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27, fail 0`; `node backend/scripts/rehearse-migrations.mjs` -> `Rehearsal: 26/26 checks passed (2000 synthetic providers).`

After phases 081-087 (media files overlaid on the git HEAD baseline, so other workstreams' in-flight files cannot interfere): `Migrations applied: 36/36`, `Tests: 30/30 files passed, 411/411 assertions passed. PASS`; `Rehearsal: 33/33 checks passed (2000 synthetic providers).`

Whole working tree at the end (includes other agents' uncommitted work): `Migrations applied: 44/44`, `Tests: 37/38 files passed, 581/582 assertions passed. FAIL` where the one failing file is `0042_location_consent.test.sql` (not part of this workstream); `node --test` -> `tests 71, pass 71, fail 0`; `Rehearsal: 41/41 checks passed (2000 synthetic providers).` `node backend/scripts/db-inventory.mjs` -> exit 0; the new objects add only the authenticated entry points `request_media_upload`, `get_media_upload`, `replace_provider_photo`, `set_photo_order`; every other new function is service-role only; the four new `private` tables show no anon/authenticated privilege.

## Migration / configuration effects
Forward-only migrations 20261008000030-36. New private tables only (no new column in `public`, so docs/contracts/column-classification.json is unchanged). New flags: `media_pipeline` (off), `media_cleanup` (on). The earlier owner-folder storage policies are kept for the pre-pipeline mode and neutralised by a restrictive policy once `media_pipeline` is on. Edge Functions: media-upload-authorize, media-process, media-gc (not deployed).

## Remaining uncertainty
- `createSignedUploadUrl` token lifetime and path binding are Supabase platform behaviour; the database does not rely on the token expiry (it rejects objects written after `expires_at` at processing time).
- Edge Function index.ts is not deployed or run; it uses the anon key for the caller-token RPC (SUPABASE_ANON_KEY is injected by the platform).
- Flutter follow-up: replace direct storage upload with authorize -> PUT with token -> media-process (lib/ not touched).

## Rollback / safe stop
Turn `media_pipeline` off (no uploads are issued; approved reads continue) and `media_cleanup` off (deletion pauses). Migrations are forward-only; no existing user data is modified.

## Next action
Deploy to the staging project and exercise the three-step flow with a real token; confirm a PUT to another path with the same token fails.
