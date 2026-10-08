# Phase 089 Evidence - Credential decision workflow

**Status:** Done locally (database side); reviewer console UI and hosted behaviour not done. **Reviewer:** pending **Human sign-off:** pending

## Objective
Credentials move through submitted, reviewing, needs-information, approved, rejected and expired with an authorized reviewer, source reference, rationale and validity period; every badge has a current attributable decision; providers cannot approve themselves; AI cannot grant.

## Changed paths
- backend/supabase/migrations/20261008000040_credential_workflow.sql (`private.credential_decisions`, `list_credential_queue`, `start_credential_review`, `decide_credential`, `withdraw_credential_decision`, `expire_credential_decisions`, `get_credential_status`, `resubmit_credential`; `record_credential_review` now only errors)
- backend/supabase/tests/database/0040_credential_workflow.test.sql
- backend/test/trust-contract.test.mjs
- docs/trust-and-credentials.md (section 2)

## Commands run (actual results, 2026-10-08)
See phase-088.md for the baseline and final runs. This phase's suite: `ok 0040_credential_workflow.test.sql (45 tests)`; full: `Tests: 38/38 files passed, 582/582 assertions passed. PASS`; Node `tests 41, pass 41, fail 0`.

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Authorized reviewer only | 0040: support role -> `not_owner`; moderation-equivalent roles cannot decide; stale MFA -> `reauth_required`; unclaimed case -> `conflict` | Pass |
| Source reference, rationale, validity required | 0040: approval without source -> `validation_failed`; validity > 3 years refused; short rationale refused; the table `check` repeats it. Claimed date cap and healthcare registry rule are in the function (healthcare/claimed-date branches have no dedicated test) | Pass / partly untested |
| Providers cannot approve themselves | 0040: column grants block `review_state`/`status` (42501); a reviewer who owns a listing gets `not_owner` on their own case and does not see it in their queue | Pass |
| Each badge has a current attributable decision | 0040: decision row carries reviewer id, source type, validity; public `credentials` badge appears only with it (0041 also proves a bare "approved" `verification_records` row shows nothing) | Pass |
| Needs-information round trip | 0040: reviewer asks, owner sees state and note, resubmits, case returns to `submitted` | Pass |
| Withdrawal and expiry | 0040: withdrawn badge disappears at once; a lapsed decision has no badge before the expiry job and the job sets `expired` (returns 1) | Pass |
| AI cannot grant | no function other than the human reviewer RPCs writes decisions; `reviewer_id` is a not-null FK to `auth.users`; no service-role decision function exists | Pass (by construction) |
| Registry checks cannot be replaced | healthcare categories require `registry` or `registry_and_document`; non-healthcare registry requirements are a policy decision not encoded | Partial |
| Real storage/CDN behaviour | BLOCKED (see phase-088) | BLOCKED |

## Assumptions and uncertainty
- Decisions cascade-delete with the credential (data minimisation); the audit log keeps `credential_decided` events (ids and decision only, no free text, because `write_audit` rejects phone-like numbers).
- A reviewer account cannot be deleted while it has decisions (FK without cascade); admins are deactivated, not deleted.
- Four-eyes approval is not required (single reviewer); the claim-then-decide rule only prevents two reviewers deciding one case.

## Rollback / safe stop
Withdraw disputed badges with `withdraw_credential_decision`; the public badge is computed live, so withdrawal and expiry act at once. Hide the whole category by turning the `credential_intake` flag off and not granting the role.

## Next action
Admin console screens for the queue and decision form; schedule `expire_credential_decisions` and `purge_stale_credential_evidence` daily; add dedicated tests for the healthcare registry rule and the claimed-date cap.
