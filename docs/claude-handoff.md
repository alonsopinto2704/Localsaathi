# Backend handoff

Written by Claude (backend developer/reviewer role), working alongside
Google Antigravity (Flutter interface/flows). See
[docs/backend-contract.md](backend-contract.md) for the full API/data
contract this summarizes.

## 1. What was implemented

A complete Supabase (Postgres + Auth + Storage) backend for LocalSaathi,
designed to be a drop-in implementation of the repository interfaces
Antigravity already defined under `lib/domain/repositories/` — no change to
any file under `lib/` was made or is required for this backend to work.

- Full relational schema: locations (country → state → city → locality,
  with per-city launch status), service taxonomy, provider profiles and
  every child table (categories, service areas, working hours, photos,
  starting prices, healthcare details), consent/verification/credential
  trails, reports, engagement events, promotions, subscription plans.
- Identity built on Supabase Auth's native phone OTP rather than a custom
  OTP system — `auth.users` *is* the account; `provider_profiles.user_id`
  being `UNIQUE` is the entire "one phone = one account = one profile" rule.
- Row Level Security on every table — the actual server-side enforcement of
  every access-control rule in the brief, not just documentation of intent.
- A set of Postgres functions (SQL/PL/pgSQL, called via Supabase RPC) for
  search, registration, atomic profile updates, and the handful of
  admin-only actions (credential review, moderation, promotions).
- One Edge Function (`delete-account`) — the only place a privileged
  service-role key is used, and the only piece of "server code" that isn't
  SQL.
- A generator script that derives the location/category seed data directly
  from Antigravity's own `lib/data/seed/location_seed.dart` and
  `category_seed.dart`, so ids stay byte-for-byte identical on both sides.
- pgTAP tests for the scenarios the brief lists under TESTING.
- This contract/handoff documentation.

**Everything above is written, not executed.** The environment this was
built in has Python 3.11 and Node 24 but no Docker, no Supabase CLI and no
`psql` (confirmed by trying each — see `backend/README.md`). Nothing here
has touched a real database. Treat it as a careful first draft that needs a
real `supabase start` + `supabase test db` run before you trust it.

## 2. Files changed/added

Nothing under `lib/`, `android/`, `test/`, `tool/`, `pubspec.yaml` or
`analysis_options.yaml` was touched. Everything new:

```
backend/
  README.md
  scripts/generate_seed_sql.py
  supabase/
    config.toml
    migrations/20260101000001_extensions.sql … 20260101000011_storage.sql
    seed.sql                                    (generated)
    functions/delete-account/index.ts
    tests/database/README.md, 0000_helpers.sql, 0001…0005_*.test.sql
docs/
  backend-contract.md
  claude-handoff.md   (this file)
```

## 3. Running the backend locally

See `backend/README.md` for full detail. Short version, on a machine with
Docker Desktop and the Supabase CLI installed:

```bash
cd backend
supabase start        # prints local API URL + anon/service keys
supabase db reset      # applies migrations + seed.sql
supabase test db       # runs the pgTAP suite
```

## 4. Environment variables (names only, no secrets exist)

| Name | Used by | Notes |
|---|---|---|
| `SUPABASE_URL` | Flutter app | from `supabase start` locally; project settings once hosted |
| `SUPABASE_ANON_KEY` | Flutter app | safe to ship — RLS is the real boundary |
| `SUPABASE_SERVICE_ROLE_KEY` | `delete-account` Edge Function only | set via `supabase secrets set`; never in the app |

No production Supabase project, no production SMS provider account, and no
payment provider account were created or configured — none of that was
needed for this scope, per "do not provision paid resources... without
explicit instruction."

## 5. Migrations and seed instructions

Migrations run in filename order (`20260101000001_...` through
`...000011_storage.sql`) via `supabase db reset` or `supabase db push`
(hosted). `backend/supabase/seed.sql` is **generated** —
re-run `python backend/scripts/generate_seed_sql.py` after Antigravity edits
either `lib/data/seed/location_seed.dart` or `category_seed.dart`, then
re-apply. Do **not** hand-edit `seed.sql`.

One concrete thing already caught by this generate-don't-transcribe
approach: `category_seed.dart`'s group ids/descriptions changed mid-session
while this backend was being built (from `home-repair`/7 groups to
`home-repairs`/6 groups, etc.) — the generator picked up the live file
automatically; nothing had to be manually reconciled.

## 6. Tests run and their results

**Not run.** Written as pgTAP (`backend/supabase/tests/database/*.test.sql`)
covering every scenario listed in the brief's TESTING section — see the
table in `backend/supabase/tests/database/README.md` for which file covers
which scenario. Run `supabase test db` after `supabase start` to actually
execute them. The part most likely to need a small fix for your exact local
Postgres/Auth image version is the `auth.users` fixture insert in
`0000_helpers.sql` (`tests.create_phone_user`) — if a test fails on that
insert rather than on an assertion, add whatever `NOT NULL` column it's
missing.

The existing Flutter test suite (`test/localsaathi_core_test.dart`, run
against the mocks) was not touched and was not re-run here — this
environment has no Flutter SDK either (`flutter`/`dart` are not on `PATH`).
It should be unaffected: no file it imports was changed.

## 7. Integration steps for Antigravity

1. Add `supabase_flutter` to `pubspec.yaml` (not added here — that file is
   explicitly Antigravity's/the user's to edit while onboarding is in
   progress).
2. Write new concrete classes implementing the *existing* interfaces —
   `SupabaseProviderAuthRepository implements ProviderAuthRepository`, etc.
   — following the call mapping in `docs/backend-contract.md` §3/§6/§13. Do
   not change the interfaces themselves except the one proposed addition in
   §8 of that contract (`ProviderQuery.offset`), and only if you want
   pagination now rather than later.
3. Wire them into `lib/app/app_dependencies.dart` behind a flag/second
   factory (e.g. `AppDependencies.supabase({...})` alongside the existing
   `AppDependencies.mock(...)`), so the mock path keeps working for anyone
   not ready to point at a live project yet.
4. Point the app at a local `supabase start` stack first
   (`SUPABASE_URL`/`SUPABASE_ANON_KEY` from its output) before ever touching
   a hosted project.
5. Read `docs/backend-contract.md` §11 for the error-code mapping your
   repository implementations need to translate `PostgrestException` into
   the existing `RepositoryException`/`DuplicatePhoneNumberException` types
   screens already catch.

## 8. Remaining blockers and production work

- **Nothing here has been run against a real Postgres instance.** This is
  the biggest open item: get Docker + the Supabase CLI, run the three
  commands in §3, and fix whatever the first real run surfaces.
- **Production SMS delivery for phone OTP is an open decision**, not
  configured: Supabase Auth supports Twilio, Twilio Verify, MessageBird,
  Vonage, or a community TextLocal integration, or a custom "Send SMS Hook"
  that can call any provider (e.g. MSG91/Gupshup). India's TRAI DLT SMS
  regulations are a real operational concern for whichever provider is
  picked — this needs your decision and is not required for any local
  development work. (Verified against supabase.com/docs/guides/auth/phone-login
  on 2026-10-04; the DLT point is the documentation's own caution, not
  independently verified beyond that.)
- **Retention after deletion is unresolved, not claimed compliant** — see
  `docs/backend-contract.md` §4.6/§9. If consent-record retention after a
  listing is deleted turns out to matter legally, that needs a real schema
  change (a non-cascading audit table) and legal review, not an assumption
  baked into this schema.
- **Photo storage flow is designed but not exercised**: the `provider-photos`
  bucket + RLS policies exist (`0011_storage.sql`), but no code has actually
  uploaded a file through it.
- **No admin UI.** Granting admin is a manual `INSERT INTO app_admins` from
  the Supabase SQL editor; moderation/credential-review/promotion actions
  are callable (RPC/table writes) but have no screen anywhere — "a full
  admin dashboard is outside scope," per the brief, so this is intentional,
  not a gap.
- **`ProviderQuery.offset` is a proposal, not applied** — see
  `docs/backend-contract.md` §8. The backend already accepts and defaults
  `p_offset` to `0`, so adding the field later is backward compatible.
- **Monetization stays presentation-only**, as instructed — `promotions` and
  `subscription_plans` are real tables an admin can populate, but there is no
  checkout, no entitlement, and no code path that could grant one.

## Message to paste into Antigravity

> The backend is in `backend/` (Supabase: Postgres + Auth + Storage), with
> the full contract in `docs/backend-contract.md` and a summary of what's
> done/blocked in `docs/claude-handoff.md`. Nothing under `lib/` was
> changed. When you're ready to wire up real data: add `supabase_flutter` to
> `pubspec.yaml`, implement the existing repository interfaces
> (`lib/domain/repositories/*.dart`) as new Supabase-backed classes per the
> call-by-call mapping in `backend-contract.md` §3/§6/§13, and register them
> in `app_dependencies.dart` alongside (not replacing) the current
> `AppDependencies.mock(...)` path. Run `supabase start` locally first — see
> `backend/README.md` — before pointing at anything hosted. One proposed
> interface change is flagged in `backend-contract.md` §8 (an optional
> `offset` field on `ProviderQuery` for pagination); it's optional and
> backward compatible, your call on timing.
