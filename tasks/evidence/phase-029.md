# Phase 029 — Atomic profile mutations

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Validate the complete payload before changing anything, keep writes transactional, and make retries with side effects idempotent per owner.

## Changed paths
Migration `…17`: `private.validate_profile_payload` (shared), `register_profile`, `update_profile_full` and `private.idempotency_keys`.

## Implementation
- **Validation runs before any write:**

| Field | Rule |
|---|---|
| Display name | 1–80 characters |
| Description | ≤1000 characters |
| Languages | ≤10 |
| Categories | 1–10, must exist |
| Service areas | 1–20, in the base city |
| Working hours | ≤7 distinct weekdays, minutes 0–1439, open and close set together |
| Starting prices | ≤10, amount 0–1,000,000, one per category, note ≤140 |
| Photos | ≤5 |

  Type errors and unknown references map to `validation_failed` instead of raw Postgres errors (22P02/23503).
- **Each RPC is one transaction.** Any failure rolls everything back.
- **Idempotency:**
  - `register_profile` accepts an `idempotencyKey` of 8–64 characters.
  - The same key with the same payload returns the stored response and creates nothing.
  - The same key with a different payload returns `conflict`.
  - Keys are scoped per user and purged after 24 hours (`purge_expired_records`).
  - `update_profile_full` is a full replace, so retries converge without duplicate children.

## Verification
- `0008`:
  - an invalid locality in an update leaves categories **and** hours unchanged (an injected failure preserves the prior profile);
  - an identical retry returns identical JSON and produces one profile;
  - a changed payload under the same key returns conflict.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Rollback
Transaction rollback; the client keeps its draft.
