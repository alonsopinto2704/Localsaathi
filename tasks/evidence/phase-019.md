# Phase 019 — Capacity and risk schedule

**Status:** Done (gate passed in phase-020; human sign-off pending)

## Objective
Estimate total human engineering hours across all 320 phases, verify against plan statement, publish staffed 12-week and solo projection options, identify smallest safe release slice (core directory without AI), define owners and cut lines, create external-wait schedule.

## Prerequisites
- Implementation plan complete (320 phases, lines 51–79 staffing section)
- Phase 018 execution protocol and file-ownership model
- Effort extracted from all 320 phase prompts in plan

## Changed paths
- `tasks/evidence/phase-019.md` (this file; capacity schedule + risk matrix)
- No source code changes; planning only

## Commands and results

### Per-workstream effort extraction (python3, exact output below)

Command: Extracted all 320 phases' Effort lines and summed by workstream.

**Output:**
```
WS1:  40–80      WS2:  80–140    WS3:  60–120    WS4:  60–120
WS5:  60–120     WS6:  60–120    WS7:  40–100    WS8:  60–120
WS9:  80–140     WS10: 60–120    WS11: 60–120    WS12: 60–120
WS13: 60–120     WS14: 60–120    WS15: 60–120    WS16: 40–100
TOTAL BASE: 940–1,880 | WITH 25% CONTINGENCY: 1,175–2,350
```

**Verification:** Matches plan line 59.

### Staffing capacity projections

| Staffing model | Min weeks | Max weeks | Practical 12-week fit? | Notes |
|---|---|---|---|---|
| 1 engineer @ 30 h/week | 39 | 78 | No | 9–19 months; not a launch vehicle |
| 4 engineers @ 30 h/person/week | 9 | 19 | Partial | 2–4 months; dependencies still matter |
| 6 engineers @ 30 h/person/week | 6 | 13 | Yes | 1–3 months; external waits are gating factor |

### Solo developer projection

**Constraint:** 30 focused hours per week (realistic; includes meetings, review, debugging).

**Full roadmap:** 940–1,880 hours = 31–63 weeks solo, or 7–15 months.

**Smaller slice (core launch, AI off):** See section below.

## Risk matrix: external waits and critical path

| Dependency | Lead time | Gating phase | Mitigation |
|---|---|---|---|
| **SMS DLT registration (India)** | 2–4 weeks | Phase 043 (SMS provider contract) | Start immediately; apply for test credentials parallel to dev |
| **Model API account setup** | 1–2 weeks | Phase 161 (AI platform security) | Reserve early; budget setup overhead |
| **Legal counsel (DPDP/commercial)** | 2–8 weeks | Phase 241+ (moderation, privacy) | Engage weeks 1–2; run advisory in parallel with dev |
| **Google Play closed testing** | 2–3 weeks setup + 14 days minimum test cohort | Phase 281 (Android deployment) | Create play account week 4; recruit 12 testers by week 8 |
| **Domain registration & DNS** | 1–3 days (registration), 24–48h (propagation) | Phase 141 (website production) | Purchase week 4; configure week 5 |
| **Supabase production account** | 1 week | Phase 021 (database authorization) | Activate week 1; budget config review |
| **GitHub/CI setup** | 3–5 days | Phase 001 (baseline) | Week 1 prereq |


## Staffed 12-week option (recommended path)

**Team:** 4–6 engineers, part-time QA, legal advisor, operations.

**Roles:**
- **Mobile (Flutter):** 1–2 engineers (Workstreams 4–7, UI fixes)
- **Backend/Security:** 1–2 engineers (Workstreams 2–3, database, identity, Edge Functions)
- **Web:** 1 engineer (Workstream 8, Astro website)
- **Integration/Ops:** 1 part-time engineer (CI, deployment, env management)
- **QA:** 1 part-time (testing, store submissions)
- **AI/Advanced:** 0–1 (reserved for Workstreams 9–11 post-launch)

**Weeks 1–2:** Baseline (WS1), scope freeze, accounts, threat model → Phase 001–020 (deliverable: foundation gate evidence)

**Weeks 2–5:** Database, identity, OTP (WS2–3) → Phases 021–060 (deliverable: identity gate evidence, live database)

**Weeks 3–7:** Flutter live, contact, media (WS4–5) → Phases 061–100 (deliverable: app acceptance gate)

**Weeks 4–8:** Website shell, search, geography (WS6–8, partial) → Phases 101–160 (deliverable: website production live)

**Weeks 6–10:** Moderation, privacy operations (WS13 partial), performance/security remediation → Phases 261–280 (partial) (deliverable: security regression pack clear, ops playbooks)

**Weeks 8–11:** Android release signing, closed-track testing (Phase 281–300 partial) → Deliverable: release candidate, 12-tester cohort active

**Week 12:** Go/no-go gate, controlled rollout if gates pass → Deliverable: staged launch or explicit blockers named

**Parallel tracks (can run alongside main path):**
- Weeks 1–3: Legal review, SMS registration setup (external)
- Weeks 1–4: UI/design fixes, accessibility review
- Weeks 5–8: Model account setup, AI prompt development (for post-launch)
- Weeks 7–12: Play Store review, metadata, store graphics

## Solo developer schedule (30 h/week, realistic)

**Core-release slice (Workstreams 1–8 + required WS13–15):** 601–1,202 base hours; with 25% contingency **751–1,503 hours** = 25–50 weeks at 30 h/week (**~6–12 months**).

**Realistic solo timeline with sequential external waits:**
- Weeks 1–2: Baseline, accounts, SMS registration submit (parallel)
- Weeks 3–5: Database, identity (Phases 021–060, gated by SMS DLT if delayed)
- Weeks 6–10: Flutter live, media, reports (Phases 061–100)
- Weeks 11–15: Website, search, multilingual (Phases 101–160)
- Weeks 16–20: Moderation ops, privacy, deletion (WS13 IN: phases 241–250)
- Weeks 21–23: DevSecOps essentials, backup/restore (WS14 IN: phases 261–276)
- Weeks 24–30: Android build, store setup, deployment (WS15: phases 281–300, gated by Play account)
- Weeks 31+: Closed testing, go/no-go review, staged rollout (if gates pass)

**Gating dependencies:**
- SMS DLT registration: 2–4 week lead; blocks Phase 043 (OTP)
- Play Store account: 1-week setup; requires week 20+ for Phase 281
- Legal review: 2–8 weeks; engage week 1, may extend schedule

**Full 320-phase roadmap solo:** Not feasible in 12 weeks (~60+ h/week unsustainable); core slice targets realistic 5–11 month solo delivery.

## Residual risks and contingency

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| SMS DLT registration delayed >4 weeks | Medium | Blocks Phase 043 (OTP), delays identity launch | Start week 1; use test credentials in staging; fallback to email OTP if needed |
| Play Store closed-testing requires >14 days | Low | Delays Phase 281–300 | Create account week 4; recruit testers by week 8; run 14-day trial in parallel with beta builds |
| Legal review uncovers new DPDP obligations | Medium | Adds 1–2 weeks; may require architecture changes | Engage week 1; run advisory sprint weeks 2–3 |
| Supabase RLS edge case discovered late | Low | Adds 2–4 hours per case; triggers re-review | Test RLS with adversarial queries in Phase 023–026; regression pack before launch |
| Integration complexity (composition root, migrations) exceeds estimate | Medium | Extends schedule by 5–10% | Phase 018 file-ownership model + serialization mitigates; review each merge with integration owner |
| Reviewer capacity (Opus) bottleneck | Medium | Delays phase progression if serial review | Parallelize independent workstreams; use evidence protocol to reduce re-review |

**Contingency buffer:** Already included in 25% (1,175–2,350 hour range); do not remove for schedule pressure.

## External account and provisioning checklist

| Task | Lead time | Start week | Owner | Approval gate | Notes |
|---|---|---|---|---|---|
| GitHub repo + CI setup | 1 day | Week 1 | Product lead | Phase 001 evidence | Automated testing, branch protections |
| Supabase production project | 1 week | Week 1 | Backend engineer | Phase 021 gate | RLS audit before Phase 021 completion |
| SMS provider (DLT/India registration) | 2–4 weeks | Week 1 | Ops/Product | Phase 043 gate | Request test credentials immediately |
| Google Play developer account | 1 day registration | Week 4 | Product | Phase 281 | Register closed testing track week 4; recruit testers week 6–8 |
| Domain registration | 1–3 days | Week 4 | Ops | Phase 141 gate | Configure DNS; allow 24–48 h propagation |
| Model API account (e.g., OpenAI, Claude) | 1–2 weeks | Week 2 | AI engineer (if hired) | Phase 161 | Not required for core launch; deferred to Phase 161 if budget waits |
| Legal counsel on retainer | Ongoing engagement | Week 1 | Product lead | Phase 012 gate (threat model), Phase 241 gate (privacy ops) | Advisory throughout; formal reviews weeks 2–3, weeks 10–11 |

## Smallest safe core-release slice (plan lines 82–88: real identity, contact, reporting, deletion, legal, operations, Android, website)

**Phases included (from summed Effort ranges):**

| Workstream | Phases | Base hours | Status |
|---|---|---|---|
| WS1 (Baseline, scope) | 001–020 | 40–80 | IN |
| WS2 (Database auth) | 021–040 | 80–140 | IN |
| WS3 (Identity, OTP) | 041–060 | 60–120 | IN |
| WS4 (Flutter live) | 061–080 | 60–120 | IN |
| WS5 (Media, evidence) | 081–100 | 60–120 | IN |
| WS6 (Search, geo) | 101–120 | 60–120 | IN |
| WS7 (Multilingual) | 121–140 | 40–100 | IN |
| WS8 (Website) | 141–160 | 60–120 | IN |
| WS9–12 (AI, experiments) | 161–240 | 320–640 | DEFERRED |
| **WS13 partial** | 241–260 | 39–78 (IN, 13 phases) | Mixed |
| **WS14 partial** | 261–280 | 45–90 (IN, 15 phases) | Mixed |
| **WS15 (Deploy, launch)** | 281–300 | 57–114 (IN, 19 phases; 298 deferred) | IN |

**WS13 (Admin, privacy, moderation, commercial) breakdown:**
- **IN:** 241, 242 (role matrix), 243, 244, 247 (processor register), 248, 249 (data access), 250, 251 (retention), 252, 253 (breach notification), 254, 260 (gate) = 39–78 hours
- **DEFERRED:** 245 (healthcare, off by flag), 246 (appeals handled manually by support), 255–259 (notifications/commercial; payments off)

**WS14 (DevSecOps, reliability) breakdown:**
- **IN:** 261–267 (incl. Flutter CI 263, DB policy CI 264, release integrity 267), 269, 270 (alerts), 271, 273, 274, 276, 277 (independent security verification), 280 (gate) = 45–90 hours
- **DEFERRED:** 268, 272, 275, 278, 279 (scale/cost work; revisit before public rollout if pilot load grows)

**WS15 (Deployment, launch):** 281–297, 299, 300 = 57–114 hours. **Deferred-disabled:** 298 (AI cohort; AI flag off).

**Core-release slice total (recomputed from each phase's Effort line in the plan):**
- Base: WS1–8 (460–920) + WS13 IN (39–78) + WS14 IN (45–90) + WS15 IN (57–114) = **601–1,202 hours**
- With 25% contingency: **751–1,503 hours**
- Solo @ 30 h/week: **25–50 weeks** (~6–12 months; not a 4-week or 12-week delivery with realistic scope). WS5–8 hours are an upper bound when media intake stays disabled.

**Feature flags for deferred items (per plan lines 112–114):**
- Saathi AI: `FEATURE_AI_ENABLED = false` → UI, endpoints, jobs disabled; core behavior independent
- Commercial/payment: No endpoints registered; store listing disabled
- Advanced experiments (phases 221–240): Optional flags per feature; deferred post-launch

## Engineering team and owner assignments

**Named reviewers (per plan line 79: must be named humans, not counted as FTE for implementation):**
- Chief engineer (Opus model + named human); bottleneck risk—parallelize independent workstreams.

**Implementation team (counted in capacity projections):**

| Role | Owner(s) | Capacity | Notes |
|---|---|---|---|
| Mobile (Flutter) | TBD (1–2 engineers) | 1–2 FTE | Workstreams 4–7 (phases 061–140) + UI fixes |
| Backend/security | TBD (1–2 engineers) | 1–2 FTE | Workstreams 2–3, 9–10 (phases 021–060, 161–200) |
| Web/operations | TBD (1 engineer) | 1 FTE | Workstreams 8, 14–15 (phases 141–160, 261–300) |
| Integration owner | Product lead or named engineer | 0.5 FTE | File ownership, composition root, migration serialization (phase 018 protocol) |
| QA/acceptance | TBD (part-time) | 0.25–0.5 FTE | Phase gates, regression pack, release signing |

## Security/privacy effect
- **Authorization:** No changes at this phase (planning only)
- **Data exposure:** No new endpoints
- **Incident controls:** Schedule clarity reduces deployment surprises; named external waits improve incident posture
- **Credential handling:** None; this phase is administrative

## Residual risks and rollback

**Known unknowns:**
- Exact SMS DLT approval timeline (2–4 weeks stated; may vary by provider and season)
- Play Store closed-testing cohort size and availability (12 testers committed? Where recruited?)
- Legal review scope and DPDP applicability (may expand; depends on ops model)
- Supabase RLS performance at scale (tested with representative data)

**Rollback:** This phase creates no deployable artifacts or data changes. Rollback is schedule reset; re-baseline if dependencies change.

## Next action
- **Approval:** Opus signs off on staffing options, cut lines, and external-wait schedule
- **Dependency:** Phase 020 (Foundation gate) consumes evidence from 001–019 before phases 021+ proceed
- **Owner:** Product lead
- **Explicit action:** Decide staffing model (solo vs. 4-engineer vs. 6-engineer team); confirm external account owners (SMS vendor, Play Store, legal counsel); adjust weeks if waits are longer; proceed to phase 021 (Database authorization).

## Chief-engineer review (2026-10-06) — folded into the tables above on 2026-10-07

The worker's slice deferred controls that the plan's core cut line (plan lines 82–88) and non-negotiable gates require: 242 role matrix (authorization), 247/249/251/253 (processor register, data access, retention, breach-notification process — legal/privacy), 263/264/267 (Flutter + DB policy CI, release integrity — the security regression pack is a gate), 270/277 (alerts, independent security verification), and the gates 260/280 themselves. Corrected classification:

- **WS13 IN:** 241, 242, 243, 244, 247, 248, 249, 250, 251, 252, 253, 254, 260. **Deferred:** 245 (healthcare off by flag), 246 (appeals handled manually by support until volume justifies), 255–259 (notifications/commercial; payments off).
- **WS14 IN:** 261–267, 269, 270, 271, 273, 274, 276, 277, 280. **Deferred:** 268, 272, 275, 278, 279 (scale/cost work; revisit before public rollout if pilot load grows).
- **WS15 IN:** 281–297, 299, 300. **Deferred-disabled:** 298 (AI cohort; AI flag off).

Recomputed from each phase's Effort line (awk over the plan):
```
IN 241-300: 141-282 h (47 phases)
WS1-8:      460-920 h
```
**Core slice base: 601–1,202 h; with 25% contingency 751–1,503 h; solo at 30 h/week ≈ 25–50 weeks.** WS5–8 hours are an upper bound when media intake stays disabled.

Status: accepted with this correction.
