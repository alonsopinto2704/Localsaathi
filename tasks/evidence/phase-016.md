# Phase 016 — Environment & Cost Worksheet

**Status:** In review  
**Objective:** Define dev/staging/production environments, resource inventory, and a cost model with low/expected/stress scenarios; identify owner decisions needed for pricing confirmation.  
**Changed paths:** None (planning document, evidence-only)  
**Inputs reviewed:** implementation-plan (ADRs, release gates), backend/supabase/config.toml, docs/backend-contract.md, pubspec.yaml, play-store requirements, Vercel/Supabase pricing tiers (as of Oct 2026)

---

## Environment & Resource Matrix

### Development (Local)

| Resource | Specification | Owner | Data Retention | Backups | Notes |
|---|---|---|---|---|---|
| **Postgres** | PGlite (local, Docker) via `supabase start` | Developer | Session only | N/A | Disposable; reset via `supabase db reset` |
| **Auth** | Supabase Auth (local instance) | Developer | Test OTPs in config.toml | N/A | Local SIM: +911234500000 → 123456 |
| **Storage** | Local filesystem (Docker volume) | Developer | Session only | N/A | Photos/docs discarded on reset |
| **Secrets** | .env.local (NOT in git) | Developer | Session only | N/A | Contains SUPABASE_URL, SUPABASE_ANON_KEY (test values) |
| **Flutter** | SDK + Android emulator or device | Developer | N/A | N/A | Local; no cloud backup needed |
| **CI/GitHub** | Public repo (open-source or private) | Developer | Indefinite | GitHub's retention | Actions logs deleted after 90 days (free tier) |
| **Cost** | $0 | — | — | — | Local infrastructure only |

### Staging (Pre-Production Verification)

| Resource | Specification | Owner | Data Retention | Backups | Notes |
|---|---|---|---|---|---|
| **Supabase Project** | Staging instance, ap-south-1 (Mumbai) or closest | Platform Engineer | Test data only | Daily automated | Small project tier ($25/month est.) or free tier during testing |
| **Auth** | Supabase Auth + test SMS provider (e.g., Firebase Test Mode or Twilio sandbox) | Platform Engineer | Test OTPs, no real users | N/A | Real SMS provider NOT used; test tokens only |
| **Postgres** | ~100 MB test data (all categories, 50 test providers, locations) | Platform Engineer | Test data; purged monthly | Daily automated (Supabase) | Replica of prod schema; prod RLS policies enforced |
| **Storage** | test-photos bucket (Supabase Storage) | Platform Engineer | Test images; purged monthly | Automated | ~1 GB max |
| **Edge Functions** | delete-account (index.ts) + test gateway stub | Platform Engineer | None (read-only testing) | Via version control | Deployed via `supabase functions deploy` |
| **Website** | Preview deployment (Vercel or Netlify preview branch) | Frontend Engineer | Transient (auto-cleanup) | N/A | Non-indexed; robots.txt: User-agent: \* Disallow: / |
| **Android** | Google Play internal testing track | Mobile Engineer | Build artifacts only | N/A | APK/AAB uploaded; revoked after test conclusion |
| **SMS Provider** | Test account (Firebase Phone Auth test mode, or Twilio sandbox) | Platform Engineer | No real SMS sent | N/A | Rate limit: 1000/day; no cost |
| **Monitoring** | Sentry (error tracking, free tier) | Platform Engineer | 14-day retention (free) | N/A | Optional; helps catch regressions |
| **Cost** | $25–50/month | — | — | — | Supabase staging + SMS test + optional Sentry |

### Production

| Resource | Specification | Owner | Data Retention | Backups | Notes |
|---|---|---|---|---|---|
| **Supabase Project** | Production instance, ap-south-1 (Mumbai preferred) | Product Owner + Ops | Live user data | Daily incremental, weekly full backup | Pro tier ($109/month est.) or higher based on usage |
| **Auth** | Supabase Auth + SMS provider (TO QUOTE: MSG91, Gupshup, Firebase, Twilio) | Product Owner | Per DPDP rules (~6 months unless longer retention justified) | Included in Supabase backup | Real SMS delivery; rate-limit enforcement |
| **Postgres** | Live provider + customer data, with RLS enforced | Ops | Per retention policy (DPDP rules checklist: Phase 013) | Automated daily + on-demand restore drills | RPO ≤ 24h; RTO ≤ 4h (Phase 001 target) |
| **Storage** | Supabase Storage: public-profiles (CDN) + private-credentials | Ops | User uploads: retention = profile lifetime + grace period (~30 days after deletion) | Automated; versioning enabled | Egress: assume 10GB/month at launch (Phase 016 cost model) |
| **Edge Functions** | delete-account + AI gateway + rate-limiter | Ops | Deployment versions only (code, no execution logs) | Via version control + Vercel backup | Secrets stored in Supabase secrets manager |
| **Website** | Vercel (or equivalent static host) + custom domain | Frontend Engineer | Prod site; non-indexed (indexingEnabled: false until launch gate) | Via GitHub + Vercel | Purge on-demand; rebuild 1x/day or manual |
| **Android App** | Play Store listing + APK/AAB | Mobile Engineer | Build artifacts + release notes | GitHub releases + Play Console | Signing key: held by owner (Phase 007) |
| **SMS Provider** | Real SMS gateway with DLT registration (India requirement) | Ops | SMS logs per provider's policy | Provider's standard | Cost: TO QUOTE per SMS (typically ₹0.50–2 per OTP + higher for marketing SMS) |
| **AI Gateway** | LLM API (OpenAI, Anthropic, etc. — TO DECIDE Phase 161) | Ops | Request/response logs for 30 days (audit), then purge | Included in provider's backup | Cost: TO QUOTE per token/request |
| **Monitoring & Logging** | Sentry (error tracking) + Supabase logs (PostgREST, Edge Functions) | Ops | 30-day retention (Sentry Pro, ~$29/month) | Logs auto-cleaned by retention policy | Critical for incident response |
| **Domain** | custom domain (localsaathi.com or similar — not purchased yet) | Product Owner | Indefinite (domain owner's responsibility) | WHOIS privacy + annual renewal | Cost: ₹500–2000/year depending on registrar |
| **Cost** | $300–800/month est. (see cost model below) | — | — | — | Before SMS provider + AI model pricing confirmation |

---

## Cost Model: Low / Expected / Stress Scenarios

### Usage Assumptions (Monthly)

| Metric | Definition | Low Scenario | Expected Scenario | Stress Scenario | Unit |
|---|---|---|---|---|---|
| **Registered Users (Providers)** | Active provider accounts, end of month | 100 | 500 | 2,000 | accounts |
| **Monthly Active Users (Providers)** | Providers who edited profile or responded to contact in the month | 50 | 200 | 800 | accounts |
| **Unique Visitors (Website)** | Unique IPs accessing website pages (no tracking cookie) | 500 | 2,000 | 10,000 | IPs |
| **OTPs Issued (Auth)** | Phone verification attempts across all users | 500 | 2,000 | 10,000 | OTPs |
| **OTP Delivery Success Rate** | Percentage of OTPs delivered (not sent) | 95% | 98% | 98% | % |
| **Search Queries** | Provider searches via app or website | 2,000 | 10,000 | 50,000 | queries/month |
| **Photos Uploaded** | New provider profile photos (lifetime max 5 per provider) | 200 | 1,000 | 5,000 | photos |
| **Storage Used** | Photos + document backups (avg 2 MB/provider) | 200 MB | 1 GB | 4 GB | GB |
| **Storage Egress** | Data served from CDN to customers + website | 2 GB | 10 GB | 50 GB | GB/month |
| **AI Requests (Chat)** | Grounded AI assistant queries (Phase 161+) | 0 | 100 | 1,000 | requests/month |
| **AI Tokens (LLM)** | Input + output tokens to LLM API (avg 2K tokens/request) | 0 | 200K | 2M | tokens/month |

---

### Cost Breakdown (Prod, All Scenarios)

#### Supabase (Postgres + Auth + Storage + Edge Functions)

| Component | Low | Expected | Stress | Notes |
|---|---|---|---|---|
| **Base Tier** | $25 | $109 | $109+ | Free: $0; Pro: $109/month (1M egress free, $0.13/GB after) |
| **Compute (extra)** | $0 | $0 | $50–100 | Added CPU/RAM if queries exceed baseline; auto-scaling |
| **Storage Overage** | $0 | $0 | $50+ | $0.025/GB/month; 4 GB = $100/month |
| **Egress Overage** | $0 | $0 | $4–6.50 | Pro includes 1 GB free; $0.13/GB after; 50 GB = $6.37 |
| **Subtotal** | **$25** | **$109** | **$200+** | TO QUOTE exact pricing at execution (Oct 2026 rates may differ) |

#### SMS Provider (OTP Delivery)

| Provider | Cost Model | Low | Expected | Stress | Notes |
|---|---|---|---|---|
| Firebase Phone Auth | Free / Pay-as-you-go | $0 | $0–20 | $20–50 | 10K free/month; then $0.06/SMS in India (unconfirmed; check docs) |
| MSG91 (India-native) | Prepaid balance | ₹500–2000/month | ₹1000–5000 | ₹5000–15000 | Typical: ₹0.50–2.00/OTP; DLT registration required |
| Gupshup | Prepaid balance | ₹1000–3000 | ₹2000–8000 | ₹8000–20000 | Similar to MSG91; popular in India |
| Twilio | Pay-as-you-go + commitment discounts | $20–50 | $50–200 | $200–500 | $0.01–0.075 per SMS depending on country/volume |
| **Estimated for LocalSaathi** | Assume MSG91 or Gupshup | ₹500–2000 | ₹2000–5000 | ₹5000–15000 | **TO QUOTE at execution** — owner decision Phase 041 |
| **USD Conversion (approx.)** | — | $6–24 | $24–60 | $60–180 | At 83 INR/USD; FX varies |

#### AI Gateway (LLM API)

| Provider | Cost Model | Low | Expected | Stress | Notes |
|---|---|---|---|---|
| OpenAI (gpt-4-turbo) | $0.01–0.03 per 1K in/out tokens | $0 | $6–12 | $60–120 | 200K tokens/month = 100K calls × 2K tokens; regional pricing varies |
| Anthropic (Claude 3 Haiku) | $0.25 per 1M input, $1.25 per 1M output tokens | $0 | $0.50–2 | $5–10 | Cheapest option; low latency; used in Phase 015 examples |
| Anthropic (Claude 3 Sonnet) | $3 per 1M input, $15 per 1M output | $0 | $6–15 | $60–150 | Mid-range quality; trade-off between Haiku and Opus |
| **Estimated for LocalSaathi** | Assume Haiku for launch (cheapest) | $0 | $1–3 | $10–20 | **TO QUOTE at execution** — owner decision Phase 161; scale up to Sonnet if quality insufficient |

#### Website Hosting & CDN

| Provider | Cost Model | Low | Expected | Stress | Notes |
|---|---|---|---|---|
| Vercel (Hobby/Pro) | Free (Hobby) or $20/month (Pro) | $0 | $20 | $20 | Hobby: 100 GB bandwidth/month free; Pro: unlimited egress from Vercel edge |
| Netlify (Free/Pro) | Similar; Free: 300 build minutes/month | $0 | $19 | $19 | Comparable; either works; assume Vercel |
| **Estimated for LocalSaathi** | Vercel Pro for prod | $0 | $20 | $20 | Includes analytics (free tier); no separate analytics charge |

#### Domain & SSL

| Component | Cost | Notes |
|---|---|---|
| **Domain** (localsaathi.com or .in) | ₹500–2000/year (~$6–24/month avg) | One-time at launch; renewal auto. Registrar: GoDaddy, Namecheap, or in-country registrar |
| **SSL Certificate** | $0 | Vercel/Netlify + Let's Encrypt automatic; no additional cost |
| **Estimated for LocalSaathi** | **$6–24/month** | **TO DECIDE** — owner selects domain name; only then exact cost known |

#### Monitoring & Error Tracking

| Service | Cost Model | Low | Expected | Stress | Notes |
|---|---|---|---|---|
| Sentry (Free) | Free tier; 5K events/month, 30-day retention | $0 | $0 | — | Suitable for small launch pilot |
| Sentry (Pro) | $29/month per team member; 100K events/month | $0 | $29 | $29 | Recommended for production (incident response, alerts) |
| **Estimated for LocalSaathi** | Sentry Pro (1 person initially) | $0 | $29 | $29 | Critical for post-launch reliability |

#### Google Play Console

| Component | Cost | Notes |
|---|---|---|
| Developer Account | $25 one-time | No annual fee; pay once, account open indefinitely |
| In-App Purchases (future) | 15% platform fee | Not included in Phase 1 launch (monetization Phase 241+) |
| **Estimated for LocalSaathi** | **$25 one-time** | **TO PAID by owner** — not an ongoing cost |

#### Contingency & Miscellaneous

| Item | Est. | Notes |
|---|---|---|
| Load testing / capacity audit | $500–1000 | One-time; conducted Phase 281 (deployment) |
| Security audit / penetration test | $2000–5000 | One-time; recommended pre-launch (Phase 012 threat model should inform scope) |
| Legal review (DPDP, privacy, T&C) | $1000–3000 | One-time; payable to qualified counsel (Phase 013+) |
| **Estimated** | **$3500–9000** | Optional, but recommended for launch confidence |

---

### Total Monthly Cost Model (Prod)

| Scenario | Supabase | SMS | AI | Website | Domain | Monitoring | Misc. | **Total/Month** | **Annual** |
|---|---|---|---|---|---|---|---|---|---|
| **Low (100 providers, 500 users/month)** | $25 | $6 | $0 | $0 | $2 | $0 | $0 | **$33** | **$400** |
| **Expected (500 providers, 2K users/month)** | $109 | $40 | $2 | $20 | $2 | $29 | $0 | **$202** | **$2,424** |
| **Stress (2K providers, 10K users/month)** | $200 | $120 | $15 | $20 | $2 | $29 | $0 | **$386** | **$4,632** |

**Notes on "Stress" scenario:**
- Supabase overages assume 4 GB storage + 50 GB egress (Phase 016 assumptions).
- SMS assumes ₹5000–15000/month (₹0.50–2/OTP average) via MSG91 or Gupshup.
- AI assumes Claude 3 Haiku at 1000 requests/month (2K tokens average) = ~2M tokens = ~$12–15.
- Website assumes Vercel Pro; egress within free tier.
- Monitoring assumes Sentry Pro (incident response, production essential).
- One-time costs (Google Play $25, domain setup, legal review, security audit) are NOT included in monthly totals.

---

### Spending Ceilings & Alert Owners

**Production Monthly Spending Limits:**

| Threshold | Alert Owner | Action |
|---|---|---|
| $150 | Product Owner | Weekly spend review; escalate if trending to $200 |
| $250 | CTO / Platform Owner | Investigate cost drivers; consider cost-optimization measures (e.g., switch SMS provider, reduce AI requests, optimize Supabase queries) |
| $350 | Board / Founder | Halt new feature launches until cost stabilized; conduct cost audit (Phase 016 assumptions vs. actual); consider deferring AI feature if cost exceeds budget |

**Staging Monthly Limit:** $50 (terminate daily if > $75)

**Development:** $0 (local only; no external services)

---

### One-Time / Pre-Launch Costs (Owner Authorization Required)

| Item | Amount | Approver | Status | Notes |
|---|---|---|---|---|
| Google Play Developer Account | $25 USD | Product Owner | Ready to pay | No approval gate; standard one-time fee |
| Supabase Project Setup (prod) | $0 (included in Pro tier) | Platform Owner | Blocked on SMS provider decision (Phase 041) | Verified in Phase 006; no cost to create project, only to run queries/store data |
| SMS Provider Account & DLT Registration | ₹2000–5000 upfront | Ops + Legal | **BLOCKED** — requires Phase 041 decision (MSG91 vs. Gupshup vs. Firebase vs. Twilio) | Approval workflow: Phase 041 research → owner decision → account setup → DLT registration (2–4 weeks lead time in India) |
| Domain Registration | ₹500–2000 (~$6–24) | Product Owner | **BLOCKED** — owner must choose domain name (Phase 009 business decision) | Registrar: GoDaddy, Namecheap, or in-country registrar (e.g., BigRock) |
| LLM API Account (OpenAI/Anthropic) | $0 (free tier or BYOK) | Ops | **BLOCKED** — owner decision Phase 161 (model selection) | No approval for card; setup at implementation time |
| Security Audit | $2000–5000 | Board / CTO | Optional; recommended if launch date < 8 weeks | Scope: Supabase RLS, Edge Functions, Flutter client authorization, website OWASP Top 10 |
| Legal Review (DPDP, Privacy, T&C) | $1000–3000 | Legal + Product Owner | **REQUIRED before launch** — Phase 013+ | Approver: Qualified Indian data-protection counsel; must sign off before play-store submission |

---

## Cost Model as CSV (For Spreadsheet Import)

```
Scenario,Component,Unit,Quantity,Unit_Price_USD,Total_Monthly_USD,Notes
Low,Supabase Pro,month,1,25,25,Base tier; 1M egress free
Low,SMS (MSG91),OTPs,500,0.012,6,Assume $0.012 per OTP (₹1 avg)
Low,AI (off),requests,0,0,0,Saathi AI not live yet
Low,Website (Vercel),month,1,0,0,Hobby tier (free); 100 GB bandwidth free
Low,Domain (avg),month,1,2,2,₹500-2000/year amortized (~$2/month)
Low,Monitoring (Sentry free),month,1,0,0,Free tier; 5K events/month
Low,TOTAL_LOW,,,,,33
Expected,Supabase Pro,month,1,109,109,Base tier + compute (if needed)
Expected,SMS (MSG91),OTPs,2000,0.020,40,Assume $0.020 per OTP (₹1.67 avg)
Expected,AI (Haiku),1M tokens,0.2,1.25,2,200K tokens/month; $0.25 per 1M input + $1.25 per 1M output
Expected,Website (Vercel Pro),month,1,20,20,Pro tier; unlimited egress from Vercel edge
Expected,Domain (avg),month,1,2,2,Registrar renewal
Expected,Monitoring (Sentry Pro),month,1,29,29,Incident response; recommended for production
Expected,TOTAL_EXPECTED,,,,,202
Stress,Supabase Pro + Overages,month,1,200,200,"Base $109 + compute $50 + storage overage $50; 4 GB storage, 50 GB egress"
Stress,SMS (MSG91),OTPs,10000,0.012,120,"Assume $0.012 per OTP; ₹0.50-2 typical; stress = higher volume"
Stress,AI (Haiku),1M tokens,2,1.25,15,"2M tokens/month; 1000 requests × 2K tokens; Haiku ~$0.125 per request"
Stress,Website (Vercel Pro),month,1,20,20,Pro tier; egress free
Stress,Domain (avg),month,1,2,2,Registrar renewal
Stress,Monitoring (Sentry Pro),month,1,29,29,Production essential
Stress,TOTAL_STRESS,,,,,386
```

---

## Residual Uncertainty & Owner Decisions Needed

1. **SMS Provider & DLT Registration (Phase 041):** Which SMS provider? Gupshup, MSG91, Firebase, or Twilio? This decision affects monthly cost by $50–150 and legal compliance timeline (DLT registration 2–4 weeks in India). → **Owner decision, blocking Phase 041.**

2. **LLM Model Selection (Phase 161):** OpenAI (gpt-4-turbo, $6–12/month in expected scenario) vs. Anthropic Claude (Haiku $1–3, Sonnet $6–15)? Quality/latency/cost trade-off. → **Owner decision, blocking Phase 161.**

3. **Domain Name (Phase 009):** localsaathi.com vs. .in vs. other? Affects registration cost (₹500–5000) and brand identity. → **Owner decision, unblocked; ready to proceed when owner chooses.**

4. **Sentry Pro vs. Free (Phase 281):** Is production error tracking ($29/month) justified, or use free tier? Affects incident response SLA. → **Recommended for production; revert to free tier only if monthly spend ceiling exceeded.**

5. **Website Analytics (Phase 005):** Vercel Analytics (free, in Vercel Pro), Plausible ($9–20/month, privacy-friendly), or none? → **Assumed Vercel free tier; no additional cost in model.**

6. **Security Audit Scope (Phase 012):** Full penetration test ($5K+), or risk-based audit focusing on RLS + Edge Functions ($2K)? → **Recommended; approve once Phase 012 threat model is finalized.**

7. **Legal Review Timeline (Phase 013):** Must complete before Play Store submission (Phase 281). Allocate 2–4 weeks + ₹1000–3000 cost for DPDP + privacy + T&C review by qualified counsel. → **Required before launch; authorize in Phase 013.**

---

## Next Integration Actions

1. **Phase 041 (Identity, OTP):** Owner decides on SMS provider. Once chosen, Ops can set up account + DLT registration (2–4 weeks lead time).
2. **Phase 161 (AI Gateway):** Owner decides on LLM provider. Ops provisions API account + rate-limiter.
3. **Phase 016 handoff:** Update cost model with actual unit prices (SMS per-OTP, AI per-token, domain registrar quote). Re-baseline spending ceilings if totals differ from estimates.
4. **Phase 281 (Deployment):** Before go-live:
   - Verify staging cost is < $50/month (adjust resource cleanup if needed).
   - Run a 7-day production dry-run with scaled test load; measure actual costs vs. model predictions.
   - Obtain legal sign-off on DPDP + privacy + T&C.
   - Confirm all spending ceilings are approved + alarms configured.


## Chief-engineer review (2026-10-06)

- Every currency figure in this worksheet is an **unverified indicative placeholder**, not a quote; scenario totals ($25/$109/$200+ etc.) must be recomputed from real quotes at execution before any spending decision. No accounts were created.
- Status: accepted as a template; numbers not decision-grade.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| Development environment has $0 cost | Confirmed | Local development uses `supabase start` (free), Docker free, no cloud resources |
| Staging cost estimate $25-50/month | Unsupported | Estimates provided but not quoted; no staging account created |
| Production cost breakdown provided | Confirmed | Three scenarios (Low/Expected/Stress) with itemized costs |
| SMS provider cost estimates provided | Confirmed | Table shows Firebase, MSG91, Gupshup, Twilio with low/expected/stress scenarios |
| No actual accounts created | Confirmed | Chief-engineer note explicitly states "No accounts were created" |
| Chief-engineer review present | Confirmed | Cost figures explicitly marked as "unverified indicative placeholder" |

Cost worksheet is well-structured and transparent about uncertainty. All figures correctly marked as unquoted estimates requiring confirmation before spending decisions.
