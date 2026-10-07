# Idea Council verdicts

## 2026-10-06 — LocalSaathi core launch slice (phases 001–020 scope)

**Idea:** Mumbai-first local-services directory (Flutter Android + Astro site + Supabase), guest browsing, en/hi/mr, phone-verified providers; AI and paid promotions later.

```
VERDICT: FIX FIRST
BIGGEST RISK: Free incumbents (Google Maps, JustDial, WhatsApp groups) already cover discovery; LocalSaathi has no proven reason to switch.
10-MINUTE TEST: Search Google Maps + JustDial for "plumber Andheri West"; call/WhatsApp 5 listed numbers and note how many are stale, unreachable, or upsell-gated. Then ask those 5 providers if they'd list for free on a local directory.
FLIP TO BUILD: One real data point that incumbents fail the pilot cluster (e.g. >=2 of 5 numbers stale/unreachable, or >=3 of 5 providers say they want a free listing outside JustDial), PLUS keep the launch slice to one contiguous cluster and ~10-15 categories with AI/promotions off.
EVIDENCE USED: none, capped at FIX FIRST
```

- **Skeptic (blind):** "Someone does it free" — JustDial/Google/Instagram already own local discovery; no payer; too big for a solo dev.
- **Believer:** The wedge is trust evidence incumbents don't show (freshness of availability, checked-vs-claimed credentials, no lead-selling), in Hindi/Marathi, for one dense cluster. Must be true: (1) incumbent numbers are often stale/spammy, (2) providers will refresh availability, (3) one cluster can be seeded densely enough to beat Maps on relevance.
- **Investor:** No clear payer at launch (guess). Possible later payer: providers paying for featured placement (guess: ₹99–299/month); first revenue not before a dense pilot proves contact volume. Cost to reach a provider = field visit/WhatsApp outreach (guess).

**Effect on plan:** phase 009 slice stays small (one contiguous cluster); phase 017 keeps AI and promotions default-off; phase 008 interviews must test the incumbent-failure hypothesis first.

## 2026-10-07 — LocalSaathi after phases 001–040 (re-review incl. website + two external audits)

**Idea:** Same Mumbai-first directory; now with a hardened Supabase backend (22 migrations, 172 pgTAP assertions), a green Flutter mock app, a static showcase site, and zero real providers or users.

**Earlier verdict (2026-10-06):** FIX FIRST — free incumbents; flip = one real incumbent-failure data point + small slice. **What changed:** 40 phases of engineering; the flip test was never run.

```
VERDICT: FIX FIRST
BIGGEST RISK: Engineering is outrunning evidence — 40 phases of backend hardening with no proof anyone switches from JustDial/Maps/WhatsApp, and seed density is 1 plumber per pilot locality vs the ≥10 the plan itself requires.
10-MINUTE TEST: Search Google Maps + JustDial for "plumber Andheri West"; call/WhatsApp 5 listed numbers; tally stale/unreachable/upsell-gated; ask those 5 if they'd list free on a no-lead-selling directory.
FLIP TO BUILD: The desk test passes (>=2/5 stale or >=3/5 providers want a free listing) AND 10 real providers in one category across the 4 Andheri/Jogeshwari/Vile Parle localities agree to list, before any Workstream 3 spend (real SMS/OTP, DLT registration).
EVIDENCE USED: none, capped at FIX FIRST
```

- **Skeptic (blind):** Ranked: (1) someone does it free — JustDial, Google Maps and society WhatsApp groups already answer "plumber near me"; (2) cold start — a directory with 1 listing per locality is worse than Maps; (3) too big for one person (601–1,202 h core slice). Top: (1), still unanswered by any outside data.
- **Believer:** The wedge is real and now built server-side: phone-confirmed numbers, no lead selling, consent-gated contact, Hindi/Marathi, honest "phone-verified" labels. Must be true: incumbent numbers are often stale/spammy; 10+ providers per category per locality can be signed up by hand; providers will confirm availability.
- **Investor:** No clear payer — sponsored placement and billing are off by design (guess: later ₹99–299/month featured slots). Running cost low (Supabase ~$25–109/month, sourced from phase-016 template, unverified). Real cost is provider acquisition by field visits (guess: hours per provider); first revenue not before a dense pilot.

**Website:** the static `showcase/` demo was deleted on 2026-10-07 at the owner's request; testing uses the Flutter web build (port 5174); the production Astro site (phases 141–160) should wait for the flip condition — a site with no dense listings has nothing to show search engines or visitors.
