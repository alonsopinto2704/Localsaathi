# Phase 010 — Outcome metrics and counter-metrics

**Status:** Done (gate passed in phase-020; human sign-off pending)

**Objective:** Define qualified discovery, intentional contact taps, provider activation, freshness coverage, support workload with formulas, event sources, and safety counter-metrics; establish decision thresholds and minimum sample sizes.

## Changed paths

- **Event writes:** `public.record_engagement` RPC (`20261006000018_guest_writes.sql`, rate-limited); no `event_log.ts` Edge Function is needed
- **Existing:** `lib/data/local/key_value_store.dart` has `engagementEvents` key for local buffering
- **Existing:** `lib/core/widgets/provider_contact.dart` fires contact taps (WhatsApp, call, report)
- **Existing:** `lib/app/controllers/provider_search_controller.dart` has profile view recording

## Inputs reviewed

- `tasks/implementation-plan-320-phases.md` (lines 339–356)
- `lib/core/widgets/provider_contact.dart`: "Fires the contact actions and records the corresponding in-app tap"
- `lib/app/controllers/provider_search_controller.dart`: profile view recording
- `lib/data/local/key_value_store.dart`: local engagement event storage
- `backend/supabase/migrations/`: `public.engagement_events` (0006) and `public.reports` (0005) already exist; metrics use them (see "Event sources").

## Content

### Core outcome metrics

#### 1. Qualified discovery

**Definition:** Unique users who view at least one provider profile in a search result after entering a locality + category query.

| Metric | Numerator | Denominator | Window | Event source | Owner | Decision |
|--------|-----------|-------------|--------|--------------|-------|----------|
| **Discovery rate** | Profiles viewed (unique users, unique provider per session) | Sessions that completed a location + category selection | Weekly / monthly | `engagement_events.type='profile_view'`. **Gap:** the table has no session id and no search event, so "sessions" is not computable today; needs a `search_performed` enum value + anonymous session id (owner: Workstream 6) | Analytics | ≥50% of sessions that select a locality should reach at least one profile view. If <30%, search UX blocking discovery. |
| **Locality coverage** | Providers with ≥1 active listing in selected locality | Total providers enabled in that locality | Weekly | `provider_profiles` joined to `provider_service_areas` where `status='published'` and publicly listed | Operations | ≥10 providers per locality at launch. If locality falls to <5, disable locality temporarily (phase-009 config). |
| **Category freshness** | Providers with `availability_confirmed_at` ≤ 14 days old for a category in a locality | All published providers in that category + locality | Weekly | Proposed column `provider_profiles.availability_confirmed_at`, set **only** by the provider confirming availability or by ops verification (never by a customer tap) | Operations | ≥60% of providers in each launch category should have verification ≤14 days. If <40%, initiate re-verification outreach. |

#### 2. Intentional contact taps

**Definition:** User initiates contact (WhatsApp, call, report) with a specific provider from the app.

| Metric | Numerator | Denominator | Window | Event source | Owner | Decision |
|--------|-----------|-------------|--------|--------------|-------|----------|
| **Contact tap rate** | Taps on Call or WhatsApp (`call_button_tap`, `whatsapp_button_tap`) | Profile views (same session) | Weekly / monthly | `engagement_events.type in ('call_button_tap','whatsapp_button_tap')`; reports come from `public.reports` (not an engagement event) | Analytics | ≥8% of profile views should lead to a contact tap. If <5%, profile data or trust signals missing (phase-081 evidence weakness). |
| **Contact-to-view ratio by category** | Contact taps per unique provider viewed | Total profile-view events for that provider | Weekly | Same source; segment by category_id | Operations | Identify low-conversion categories (e.g., tutors 2% vs. plumbers 12%). May indicate category-specific trust barrier or demand weakness. |
| **Unwanted contact complaints** | `public.reports` rows with `reason in ('wrong_phone_number','spam_or_misleading')` (the enum has no "unwanted contact"/"no response" value; adding one is a schema change for Workstream 13) | Total contact taps across all providers | Monthly | `public.reports.reason` | Support | ≤1 unwanted complaint per 1000 contact taps. If >2 per 1000, enable provider-side contact limits (phase 241). |

#### 3. Provider activation

**Definition:** A provider with a seeded or on-boarded account receives ≥1 contact tap from the app in their service area.

| Metric | Numerator | Denominator | Window | Event source | Owner | Decision |
|--------|-----------|-------------|--------|--------------|-------|----------|
| **Activation rate** | Providers who received ≥1 contact tap | Total providers with published listings in the launch localities | Monthly | `engagement_events` call/WhatsApp taps grouped by `provider_id` | Operations | ≥30% of seeded providers should activate (receive ≥1 contact) in first month. If <15%, launch localities/categories too narrow or provider data stale. |
| **Repeat activators** | Providers who received ≥2 contact taps in same month | Activated providers | Monthly | Count taps per provider_id where tap_count ≥ 2 | Operations | ≥40% of activated providers should get repeat interest. If <20%, suggests one-off inquiries or poor provider-customer match. |

#### 4. Freshness coverage

**Definition:** Percentage of published provider listings with recent availability confirmation.

| Metric | Numerator | Denominator | Window | Event source | Owner | Decision |
|--------|-----------|-------------|--------|--------------|-------|----------|
| **Freshness (all)** | Published providers with `availability_confirmed_at` ≤ 14 days | All published providers in launch scope | Daily | `provider_profiles.availability_confirmed_at` (proposed; provider confirmation or ops verification only) | Operations | Target ≥70% at launch. If <50%, listings stale; trigger re-verification workflow. |
| **Freshness by locality** | Same as above, per locality | Published providers in that locality | Weekly | Same source, grouped by locality_id | Support | Each locality should maintain ≥60% freshness. If a locality drops below 40%, support staff manually re-verify top 10 providers. |

#### 5. Support workload

**Definition:** Volume and type of manual interventions required to keep discovery functioning.

| Metric | Numerator | Denominator | Window | Event source | Owner | Decision |
|--------|-----------|-------------|--------|--------------|-------|----------|
| **Reports (user)** | `public.reports` rows (there is no `support_tickets` table) | Discovery sessions | Weekly | `public.reports`, grouped by `reason` | Support | ≤5 tickets per 1000 discovery sessions. If >10 per 1000, UX friction or provider quality issues. |
| **Support tickets (provider)** | Tickets from providers (unwanted contact volume, dispute resolution, listing edits) | Total activated providers | Monthly | Not captured in the schema today (no provider support channel); manual log until Workstream 13 adds one | Support | ≤2 tickets per 100 active providers per month. If >5 per 100, contact-limiting or moderation workflow needed. |
| **Re-verification workload** | Calls/messages to providers to confirm availability | Published providers | Weekly | Manual outreach log (phase 081 tool) | Operations | Should be <5% of provider base per week. Automation via WhatsApp blast reduces cost. |

---

### Counter-metrics (safety & quality)

| Counter-metric | Definition | Numerator | Denominator | Window | Event source | Owner | Threshold |
|---|---|---|---|---|---|---|---|
| **Reports per 1000 contacts** | Abuse/safety reports filed | `public.reports` rows (all reasons; no `unsafe` value exists yet) | Total contact taps ÷ 1000 | Monthly | `public.reports` (`reason`) ÷ `engagement_events` call/WhatsApp taps | Moderation | <2 per 1000 (i.e., <0.2% of contacts → issue) |
| **Stale listing rate** | Listings older than 21 days without verification | Providers with `availability_confirmed_at` > 21 days | Published providers | Weekly | `provider_profiles.availability_confirmed_at` (proposed) | Operations | <20% stale at launch; escalate re-verification if >30% |
| **Provider inactivity** | Providers who haven't received contact in 30 days | Providers with no contact taps in last 30 days | Previously activated providers | Monthly | Contact taps by provider_id | Analytics | Up to 40% is expected churn; >60% suggests category/locality mismatch or low-quality seeding |
| **Unresolved reports** | Reports not yet reviewed >7 days | `public.reports` with `status in ('submitted','under_review')` and `created_at` > 7 days ago | Total reports filed | Daily | `public.reports.created_at` / `reviewed_at` | Support | <10% unresolved. SLA: user reports within 24h, provider resolution within 3 days. |
| **Cross-account exposures** | Contacts reaching wrong account or seeing private fields | Audit: test admin account access, cross-locality visibility | N/A | After each deploy | Manual security audit + automated RLS tests | Security | 0 (must be zero before launch). |

---

### Event sources (existing schema — no new events table)

Corrected 2026-10-07: the first draft proposed a new `public.events` table and referenced non-existent `support_tickets` and `providers.last_availability_check`. Metrics are defined against what exists:

| Source | Defined in | Use |
|---|---|---|
| `public.engagement_events` (`type`: `profile_view`, `call_button_tap`, `whatsapp_button_tap`, `share_tap`, `sponsor_impression`, `sponsor_tap`; plus `city_id`, `locality_id`, `category_id`) | `20260101000006_engagement_monetization.sql` | Views, contact taps, activation. No user/session id by design. |
| `public.reports` (`reason`, `status`, `created_at`, `reviewed_at`) | `20260101000005_trust_moderation.sql` | Support workload, counter-metrics, SLA. |
| `public.provider_profiles` (`status`, `availability`, `updated_at`) | `20260101000004_providers.sql` | Coverage, freshness. |

**Schema gaps (proposals, not built):**
1. `provider_profiles.availability_confirmed_at timestamptz` — set only by a provider "I'm still available" action or by ops verification. A customer tapping Call/WhatsApp proves nothing about whether the provider is active or answered, so taps must never refresh it. `updated_at` is not a substitute (any edit bumps it).
2. A `search_performed` engagement type plus an anonymous, rotating session id, if the discovery-rate denominator is wanted; otherwise report discovery as absolute view counts.
3. Report reasons for "unwanted contact" / "unsafe" if those counter-metrics are kept.

### Minimum sample sizes

| Metric | Minimum sample | Collection period | Rationale |
|--------|----------------|------------------|-----------|
| Qualified discovery rate | ≥500 discovery sessions | Week 1–4 of pilot | Detect >50% goal accuracy |
| Contact tap rate | ≥100 taps per category | Week 1–4 | Identify category-specific friction |
| Activation rate | ≥20 providers | Month 1 | Sufficient to show provider demand signal |
| Reports per 1000 | ≥20 total taps to measure rate | Ongoing; flag <20 as "insufficient data" |
| Freshness | Snapshot at day 7, 14, 21 of pilot | Weekly | Show stale-listing trend |

---

### Decision thresholds (Phase 1 pilot gates)

| Gate | Metric | Target | Action if missed | Owner |
|------|--------|--------|------------------|-------|
| **Week 1: Discovery working?** | Qualified discovery rate | ≥20% of sessions reach profile | Debug search/filter UX; extend phase-101 timeline | Product + Engineering |
| **Week 2: Contact flows live?** | Contact tap rate | ≥100 taps total across app | Verify `provider_contact.dart` wired; test button behavior | QA + Flutter lead |
| **Week 3: Provider data quality?** | Freshness ≥70%, activation rate ≥10% | ≥70% providers fresh; ≥10% got ≥1 contact | Re-verify provider phone numbers; check service-area matching | Operations |
| **Week 4: Safety baseline?** | Reports per 1000 <2, unresolved tickets <10% | <2 reports per 1000 taps; <10% tickets open >7d | Enable contact-limiting or re-verify providers if rate high | Support + Moderation |
| **Month 2: Scale/retention?** | Activation ≥30%, repeat taps ≥20% | ≥30% of providers activated; ≥20% repeat interest | Evaluate category-locality fit; consider disabling low-volume cells | Analytics |

---

## Residual uncertainty / decisions needing the owner

1. **Event data retention:** How long to retain raw events? (DPDP rules & cost: raw events for 90 days only, then aggregate to counts.) Requires legal review for India's personal-data rules.
2. **Guest analytics:** Can we track guest sessions without user_id? (Yes, by session_id; proposed schema above does not link to personal data.)
3. **Reporting cadence:** Who receives weekly metrics summaries? (Proposed: Product lead, Operations lead, Support lead; automated Slack digest.)
4. **Threshold tuning:** Should thresholds be hardcoded or configurable per launch wave? (Configurable recommended; hardcoding will need phase-012 review for each new city.)
5. **AI/ML on events:** Phase 201 (AI experience) may want to train on these events. Data governance required before integration.

## Next integration action

1. Event logging exists: `public.record_engagement` (migration 0018). Remaining gap: a `search_performed` type + anonymous session id if the discovery-rate denominator is wanted.
2. Update `lib/core/widgets/provider_contact.dart` to emit events on tap (phase 061 dependency).
3. Wire `lib/app/controllers/provider_search_controller.dart` to log profile views (phase 101 dependency).
4. Create Supabase table + RLS policy (phase 021 dependency).
5. Build metrics dashboard (e.g., Supabase Studio or basic SQL queries for manual reporting).
6. Confirm thresholds with Operations + Support during week-1 pilot kickoff.

---

**Attribution:** Phase 010 evidence, LocalSaathi implementation plan. Never collect raw personal messages for ordinary metrics; always pseudonymize or aggregate.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| engagementEvents key exists in key_value_store | Confirmed | `grep -n "engagementEvents" lib/data/local/key_value_store.dart` line 90, 109 |
| event_log.ts marked as proposed/new | Confirmed | Evidence correctly states "**New:** `backend/supabase/functions/event_log.ts` (proposed; ...)" |
| event_log.ts does not exist | Confirmed | `ls backend/supabase/functions/event_log.ts` returns ENOENT |
| provider_contact.dart fires contact taps | Unsupported | No actual execution evidence; claim is code structure observation |
| Metric formulas use correct columns | Unsupported | SQL queries not executed; schema not yet deployed |

Metrics design is well-reasoned. All dependencies on missing functions (event_log.ts) and tables correctly marked as proposed. No invented data.
