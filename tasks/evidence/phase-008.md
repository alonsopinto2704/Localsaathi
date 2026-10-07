# Phase 008 — User research brief

**Status:** Done (gate passed in phase-020; human sign-off pending)

**Objective:** Prepare interviews for customers, independent providers, older users, people arranging home visits, and clinics; define consent, retention, participant diversity, and research questions mapped to product decisions.

## Changed paths

None (research planning document).

## Inputs reviewed

- `tasks/implementation-plan-320-phases.md` (lines 299–316)
- `lib/data/seed/category_seed.dart` (service taxonomy)
- `lib/data/seed/location_seed.dart` (active localities)
- `lib/data/seed/provider_seed.dart` (provider fixtures demonstrating UI exercise)

## Content

### Participant segments

| Segment | Definition | Recruitment aim | Key questions focus |
|---------|-----------|------------------|---------------------|
| Customers (general) | People seeking local services, any frequency | 4–6 across income levels, device ownership | Discovery trust signals, friction in search, contact confidence |
| Customers (home visits) | Specifically arrange in-home care or repair | 2–3 with mobility/access needs | Scheduling, provider vetting, payment clarity |
| Independent providers | Unaffiliated tradespeople using app to find customers | 3–5 across categories (plumbing, domestic help, repair) | Onboarding friction, availability control, unwanted contact volume |
| Older users (65+) | Seniors searching services independently or via family | 2–3, varying device comfort | Text size, language preference, phone trust vs. app |
| Clinic staff | Hospital/diagnostic centre intake roles | 1–2 | Directory expectations, patient referral clarity, bulk inquiry needs |

**Diversity criteria:**
- Localities: at least Andheri West, Kurla, Powai, Colaba (geographic spread within seed data, income variation)
- Languages: conduct or offer interviews in English, Hindi, Marathi (one native speaker per language)
- Device types: mix of Android smartphones (primary), at least one tablet or older device model
- Phones: unmoderated calls via WhatsApp video; in-person in selected localities where safe

### Consent and retention

**Consent script (English draft; Hindi/Marathi to be reviewed by native speaker before use):**

> We are testing a service directory to help people find local help easily. Your feedback will help us understand what works and what doesn't.
>
> - This conversation will last about 20 minutes.
> - We may take notes and record audio (with your permission).
> - Your name and phone number will not be shared or published.
> - After 90 days, all identifiable notes will be deleted. We keep only pseudonymous feedback (e.g., "Marathi speaker, Andheri, older user").
> - You can stop or skip any question at any time.
> - This is a free test of a product idea, not a sale or survey subscription.

**Data retention:**
- Delete all identifiable notes (name, phone, address) after 90 days
- Retain only: pseudonymous participant ID, date, segment, locality, device type, language(s) used, summary of feedback
- Store notes in encrypted, access-controlled file (not email, not public docs)
- No personal messages, contact details, or provider phone numbers from interviews

### Research questions → product decisions

| Question | Segment | Maps to phase | Decision needed |
|----------|---------|-------|---------|
| How do you currently find a plumber/electrician? What trust signals matter most? | Customers (general) | 101 (search) | How prominent to show "availability verified last X days" vs. reviews |
| Would you call immediately or message first? | Customers (general) | 061 (contact) | Favor WhatsApp + call, or offer chat buffer |
| What stops you trusting an unknown provider? | Customers (home visits) | 081 (evidence) | Credential visibility rules, listing transparency |
| How often do unwanted callers contact you after a service inquiry? | Customers (general) | 241 (moderation) | Report flow design, support volume estimate |
| Do you feel confident your home address won't be shared? | Customers (home visits) | 141 (website privacy) | Privacy copy prominence, locality-only vs. address |
| How do you keep work steady? Do app inquiries convert? | Providers | 009 (launch support) | Support owner for provider education, expected inquiry quality |
| Does volume of inquiries ever feel overwhelming? | Providers | 010 (metrics) | Unwanted-contact threshold, report mechanism |
| Would a directory-only mode (no booking, no guarantees) feel safe to use? | Clinics | 009 (category rules) | Healthcare read-only confidence, referral clarity |
| Text size: is this readable on your phone? | Older users | 121 (accessibility) | Launch minimum font sizes, high-contrast option |
| Do you prefer Hindi, Marathi, or English? Any mixing? | Older users | 121 (multilingual) | Language retention across sessions, script preferences |

### Primary hypothesis: do free incumbents fail users? (Idea Council `FIX FIRST`, `council/verdicts.md`)

The council made this the **first** thing Phase 008 must test; the build is not justified until it has one real data point. Run before the other interviews.

**Desk test (10 minutes, no participants):** search Google Maps and JustDial for "plumber Andheri West" (repeat for electrician, AC repair). Call/WhatsApp 5 listed numbers per search. Record per number: answered / stale (wrong person, disconnected) / unreachable / upsell-gated (paid-lead or "premium" gate).

**Interview questions:**

| Question | Segment | Pass signal |
|----------|---------|-------------|
| Last time you needed a plumber/electrician, where did you look first (Google Maps, JustDial, WhatsApp/society group, neighbour)? Did it work? | Customers | Names a concrete failure, not "it was fine" |
| Have you called a listed number that was wrong, switched off, or someone else's? How many times this year? | Customers | ≥1 recent stale-number story |
| After searching or enquiring on JustDial/similar, did you get calls from businesses you never contacted? | Customers | Lead-selling spam reported |
| What would make you try a new app instead of asking your society WhatsApp group? | Customers, older users | A reason other than "it's new" |
| Are you listed on JustDial / Google? Do you pay? Are the leads real or spam? | Providers | Pays for poor leads, or is listed with stale details |
| Would you list for free on a local directory that never sells your number as a lead? Would you update your availability weekly? | Providers | Yes to both (tests the council's "providers will refresh availability") |

**Decision rule (from the council):** flip to BUILD only if **≥2 of 5** incumbent numbers are stale/unreachable, **or ≥3 of 5** providers want a free listing outside JustDial. Otherwise record the result here and stop before Phase 009 widens scope.

## Residual uncertainty / decisions needing the owner

1. **Recording consent**: Are audio recordings needed for later review? If yes, require explicit opt-in and host on secure server (not transcribed to third party without consent).
2. **Incentive**: Should participants receive ₹100–200 mobile recharge or tea? (Affects recruitment and consent fairness.)
3. **Moderation path**: If a provider reports "I got 30 calls from this feature in one week," what's the escalation? (Feeds into phase 241 support SLA.)
4. **Native translation**: Marathi and Hindi versions of consent script must be reviewed by a local speaker, ideally a team member familiar with privacy/compliance language in India.

## Next integration action

1. Run the incumbent desk test above and record the 5-number tallies here.
2. Finalize consent script in all three languages with legal/compliance review.
3. Identify 12–14 recruit participants across segments, confirm interview schedule.
4. Conduct interviews (2–3 weeks).
5. Synthesize findings into a summary document mapping key friction points to launch gates (e.g., "all 6 customer interviews said availability freshness was critical" → measure phase 101 discovery accuracy).
6. Record no phase-009 or phase-010 decisions until interview synthesis is shared; interview findings may shift launch category selection and metric thresholds.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| Research planning document scope | Confirmed | Document contains participant segments, consent script, retention policy, research questions |
| No changed paths (evidence-only) | Confirmed | Header states "None (research planning document)" |
| Inputs reviewed from plan.md | Unsupported | No verification that all cited sections (299-316, etc.) were actually checked |
| Participant segments well-defined | Confirmed | Table shows 5 segments with clear recruitment aims and key questions |
| Consent script has 90-day retention | Confirmed | Text states "After 90 days, all identifiable notes will be deleted" |

Research planning document is well-structured. No executable claims to verify; content is reasonable and defensible.

---

**Attribution:** Phase 008 evidence, LocalSaathi implementation plan. Conduct as research; do not send outreach without owner approval.
