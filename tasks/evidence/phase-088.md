# Phase 088 Evidence - Private credential intake

**Status:** Done locally (database side). Live storage/CDN access, the signing Edge Function and the upload UI are NOT done or BLOCKED (no hosted Supabase). **Reviewer:** pending **Human sign-off:** pending

## Objective
Credential evidence is collected under a stated notice, kept in a private bucket, readable by the owner and by a credential reviewer only through a short-lived, logged path; support and other roles get nothing.

## Changed paths
- backend/supabase/migrations/20261008000040_credential_workflow.sql (intake columns, `private.credential_intake` trigger, `begin_credential_evidence_view`, access log, narrowed RLS, storage policy fix, per-bucket cleanup trigger, `purge_stale_credential_evidence`)
- backend/supabase/tests/database/0040_credential_workflow.test.sql
- backend/test/trust-contract.test.mjs
- docs/trust-and-credentials.md (sections 1-2: notice content, bucket contract, retention)
- docs/contracts/column-classification.json (11 new columns classified)

## Contract with the storage workstream (081-087)
Bucket `credentials-private`: private; path `<auth uid>/<file>`; owner insert/read/delete in own folder; **no policy for any administrator**; bytes reach reviewers only through a <= 60 s signed URL minted by a service-role Edge Function after `begin_credential_evidence_view` succeeds. This migration does not create the bucket or any policy on it. The cleanup queue takes `(bucket_id, exact path)`; the processor must accept `credentials-private`.

## Commands run (actual results, 2026-10-08)
| Command | Result |
|---|---|
| baseline `npm --prefix backend test` (before edits) | `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, Node `tests 27, pass 27` |
| baseline `node backend/scripts/rehearse-migrations.mjs` | `Rehearsal: 26/26 checks passed (2000 synthetic providers).` |
| after 088/089/090/091/093 `npm --prefix backend test` | `Migrations applied: 44/44`, `ok 0040_credential_workflow.test.sql (45 tests)`, `Tests: 38/38 files passed, 582/582 assertions passed. PASS`, Node `tests 41, pass 41, fail 0` (the tree also contains the concurrent media/identity suites) |
| `node backend/scripts/rehearse-migrations.mjs` | `Rehearsal: 41/41 checks passed (2000 synthetic providers).` |
| `node backend/scripts/db-inventory.mjs` | exit 0; the credential functions are executable by `authenticated` only, `expire_credential_decisions`/`purge_stale_credential_evidence` by `service_role` only; `private.credential_decisions`, `private.credential_access_log` have no API-role grants |

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Notice before upload | 0040: upload without `notice_version` -> `consent_required`; with it, row is `submitted` in `credentials-private` with an acknowledgement time. Wording is fixed in docs section 1 (client must display it) | Pass (DB); UI pending |
| Guest cannot retrieve evidence | 0040: anon -> 42501 on queue function and on `credential_records` | Pass |
| Other provider cannot | 0040: sees 0 rows; `get_credential_status` and `begin_credential_evidence_view` -> `not_owner` | Pass |
| Non-reviewer cannot | 0040: support-role admin -> `not_owner`, 0 rows; a different reviewer cannot open a case claimed by someone else; stale MFA -> `reauth_required`; claim required first | Pass |
| Old bucket no longer open to admins | 0040: credential reviewer sees 0 objects in `credential-evidence`; owner sees theirs | Pass |
| Access is logged | 0040: one `credential_access_log` row and one `credential_evidence_viewed` audit event per view; 60/hour limit | Pass |
| Revocation / cleanup | 0040: purged and owner-deleted credentials queue their exact object under their own bucket | Pass (queue); actual blob deletion BLOCKED |
| Real storage/CDN bytes, signed-URL TTL, no URL in logs | needs a hosted project and the Edge Function | BLOCKED |
| Synthetic images / malformed structures | not applicable at this layer (no upload pipeline here); EXIF/format checks belong to 083-084 | Not done |

## Assumptions and uncertainty
- Existing credential rows (none expected in production; intake flag is off) are re-queued: an old `approved` is no longer a badge, evidence moved to `evidence_bucket = 'credential-evidence'` until re-uploaded.
- GoTrue `aal`/`amr` claim shape is as assumed in phase 054 (unconfirmed on hosted).
- 0006 (anon allowlist) was edited by one entry (`get_trust_summary`); see phase-090.

## Rollback / safe stop
Set flag `credential_intake` off (stops new claims and resubmissions); `delete from private.admin_roles where role = 'credential_review'` revokes reviewers immediately. Forward-only migration; no irreversible step except dropping the old admin storage policy (re-add only with an explicit decision).

## Next action
Build the `credential-evidence-url` Edge Function and the `credentials-private` bucket policies (storage agent), then run the live access pack against it.
