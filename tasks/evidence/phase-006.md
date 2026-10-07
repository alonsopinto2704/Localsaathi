# Phase 006 Evidence - Full Supabase parity check

**Status:** Blocked

## Objective
Run a disposable full Supabase stack (GoTrue, PostgREST, Storage) beside PGlite and prove four behaviors over real HTTP with real role tokens: anonymous read, owner write, cross-owner denial, private-object denial.

## Prerequisites checked
- Phase 004: done in this change (5/5 suites, 17/17 assertions via PGlite), pending review.
- `docker --version` -> `docker: command not found`; `C:\Program Files\Docker` absent.
- `npx --no-install supabase --version` -> `npx canceled due to missing packages` (CLI not installed; not installed here per instructions). `psql` also not on PATH.
- **Executed: nothing against a full stack. All HTTP checks below are unexecuted.**

## Blocker
- **Missing dependency:** Docker Desktop (WSL2 or Hyper-V enabled) and Supabase CLI (2.x; `npx supabase`, scoop, or dev dependency).
- **Owner:** user (installs Docker Desktop; needs admin + virtualization), with the integration engineer for CLI version pinning.
- **Next action:** install Docker Desktop, then run the sequence below. Alternative without local Docker: a throwaway cloud Supabase project (needs user account and cost decision; not created).

## Changed paths
None (evidence only).

## Ready-to-run command sequence (repo root)
```bash
docker --version && npx supabase --version
cd backend
npx supabase start                                   # applies migrations/ + seed.sql on a clean local stack
npx supabase status -o env > /tmp/sb.env && source /tmp/sb.env   # API_URL, ANON_KEY, SERVICE_ROLE_KEY, JWT_SECRET
npx supabase test db                                 # the same 5 pgTAP suites on real Postgres/auth/storage schemas
```
Parity diff to record on PGlite and the stack: `select version(); show timezone; select extname, extversion from pg_extension;`, `has_table_privilege` for anon/authenticated on public tables, and `auth.users` columns versus `scripts/supabase-stub.sql`.

## The 4 HTTP checks — executable script
**Superseded by `backend/scripts/http-authz-pack.mjs` (Phase 039), which is the runnable version of this plan** (`--self-test` passes offline). Once the stack above is up, export `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OWNER_JWT`, `OTHER_JWT`, `ADMIN_JWT`, `OWNER_PROFILE_ID`, `HIDDEN_PROFILE_ID`, `OWNER_USER_ID` (from `supabase status -o env` and two GoTrue sign-ins), then run `node backend/scripts/http-authz-pack.mjs`. It refuses to run with a service-role key and covers anon read/denial, direct-PATCH denial (writes go through RPCs since migration 0013), cross-owner denial and private-object (credential-evidence) denial. One check this plan has and the pack does not: a positive owner Storage upload to `provider-photos/<A>/`.

The original prose plan is kept below for history; where it says owners may `PATCH provider_profiles` directly, that predates migration `20261006000013_privilege_hardening.sql` (direct table writes are now denied).

Create two users via the GoTrue admin API (SERVICE_ROLE_KEY, `phone_confirm: true`, synthetic phones `+919000000101` and `+919000000102`), sign each in to get JWTs `$A` and `$B`. Then:

1. **Anonymous read.** `curl "$API_URL/rest/v1/rpc/search_providers" -H "apikey: $ANON_KEY" -H 'content-type: application/json' -d '{"p_city_id":"<seeded active city>","p_locality_id":"<seeded locality>"}'` -> 200, items present, no `moderation_status`/`suspension_reason`/credential fields in the JSON. `GET /rest/v1/app_admins` and `/rest/v1/consent_records` as anon -> 401/403 or `[]`.
2. **Owner write.** As A: `POST /rest/v1/rpc/register_profile` (Bearer `$A`, valid submission with `phoneDisplayConsented:true`) -> 200. `PATCH /rest/v1/provider_profiles?user_id=eq.<A>` with `{"description":"x"}` and `Prefer: return=representation` -> 200 with 1 row. `POST /storage/v1/object/provider-photos/<A>/p.jpg` -> 200.
3. **Cross-owner denial.** As B: `PATCH .../provider_profiles?id=eq.<A profile id>` -> 200 with `[]` (RLS zero rows), follow-up read shows value unchanged. `PATCH` of `moderation_status` on B's own row -> `not_owner` error. Upload to `provider-photos/<A>/x.jpg` -> 403/RLS violation. Insert into `promotions` -> RLS error.
4. **Private-object denial.** A uploads `credential-evidence/<A>/doc.pdf` -> 200. Anon `GET /storage/v1/object/public/credential-evidence/<A>/doc.pdf` -> 400/404. B `GET /storage/v1/object/authenticated/credential-evidence/<A>/doc.pdf` -> 400/403/404. A -> 200. `POST /storage/v1/object/list/credential-evidence` as B returns `[]`.

Also record service-role behavior: `GET /rest/v1/app_admins` with SERVICE_ROLE_KEY -> 200 (expected; key must never ship in a client).
Cleanup: delete only the fixtures with phones `+919000000101/102` (GoTrue admin delete), then `npx supabase stop --no-backup`.

## Already covered at SQL level (Phase 004 suites) vs. needs HTTP
| Check | SQL-level coverage today | Genuinely needs HTTP/stack |
|---|---|---|
| Anonymous read | 0002 (anon role calls `search_providers`; suspended/paused excluded), 0005 (private fields excluded) | PostgREST grants and exposed schemas, wire JSON shape, anon denial on tables |
| Owner write | 0004 (`register_profile` as authenticated), 0003 (credential insert as owner). No direct owner `UPDATE` success test | Real GoTrue JWT claims, PostgREST role switch, Storage upload |
| Cross-owner denial | 0002 (intruder update affects zero rows), 0003 (promotions insert denied; credential status forced pending) | Same with real tokens; Storage cross-folder upload |
| Private-object denial | None (no suite touches `storage.objects` policies) | Storage API, `public=false` bucket behavior, authenticated URLs; a SQL suite on the stub's `storage.objects` could be added but only HTTP proves platform behavior |

## Findings
- Docker and Supabase CLI are absent, so parity cannot be shown here. Known PGlite differences are documented in `backend/scripts/supabase-stub.sql` (superuser session user; GoTrue/Storage schemas are modelled, not real).
- Gap: no automated test of `storage.objects` policies; recommend a small `0006` suite plus HTTP check 4.

## Security/privacy effect
None (no execution). Plan uses synthetic users only; SERVICE_ROLE_KEY stays in the local shell.

## Residual risks
Real-platform authorization (JWT handling, PostgREST grants, Storage) is unverified; passing PGlite suites does not prove it.

## Rollback
Nothing changed. After a future run: `npx supabase stop --no-backup`.

## Next integration action
User installs Docker Desktop (or connects a disposable cloud project); integration engineer runs the boot sequence plus `node backend/scripts/http-authz-pack.mjs`, records outputs here and in phase-039.md, and moves status to In review.

## 2026-10-07 audit follow-up
See `tasks/evidence/audit-2026-10-07-followup.md`. Storage policies now have a pgTAP suite (`0016_storage_policies.test.sql`); platform serving behaviour still needs the HTTP pack.
