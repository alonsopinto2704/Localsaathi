# Phase 015 — Architecture Decision Records

**Status:** Done (gate passed in phase-020; human sign-off pending)  
**Objective:** Document architectural decisions, resolve Floot references, define measurable triggers for future enhancements.  
**Changed paths:** None (evidence-only, no source edits)  
**Inputs reviewed:** `implementation-plan-320-phases.md`, `tasks/plan.md`, `docs/claude-handoff.md`, `tool/export_floot_data.py`, `backend/supabase/config.toml`, `pubspec.yaml`

## Architecture Decision Records

### ADR-001: Flutter for Android App

**Context:**  
LocalSaathi has a functioning Flutter Android application (`lib/`, `android/`, `pubspec.yaml`) with six trade groups, 28+ service categories, three-language UI (English/Hindi/Marathi), and a working category/search/provider-profile flow. Flutter is proven for local development, has existing tests, and integrates with Supabase via `supabase_flutter` package. iOS is out of scope for launch; expansion would be a separate workstream.

**Decision:**  
Continue development on Flutter Android. Keep controllers, repository interfaces, and state management as-is; extend rather than rewrite. Use Flutter web (`flutter build web`) for reference screenshots and accessibility testing, not for deployment. Target API 36 per current Google Play requirements.

**Alternatives considered:**
- React Native: would require partial rewrite of existing Flutter asset; no immediate time gain.
- Native Android Kotlin: throws away existing UX, tests, and infrastructure.
- Delay iOS: acceptable; set as post-launch gate.

**Evidence:**  
- Existing: `lib/app/controllers/`, `lib/domain/models/`, `lib/features/*/screens.dart`, `lib/data/repositories/` (mock layer)
- Gradle: `android/build.gradle`, `android/app/build.gradle` (API 36; repo is already on Gradle 9.3.1 (`gradle-wrapper.properties`) and AGP 9.1.0 (`settings.gradle`), per phase-007)
- Tests: `test/localsaathi_core_test.dart`, domain + fixture tests
- Target: `flutter build appbundle --release` must succeed with 16 KB page-size alignment, R8 on, release signing

**Owner:**  
Product lead + Workstream 3 (Android release)

**Cost:**  
No incremental cost vs. stopping Flutter. Release-path cost: ~6–8 focused hours to tighten toolchain, add signing, enforce R8 alignment, run full test suite, and verify on a real device.

**Reversal path:**  
A full language rewrite would be a post-launch decision. No lock-in from Flutter; codebase can be archived and re-evaluated after a 6-month live metrics period.

**Reconsider when:**  
- If Play Store review rejects the app on technical grounds (ABI issues, API misuse, etc.) — investigate root cause before rewriting.
- If crash-free session rate in live data drops below 99.5% — prioritize stability over feature expansion.
- If new platform (iOS) is deemed launch-critical — this forces re-evaluation; flag it now.

---

### ADR-002: Supabase (Auth, Postgres, RLS, Storage, Edge Functions)

**Context:**  
A complete Postgres schema, 12 migrations, RLS on every table, SQL functions for search/registration/profile-update, and Supabase Auth are implemented in `backend/`. All repository interfaces (`lib/domain/repositories/`) are contract-based, allowing mock or Supabase implementation as a drop-in. Supabase is the only backend production service chosen; no multi-backend strategy is in flight.

**Decision:**  
Use Supabase as the single backend: Auth handles phone verification via SMS OTP (local dev: fixed test OTPs in `config.toml`; production: real SMS provider); Postgres with RLS enforces all authorization; Storage holds media (photos, credentials); Edge Functions own privileged operations (`delete-account` is the only one initially). No separate API gateway, no message queue, no vector database at launch.

**Alternatives considered:**
- Firebase: would require new schema and role mapping. RLS enforcement is available but less controllable.
- Custom Node/Express: introduces DevOps, secrets management, and scaling complexity without functional advantage.
- GraphQL federation: not justified at launch volume; REST via PostgREST + RPCs is simpler.
- Managed vector DB: wait until search p95 exceeds 800ms at documented load (Phase 101–120 verification).

**Evidence:**  
- Schema: `backend/supabase/migrations/20260101000001_extensions.sql` → `000011_storage.sql`
- Auth: `config.toml` (`auth.sms.test_otp` for dev; production SMS config documented in Phase 016)
- RLS: every table has `enable rls; grant …` statements; `verify-db.mjs` script tests authorization boundaries
- Edge Functions: `backend/supabase/functions/delete-account/index.ts` (Postgres service-role call only)
- Seed: `backend/scripts/generate_seed_sql.py` derives locations + categories from Flutter seed files (byte-identical IDs)
- Contract: `docs/backend-contract.md` lists every endpoint, RPC, and authorization rule

**Owner:**  
Workstream 1 (Backend verification) + Workstream 2 (Supabase data layer)

**Cost:**  
- Local dev: ~1–2 focused hours (Docker + Supabase CLI, `supabase start`, test runner repair per Phase 004).
- Staging: ~2–3 hours (Supabase-hosted project setup, real SMS provider integration, environment variable wiring).
- Production: included in Phase 016 provisioning; ongoing: SMS per-OTP cost + storage egress (Phase 016 cost model).

**Reversal path:**  
Schema is Postgres-standard; can be migrated to self-hosted PostgreSQL with RLS intact if Supabase cost/availability becomes untenable. No vendor lock-in for the data model. Migration would require re-pointing Flutter client to new Auth provider + PostgREST URL + redeploying Edge Functions as standalone services.

**Reconsider when:**  
- Supabase pricing exceeds budget per Phase 016 thresholds — evaluate self-hosted PostgreSQL + open-source Auth (Keycloak, etc.).
- OTP delivery SLA fails (e.g., >5% drops, >30s latency) — switch SMS provider and re-test RLS boundaries.
- Schema needs vector search: measure actual search p95 latency (Phase 101–120); if < 800ms, stay deterministic; if worse, add pgvector + trigger-based indexing within Postgres first before external vector DB.

---

### ADR-003: Static Astro Website (In-Repo, Not Floot/Lovable)

**Context:**  
An Astro-based static website is planned in `website/` (currently absent). The old exporter (`tool/export_web_data.py`) was deleted on 2026-10-07 with the showcase; the website will need a fresh exporter from `lib/data/seed/`.js`. A second script, `tool/export_floot_data.py`, was written to export to a Floot project, but the Floot platform was abandoned by the owner (decision: 2026-10-04). The website must mirror the app without creating a competing backend or duplicating logic.

**Decision:**  
Build the website as static Astro (ssg, prerendering) in-repo at `website/`. Export directory data (categories, localities, masked providers) from Flutter seed files and legal documents. Generate stable pages for: home, search results (by locality and category), city/locality/service landing pages, provider profiles, and legal pages (privacy, terms, guidelines, grievance). Use app screenshots for hero imagery; no invented testimonials or fake user counts. Keep phone numbers masked (demo data) until late-launch verification. Provider pages must not be permanently prerendered with revocable data (phone, availability, suspension): render them live or with a short, purge-on-revoke cache (target: revocation visible on fresh requests immediately, CDN purge SLA measured in phase 141+); disable static indexing (`indexingEnabled: false` config) until listings are verified non-demo.

**Alternatives considered:**
- Floot: platform abandoned; project export stale; no longer an option.
- Lovable: creates competing backend with its own auth/db; breaks "mirror the app" principle.
- Next.js SSG: unnecessary complexity over Astro; same static output.
- Flutter web deploy: not a website; no SEO, no static sharing, no offline-usable artifact.

**Evidence:**  
- Owner decision: `implementation-plan-320-phases.md` lines 44–45 ("Retire stale Floot-specific analytics assumptions… do not permanently export revocable phone numbers, suspended profiles, or private fields into static pages.") and plan.md line 25 ("website analytics is Floot's built-in, storage-free mode").
- Stale export: `tool/export_floot_data.py` is written and functional but has no Floot project to upload to (plan.md founder decision to replace Floot with in-repo Astro).
- Data mirror: ~~`tool/export_web_data.py` → `showcase/data.js`~~ deleted 2026-10-07 with the showcase; the Astro site (141–160) needs a fresh exporter reading `lib/data/seed/`.
- Legal sync: `lib/features/legal/legal_documents.dart` + `tool/export_floot_data.py` lines 181–219 show pattern for extracting legal text with placeholders filled.

**Owner:**  
Workstream 5 (Website, top priority)

**Cost:**  
- Build base site: ~12–16 focused hours (scaffolding, page templates, data export wiring, screenshots, SEO tags, sitemap, robots).
- Deploy: Vercel or similar CI/CD ~2–4 hours (GitHub Actions, domain DNS, HSTS headers).
- Maintenance: included in Phase 016 operations.

**Reversal path:**  
If Astro becomes problematic, migrate to another SSG (Hugo, Jekyll) by re-exporting data and rewriting templates. Content (categories, providers, legal) is in Postgres and seed files; no data lock-in to Astro.

**Reconsider when:**  
- Website p95 LCP > 2.5s or INP > 200ms on a documented mobile test profile (Phase 281 deployment gate) — optimize image serving, lazy-load, or consider incremental static regeneration (ISR) + a lightweight API.
- Listings need real-time updates (e.g., provider pauses a listing, site should reflect in < 1 minute) — enable on-demand revalidation via Supabase webhook triggering a rebuild, or introduce a lightweight BFF (Backend for Frontend) server.
- Multiple cities launched and directory becomes too large for static export — implement dynamic city-selection backend without exporting full provider list to HTML.

---

### ADR-004: Server-Side AI Gateway with Existing Model

**Context:**  
Owner has selected "a branded assistant using private app data and an existing AI model" (implementation-plan lines 12–13). Saathi AI is a product feature, not a fine-tuning or self-hosted-model project. Permission-scoped tools and authorized retrieval are required; initial AI is read-only (drafts/explains; UI confirmation controls publication and contact).

**Decision:**  
Implement an Edge Function (Phase 161–180) that acts as an AI gateway:
1. Receives a request with user role (guest, provider, admin) and context (saved providers, current profile data, search history).
2. Calls an existing LLM API (OpenAI, Anthropic, or similar, to be selected at Phase 161) with a curated system prompt.
3. Enforces authorization: guest sees only public eligible data; provider sees only own data; admin sees moderation-scoped data.
4. Returns streamed or completed response directly to client.
5. Logs requests/responses for quality review and cost tracking; no retention of user PII beyond the immediate request.

No fine-tuning, no vector database (initially), no knowledge-base indexing system at launch. Retrieval is deterministic Postgres search + authorized field filtering.

**Alternatives considered:**
- Self-hosted model (Llama, Mistral): introduces DevOps, GPU cost, and quality unpredictability. Reasonable if edge function cost exceeds $X/month per Phase 016 projections; decision gate at Phase 201.
- Vector retrieval + RAG: adds Pinecone/Weaviate cost, latency, and dependency. Measure keyword search p95 latency first (Phase 101–120); use vectors only if deterministic search fails.
- Fine-tuned model: requires substantial labeled data (provider knowledge, correction examples) and ongoing retraining. Hypothesis: existing model + prompt engineering is sufficient for launch; measure BLEU/factuality on Phase 201 evaluation set before committing to fine-tuning.

**Evidence:**  
- Owner vision: implementation-plan lines 12–13, 46–48 (permission-scoped tools, read-only initial state, human-reviewed languages, incident controls).
- Threat model: Phase 012 (prompt injection, excessive agency, data disclosure, retrieval poisoning, resource consumption).
- Knowledge scope: Phase 181–200 (grounded retrieval, authorized knowledge lifecycle).

**Owner:**  
Workstream AI (Phases 161–200)

**Cost:**  
- OpenAI or Anthropic API: TO QUOTE at execution. Assume $0.01–0.05 per request (Claude 3 Haiku, 1K context in/out); scale from 10–500 AI requests/day per Phase 016 scenarios.
- Supabase Edge Function compute (same platform as ADR-002): included in the plan's invocation quota at pilot volume; negligible.
- Rate-limiting, cost caps, human-review queue: ~4–6 focused hours (Phase 201).

**Reversal path:**  
If edge function cost exceeds budget, switch to a self-hosted model on a container runner (Cloud Run, EC2) with per-user quota. Code change: replace edge-function call URL + adjust per-request cost model. Data (requests/responses for review) is in Postgres; no AI vendor lock-in.

**Reconsider when:**  
- AI-specific operational cost exceeds 20% of total monthly backend spend (Phase 016 thresholds) — evaluate self-hosting or quota reduction.
- Hallucination rate on factuality evaluation (Phase 201) exceeds 5% — trigger fine-tuning or prompt-engineering iteration.
- User reports of prompt-injection or excessive agency (Phases 012, 201) — implement mitigation (input filtering, tool restrictions, human review queue) before expansion.
- LLM provider API becomes unavailable — fall back to deterministic search only; AI feature off until restored.

---

### ADR-005: Deterministic Postgres Search First, No Vector DB Until Measured

**Context:**  
Provider search is currently implemented as in-memory token matching over seed data (`lib/domain/repositories/provider_repository.dart`, `lib/data/repositories/mock_provider_repository.dart`). The backend has no `search_vector`/`tsvector` column: search uses `pg_trgm` trigram GIN indexes (`gin_trgm_ops` on `display_name`, `description`, locality names; `20260101000010_indexes.sql:13-27`) inside the `search_providers` RPC, executed in PGlite (phases 034, 038); the Flutter client does not call it yet (Phases 061–080). Vector retrieval (pgvector) is not implemented.

**Decision:**  
Prioritize deterministic Postgres search (today `pg_trgm` similarity; add FTS only if trigram matching measures short) with multi-token matching on provider names, trade names, keywords, and localities. Target p95 latency under 800ms at documented test load (estimated 1000 concurrent users, each issuing 5 search queries during a 15-minute session). Measure actual latency in Phase 101–120 search evaluation. Do not add pgvector or an external vector database unless:
1. Deterministic search p95 latency consistently exceeds 800ms under load, AND
2. Semantic relevance (not just latency) is measured as the limiting factor via user feedback or evaluation metrics.

Queues, caching, and other infrastructure come only when measured needs justify them.

**Alternatives considered:**
- Elasticsearch: standalone service, operational overhead, cost scaling. Defer until Postgres (trigram) search is proven insufficient.
- pgvector in Postgres: fair, but requires trigger-based indexing on every profile edit (cost, staleness). First measure trigram search performance.
- Redis cache on search queries: reasonable after a measured search baseline; add only if hit rate is predictable.

**Evidence:**  
- Current: `backend/supabase/migrations/20260101000010_indexes.sql` (`pg_trgm` GIN indexes), `search_providers` RPC (latest in `20261006000016_public_projection.sql`); no `tsvector` column, no pgvector extension
- Target: implementation-plan line 369 ("deterministic search surviving model outages")
- Measurement plan: Phase 010 (metrics definition), Phase 101–120 (search evaluation with test load)
- Thresholds: "p95 search > 800ms at documented load" is the explicit reconsider trigger (implementation-plan ADR guidance)

**Owner:**  
Workstream 3 (Search) + Workstream AI (fallback if semantic relevance becomes a factor)

**Cost:**  
- Postgres (trigram) search: included in Supabase compute (Phase 016).
- pgvector or Elasticsearch: deferred; estimate $500–2000/month if added (Phase 016 cost model, conditional line).
- Caching layer (Redis): $50–500/month depending on dataset size; add only if the search hit ratio is low and not fixable via index tuning.

**Reversal path:**  
If trigram search proves insufficient (p95 > 800ms), add pgvector to the same Postgres instance (no external service, immediate reversal). If vector search alone doesn't solve latency, introduce read replicas or a cache layer (Redis), then re-measure. Data in Postgres is not vendor-locked; search strategy is isolated to backend queries.

**Reconsider when:**  
- Measured p95 search latency > 800ms at documented load (Phase 101–120 evaluation).
- Vector-search relevance significantly outperforms deterministic search on a small labeled evaluation set (Phase 201 AI evaluation).
- Operational cost of deterministic search exceeds vector-search cost by > 30% (Phase 016 monthly billing audit).

---

## Floot References: Disposition

All Floot references have been located and are actionable:

| File | Line(s) | Reference | Disposition | Next Action |
|---|---|---|---|---|
| `tool/export_floot_data.py` | 1–225 | Script exports directory data to Floot project format (`build/floot/directoryData.tsx`, etc.) | **Retire** — Floot platform abandoned per owner decision (2026-10-04); no active project to upload to | Delete file after confirming Astro website exports the same data (Phases 141–160). Archive in separate commit with message "Retire Floot export tool; Astro website replaces it." |
| `tasks/plan.md` | 24 | Analytics: "website analytics is Floot's built-in, storage-free mode" | **Replace** — Floot platform unavailable; Astro website will use Vercel Analytics (free tier) or Plausible | Update plan.md line 24 to read: "No new tracking SDKs. Crashes and ANRs come from Play Console Android vitals; website analytics is [chosen analytics provider, e.g. Vercel built-in]." |
| `tasks/plan.md` | 25 | Website scope: "No invented facts… no team names, addresses" | **Keep** — applies to both Floot and Astro; reflects integrity principle | No change required. |
| `tasks/implementation-plan-320-phases.md` | 44 | "Retire stale Floot-specific analytics assumptions" | **Action taken via this ADR** — Floot references catalogued, Astro path confirmed | Mark Phases 141–160 acceptance with evidence: Floot references resolved, Astro website asset export matches `tool/export_floot_data.py` capability. |

**Summary:** Floot export tool is dead code; website analytics placeholder must be filled with a real provider. Both are low-complexity cleanup actions that do not block core launch.

---

## Residual Uncertainty & Owner Decisions Needed

1. **AI Model Selection (Phase 161):** OpenAI vs. Anthropic vs. other? Cost and latency estimates depend on this. Placeholder in Phase 016 cost model pending decision.
2. **SMS Provider (Phase 041):** Firebase Phone Auth vs. MSG91 vs. Gupshup vs. other? DLT registration in India required. Cost varies widely.
3. **Website Hosting & Analytics (Phases 141–160):** Vercel (free tier or Pro) vs. Netlify vs. other? Vercel assumed for deployment cost model in Phase 016.
4. **Real-time vs. Static Listings (Phases 141–160):** Website stays fully static (rebuilt 1x/day or on-demand) or introduces a lightweight BFF for real-time provider availability? Affects architecture and cost.

---

## Next Integration Action

1. **Phase 001–014:** Verify all baseline evidence before Phase 015 gate. No new ADRs until this phase is reviewed and signed off.
2. **Phase 016:** Finalize cost worksheet with unit prices (SMS provider API, AI model pricing, Supabase project SKU).
3. **Phase 021–040 (Database), 041–060 (Identity), 061–080 (Live Repositories), 141 (Website):** Each workstream implements per the ADR contracts. If a workstream needs to deviate (e.g., deterministic search is chosen to stay in-app for a feature), update the relevant ADR's "Reversal path" and log the decision in that phase's evidence.
4. **Phase 101–120 (Search), Phase 201 (AI Evaluation):** Measure against reconsider thresholds; produce Phase 016 cost model reconciliation.


## Chief-engineer review (2026-10-06)

- Replaced the proposed 24-hour provider-card cache: it would keep suspended/withdrawn phone numbers public for up to a day, contradicting the plan's architecture section (short, revocable caching only).
- `tool/export_floot_data.py`: **deleted 2026-10-07 with the owner's go-ahead** (Floot abandoned; it only read the deleted showcase data).
- Status: accepted for phase 020.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| export_floot_data.py exists | Confirmed | `ls tool/export_floot_data.py` = exists |
| export_website_data.py exists | Wrong name (reviewer) | real file is `tool/export_web_data.py`; `ls tool/export_website_data.py` = ENOENT |
| Astro website is currently in website/ | Confirmed | No website/ directory found (correctly noted as missing) |
| legal_documents.dart exists | Confirmed | `ls lib/features/legal/legal_documents.dart` = exists |
| Chief-engineer review documented | Confirmed | Three corrections documented with rationale |

**[reviewer] Correct name is `tool/export_web_data.py` (exists); the auditor's "only export_floot_data.py exists" was also wrong. Memory note naming `export_website_data.py` is stale.**
