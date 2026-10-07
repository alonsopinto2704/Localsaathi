# Phase 022 — Explicit public profile projection

**Status:** In review. Verified locally (PGlite); HTTP verification Blocked (phases 006/039). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Provide a public response distinct from owner data and built from an allowlist. Tie contact fields to current consent, so a future private column cannot leak through generic serialization.

## Changed paths
`backend/supabase/migrations/20261006000016_public_projection.sql`: new `public.public_profile_json()`. Every public read path now uses it.

## Before → after
- **Before:** public paths returned the **owner** JSON minus `moderationStatus`, which is a blocklist. As a result:
  - every new key became public automatically;
  - `phoneE164` was returned whatever the consent;
  - the exact map pin was public;
  - `verification.credentials` exposed `pending`/`rejected` states (independent audit, executed probe).
- **After:** every public key is named:
  - `id, displayName, baseCityId, baseLocalityId, status, createdAt, updatedAt`
  - `phoneE164` (only with current phone consent), `phoneDisplayConsented`, `whatsappEnabled` (only with phone consent)
  - `categoryIds` (launch-approved only), `serviceAreas, description, languages, workingHours`
  - `photos` {id, caption, remoteUrl, storagePath, isPlaceholder, uploadedAt}, `startingPrices` (approved categories only)
  - `healthcareDetails, homeVisits, availability`, `verification` (**approved states only**), `pinCodes`
  - `mapLocation` rounded to 2 dp (≈1 km)
- **Never public:** `user_id`, moderation status and reason, `revision`, `isPubliclyListed`, exact coordinates, credential evidence paths, pending or rejected verification.
- **Owner shape** (`provider_profile_json`): all keys kept, plus `revision` and `isPubliclyListed`.

## Verification
- `0007_public_projection` (9 assertions):
  - the public key set equals the allowlist exactly;
  - adding a `secret_note` column inside the test changes nothing publicly, including search results;
  - a rejected credential is hidden publicly but visible to the owner;
  - the map is rounded publicly and exact for the owner;
  - forbidden keys are absent.
- `0005_private_fields`: `moderationStatus` is absent from search and profile.
- HTTP pack self-test: a fake response carrying `phone_e164`/`moderationStatus` makes the pack FAIL (phase 039).
- Suite result: `node backend/scripts/verify-db.mjs` → `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Residual risk
`healthcareDetails.registrationNumber` and `clinicAddress` are public by design (business directory facts). Healthcare stays disabled at launch (phases 009/017). Confirm with counsel before enabling it.

## Rollback
Keep the tighter projection during any client rollback (plan rule). The Dart model ignores unknown keys.
