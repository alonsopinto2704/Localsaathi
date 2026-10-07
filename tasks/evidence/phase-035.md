# Phase 035 — Deletion and retained records

**Status:** In review. SQL is verified locally; the Edge Function has **not been executed** (no Deno or Supabase here). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Every data category must have a defined deletion, pseudonymization, retention or processor-request behaviour. Storage cleanup must be done explicitly, not assumed to follow from SQL cascades.

## Changed paths
- Migration `…19`:
  - reports survive deletion as snapshots;
  - `private.storage_cleanup_queue` (new);
  - a BEFORE DELETE trigger on `provider_profiles`;
  - `private.purge_expired_records` (new);
  - `public.mark_storage_cleaned` (service role only).
- `backend/supabase/functions/delete-account/index.ts`:
  - identifies the caller with `auth.getUser(jwt)`;
  - removes the caller's objects in `provider-photos` and `credential-evidence` **before** deleting the auth user (the old function removed none), so a failure leaves the account intact and retryable;
  - marks the queue rows done;
  - stops returning raw error messages to the client.

## Data map
| Data | On listing or account deletion | Retention |
|---|---|---|
| Profile, categories, areas, hours, photo rows, prices, healthcare details, consents, verifications, credentials, engagement, promotion interest | Cascade delete | None. Whether to keep consent history needs counsel (phase 248). |
| Storage objects (photos, evidence) | delete-account removes them. A plain `delete_listing` queues the prefix for the lifecycle job (Workstream 5). | Until processed |
| Reports about the listing | Kept. `provider_id` becomes null and `provider_snapshot` holds {displayName, baseCityId, deletedAt}. Admin-only. Deleting an account therefore cannot erase abuse evidence. | 180 days, then purged |
| Reporter phone and source hash | — | Cleared after 90 days |
| Audit events | A `listing_deleted` row is written, with a by_owner flag | Kept. Holds ids and enums only, no contact data. |
| Idempotency keys / rate-limit windows | — | 24 hours / 2 days |
| Device data (drafts, bookmarks) | **Not cleared today** | Phase 049/051. Reproduced by `test/account_switch_draft_test.dart`. |
| Supabase backups | Not rewritten | Provider's backup retention. The restore runbook must re-apply deletions (phases 273/274). |
| Website and AI copies | Do not exist yet | Must read live or purge on revoke (phases 141+, 181+) |

## Verification
- `0013`:
  - deletion keeps the report and fills its snapshot;
  - two cleanup prefixes are queued;
  - the audit row is written;
  - the purge removes a 181-day-old orphan report and clears a 91-day-old reporter phone.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Not verified
- **The Edge Function is unexecuted.** It needs a deploy and run against a disposable project (depends on phase 006). It assumes the flat `<uid>/<file>` layout, so nested folders are not listed.
- **Purge scheduling.** `purge_expired_records` still needs a schedule (pg_cron or a scheduled function). That is a deployment task.
