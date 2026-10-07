# Phase 030 — Optimistic concurrency control

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Add a revision precondition to owner edits, so two devices cannot silently overwrite each other's committed changes.

## Changed paths
- Migration `…15`: adds `provider_profiles.revision`, which the row trigger increments on every update.
- Migration `…17`: adds `expectedRevision` to `update_profile_full`'s patch and `p_expected_revision` to `set_listing_status`. Both are checked under `FOR UPDATE` in `lock_owned_profile`.

## Semantics
- **The precondition is optional,** for backward compatibility. A client that sends it gets `conflict: revision_mismatch (you have X, current is Y)` when its snapshot is stale. The owner JSON returns `revision`.
- **Mergeable fields:**
  - The availability toggle (`set_availability`) has no precondition. Last write wins, which is harmless.
  - For everything in `update_profile_full`, sending the precondition is recommended. On a conflict the client re-fetches and asks the user.
- **Moderation:** owners cannot change moderation fields at all (the trigger enforces this), so a stale owner form cannot undo a suspension. Admin moderation locks the row.
- **Backfill:** the phone backfill in `…15` disables user triggers, so it does not bump revisions. The phase 037 rehearsal asserts this.

## Verification
- `0009`:
  - a stale revision returns `conflict`;
  - the current revision succeeds and increments the counter.
- Suite: `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Follow-up
The Flutter adapters (phase 061+) must send `expectedRevision` from the owner JSON and handle the conflict in the edit UI.
