# Backend pgTAP tests

Run with (no Docker needed; PGlite + pgTAP, see `backend/scripts/verify-db.mjs`):

```bash
npm --prefix backend test
```

Convention: `*.test.sql` files are pgTAP suites (one session each, must meet
their plan; any error, missing/short plan or failed assertion exits nonzero).
Any other `.sql` here (`0000_helpers.sql`) is setup, loaded once before the
suites. Helpers `tests.moderate_as_admin` (moderation changes through the real
admin gate) and `tests.share_fixture` (grants a temp fixture table to the
switched API roles) exist so fixtures never disable triggers or RLS.

The same files are also written for `supabase test db`:

```bash
supabase test db
```

These need a local Supabase stack (`supabase start`), which needs Docker.
**Against a full Supabase stack they have not been executed (Phase 006); the PGlite runner above is what has run them** (no Docker/Supabase CLI/psql were available there — see
`backend/README.md`). They are written against the documented shape of
`auth.users` and the standard Supabase pgTAP RLS-testing pattern
(`set local role authenticated; set local request.jwt.claims = '...'`), but
that `auth.users` fixture insert is the one part most likely to need a small
adjustment if your local Supabase image's Auth schema has drifted (an extra
NOT NULL column, etc.) — if a test file fails on the fixture insert rather
than on an assertion, fix the insert's column list first.

Each file is self-contained (creates its own fixture rows, runs in its own
transaction, rolls back) so they can run in any order.

| File | Covers (from the brief's TESTING section) |
|---|---|
| `0001_phone_uniqueness.test.sql` | Equivalent phone formats resolve to one identity (via the client's `PhoneUtils`, exercised at the DB boundary by the UNIQUE constraint); concurrent duplicate creation rejected |
| `0002_ownership_and_publication.test.sql` | Unauthorized profile edits rejected; suspended/paused profiles excluded from public search; providers found through service areas (not just base locality) |
| `0003_credentials_and_promotions.test.sql` | Provider self-verifying credentials rejected; provider granting themselves a paid placement rejected |
| `0004_city_activation_and_deletion.test.sql` | Inactive cities reject new public listings; account/listing deletion removes public visibility |
| `0005_private_fields.test.sql` | Private fields (moderation status, suspension reason) excluded from public-facing responses |
