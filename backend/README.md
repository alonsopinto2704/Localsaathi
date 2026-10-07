# LocalSaathi backend

Supabase (hosted Postgres + Auth + Storage). See
[docs/backend-contract.md](../docs/backend-contract.md) for the API/data
contract and [docs/claude-handoff.md](../docs/claude-handoff.md) for what is
implemented vs. proposed vs. still needed.

**Not run or executed in the environment this was written in.** That
sandbox had Python 3.11 and Node 24 but no Docker, no Supabase CLI and no
`psql` (verified by trying each). Everything below is standard, carefully
written SQL/Deno, but you are the first one to actually run it — do that
before trusting it against real data.

## Prerequisites (on your own machine)

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — local Postgres runs in it.
- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started) — `npm install -g supabase` or `scoop install supabase` on Windows.

## Running locally

```bash
cd backend
supabase start          # first run pulls Docker images; prints local URLs + anon/service keys
supabase db reset        # applies every migration in supabase/migrations/, then supabase/seed.sql
```

`supabase start` prints a local Studio URL (Postgres GUI), an API URL, and
`anon`/`service_role` keys for `http://localhost:54321`. Point the Flutter
app's Supabase client at that URL + anon key for local development.

Re-apply after editing a migration or `seed.sql`:

```bash
supabase db reset
```

Regenerate `seed.sql` after Antigravity edits either Dart seed file:

```bash
python scripts/generate_seed_sql.py
```

## Phone OTP in local development

No SMS provider is configured or needed locally. The Supabase CLI's local
Auth server intercepts outgoing OTPs instead of sending a real SMS — check
`supabase status` / the CLI's logs for the code it "sent", or use the fixed
test number/code in `supabase/config.toml` (`[auth.sms.test_otp]`). This
config block's exact syntax should be double-checked against
`supabase --version`'s own `supabase config` docs if `supabase start`
complains about it — the CLI's config schema has changed between versions
and this was written without being able to run the CLI to confirm it.

**Production phone OTP delivery is not configured and needs a decision before
launch** — see docs/claude-handoff.md, "Remaining blockers," for the
Twilio-Verify vs. India-DLT-compliant-provider (MSG91/Gupshup via a custom
Send SMS Hook) tradeoff. This does not block any local development work.

## Running the test suite

```bash
supabase test db
```

Needs the local stack running (`supabase start`). See
`supabase/tests/database/README.md` for what each file covers and the one
part (`auth.users` fixture columns) most likely to need a tweak for your
exact local Postgres/Auth image version.

## Project layout

```
backend/
  README.md                  -- this file
  scripts/
    generate_seed_sql.py      -- regenerates seed.sql from the Flutter seed files
  supabase/
    config.toml               -- local dev stack config
    migrations/               -- schema, RLS, functions, storage (run in filename order)
    seed.sql                  -- GENERATED, do not hand-edit (see script above)
    functions/
      delete-account/         -- Edge Function: the one place a service-role key is used
    tests/database/           -- pgTAP tests (see its own README)
```

## Environment variables

**Flutter app** (read via `--dart-define` or a `.env` not committed to the
repo — follow whatever convention Antigravity's project already uses):

| Name | Where it comes from |
|---|---|
| `SUPABASE_URL` | `supabase start` output locally; project settings once hosted |
| `SUPABASE_ANON_KEY` | same |

The anon key is safe to ship in the compiled app — it has no special
privileges beyond what RLS grants to the `anon` role, which is exactly what
every policy in this schema was written to assume.

**Edge Function** (`delete-account`), set via `supabase secrets set` once a
project exists, never committed:

| Name | Notes |
|---|---|
| `SUPABASE_URL` | the project's API URL |
| `SUPABASE_SERVICE_ROLE_KEY` | **never** put this in the Flutter app or any client-readable config |

No other secret exists yet. No payment, no production SMS provider, and no
production Supabase project have been created by this work — see
"Do not provision paid resources" in docs/claude-handoff.md.
