# Phase 026 — Concurrent identity uniqueness

**Status:** In review. Verified locally (PGlite); true multi-session concurrency was not exercised. · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Normalize phones to E.164 and keep identity unique under concurrency. Conflicts must be stable and must not enable enumeration. Duplicate payloads must never leave partial children or transfer ownership.

## Changed paths
- Migration `…15`: `private.normalize_e164`, a data backfill, the `provider_phone_is_e164` CHECK, and the rewritten auth sync trigger.
- Migration `…17`: the rewritten `register_profile`.

## Findings and fixes
- **Bug: phones were not E.164.** GoTrue stores `auth.users.phone` without the `+` (the stub documents this). The old `register_profile` and auth sync copied it verbatim, so every real registration would have stored a non-E.164 `phone_e164`.
  - Both paths now normalize.
  - A CHECK enforces `^\+[1-9][0-9]{7,14}$`.
  - The backfill is required: phase 037 showed the constraint fails on prior data without it.
- **Uniqueness.** The UNIQUE constraints on `provider_profiles.user_id` and `phone_e164` remain the arbiter. Under concurrency exactly one insert commits. The loser's `unique_violation` maps to `conflict:`, and its whole transaction rolls back, children included.
- **Enumeration.** The conflict is shown only to a caller who has already proved control of that phone by OTP, so it reveals nothing new.
- **Duplicate payloads.**
  - Duplicate `categoryIds`, `serviceAreaIds` and languages are de-duplicated.
  - Duplicate weekdays and duplicate starting-price categories are rejected (`validation_failed`).
  - Before, a duplicate raised a raw primary-key error.
- **Ownership.** `user_id` comes only from `auth.uid()`, and the trigger forbids changing it.
- **Missing verification record.** New registrants now get their phone `verification_records` row. Before, `register_profile` wrote none (independent audit finding).

## Verification
- `0001`: unique phone and unique user.
- `0008`:
  - a GoTrue-format phone `919000000801` is stored as `+919000000801`;
  - duplicate ids produce one child row each;
  - a second registration returns `conflict`;
  - the owner JSON shows `verification.phone = approved`.
- Rehearsal (phase 037): 2,000 old-format phones are normalized during the upgrade.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Not verified
Truly simultaneous sessions, because PGlite uses a single connection. Correctness rests on the UNIQUE constraints, which Postgres enforces across sessions. Re-run two parallel `register_profile` HTTP calls on the disposable stack (phase 006).
