# LocalSaathi backend contract

Status key used throughout this document:
- **Done** — implemented in `backend/supabase/migrations/`, written but not
  executed (no Docker/Supabase CLI in the environment this was written in —
  see `backend/README.md`).
- **Proposed** — a change to a shared Flutter interface. Not applied to any
  file under `lib/`. Antigravity (or whoever owns that file) decides whether
  to make it.
- **Client-only** — needs no backend at all; satisfied by code that already
  exists (or should exist) purely on-device.
- **Removed** — a direct-table path the earlier version of this contract
  described. Migration `0013` revoked the grants; the call now fails over
  HTTP. Each is marked **REMOVED** below with its replacement RPC.

**Hardening revision (migrations `0013`-`0023`, plus the identity set `0024`-`0029` described in section 3.0, phases 021-040 and the 2026-10-07 audit follow-ups).** Every
client write to provider data and every guest submission now goes through an
owner-checked or rate-limited `SECURITY DEFINER` RPC. Tables and functions are
closed by default (`0013`); a client can only call what is listed in this
document. The HTTP-level regression pack is
`backend/scripts/http-authz-pack.mjs` (`tasks/evidence/phase-039.md`).

## 1. Architecture

**Backend: Supabase** — hosted Postgres + Auth (phone OTP) + Storage.
Chosen over a hand-rolled API server because every requirement in the brief
maps onto something Supabase already does natively:

| Requirement | How Supabase covers it |
|---|---|
| Flutter compatibility | Official `supabase_flutter` package |
| Indian phone OTP | Auth's native phone sign-in (provider-agnostic SMS delivery — see §3 and the open question in `docs/claude-handoff.md`) |
| Relational data + search | Real Postgres: joins, `pg_trgm` text search, arrays, enums |
| Operating cost | Free tier: 500 MB DB, 50k MAU, 5 GB egress (verified against supabase.com/pricing on 2026-10-04) — comfortably covers a Mumbai-launch MVP |
| Maintenance burden (solo dev) | No server process to run/patch/scale; RLS replaces a hand-written authorization layer |

There is **no separate API server**. The Flutter client talks to Postgres
directly through Supabase's auto-generated REST (PostgREST) and RPC layer.
Row Level Security (RLS) policies are the actual enforcement of every access
rule in this document — "the backend" *is* the set of migrations in
`backend/supabase/migrations/`, run against a Supabase project. The one
exception is `backend/supabase/functions/delete-account/`, a small Edge
Function used only because deleting an `auth.users` row needs the
service-role key, which must never ship in the app.

**Unverified/needs your decision:** production SMS delivery for phone OTP to
Indian numbers (Twilio Verify vs. MSG91/Gupshup via a custom Send SMS Hook,
because of India's TRAI DLT regulations). See `docs/claude-handoff.md`,
"Remaining blockers." Local development needs none of this (§3.2).

## 2. Identity model

There is no `accounts` table. **A provider's account *is* their Supabase Auth
user** (`auth.users`, phone sign-in). `ProviderAccount`
(`lib/domain/models/account.dart`) is synthesized on read by `my_account()`
(§5) from `auth.users` + `provider_profiles`, not stored as its own row.

| `ProviderAccount` field | Source |
|---|---|
| `id` | `auth.users.id` |
| `phoneE164` | `auth.users.phone`, normalized to E.164 **with** a leading `+` (GoTrue stores it without; `private.normalize_e164`, `0015`) |
| `createdAt` | `auth.users.created_at` |
| `profileId` | `provider_profiles.id` (null if not yet registered) |
| `phoneVerifiedAt` | `auth.users.phone_confirmed_at` |
| `lastSignedInAt` | `auth.users.last_sign_in_at` |
| `isSuspended` / `suspensionReason` | `provider_profiles.moderation_status` / `.suspension_reason` |

**Why this satisfies the brief's identity rules without a custom OTP
system:** Supabase Auth owns the OTP code, delivery, expiry and attempt
limit. A client-submitted "phone verified" flag is never read anywhere in
this schema — the *only* fact this schema trusts is
`auth.users.phone_confirmed_at`, which only Supabase Auth itself can set
(after a correct code). `provider_profiles.user_id` is `UNIQUE NOT NULL
REFERENCES auth.users(id)`, which is the entire enforcement of "one account =
one profile" — a second `INSERT` for the same user hits a Postgres
`unique_violation`, including under concurrent requests, because that is
what a `UNIQUE` constraint is for.

## 3. Authentication flow (client-side, no new backend code)

`ProviderAuthRepository` (`lib/domain/repositories/auth_repository.dart`)
keeps its exact current shape. Here is how each method is satisfied by the
Supabase client SDK directly, with one implementation note:

| Method | Supabase call |
|---|---|
| `restoreSession()` | `supabase.auth.currentSession`, then `my_profile()` (§5) if signed in |
| `requestOtp(rawPhone)` | Normalize with the existing `PhoneUtils` (unchanged), then `supabase.auth.signInWithOtp(phone: e164)` |
| `verifyOtp({challengeId, code})` | See note below |
| `currentAccount()` | `my_account()` RPC |
| `currentProfile()` | `my_profile()` RPC |
| `registerProfile(submission)` | `register_profile(jsonb)` RPC (§6) |
| `requestPhoneNumberChange(rawPhone)` | `supabase.auth.updateUser(phone: newE164)` — Supabase's native phone-change flow, OTP sent to the *new* number |
| `confirmPhoneNumberChange({challengeId, code})` | `supabase.auth.verifyOtp(phone: newE164, token: code, type: phoneChange)`, then `my_account()` |
| `signOut()` | `supabase.auth.signOut()` |
| `deleteAccount()` | `supabase.functions.invoke('delete-account')` (§9), then local sign-out |

**Implementation note on `challengeId`:** Supabase's `verifyOtp` takes a
phone number, not an opaque challenge id — it has no server-side concept of
a "challenge" the way the mock's `OtpChallenge` does. **No interface change
is needed.** The concrete Supabase-backed repository (new Dart code, not
written here) generates its own local id at request time and keeps an
in-memory `{id: phoneE164}` map for the few minutes a user takes to type a
code — exactly the kind of local bookkeeping `MockProviderAuthRepository`
already does with `_phoneChangeChallenges`. `OtpChallenge.simulatedCode` is
simply left unused/empty in this implementation, consistent with its own
docstring ("DEVELOPMENT ONLY").

**Why `requestOtp` still never reveals whether a number is registered:**
`signInWithOtp` behaves the same way whether the phone belongs to an existing
or a brand-new `auth.users` row; `existingProfileId` only becomes
non-`null` after `verifyOtp` succeeds, by querying `my_profile()` — exactly
the mock's "verification is the gate" rule.

### 3.1 Two creation entry points, one backend path

`ProviderAuthRepository.registerProfile` and
`ProviderRepository.createProfile` have near-identical parameters today. Both
map to the same `register_profile()` RPC server-side — there is one creation
path in the backend regardless of which Dart method a screen calls. No
duplication, no interface change.

### 3.0 Identity controls (migrations 0024-0029, phases 041-060)

Live implementation: `lib/data/supabase/` (`SupabaseProviderAuthRepository`
over an `AuthGateway`; chosen by `LS_ENV=demo|staging|production`, fail-closed
when `SUPABASE_URL`/`SUPABASE_ANON_KEY` are missing in a non-demo build).
Behaviours the client now relies on:

| Area | Contract |
|---|---|
| Code delivery | Auth's Send SMS hook (`send-sms-hook`) calls `public.otp_send_gate(phone)` first: only `+91` mobiles, per-number, per-10,000-block and global limits, circuit breaker. Service role only. |
| `my_account()` | `phoneE164` is always E.164 with `+` (was GoTrue's `+`-less form until 0024). |
| Recent authentication | `public.request_sensitive_action(action)` (`phone_change`, `delete_account`, `export_private_evidence`) succeeds only if the token's `amr` shows an SMS/TOTP proof within 5 minutes, else `reauth_required:`. A grant lasts 10 minutes and is single use. |
| Phone change | Starting a change is blocked by an `auth.users` trigger unless a `phone_change` grant exists. When it commits, the profile keeps its owner, `phone_display_consented`/`whatsapp_enabled` reset, a published listing pauses, consent rows for the new number are written, and `phone_changed` is audited (no numbers). |
| Administrators | `is_admin()` = `app_admins` row + a role in `private.admin_roles` + `aal2`. Roles: `support`, `moderation`, `credential_review`, `infrastructure`. Sensitive admin RPCs also need a TOTP proof under 15 minutes old. Since 0050 every admin write/read surface is role-gated: moderation (`set_listing_moderation`, report queue), infrastructure (`admin_audit_events`, promotions, raw engagement events, admin list, city/category/flag RPCs), support (city requests, recovery), credential_review (`record_credential_review`). Reference data has no direct-write policy. |
| Recovery | `open_recovery_case`, `my_recovery_notices`, `dispute_recovery_case` (authenticated); `admin_recovery_queue`, `admin_review_recovery_case`, `admin_execute_recovery` (support role). 7-day wait, owner dispute freezes; the executor must differ from the approving reviewer (0051). |
| Deletion | `delete-account` Edge Function: body is `{idempotencyKey}` only; 403 `reauth_required`, 401 `not_authenticated`, 502 `delete_failed`; one job per user (`private.deletion_jobs`); 409 `deletion_in_progress` for a different key; resume after 10 minutes needs a fresh grant; `rpc('cancel_account_deletion')` abandons an unfinished job (0052). |
| New error prefix | `reauth_required:` -> `RepositoryErrorCode.reauthRequired`; transport/5xx -> `RepositoryErrorCode.unavailable` (client-side only). |

Operations: `docs/identity-operations.md`. SMS vendor: `docs/sms-provider-evaluation.md`.

### 3.2 Local development without a real SMS provider

`supabase start`'s local Auth server intercepts outgoing OTPs instead of
sending real SMS (see CLI logs / `supabase/config.toml`'s
a local-only `[auth.sms.test_otp]` block that is deliberately **not** in the committed `config.toml` — see `config.local-test-otp.toml.example`). No SMS account, no cost, no production credentials —
satisfying "proceed with local development work without requiring paid
services or production credentials" for this whole area.

## 4. Data model

All tables live in the `public` schema. Enum values are shown as the
Postgres `enum` labels (snake_case); the equivalent Dart enum is named next
to it.

### 4.1 Locations (`lib/domain/models/location.dart`)

| Table | Key columns | Notes |
|---|---|---|
| `countries` | `id` (text pk, e.g. `in`), `name`, `iso_code`, `dial_code`, `is_active` | |
| `state_regions` | `id` pk, `country_id` fk, `name`, `is_union_territory`, `is_active` | |
| `cities` | `id` pk, `state_id` fk, `name`, `launch_status`, `aliases text[]`, `is_metro` | `launch_status`: `active` \| `coming_soon` \| `inactive` ↔ `CityLaunchStatus` |
| `localities` | `id` pk, `city_id` fk, `name`, `pin_code`, `is_popular` | |
| `city_requests` | `id` uuid pk, `city_name`, `state_name`, `note`, `submitted_by_phone`, `requested_at` | |

`cities.launch_status = 'active'` is the single switch for "is this market
browsable and registerable" — changing one row activates Thane, Navi Mumbai
or Vasai-Virar with no code change on either side, matching the brief's
requirement exactly.

### 4.2 Service taxonomy (`lib/domain/models/service_category.dart`)

| Table | Key columns |
|---|---|
| `service_groups` | `id` pk, `name`, `icon_key`, `sort_order`, `description` |
| `service_categories` | `id` pk, `group_id` fk, `name`, `icon_key`, `sort_order`, `keywords text[]`, `is_healthcare`, `is_popular`, `is_approved_for_launch` |

### 4.3 Provider identity and listing (`lib/domain/models/provider.dart`)

`provider_profiles` — one row per provider, `id` uuid pk, `user_id` uuid
**unique** fk → `auth.users(id)`:

| Column | Type | Required | Notes |
|---|---|---|---|
| `phone_e164` | text, unique | yes | synced from `auth.users.phone`, never client-writable; CHECK `^\+[1-9][0-9]{7,14}$` (always E.164 with `+`) |
| `display_name` | text | yes | |
| `base_city_id` / `base_locality_id` | text fk | yes | locality must belong to the city (enforced by trigger) |
| `description` | text | no | |
| `languages` | text[] | no, default `{}` | |
| `home_visits` | boolean | no, default true | |
| `availability` | enum `available`\|`busy`\|`unavailable` | no, default `available` | ↔ `AvailabilityStatus` |
| `whatsapp_enabled` | boolean | no, default false | |
| `phone_display_consented` | boolean | no, default false | required to publish |
| `status` | enum `draft`\|`published`\|`paused` | no, default `draft` | ↔ `ListingStatus` (minus `deleted` — deletion is a row delete, see §4.6) |
| `moderation_status` | enum `active`\|`suspended` | no, default `active` | **admin-only to change**, never the provider |
| `suspension_reason` | text | no | admin-only |
| `pin_codes` | text[] | no, default `{}` | |
| `revision` | bigint | system, default 1 | bumped by trigger on every update; basis of `expectedRevision` (§6) |
| `created_at` / `updated_at` / `published_at` | timestamptz | system | |

Child tables (all `provider_id` → `provider_profiles(id) on delete cascade`,
owner/admin RLS only — see §7):

| Table | Purpose | Maps to |
|---|---|---|
| `provider_categories` | `(provider_id, category_id)` junction | `ProviderProfile.categoryIds` |
| `provider_service_areas` | `city_id, locality_id, is_primary, pin_codes` | `ProviderServiceArea` |
| `provider_working_hours` | one row per weekday (1=Mon..7=Sun), nullable open/close minutes | `WorkingHours`/`DayHours` — **zero rows = "hours not provided"** (`WorkingHours.hasAnyHours == false`); see §4.4 |
| `provider_photos` | `caption, storage_path, remote_url, is_placeholder, uploaded_at` | `ProviderPhoto` |
| `provider_starting_prices` | `(provider_id, category_id)`, `amount_rupees, note` | `StartingPrice` |
| `provider_healthcare_details` | one row per provider (pk = provider_id) | `HealthcareDetails` |

### 4.4 Working hours — one representation decision worth flagging

The Dart model's "not provided" sentinel is `WorkingHours.none()`, which is
**seven rows all closed**, not zero rows. The backend instead uses **zero
rows** to mean "not provided," and a provider who *has* set hours always has
exactly seven rows (a closed day still gets a row with `open`/`close` =
`null`, which is what lets `isOpenAt()` tell "closed today" apart from "no
hours exist at all"). The Dart repository implementation should treat
"0 working-hour rows returned" as `workingHours: null`/absent in the
`ProviderProfile` it builds (the JSON from `provider_profile_json()` already
does this — `workingHours` is `null` in the JSON when no rows exist), and
reconstruct `WorkingHours.none()` client-side only where the UI specifically
wants that sentinel object. This is a data-shape note, not an interface
change.

### 4.5 Trust, moderation, engagement, monetization

(`lib/domain/models/moderation.dart`) — `consent_records`,
`verification_records`, `credential_records`, `reports`,
`engagement_events`, `promotions`, `subscription_plans`,
`promotion_interest`, plus `app_admins` (the moderator allowlist — grant by
inserting a row from the Supabase SQL editor, not from the app). Field names
and enum values mirror the Dart model 1:1 (snake_case ↔ camelCase); see the
migration files for the exact column list of each.

### 4.6 `ListingStatus.deleted` → row deletion, not a status value

The Postgres enum `listing_status` has only `draft` \| `published` \|
`paused`. "Delete my listing"
(`ProviderRepository.deleteListing`/`ProviderAuthRepository.deleteAccount`)
is a `DELETE FROM provider_profiles`, which cascades to every child table.
This matches `MockProviderRepository.deleteListing` exactly (it removes the
map entry rather than tagging it `deleted`) and means a deleted number is
immediately free to register again, which is the documented behaviour.

Deletion is `rpc('delete_listing', {p_profile_id})` (owner only; admins act through moderation RPCs, not owner RPCs).

**Retention (migration `0019`, not a compliance claim):** the listing and its
children (consent, verification, credentials, engagement, ...) are deleted by
cascade; consent history is not kept. Reports about the listing are kept 180
days with a minimal snapshot (admin-only), reporter phone/source hash are
nulled after 90 days, audit events (`private.audit_events`, ids and enums
only) are kept, rate-limit rows 2 days, idempotency keys 24 hours. Storage
objects are not removed by SQL: a cleanup row is queued and processed by the
storage lifecycle job / `delete-account`. Whether India consent-record rules
need longer retention still needs legal review (`docs/claude-handoff.md`).

## 5. Reading a profile: two shapes, an allowlist and an owner builder

There are two JSON shapes. Never mix them.

| Shape | Builder | Who sees it |
|---|---|---|
| **Public** | `public_profile_json(id)` (not callable by clients; only via the functions below) | everyone, only for a listing where `is_publicly_listed(id)` |
| **Owner** | `provider_profile_json(id)` (not callable by clients; returned by the owner RPCs) | the owner or admin |

**Public shape = explicit allowlist** (a new column is private until someone
adds it to `public_profile_json`; the HTTP pack asserts no other key
appears): `id, displayName, baseCityId, baseLocalityId, status, createdAt,
updatedAt, phoneE164, phoneDisplayConsented, whatsappEnabled, categoryIds,
serviceAreas, description, languages, workingHours, photos, startingPrices,
healthcareDetails, homeVisits, availability, verification, pinCodes,
mapLocation`. Rules inside it:
- `phoneE164` is present only while `phoneDisplayConsented` is true; always
  `+`-prefixed E.164. `whatsappEnabled` is false whenever consent is off.
- `mapLocation` is **rounded to 2 decimal places (~1 km)** publicly; the owner
  shape returns the exact `{lat, lng}` (or `null`).
- `verification` lists only `approved` kinds; pending/rejected states are
  private. Category ids and prices only for categories approved for launch.
- Never present: `moderationStatus`, `suspensionReason`, `user_id`, `revision`,
  `isPubliclyListed`, any snake_case key.

**Owner shape** = the same fields plus `moderationStatus`, `suspensionReason`,
exact `mapLocation`, **`revision`** (bigint, for `expectedRevision`) and
**`isPubliclyListed`** (so an owner can see *why* a listing is not visible).

**One eligibility rule:** `is_publicly_listed(id)` = published + moderation
`active` + phone-display consent + city `launch_status = 'active'` + at least
one launch-approved category + at least one service area. Every discovery path
uses it, so withdrawing consent, deactivating a city or un-approving the last
category removes the listing on the next request.

| Call | Who | Returns |
|---|---|---|
| `get_public_profile(p_id)` | anyone | public shape, or JSON `null` (HTTP 200) if not publicly listed (draft, paused, suspended, unconsented, inactive city, unknown id are indistinguishable) |
| `get_owner_profile(p_id)` / `my_profile()` | owner or admin | owner shape, any status |
| `search_providers` / `similar_providers` / `providers_published_in_city` | anyone | public shape per result |

Direct table reads of `provider_profiles` and every child/trust table by
`anon` are **REMOVED** (no grant): they return a permission error, not zero
rows. Signed-in users may `SELECT` only their own rows (RLS); this is a
fallback, the RPCs above are the contract. `phone_e164` and
`suspension_reason` are never part of any public response.

## 6. Writing a profile

**There are no direct table writes for provider data.** `INSERT`/`UPDATE`/
`DELETE` on `provider_profiles` and all child tables are **REMOVED** for
`anon` and `authenticated` (`0013`); a `PATCH`/`POST`/`DELETE` to
`/rest/v1/<table>` fails with a permission error. Use only these RPCs:

| Operation | Call | Notes |
|---|---|---|
| Create (`registerProfile`/`createProfile`) | `rpc('register_profile', {p_submission})` | one transaction, whole payload validated first. Needs a verified phone (`not_authenticated` otherwise). Accepts optional **`idempotencyKey`** (8-64 chars, per user, kept 24 h): a retry with the same key and same payload returns the first response; same key with a different payload is `conflict`. Without a key a second call is `conflict: this account already has a profile`. |
| Full edit (`updateProfile`) | `rpc('update_profile_full', {p_profile_id, p_patch})` | atomic; keys present are replaced wholesale (`categoryIds`, `serviceAreas`, `workingHours`, `startingPrices`, `healthcareDetails`), scalars patched individually. Optional **`expectedRevision`** inside `p_patch`: if it differs from the row's current `revision` the call fails `conflict: revision_mismatch` and nothing is written. `phoneDisplayConsented`/`whatsappEnabled` changes are recorded as consent rows in the same transaction. Photos and map pin are separate. Returns the owner shape. |
| Publish / pause / draft (`publish`, `setListingStatus`) | `rpc('set_listing_status', {p_profile_id, p_status, p_expected_revision})` | `p_expected_revision` optional (same conflict rule). Publication rules run in the row trigger (consent, display name, verified phone, active city, approved category, service area, not suspended) and stamp `published_at`. **REMOVED:** `.from('provider_profiles').update({status})`. |
| Availability (`setAvailability`) | `rpc('set_availability', {p_profile_id, p_availability})` | **REMOVED:** direct `.update({availability})`. |
| Delete (`deleteListing`) | `rpc('delete_listing', {p_profile_id})` | **REMOVED:** direct `.delete()`. See §4.6. |
| Add a photo | upload to Storage bucket `provider-photos` at `{profile_id}/{filename}` (`[A-Za-z0-9._-]`, <=100 chars), **then** `rpc('add_provider_photo', {p_profile_id, p_storage_path, p_caption})` | the path must be in the profile's own folder (`<profile_id>/`, since 0022); no client URL is stored (build the public URL from `storagePath`); caption <=140; max 5 photos. **REMOVED:** inserting `provider_photos` rows. |
| Remove a photo | `rpc('delete_provider_photo', {p_photo_id})`, then delete the Storage object | **REMOVED:** direct row delete. |
| Map pin on/off | `rpc('set_map_location', {p_profile_id, p_lat, p_lng})` | owner-only; nulls withdraw it and record a `show_map_location` consent row. |
| Accept Terms | `rpc('record_terms_acceptance', {p_profile_id, p_version})` right after `register_profile` | records a `terms_accepted` consent row. |
| Consent | `rpc('record_consent', {p_profile_id, p_kind, p_granted, p_wording_version})` | owner only; applies the decision and appends evidence atomically. Withdrawing `display_phone_number` or `public_profile` pauses a published listing (never silently re-listed). `whatsapp_contact` granted without phone consent is `consent_required`. Map and terms use their own RPCs. **REMOVED:** `.insert()` on `consent_records`. |

Owner RPCs check `auth.uid()` inside the function (`not_owner` for another
user's profile, `not_found` for an unknown id). `private.lock_owned_profile`
is owner-only: admins get `not_owner` too and use the moderation RPCs. Each
owner RPC call bumps `revision` exactly once (0022), and an edit that would
leave a published listing without a launch-approved category or a service
area is refused with `validation_failed`.

**Feature flags (0022):** `rpc('get_client_flags')` returns `{key: bool}` for
hiding UI; the server is the boundary and raises `feature_disabled:` when a
gated action runs with its flag off (`media_intake` for `add_provider_photo`,
`credential_intake` for credential claims, `precise_location` for a map pin,
`provider_signup` for `register_profile`). `sponsored_placement` off makes
`active_promotions` return `[]`; `contact_reveal` off removes `phoneE164`
from public JSON. Admins change flags with `set_feature_flag(key, enabled,
reason)`, which is audited.

**Photo paths (0022):** upload to `provider-photos/<profile_id>/<file>` (was
`<user_id>/`), so public URLs never expose the owner's auth id.

**Guest and provider submissions (rate-limited, bounded):**

| Operation | Call | Notes |
|---|---|---|
| Report a listing | `rpc('submit_report', {p_provider_id, p_reason, p_details, p_reporter_phone})` | listing must be publicly listed (`not_found`); details <=1000; reporter phone normalized to E.164 or `validation_failed`; same source+listing within 24 h returns the same receipt; limits 5/h and 20/day per source, 50/day per listing -> `rate_limited`. Returns `{receiptId, status}`. **REMOVED:** `.insert()` on `reports`. |
| Engagement tap/view | `rpc('record_engagement', {p_provider_id, p_type, p_city_id, p_locality_id, p_category_id})` | returns nothing; unlisted ids and over-budget events are **dropped silently** (never `rate_limited`: a tap must not fail). **REMOVED:** `.insert()` on `engagement_events`. |
| Request a city | `rpc('request_city', {p_city_name, p_state_name, p_note})` | name 2-80, state <=80, note <=500; 5/day per source; `submitted_by_phone` is set server-side from the signed-in provider, never from input. Returns `{receiptId, status}`. **REMOVED:** `.insert()` on `city_requests`. |

The rate-limit "source" is `u:<user id>` or a daily-rotating hash of the edge
client IP: a throttle, not an identity.

**Admin RPCs** (each checks its administrator role, see §Administrators, -> `not_owner` otherwise; each writes
an append-only audit event in the same transaction):

| Operation | Call | Notes |
|---|---|---|
| Market activation | `rpc('set_city_launch_status', {p_city_id, p_status, p_reason})` | reason required. **REMOVED:** `.update()` on `cities`. |
| Category approval | `rpc('set_category_launch_approval', {p_category_id, p_approved, p_reason})` | reason required. **REMOVED:** `.update()` on `service_categories`. |
| Moderation | `rpc('set_listing_moderation', {p_provider_id, p_status, p_reason})` | **reason required to suspend** (`validation_failed`). |
| Credential review | `rpc('record_credential_review', {p_provider_id, p_credential_id, p_status, p_note})` | `approved` or `rejected` only. |
| Read audit trail | `rpc('admin_audit_events', {p_limit, p_before_id})` | newest first, limit clamped 1-500, keyset by `p_before_id`. Admin only; `anon` cannot execute it. |

**Still direct (granted to `authenticated`, RLS-gated):** `credential_records`
insert (claim fields only; status forced to `pending`) and delete, and
`promotion_interest`. Admin tools may also read `reports`, `engagement_events`,
`city_requests`, `app_admins` and write `promotions`.

**Deliberate backend-only hardening vs. the current mock:**
`register_profile()` enforces `location_not_active` for a non-active city and
the publish trigger enforces it again, even though `MockProviderRepository`
does not check it. The documented contract is authoritative. Covered by
`backend/supabase/tests/database/0004_city_activation_and_deletion.test.sql`.

## 7. Access control summary

Grants are the first barrier (default deny, `0013`), RLS the second, and the
function body's own `auth.uid()`/`is_admin()` check the third.

| Role | Can read | Can write |
|---|---|---|
| Guest (`anon`) | reference data (`SELECT`), and the public RPCs: `search_providers`, `get_public_profile`, `similar_providers`, `provider_count_by_locality`, `providers_published_in_city`, `active_promotions`, `search_cities`, `search_categories`. **No** table access to provider, consent, verification, report, engagement or admin tables. | only `submit_report`, `record_engagement`, `request_city` (RPC) |
| Signed-in provider (`authenticated`) | the above + own profile via `get_owner_profile`/`my_profile`/`my_account` (and own rows via RLS) | the owner RPCs in §6 on their own profile; direct `credential_records` claim insert/delete and `promotion_interest` |
| Admin (`app_admins` row; grant from the SQL editor only, audited) | everything via RLS `is_admin()` branches | the admin RPCs in §6, `promotions` |

Not executable by any client role: `provider_profile_json(_core)`,
`public_profile_json`, `is_publicly_listed`, every trigger function and
everything in the `private` schema (not exposed to PostgREST). `search_path`
is empty on every definer function. Account deletion for a signed-in user is
the `delete-account` Edge Function (§9).

This is enforced in Postgres itself, and verified over HTTP by
`backend/scripts/http-authz-pack.mjs`.

## 8. Search, pagination, filtering

`ProviderRepository.search(ProviderQuery)` → `rpc('search_providers', {...})`:

| `ProviderQuery` field | RPC parameter |
|---|---|
| `cityId` | `p_city_id` (required) |
| `localityId` | `p_locality_id` (required) |
| `text` | `p_text` |
| `categoryIds` | `p_category_ids` |
| `localityFilterIds` | `p_locality_filter_ids` |
| `openNowOnly` | `p_open_now_only` |
| `homeVisitsOnly` | `p_home_visits_only` |
| `limit` | `p_limit` |
| *(none today)* | `p_offset` — **proposed**, see below |

**Bounds** (violations raise `validation_failed`, except limit which is
clamped): `p_text` <= 80 characters (also for `search_cities` and
`search_categories`); at most 20 `p_category_ids` and 20
`p_locality_filter_ids`; `p_limit` clamped to 1-50 (default 20); `p_offset`
must be <= 500 ("refine the search"). User text is matched literally (`%`,
`_` and backslash are escaped, never LIKE wildcards).
`providers_published_in_city` is capped at 500 rows. Only listings passing
`is_publicly_listed` (§5) can match, so every result has consented phone
display and an active city.

Response: `{ "totalCount": number, "items": [{ "isSponsored": bool, "provider": {...public shape...} }] }`.
Sort: sponsored first (promotion priority), then photo count desc, category
count desc, name asc, id asc. (The old "phone-consent desc" key is gone: all
results are consented.)

**Working hours / "open now":** computed in `Asia/Kolkata` by one rule
(`private.hours_open`, mirrored by `WorkingHours.isOpenAt`). Weekday 1=Mon..7=Sun;
times are minutes since midnight (0-1439). A window with `close <= open` is
overnight and also covers the early hours of the **next** day (until `close`);
`close = 1439` means until midnight; a day with null open/close is closed;
**no rows at all means hours unknown: never "open now"**. Boundary cases are
the shared fixtures in
[`docs/contracts/fixtures/working-hours.json`](contracts/fixtures/working-hours.json),
driven from both Dart and `backend/scripts/verify-db.mjs`. Validation on write:
at most 7 days, each weekday once, open and close both set or both null.

**Proposed change** to `lib/domain/repositories/provider_repository.dart`'s
`ProviderQuery`: add an optional `int? offset` field (default `null`/`0`),
threaded through to `p_offset`, max 500. *Why:* `limit` alone cannot page past
the first page.

```dart
class ProviderQuery {
  const ProviderQuery({
    // ...existing fields...
    this.limit,
    this.offset, // new
  });
  final int? offset; // new
}
```

Until that lands, every caller behaves as today (`offset` defaults to `0`).

## 9. Account deletion

`ProviderAuthRepository.deleteAccount()` → `supabase.functions.invoke('delete-account')`
(see `backend/supabase/functions/delete-account/index.ts`). The function
checks the caller's own JWT, then calls the Auth Admin API to delete that
`auth.users` row, which cascades through `provider_profiles` and every table
beneath it (§4.6's retention caveat applies here too).

## 10. Things that stay entirely on-device (no backend call at all)

| Repository method | Why |
|---|---|
| `SavedProviderRepository` (all methods) | explicit requirement: "Keep customer favourites on-device for the MVP" |
| `ProviderDraftRepository` (all methods) | onboarding drafts are not listings; already documented as locally persisted in the Dart model's own docstring |
| `ReportRepository.myReports()` / `.hasReported()` | customers are guests by design (no customer account exists anywhere in this product) — there is no server-side identity to key "reports from this device" off. Store submitted report ids in `shared_preferences`, same mechanism already used for saved providers. |
| `LocationRepository.pendingCityRequests()` / `.hasRequestedCity()` | same reasoning, for guests. A **signed-in provider's** request can optionally be looked up server-side (`city_requests.submitted_by_phone` + RLS policy already supports this), but a guest's cannot. |
| `ServiceCatalogRepository.requiresHealthcareDetails()` | pure derivation over already-fetched categories (`any(categoryIds, isHealthcare)`) |
| `ProviderRepository.serviceAreaLocalities()` | derivable client-side from the profile's own `serviceAreas` (cityId/localityId pairs already in hand) joined against `LocationRepository.localities()`, which the client already calls elsewhere |
| `LocationRepository.activeLaunchCity()` / `.resolveSelection()` / `.isCityActive()` / `.defaultLocality()` | thin client-side composition over plain `SELECT`s against `cities`/`localities` (public read, no RLS complexity) |

## 11. Error format

Functions and triggers raise `exception '<code>: <human-readable message>'`.
The code prefix is a stable contract (never renamed once released; additive
only). It matches `RepositoryErrorCode` (`lib/domain/models/account.dart`) and
the client-facing codes in
[`docs/contracts/fixtures/error-codes.json`](contracts/fixtures/error-codes.json):

| Prefix | Dart mapping | Fixture code | Raised by (examples) |
|---|---|---|---|
| `not_authenticated:` | `RepositoryErrorCode.notAuthenticated` | `AUTH_REQUIRED` | register without verified phone; publish without verified phone |
| `not_owner:` | `RepositoryErrorCode.notOwner` | `NOT_OWNER` | any owner RPC on another's profile; every admin RPC for a non-admin; `admin_audit_events` |
| `not_found:` | `RepositoryErrorCode.notFound` | `NOT_FOUND` | unknown profile/photo/city/category; `submit_report` on an unlisted listing |
| `validation_failed:` | `RepositoryErrorCode.validationFailed` | `VALIDATION_FAILED` | payload bounds, search bounds, missing reason, bad phone |
| `conflict:` | `RepositoryErrorCode.conflict` | `CONFLICT` | `revision_mismatch`, reused idempotency key, account already has a profile. The exact message `conflict: this phone number already owns a profile` maps to `DuplicatePhoneNumberException`. |
| `location_not_active:` | `RepositoryErrorCode.locationNotActive` | `LOCATION_NOT_ACTIVE` | register, publish |
| `listing_not_publishable:` | `RepositoryErrorCode.listingNotPublishable` | `LISTING_NOT_PUBLISHABLE` | publish without phone display consent |
| `consent_required:` | *(none yet: propose `RepositoryErrorCode.consentRequired`)* | `CONSENT_REQUIRED` | enabling WhatsApp without phone-display consent |
| `reauth_required:` | `RepositoryErrorCode.reauthRequired` | *(not in the fixture file yet)* | `request_sensitive_action`, phone-change trigger, administrator RPCs without a fresh MFA proof |
| `rate_limited:` | *(none yet: propose `RepositoryErrorCode.rateLimited`)* | `RATE_LIMITED` | `submit_report`, `request_city` |
| `feature_disabled:` | *(none yet: propose `RepositoryErrorCode.featureDisabled`)* | `FEATURE_DISABLED` | any write or read behind a kill switch (`sponsored_placement`, `healthcare_listings`, `precise_location`, `media_intake`, ...) |
| `suspended:` | `RepositoryErrorCode.suspended` | `SUSPENDED` | publishing a suspended listing |
| `category_not_allowed:` | `RepositoryErrorCode.categoryNotAllowed` | `CATEGORY_NOT_ALLOWED` | **not raised today**: unknown categories are `validation_failed: unknown category`. |

**Mismatches with `error-codes.json` (that file is not edited here):**
- Fixed in `error-codes.json`: `CONSENT_REQUIRED` and `RATE_LIMITED` are `implementedInSql: true`.
- `LOCATION_NOT_ACTIVE` says it is enforced "only in register_profile"; it is
  now also enforced by the publish trigger (`0015`).
- `CATEGORY_NOT_ALLOWED` is still not implemented (`validation_failed`
  instead), and `INTERNAL`'s 22P02 note is mostly handled: payload casts are
  caught and re-raised as `validation_failed`.
- The fixture lists HTTP 401/403/404/409/422/429, but PostgREST returns
  HTTP 400 (`P0001`) for every `raise exception`; clients must map by prefix,
  not by HTTP status. `rate_limited` is not a 429 on the wire.
- `set_map_location` / `record_terms_acceptance` use `validation_failed:`
  since `0017` (the bare `validation:` prefix from `0012` is gone).
- No `duplicate_phone:` prefix exists yet (the fixture proposes one).
- Permission failures from revoked grants/functions are PostgREST errors
  (HTTP 401/403, Postgres `42501`), not `not_owner:`; the Dart layer should
  treat 401/403 without a prefix as `notAuthenticated`/`notOwner`.

The Supabase Dart client surfaces the text as `PostgrestException.message`
(for RPC calls): parse the leading `word:` token. A `UNIQUE` violation outside
a function surfaces Postgres's own wording; treat `duplicate key value` as
`conflict` as a fallback.

## 12. Example: search request/response

Request (`supabase.rpc('search_providers', {...})`):

```json
{
  "p_city_id": "mh-mumbai",
  "p_locality_id": "mh-mumbai-andheri-west",
  "p_text": "",
  "p_category_ids": ["plumbing"],
  "p_locality_filter_ids": [],
  "p_open_now_only": false,
  "p_home_visits_only": false,
  "p_limit": 20,
  "p_offset": 0
}
```

Response:

```json
{
  "totalCount": 1,
  "items": [
    {
      "isSponsored": false,
      "provider": {
        "id": "b1f6...",
        "phoneE164": "+919876543210",
        "displayName": "Shree Plumbing Works",
        "baseCityId": "mh-mumbai",
        "baseLocalityId": "mh-mumbai-andheri-west",
        "status": "published",
        "createdAt": "2026-09-01T10:00:00+00:00",
        "updatedAt": "2026-09-20T08:30:00+00:00",
        "categoryIds": ["plumbing"],
        "serviceAreas": [
          {"cityId": "mh-mumbai", "localityId": "mh-mumbai-andheri-west", "pinCodes": [], "isPrimary": true}
        ],
        "description": "24x7 plumbing, tap and drain repair",
        "languages": ["hi", "en"],
        "workingHours": {"days": [{"weekday": 1, "open": 540, "close": 1200}, ...]},
        "photos": [],
        "startingPrices": [{"categoryId": "plumbing", "amount": 150, "note": "visit charge"}],
        "healthcareDetails": null,
        "homeVisits": true,
        "availability": "available",
        "whatsappEnabled": true,
        "phoneDisplayConsented": true,
        "verification": {"phone": "approved"},
        "pinCodes": [],
        "mapLocation": null
      }
    }
  ]
}
```

(Only the §5 allowlist appears. `moderationStatus`, `revision` and
`isPubliclyListed` are intentionally absent; they exist in the owner shape
only. `phoneE164` is shown because this listing has consented.)

## 13. Full operation index

| Area | Dart interface method | Backend call |
|---|---|---|
| Locations | `LocationRepository.countries/states/citiesByState/cityById/availableCities/localities/localityById` | plain `SELECT` (public read) |
| Locations | `.activeLaunchCity/.resolveSelection/.isCityActive/.defaultLocality` | client-side composition over the above (§10) |
| Locations | `.setCityLaunchStatus` | `rpc('set_city_launch_status', {p_city_id, p_status, p_reason})` (admin; **REMOVED:** `.update()` on `cities`) |
| Locations | `.requestCity` | `rpc('request_city', {p_city_name, p_state_name, p_note})` (**REMOVED:** `.insert()` on `city_requests`) |
| Locations | `.pendingCityRequests/.hasRequestedCity` | client-local (§10); `city_requests` is admin-readable only, so do not rely on a server lookup |
| Locations | `.searchCities` | `rpc('search_cities', ...)` |
| Catalog | `ServiceCatalogRepository.groups/categories/categoriesByGroup/popularCategories/healthcareCategories/categoryById/categoriesByIds/groupById/categoriesWithGroup` | plain `SELECT` (public read) |
| Catalog | `.searchCategories` | `rpc('search_categories', ...)` |
| Catalog | `.requiresHealthcareDetails` | client-side (§10) |
| Discovery | `ProviderRepository.search` | `rpc('search_providers', ...)` (§8) |
| Discovery | `.publicProfileById` | `rpc('get_public_profile', {p_id})` |
| Discovery | `.profileByIdForOwner` | `rpc('get_owner_profile', {p_id})` |
| Discovery | `.publishedInCity` | `rpc('providers_published_in_city', {p_city_id})` |
| Discovery | `.providerCountByLocality` | `rpc('provider_count_by_locality', {p_city_id})` |
| Discovery | `.similarProviders` | `rpc('similar_providers', {p_provider_id, p_limit})` |
| Discovery | `.serviceAreaLocalities` | client-side (§10) |
| Provider write | `.createProfile` / `ProviderAuthRepository.registerProfile` | `rpc('register_profile', jsonb)` (§6) |
| Provider write | `.updateProfile` | `rpc('update_profile_full', ...)` (§6) |
| Provider write | `.publish/.setListingStatus` | `rpc('set_listing_status', {p_profile_id, p_status, p_expected_revision})` (**REMOVED:** `.update()`) |
| Provider write | `.setAvailability` | `rpc('set_availability', {p_profile_id, p_availability})` (**REMOVED:** `.update()`) |
| Provider write | `.deleteListing` | `rpc('delete_listing', {p_profile_id})` (**REMOVED:** `.delete()`) |
| Provider write | photos | upload to Storage, then `rpc('add_provider_photo', {p_profile_id, p_storage_path, p_caption})` / `rpc('delete_provider_photo', {p_photo_id})` (**REMOVED:** `provider_photos` writes) |
| Auth | `ProviderAuthRepository.*` | §3 |
| Reports | `ReportRepository.submit` | `rpc('submit_report', {p_provider_id, p_reason, p_details, p_reporter_phone})` (**REMOVED:** `.insert()` on `reports`) |
| Reports | `.myReports/.hasReported` | client-local (§10) |
| Reports | `.queue` | plain `SELECT` on `reports` (admin RLS only) |
| Engagement | `EngagementRepository.record` | `rpc('record_engagement', {p_provider_id, p_type, p_city_id, p_locality_id, p_category_id})` (**REMOVED:** `.insert()`) |
| Engagement | `.summaryFor` | `rpc('engagement_summary_for', {p_provider_id})` |
| Promotions | `PromotionRepository.activePromotions` | `rpc('active_promotions', ...)` |
| Promotions | `.subscriptionPlans` | plain `SELECT` |
| Promotions | `.registerInterest/.interestFor` | `.upsert()`/`.select()` on `promotion_interest` |
| Drafts/Saved | `ProviderDraftRepository.*`, `SavedProviderRepository.*` | client-only (§10) |
| Consent | `ConsentRepository.record` | `rpc('record_consent', {p_profile_id, p_kind, p_granted, p_wording_version})` (**REMOVED:** `.insert()` on `consent_records`) |
| Consent | `.forProvider/.currentState` | `.select()` on `consent_records` (owner/admin RLS) or read from the owner shape |
| Map / Terms | map pin, terms acceptance | `rpc('set_map_location', ...)`, `rpc('record_terms_acceptance', ...)` (§6) |
| Verification | `VerificationRepository.recordPhoneVerification` | **no client call** — written automatically by the auth-sync trigger on a real OTP confirmation |
| Verification | `.recordsFor/.currentStatus` | plain `SELECT` (owner/admin RLS) |
| Verification | `.recordCredentialReview` | `rpc('record_credential_review', ...)` (admin-only, audited) |
| Admin | moderation / market / category | `rpc('set_listing_moderation', ...)` (reason required to suspend), `rpc('set_city_launch_status', ...)`, `rpc('set_category_launch_approval', ...)` |
| Admin | audit trail | `rpc('admin_audit_events', {p_limit, p_before_id})` |
| Credentials | `CredentialRepository.forProvider/.saveClaimed/.remove` | plain `SELECT`/`.insert()`/`.delete()` on `credential_records` (still direct; claim columns only, status forced `pending`) |

## Feature-flag RPCs (0022, 0023)

- `flag_enabled(p_key)` and `get_client_flags()`: callable by `anon` and `authenticated`.
- `set_feature_flag(p_key, p_enabled, p_reason)`: admin only, audited.
- 0023: `search_providers` sponsor boost, `public_profile_json` (`healthcareDetails`, `mapLocation`) and `delete_provider_photo` now honour their flags.
