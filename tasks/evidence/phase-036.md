# Phase 036 — Append-only privileged audit

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Keep an attributable record of privileged decisions that clients cannot forge or erase, with a redaction rule. An action must fail if its audit record cannot be written.

## Changed paths
- Migration `…14`:
  - `private.audit_events`, `private.write_audit`, and an admin-grant trigger;
  - `public.admin_audit_events` (read path);
  - moderation and credential review rewritten to write audit rows. A suspension now requires a reason, and a review must decide approved or rejected.
- Migration `…15`: city and category activation are audited.
- Migration `…19`: listing deletion is audited.

## Design
- **Columns:** `actor_id` (`auth.uid()`), `actor_role`, `action`, target type and id, `reason`, `correlation_id`, and `details`. The correlation id comes from the `x-request-id` or `x-correlation-id` header, falling back to a generated uuid.
- **Same transaction.** The audit row is written in the same transaction as the action, so a failed audit insert rolls the action back.
- **Append-only.** UPDATE, DELETE and TRUNCATE raise an error for everyone. A superuser disabling triggers is outside the application's threat model and shows up in Postgres logs.
- **Not exposed.** No API role has grants on it, and the `private` schema is not exposed by PostgREST.
- **Redaction.** After UUIDs are stripped, any run of 10 or more digits in `details` or `reason` is refused, so phone numbers cannot enter the audit trail. The code review found the first version also rejected UUIDs with an all-digit last segment (about 0.35% of ids), which would have permanently blocked credential reviews for those providers. Fixed, and covered by `0014`.
- **Read path:** `admin_audit_events(limit ≤500, before_id)`, admin only.
- **Not an operational log.** This table records decisions. Edge Function and Postgres logs are separate and short-lived.

## Verification
- `0013` (15 assertions):
  - UPDATE, DELETE and TRUNCATE are refused;
  - anon and authenticated cannot select the table;
  - a non-admin calling `admin_audit_events` gets `not_owner`;
  - phone-like details are refused;
  - a suspension without a reason is refused;
  - deletion writes an audit row.
- `0010`: activation changes write audit rows.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Residual
Credential evidence exports and data-access exports (phase 249) must call `write_audit` when they are built.
