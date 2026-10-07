# Phase 013 — Field-level data classification

**Status:** In review

## Objective

Classify every column of every table (locations, catalog, profile, credentials, consent, reports, engagement, monetization, auth sync) and both Storage buckets. Define public / owner / moderator / admin / AI(guest) / AI(owner) access explicitly. Separate consented business contact from identity phone. Audit the current public boundary in migration 0009 and recommend an allowlist public projection (not implemented here; Phase 022 implements).

## Changed paths

- New: `tasks/evidence/phase-013.md` (this file)
- New: `tasks/evidence/phase-014.md`, `docs/contracts/fixtures/*.json` (Phase 014)
- No migrations, Dart, or other docs touched.

## Commands and results

Static review only. No database was started; `verify-db.mjs` was not run (plan line 28 records it already failing). Files read in full: `backend/supabase/migrations/20260101000002` through `...12` (referred to below as 0002-0012), `backend/supabase/config.toml`, `backend/supabase/functions/delete-account/index.ts`, `backend/supabase/tests/database/0000_helpers.sql` and `0005_private_fields.test.sql`, `docs/backend-contract.md`, `lib/domain/models/*.dart`. Every cited line number was read from `cat -n` output of the file at review time. **[audit: WRONG - many 0004/0011/0012 line numbers were offset by a concatenated listing (0004 +90, 0011 +235, 0012 +267) and did not exist or pointed elsewhere; corrected in place below, see Independent audit.]** Claims about hosted-Supabase behaviour that cannot be proven from source are marked UNVERIFIED in Residual uncertainty.

## Legend

Class: **PB** public-business, **OP** owner-private, **IP** identity-private, **MI** moderation-internal, **AD** admin-only, **SY** system (server-set, never client-written).
Access: **R** read, **W** write (create/update), **Rc** read only when the stated consent/eligibility holds, **Ra** aggregate or derived only, **-** none.
"Public" means anon and also the AI(guest), which may only ever receive what Public receives (never a raw row; contact via UI action, not model context). "Moderator" and "Admin" are the target split; today both collapse into one `app_admins` allowlist (0005:22-35, `is_admin()`), so every Moderator cell below is currently an Admin capability. "Eligible" = `status='published' and moderation_status='active'` (and, for contact, the consent flag).
Default for any column not listed, or added later: class UNCLASSIFIED = `-` for Public, Moderator, AI(guest), AI(owner); Owner reads only through the owner RPC after review; Admin by direct SQL only. A new column joins a public response only by adding it to the allowlist file and a passing test.

## Access matrix

### Locations (0002)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| countries.id / name / iso_code / dial_code / is_active | PB | R | R | R | W | R | R | n/a |
| state_regions.id / country_id / name / is_union_territory / is_active | PB | R | R | R | W | R | R | n/a |
| cities.id / state_id / name / aliases / is_metro | PB | R | R | R | W | R | R | city-level (approximate) |
| cities.launch_status | PB | R | R | R | W | R | R | activation switch; `inactive` rows should not be listed publicly (currently are: 0009:36) |
| localities.id / city_id / name / is_popular | PB | R | R | R | W | R | R | locality-level (approximate) |
| localities.pin_code | PB | R | R | R | W | R | R | indicative, never an identifier |
| city_requests.id | SY | - | R(own) | R | R | - | - | |
| city_requests.city_name / state_name | PB-ish | - | R(own) | R | R | - | - | |
| city_requests.note | OP | - | R(own) | R | R | - | - | free text, may hold PII; length unbounded (0002:55) |
| city_requests.submitted_by_phone | IP | - | R(own) | R | R | - | - | client-supplied, unverified (0009:56 `with check (true)`) |
| city_requests.requested_at | SY | - | R(own) | R | R | - | - | |

### Service catalog (0003)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| service_groups.id / name / icon_key / sort_order / description | PB | R | R | R | W | R | R | n/a |
| service_categories.id / group_id / name / icon_key / sort_order / is_healthcare / is_popular | PB | R | R | R | W | R | R | n/a |
| service_categories.keywords | PB | R | R | R | W | R | R | search vocabulary |
| service_categories.is_approved_for_launch | AD | - (target) | - | R | W | - | - | currently public via 0009:39 `using (true)` incl. unapproved rows |

### Provider profile (0004, 0012)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| provider_profiles.id | PB | R (eligible) | R | R | R | R (eligible) | R | opaque listing id |
| provider_profiles.user_id | IP | - | R | R | R | - | - | = auth.users.id; today anon-selectable (see F1) |
| provider_profiles.phone_e164 | IP (copy of auth phone) | - (see contact rule) | R | R | R | - | R | identity phone; never public as such |
| provider_profiles.display_name | PB | R (eligible) | W | R | W | R | W-draft only (human confirms) | business name |
| provider_profiles.base_city_id | PB | R (eligible) | W | R | W | R | R | city-level |
| provider_profiles.base_locality_id | PB | R (eligible) | W | R | W | R | R | locality-level, "never an address" (provider.dart comment) |
| provider_profiles.description | PB | R (eligible) | W | R | W | R | R | free text; scan for embedded phone numbers (bypasses consent) |
| provider_profiles.languages | PB | R (eligible) | W | R | W | R | R | |
| provider_profiles.home_visits | PB | R (eligible) | W | R | W | R | R | |
| provider_profiles.availability | PB | R (eligible) | W | R | W | R | R | self-reported hint |
| provider_profiles.whatsapp_enabled | PB | Rc (needs phone consent) | W | R | W | Rc | R | public only if phone_display_consented AND whatsapp_contact consent |
| provider_profiles.phone_display_consented | OP | Ra (as "contact available") | W | R | R | Ra | R | raw flag not public |
| provider_profiles.status | PB | R (only eligible rows exist) | W | R | W | R | R | |
| provider_profiles.moderation_status | MI | - | R (own) | R | W | - | R (own, read-only) | owner may see own suspension (my_account) |
| provider_profiles.suspension_reason | MI | - | R (own) | R | W | - | R (own, read-only) | |
| provider_profiles.pin_codes | PB | R (eligible) | W | R | W | R | R | PIN-level, approximate |
| provider_profiles.created_at | SY | - | R | R | R | - | R | not needed publicly |
| provider_profiles.updated_at | SY | R (freshness) | R | R | R | R | R | feeds "last confirmed" |
| provider_profiles.published_at | SY | - | R | R | R | - | R | |
| provider_profiles.map_lat / map_lng | PB (only after consent) | Rc (consent `show_map_location`) | W via set_map_location only | R | R | Rc | R | EXACT business-premises pin; target: exact only for premises-based providers who chose it, otherwise null; never a home pin |
| provider_categories.provider_id / category_id | PB | R (eligible) | W | R | W | R | R | |
| provider_service_areas.provider_id / city_id / locality_id / is_primary | PB | R (eligible) | W | R | W | R | R | locality-level |
| provider_service_areas.pin_codes | PB | R (eligible) | W | R | W | R | R | PIN-level |
| provider_working_hours.provider_id / weekday / open_minutes / close_minutes | PB | R (eligible) | W | R | W | R | R | null/null = closed day; zero rows = not provided |
| provider_photos.id / caption / uploaded_at | PB | R (eligible, validated) | W | R | W | R | R | |
| provider_photos.provider_id | SY | - | R | R | R | - | R | |
| provider_photos.storage_path | OP | - | R | R | R | - | R | source of truth; must be checked to start with owner uid |
| provider_photos.remote_url | PB | R (eligible) | W (target: server-set only) | R | R | R | R | currently owner-supplied arbitrary URL, emitted publicly (0004:93-94 [audit-corrected], 0008:125) |
| provider_photos.is_placeholder | SY | R | R | R | R | R | R | |
| provider_starting_prices.provider_id / category_id / amount_rupees / note | PB | R (eligible) | W | R | W | R | R | indicative only |
| provider_healthcare_details.provider_id | SY | - | R | R | R | - | R | |
| provider_healthcare_details.qualification / specialty / clinic_name / consultation_hours_note / registration_council / is_diagnostic_centre / accepts_walk_ins | PB (provider-claimed) | R (eligible, labelled "claimed") | W | R | R | R (label claimed) | R | |
| provider_healthcare_details.clinic_address | PB (claimed) | R (eligible) | W | R | R | R | R | EXACT premises text; a home-based practitioner could type a residence here, nothing prevents it |
| provider_healthcare_details.registration_number | PB (claimed) | R (eligible, labelled "claimed") | W | R | R | R | R | not verification |

### Credentials, consent, verification, reports, admin (0005, 0007, 0012)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| app_admins.user_id / added_at | AD | - | - | - | R | - | - | readable by any admin (0009:235) |
| consent_records.id | SY | - | R | R | R | - | R | |
| consent_records.provider_id | SY | - | R | R | R | - | R | |
| consent_records.kind / granted / wording_version | OP (audit) | Ra (derived: contact available, map shown) | R, C via RPC | R | R | Ra | R | kinds: display_phone_number, whatsapp_contact, public_profile, marketing_contact, show_map_location, terms_accepted |
| consent_records.recorded_at | SY | - | R | R | R | - | R | owner-writable today (0009:148-150), should be server-set |
| consent_records.phone_e164 | IP | - | R | R | R | - | R | audit copy of identity phone; client-supplied today |
| consent_records.withdrawn_at | SY | - | R | R | R | - | R | never set (append-only, no UPDATE policy); withdrawal is a new granted=false row **[audit: overstated - no server path sets it, but the owner INSERT policy lets a client set it (executed: row with withdrawn_at accepted).]** |
| verification_records.id / provider_id / kind / status / created_at | PB (status only) | Rc: kind->status map only | R | R | R | Rc status map | R | public gets `{phone: approved}` only **[audit: WRONG - the public JSON `verification` is kind -> latest status for EVERY kind (0008:152-158), so it also exposes e.g. `credentials: rejected`/`pending`; executed.]** |
| verification_records.method | OP | - | R | R | R | - | R | e.g. otp_sms, document_review |
| verification_records.reviewed_by | MI | - | - (target); R today (0009:162-164) | R | R | - | - | admin uid; leaks reviewer identity |
| verification_records.reviewed_at | OP | - | R | R | R | - | R | |
| verification_records.note | MI | - | - (target) / R today | R | W | - | - | admin free text; owner needs a separate reviewed `decisionReason` instead |
| credential_records.id / provider_id / title / issuing_body / registration_number / valid_until | OP (claimed) | Rc only after approval, as claimed fact + badge | R, C, D | R | R | Rc | R | |
| credential_records.status | PB after review | Rc (approved only) | R (cannot write: forced pending, 0005:106-118) | R | W via record_credential_review | Rc | R | |
| credential_records.reviewed_at | OP | - | R | R | R | - | R | |
| credential_records.reviewed_by | MI | - | - (target) / R today | R | R | - | - | |
| credential_records.evidence_storage_path | AD/IP | - | R (own path) | R | R | - | - | never in AI context; must be validated to own prefix (0005:81 unconstrained) |
| reports.id | SY | - | - | R | R | - | - | |
| reports.provider_id | SY | - | Ra (count of open reports only if policy allows) | R | R | - | Ra | |
| reports.reason | MI | - | - | R | R | - | - | enum |
| reports.status | MI | - | - | W | W | - | - | writable by anon INSERT today (F5) |
| reports.details | MI | - | - | R | R | - | - | free text up to 1000 chars (0005:93); may contain third-party PII |
| reports.reporter_phone_e164 | IP (third party) | - | - | R (masked default) | R | - | - | reporter is a guest customer; never to the owner |
| reports.created_at | SY | - | - | R | R | - | - | |
| reports.reviewed_at / resolution_note | MI | - | - | W | W | - | - | resolution_note must never reach the owner or any AI |

### Engagement and monetization (0006)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| engagement_events.id / occurred_at | SY | - | - | R | R | - | - | raw rows admin-only (0009:205) |
| engagement_events.provider_id / type | OP | C (insert only) | Ra (summary via engagement_summary_for) | R | R | - | Ra | |
| engagement_events.city_id / locality_id / category_id | OP | C | Ra | R | R | - | Ra | customer context, locality-level; never customer-identifying |
| promotions.id / provider_id / state / placement / starts_at / ends_at / category_ids / locality_ids / city_id / priority | PB when active | Rc (via active_promotions, eligible provider only) | R (own, target) | R | W | Rc | Rc | |
| promotions.created_by | AD | - | - | - | R | - | - | |
| subscription_plans.id / title_key / feature_keys / is_recommended / price_label | PB | R | R | R | W | R | R | |
| promotion_interest.provider_id / plan_id / recorded_at | OP | - | R, W | R | R | - | R | |

### Auth sync (0007) and Supabase `auth.users` (read through `my_account()`, 0008:646-666)

| table.column | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Location note |
|---|---|---|---|---|---|---|---|---|
| auth.users.id | IP | - | R | - | R | - | - | |
| auth.users.phone | IP | - | R | masked | R | - | R (owner's own only) | login identity; NOT a published contact |
| auth.users.phone_confirmed_at | IP/SY | - | R | R | R | - | R | only trust anchor for "phone verified" |
| auth.users.created_at / last_sign_in_at | IP | - | R | - | R | - | - | |
| handle_auth_phone_change() (trigger) | SY | - | - | - | - | - | - | writes provider_profiles.phone_e164 and verification_records (kind=phone) |

### Storage buckets (0011)

| bucket | class | Public | Owner | Moderator | Admin | AI guest | AI owner | Notes |
|---|---|---|---|---|---|---|---|---|
| provider-photos (public=true, 0011:8 [audit-corrected]) | PB | R by URL | W own folder `{uid}/...` | R | R | URL only for eligible listing | R | no size or MIME limit (0011:6-10 [audit-corrected]); objects stay public after unpublish, suspension, account deletion |
| credential-evidence (public=false, 0011:9 [audit-corrected]) | AD/IP | - | R, W, D own folder | R | R (all, 0011:27-30 [audit-corrected]) | - never | - never | credential scans never in model context; per-reviewer signed URLs only |

## Phone separation (consented business contact vs identity phone)

Three different things share the name "phone" today and must stay separate:

1. **Identity phone** = `auth.users.phone` (IP). Login credential. Owner-only; never a public field and never a business contact by itself.
2. **Denormalised copy** = `provider_profiles.phone_e164` (0004:37 [audit-corrected]), also copied into `consent_records.phone_e164`, `city_requests.submitted_by_phone`, `reports.reporter_phone_e164`. All IP. Public must never read these columns directly.
3. **Consented business contact** = a derived value that exists publicly only when `phone_display_consented = true` AND the listing is eligible (and, for WhatsApp, a granted `whatsapp_contact` consent). Today (3) is not modelled: it is (2) emitted unconditionally (see F2). Because the product design is one phone for identity and contact, the lowest-effort correct model is: keep one stored number, but expose it only through a contact projection (`contactPhone`, `whatsappAvailable`) that returns null unless consent holds, and do not put it in list/search payloads at all (a separate, rate-limited "reveal contact" call that also records the engagement tap). Longer term a distinct `business_contact_phone` column lets a provider publish a number different from the login number.

## Exact vs approximate location rules

| Item | Precision | Public | Rule |
|---|---|---|---|
| base_locality_id, service-area localities, cities | locality/city (approximate) | yes | the default and the only precision for home-based providers |
| pin_codes (profile and service areas) | PIN (approximate) | yes | owner-entered |
| map_lat / map_lng | exact point | only with `show_map_location` consent | premises-based providers only; withdrawal deletes coordinates (0012:9-12,45-54 [audit-corrected]); never derive from home address |
| clinic_address (healthcare) | exact text | yes, provider-claimed | for clinics only; add a validation prompt and moderation flag for residential-looking text |
| engagement_events locality/city | locality (approximate) | no | owners see aggregates only; do not add lat/lng ever |
| reports/city_requests | none stored | n/a | keep it that way |

## Audit of the current public boundary (migration 0009)

Answer to the headline question: **yes**. Anon gets SELECT on the raw `provider_profiles` rows of every eligible listing (0009:71 grant, 0009:73-75 policy), and RLS cannot hide columns inside an allowed row, so every column is readable by anon via PostgREST. It also grants EXECUTE on every function in `public` to anon and authenticated (0009:16-17).

## Findings, ranked (security first)

**F1 — High. Anon reads every column of every published provider row.** `0009:70-71` (`grant select on public.provider_profiles to anon`) plus `0009:73-75` (policy `status = 'published' and moderation_status = 'active'`). Columns exposed to a plain `GET /rest/v1/provider_profiles?select=*`:
- `phone_e164` (0004:37 [audit-corrected]) even when `phone_display_consented = false` (0004:48 [audit-corrected]). The listing can be eligible with consent false (see F2/F4). Bulk scrape of all numbers and reverse lookup by number (`?phone_e164=eq.+91...`) are possible; `max_rows = 1000` in `config.toml:9` only paginates.
- `user_id` (0004:36 [audit-corrected]): the auth user UUID, which is also the Storage folder prefix (0011:16 [audit-corrected]) and links a listing to an identity.
- `map_lat`, `map_lng` (0012:14-15 [audit-corrected]): exact coordinates (consent-gated by data deletion, but exposed at full precision).
- `moderation_status`, `suspension_reason` (0004:50-51 [audit-corrected]): values for eligible rows are `active` / usually null, but the reason column stays selectable and `set_listing_moderation` (0008:565-567) stores whatever the admin types, including on an `active` row.
- `pin_codes`, `created_at`, `published_at`, `phone_display_consented`.
The existing test (`0005_private_fields.test.sql`) only proves invisibility of an unpublished row, not column minimality of an eligible one. The `backend-contract.md` claim (section 5) that no masking is needed because the row gate holds is incorrect for columns.

**F2 — High. Public JSON always includes the phone number, regardless of consent.** `0008:90` (`'phoneE164', pp.phone_e164`) inside `provider_profile_json`, which `get_public_profile` (0008:177), `search_providers` (0008:330), `similar_providers` (0008:356) and `providers_published_in_city` (0008:679) reuse. The publish gate checks consent only on the draft-to-published transition (0008:36-38). `update_profile_full` sets `phone_display_consented` freely on a published listing (0008:722) with no republish check, no consent record, and no coupling to `whatsapp_enabled` (compare registration, 0008:458). Result: withdrawing consent leaves the number public. Dart `canBeCalled` hides the button, but the number is still in the payload.

**F3 — High. EXECUTE granted on every function in `public` to anon and authenticated, including future ones.** `0009:16` (`grant execute on all functions ... to anon, authenticated`) and `0009:17` (`alter default privileges ... grant execute on functions`). Intended anon-callable surface is 8 read RPCs. Actually callable by anon today: `record_credential_review` (0008:524), `set_listing_moderation` (0008:551), `set_map_location` (0012:23 [audit-corrected]), `record_terms_acceptance` (0012:61 [audit-corrected]), `register_profile` (0008:394), `update_profile_full` (0008:693), `my_profile`, `my_account`, `engagement_summary_for` (0008:575), `is_admin` (0005:27), and the internal builders `provider_profile_json` and `provider_profile_json_core` (0008:83, 0012:91-104 [audit-corrected]; SECURITY INVOKER, so their behaviour depends on table grants rather than their own code), `assert_locality_in_city` (0004:128 [audit-corrected]). Each currently self-checks `auth.uid()` or `is_admin()`, so none is exploitable today, but the boundary is one forgotten `if` away from fail-open for any later function (the default-privileges line makes new functions callable automatically). Also note Postgres grants EXECUTE to PUBLIC by default, so a revoke must name PUBLIC as well as the API roles.

**F4 — High. Authenticated users can create or alter a profile row directly, bypassing `register_profile` and the phone trust anchor.** `0009:79-81` (insert policy checks only `auth.uid() = user_id`), `0009:82-86` (update policy, all columns), `0008:24-34` (the immutability checks for `phone_e164`, `moderation_status`, `suspension_reason` run only when `tg_op = 'UPDATE'`). Consequences: (a) INSERT of a profile with someone else's `phone_e164` and no phone verification (`0004:37 [audit-corrected]` only enforces uniqueness), which squats the number and makes the real owner's later `register_profile` fail with `conflict`; the row can then be moved to published and displays a victim's number; (b) direct UPDATE of `map_lat/map_lng` without writing the `show_map_location` consent row (0012:49-54 [audit-corrected] does both only inside the RPC); (c) direct UPDATE of `phone_display_consented` without audit; (d) direct UPDATE of `base_city_id` to an inactive city (trigger checks only locality-in-city, 0004:141-153 [audit-corrected]); (e) forging `created_at`/`published_at`. Phone-account sign-up is enabled (`config.toml:24,32`); whether other sign-up methods are enabled on the hosted project is UNVERIFIED, any signed-in user qualifies.

**F5 — Medium-High. Anonymous write surfaces have no column or rate controls.** 
- `reports`: anon INSERT with `with check (true)` (0009:190-193). A client can set `status`, `reviewed_at`, `resolution_note`, `reporter_phone_e164` (0005:88-98 have no restrictions beyond `details` length), e.g. insert already `dismissed`. An FK violation response also confirms whether any provider UUID exists, including unpublished ones.
- `engagement_events`: anon INSERT for any `provider_id` and any type including `sponsor_impression`/`sponsor_tap` (0009:202-204); owner dashboards and any future sponsor billing are forgeable.
- `city_requests`: anon INSERT, arbitrary `submitted_by_phone`, unbounded `note` (0002:51-58, 0009:54-56).
No quota, no CAPTCHA/attestation, no abuse counters.

**F6 — Medium. Unbounded bulk extraction RPCs.** `search_providers` clamps `p_limit` only from below (`greatest(p_limit,0)`, 0008:323), so `p_limit = 100000` dumps the directory in one call (an explicit JSON `null` limit becomes 0 because `greatest` ignores NULLs, which silently returns an empty page); `providers_published_in_city` (0008:672-681) returns the entire city, phone included, in one call. `max_rows` (config.toml:9) does not bound a single-row `jsonb` result. Ranking has no unique tiebreaker (0008:320-322), so paging can duplicate or skip equal-name rows.

**F7 — Medium. Photo storage is public, unbounded, and outlives its owner.** `0011:6-10 [audit-corrected]` (`provider-photos` public, no `file_size_limit`, no `allowed_mime_types`); objects remain reachable by URL after unpublish, suspension, or account deletion because the Edge Function deletes only the auth row (`delete-account/index.ts:47-48`) and the FK cascade never touches Storage. `provider_photos.remote_url` and `storage_path` are owner-supplied free text (0004:93-94 [audit-corrected]) and `remote_url` is emitted publicly (0008:125): arbitrary third-party URLs (tracking pixels, hostile content) and paths pointing into another user's folder are not prevented.

**F8 — Medium. Moderation internals visible to owners.** `0009:162-164` lets the owner read their own `verification_records`, including `reviewed_by` (admin uid) and `note` (admin free text, 0005:60-63, set at 0008:545-546); `0009:174-176` exposes `credential_records.reviewed_by` and `evidence_storage_path`. Decide per field; default-deny says hide until a reviewed owner-facing `decisionReason` exists.

**F9 — Medium. The consent trail is client-forgeable.** `0009:148-150` lets the owner INSERT any `kind`, `granted`, `recorded_at`, `wording_version`, `phone_e164`, `withdrawn_at` (0005:39-48). `recorded_at` can be backdated and the phone copy falsified, so it is weak audit evidence for the Play/consent requirement. Writes should go through RPCs that set time and phone server-side.

**F10 — Low-Medium. Single admin tier and over-broad evidence access.** `app_admins` (0005:22-25) gives one boolean `is_admin()` that reads every consent, report, credential file (0011:27-30 [audit-corrected]) and all engagement. The plan (line 49) requires separate support, moderation, credential-review and infrastructure privileges.

**F11 — Low-Medium. Non-eligible data in reference tables and promotions.** `service_categories` rows with `is_approved_for_launch = false` are public (0009:39). `active_promotions` (0008:604-625) returns `providerId` without checking the provider is still eligible, so it leaks ids of paused or suspended providers.

**F12 — Low (structural). Grants are not the real boundary on hosted Supabase.** Supabase's default privileges grant ALL on new `public` tables to anon/authenticated (mirrored in `backend/scripts/supabase-stub.sql:28`), so the explicit `grant select ... to anon` lines are redundant and RLS is the only gate. Column-level least privilege therefore requires `revoke all` first. UNVERIFIED against a hosted project.

**F13 — Low. Free-text can carry private data.** `description` and `healthcare.clinic_address` are public free text. A phone number typed into `description` bypasses consent; a residential address typed into `clinic_address` becomes an exact public location. Needs validation plus a moderation flag.

## Recommended allowlist public projection (description only; Phase 022 implements)

1. **Revoke first.** `revoke all on all tables in schema public from anon, authenticated, public` for the provider/consent/credential/report tables, then re-grant only what clients need; `revoke execute on all functions in schema public from public, anon, authenticated`; `alter default privileges ... revoke execute on functions from public, anon, authenticated`. Re-grant EXECUTE on an explicit list: anon gets only `get_public_profile`, `search_providers`, `similar_providers`, `provider_count_by_locality`, `providers_published_in_city`, `active_promotions`, `search_cities`, `search_categories` (plus a future `submit_report`, `record_engagement`, `request_city`). Authenticated additionally gets the owner RPCs. Admin-only functions are granted to a dedicated admin role or called from a protected admin function only.
2. **One internal builder.** `provider_public_json(p_id)` (SECURITY DEFINER, `set search_path = ''`, not executable by API roles) builds the public shape from an explicit column list. It emits: `id`, `displayName`, `baseCityId`, `baseLocalityId`, `description`, `languages`, `homeVisits`, `availability`, `categoryIds`, `serviceAreas` (city, locality, pin codes), `workingHours`, `photos` (id, caption, validated public URL, uploadedAt), `startingPrices`, `healthcareDetails` (claimed, labelled), `verification` as `{kind: status}` only, `mapLocation` only with consent, `updatedAt`, `isSponsored`. It never emits `user_id`, `phone_e164`, `moderation_status`, `suspension_reason`, `published_at`, `created_at`, reviewer fields or notes. Contact appears as `contact: {phone, whatsapp}` only when `phone_display_consented` (and WhatsApp consent) hold; otherwise `contact: null`. All eight public RPCs call this single builder so shapes cannot drift (today the owner and public shapes share one builder and subtract fields, which is the pattern the plan forbids: 0008:177, 330, 356, 679).
3. **Move contact out of lists.** Search and list payloads omit the phone; a `reveal_contact(p_provider_id)` RPC returns it (rate-limited per device/IP, records the engagement tap, rechecks eligibility and consent at call time). This also gives immediate revocation.
4. **Make direct table access owner-only and narrow.** Public gets no SELECT on `provider_profiles` or child tables. Owner writes go through RPCs or a column-level grant list that excludes `phone_e164`, `user_id`, `moderation_*`, `suspension_reason`, `published_at`, `created_at`, `map_*`.
5. **Clamp and page.** `p_limit` clamped to 1..50 in SQL, `null` mapped to the default, unique tiebreaker (`id`) in ORDER BY, no unpaged city dump.
6. **Anonymous writes through RPCs only** (`submit_report`, `record_engagement`, `request_city`) with server-set status/time, length caps, per-device rate limit, and an existence check that returns an indistinguishable result for unknown and hidden providers.
7. **Default-deny regression test.** A pgTAP test enumerates `information_schema.columns` for `public` and fails if a column is not in a committed classification file (this document's matrix as a machine-readable allowlist), and a second test asserts `jsonb_object_keys(get_public_profile(...))` equals the allowlist exactly and that anon `select` on `provider_profiles` is denied.
8. **Photos.** Server-validated upload (size, MIME, re-encode, EXIF strip) writes `remote_url`; clients never write it. Cleanup on unpublish/suspend (move to private or delete) and on account deletion.

## Residual uncertainty

- Not executed: no pgTAP/PGlite run, no live PostgREST probing. All exposure statements are from reading grants, policies and function bodies; each is cheap to prove with an anon `select`/`rpc` call once a local stack runs (Phase 022 should add those as failing tests first).
- UNVERIFIED: GoTrue stores `auth.users.phone` without a leading `+`, while `my_account()`/triggers/tests assume E.164 with `+` (the test helper inserts `+91...` directly, `0000_helpers.sql:18-22`). If true, `phone_e164` equality, uniqueness and the Dart `phoneE164` contract all need normalisation.
- UNVERIFIED: hosted project sign-up settings (email, anonymous) and default privileges (F4 scope, F12).
- `moderator`, `AI(owner)` and `AI(guest)` columns describe the target; none of those actors exists in the schema yet.
- Legal classification of consent evidence (retention after deletion, see `backend-contract.md` 4.6) is not decided here.

## Next integration action

Phase 022 turns recommendations 1-7 into a migration plus failing-first pgTAP tests (anon column read, anon function list, consent withdrawal removes phone, direct insert with foreign phone rejected). Phase 014's `registration.json` and `search.json` fixtures already assume the target contact shape (`phoneDisplayConsented=true` rows only). Owner decisions needed: moderator vs admin role names, whether `reviewed_by`/`note` ever reach owners, and whether to introduce a separate `business_contact_phone`.


## Independent audit (2026-10-06)

Method: every citation opened; SQL behaviour executed in PGlite with the repo harness (`supabase-stub.sql` roles, 12 migrations + seed, `set role anon/authenticated` with `request.jwt.claims`). Probes (throwaway, not in repo): `probe.mjs`..`probe5.mjs` + `*.out` in `C:/Users/alonso/AppData/Local/Temp/claude/C--Users-alonso-Documents-Localsaathi/36b4a25f-6d05-48a4-aadf-1d702215fcb4/scratchpad`. Baseline `verify-db.mjs`: 12/12 migrations, 5/5 files, 17/17 assertions PASS. Citation defects: 0004 cites were offset +90, 0011 +235, 0012 +267 (e.g. `0011:241-265` in a 32-line file; `0004:127` is a comment); 17 distinct citations corrected in place and tagged `[audit-corrected]`. Corrected citations do not change claim verdicts. Harness caveat: PGlite session user is superuser; default privileges to anon/authenticated mirror Supabase (`supabase-stub.sql:27-29`).

**Verdict counts:** 56 claims audited - Confirmed 48, Wrong 2, Overstated 4, Understated 2. Citations corrected in place: 23 occurrences tagged [audit-corrected] above this section (the tags inside this section are the same corrections cross-referenced).

| Claim | Citation | Verdict | Proof |
|---|---|---|---|
| "Every cited line number was read from `cat -n` output at review time"; files read in full | header | Wrong | Many 0004/0011/0012 numbers do not exist or point at other code (offsets above). Corrected in place. |
| "`verify-db.mjs` not run (plan line 28 records it already failing)" | `implementation-plan-320-phases.md:28` | Overstated | Stale: executed now 12/12, 5/5 files, 17/17 assertions PASS. |
| `cities` rows incl. `inactive` are publicly listed | `0009:36` | Confirmed | `for select using (true)`; executed anon `select count(*) from cities` = 62. |
| `city_requests.note` unbounded; `submitted_by_phone` client-supplied | `0002:55`; `0009:56` | Confirmed | Executed anon insert with 2,000,000-char note and arbitrary phone accepted. |
| `service_categories.is_approved_for_launch=false` rows are public | `0009:39`; `0003:26` | Confirmed | Policy `using (true)`; column read by no function (executed grep of `pg_proc.prosrc`: 0 hits). |
| `provider_profiles.user_id` anon-selectable | F1 | Confirmed | Executed anon `select user_id` returns the uuid. |
| `phone_e164` is a copy of the auth phone, anon-readable | `0004:37` [audit-corrected, was :127] | Confirmed | `phone_e164 text not null unique` at 0004:37; executed anon read + reverse lookup. |
| `provider_photos.remote_url` owner-supplied arbitrary URL, emitted publicly | `0004:93-94` [audit-corrected, was 183-184/184]; `0008:125` | Confirmed | Executed `remote_url='https://evil.example/p.gif'` accepted; `0008:125` emits `'remoteUrl', ph.remote_url`. |
| `provider_photos.storage_path` must be checked to start with owner uid | matrix | Confirmed | Executed `storage_path='other-uid/x.jpg'` accepted. |
| `clinic_address` could hold a residence, nothing prevents it | matrix | Confirmed | `provider_healthcare_details.clinic_address text` unconstrained (`0004:115`). |
| `app_admins` readable by any admin | `0009:235` | Confirmed | Executed admin `select count(*) from app_admins` = 1. |
| `consent_records.recorded_at` owner-writable, should be server-set | `0009:148-150` | Confirmed | Executed owner insert with `recorded_at='2000-01-01'` accepted. |
| `consent_records.withdrawn_at` "never set" | matrix | Overstated | Executed: owner INSERT with `withdrawn_at=now()` accepted; only server code never sets it. |
| Public `verification` is `{phone: approved}` only | matrix | Wrong | `0008:152-158` is `jsonb_object_agg(kind, latest status)` for every kind. Executed: after admin rejected a credential, anon `get_public_profile -> verification = {"credentials":"rejected"}`. |
| Owner reads own `verification_records` incl. `reviewed_by`, `note` | `0009:162-164`; `0005:60-63`; `0008:545-546` | Confirmed | Executed owner select returned `method`, `reviewed_by`, `note` (admin text for credential rows). |
| Credential insert forced to `pending` | `0005:106-118` | Confirmed | Executed owner insert `status='approved'` stored `pending`. |
| `credential_records.evidence_storage_path` unconstrained | `0005:81` | Confirmed | Executed insert `'otheruser/file'` accepted. |
| `reports.details` max 1000; free text may hold PII | `0005:93` | Confirmed | check constraint present. |
| Raw engagement rows admin-only | `0009:205` | Confirmed | Executed anon `count(*)` = 0 while anon INSERT succeeds. |
| `my_account()` synthesises account from `auth.users` | `0008:646-666` | Confirmed | Read; executed anon returns null. |
| `handle_auth_phone_change` writes `provider_profiles.phone_e164` and verification records | matrix auth-sync row | Overstated | Executed: with an existing profile the trigger's UPDATE raises `not_owner: phone number changes only through phone verification` (`0008:31-33`) and the auth update rolls back; verification row written only on same-phone re-confirmation. |
| Storage: `provider-photos` public, no size/MIME limit; `credential-evidence` private | `0011:8-9`, `0011:6-10` [audit-corrected, were 243, 244, 241-245] | Confirmed | Executed buckets: photos `public=true, file_size_limit NULL, allowed_mime_types NULL`; evidence `public=false`. |
| Objects stay public after unpublish/suspension/account deletion | F7 | Confirmed | Executed: after deleting the profile, the `storage.objects` row remained (no FK/cascade to Storage). |
| Admin reads all credential evidence | `0011:27-30` [audit-corrected, was 262-265] | Confirmed | Executed admin sees 2 objects; non-owner sees 0 of owner's. |
| Headline: anon gets SELECT on raw eligible rows; all columns readable | `0009:71,73-75` | Confirmed | Executed `select *` as anon returns all 21 columns (list in phase-012 audit). |
| F1: `phone_e164` exposed even when consent false; `max_rows` only paginates | `0004:37` [audit-corrected], `0004:48` [audit-corrected, was :138]; `config.toml:9` | Confirmed | Executed: consent false, anon still reads phone. |
| F1: `user_id` is the Storage folder prefix | `0004:36` [audit-corrected, was :126]; `0011:16` [audit-corrected, was :251] | Confirmed | Policy `(storage.foldername(name))[1] = auth.uid()::text`. |
| F1: `map_lat/map_lng` exact, anon-readable | `0012:14-15` [audit-corrected, was 281-282] | Confirmed | Executed anon `select map_lat,map_lng` = 19.1, 72.8. |
| F1: `suspension_reason` stays selectable and `set_listing_moderation` stores any text on an active row | `0004:50-51` [audit-corrected, was 140-141]; `0008:565-567` | Confirmed | Executed: admin `set_listing_moderation(id,'active','typed reason')`; anon `select suspension_reason` on the published+active row returns `typed reason`. "Usually null" understates a live disclosure path. |
| F1: existing test proves only unpublished invisibility; `backend-contract.md` §5 "no masking needed" wrong for columns | `0005_private_fields.test.sql`; `backend-contract.md` §5 | Confirmed | Test inserts a draft/suspended row; doc §5 says no masking needed once the row gate holds; executed rebuttal above. |
| F2: JSON includes phone regardless of consent; reused by get_public_profile, search, similar, in_city | `0008:90,177,330,356,679` | Confirmed | Executed anon: consent false -> `phoneE164` present via `get_public_profile`, `search_providers`, `providers_published_in_city`. |
| F2: consent gate only on draft->published transition | `0008:36-38` | Confirmed | Executed: consent set false after publish, listing stays published. |
| F2: `update_profile_full` freely sets consent, no consent record, no WhatsApp coupling | `0008:722`, `:458` | Confirmed | Executed: `whatsapp_enabled=true` with `phone_display_consented=false`; consent rows unchanged. |
| F3: EXECUTE on all functions to anon/authenticated incl. future | `0009:16-17` | Confirmed | Executed: 30/30 project functions anon-executable; new function auto-executable. |
| F3: list of anon-callable functions; each self-checks so none exploitable today | `0008:524,551,394,693,575,83`; `0012:23` [audit-corrected, was :290], `:61` [audit-corrected, was :328], `:91-104` [audit-corrected, was 358-371]; `0005:27`; `0004:128` [audit-corrected, was :218] | Confirmed | Executed anon: every mutator raised P0001 (`set_listing_moderation`, `record_credential_review`, `engagement_summary_for`, `update_profile_full`, `register_profile`, `set_map_location`, `record_terms_acceptance`). Understated: list omits `get_owner_profile`; the 8 trigger functions are not RPC-callable (`0A000`). |
| F3: builders are SECURITY INVOKER so behaviour depends on table grants | `0008:83` | Confirmed | `pg_proc.prosecdef=false` for `provider_profile_json`/`_core`. Executed: anon call returns the JSON (phone, pin, `moderationStatus:"active"`) for an eligible row only, child arrays empty (RLS) - no extra exposure beyond the table read. |
| F3: revoke must name PUBLIC too | F3 | Confirmed | Executed: `revoke execute ... from anon, authenticated` leaves anon and authenticated EXECUTE (`proacl` has `=X`); `from public, anon, authenticated` removes it. |
| F4(a): authenticated direct INSERT with someone else's phone squats it; victim's `register_profile` fails; row can be published showing the victim's number | `0009:79-81`; `0004:37` [audit-corrected] | Confirmed | Executed: stranger inserted `phone_e164='+919777777777'`; victim `register_profile` -> `conflict: this phone number already owns a profile`; stranger added category+area, published, and anon `search_providers` returned `{name:"Squatter", phone:"+919777777777"}`. |
| F4(b): direct UPDATE of `map_lat/map_lng` with no consent row | `0012:49-54` [audit-corrected, was 288-322] | Confirmed | Executed owner `update ... set map_lat=1,map_lng=1` returned the row; no `show_map_location` row. |
| F4(c)/(d)/(e): direct consent flip; move `base_city_id` to inactive city; forge `created_at`/`published_at` | `0008:24-34`; `0004:141-153` [audit-corrected, was 231-243] | Confirmed | Executed: consent set true; `base_city_id` -> `mh-thane` (coming_soon) accepted; `created_at='2000-01-01'` accepted. `published_at` not executed (no guard in `0008:24-34` by reading). |
| F4: sign-up enabled | `config.toml:24,32` | Confirmed | Both `enable_signup = true`. |
| F5: anon INSERT into `reports` with any status/reporter phone; FK error reveals provider existence incl. unpublished | `0009:190-193`; `0005:88-98` | Confirmed | Executed: report with `status='dismissed'`, note and phone accepted; random uuid -> `23503`; a draft provider's id accepted. |
| F5: anon `engagement_events` any provider/type; `city_requests` unbounded | `0009:202-204`; `0002:51-58`, `0009:54-56` | Confirmed | Executed `sponsor_tap` and 2 MB note accepted. |
| F6: `p_limit` clamped only from below; NULL limit -> empty page; city dump | `0008:323`, `:672-681`; `config.toml:9` | Confirmed | Executed: `p_limit=100000` -> 121 items; `p_limit=null` -> 0 items, totalCount 1; `providers_published_in_city` -> 121. |
| F6: no unique tiebreaker | `0008:320-322` | Confirmed | `order by ... display_name asc` only. |
| F7: photo storage public/unbounded; Edge Function deletes only auth row; `remote_url`/`storage_path` free text | `0011:6-10` [audit-corrected]; `index.ts:47-48`; `0004:93-94` [audit-corrected]; `0008:125` | Confirmed | Executed (rows above). |
| F8: owner sees moderation internals | `0009:162-164`, `:174-176` | Confirmed | Executed owner read of `verification_records.note`; policy at 174-176 returns whole credential row. |
| F9: consent trail client-forgeable | `0009:148-150`; `0005:39-48` | Confirmed | Executed backdated + `withdrawn_at` insert accepted. |
| F10: single admin tier; plan line 49 requires separate privileges | `0005:22-25`; `0011:27-30` [audit-corrected, was 262-265] | Confirmed | `app_admins` is one table; plan :49 quote verified. |
| F11: unapproved categories public; `active_promotions` leaks ids of paused/suspended providers | `0009:39`; `0008:604-625` | Confirmed | Executed: active promotion for a suspended provider and for a paused provider both returned by anon `active_promotions` (`providerId` match true). |
| F12: default privileges grant ALL on new tables to anon/authenticated (stub mirrors) | `supabase-stub.sql:28` | Confirmed | Executed: new table -> `has_table_privilege('anon', ..,'select')` and `'insert'` true. Hosted behaviour remains UNVERIFIED as stated. |
| F13: free text can carry phone/address | `0004:41`, clinic_address | Confirmed | Columns are unconstrained `text`. |
| Rec 1: revoke all then re-grant allow-list of 8 anon RPCs (plus 3 future) | Recommendation 1 | Understated | Allow-list omits `is_admin()`. Executed: with `is_admin()` revoked from public/anon/authenticated, anon `select from provider_profiles` and `city_requests` fail `42501 permission denied for function is_admin` because policies `0009:76-78`, `:57-60` call it. Keep policy-used functions executable (or remove those policies first). |
| Rec 2: internal builder not executable by API roles; all public RPCs call it | Recommendation 2 | Confirmed | Executed: revoked `provider_profile_json(_core)` from public/anon/authenticated; anon `get_public_profile`, `search_providers` and owner `my_profile` still work (SECURITY DEFINER callers run it as owner); direct anon call -> `42501`. This also shows the `0009_rls.sql:6-14` rationale (callees need EXECUTE for the calling role) is wrong for SECURITY DEFINER callers. |
| UNVERIFIED: GoTrue stores phone without leading `+` | Residual | Understated | The repo itself asserts it: `supabase-stub.sql:36` "GoTrue stores `phone` WITHOUT the leading '+'" (cites `internal/api/phone.go`); still not provable locally against a real GoTrue. |
| Phase 014 fixtures "already assume the target contact shape" | Next action | Overstated | `search.json:38,81`, `public-profile.json:22`, `registration.json:51` still emit `phoneE164` (current shape); only a `notes` entry (`search.json:8`) mentions the target. |
