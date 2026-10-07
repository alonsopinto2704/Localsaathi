# LocalSaathi — production, security, and Saathi AI implementation roadmap

**320 detailed coding-agent phases · Separate expansion plan · 6 October 2026**

This is a new, standalone implementation plan. It preserves every existing improvement document and the earlier [launch plan](plan.md); it does not replace or delete them. The current request authorizes planning and review. None of the proposed implementation, account provisioning, deployment, spending, or external communication is claimed as completed.

**Plan status:** Complete: 320 numbered phase prompts across 16 workstreams. Every implementation phase starts as **Not started**, including phases that verify or reuse existing code. Completing this roadmap does not mean its implementation has been completed.

## Product direction

LocalSaathi should become a dependable Mumbai-first directory for local services, with Flutter Android, a public website, real Supabase services, guest browsing, and English/Hindi/Marathi support. Preserve the useful existing architecture. Provider identity remains one verified phone identity with one owned profile; phone verification must never imply professional qualification or guaranteed safety.

The owner selected **a branded assistant using private app data and an existing AI model**. Saathi AI therefore owns its product experience, prompt configuration, authorized retrieval, local service knowledge, evaluations, and operational controls. It does not claim to own a newly trained foundation model. Start with an existing model through a server gateway. Fine-tuning or self-hosting needs later measured justification and is not required for launch.

A distinctive launch combines practical discovery with transparent evidence: explain why a provider fits, distinguish checked credentials from provider claims, show when availability was last confirmed, help users prepare a multilingual service brief, and keep direct contact under the user's control. Experimental features must prove value before becoming permanent.

## What the current app actually contains

The review inspected the source, the existing implementation plan and backend contract, Android build settings, database policies and functions, storage rules, account deletion code, and an existing home-screen screenshot. This was not a complete live UI walkthrough or a penetration test.

| Area | Evidence and current state | Consequence |
|---|---|---|
| Flutter product | Screens for discovery, local bookmarks, onboarding, profile editing, maps/photos, reporting, monetization information, legal drafts, and three languages exist. | Extend the product; do not start a rewrite. |
| Data selection | `lib/main.dart` always calls `AppDependencies.mock`; `lib/app/app_dependencies.dart` wires mock repositories. | Real repository adapters and explicit environment selection are launch blockers. |
| Supabase dependency | `supabase_flutter` is in `pubspec.yaml`; `lib/data/supabase/` was absent. | An installed package is not a completed integration. |
| Contact actions | `lib/core/widgets/provider_contact.dart` still displays not-wired messages for live calls/WhatsApp. | The central customer action must be implemented and verified. |
| Database | Twelve migrations, seed data, SQL tests, and a PGlite runner exist. | There is useful backend work to preserve and harden. |
| Executed DB check | `node backend/scripts/verify-db.mjs`: 12/12 migrations applied, seed applied, 2/6 SQL files passed. | Overall database verification failed. |
| Failure detail | Helpers were treated as TAP tests; moderation fixtures, temporary-table privileges under switched roles, and publication consent caused failures. Only seven assertions completed, all seven passing. | Repair the harness and fixtures without weakening production rules, then run full Supabase checks. |
| Flutter test attempt | Explicit SDK-path invocation of `flutter test --no-pub` produced no output and was interrupted. | Tests, analysis, release builds, and real-device health remain unverified here. |
| Public DB boundary | Migration 0009 grants broad function execution and public SELECT on eligible raw provider rows. | Audit callable helpers and field disclosure. RLS selects rows; it does not hide columns inside allowed rows. |
| Media | Public portfolio bucket and private credential bucket are defined. Client metadata stripping exists. | Add server validation, processing, lifecycle cleanup, and realistic takedown behavior. |
| Android | Current files target API 36 and reference Gradle 9.3.1. Release signing can fall back to debug. | Retest historical build issues; enforce correct production signing. |
| Website and operations | `website/`, deployment runbooks, and CI workflow were absent. Some store graphics/screenshots exist; several screenshot filenames indicate failures. | Build and verify the actual website and launch artifacts. |
| Visual baseline | Existing home screenshot shows category names wrapping or clipping awkwardly. | Include small-screen, large-text, and multilingual layout fixes. |
| Legal configuration | Placeholder business/contact fields and draft legal flags remain. | Use real operator details and qualified review before launch. |
| Repository history | `git status` reported no Git repository in this checkout. | Establish versioned recovery before production implementation. |

No production account, domain, SMS delivery setup, model credential, hosted deployment, or store approval was verified. Current source is stronger evidence than older prose, and executed integration evidence is stronger than source comments.

## Architecture and ownership

Keep Flutter controllers and repository interfaces where they work. Supabase Auth owns phone verification; Postgres constraints, grants, RLS, and carefully scoped RPCs enforce authorization. Edge Functions handle privileged lifecycle work, protected guest writes, and the AI gateway. Service-role and model credentials stay server-side.

The earlier plan calls for an Astro website, and this roadmap preserves that direction. Use static rendering for stable public content and live rendering or explicitly short, revocable caching for provider pages. Do not permanently export revocable phone numbers, suspended profiles, or private fields into static pages. Flutter web remains useful for reference and testing. Retire stale Floot-specific analytics assumptions when implementing the website.

Saathi AI uses permission-scoped tools and approved knowledge. Guest AI gets public eligible data; owner AI gets only the current owner's authorized information. Credential scans, moderation reports, OTPs, tokens, and other providers' private data are outside ordinary model context. Initial AI is read-only: it drafts and explains, while ordinary UI confirmation controls publication, contact, and deletion.

A planned admin surface must enforce separate support, moderation, credential-review, and infrastructure privileges. Do not duplicate business authorization in an unprotected admin frontend. Introduce queues, vector retrieval, and additional infrastructure only when a measured task needs them.

## Time and staffing: a realistic 2–3 month program

A phase is a bounded engineering assignment, not an entire sprint or a promise of one day's work. Most phases require 2–7 focused hours plus review; difficult integrations may grow after discovery. The full 320-phase program is deliberately substantial and can take far longer than three months for one person.

Use a **12-week planning horizon** for a staffed delivery team, with 4–6 engineers covering mobile, backend/security, web, AI, and integration, plus part-time QA, native-language review, legal advice, and trust operations. Agents accelerate work but do not remove human review, provider-account setup, user research, or store waiting periods. Budget another 25% for integration and uncertainty; recalculate capacity from the per-phase estimates before committing dates.

A solo developer at approximately 30 focused hours a week should expect many months for the entire roadmap. For a solo 2–3 month launch, select a smaller reviewed release slice after phase 019; do not pretend all 320 substantial assignments fit or omit required security controls to meet a date.

The completed phase estimates sum to **940–1,880 focused engineering hours**, or **1,175–2,350 hours with 25% integration/uncertainty allowance**. These are planning ranges, not measured completion times. Reusing verified existing work can reduce them; defects, integration, account setup, and legal/store review can increase calendar time.

| Staffing assumption | Arithmetic capacity estimate for the entire program | Practical interpretation |
|---|---|---|
| One engineer, 30 focused hours/week | Approximately 40–79 weeks | Roughly 9–18 months for the full roadmap; agent assistance does not guarantee a particular acceleration. |
| Four engineers, 30 focused hours/person/week | Approximately 10–20 weeks | Twelve weeks can cover a lower-effort outcome or a deliberately selected release slice; dependencies still matter. |
| Six engineers, 30 focused hours/person/week | Approximately 7–14 weeks | A twelve-week target is plausible for much of the range, with external waits and review capacity still capable of extending it. |

These divisions are capacity checks, not a claim that every phase parallelizes. Reserve named security and integration reviewers and do not count one person's time in multiple roles simultaneously. The plan is substantial enough for the requested 2–3 months and beyond; it is not padded with requirements to train a foundation model or rewrite the existing application.

| Window | Primary outcome | Work that can run alongside it |
|---|---|---|
| Weeks 1–2 | Reproducible baseline, scope, contracts, threat model, account prerequisites | Legal fact gathering, design-state audit, CI skeleton |
| Weeks 2–4 | Trusted schema, real identity, bounded public endpoints | Website shell, UI corrections, operations workflows |
| Weeks 3–5 | Live Flutter repositories and contact journey | Search evaluation, media lifecycle, staging infrastructure |
| Weeks 4–7 | Safe media, usable discovery, complete website, privacy operations | AI gateway and reviewed knowledge pipeline |
| Weeks 6–9 | Grounded text assistant and end-to-end staging acceptance | Performance, accessibility, security remediation, selected experiments |
| Weeks 8–10 | Signed Android candidate and eligible closed testing | Store content, restores, incident drills, small provider pilot |
| Weeks 10–11 | Release-candidate evidence and go/no-go review | Controlled AI cohort, support rehearsal, experiment decisions |
| Week 12 | Staged public rollout if gates pass, stabilization and ownership handover | Otherwise extend the schedule with explicit blockers; never declare an unready release complete |

These windows overlap and are capacity targets, not a dependency-free calendar. Numbers organize the roadmap; actual prerequisites and file ownership control execution. Start account-dependent preparation early. For applicable newly created personal Google Play developer accounts, closed testing currently requires at least 12 continuously opted-in testers for 14 days; verify the actual account category and current policy before scheduling. [Google Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).

## Release cut lines and non-negotiable gates

- **Core directory release:** real identity, eligible public data, functional contact, safe uploads if enabled, reporting/support, deletion, truthful legal/store disclosures, operational recovery, tested Android and website artifacts. AI and experimental features can remain off.
- **AI text pilot:** all core data boundaries plus evaluated gateway, authorized retrieval, revocation, budget limits, human-reviewed languages, incident controls, and safe fallback.
- **Experimental release:** independently flagged features with a hypothesis, privacy review, metric, cohort, and stop rule. Voice/photo AI and phases 221–240 are not automatic launch requirements.
- **Commercial release:** paid placement or subscriptions remain disabled until the applicable platform/payment policies, billing lifecycle, refunds, and disclosures are verified.
- **Expansion:** a second city is a separately gated data-and-operations rollout, not a reason to delay a safe Mumbai launch.

Proposed initial engineering targets, to be confirmed after baseline measurement: no unresolved critical/high exploitable authorization defects; zero forbidden-field or cross-account exposures in the security regression pack; database search p95 under 800 ms at the documented test load; gateway-only ordinary API error rate under 1% during the launch rehearsal; Android crash-free sessions at least 99.5% in a sufficiently sized pilot; website LCP at most 2.5 s, INP at most 200 ms, and CLS at most 0.1 on a documented mobile test profile; text-AI completed-response p95 under 10 seconds, at least 95% supported factual claims on the reviewed evaluation set, and zero critical privacy/action violations. These are project targets, not certifications or guarantees.

Proposed recovery targets: core database RPO no worse than 24 hours and RTO no worse than 4 hours for an early pilot, improving if account capabilities and business impact justify it. A restore drill must prove the chosen numbers. Authorization checks should exclude revoked data immediately on fresh requests; asynchronous index/object deletion needs its own measured SLA. Public copies already downloaded cannot be recalled.

## Master coding-agent prompt

> Implement only the assigned LocalSaathi phase and its explicitly agreed integration work. Read this plan, applicable repository guidance, dependency evidence, and current code first. Preserve completed improvements and unrelated local changes. If code already satisfies an assignment, demonstrate verified reuse instead of rewriting it.
>
> Trace the real data flow and authorization boundary. Keep Flutter, the existing repository contracts where sound, Supabase, guest browsing, Mumbai-first data-driven activation, local bookmarks, and English/Hindi/Marathi support. Build the planned website without creating a competing backend. Saathi AI is a branded model-backed assistant, not a foundation-model training project.
>
> Deliver the smallest complete change for the phase, including meaningful loading/error/empty/offline behavior where relevant. Protect data server-side; hidden buttons and model instructions are not authorization. Never silently use demo data after a live-service failure. Keep production secrets and development OTP bypasses out of client artifacts.
>
> Run tests that verify realistic failure modes and the phase's acceptance conditions. Use synthetic fixtures and redact secrets and personal information. For research or documentation phases, validate evidence, links, and decisions instead of inventing meaningless code tests. Mark unexecuted checks honestly.
>
> Prepare a reviewable artifact before requesting any missing account or product decision. Do not send messages, incur costs, provision paid resources, publish releases, or delete production data without applicable authorization. Existing authorization remains valid; do not repeatedly ask for routine reversible work.
>
> Record changed paths, prerequisite evidence, exact commands/results, screenshots where relevant, residual risks, migrations, rollout flags, and rollback steps in tasks/evidence/phase-NNN.md. Update status only after review. If blocked, record the exact missing dependency, owner, and next action, then continue independent authorized work.

## Working rules, evidence, and dependency conventions

Each phase has a suggested specialist, effort range, starting paths, detailed prompt, acceptance checks, deliverables, and safe-stop behavior. A path marked new is a proposal. The assigned engineer may discover a better narrow location, but must document contract or ownership changes.

Status progression: Not started → Ready → In progress → In review → Done. Use Blocked with an owner and next action; experiments may become Deferred or Cancelled with evidence. Do not create hundreds of empty evidence files. When implementing, record objective, prerequisites, changed files, commands/results, security/privacy effects, release decision, rollback, reviewer, and follow-up issues.

Dependencies listed for a workstream are **entry dependencies**; additional phase dependencies must be honored. Within a stream, its foundation assignment precedes dependent implementations, and its final gate consumes evidence from all enabled phases. Independent tasks can run in parallel after contracts are agreed; they must not edit the same migration, composition root, shared model, or localization file concurrently. The integration owner assigns files and serializes shared changes. Listed dependencies are a minimum: inspect actual interfaces and add newly discovered prerequisites to the phase evidence before implementation.

For optional capabilities, a gate dependency can be satisfied by an explicit reviewed **Deferred / feature disabled** disposition rather than by implementing the feature. The disposition must name disabled UI, endpoints, jobs, and flags and prove that core behavior does not depend on them. Never use this exception for required authorization, deletion, legal disclosure, release signing, or recovery controls. Thus an AI-off directory launch does not require phase 298 to enable AI, and a no-payments launch does not require phases 257–259 to process purchases.

The schedule is intentionally a dependency graph rather than 320 sequential sprints. Research, legal preparation, infrastructure design, and UI audits may begin before the associated implementation is enabled. A gate cannot be passed on preparation alone. Conditional features may be deferred only if their UI, endpoints, and rollout flags remain disabled and the release owner records the exclusion.

## Official references and freshness rules

These links informed the architecture and release checks; phase details are LocalSaathi-specific engineering proposals. Recheck vendor behavior and legal applicability at implementation/release time.

- Supabase recommends reviewing production security and operating responsibilities, including RLS and project access. Use this alongside actual HTTP tests, not as a certification. [Supabase production checklist](https://supabase.com/docs/guides/deployment/going-into-prod).
- Use selected applicable ASVS requirements for web/backend evidence and an explicit applicability matrix. [OWASP ASVS](https://owasp.org/projects/asvs).
- Include prompt injection, excessive agency, data disclosure, retrieval poisoning, and resource consumption in AI threat analysis. [OWASP LLM risks](https://genai.owasp.org/llm-top-10/).
- If OpenAI is selected, use currently supported server-side APIs and validated function-call schemas; application authorization remains necessary. [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling).
- Evaluate retention and data controls by endpoint and account capability; do not assume store=false or an account setting means no provider-side retention. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).
- Google Play currently lists API 36 for ordinary new apps/updates from 31 August 2026; recheck the exact app category and submission date. [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878).
- Legal phases must check current DPDP rules, commencement dates, operator role, and other applicable Indian obligations with qualified counsel. This roadmap does not certify compliance or treat every provision as already applicable. [MeitY DPDP rules](https://www.meity.gov.in/content/digital-personal-data-protection-rules-2025).

## Workstream index

| Phases | Workstream |
|---|---|
| [001–020](#phase-001) | Baseline, scope, architecture, and delivery contracts |
| [021–040](#phase-021) | Database authorization and domain invariants |
| [041–060](#phase-041) | Identity, OTP, sessions, and recovery |
| [061–080](#phase-061) | Live Flutter repositories and contact |
| [081–100](#phase-081) | Media, evidence, and trustworthy listings |
| [101–120](#phase-101) | Local search, geography, and freshness |
| [121–140](#phase-121) | Accessible multilingual product experience |
| [141–160](#phase-141) | Production public website |
| [161–180](#phase-161) | Saathi AI platform and security |
| [181–200](#phase-181) | Grounded retrieval and knowledge lifecycle |
| [201–220](#phase-201) | AI experience and evaluation |
| [221–240](#phase-221) | Distinctive product experiments |
| [241–260](#phase-241) | Administration, privacy, moderation, and commercial readiness |
| [261–280](#phase-261) | DevSecOps, reliability, and recovery |
| [281–300](#phase-281) | Android/store/website deployment and controlled launch |
| [301–320](#phase-301) | Post-launch validation, growth, and sustainable ownership |

## Workstream 1 — Baseline, scope, architecture, and delivery contracts

**Phases:** 1–20. **Lead:** Product lead and integration engineer. **Entry dependencies:** Current repository baseline. **Release class:** Core launch.

<a id="phase-001"></a>

### Phase 001 — Repository and artifact inventory

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** No earlier phase required. Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Inventory screens, controllers, repositories, migrations, Edge Functions, assets, and missing deployment directories. Classify each as implemented, partial, missing, or unverified. Record the absent Git history and a recovery approach before implementation. Identify any ongoing edits without treating old completion claims as evidence.

**Acceptance and verification:** A path-linked inventory lets another engineer reproduce each status and names the owner of unresolved assumptions. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-001.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep original files intact and record corrections as a new baseline. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-002"></a>

### Phase 002 — Customer journey baseline

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Trace locality selection, search, comparison, saving, reporting, and contact from screen to repository. Capture demo/live boundaries and where actions stop at snackbars. Review English, Hindi, and Marathi, a narrow viewport, and a returning guest session. Record expected behavior separately from what the current code does.

**Acceptance and verification:** A journey matrix identifies each broken or mocked action, responsible interface, and required production result. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-002.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain baseline captures and fictional fixtures. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-003"></a>

### Phase 003 — Provider journey baseline

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Exercise ten-step onboarding, interrupted drafts, existing numbers, profile edits, pause/resume, hours, and deletion. Inventory personal data persisted on-device and potential account-switch leakage. Distinguish phone control from professional verification. Record failures without rewriting the workflow before its rules are understood.

**Acceptance and verification:** Fresh, returning, interrupted, and switched-account scenarios each have reproducible expected outcomes. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-003.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Preserve original drafts and avoid migrating demo identities into production. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-004"></a>

### Phase 004 — Database test runner repair

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Inspect verify-db.mjs and helper SQL. Load helper files as setup rather than TAP suites, correct role-switched fixture access, and construct published fixtures through valid consent/category/service-area rules. Investigate moderation setup failures without disabling real triggers. Make missing plans and failed assertions fail the command.

**Acceptance and verification:** Every intended SQL suite executes its full plan; intentional failures return a nonzero exit status. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-004.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain the previous runner and explain every fixture change. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-005"></a>

### Phase 005 — Flutter baseline execution

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Resolve the installed SDK from local configuration and record Flutter/Dart/toolchain versions. Run analysis and tests using locked dependencies, investigate silent startup separately, and group failures by environment, fixture, and product defect. Do not upgrade dependencies merely to conceal the current baseline.

**Acceptance and verification:** Save full results and exact failing test names; unavailable checks remain explicitly unverified. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-005.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the known local demo route usable. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-006"></a>

### Phase 006 — Full Supabase parity check

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001), [004](#phase-004) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Run a disposable complete Supabase stack alongside PGlite. Compare Auth claims, storage, PostgREST grants, extensions, timezone, and service-role behavior. Exercise requests through actual HTTP services with real role tokens; lightweight SQL success does not prove full platform authorization.

**Acceptance and verification:** Demonstrate anonymous read, owner write, cross-owner denial, and private-object denial through the full stack. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-006.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Clean only clearly identified disposable fixtures after recording evidence. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-007"></a>

### Phase 007 — Release configuration baseline

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Inspect current Gradle, Kotlin, manifests, signing choices, permissions, SDK targets, and build defines. Recheck historical build failures against current files, which already specify API 36 and newer Gradle. Identify release paths that permit debug signing or mock dependencies.

**Acceptance and verification:** A debug/staging/production matrix defines concrete fail-closed requirements and unresolved build checks. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-007.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Preserve local development configuration while tightening production later. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-008"></a>

### Phase 008 — User research brief

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Prepare interviews for customers, independent providers, older users, people arranging home visits, and clinics. Investigate language, trust interpretation, contact friction, and willingness to refresh availability. Define consent, note retention, participant diversity, and research questions. Prepare outreach only; do not send it automatically.

**Acceptance and verification:** Each interview question maps to a product decision and notes exclude unnecessary identifiers. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-008.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Delete identifiable research notes under the agreed retention policy. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-009"></a>

### Phase 009 — Launch category and locality boundaries

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Choose a small first operational slice of Mumbai while leaving the catalog data-driven. Classify healthcare as directory-only and define credential requirements per enabled category. Explicitly exclude unsupported emergency dispatch, booking guarantees, escrow, and outcome claims. Record why each launch category can be supported.

**Acceptance and verification:** A launch matrix defines visibility, verification, and support ownership for every enabled category. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-009.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable categories through configuration without deleting listings. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-010"></a>

### Phase 010 — Outcome metrics and counter-metrics

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Define qualified discovery, intentional contact taps, provider activation, freshness coverage, and support workload with formulas and denominators. Never call taps completed jobs. Add safety and quality counter-metrics, sample-size requirements, and measurement windows. Avoid collecting raw personal messages to compute ordinary product metrics.

**Acceptance and verification:** Every metric has an observable event source, limitations, owner, and decision threshold. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-010.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable optional measurement independently of core discovery. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-011"></a>

### Phase 011 — Architecture and data-flow diagram

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Map Flutter, planned Astro website, Supabase Auth/Postgres/Storage, SMS, admin tools, and AI gateway. Label trust boundaries, credentials, public/private fields, and external processors. Follow both a request and a deletion through every store; show deterministic search surviving model outages.

**Acceptance and verification:** The diagram identifies each authority boundary and each retained copy of user information. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-011.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Update the diagram whenever a new data path is introduced. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-012"></a>

### Phase 012 — Threat model and abuse stories

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Model account takeover, OTP pumping, impersonation, scraping, malicious uploads, insider misuse, and prompt injection. Include unwanted contact and residential-location disclosure as realistic product threats. Prioritize by impact and exposure rather than adding unrelated security products. Map launch-critical threats to tests and response owners.

**Acceptance and verification:** Each significant abuse story has a prevention/detection control, negative test, and residual-risk decision. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-012.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reopen the threat model when new endpoints or processors appear. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-013"></a>

### Phase 013 — Field-level data classification

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Classify every profile, credential, consent, report, location, and engagement field. Define public, owner, moderator, admin, and AI access explicitly. Separate consented business contact information from private identity data. Use an allowlist for public projection rather than subtracting known forbidden fields from owner objects.

**Acceptance and verification:** A complete access matrix covers new fields by default-deny and distinguishes exact from approximate locations. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-013.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep unclassified fields out of all public responses. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-014"></a>

### Phase 014 — API contract reconciliation

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Compare Dart repository signatures with SQL response shapes, enums, timestamp handling, hours sentinels, pagination, and deletion semantics. Create realistic request/response fixtures and stable error codes. Preserve working contracts and identify precise mismatches instead of requesting an architecture rewrite.

**Acceptance and verification:** Search, profile, registration, edit, report, and deletion fixtures can drive both clients and backend tests. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-014.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use additive compatibility until older clients can be retired. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-015"></a>

### Phase 015 — Architecture decision records

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Record why Flutter, Supabase, the planned Astro website, and a server-side AI gateway fit the current product. Resolve stale Floot analytics assumptions. Define measurable triggers for adding semantic search, queues, or another service, and document costs and reversal paths.

**Acceptance and verification:** Each decision includes alternatives, evidence, ownership, and the condition for reconsideration. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-015.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reopen only the decision affected by new evidence. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-016"></a>

### Phase 016 — Environment and cost worksheet

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

List development, staging, and production resources, regions, access owners, retention, and backups. Model SMS, AI, storage, egress, domain, monitoring, and store costs using current quotes during execution. Set spending ceilings and alert ownership. Keep account creation separate from local preparation.

**Acceptance and verification:** A worksheet computes low/expected/stress costs without relying on stale free-tier claims. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-016.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep expensive services disabled until their resource and budget decisions are approved. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-017"></a>

### Phase 017 — Release scope and feature flags

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Classify core launch, AI pilot, and optional experiments. Define server-controlled switches for AI, media intake, healthcare, promotions, and cities. Specify default-off behavior and what remains usable when each feature is disabled. Avoid flags that merely hide an otherwise unprotected endpoint.

**Acceptance and verification:** A flag matrix names audience, dependency, disable behavior, and evidence required to enable it. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-017.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable one capability without rolling back the entire app. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-018"></a>

### Phase 018 — Coding-agent execution protocol

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Define bounded assignments, file ownership, integration responsibility, evidence notes, and review requirements. Include honest reporting of unrun checks and preservation of unrelated improvements. Trial a handoff between engineers using one small phase. Avoid parallel edits to the same migrations, models, or composition root.

**Acceptance and verification:** Another agent can resume from the phase evidence and current files without conversational history. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-018.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reassign incomplete work while preserving reviewable changes. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-019"></a>

### Phase 019 — Capacity and risk schedule

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Estimate human engineering hours, reviewer capacity, external waits, and integration overhead. Schedule SMS registration, legal input, model accounts, and store testing early. Publish a staffed twelve-week option and a longer solo projection. Identify the smallest safe release slice without pretending all phases fit one person's three months.

**Acceptance and verification:** The schedule reconciles people and hours and includes contingency, owners, and explicit cut lines. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-019.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Rebaseline dates whenever real estimates or dependencies change. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-020"></a>

### Phase 020 — Foundation gate and scope freeze

**Status:** Not started. **Suggested owner:** Product lead and integration engineer. **Effort:** 2–4 focused hours. **Release class:** Core launch.

**Prerequisites:** [001](#phase-001), [002](#phase-002), [003](#phase-003), [004](#phase-004), [005](#phase-005), [006](#phase-006), [007](#phase-007), [008](#phase-008), [009](#phase-009), [010](#phase-010), [011](#phase-011), [012](#phase-012), [013](#phase-013), [014](#phase-014), [015](#phase-015), [016](#phase-016), [017](#phase-017), [018](#phase-018), [019](#phase-019) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `README.md`, `tasks/plan.md`, `docs/backend-contract.md`, `lib/`, `test/`, `backend/scripts/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Establish the truth about the existing Flutter and Supabase product before extending it. Preserve guest browsing, local bookmarks, the three languages, and Mumbai-first activation; distinguish observed implementation from proposals and unverified assumptions.

Review the actual baseline, contracts, threats, costs, and proposed differentiators. Turn uncertainty into bounded experiments and freeze core release expectations. Confirm account/legal blockers have owners and next actions. Preserve the earlier implementation plan as historical context without repeating stale claims as facts.

**Acceptance and verification:** Core scope is coherent, prerequisites are evidenced, and each unresolved decision has a concrete next step. For documentation, verify cited files and observations. For executable fixes, retain the original failing reproduction and the new command output; do not weaken a rule merely to make a fixture pass.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-020.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the latest reviewed baseline and record all later scope changes. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 2 — Database authorization and domain invariants

**Phases:** 21–40. **Lead:** Backend and security engineer. **Entry dependencies:** phase 013, phase 014, phase 020. **Release class:** Core launch.

<a id="phase-021"></a>

### Phase 021 — Database object and privilege inventory

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Enumerate tables, views, functions, triggers, exposed schemas, roles, grants, and default privileges. Mark each definer function's owner and intended callers. Trace nested calls before replacing blanket grants, including inherited PUBLIC privileges and helpers exposed through PostgREST.

**Acceptance and verification:** Every callable object has a documented purpose, caller set, and authorization boundary. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-021.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep a schema-only snapshot for comparison. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-022"></a>

### Phase 022 — Explicit public profile projection

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Create an allowlisted public response distinct from owner data. Exclude user identifiers, moderation history, private coordinates, and evidence paths. Tie contact fields to current consent and prevent future private columns from leaking through generic JSON serialization.

**Acceptance and verification:** Guest responses expose only approved keys even after a private column is added. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-022.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain the tighter projection during client rollback. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-023"></a>

### Phase 023 — Internal function isolation

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Move helpers outside exposed schemas or revoke execution from PUBLIC and client roles. Replace blanket default grants with an explicit callable allowlist. Preserve nested function execution through appropriate ownership rather than restoring broad public grants when tests fail.

**Acceptance and verification:** Anonymous helper calls fail while approved search and registration remain functional. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-023.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore only a specifically justified permission. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-024"></a>

### Phase 024 — Definer-function hardening

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Audit caller validation, ownership, qualified references, safe search_path, and parameter limits for every SECURITY DEFINER routine. Exclude untrusted writable schemas. Ensure administrator checks use trustworthy server-controlled facts rather than mutable client metadata.

**Acceptance and verification:** Forged identities and object-shadowing attempts cannot change authorization or returned data. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-024.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the affected RPC until verified. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-025"></a>

### Phase 025 — Provider row and column controls

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Restrict raw-table access that bypasses the approved public projection. Protect phone, ownership, moderation, and internal fields during insert and update, including direct API writes. Remember that a public SELECT row policy exposes all columns allowed by grants.

**Acceptance and verification:** Guests cannot retrieve internal columns from published rows or mutate protected data. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-025.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep approved RPC access while tightening tables. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-026"></a>

### Phase 026 — Concurrent identity uniqueness

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Verify E.164 normalization, Auth uniqueness, unique provider user_id, and phone constraints under simultaneous registrations and changes. Define stable retry/conflict behavior without revealing account existence before verification. Reject partial child creation and ownership transfer through duplicate payloads.

**Acceptance and verification:** Concurrent duplicates create exactly one owned profile with consistent children. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-026.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Roll back the failed transaction. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-027"></a>

### Phase 027 — Publication invariants

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Enforce verified identity, current consent, enabled market/category, required content, and moderation acceptance. Revalidate edits to already-published listings so removing service areas or consent cannot bypass checks that run only on initial publication.

**Acceptance and verification:** Direct writes and RPCs cannot leave an invalid listing publicly eligible. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-027.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause invalid listings pending owner correction. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-028"></a>

### Phase 028 — Market activation authorization

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Protect city and category activation with admin rights and audit reasons. Make all search, count, profile, and similar-provider routes honor deactivation. Explain the effect on ongoing owner edits and preserve drafts without claiming the market is still live.

**Acceptance and verification:** Inactive markets disappear across every fresh public discovery path. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-028.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore only the intended approved configuration. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-029"></a>

### Phase 029 — Atomic profile mutations

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Validate complete replacement payloads before changing categories, hours, prices, or photos. Keep registration and full updates transactional. Add ownership-bound idempotency where retries produce side effects; bound key retention and distinguish a repeated request from a changed payload.

**Acceptance and verification:** Injected failures preserve the prior complete profile; retries do not duplicate children. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-029.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use transaction rollback and preserve the draft. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-030"></a>

### Phase 030 — Optimistic concurrency control

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Add a revision precondition to owner and admin edits. Return a safe conflict instead of silently overwriting a newer state. Define mergeable fields and explicit review for conflicting values; protect moderation changes from stale owner forms.

**Acceptance and verification:** Two devices editing one snapshot cannot silently erase each other's committed updates. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-030.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the latest committed server revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-031"></a>

### Phase 031 — Working-hours semantics

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Unify Dart and SQL handling of unknown hours, closed days, all-day service, overnight intervals, holidays, and Asia/Kolkata time. Test early-morning spillover from the previous weekday and week boundaries instead of checking only today's row.

**Acceptance and verification:** Database filtering and profile labels agree on boundary fixtures. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-031.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable open-now filtering until consistent. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-032"></a>

### Phase 032 — Consent withdrawal propagation

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Define how revoking phone or WhatsApp consent changes publication and contact eligibility. Apply it to public RPCs, caches, future AI retrieval, and subsequent contact requests. Record versioned consent events privately and document unavoidable limits for previously downloaded public data.

**Acceptance and verification:** Fresh reads stop disclosing revoked contact details across all supported paths. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-032.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep revoked state until explicit new consent. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-033"></a>

### Phase 033 — Protected anonymous writes

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Review guest reports, city requests, and engagement submissions. Apply input bounds, deduplication, trusted quotas, and safe receipts. Revoke direct-table write paths that bypass enforcement. Treat client identifiers as untrusted signals rather than reliable identity proof.

**Acceptance and verification:** Oversized or repeated submissions cannot bypass limits using the direct API. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-033.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable guest writes while retaining discovery. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-034"></a>

### Phase 034 — Search resource bounds

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Cap text, filters, array lengths, pagination, sort options, and execution time before expensive query work. Select an index-supported pagination approach and measure realistic datasets. Avoid unlimited offsets or wildcard expansion that turns a public endpoint into a resource-exhaustion path.

**Acceptance and verification:** Adversarial inputs remain bounded and ordinary searches meet the test budget. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-034.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore a simpler bounded query. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-035"></a>

### Phase 035 — Deletion and retained records

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Map account deletion across auth, profiles, blobs, evidence, reports, consent, caches, and future AI artifacts. Separate justified limited-retention records from ordinary cascades. Define expiry and restricted access; neither SQL cascade nor account removal proves storage cleanup.

**Acceptance and verification:** Every data category has deletion, pseudonymization, retention, or processor-request behavior. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-035.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain only the minimal deletion job state. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-036"></a>

### Phase 036 — Append-only privileged audit

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Record moderation, credential, export, deletion, and configuration decisions with actor, reason, time, and correlation ID. Restrict writers and prohibit application-role edits/deletes. Redact payloads and distinguish operational logs from the application audit trail.

**Acceptance and verification:** Clients cannot forge or erase events; privileged actions have attributable evidence. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-036.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop actions requiring audit if recording fails. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-037"></a>

### Phase 037 — Forward migration rehearsal

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Apply upgrades to a sanitized prior-version database with realistic volume. Measure locking and check compatibility with old mobile clients. Use expand-and-contract changes for breaking fields and document interrupted states, avoiding destructive cleanup in the first rollout.

**Acceptance and verification:** Old and new clients function during migration and interruption is recoverable. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-037.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a forward repair and compatible app build. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-038"></a>

### Phase 038 — Database performance evidence

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Generate labeled synthetic providers and service relationships at expected and stress scale. Inspect plans for search and owner dashboards. Add only measured indexes, recording write overhead and storage cost alongside read improvements; avoid changing relevance unnoticed.

**Acceptance and verification:** Before/after plans and latency demonstrate a useful improvement without semantic regression. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-038.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Drop ineffective indexes through a reviewed migration. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-039"></a>

### Phase 039 — HTTP authorization regression pack

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Probe every public endpoint with real guest, owner, other-owner, and admin tokens. Include direct-table reads, helper RPCs, hidden profiles, revoked consent, and storage URLs. Never run customer authorization checks with the service-role key.

**Acceptance and verification:** A deliberate forbidden-field or cross-owner mutation regression makes the pack fail. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-039.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Block promotion until the boundary is restored. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-040"></a>

### Phase 040 — Trusted backend gate

**Status:** Not started. **Suggested owner:** Backend and security engineer. **Effort:** 4–7 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [014](#phase-014), [020](#phase-020), [021](#phase-021), [022](#phase-022), [023](#phase-023), [024](#phase-024), [025](#phase-025), [026](#phase-026), [027](#phase-027), [028](#phase-028), [029](#phase-029), [030](#phase-030), [031](#phase-031), [032](#phase-032), [033](#phase-033), [034](#phase-034), [035](#phase-035), [036](#phase-036), [037](#phase-037), [038](#phase-038), [039](#phase-039) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/tests/database/`, `backend/scripts/`, `docs/backend-contract.md`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Harden the existing schema with forward migrations. Treat row policies, column privileges, function execution, and service-role operations as distinct controls; public HTTP access must match the field policy.

Review grants, field projection, lifecycle controls, query bounds, and platform-level tests. Require a second reviewer to reproduce the highest-impact disclosure and ownership cases. Distinguish verified Supabase behavior from still-unconfigured provider accounts.

**Acceptance and verification:** No unresolved critical authorization leak remains and recovery steps are executable. Exercise anon, owner, another owner, and administrator roles. Repeat critical boundaries through disposable Supabase HTTP APIs because SQL stubs do not represent the complete platform.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-040.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep production writes disabled while blocked. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 3 — Identity, OTP, sessions, and recovery

**Phases:** 41–60. **Lead:** Authentication and mobile engineer. **Entry dependencies:** phase 014, phase 020. **Release class:** Core launch.

<a id="phase-041"></a>

### Phase 041 — Live auth repository skeleton

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Implement ProviderAuthRepository with Supabase and explicit environment selection. Map SDK responses into domain types rather than spreading SDK objects across screens. Keep simulation restricted to a designated demo build and fail closed when production authentication configuration is missing.

**Acceptance and verification:** Contract tests choose the correct implementation in each environment. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-041.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Switch only development builds back to mocks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-042"></a>

### Phase 042 — Phone normalization and entry

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Review Indian mobile input, country codes, pasted separators, Unicode digits, invalid lengths, and international boundaries. Keep one canonical E.164 representation and accessible localized guidance. Never add a fixed production test number as a shortcut around validation.

**Acceptance and verification:** Dart and server fixtures agree on valid and invalid normalized input. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-042.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Preserve entered text when validation changes. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-043"></a>

### Phase 043 — SMS provider contract

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Evaluate current India delivery support, DLT setup, templates, outages, and pricing. Prepare the appropriate Supabase integration or SMS hook with secret ownership and timeout behavior. Use fake responses before provisioning accounts or sending paid messages.

**Acceptance and verification:** Adapter fixtures cover delivery success, rejection, duplication, and timeout. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-043.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Route staging to the fake sender. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-044"></a>

### Phase 044 — OTP challenge mapping

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Implement bounded challenge-to-phone bookkeeping required by the current interface. Clear it on logout and account change, and restart safely after process death. Ensure live mode never exposes simulatedCode or trusts a challenge belonging to another session.

**Acceptance and verification:** Expired and cross-session challenges cannot verify the wrong phone. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-044.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restart verification without losing safe draft fields. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-045"></a>

### Phase 045 — Verification and replay

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Use the server auth verifier for codes, expiration, and attempts. Map wrong-code and expired-code failures without revealing registration status. Reject replay and never infer success locally because connectivity failed or the UI countdown ended.

**Acceptance and verification:** Consumed codes fail on replay and wrong attempts create no account session. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-045.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Invalidate the local challenge and offer controlled resend. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-046"></a>

### Phase 046 — Resend and delayed delivery

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Coordinate resend cooldowns with server policy, disable duplicate submits, and handle delayed messages clearly. Preserve accessibility while loading and avoid resetting real limits when the app backgrounds. Record aggregate failures without storing message contents.

**Acceptance and verification:** Rapid taps and app restarts cannot evade server resend limits. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-046.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Offer bounded manual retry after cooldown. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-047"></a>

### Phase 047 — OTP pumping protection

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Enforce per-number, network/risk, and global spend controls at a boundary direct Auth requests cannot bypass. Use supported provider/platform hooks and expiring privacy-aware signals. Add thresholds, alert ownership, and a circuit breaker before expenditure becomes unbounded.

**Acceptance and verification:** Synthetic abuse hits hard limits while legitimate shared-network users retain recovery. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-047.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Temporarily stop outbound OTP and show service status. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-048"></a>

### Phase 048 — Enumeration resistance

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Compare unverified responses and timing for new, existing, suspended, and deleted numbers. Reveal account state only after phone control is proven. Remove information leaks from error details and support lookup endpoints available to untrusted callers.

**Acceptance and verification:** Pre-verification behavior does not disclose whether a number owns a listing. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-048.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return generic verification responses while investigating. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-049"></a>

### Phase 049 — Secure session persistence

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Evaluate SDK defaults and platform-backed Android storage for tokens. Separate session secrets from bookmarks and ordinary preferences. Clear owner-specific drafts and caches on logout/account switch, and avoid persisting credential evidence or raw conversations in generic local storage.

**Acceptance and verification:** A second account cannot recover the first account's token or private state. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-049.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Require reauthentication when secure storage is unsafe. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-050"></a>

### Phase 050 — Refresh and revocation

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Handle expired access tokens, concurrent refresh, revoked sessions, offline recovery, and background resume. Bound retries and prevent protected operations from falling back to guest or mock behavior. Preserve an editable draft when a fresh sign-in is necessary.

**Acceptance and verification:** Revoked sessions cannot write and concurrent requests avoid refresh storms. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-050.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop protected writes pending a new session. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-051"></a>

### Phase 051 — Owner-state restoration

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Fetch current server ownership when restoring a session. Route new, published, paused, suspended, and deleted profiles correctly instead of trusting cached IDs. Account recovery or phone changes must invalidate stale owner references and cached authorization assumptions.

**Acceptance and verification:** Every account state restores correctly without another provider's owner view. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-051.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Clear stale state and rebuild from verified identity. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-052"></a>

### Phase 052 — Verified phone change

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Require appropriate recent authentication and verification of the replacement number. Update canonical identity through trusted synchronization, audit the change, and define notification/session behavior. A number already owned by another account must never transfer its profile through a conflict.

**Acceptance and verification:** Interrupted or conflicting changes preserve the original verified ownership. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-052.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the original number until full commit. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-053"></a>

### Phase 053 — SIM-loss recovery workflow

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Create a support-assisted recovery case with minimal evidence, fraud review, and delayed high-risk transfer. Public listing knowledge is insufficient proof. Separate recovery preparation from actual ownership transfer and record reviewer rationale and challenge resolution.

**Acceptance and verification:** An impersonation attempt cannot transfer a listing using public facts. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-053.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Freeze disputed transfers under the existing owner. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-054"></a>

### Phase 054 — Administrator MFA and roles

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Require platform-supported MFA for privileged access and separate support, moderation, credential-review, and infrastructure roles. Avoid shared administrator identities and mutable client-controlled roles. Test route enforcement using ordinary provider accounts and stale privileged sessions.

**Acceptance and verification:** Metadata edits cannot confer privilege and admin routes require adequate assurance. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-054.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke privileged sessions and disable affected roles. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-055"></a>

### Phase 055 — Sensitive-action reauthentication

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Enforce recent authentication server-side for deletion, phone changes, private evidence export, and sensitive admin actions. Define assurance age and cancellation. After reauthentication, return to the reviewed action with fresh authorization rather than executing automatically.

**Acceptance and verification:** A valid but old session cannot perform a sensitive action. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-055.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Cancel the pending action without changing account data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-056"></a>

### Phase 056 — Reviewer access without backdoors

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Prepare minimally privileged review access isolated from real providers. Do not ship universal fixed codes, magic numbers, or admin bypasses. Document the supported review environment and ensure all required owner features are accessible without weakening production identity controls.

**Acceptance and verification:** Review instructions work and grant no unrelated private access. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-056.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Rotate or revoke review access after use. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-057"></a>

### Phase 057 — Deletion request endpoint

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [035](#phase-035), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Harden delete-account with verified caller identity, recent auth, stable safe errors, idempotency, and a job identifier. Coordinate auth removal with blob cleanup and retained records. Stop exposing raw internal failures and never accept a client-supplied victim identifier as authority.

**Acceptance and verification:** Retries preserve one deletion state and cross-account deletion attempts fail. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-057.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause before irreversible removal if prerequisites fail. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-058"></a>

### Phase 058 — Accessible localized verification

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Test TalkBack, large fonts, paste, keyboard navigation, slow SMS, and Hindi/Marathi messages. Avoid unnecessary SMS inbox permissions and technical error jargon. Provide a usable path through denied permissions, long waits, and failed resend attempts.

**Acceptance and verification:** The complete flow works with screen-reader navigation in all supported languages. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-058.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a simple code field if segmented input fails. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-059"></a>

### Phase 059 — Authentication stress scenarios

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Exercise concurrent sign-ins, logout during refresh, account switching during uploads, number changes during edits, and provider outages. Track aggregate failure types while keeping secrets out of evidence. Confirm retries and background work stop when account authority changes.

**Acceptance and verification:** No scenario crosses account boundaries or creates duplicate live identities. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-059.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the failing protected path, preserving guest search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-060"></a>

### Phase 060 — Identity readiness gate

**Status:** Not started. **Suggested owner:** Authentication and mobile engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [020](#phase-020), [041](#phase-041), [042](#phase-042), [043](#phase-043), [044](#phase-044), [045](#phase-045), [046](#phase-046), [047](#phase-047), [048](#phase-048), [049](#phase-049), [050](#phase-050), [051](#phase-051), [052](#phase-052), [053](#phase-053), [054](#phase-054), [055](#phase-055), [056](#phase-056), [057](#phase-057), [058](#phase-058), [059](#phase-059) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/domain/repositories/auth_repository.dart`, `lib/app/controllers/session_controller.dart`, `lib/data/supabase/` (new), `backend/supabase/config.toml`, `backend/supabase/functions/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Replace simulated identity through the existing repository contract while keeping guest discovery available. Phone verification establishes control of a number, not credentials, background screening, or trustworthiness.

Review SMS configuration, real adapter behavior, session persistence, recovery, privileged MFA, and budget controls. Demonstrate that the demo code cannot authenticate in production. Record actual staging delivery evidence and unresolved provider-account setup separately.

**Acceptance and verification:** A staging verification and all critical negative scenarios pass with operational instructions. Use isolated staging numbers and fake SMS fixtures where possible. Exercise expiry, replay, retries, suspension, and account switching without logging codes, tokens, or full personal numbers.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-060.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep production registration closed until controls pass. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 4 — Live Flutter repositories and contact

**Phases:** 61–80. **Lead:** Flutter integration engineer. **Entry dependencies:** phase 014, phase 040, phase 060. **Release class:** Core launch.

<a id="phase-061"></a>

### Phase 061 — Environment-aware composition root

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Add explicit demo, staging, and production factories and remove unconditional mock selection. Initialize backend dependencies before protected features load. Separate local preference failures from backend failures so a storage exception cannot silently make a release display demo data.

**Acceptance and verification:** Missing production configuration produces an actionable blocked state, not fictional providers. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-061.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the previous compatible release artifact. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-062"></a>

### Phase 062 — Shared mapping and error types

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Map timestamps, enums, optional values, prices, lists, and stable errors into domain objects. Document snake_case/camelCase boundaries. Reject impossible responses and handle unknown enum values conservatively, never interpreting an unfamiliar state as verified, active, or published.

**Acceptance and verification:** Fixtures cover nulls, missing optional fields, unknown states, and malformed responses. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-062.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pin the last compatible response contract. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-063"></a>

### Phase 063 — Live location repository

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Load cities, localities, activation status, and requests from the backend. Cache public reference data with revision and expiry. Preserve the chosen locality when valid; explain deactivation and offer a deliberate alternative instead of silently relocating a customer.

**Acceptance and verification:** Market activation changes the app through data without an update. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-063.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use only explicitly labeled safe stale reference data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-064"></a>

### Phase 064 — Live service catalog

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Load approved groups, categories, keywords, ordering, and icons through the existing contract. Preserve stable IDs and localization fallbacks. Handle retired categories and unknown icon keys in old links and saved profiles without accepting them for new publication.

**Acceptance and verification:** Data-driven catalog edits appear correctly and retired categories cannot be newly published. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-064.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior approved catalog revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-065"></a>

### Phase 065 — Bounded search adapter

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [062](#phase-062) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Map filters/pagination into the authorized search RPC. Ignore superseded asynchronous responses and preserve server ranking and sponsored flags. Avoid downloading all listings for client-side filtering or returning private fields through a general-purpose fetch.

**Acceptance and verification:** Rapid edits never let an older request overwrite newer search results. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-065.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the simplest bounded search route. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-066"></a>

### Phase 066 — Public profile adapter

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [062](#phase-062) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Use only the public projection for details, sharing, similar profiles, and bookmark refresh. Handle paused, suspended, deleted, and revoked records as unavailable. Never replace a missing linked profile with another provider while preserving the original person's identity on screen.

**Acceptance and verification:** Stale links cannot reveal hidden listings or cached private fields. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-066.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Show an explicit unavailable profile state. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-067"></a>

### Phase 067 — Owner profile adapter

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [062](#phase-062) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Use authenticated owner endpoints for editor/dashboard data and keep that cache separate from public cards. Recheck ownership after recovery or access changes. Handle a permission loss while the screen is open without retaining private content on subsequent accounts.

**Acceptance and verification:** Guessed IDs do not let another provider read or update owner records. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-067.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Close owner views and clear private caches. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-068"></a>

### Phase 068 — Transactional live onboarding

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [062](#phase-062) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Connect final review to atomic registration with versioned consent, valid categories, areas, and optional hours. Retain the draft until server success is known. Route validation errors back to the appropriate step, and resolve timeouts through idempotent retry rather than another profile creation.

**Acceptance and verification:** A timed-out resubmission yields one profile and preserves user input. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-068.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the draft at the review step. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-069"></a>

### Phase 069 — Revision-aware profile editing

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [067](#phase-067) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Send the current revision with saves, reconcile server validation, and show conflicts caused by another device or moderator. Preserve local text for deliberate merging. Do not announce success before acknowledgement or overwrite protected values with stale form state.

**Acceptance and verification:** Conflicting edits cannot erase newer changes or moderation decisions. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-069.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep server state authoritative with an editable local draft. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-070"></a>

### Phase 070 — Pause and publication controls

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [067](#phase-067) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Use server-confirmed transitions for pause, resume, and publication. Explain missing requirements and distinguish moderation suspension from owner pause. Reconcile optimistic UI after rejection and prevent a resume control from pretending it can override a server suspension.

**Acceptance and verification:** A paused profile disappears from fresh discovery and cannot bypass suspension. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-070.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the last server-confirmed listing state. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-071"></a>

### Phase 071 — Real call and WhatsApp launch

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [066](#phase-066) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Replace not-wired snackbars with validated tel and wa.me handoffs. Recheck eligibility, encode messages, handle missing apps, and preserve demo notices. Track intent separately from launcher result; do not claim the call, message, or job completed.

**Acceptance and verification:** Correct live destinations open; demo, revoked, and malformed contacts remain blocked. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-071.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Offer only consent-permitted safe contact fallback. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-072"></a>

### Phase 072 — Local guest bookmarks

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Keep anonymous saves on-device with minimal public fields, predictable ordering, and unavailable states. Version stored formats and provide clear-data controls. Do not upload bookmarks or require registration implicitly; refresh only authorized current public data.

**Acceptance and verification:** Bookmarks survive restart and respect known deletion and account-cache isolation. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-072.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore a supported bookmark format without owner data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-073"></a>

### Phase 073 — Draft ownership and expiry

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Version onboarding drafts and separate anonymous content from authenticated owner drafts. Define expiry and behavior after logout, account switch, reinstall, or schema changes. Exclude credential scans, tokens, and full AI sessions from general preferences.

**Acceptance and verification:** A switched account cannot recover another provider's private draft. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-073.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Preserve only a minimal non-sensitive recoverable draft. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-074"></a>

### Phase 074 — Live reports and city requests

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Wire the existing sheets to protected endpoints with localized reason codes, bounded text, deduplicated retries, and receipts. Support anonymous reports where intended while keeping the queue restricted. Distinguish accepted submission from an already-completed moderation decision.

**Acceptance and verification:** Repeated taps create one logical submission and providers cannot read private reports. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-074.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep minimal retry state or request explicit resubmission. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-075"></a>

### Phase 075 — Real engagement aggregates

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Replace sample counters with owner-authorized time-windowed aggregates. Separate views, contact taps, and shares; show freshness and unobserved outcome limits. Filter demo and QA traffic, and avoid leaking the identity of people browsing a provider.

**Acceptance and verification:** Synthetic events reconcile and another provider cannot read the counters. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-075.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide counters without interrupting discovery or contact. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-076"></a>

### Phase 076 — Consent and promotion-interest adapters

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Implement legitimate consent records and interest submissions without inventing paid subscriptions or granted placement. Block client changes to verification and sponsorship. Align commercial copy with actual supported operations and clearly distinguish requesting information from purchasing a service.

**Acceptance and verification:** Interest never grants paid status and client timestamps cannot fabricate consent evidence. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-076.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return the feature to informational mode. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-077"></a>

### Phase 077 — Offline and bounded retry UX

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Create consistent deadlines and bounded retries for safe reads and explicitly idempotent writes. Label stale public results and prevent protected offline actions from pretending to succeed. Preserve user input and eliminate infinite spinners or automatic demo fallback.

**Acceptance and verification:** Airplane-mode tests have clear outcomes without duplicate submissions. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-077.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop writes and show safe cached reads. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-078"></a>

### Phase 078 — Cache partition and invalidation

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Partition by environment, public/owner scope, account, locale, and revision. Invalidate on logout, suspension, deletion, consent withdrawal, and relevant catalog changes. Define maximum stale windows and avoid storing private owner objects in reusable public caches.

**Acceptance and verification:** Account switches and revocations demonstrate no cross-context reuse. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-078.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Clear only affected namespaces and refetch authorized data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-079"></a>

### Phase 079 — Deep links and external routes

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Align app and website provider, category, locality, help, and deletion URLs. Validate identifiers, unknown routes, external return paths, and allowed destinations. Keep links useful without the app and avoid following arbitrary URLs embedded in untrusted provider content.

**Acceptance and verification:** Shared links resolve equivalent eligible content; malformed IDs fail safely. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-079.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Send unsupported routes to the directory landing page. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-080"></a>

### Phase 080 — Live app acceptance gate

**Status:** Not started. **Suggested owner:** Flutter integration engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [014](#phase-014), [040](#phase-040), [060](#phase-060), [061](#phase-061), [062](#phase-062), [063](#phase-063), [064](#phase-064), [065](#phase-065), [066](#phase-066), [067](#phase-067), [068](#phase-068), [069](#phase-069), [070](#phase-070), [071](#phase-071), [072](#phase-072), [073](#phase-073), [074](#phase-074), [075](#phase-075), [076](#phase-076), [077](#phase-077), [078](#phase-078), [079](#phase-079) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/data/supabase/` (new), `lib/app/controllers/`, `lib/core/widgets/provider_contact.dart`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Connect existing repository interfaces to real services and retain the established navigation. A live failure must show an error or clearly stale public cache; it must never substitute fictional profiles or simulated authentication.

Run guest and provider journeys against staging with every required real adapter enabled. Capture the current build and verify sample labels disappear only when their sources are actually live. Complete verification, publication, edit, contact, pause, report, and deletion flows.

**Acceptance and verification:** Core journeys work end to end while guest browsing remains account-free. Use mapping fixtures and staging integration checks. Cover guest, owner, offline, empty, error, and account-switch states; demo identities must never launch a real contact action.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-080.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert the staging build while preserving compatible migrations. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 5 — Media, evidence, and trustworthy listings

**Phases:** 81–100. **Lead:** Storage and trust engineer. **Entry dependencies:** phase 013, phase 040, phase 060. **Release class:** Core launch.

<a id="phase-081"></a>

### Phase 081 — Storage classification contract

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Define buckets and policies for quarantine, approved portfolios, credential evidence, and future AI attachments. Specify ownership, MIME/size limits, expiry, signed-link lifetime, publication, and deletion. Reassess public provider-photos behavior for unpublished or suspended profiles.

**Acceptance and verification:** A matrix explains upload/read/publish/delete authority for every media class. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-081.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep unclassified objects private. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-082"></a>

### Phase 082 — Owner-bound upload authorization

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Authorize uploads for the current account, generated object key, approved bucket, and bounded size. Reject caller-chosen ownership prefixes and cross-account overwrites. Validate actual content after transfer instead of trusting client metadata or filename extensions.

**Acceptance and verification:** Expired authorization and changed destinations fail at both API and storage boundaries. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-082.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable upload issuance while preserving approved reads. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-083"></a>

### Phase 083 — Quarantine and content validation

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Validate magic bytes, decoded dimensions, file size, and supported formats server-side. Isolate resource-intensive decoding and reject malformed or decompression-bomb images. Keep pending files private with expiry and a clear processing state rather than publishing first and reviewing later.

**Acceptance and verification:** Renamed executables and oversized/malformed images never enter public delivery. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-083.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove rejected quarantine files through the cleanup process. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-084"></a>

### Phase 084 — Server-side metadata stripping

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Retain current client stripping as an optimization but enforce safe server re-encoding. Remove GPS, names, comments, device identifiers, and unnecessary metadata; preserve correct orientation. Keep originals private for only the agreed short processing window.

**Acceptance and verification:** Known EXIF/PNG metadata fixtures disappear from every public derivative. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-084.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop publication until safe processing is restored. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-085"></a>

### Phase 085 — Interrupted uploads and orphans

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Implement repeatable upload state with bounded retries and a grace period for abandoned files. Reconcile app crashes, processing failures, and missing profile references. Garbage collection must verify ownership and references before deletion instead of removing all old objects blindly.

**Acceptance and verification:** Interrupted uploads create no public partial file and eligible orphans eventually disappear. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-085.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause cleanup when reference checks are uncertain. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-086"></a>

### Phase 086 — Image derivatives and byte budgets

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Generate a small defined set of card thumbnails and full images. Use versioned URLs, useful placeholders, and measured low-bandwidth budgets. Avoid loading original-resolution media into search cards or generating excessive variants without a demonstrated display need.

**Acceptance and verification:** Representative browsing meets the media budget and replacements invalidate old revisions. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-086.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Serve the last approved derivative. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-087"></a>

### Phase 087 — Atomic gallery updates

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Bind approved objects to owned profile records with readiness checks. Implement ordering, replacement, and deletion atomically where possible. Enforce configurable photo limits server-side under concurrent uploads, and prevent rejected objects from appearing via a manually supplied URL.

**Acceptance and verification:** Concurrent additions respect limits and failed replacements preserve the previous gallery. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-087.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior approved reference list. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-088"></a>

### Phase 088 — Private credential intake

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Explain purpose, requested fields, reviewer access, and retention before credential upload. Collect the minimum necessary evidence and keep signed URLs short-lived and out of logs. Ordinary support roles must not automatically receive access to private documents.

**Acceptance and verification:** Guest, other-provider, and non-reviewer requests cannot retrieve evidence bytes. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-088.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke access and suspend intake. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-089"></a>

### Phase 089 — Credential decision workflow

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Model submitted, reviewing, needs-information, approved, rejected, and expired states. Require an authorized reviewer, source reference, rationale, and validity period. AI may summarize permitted evidence but cannot grant credentials or replace required registry checks.

**Acceptance and verification:** Each badge has a current attributable decision; providers cannot approve themselves. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-089.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Withdraw disputed or expired badges pending review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-090"></a>

### Phase 090 — Truthful trust badges

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Separate verified phone, reviewed listing, checked credential, and self-reported information. Add localized explanations of scope and limitations. Eliminate universal trusted/safe guarantees and client-controlled verification flags. Make expiry and withdrawal affect every public display.

**Acceptance and verification:** Badge truth tables match server evidence in all supported languages. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-090.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide an unreliable badge category. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-091"></a>

### Phase 091 — Precise location consent

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Distinguish public business address, approximate service locality, and residential coordinates. Require explicit precise-location consent and offer locality-only discovery. Apply the same disclosure policy to maps, APIs, exports, AI context, and image metadata.

**Acceptance and verification:** Locality-only profiles reveal no exact coordinates through public surfaces. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-091.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove precise pins while keeping area search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-092"></a>

### Phase 092 — Portfolio moderation pipeline

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Review harmful, misleading, irrelevant, or privacy-invasive images and captions before public use. Automated checks may prioritize human work; they cannot silently replace appeals. Keep pending or rejected material out of website and AI ingestion paths.

**Acceptance and verification:** Rejected media cannot be republished by changing a caption or metadata. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-092.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Quarantine affected media and preserve appeal access. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-093"></a>

### Phase 093 — Safe profile and caption text

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Bound user text, escape rendered HTML/JSON, and reject unsupported dangerous markup. Preserve legitimate multilingual characters rather than stripping whole scripts. Label provider text as untrusted data in future model contexts so it cannot become policy or tool instructions.

**Acceptance and verification:** Script-like content renders inertly and text cannot alter application privileges. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-093.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use plain-text rendering. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-094"></a>

### Phase 094 — Public-media takedown behavior

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Define origin removal, CDN invalidation, and signed-link behavior after suspension, deletion, or consent withdrawal. Choose revocable delivery where immediate exclusion is required. Explain that already-downloaded public copies cannot be recalled; do not promise impossible retroactive secrecy.

**Acceptance and verification:** A takedown drill measures the actual accessible window at origin and CDN. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-094.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Block origin delivery and purge affected keys. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-095"></a>

### Phase 095 — Portfolio provenance and duplicates

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Store provider-declared context and dates as claims, not authenticity proof. Detect exact repeated images for review and support stolen-work reports. Avoid publishing an unvalidated AI authenticity score or automatically labeling a provider fraudulent from similarity alone.

**Acceptance and verification:** Duplicate detection creates an explainable review case without automatic accusation. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-095.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove the heuristic from public decisions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-096"></a>

### Phase 096 — Impersonation and ownership disputes

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Create cases for recycled numbers, duplicate names, stolen photos, and contested listings. Require verified evidence before merging or transferring records. Protect reporters and preserve appeals; fuzzy matching may prioritize review but cannot decide ownership.

**Acceptance and verification:** Public information alone cannot transfer or merge a provider account. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-096.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restrict disputed changes until review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-097"></a>

### Phase 097 — Owner corrections and appeals

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Show actionable reasons for withheld badges, rejected photos, and suspension without exposing reporters or sensitive detection details. Accept structured corrections and track appeal status. Separate review of an appeal from automatically reapplying the original decision.

**Acceptance and verification:** Owners can understand, correct, and appeal while private reports stay hidden. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-097.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause erroneous automation during qualified review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-098"></a>

### Phase 098 — Accessible portfolio viewer

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Provide reviewed captions, useful image descriptions, predictable focus return, and accessible zoom/close controls. AI-generated descriptions require owner review and must not invent traits or quality. Test translated controls and screen-reader order across gallery states.

**Acceptance and verification:** A screen-reader user can navigate and exit the gallery independently. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-098.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a simpler text-and-image list. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-099"></a>

### Phase 099 — Storage retention and cost controls

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Measure bytes, derivative counts, orphans, processing failure, and egress by content class. Implement dry-run retention jobs, exception reporting, and cost alerts. Keep cleanup evidence without copying deleted personal content into logs indefinitely.

**Acceptance and verification:** A synthetic retention batch deletes only eligible expired objects. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-099.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable cleanup when eligibility is uncertain. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-100"></a>

### Phase 100 — Media and trust gate

**Status:** Not started. **Suggested owner:** Storage and trust engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [060](#phase-060), [081](#phase-081), [082](#phase-082), [083](#phase-083), [084](#phase-084), [085](#phase-085), [086](#phase-086), [087](#phase-087), [088](#phase-088), [089](#phase-089), [090](#phase-090), [091](#phase-091), [092](#phase-092), [093](#phase-093), [094](#phase-094), [095](#phase-095), [096](#phase-096), [097](#phase-097), [098](#phase-098), [099](#phase-099) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `backend/supabase/functions/`, `lib/core/utils/image_metadata.dart`, `lib/core/widgets/provider_photos.dart`, `lib/domain/models/moderation.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Move media into controlled storage while separating public portfolios, quarantined uploads, private credentials, and temporary attachments. Trust claims must reflect actual review, and lifecycle rules must work beyond the Flutter UI.

Rehearse upload, processing, review, publication, consent change, appeal, and complete deletion. Check public projections and storage permissions under every role. Verify badge wording matches actual review staffing and processes rather than aspirational marketing.

**Acceptance and verification:** No private evidence or unapproved media is public; database/blob cleanup reconciles. Use synthetic images with known metadata, malformed structures, and cross-owner paths. Test actual storage/CDN access, revocation, and cleanup rather than assuming database deletion removes blobs.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-100.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep uploads or badges disabled until repaired. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 6 — Local search, geography, and freshness

**Phases:** 101–120. **Lead:** Search and data-quality engineer. **Entry dependencies:** phase 009, phase 010, phase 040, phase 065. **Release class:** Core launch.

<a id="phase-101"></a>

### Phase 101 — Search evaluation dataset

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Build realistic English, Hindi, Marathi, Romanized, misspelled, mixed-language, and ambiguous Mumbai queries. Label category and geography separately from ranking preferences. Include unsupported requests and no-result cases, keeping a held-out set separate from examples used while tuning.

**Acceptance and verification:** Each case has reviewer rationale and no unnecessary personal search history. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-101.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain prior dataset versions for comparison. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-102"></a>

### Phase 102 — Reviewed service synonyms

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Add everyday problem phrases and trade synonyms as versioned catalog data. Handle ambiguous words through context and reviewed mappings, not indiscriminate keyword expansion. Preserve localized labels and document why a phrase belongs to a category.

**Acceptance and verification:** Synonym changes improve relevant matches without unrelated category expansion. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-102.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the previous catalog revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-103"></a>

### Phase 103 — Unicode and transliteration

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Normalize script variants, spacing, punctuation, and common Romanized language forms while preserving meaningful name differences. Use equivalent rules in tests and production. Avoid destructive conversion that merges unrelated localities or treats every short token as a fuzzy match.

**Acceptance and verification:** Reviewed native-script/transliterated pairs retrieve equivalent eligible categories. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-103.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Fall back to literal normalized search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-104"></a>

### Phase 104 — Multi-token lexical search

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Replace whole-string assumptions with a bounded token strategy using suitable existing Postgres features. Document category, locality, name, and description weights. Treat explicit geography as a constraint rather than allowing a matching biography to bypass it.

**Acceptance and verification:** Multi-term service/problem/locality queries return relevant eligible results. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-104.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert query and weight revisions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-105"></a>

### Phase 105 — Controlled typo tolerance

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Apply prefix/trigram matching only where labeled cases demonstrate benefit. Bound candidates, require useful token length, and set field-specific thresholds. Offer a correction when intent is ambiguous instead of silently changing a person's name or chosen area.

**Acceptance and verification:** Typo recall improves without degrading exact-name and locality precision. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-105.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable fuzzy expansion for weak fields. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-106"></a>

### Phase 106 — Locality aliases and boundaries

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Maintain canonical IDs, reviewed aliases, neighboring areas, and geographic provenance. Distinguish administrative names from everyday Mumbai usage and ask about ambiguous matches. Keep special cases in data rather than scattered UI conditionals.

**Acceptance and verification:** Aliases map predictably and ambiguous localities require deliberate selection. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-106.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the approved geography revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-107"></a>

### Phase 107 — Service-area eligibility

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Model declared travel areas separately from business location and customer area. Start with explicit localities; add radius/travel rules only if evidence warrants them. Do not assume a geographically nearby provider serves a locality merely because their pin is close.

**Acceptance and verification:** Providers outside declared coverage are excluded unless users broaden criteria. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-107.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to explicit locality membership. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-108"></a>

### Phase 108 — Why-this-result explanations

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Show reasons derived from current fields, such as category fit, declared coverage, language, or recently confirmed availability. Keep sponsorship separate and avoid best/safest/cheapest claims without evidence. Ensure reasons remain consistent after filters or source data change.

**Acceptance and verification:** Every explanation is traceable to an eligible field. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-108.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide unreliable explanations while preserving results. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-109"></a>

### Phase 109 — Honest sponsored placement

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Define clearly labeled sponsored slots that cannot displace all useful organic results. Apply identical eligibility, consent, and moderation rules. Prevent payments from affecting credentials, safety labels, or emergency relevance, and block providers from setting paid status themselves.

**Acceptance and verification:** An ineligible paid listing never appears and sponsorship is obvious. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-109.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable promotions, keeping organic ranking. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-110"></a>

### Phase 110 — Stable pagination

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Use deterministic tie-breaking and a defined contract for result changes between pages. Prevent duplicate cards, bound deep pagination, and restart coherently after major filters change. Handle deletion during browsing without resurfacing hidden rows from cache.

**Acceptance and verification:** Stable datasets paginate consistently and changed datasets fail gracefully. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-110.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restart from a fresh first page. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-111"></a>

### Phase 111 — Truthful search filters

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Align open-now, home visits, language, category, and locality with authoritative fields. Distinguish scheduled hours from explicit current availability, preserving unknown states. Ensure combined filters do not create client/server disagreement or misleading green indicators.

**Acceptance and verification:** Every returned result satisfies filters and missing hours stay unknown. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-111.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove inconsistent filters temporarily. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-112"></a>

### Phase 112 — Expiring availability heartbeat

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Allow providers to confirm available, busy, or unavailable for a chosen duration. Store last-confirmed time and decay old state into unknown. Support quiet hours and easy updates without implying immediate arrival, booking, or guaranteed response.

**Acceptance and verification:** Expired confirmations stop influencing live-availability ranking. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-112.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use ordinary hours when heartbeat data is unavailable. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-113"></a>

### Phase 113 — Holiday and exceptional hours

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Add date-specific closures, festivals, temporary travel, and shortened hours with clear precedence over weekly schedules. Validate timezone and overnight boundaries. Make exceptions easier to enter than rewriting every weekday and allow safe removal.

**Acceptance and verification:** Exceptions override correctly and expire without corrupting weekly hours. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-113.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove the faulty exception. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-114"></a>

### Phase 114 — Useful zero-result recovery

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Offer explicit alternatives: nearby area, broader category, different time, or saved intent. Explain each relaxation and require selection before changing filters. Never replace healthcare or urgent requests with unrelated paid results disguised as valid matches.

**Acceptance and verification:** Users understand why no result exists and control all broadening. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-114.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Show honest empty results with manual navigation. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-115"></a>

### Phase 115 — Low-bandwidth result cache

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Cache small public summaries with revision, filters, expiry, and clear age. Refresh eligibility before new contact disclosures where possible. Avoid storing private fields or portraying cached availability as live; define conservative behavior after known revocation.

**Acceptance and verification:** Offline results communicate age and respect known consent withdrawal. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-115.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Clear stale results while retaining local bookmarks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-116"></a>

### Phase 116 — Map and list parity

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Synchronize map/list eligibility and provide complete discovery without requiring maps or GPS. Use approximate coordinates where exact-location consent is absent. Ensure keyboard, screen-reader, and data-saving users can reach every result through the list.

**Acceptance and verification:** All pins have equivalent list entries without extra location disclosure. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-116.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable map rendering, preserving the list. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-117"></a>

### Phase 117 — Validated geography imports

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Create dry-run import diffs with unique IDs, parent constraints, translated labels, and provenance. Protect against accidental city activation and orphaned provider areas. Require reviewed batches and a safe restoration path for reference-data mistakes.

**Acceptance and verification:** Malformed imports cannot activate markets or corrupt geographic references. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-117.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reapply the last approved snapshot. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-118"></a>

### Phase 118 — Search abuse controls

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Measure high-volume enumeration and cap expensive queries without invasive identity tracking or blocking ordinary guest access. Use graduated throttling and safe caching. Acknowledge that publicly consented details remain copyable rather than promising prevention through obfuscation.

**Acceptance and verification:** Abuse triggers limits while shared-network users retain basic search. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-118.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable expensive query features during an incident. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-119"></a>

### Phase 119 — Ranking quality and fairness

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Review exposure by locality, category, language, and new-provider status with sufficient samples. Detect incentives for category stuffing or irrelevant photo uploads. Base changes on relevance and transparent policy, avoiding sensitive-trait inference or unsupported quality scoring.

**Acceptance and verification:** Every ranker change includes held-out relevance and exposure-impact evidence. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-119.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior ranker and catalog. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-120"></a>

### Phase 120 — Discovery acceptance gate

**Status:** Not started. **Suggested owner:** Search and data-quality engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [009](#phase-009), [010](#phase-010), [040](#phase-040), [065](#phase-065), [101](#phase-101), [102](#phase-102), [103](#phase-103), [104](#phase-104), [105](#phase-105), [106](#phase-106), [107](#phase-107), [108](#phase-108), [109](#phase-109), [110](#phase-110), [111](#phase-111), [112](#phase-112), [113](#phase-113), [114](#phase-114), [115](#phase-115), [116](#phase-116), [117](#phase-117), [118](#phase-118), [119](#phase-119) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/migrations/`, `lib/app/controllers/provider_search_controller.dart`, `lib/features/search/`, `lib/data/seed/`, `lib/domain/models/location.dart`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve deterministic discovery before adding model interpretation. Eligibility by publication, moderation, market, category, and consent always precedes relevance ranking and cannot be overridden by paid placement or similarity scores.

Run the full query set, scale checks, stale-data scenarios, and customer tasks. Separate low supply from algorithm defects. Confirm users understand explanations and empty states, and record weak languages or markets as explicit limitations.

**Acceptance and verification:** Core queries meet declared relevance/latency targets with no eligibility leaks. Use labeled multilingual queries, synthetic scale data, and native-language review. Measure precision, useful empty-state recovery, latency, and exposure concentration with documented samples and conditions.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-120.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Ship stable lexical search while deferring weak enhancements. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 7 — Accessible multilingual product experience

**Phases:** 121–140. **Lead:** Flutter product designer and engineer. **Entry dependencies:** phase 002, phase 003, phase 020. **Release class:** Core launch.

<a id="phase-121"></a>

### Phase 121 — Screen and component state matrix

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Catalog existing screens with loading, empty, success, error, offline, disabled, and permission states. Identify duplicated controls and inconsistent spacing before redesigning. Tie each state to actual repository behavior rather than assuming mock success represents production UX.

**Acceptance and verification:** Every main journey includes explicit network, validation, and missing-data behavior. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-121.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain existing navigation while replacing individual components. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-122"></a>

### Phase 122 — Category-card clipping repair

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Fix the observed category labels that wrap awkwardly or disappear on narrow screenshots. Use responsive columns, sensible wrapping, and minimum dimensions instead of shrinking every label. Test long English names and Devanagari at increased system text size.

**Acceptance and verification:** No essential category label is clipped at agreed minimum widths and text scales. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-122.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a simpler two-column or list layout. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-123"></a>

### Phase 123 — Home information hierarchy

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Prioritize locality, search, useful categories, and honest live/demo status. Reduce competing visual weight while preserving sponsor labels and provider entry points. Test first-use comprehension rather than adding a larger decorative hero that pushes the core action below the screen.

**Acceptance and verification:** New users identify their area and start a service search without explanation. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-123.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior hierarchy if task completion worsens. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-124"></a>

### Phase 124 — Guest onboarding without permission pressure

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Allow simple locality/language selection with optional guidance and manual location entry. Avoid requiring GPS, notifications, or account creation before discovery. Explain why area information matters and preserve a usable default when users skip nonessential steps.

**Acceptance and verification:** A fresh install reaches meaningful guest search without unnecessary permissions. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-124.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use manual locality selection and standard welcome. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-125"></a>

### Phase 125 — Structured provider comparison

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Compare up to three providers using coverage, category, language, price caveats, freshness, and evidence-backed badges. Show missing information as unknown, not a negative rating. Keep the layout readable at large text and avoid overwhelming customers with internal fields.

**Acceptance and verification:** Comparison uses current public data and is navigable with assistive technology. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-125.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep individual profiles if comparison is disabled. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-126"></a>

### Phase 126 — Public profile hierarchy

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Organize service fit, contact availability, area, hours, evidence, and photos for quick assessment. Place limits close to claims, distinguish healthcare qualifications from marketing, and avoid fabricated reviews. Preserve contact actions while users inspect important trust details.

**Acceptance and verification:** Users can find contact, coverage, and badge meanings during a short task. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-126.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the previous component order. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-127"></a>

### Phase 127 — Shorter provider onboarding

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Measure step-level friction using minimal aggregate data. Require only genuine publication essentials initially and offer optional enrichment later. Preserve consent and eligibility checks, honest progress, and interrupted drafts rather than reducing visible steps while hiding extra requirements.

**Acceptance and verification:** Providers understand required fields and can resume without lost input. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-127.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to the established wizard structure. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-128"></a>

### Phase 128 — Inline validation and recovery

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Attach errors to the relevant field or step with corrective examples. Preserve completed values and map stable server errors consistently. Focus an accessible summary when several errors occur instead of relying on disappearing snackbars or resetting the entire form.

**Acceptance and verification:** Representative failures identify the right control and preserve unrelated input. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-128.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a simple linked error summary. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-129"></a>

### Phase 129 — Useful provider dashboard

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Prioritize visibility state, required fixes, availability, real aggregate interest, and support needs. Label delayed or unobserved outcomes. Avoid incentives to upload irrelevant material or buy sponsorship merely to look trustworthy; expose actual useful owner actions first.

**Acceptance and verification:** Providers can tell whether they are visible and what action is needed. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-129.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide unreliable metrics, preserving listing controls. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-130"></a>

### Phase 130 — Local saved-list organization

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Prototype optional notes or folders only if research supports them. Keep personal notes on-device by default and explain exports/deletion. Retain a simple flat list and avoid introducing account requirements or unnoticed uploads for a convenience feature.

**Acceptance and verification:** Users can organize and erase notes without signing in. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-130.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to the flat bookmark list without losing references. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-131"></a>

### Phase 131 — Localization completeness

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Find hard-coded text, errors, weekday abbreviations, semantics labels, tooltips, and pluralization gaps. Preserve the current localization approach unless a concrete problem justifies migration. Assign native-language review for trust, safety, and legal terminology.

**Acceptance and verification:** Launch-critical strings exist and are reviewed in English, Hindi, and Marathi. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-131.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use explicit English fallback instead of blanks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-132"></a>

### Phase 132 — Language switching and mixed script

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Persist language preference without corrupting navigation or drafts. Test mixed Latin/Devanagari text, prices, numbers, punctuation, and long names. Keep provider-authored content in its original language unless translation is requested and clearly labeled.

**Acceptance and verification:** Mid-onboarding language changes preserve the draft and available actions. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-132.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Rebuild the screen in the last stable locale. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-133"></a>

### Phase 133 — TalkBack semantics

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Audit headings, button names, loading/error announcements, badge explanations, image controls, and bottom navigation. Remove decorative noise and identify the provider in contact actions. Verify complete journeys on a real screen reader rather than relying only on widget semantics snapshots.

**Acceptance and verification:** A blind tester completes discovery, saving, reporting, and onboarding independently. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-133.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Replace failing custom controls with standard accessible widgets. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-134"></a>

### Phase 134 — Large text and touch targets

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Test supported font/display scaling on narrow devices and long translations. Keep adequate targets, scrollable dialogs, and reachable confirmations. Do not disable system scaling to hide overflows; redesign dense layouts when necessary.

**Acceptance and verification:** Essential controls remain visible and operable at the maximum tested scale. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-134.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stack dense content vertically. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-135"></a>

### Phase 135 — Contrast and non-color cues

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Measure text, icons, badges, focus, errors, and disabled states. Preserve branding while correcting measured failures. Add wording or shape where status currently depends only on color, and test grayscale interpretation of availability and verification.

**Acceptance and verification:** Core states pass chosen contrast checks and are understandable without color. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-135.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use an accessible neutral variant. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-136"></a>

### Phase 136 — Reduced motion and bounded loading

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Respect system reduced-motion preferences and avoid repeatedly animating refreshed content. Replace indefinite spinners with useful progress or timeout states. Preserve focus and scroll position across searches and tabs; no important behavior may depend on animation timing.

**Acceptance and verification:** Reduced-motion mode and delayed-network tests remain usable. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-136.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use immediate transitions and static placeholders. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-137"></a>

### Phase 137 — Low-literacy assisted use

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Prototype simpler wording, icon-plus-text actions, short guidance, and optional read-aloud. Test comprehension rather than assuming icons are universal. Keep family assistance distinct from account ownership so helping a provider cannot silently transfer control of their listing.

**Acceptance and verification:** Participants interpret core actions and errors without technical vocabulary. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-137.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the standard interface easily available. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-138"></a>

### Phase 138 — Focused accessibility regressions

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Add meaningful fixtures for observed clipping, focus loss, semantics, and large-text bugs. Prefer behavior checks and selective goldens over brittle screenshots for every screen. Document manual checks that automated tests cannot prove.

**Acceptance and verification:** Reintroducing a known overflow or inaccessible error makes the relevant check fail. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-138.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Update fixtures only after reviewing real differences. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-139"></a>

### Phase 139 — Usability sessions and repairs

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Run consented guest, owner, contact, trust, and deletion tasks. Separate observed failures from stylistic preferences and rank by task impact. Make bounded changes and repeat affected tasks with anonymized notes and recorded test conditions.

**Acceptance and verification:** The most serious usability issues have before/after task evidence. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-139.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert changes that reduce comprehension or success. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-140"></a>

### Phase 140 — Experience acceptance gate

**Status:** Not started. **Suggested owner:** Flutter product designer and engineer. **Effort:** 2–5 focused hours. **Release class:** Core launch.

**Prerequisites:** [002](#phase-002), [003](#phase-003), [020](#phase-020), [121](#phase-121), [122](#phase-122), [123](#phase-123), [124](#phase-124), [125](#phase-125), [126](#phase-126), [127](#phase-127), [128](#phase-128), [129](#phase-129), [130](#phase-130), [131](#phase-131), [132](#phase-132), [133](#phase-133), [134](#phase-134), [135](#phase-135), [136](#phase-136), [137](#phase-137), [138](#phase-138), [139](#phase-139) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/`, `lib/core/widgets/`, `lib/core/theme/`, `lib/core/l10n/`, `test/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Improve the established interface using observable customer and provider problems. Preserve clear direct-contact journeys on narrow Android screens, large text, assistive technology, and intermittent connectivity instead of redesigning for novelty.

Review language quality, narrow-screen captures, accessibility evidence, and research outcomes. Resolve all blockers in authentication, contact, reporting, and deletion. Align terminology with website and AI plans so trust explanations do not contradict each other.

**Acceptance and verification:** Essential journeys pass the agreed device, language, and accessibility matrix. Review narrow-phone, enlarged-text, translated, offline, and error states. Use actual TalkBack and keyboard interaction where applicable; screenshots alone do not establish accessibility or working behavior.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-140.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hold affected screens until essential access is restored. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 8 — Production public website

**Phases:** 141–160. **Lead:** Web engineer. **Entry dependencies:** phase 011, phase 014, phase 015, phase 020. **Release class:** Core launch.

<a id="phase-141"></a>

### Phase 141 — Website foundation and routes

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Create a minimal locked Astro project with explicit configuration and documented build commands. Establish public content, live discovery, not-found, and protected administration boundaries as applicable. Keep privileged keys out of public environment variables, generated files, and browser bundles.

**Acceptance and verification:** A clean install builds reproducibly with the essential route skeleton. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-141.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Redeploy the last validated artifact. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-142"></a>

### Phase 142 — Shared design and content contract

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Export approved colors, spacing, typography, logo use, and shared wording from the app into a small versioned contract. Separate platform-specific interactions from shared facts. Do not copy seed listings into production pages as if they were real supply.

**Acceptance and verification:** The website matches the app's design and authoritative content without fake claims. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-142.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pin the previous token/content revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-143"></a>

### Phase 143 — Honest public homepage

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Explain area selection, provider comparison, and direct contact. Present current market availability and provider benefits without invented testimonials, usage numbers, guarantees, or business details. Keep clear, accessible entry points into search and provider onboarding.

**Acceptance and verification:** Every public claim is supported by real behavior or an approved fact. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-143.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove unsupported claims while keeping discovery links. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-144"></a>

### Phase 144 — URL-addressable live search

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Implement shareable query/filter URLs using the same authorized bounded search contract as Flutter. Preserve locality and query through navigation, show sponsorship explicitly, and handle empty/error states. Validate parameters at the trusted boundary instead of relying on form controls.

**Acceptance and verification:** A shared URL reproduces equivalent eligible results across screen sizes. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-144.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a simplified directory route. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-145"></a>

### Phase 145 — Fresh provider pages

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Render the current public projection with SSR or a short measured cache and takedown controls. Define unavailable, deleted, and temporary-error responses. Prevent a static export from indefinitely preserving revoked contact, suspended listings, or owner-only fields.

**Acceptance and verification:** Revocation removes sensitive data within the documented cache limit. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-145.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Bypass cache and serve an unavailable state. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-146"></a>

### Phase 146 — City and locality pages

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Publish genuinely useful pages for active supported markets with real supply information and reviewed descriptions. Avoid thin pages for every unlaunched city. Handle translations and inactive data carefully so search-engine presence never implies available providers where none exist.

**Acceptance and verification:** Only useful approved market pages are indexable. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-146.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Apply noindex until content is corrected. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-147"></a>

### Phase 147 — Locality-service landing pages

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Create selected high-value combinations with distinct guidance and current eligible listings. Define minimum usefulness and supply conditions before indexing. Avoid duplicate keyword paragraphs and fabricated providers merely to multiply pages.

**Acceptance and verification:** Reviewed pages add real information and show accurate service coverage. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-147.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove weak combinations from indexing. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-148"></a>

### Phase 148 — Provider acquisition bridge

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Explain publication requirements, privacy choices, eligibility, and actual pricing status. Link to supported app onboarding or a deliberately implemented web owner flow. Avoid collecting the same personal data twice through marketing forms and clarify verification limits.

**Acceptance and verification:** Each CTA reaches a working supported onboarding path. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-148.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the page informational until integration works. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-149"></a>

### Phase 149 — Help and support pages

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Publish task-based guidance for searching, contact problems, listing edits, reports, recovery, and deletion. Use real configured support addresses and approved response expectations. Avoid introducing a form until its storage, abuse, access, and retention behavior exists.

**Acceptance and verification:** Support links work and no placeholder contact domain remains at release. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-149.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the approved support email route. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-150"></a>

### Phase 150 — Legal and external deletion pages

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Synchronize privacy, terms, community guidance, grievance details, and a usable deletion-request path with the app. Insert verified operator information and reviewed versions. Explain identity checks without requiring users to reinstall the app simply to request account deletion.

**Acceptance and verification:** The public deletion URL works and matches actual retention behavior. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-150.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Block new registration if essential disclosures are unavailable. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-151"></a>

### Phase 151 — Canonicals and localized metadata

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Generate unique titles, descriptions, canonical URLs, social previews, and valid locale links. Bound indexable filter combinations and use one production origin. Avoid contradictory metadata that advertises draft services or exposes staging hosts in public canonicals.

**Acceptance and verification:** A crawl detects no accidental demo/staging indexing or duplicate canonical loops. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-151.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use a site-wide noindex control during repairs. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-152"></a>

### Phase 152 — Truthful structured data

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Add only appropriate structured claims visible on the page and supported by current public records. Do not invent aggregate ratings, certifications, or medical credibility. Escape JSON safely and check current search-platform guidance during implementation.

**Acceptance and verification:** Validators pass and each field maps to a supported visible fact. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-152.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove invalid structured-data blocks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-153"></a>

### Phase 153 — Sitemaps and removal workflow

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Generate sitemaps from eligible pages, excluding private, demo, inactive, or deleted records. Separate crawler preferences from actual authorization. Provide reviewed cache invalidation and removal procedures for takedowns, including the limits of third-party search caches.

**Acceptance and verification:** Deleted listings leave sitemaps and private routes remain unauthorized regardless of robots behavior. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-153.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop sitemap publication until eligibility is repaired. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-154"></a>

### Phase 154 — Responsive web accessibility

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Test landmarks, headings, skip links, keyboard focus, form errors, menus, cards, and contact actions. Cover zoom and narrow widths with translated text. Remove hover-only or precision-pointer requirements and keep trust explanations consistent with the app.

**Acceptance and verification:** Essential web journeys work keyboard-only and at high zoom. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-154.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use native accessible controls. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-155"></a>

### Phase 155 — Web performance budgets

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Measure on a documented throttled mobile profile. Limit shipped JavaScript, size images, optimize font delivery, and load maps only when useful. Report reproducible conditions rather than a single fast-desktop score; protect basic interaction when optional widgets fail.

**Acceptance and verification:** Key pages meet the agreed loading, interaction, and layout-shift targets. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-155.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable optional scripts or rich maps. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-156"></a>

### Phase 156 — Browser security headers

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Configure CSP, framing controls, MIME protection, referrer policy, and secure transport for the actual deployment. Reconcile scripts, maps, auth redirects, and fonts without broad unsafe allowances. Test a new CSP in report-only mode before enforcement when appropriate.

**Acceptance and verification:** Expected flows work and injected script/iframe cases are blocked. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-156.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the specific previous policy revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-157"></a>

### Phase 157 — Authenticated browser protection

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Choose a coherent cookie/token design for web owner or admin features. Apply CSRF, origin, session, and authorization controls appropriate to that design. Public pages remain session-free; CORS is not a substitute for server authorization.

**Acceptance and verification:** Cross-site mutations and anonymous owner/admin reads fail. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-157.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable authenticated web mutations, preserving public pages. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-158"></a>

### Phase 158 — Android links and sharing

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Publish verified app-link configuration and canonical provider URLs. Preserve useful web content when Android is absent and avoid intrusive install walls. Validate redirect targets and campaign fields, keeping personal phone or message content out of tracking URLs.

**Acceptance and verification:** The same link opens the correct eligible content with or without the app. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-158.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the canonical web route. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-159"></a>

### Phase 159 — Minimal website measurement

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Replace stale Floot assumptions with a justified measurement approach. Define events, purpose, retention, consent applicability, and bot filtering. Do not capture raw phone numbers, private messages, or precise location in ordinary analytics. Make measurement independently removable.

**Acceptance and verification:** A network audit matches the disclosed data inventory. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-159.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove optional measurement scripts. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-160"></a>

### Phase 160 — Website staging gate

**Status:** Not started. **Suggested owner:** Web engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [011](#phase-011), [014](#phase-014), [015](#phase-015), [020](#phase-020), [141](#phase-141), [142](#phase-142), [143](#phase-143), [144](#phase-144), [145](#phase-145), [146](#phase-146), [147](#phase-147), [148](#phase-148), [149](#phase-149), [150](#phase-150), [151](#phase-151), [152](#phase-152), [153](#phase-153), [154](#phase-154), [155](#phase-155), [156](#phase-156), [157](#phase-157), [158](#phase-158), [159](#phase-159) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new Astro project), `tool/export_website_data.py` (new if justified), `docs/deploy/website.md` (new), `lib/core/theme/`, `lib/features/legal/`. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the Astro website described in the existing plan, sharing approved public contracts and design tokens. Stable content can be static; revocable provider details need live eligibility or explicitly bounded cache invalidation.

Deploy a noindex staging artifact and check live search, removed profiles, legal links, app links, mobile layouts, security headers, and performance. Capture the actual website build, not legacy showcase HTML, and record its revision and backend environment.

**Acceptance and verification:** The website passes the declared content, accessibility, freshness, and security checks. Check mobile/desktop navigation, keyboard access, metadata, safe rendering, and removal behavior. Never treat robots rules or an unlisted URL as privacy protection, and keep demo/staging pages unindexed.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-160.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Redeploy the last verified artifact. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 9 — Saathi AI platform and security

**Phases:** 161–180. **Lead:** AI platform and security engineer. **Entry dependencies:** phase 011, phase 012, phase 013, phase 020, phase 040. **Release class:** AI pilot.

<a id="phase-161"></a>

### Phase 161 — AI charter and boundaries

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Define service clarification, grounded discovery, listing explanation, provider drafting, and approved help as supported tasks. Exclude autonomous contact, booking, payment, medical diagnosis, and invented verification. Document accepted, clarified, refused, and deterministic-fallback examples in each launch language.

**Acceptance and verification:** The charter maps every proposed tool to a bounded user benefit and explicit exclusions. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-161.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable AI entry points, preserving ordinary search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-162"></a>

### Phase 162 — Data and processor assessment

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Classify prompt fields and review provider retention, training use, regions, subprocessors, endpoint differences, and deletion capabilities. Do not assume a storage flag means no provider-side retention or that zero-retention settings are automatically available. Record consent and contractual prerequisites.

**Acceptance and verification:** An approved field-flow matrix identifies exactly what may leave LocalSaathi. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-162.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use synthetic or public-only context pending review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-163"></a>

### Phase 163 — Model selection benchmark

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Compare a small set of currently available models on multilingual intent, structured tools, grounding, latency, and measured cost. Resolve model names from current official documentation during execution. Select a primary configuration and only an evaluated, contractually approved fallback.

**Acceptance and verification:** A reproducible scorecard justifies quality, safety, latency, and per-task cost. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-163.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pin the prior evaluated configuration or disable generation. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-164"></a>

### Phase 164 — Server AI gateway

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Create one validated gateway for bounded guest requests and authenticated owner assistance. Define typed requests, payload limits, deadlines, and normalized errors. Keep model keys in server secrets; clients must not call the provider directly or choose arbitrary upstream endpoints.

**Acceptance and verification:** Malformed requests fail before model invocation and client bundles contain no model secrets. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-164.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return deterministic search/help through the client contract. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-165"></a>

### Phase 165 — Guest quotas and fair access

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Provide limited guest AI without forcing account creation for normal discovery. Combine expiring coarse abuse signals, session/network quotas, and project ceilings without invasive fingerprinting. Close direct gateway bypasses and retain a usable path for legitimate shared-network customers.

**Acceptance and verification:** Abuse reaches hard limits while non-AI search remains available. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-165.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable guest generation during abuse. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-166"></a>

### Phase 166 — Owner-private context authorization

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Derive identity from a verified session and retrieve private data under that caller's rights. Never trust a model/client provider_id as authority. Recheck every tool request after access changes, phone recovery, suspension, or session expiry.

**Acceptance and verification:** Cross-owner prompts and forged tool arguments retrieve no private data. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-166.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove private-owner tools, retaining public assistance. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-167"></a>

### Phase 167 — Versioned prompt registry

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Review and version system instructions, locale styles, tools, model parameters, and safety settings together. Attach revisions to redacted traces and evaluations. Exclude secrets from prompts because system-instruction confidentiality is not a security boundary or reliable access control.

**Acceptance and verification:** A response can be traced to its configuration without storing unnecessary conversation content. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-167.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the last evaluated configuration pair. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-168"></a>

### Phase 168 — Strict tool contracts

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Define narrow tools for provider search, public details, the caller's listing, and approved help. Validate all arguments server-side even with provider schema constraints. Reject unknown tools, extra fields, arbitrary SQL, shell commands, and unrestricted URL fetching.

**Acceptance and verification:** Malformed and unauthorized tool calls cannot invoke unregistered operations. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-168.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the offending tool. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-169"></a>

### Phase 169 — Read-only initial assistant

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Keep all launch tools read-only. Provider assistance creates an editable draft, while normal UI handles publishing, contact, reports, and deletion. Any later write tool requires preview, fresh authorization, explicit confirmation, and idempotency enforced outside model text.

**Acceptance and verification:** Prompting for a side effect cannot cause one during the initial pilot. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-169.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke write capabilities at the gateway. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-170"></a>

### Phase 170 — Injection containment

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Label retrieved biographies, documents, messages, and captions as untrusted data. Limit tool scope and privileges so embedded instructions cannot retrieve secrets, override policies, or access another account. Test native-script, translated, and indirect attacks rather than relying on refusal wording alone.

**Acceptance and verification:** Malicious listing text cannot alter authority or trigger unapproved tools. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-170.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Quarantine the affected source and tool. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-171"></a>

### Phase 171 — Safe output validation

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Validate response envelopes, provider IDs, references, URLs, and action types before display. Render a constrained safe format. Fetch contact and eligibility facts from authoritative records instead of accepting model-generated phone numbers, badges, or destinations.

**Acceptance and verification:** Fabricated IDs and executable markup never become actionable cards. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-171.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Show verified results with plain-text fallback. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-172"></a>

### Phase 172 — Sensitive-field minimization

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Keep OTPs, tokens, credential scans, unrelated identities, and exact private addresses out of routine prompts and logs. Combine field allowlists with limited detectors; patterns alone cannot guarantee redaction. Explain user-entered sensitive data handling and provide deletion controls.

**Acceptance and verification:** Synthetic secret fixtures do not reach upstream requests or operational logs. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-172.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Block affected request categories pending repair. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-173"></a>

### Phase 173 — Conversation lifecycle

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Use short-lived guest context and optional persistence only where justified for owners. Bind sessions to identity, environment, and permission scope. Define expiry, truncation, deletion, and export, including behavior when referenced providers or documents disappear.

**Acceptance and verification:** Another user cannot resume a session and expired data leaves active stores. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-173.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Clear context and start a new session. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-174"></a>

### Phase 174 — Redacted AI observability

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Record configuration, authorized tool names, correlation ID, latency, usage, and outcome categories. Keep full transcripts off by default. Separate consented evaluation samples from operational metrics, with access and retention limits rather than a shared unlimited debug log.

**Acceptance and verification:** Incidents can be traced without routinely retaining complete private conversations. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-174.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable content sampling while preserving minimal metrics. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-175"></a>

### Phase 175 — Bounded execution and cancellation

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Set request deadlines, provider timeouts, maximum tool turns, output size, and retry budgets. Cancel abandoned work where supported and avoid blind retries that multiply cost. Define partial-stream failure and UI recovery without displaying unvalidated actions.

**Acceptance and verification:** Hanging requests stop within budget and do not spawn unlimited tools. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-175.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return ordinary search or approved help. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-176"></a>

### Phase 176 — Cost ledger and circuit breaker

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Track estimated and billed usage by feature, environment, and cohort. Reconcile pricing/configuration changes and cap per-request/project expenditure, including concurrent in-flight work. Alert before the hard limit and document who can raise budgets.

**Acceptance and verification:** Load tests cannot create unbounded overspend through concurrent requests. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-176.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable expensive generation paths. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-177"></a>

### Phase 177 — Approved outage fallback

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Handle provider failure with a pre-evaluated policy. Never send private context to an unapproved second vendor. Prefer deterministic search and reviewed FAQs when no suitable model is available, and explain temporary limits rather than simulating a model response.

**Acceptance and verification:** An outage preserves discovery without unauthorized processor transfer. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-177.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep generation off until approved service recovers. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-178"></a>

### Phase 178 — Healthcare and urgent-risk routing

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Limit healthcare assistance to directory discovery and supported listing facts. Use reviewed concise guidance for urgent-risk language without diagnosis, prescriptions, or promised response. Have appropriate domain and language reviewers approve the handling of medical and hazardous-repair requests.

**Acceptance and verification:** Critical boundary cases use the approved route and do not produce unsafe guarantees. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-178.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable sensitive-category AI assistance. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-179"></a>

### Phase 179 — AI reporting and controls

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Add report-answer, reset, deletion/data-use explanations, and a clear non-AI path. Collect only necessary report context and request consent for extra diagnostics. Keep reports private from providers and do not force users to continue chatting to report a problem.

**Acceptance and verification:** Users can report and leave AI without losing core app access. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-179.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable persistence while preserving report receipts. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-180"></a>

### Phase 180 — AI platform gate

**Status:** Not started. **Suggested owner:** AI platform and security engineer. **Effort:** 4–7 focused hours. **Release class:** AI pilot.

**Prerequisites:** [011](#phase-011), [012](#phase-012), [013](#phase-013), [020](#phase-020), [040](#phase-040), [161](#phase-161), [162](#phase-162), [163](#phase-163), [164](#phase-164), [165](#phase-165), [166](#phase-166), [167](#phase-167), [168](#phase-168), [169](#phase-169), [170](#phase-170), [171](#phase-171), [172](#phase-172), [173](#phase-173), [174](#phase-174), [175](#phase-175), [176](#phase-176), [177](#phase-177), [178](#phase-178), [179](#phase-179) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `lib/domain/repositories/ai_repository.dart` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Build the owner-selected branded assistant using an existing model and permission-scoped application data. Own LocalSaathi's experience, retrieval, configuration, and evaluation; never claim ownership of the underlying foundation model.

Review permission boundaries, processor decisions, limits, traces, tool tests, and fallback drills. Demonstrate that generation cannot bypass ordinary publication or ownership rules. Admit only a bounded internal cohort before customer rollout and name an incident owner.

**Acceptance and verification:** Isolation, injection containment, budget, and outage checks pass with evidence. Use fake-model deterministic tests and budgeted isolated model evaluations. Treat prompts and outputs as untrusted; code must enforce authorization, data minimization, tool limits, and side-effect boundaries.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-180.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep AI flags off until critical issues are closed. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 10 — Grounded retrieval and knowledge lifecycle

**Phases:** 181–200. **Lead:** Retrieval and data engineer. **Entry dependencies:** phase 013, phase 040, phase 101, phase 180. **Release class:** AI pilot.

<a id="phase-181"></a>

### Phase 181 — Approved source registry

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Inventory help documents, service explanations, public listing fields, and owner-authorized drafts. Assign source owner, audience, language, revision, expiry, and permitted purpose. Exclude credential scans, moderation reports, and unrestricted internet scraping from the initial corpus.

**Acceptance and verification:** Unregistered or audience-undefined sources cannot enter retrieval. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-181.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove a source class without altering business records. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-182"></a>

### Phase 182 — Structured retrieval baseline

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Use existing search and profile tools before adding vectors. Translate natural language into validated filters, then return authorized structured candidates. Keep phone, price, badge, identity, and availability facts sourced from live records rather than generated prose.

**Acceptance and verification:** Cards contain only eligible providers returned by deterministic tools. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-182.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use ordinary search directly. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-183"></a>

### Phase 183 — Approved help ingestion

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Version reviewed FAQs and product guidance with stable source IDs and effective dates. Validate ownership, audience, and language during ingestion. Reject drafts and outdated policies so retrieval cannot answer deletion or verification questions using superseded requirements.

**Acceptance and verification:** An approved content change produces an attributable index revision. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-183.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior approved document set. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-184"></a>

### Phase 184 — Coherent chunking

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Split knowledge by meaningful sections with titles, source links, language, and revision intact. Keep exceptions beside rules and avoid combining permission scopes. Measure actual support-question retrieval before fixing chunk length and overlap as permanent settings.

**Acceptance and verification:** Deletion and verification answers retrieve complete applicable explanations. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-184.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Rebuild with the prior chunking strategy. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-185"></a>

### Phase 185 — Embedding adoption decision

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Compare a limited semantic prototype with lexical retrieval on held-out multilingual tasks. Measure relevance gains, false matches, latency, cost, update work, and privacy impact. Keep vectors optional: no demonstrated value means documenting the decision to retain simpler retrieval.

**Acceptance and verification:** The decision includes measured benefits and a concrete disable path. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-185.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove the prototype index, preserving baseline tools. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-186"></a>

### Phase 186 — Embedding version contracts

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

If adopted, store embedding model identity, dimension, normalization, and version with indexed content. Plan reindexing without mixing incompatible vector spaces. Assess embedding-provider data terms independently and avoid a model switch that leaves partial or silently stale coverage.

**Acceptance and verification:** Incompatible vectors cannot be queried as if they shared one space. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-186.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Switch to a fully populated prior index. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-187"></a>

### Phase 187 — Permission-scoped index

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Enforce audience, owner, and environment boundaries in trusted queries before any chunks reach the model. Do not mix private drafts into an unrestricted public vector store. Test similarity endpoints directly, including guessed document identifiers and owner changes.

**Acceptance and verification:** Guests and other owners retrieve zero forbidden chunks. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-187.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable private retrieval pending isolation repair. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-188"></a>

### Phase 188 — Measured hybrid search

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Combine lexical and semantic candidates only after access and eligibility filtering. Tune the merge against labeled cases and preserve exact locality/name matches. Keep evidence showing why each candidate entered the set and avoid arbitrary unreviewed weights.

**Acceptance and verification:** Hybrid retrieval improves declared tasks without extra stale or unauthorized results. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-188.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to lexical retrieval. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-189"></a>

### Phase 189 — Reranking experiment

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Test whether reranking provides useful improvement within latency and token budgets. Bound candidate counts and external text exposure, carrying permission metadata throughout. A reranker cannot reintroduce excluded listings or turn low evidence into a stronger trust claim.

**Acceptance and verification:** Measured quality improves without permission or freshness regression. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-189.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove reranking and keep first-stage ordering. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-190"></a>

### Phase 190 — Live business-fact hydration

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Re-fetch selected providers' publication, consent, hours, prices, and evidence immediately before rendering actionable cards. Treat indexed text as contextual, not authoritative for revocable facts. Handle a provider being suspended between candidate retrieval and final display.

**Acceptance and verification:** A mid-response suspension prevents the provider from becoming actionable. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-190.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Drop stale candidates and offer fresh search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-191"></a>

### Phase 191 — Supported citations

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Attach validated source IDs and revisions to factual response segments. Link to accessible public pages or authorized owner content and check that the cited material supports the claim. A plausible URL is not enough; invented or irrelevant citations must fail validation.

**Acceptance and verification:** Audited claims have real supporting sources accessible to the intended user. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-191.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Suppress unsupported text and show verified records. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-192"></a>

### Phase 192 — Evidence sufficiency and abstention

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Define rules for clarifying, acknowledging uncertainty, and declining unsupported claims. Use task requirements and retrieval coverage rather than presenting model confidence as calibrated probability. Cover missing prices, unreviewed credentials, unknown availability, and unsupported areas.

**Acceptance and verification:** Low evidence yields honest limitations instead of invented facts. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-192.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use approved uncertainty wording and manual search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-193"></a>

### Phase 193 — Incremental index updates

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Track approved source changes with idempotent processing, retry bounds, lag metrics, and periodic reconciliation. Avoid silently stale records after missed events. Separate ingest failure from source deletion and provide a repair command for a specific source class.

**Acceptance and verification:** Duplicate events do not duplicate chunks and lag stays within the agreed bound. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-193.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Rebuild from authoritative sources. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-194"></a>

### Phase 194 — Revocation and deletion propagation

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Exclude withdrawn consent, suspended profiles, deleted accounts, and superseded documents immediately through eligibility checks. Use tombstones until asynchronous physical cleanup finishes. Verify provider-managed stores separately and include retrieval caches and conversation references in lifecycle tests.

**Acceptance and verification:** Revoked sources cannot be retrieved and physical cleanup meets its declared SLA. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-194.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the affected index until reconciled. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-195"></a>

### Phase 195 — Multilingual retrieval parity

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Evaluate English, Hindi, Marathi, and reviewed Romanized inputs using equivalent intent tasks. Preserve original names and label translations. Investigate language-specific misses with native speakers instead of claiming equal quality from one aggregate score.

**Acceptance and verification:** Each enabled language meets its own relevance and citation thresholds. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-195.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use localized structured search for weak paths. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-196"></a>

### Phase 196 — Source integrity and poisoning

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Restrict ingestion to authorized editors and approved source types with hashes, provenance, and review history. Flag suspicious instruction-like content for inspection without treating a classifier as proof of safety. Provider text must never overwrite global policies or another owner's content.

**Acceptance and verification:** Editing a public biography cannot replace help policy or private knowledge. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-196.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Quarantine the changed source revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-197"></a>

### Phase 197 — Bounded context assembly

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Assemble only necessary authorized chunks with labels, locale, and freshness. Reserve response budget and truncate conversation history deliberately. Do not concatenate complete profiles by default or drop permission/source metadata when a context window becomes full.

**Acceptance and verification:** Long sessions remain bounded without losing critical restrictions or attribution. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-197.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reduce candidates and provide a shorter grounded answer. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-198"></a>

### Phase 198 — Scope-aware retrieval cache

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Key caches by source revision, audience, owner where needed, locale, and relevant configuration. Do not place raw private prompts in shared cache keys. Invalidate on access loss, source withdrawal, and consent changes before enabling performance shortcuts.

**Acceptance and verification:** Identical questions cannot share private context across accounts. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-198.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable caching and fetch fresh authorized content. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-199"></a>

### Phase 199 — Retrieval quality dashboard

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Track supported-claim rate, citation correctness, relevance, abstention, stale exposure, language gaps, and latency. Show sample sizes and distinguish offline benchmarks from live feedback. Attribute changes to source/configuration revisions and make critical regressions block rollout.

**Acceptance and verification:** Injected stale-source or broken-citation fixtures affect the correct gate. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-199.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the last evaluated pipeline. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-200"></a>

### Phase 200 — Knowledge readiness gate

**Status:** Not started. **Suggested owner:** Retrieval and data engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot.

**Prerequisites:** [013](#phase-013), [040](#phase-040), [101](#phase-101), [180](#phase-180), [181](#phase-181), [182](#phase-182), [183](#phase-183), [184](#phase-184), [185](#phase-185), [186](#phase-186), [187](#phase-187), [188](#phase-188), [189](#phase-189), [190](#phase-190), [191](#phase-191), [192](#phase-192), [193](#phase-193), [194](#phase-194), [195](#phase-195), [196](#phase-196), [197](#phase-197), [198](#phase-198), [199](#phase-199) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `backend/supabase/functions/saathi-ai/` (new), `backend/supabase/migrations/`, `backend/ai-evals/` (new), `docs/ai/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Ground responses in approved knowledge and live structured data. Permissions apply before model exposure, and revocable business facts must be revalidated against authoritative records. Semantic retrieval is conditional on measured improvement over a simple baseline.

Run held-out, malicious-source, live hydration, and deletion cases in staging. Review representative answers with language/domain reviewers. Confirm ownership, freshness alerts, repair commands, and index-retention decisions before enabling customer retrieval.

**Acceptance and verification:** No forbidden source reaches the model and factual claims have adequate support. Evaluate source relevance, citation support, abstention, freshness, and cross-owner isolation on held-out cases. Measure deletion and consent-revocation behavior across indexes and caches, not just source tables.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-200.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Launch only deterministic tools and approved FAQs if vectors remain uncertain. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 11 — AI experience and evaluation

**Phases:** 201–220. **Lead:** AI experience and evaluation engineer. **Entry dependencies:** phase 080, phase 140, phase 180, phase 200. **Release class:** AI pilot; voice/photo separately optional.

<a id="phase-201"></a>

### Phase 201 — Assistant entry and data-use explanation

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Add optional AI entry points from search/help with concise capability and data-use wording. Keep manual search easy to reach and do not send existing private drafts merely because the assistant opens. Preserve current locale and disclose when external model processing occurs.

**Acceptance and verification:** Users understand the assistant's role and can proceed without AI. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-201.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable entry flags without affecting discovery. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-202"></a>

### Phase 202 — Useful intent clarification

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Map everyday problems to candidate categories, locality, and relevant constraints. Ask one useful question when ambiguity changes results; avoid a long interview for a clear query. Route healthcare and hazardous situations through the approved boundary policy.

**Acceptance and verification:** Clear queries reach results quickly and ambiguous ones ask relevant questions. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-202.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Offer deterministic category suggestions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-203"></a>

### Phase 203 — Verified provider cards

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Render recommendations from validated IDs and freshly hydrated public data. Show category/area fit, languages, freshness, evidence, and sponsorship clearly. Do not display model-invented phone numbers, ratings, prices, guarantees, or relationships as actionable facts.

**Acceptance and verification:** Every card matches a currently eligible database record. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-203.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Replace narration with ordinary search results. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-204"></a>

### Phase 204 — Grounded comparison dialogue

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Compare selected providers using available structured facts and approved descriptions. Mark unknown prices/credentials explicitly and ask about user priorities before suggesting preference. Paid placement must not quietly become an explanation of organic superiority or trustworthiness.

**Acceptance and verification:** Comparison claims map to evidence and missing facts remain visible. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-204.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the standard comparison table. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-205"></a>

### Phase 205 — Editable customer service brief

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Convert a user's description into a concise draft with rough area, category, preferred timing, and useful non-sensitive details. Keep exact address optional and local until explicitly shared. Show the complete outgoing text and allow every field to be edited.

**Acceptance and verification:** No brief is sent automatically or hides personal fields from preview. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-205.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep an unsent local draft or discard it. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-206"></a>

### Phase 206 — Natural local-language responses

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Define concise English/Hindi/Marathi wording with familiar trade terms and preserved proper names. Avoid unnecessary mixed-language output or formal literal translations. Use native-speaker review and ensure user-selected language survives provider results and errors.

**Acceptance and verification:** Reviewers approve core flows and users understand the generated guidance. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-206.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use localized cards with minimal prose. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-207"></a>

### Phase 207 — Accessible streaming and cancellation

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Enable streaming only if it improves measured use. Announce progress without reading every token, provide Stop, and withhold actionable content until validation. Preserve valid cards after interrupted narration and avoid duplicate requests during reconnection.

**Acceptance and verification:** Cancellation stops updates and assistive technology remains usable. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-207.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use non-streaming responses. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-208"></a>

### Phase 208 — Conversation correction and reset

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Expose active locality/category/language constraints and let users correct them deliberately. Invalidate candidates when constraints change. Clear context on reset and shared-device transitions instead of carrying an earlier household's details into a new conversation.

**Acceptance and verification:** Changing area refreshes results and reset removes old request context. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-208.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Start a clean session. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-209"></a>

### Phase 209 — Optional voice-input prototype

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Require explicit microphone permission, show a correctable transcript, and retain a complete text path. Evaluate Hindi/Marathi transcription before rollout. Minimize raw-audio retention, prevent background recording, and keep this modality disabled if processor terms or quality remain unresolved.

**Acceptance and verification:** Denied permission and bad transcription have usable fallbacks and declared retention. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-209.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable voice, preserving typed assistance. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-210"></a>

### Phase 210 — Optional photo-input prototype

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [100](#phase-100), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Use opt-in images only to help describe visible objects/issues, avoiding hazardous repair instructions or medical diagnosis. Strip metadata, minimize retention, and require confirmation of inferred categories. Explain visible personal information before upload; never dispatch or contact autonomously.

**Acceptance and verification:** Private/uncertain/unsupported images produce controlled, truthful responses. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-210.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove photo input, keeping text clarification. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-211"></a>

### Phase 211 — Provider biography draft assistance

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Rewrite only the authenticated provider's own description for clarity or translation. Preserve facts and flag unsupported qualifications, years, guarantees, or prices. Present a diff and require ordinary editor confirmation before publication; generated copy never grants verification.

**Acceptance and verification:** Drafts add no unsupported credential and cannot publish automatically. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-211.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Discard the draft and retain current text. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-212"></a>

### Phase 212 — Listing-completeness assistant

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Explain actual server publication failures and useful optional improvements. Suggest specific service-area or hours fixes without encouraging exaggerated claims or irrelevant photos. Keep paid placement and credential approval outside owner-controlled completion tasks.

**Acceptance and verification:** Advice matches current validation and never suggests bypassing review. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-212.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Show the deterministic publication checklist. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-213"></a>

### Phase 213 — Reviewed customer message drafts

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201), [205](#phase-205) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Prepare a first-contact message from the approved brief and chosen provider. Omit exact addresses and sensitive medical details by default. Display recipient and full content, then use the normal external handoff; record intent, not delivery.

**Acceptance and verification:** Nothing leaves the app until the explicit contact action. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-213.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain an editable unsent draft. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-214"></a>

### Phase 214 — AI feedback review workflow

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Collect optional usefulness reasons such as wrong area, unclear language, stale listing, or unsafe answer. Ask before attaching conversation excerpts and route serious issues to restricted reviewers. Feedback must not become a public score or expose customer sessions to providers.

**Acceptance and verification:** Feedback is traceable with minimal authorized context. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-214.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Store only response ID and selected reason. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-215"></a>

### Phase 215 — Golden and held-out evaluations

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Create representative tasks with expected tool outcomes, supported-answer properties, and forbidden claims. Include code-switching, rare localities, no results, revoked consent, owner-private data, and healthcare. Keep release holdouts separate from prompts/examples used while tuning.

**Acceptance and verification:** Configurations are compared reproducibly on unseen cases. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-215.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the last approved configuration baseline. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-216"></a>

### Phase 216 — Adversarial end-to-end evaluations

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Test indirect injection, false source IDs, forged identity, cross-owner requests, malicious URLs, excessive tokens, and attempted contact/deletion. Observe actual tool execution, data flow, and side effects rather than counting refusal phrases as safety evidence.

**Acceptance and verification:** No critical case yields unauthorized information or action. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-216.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable vulnerable tools or sources. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-217"></a>

### Phase 217 — Human quality rubric

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Define usefulness, grounding, language, brevity, trust accuracy, and uncertainty criteria. Use multiple reviewers for sensitive or disputed samples and document adjudication. Model-based grading may assist but cannot be the only release authority for safety and language quality.

**Acceptance and verification:** Reviewers classify important failures consistently with acceptable agreement. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-217.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hold expansion while rubric ambiguity is resolved. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-218"></a>

### Phase 218 — Value and latency experiment

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Compare AI-assisted discovery with ordinary search for task completion, time, comprehension, and cost using consented cohorts. Predeclare success and harm thresholds and report sample sizes. Do not optimize longer conversations as a proxy for usefulness.

**Acceptance and verification:** The assistant provides measurable benefit without unacceptable safety, abandonment, or cost regressions. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-218.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return the entry point to ordinary search. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-219"></a>

### Phase 219 — Controlled assistant rollout

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Move from internal users to a small consented Mumbai cohort through server flags. Monitor unsupported claims, language gaps, latency, spending, and fallback frequency. Define pause triggers and staffed review before widening access; keep unproven modalities disabled.

**Acceptance and verification:** Each cohort expansion has recorded evidence and a tested immediate disable action. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-219.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Route all requests to deterministic discovery. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-220"></a>

### Phase 220 — AI experience gate

**Status:** Not started. **Suggested owner:** AI experience and evaluation engineer. **Effort:** 3–6 focused hours. **Release class:** AI pilot; voice/photo separately optional.

**Prerequisites:** [080](#phase-080), [140](#phase-140), [180](#phase-180), [200](#phase-200), [201](#phase-201), [202](#phase-202), [203](#phase-203), [204](#phase-204), [205](#phase-205), [206](#phase-206), [207](#phase-207), [208](#phase-208), [209](#phase-209), [210](#phase-210), [211](#phase-211), [212](#phase-212), [213](#phase-213), [214](#phase-214), [215](#phase-215), [216](#phase-216), [217](#phase-217), [218](#phase-218), [219](#phase-219) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/assistant/` (new), `lib/domain/repositories/ai_repository.dart` (new), `backend/ai-evals/` (new), `website/src/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Make Saathi AI an optional useful extension of discovery with verified cards and user control. Distinguish generated suggestions, provider claims, and checked evidence. Never let conversational fluency conceal missing facts or unsupported actions.

Review held-out scores, human judgments, isolation, deletion, outage response, and observed benefit. Publish accurate capability wording and known limitations. Approve text separately from voice/photo or weaker languages rather than using aggregate success to enable every feature.

**Acceptance and verification:** Enabled capabilities meet their own thresholds with no unresolved critical privacy/action failure. Combine deterministic fake-model UI checks with held-out model evaluations and native-language review. Evaluate actual tool behavior and private-data exposure, not merely whether responses sound reassuring.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-220.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Ship only the bounded validated experience. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 12 — Distinctive product experiments

**Phases:** 221–240. **Lead:** Product experiment engineer. **Entry dependencies:** phase 010, phase 080, phase 100, phase 120, phase 140. **Release class:** Optional experiment; default off.

<a id="phase-221"></a>

### Phase 221 — Listing trust receipt

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Show what was checked, the evidence category, review date, and remaining provider-declared claims. Explain scope in plain language instead of adding a mysterious trust score. Test whether users better distinguish phone control, listing review, and professional credentials.

**Acceptance and verification:** Comprehension improves without creating unsupported safety guarantees. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-221.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide receipts while retaining accurate badges. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-222"></a>

### Phase 222 — Expiring availability promise

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Offer short provider-confirmed availability windows, visible age, and automatic unknown state on expiry. Make busy periods and quiet hours easy to set. Test reduced wasted contacts against the effort required to maintain freshness, avoiding pressure to appear constantly online.

**Acceptance and verification:** Freshness helps customers without excessive provider update burden. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-222.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to ordinary hours with no live claim. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-223"></a>

### Phase 223 — Problem-to-trade atlas

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Build reviewed mappings from everyday household problems to plausible trades using local phrases and minimal clarifications. Show multiple categories when uncertain and handle hazards safely. Never describe a likely trade match as a technical diagnosis or repair guarantee.

**Acceptance and verification:** Users choose appropriate categories faster on unseen scenarios. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-223.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the standard category browser. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-224"></a>

### Phase 224 — Monsoon readiness collection

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Create reviewed seasonal checklists for drainage, waterproofing, appliance care, and relevant safety inspections. Link tasks to eligible service categories without inventing forecasts or prevention guarantees. Keep sponsored positions explicit and avoid fear-based wording.

**Acceptance and verification:** Users understand actionable preparation and find relevant services. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-224.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Unpublish the seasonal collection. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-225"></a>

### Phase 225 — Itemized quote preparation

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Help customers ask about visit fees, labor, materials, scope, exclusions, and warranty terms. Avoid made-up local price ranges. Later numerical guidance requires provenance, sample/date context, and uncertainty; start with a useful estimate checklist.

**Acceptance and verification:** Users recognize missing quote components in moderated tasks. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-225.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep questions and remove unsupported numeric guidance. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-226"></a>

### Phase 226 — Reusable service-brief passport

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Store an editable brief locally with optional images, timing, language, and constraints. Share selected fields per recipient with a full preview and exact-address removal. Avoid creating a hidden permanent server household profile for a simple sharing convenience.

**Acceptance and verification:** Recipients receive only selected fields and nothing is sent silently. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-226.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Delete the brief and expire any share token. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-227"></a>

### Phase 227 — Household maintenance notebook

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Prototype device-local appliance names, service dates, optional receipts, and manually confirmed outcomes. Explain export and erasure; secure cloud backup needs separate explicit design and consent. Do not infer completed jobs from contact taps or upload documents by default.

**Acceptance and verification:** Users can record, export, and erase without hidden data transfer. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-227.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return to bookmarks with a readable export. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-228"></a>

### Phase 228 — Care-circle shortlist sharing

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Let someone prepare an expiring provider shortlist for a family member. Keep relationship and household details private and let the recipient choose contact actions. Avoid tracking whether a person called, sharing their phone number, or silently granting sender control.

**Acceptance and verification:** Recipients browse without registering and retain contact privacy. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-228.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Expire shared lists while preserving personal bookmarks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-229"></a>

### Phase 229 — Apartment service-day interest

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Prototype opt-in aggregate interest for a building's service need without publishing unit numbers or resident phone lists. An organizer reviews what providers receive. Keep actual scheduling, deposits, and payments outside the prototype unless separately specified and authorized.

**Acceptance and verification:** A pilot reduces coordination effort without exposing nonparticipants. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-229.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Close the board and erase temporary participation data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-230"></a>

### Phase 230 — Small-job bundle brief

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Help customers describe multiple small tasks and find providers whose declared services fit. Explain that scope and pricing require direct agreement. Do not favor broad category stuffing or imply one provider is qualified for unrelated tasks merely because they checked many categories.

**Acceptance and verification:** Qualified contacts improve without worse category mismatch. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-230.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Split the brief into ordinary service searches. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-231"></a>

### Phase 231 — Fair newcomer exposure

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Try a transparent exploration slot for eligible new providers with adequate profiles. Preserve relevance and trust gates and prevent repeated registration from gaming eligibility. Measure exposure gains alongside customer task success rather than guaranteeing equal placement regardless of fit.

**Acceptance and verification:** Useful newcomer exposure rises without material relevance or abuse harm. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-231.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the exploration slot. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-232"></a>

### Phase 232 — Portable provider passport

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Generate a shareable public profile card/QR linking to the live canonical listing. Show current approved contact, service coverage, languages, and evidence explanations. Printed cards must not freeze old credential claims; the link needs suspension/deletion handling.

**Acceptance and verification:** Scans resolve current eligible facts and reveal no owner-private data. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-232.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the share link. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-233"></a>

### Phase 233 — Plain-language estimate explanation

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [220](#phase-220), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Rewrite a user-supplied estimate while preserving every amount, condition, and uncertainty beside the original. Strip unnecessary personal data before model processing and avoid legal/technical assurances. Require review, and flag ambiguity rather than inventing missing terms.

**Acceptance and verification:** Reviewed examples retain amounts and exclusions exactly. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-233.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Show the original with an itemization checklist. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-234"></a>

### Phase 234 — Quiet contact preferences

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Let providers state preferred contact windows, text preference, and language without collecting message history. Explain preferences in existing contact controls and preserve deliberate customer action. Do not schedule autonomous later calls or messages on behalf of either party.

**Acceptance and verification:** Providers report fewer unwanted interruptions without confusing customers. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-234.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove hints, preserving eligibility controls. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-235"></a>

### Phase 235 — Accessibility-aware service fit

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Allow voluntary self-reported accommodations such as text-first contact or step-free premises. Label provenance clearly and consult affected users on wording. Do not infer customer disability, diagnose needs, or claim independent accessibility verification where none exists.

**Acceptance and verification:** Users find relevant accommodations without disclosing sensitive diagnoses. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-235.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide unreliable filters and retain factual descriptions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-236"></a>

### Phase 236 — Supply-gap observatory

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Aggregate insufficient-result signals by coarse category/locality for operations and consenting providers. Suppress small cells and sensitive healthcare detail; never disclose raw household queries. Test whether the insight improves targeted supply recruitment rather than producing an unused dashboard.

**Acceptance and verification:** Displayed aggregates meet privacy thresholds and inform useful decisions. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-236.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restrict the report to internal coarse analysis. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-237"></a>

### Phase 237 — Community correction proposals

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Accept structured suggestions about outdated contact, wrong area, duplicates, and misleading claims. Keep edits moderated, protect reporters, and resist coordinated harassment. Give owners actionable corrections without letting unverified community input directly rewrite public facts.

**Acceptance and verification:** Validated suggestions improve accuracy and malicious reports cannot directly alter listings. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-237.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause suggestions, preserving normal reporting. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-238"></a>

### Phase 238 — Opt-in local partner kit

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Prepare truthful referral materials for associations, training centers, and local shops with tagged links. Explain attribution and any compensation separately from trust/eligibility. Do not send outreach or publish partner endorsements without explicit authorization and an approved fact record.

**Acceptance and verification:** The kit is ready for a limited consented trial with clear measurement. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-238.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Deactivate referral codes without affecting accounts. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-239"></a>

### Phase 239 — Low-data neighborhood pack

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Offer an optional small offline package of guidance and recent public summaries with download size, age, and easy removal. Avoid revocable private/contact data that cannot be safely refreshed. Distinguish cached content from current eligibility and availability.

**Acceptance and verification:** Poor-connectivity users gain useful navigation without misleading live claims. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-239.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Remove packs and return to normal caching. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-240"></a>

### Phase 240 — Experiment portfolio decision

**Status:** Not started. **Suggested owner:** Product experiment engineer. **Effort:** 3–6 focused hours. **Release class:** Optional experiment; default off.

**Prerequisites:** [010](#phase-010), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [221](#phase-221), [222](#phase-222), [223](#phase-223), [224](#phase-224), [225](#phase-225), [226](#phase-226), [227](#phase-227), [228](#phase-228), [229](#phase-229), [230](#phase-230), [231](#phase-231), [232](#phase-232), [233](#phase-233), [234](#phase-234), [235](#phase-235), [236](#phase-236), [237](#phase-237), [238](#phase-238), [239](#phase-239) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `lib/features/` (feature-specific additions), `backend/supabase/migrations/`, `backend/supabase/functions/`, `docs/experiments/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prototype LocalSaathi-specific improvements that solve real local-service problems. Each feature gets an independent flag and a falsifiable hypothesis; do not make every idea permanent or delay essential launch work just to increase feature count.

Compare prototypes by customer benefit, provider effort, privacy, support load, cost, and evidence quality. Select only a few for investment and explicitly archive failed or redundant concepts. Document why each continues; feature-count growth is not a success measure.

**Acceptance and verification:** Every experiment has an evidence-backed continue, revise, or remove decision. Document hypothesis, smallest cohort, success metric, privacy impact, operating burden, and stop condition. Use consented evidence and choose continue/revise/remove; favorable anecdotes alone do not justify broad rollout.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-240.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable unsuccessful flags and plan reviewed cleanup. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 13 — Administration, privacy, moderation, and commercial readiness

**Phases:** 241–260. **Lead:** Operations platform and privacy engineer. **Entry dependencies:** phase 012, phase 013, phase 035, phase 036, phase 040, phase 060. **Release class:** Core operations; paid features conditional.

<a id="phase-241"></a>

### Phase 241 — Protected administration foundation

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Create the smallest usable admin surface with secure authentication, environment labeling, and read-only defaults. Reuse backend authorization rather than embedding service keys in the browser. Provide production warnings based on actual environment, safe navigation, and session expiry behavior.

**Acceptance and verification:** A provider or guest cannot reach admin data through UI or direct endpoints. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-241.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the admin surface while retaining audited backend recovery. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-242"></a>

### Phase 242 — Role and permission matrix

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Implement distinct support, moderation, credential, privacy, and infrastructure permissions. Define who may view sensitive evidence, export, change roles, or approve claims. Require attributable accounts, appropriate MFA, and periodic review; prevent self-granting or client-metadata privilege changes.

**Acceptance and verification:** Each role passes allowed/denied action tests and cannot elevate itself. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-242.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke suspect roles and active sessions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-243"></a>

### Phase 243 — Moderation queue and triage

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Build queues for reports, suspicious listings, rejected media, and impersonation cases with severity, assignment, deadlines, and duplicate linking. Separate safety urgency from popularity or paid status. Prevent concurrent operators from silently overwriting decisions.

**Acceptance and verification:** Cases have a responsible reviewer and deterministic transitions with audit events. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-243.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Return cases to an unassigned review state. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-244"></a>

### Phase 244 — Private report evidence handling

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Limit report visibility, redact unnecessary personal data, and separate reporter identity from provider-visible explanations. Protect attachments and exports, log sensitive access, and define evidence expiry. Do not expose internal abuse-detection details that enable retaliation or evasion.

**Acceptance and verification:** Providers cannot discover reporters and unauthorized staff cannot retrieve private attachments. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-244.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restrict the case to qualified reviewers. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-245"></a>

### Phase 245 — Healthcare credential operations

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [089](#phase-089), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Provide reviewers a structured process for checking applicable professional registries, qualification claims, names, and validity. Record source/date and limitations without claiming every category has one universal verification mechanism. Expire badges and escalate mismatches for review rather than automatic accusations.

**Acceptance and verification:** Every approved medical credential has a traceable current review basis. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-245.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide the badge or disable the category pending review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-246"></a>

### Phase 246 — Appeals and reviewer accountability

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Track original decisions, appeals, new evidence, reviewer assignment, and reasons for reversal. Preserve an audit trail while making owner explanations understandable. Avoid letting automation close disputes without examination and restrict sensitive reviewer information from public surfaces.

**Acceptance and verification:** A credible appeal can be reviewed independently and corrected visibly. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-246.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Suspend the disputed automation while reviewed. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-247"></a>

### Phase 247 — Privacy inventory and processor register

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Document collected fields, purposes, access, processors, transfers, retention, deletion, and legal basis as determined by qualified review. Include SMS, AI, hosting, analytics, storage, and support systems. Match inventory to network behavior and database schema, not just a boilerplate policy.

**Acceptance and verification:** Every personal-data store and external flow has a named purpose and owner. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-247.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable unapproved data flows. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-248"></a>

### Phase 248 — Legal version and consent records

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Replace placeholders with verified operator information and reviewed text. Record versioned consent for publication, contact display, optional AI processing, and other justified choices. Distinguish mandatory terms from optional permission; withdrawing optional consent must have real functional effect.

**Acceptance and verification:** Displayed wording and stored versions match, with tested grant/withdraw behavior. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-248.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain the prior approved wording or pause affected collection. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-249"></a>

### Phase 249 — Data-access and export requests

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Build identity-verified requests for the caller's data with scoped collection, safe delivery, expiry, and audit. Exclude another user's private reports or internal secrets while explaining justified omissions. Define how support handles incomplete or disputed identity without exposing account existence.

**Acceptance and verification:** Exports contain only the requester-authorized scope and links expire. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-249.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Cancel delivery and revoke export access. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-250"></a>

### Phase 250 — End-to-end deletion orchestration

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [057](#phase-057), [060](#phase-060), [095](#phase-095), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Implement a durable deletion job spanning auth, profiles, blobs, caches, AI state, indexes, and processors. Support retries, progress, partial failure, and final reconciliation. Preserve only justified minimal retained records and make re-registration semantics explicit after deletion completes.

**Acceptance and verification:** A synthetic account disappears from every required system and retries are safe. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-250.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause before irreversible steps when prerequisites fail. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-251"></a>

### Phase 251 — Retention enforcement and holds

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Translate approved retention decisions into scheduled cleanup, dry-run reports, exception review, and narrowly controlled legal holds. A hold must have authority, scope, expiry/review, and restricted access. Do not use hypothetical compliance as a reason to retain all data forever.

**Acceptance and verification:** Expired eligible data is removed and holds neither overreach nor silently persist. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-251.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable faulty cleanup and investigate exact affected records. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-252"></a>

### Phase 252 — Age and sensitive-category policy

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Determine target audience and applicable child/sensitive-data requirements with legal and product review. Prefer data minimization over collecting birth dates unnecessarily. Define handling of minors, tutoring, healthcare discovery, and prohibited content based on actual supported services and release regions.

**Acceptance and verification:** The chosen policy is reflected in UX, moderation, disclosures, and tests. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-252.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable categories or collection that lacks an approved treatment. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-253"></a>

### Phase 253 — Incident and notification decision process

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Define triage for unauthorized disclosure, account compromise, harmful content, and processor incidents. Map applicable notification duties and timelines using current law and contracts with qualified reviewers. Prepare evidence preservation and draft templates without automatically notifying outside parties.

**Acceptance and verification:** A tabletop exercise identifies the incident owner, facts needed, escalation, and approval route. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-253.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Contain exposure and preserve minimal relevant evidence. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-254"></a>

### Phase 254 — Support and abuse operating procedures

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Create task-based playbooks for contact problems, recovery, impersonation, urgent reports, deletion, and AI mistakes. Give support only necessary access and prohibit requesting OTPs or passwords. Define escalation coverage and honest response expectations for the staffed launch window.

**Acceptance and verification:** A support operator resolves representative cases without unsafe access or secret collection. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-254.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Escalate to the appropriate restricted specialist. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-255"></a>

### Phase 255 — Notification preference foundation

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Define channels, purposes, consent, quiet hours, localization, and unsubscribe behavior before adding reminders. Separate operational/security notices from marketing. Avoid exposing sensitive details on lock screens or sending unsolicited provider/customer messages through automation.

**Acceptance and verification:** Opt-out and quiet-hour tests work; confidential content stays out of previews. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-255.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable optional notifications independently. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-256"></a>

### Phase 256 — Commercial model and policy decision

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Compare subscription, sponsored placement, and other candidate models against actual customer value, current store/payment rules, and operating costs. Keep trust and organic eligibility independent of payment. Record billing-provider/account prerequisites and avoid enabling purchases before policy and support readiness.

**Acceptance and verification:** A reviewed commercial specification identifies obligations, costs, exclusions, and a clear non-paid path. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-256.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep monetization informational and purchases disabled. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-257"></a>

### Phase 257 — Server-owned entitlements

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241), [256](#phase-256) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

If subscriptions are approved, implement server-authoritative plans, periods, limits, and status transitions. Handle grace, expiry, cancellation, and existing data above a reduced limit without destructive surprises. Never trust a client boolean, screenshot, or unsigned callback as purchase evidence.

**Acceptance and verification:** Forged client state cannot grant benefits and downgrade behavior preserves user data. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-257.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable new purchases while honoring verified existing entitlements. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-258"></a>

### Phase 258 — Payment webhook verification

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241), [257](#phase-257) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

For the approved provider, verify signatures, timestamps, replay protection, idempotency, and event ordering. Reconcile events with server-side provider records before altering entitlements. Keep secrets out of logs and cover delayed, duplicate, and conflicting messages.

**Acceptance and verification:** Replay and forged events do not change entitlements; reconciliation resolves missed delivery. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-258.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause entitlement changes and reconcile from authoritative records. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-259"></a>

### Phase 259 — Cancellation, refunds, and records

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241), [258](#phase-258) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Implement reviewed cancellation/refund flows, purchase history, invoices or receipts as applicable, and support escalation. Use current platform rules and qualified tax/legal decisions for regional requirements. Explain effective dates and avoid hidden renewal or cancellation friction.

**Acceptance and verification:** Customers understand charges and can exercise supported cancellation/refund paths with audited outcomes. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-259.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Suspend purchases if required lifecycle functions fail. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-260"></a>

### Phase 260 — Operations readiness gate

**Status:** Not started. **Suggested owner:** Operations platform and privacy engineer. **Effort:** 3–6 focused hours. **Release class:** Core operations; paid features conditional.

**Prerequisites:** [012](#phase-012), [013](#phase-013), [035](#phase-035), [036](#phase-036), [040](#phase-040), [060](#phase-060), [241](#phase-241), [242](#phase-242), [243](#phase-243), [244](#phase-244), [245](#phase-245), [246](#phase-246), [247](#phase-247), [248](#phase-248), [249](#phase-249), [250](#phase-250), [251](#phase-251), [252](#phase-252), [253](#phase-253), [254](#phase-254), [255](#phase-255), [256](#phase-256), [257](#phase-257), [258](#phase-258), [259](#phase-259) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `website/` (new protected admin area or separate reviewed admin app), `backend/supabase/functions/`, `backend/supabase/migrations/`, `lib/features/account/`, `docs/operations/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Give real operators safe tools and executable lifecycle procedures. Enforce least privilege and auditability; policy text must reflect actual software behavior, staffing, processor arrangements, and qualified legal decisions rather than aspirational compliance claims.

Rehearse moderation, appeals, export, deletion, security incidents, and support with the actual team. Verify roles, coverage, contacts, legal versions, and processor inventory. Paid features pass their own evidence gate or remain fully disabled; operational readiness cannot be a document alone.

**Acceptance and verification:** Operators complete realistic cases and all launch-critical workflows have accountable owners. Test with separate support, moderator, credential-review, and admin identities. Use synthetic personal records for exports/deletion, and treat legal/payment applicability as a documented external decision rather than an engineer's certification.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-260.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Limit launch scope to workflows the team can safely operate. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 14 — DevSecOps, reliability, and recovery

**Phases:** 261–280. **Lead:** Release, reliability, and security engineer. **Entry dependencies:** phase 007, phase 011, phase 012, phase 016, phase 020. **Release class:** Core launch.

<a id="phase-261"></a>

### Phase 261 — Version control and recovery baseline

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Establish the intended Git repository/history for this checkout without discarding local improvements. Inventory ignored files and secrets before the first commit or remote push. Define branch, review, and release-tag conventions and an independent backup of valuable uncommitted assets.

**Acceptance and verification:** A recoverable baseline exists and secret files are excluded from publication. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-261.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the original workspace snapshot. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-262"></a>

### Phase 262 — Environment and secret isolation

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Separate development, staging, and production projects, keys, buckets, domains, and CI credentials. Grant minimum privileges, document rotation, and prevent accidental production use from local defaults. Public client keys remain distinct from privileged server secrets and AI/SMS credentials.

**Acceptance and verification:** A staging job cannot mutate production and rotation is rehearsed without leakage. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-262.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke affected credentials and disable dependent jobs. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-263"></a>

### Phase 263 — Flutter continuous integration

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Create deterministic dependency, formatting, analysis, and meaningful test jobs with SDK versions recorded. Cache only safe reproducible artifacts and report failures clearly. Avoid declaring success when tests were skipped or a pipeline ran against a different checkout than the release.

**Acceptance and verification:** A deliberate core regression fails CI and an unchanged clean build is reproducible. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-263.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert the workflow revision while retaining local checks. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-264"></a>

### Phase 264 — Database CI and policy regression

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [040](#phase-040), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Run migrations and pgTAP plus full-stack authorization smoke tests in a disposable environment. Verify every suite actually executes and forbidden-field probes use real restricted roles. Include forward upgrades as well as fresh installs and preserve failure artifacts without secrets.

**Acceptance and verification:** Schema/policy regressions block promotion with attributable failing cases. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-264.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep deployment blocked until the checks are repaired. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-265"></a>

### Phase 265 — Website and AI pipeline checks

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Build the website, check critical links/accessibility contracts, and run fake-model tests on ordinary changes. Run budgeted held-out AI evaluations when prompts, tools, models, or retrieval change. Keep provider outages separate from deterministic code failures.

**Acceptance and verification:** Relevant changes trigger the appropriate gate without uncontrolled model spending. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-265.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pin validated artifacts/configurations pending review. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-266"></a>

### Phase 266 — Dependency and supply-chain review

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Inventory direct/transitive packages, lockfiles, licenses, known vulnerabilities, update policy, and abandoned dependencies. Add secret scanning and scoped static analysis with a triage owner. Pin CI actions sensibly and investigate findings rather than treating a noisy scan as assurance.

**Acceptance and verification:** Critical actionable issues have fixes or approved scope reduction before release. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-266.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert an unsafe update and isolate affected functionality. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-267"></a>

### Phase 267 — Release artifact integrity

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Build immutable identifiable app/web artifacts from reviewed sources and record hashes, versions, dependency inventory, and signing provenance. Scan bundles for credentials, debug endpoints, demo flags, and sensitive test data. Ensure only vetted artifacts can be promoted between environments.

**Acceptance and verification:** The promoted artifact matches reviewed source and contains no forbidden configuration. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-267.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Redeploy the previous verified artifact. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-268"></a>

### Phase 268 — Infrastructure configuration contract

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Record domains, runtime versions, project identifiers, access roles, quotas, headers, backup settings, and feature defaults in reviewable configuration. Use infrastructure-as-code where it reduces drift, not as a mandate to rebuild managed services. Separate secrets from reproducible non-secret settings.

**Acceptance and verification:** A second operator can reproduce staging without undocumented console guesses. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-268.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the previous approved configuration. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-269"></a>

### Phase 269 — Structured logs and trace correlation

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Introduce consistent request IDs and bounded structured errors across app-facing functions, search, deletion, and AI. Redact tokens, phones, messages, evidence URLs, and private coordinates. Define access, retention, sampling, and how client issues correlate without invasive tracking.

**Acceptance and verification:** A failed journey can be investigated without exposing unnecessary personal data. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-269.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable verbose fields while retaining minimal error signals. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-270"></a>

### Phase 270 — Service objectives and alerts

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Choose measurable availability, latency, error, deletion-lag, SMS-failure, and AI-budget objectives. Set actionable thresholds and alert destinations with escalation ownership. Separate expected user validation errors from outages and avoid paging for every harmless retry.

**Acceptance and verification:** A synthetic breach triggers the correct alert with enough safe diagnostic context. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-270.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Mute a noisy rule while retaining alternate incident detection. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-271"></a>

### Phase 271 — Representative load testing

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Model guest browsing, provider edits, uploads, reports, OTP, and AI at expected and stress loads. Use synthetic fixtures, bounded test budgets, and staging targets. Include database connection, storage, and model quotas and document the cost of the test itself.

**Acceptance and verification:** Measured capacity supports the planned cohort and failures degrade predictably. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-271.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Stop generators and restore normal staging quotas. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-272"></a>

### Phase 272 — Connection and query scaling

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Measure database connections, pooling, query saturation, cache effects, and slow endpoints under the recorded workload. Tune the existing managed stack before adding new services. Preserve authorization with any cache and document when larger resources become necessary.

**Acceptance and verification:** Bottlenecks improve without cross-user cache leakage or lost correctness. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-272.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore previous tuning and reduce rollout load. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-273"></a>

### Phase 273 — Backup policy and access

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Choose database, storage, configuration, and secret-recovery strategies based on actual provider capabilities and business impact. Document frequency, encryption, access, retention, region, and costs. Distinguish database backups from objects and ensure recovery material is not kept only on one laptop.

**Acceptance and verification:** All required assets have an owned backup/recovery path with access controls. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-273.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep production launch blocked for uncovered critical assets. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-274"></a>

### Phase 274 — Measured restore drill

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261), [273](#phase-273) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Restore a sanitized representative environment into an isolated destination and verify records, objects, authorization, and application functionality. Measure actual RPO/RTO against the chosen targets. Include account/credential recovery and record steps that still depend on unavailable personnel.

**Acceptance and verification:** A second operator can complete restore and explain any lost interval. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-274.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Leave the original environment intact until restored state is validated. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-275"></a>

### Phase 275 — Dependency-failure exercises

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Simulate SMS rejection, model outage, storage processing delay, database degradation, and broken external launchers. Confirm circuit breakers, retry bounds, queue behavior, and truthful messages. Core search should remain available when optional AI or analytics fail where architecture permits.

**Acceptance and verification:** Failures remain bounded and do not silently substitute demo data or repeat destructive writes. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-275.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the affected optional integration. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-276"></a>

### Phase 276 — Incident playbook rehearsal

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Create and rehearse severity, ownership, containment, evidence preservation, communication approval, recovery, and postmortem steps. Include leaked secrets, OTP spend spikes, provider impersonation, and AI disclosure. Prepare external communications as drafts; execution follows applicable authorization and legal decisions.

**Acceptance and verification:** A tabletop team can find the right owner and perform containment without unsafe improvisation. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-276.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use conservative feature shutdown and preserve necessary evidence. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-277"></a>

### Phase 277 — Independent security verification

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Review the assembled app/API/admin/AI surfaces against selected applicable ASVS and mobile controls. Test broken object authorization, injection, file handling, unsafe redirects, exported components, privilege escalation, and model tool boundaries in staging. Triage exploitability rather than claiming certification from scanner output.

**Acceptance and verification:** No unresolved critical/high exploitable finding remains on the launch path. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-277.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable vulnerable scope and repeat targeted verification. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-278"></a>

### Phase 278 — Backward-compatible release rehearsal

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Run old supported mobile clients against the new backend and new clients against the staged migration sequence. Check feature defaults, enums, schema expansion, and safe failures. Define minimum-version behavior without unnecessarily blocking ordinary guest browsing.

**Acceptance and verification:** A staged upgrade works without corrupting old-client writes or exposing private fields. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-278.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Roll back application code using compatible expanded schema. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-279"></a>

### Phase 279 — Operating cost and quota dashboard

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Reconcile actual SMS, model, storage, egress, compute, and monitoring usage with budgets. Monitor unexpected growth and quota exhaustion with owners and safe limits. Use current provider invoices/metrics rather than stale planning prices and avoid raw personal detail in cost attribution.

**Acceptance and verification:** Stress scenarios trigger caps before unbounded expenditure or preventable outages. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-279.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reduce optional features and pause expansion. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-280"></a>

### Phase 280 — Reliability readiness gate

**Status:** Not started. **Suggested owner:** Release, reliability, and security engineer. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [011](#phase-011), [012](#phase-012), [016](#phase-016), [020](#phase-020), [261](#phase-261), [262](#phase-262), [263](#phase-263), [264](#phase-264), [265](#phase-265), [266](#phase-266), [267](#phase-267), [268](#phase-268), [269](#phase-269), [270](#phase-270), [271](#phase-271), [272](#phase-272), [273](#phase-273), [274](#phase-274), [275](#phase-275), [276](#phase-276), [277](#phase-277), [278](#phase-278), [279](#phase-279) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `.github/workflows/` (new), `backend/scripts/`, `tool/`, `docs/deploy/` (new), `docs/operations/` (new), `android/`, `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Create a reproducible operating system for the app using proportionate managed infrastructure and evidence-based controls. Keep staging and production separate, protect credentials, and test recovery rather than assuming successful builds or backups guarantee readiness.

Review CI evidence, artifacts, secrets, objective alerts, capacity, restores, incidents, security findings, and compatibility. Verify the operating team can execute recovery, not merely locate a document. List unavailable account-dependent checks as blockers rather than marking them passed.

**Acceptance and verification:** The staged release has reproducible build, monitoring, security, and recovery evidence. Exercise the actual deployment mechanisms in isolated environments. Save artifact identities, configuration revisions, timings, and observed outcomes; avoid production load/security tests or paid provisioning without explicit applicable authorization.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-280.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hold production promotion while any critical operational gate fails. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 15 — Android, store, website deployment, and controlled launch

**Phases:** 281–300. **Lead:** Release engineer and launch owner. **Entry dependencies:** phase 007, phase 016, phase 020. **Release class:** Core launch.

<a id="phase-281"></a>

### Phase 281 — Deployment target decision

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Choose compatible hosting for the Astro rendering strategy, Supabase region/projects, AI gateway, and administrative surface. Record domain ownership, operational access, runtime constraints, logs, backups, expected cost, and rollback. Keep alternative hosting out unless the chosen target fails a concrete requirement.

**Acceptance and verification:** A reviewed target contract covers every public and private runtime. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-281.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep local/staging work independent of paid provisioning. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-282"></a>

### Phase 282 — Account and external prerequisite register

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Track domain control, hosting/Supabase accounts, SMS/DLT setup, AI project, Play developer identity, legal contacts, and billing owners. Prepare exact setup instructions and evidence needed. Distinguish unavailable credentials from implementation defects and assign deadlines early.

**Acceptance and verification:** Each external prerequisite has an owner, status, dependency, and next action. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-282.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Leave dependent services disabled until ready. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-283"></a>

### Phase 283 — Reproducible Android toolchain

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Validate the current Flutter, Gradle, Android plugin, Kotlin, Java, SDK, and NDK combination. Rebuild from clean locked inputs and record compatibility rather than repeating obsolete kickoff failures. Fix actual incompatibilities in narrow changes with reproducible output.

**Acceptance and verification:** A clean release candidate builds under the documented toolchain. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-283.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the last working version set. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-284"></a>

### Phase 284 — Android permission and component audit

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Inspect merged manifests, exported activities/providers, intents, network security, backup/data-extraction rules, camera/media permissions, and app links. Remove unnecessary permissions and protect private session/draft data from unintended backup or inter-app exposure. Test denied-permission behavior on supported Android versions.

**Acceptance and verification:** The installed artifact exposes only justified components and recovers from permission denial. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-284.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable affected optional features while retaining minimal permissions. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-285"></a>

### Phase 285 — Production signing and key recovery

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Remove debug-signing fallback for actual production artifacts while preserving a clearly named local build route. Set up protected release/upload keys, Play signing decisions, access controls, rotation/recovery records, and CI secret handling. Never commit keystores or print credentials.

**Acceptance and verification:** An unsigned/misconfigured production build fails and the candidate has the intended certificate. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-285.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Use the previous signed artifact and established key-recovery process. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-286"></a>

### Phase 286 — Native compatibility and shrinker testing

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Verify applicable page-size compatibility, supported ABIs, native libraries, release minification, resource shrinking, and plugin behavior. Exercise image picking, maps, shares, backend calls, and authentication in the optimized artifact, not just debug mode.

**Acceptance and verification:** The release artifact passes required native checks and core plugin journeys. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-286.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert the specific shrinker/plugin change with evidence. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-287"></a>

### Phase 287 — Production configuration guardrails

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Reject production builds with demo OTP, sample data, placeholder domains, unreviewed legal flags, missing backend settings, or privileged client secrets. Check compiled artifacts and runtime wiring, not merely source booleans. Synchronize app/version metadata and environment labels.

**Acceptance and verification:** A deliberately invalid production configuration fails before promotion. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-287.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep staging/demo builds separate and clearly labeled. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-288"></a>

### Phase 288 — Current store assets and listings

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Produce accurate title/descriptions, icon, feature graphic, and screenshots from the final current app. Replace failed/stale captures and validate dimensions and localized copy. Do not show unavailable AI, invented providers as live, fabricated reviews, or guarantees unsupported by the release.

**Acceptance and verification:** Every asset matches enabled behavior and current store constraints. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-288.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain the prior approved listing draft. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-289"></a>

### Phase 289 — Store declarations and policy review

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [247](#phase-247), [248](#phase-248), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Complete applicable data-safety, ads, content-rating, health, access, privacy, and deletion declarations from the actual inventory. Verify current Play requirements and billing implications for enabled features. Check that SDK/network behavior matches statements; do not copy generic answers.

**Acceptance and verification:** A traceable declaration checklist maps every answer to product evidence. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-289.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hold submission when required disclosure is uncertain. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-290"></a>

### Phase 290 — Internal distribution and reviewer journey

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [056](#phase-056), [080](#phase-080), [281](#phase-281), [285](#phase-285), [286](#phase-286), [287](#phase-287) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Distribute the signed candidate through the intended internal route and run fresh-install/update journeys on representative devices. Verify isolated reviewer access without production backdoors. Capture crashes, login failures, deep-link behavior, and account deletion using the exact package proposed for submission.

**Acceptance and verification:** Internal testers and reviewers can exercise required features without accessing real private data. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-290.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Withdraw the candidate and publish a corrected internal build. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-291"></a>

### Phase 291 — Applicable closed testing

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [290](#phase-290) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Determine whether the Play account requires a closed-test qualification period and verify current rules. Recruit eligible testers through authorized outreach, provide realistic tasks, collect feedback, and track continuous participation where required. Do not fake activity or promise approval from elapsed time alone.

**Acceptance and verification:** The actual account's prerequisites and feedback evidence are satisfied before applying for production access. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-291.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Extend testing and fix defects before submission. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-292"></a>

### Phase 292 — Full staging deployment rehearsal

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [080](#phase-080), [100](#phase-100), [120](#phase-120), [140](#phase-140), [160](#phase-160), [260](#phase-260), [280](#phase-280), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Deploy backend migrations/functions, website, storage configuration, and feature defaults to isolated staging in the documented order. Run a complete production-like guest/owner journey and synthetic lifecycle checks. Ensure staging is unindexed and cannot accidentally send production notifications or use production data.

**Acceptance and verification:** A second operator reproduces deployment and identifies each artifact revision. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-292.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the previous staging release. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-293"></a>

### Phase 293 — Domain, TLS, and public routing

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [292](#phase-292) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Configure verified domains, certificates, redirects, canonical origins, app links, allowed callback URLs, security headers, and DNS change plans. Check renewal ownership and expiry alerts. Prepare changes for review before modifying live DNS, including rollback TTL considerations.

**Acceptance and verification:** Approved hostnames serve the intended environment over valid secure transport. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-293.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore prior DNS/routing and certificate configuration. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-294"></a>

### Phase 294 — Real provider pilot data

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [060](#phase-060), [100](#phase-100), [120](#phase-120), [260](#phase-260), [281](#phase-281) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Onboard consenting genuine providers through the normal verified flow and review their public claims. Exclude seeded fictional entries from production and indexing. Verify contact consent, local coverage, hours, evidence, and optional precise location; do not scrape unsolicited personal listings to fill supply.

**Acceptance and verification:** Launch supply is real, consented, eligible, and supported in chosen categories/localities. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-294.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause affected listings while correcting data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-295"></a>

### Phase 295 — Release-candidate go/no-go

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [289](#phase-289), [290](#phase-290), [291](#phase-291), [292](#phase-292), [293](#phase-293), [294](#phase-294) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Assemble exact build hashes, tests, security findings, restore evidence, legal/store disclosures, operational coverage, real-supply checks, and rollback commands. Require named accountable reviewers. Define whether AI and payments are enabled separately; unresolved critical gates produce a no-go rather than a conditional public claim.

**Acceptance and verification:** The release decision identifies scope, evidence, exclusions, owners, and approved exposure. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-295.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the candidate in staging when any critical gate fails. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-296"></a>

### Phase 296 — Backend and website production promotion

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [295](#phase-295) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

After authorization, apply reviewed compatible migrations and function/config versions, then promote the verified website artifact. Use controlled flags and run restricted synthetic smoke checks. Confirm public eligibility, contact, deletion links, headers, and indexing settings against the real domain.

**Acceptance and verification:** Observed production responses match the intended artifact and safe configuration. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-296.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert web/functions and use a compatible forward database repair. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-297"></a>

### Phase 297 — Android public rollout

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [295](#phase-295), [296](#phase-296) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Submit the reviewed bundle and actual declarations, respond to review findings, and use supported staged exposure. Monitor fresh installs, upgrades, auth, contact, crashes, and backend compatibility. Pause on predefined failures; store acceptance alone is not proof the customer journey works.

**Acceptance and verification:** The public release is observable on the intended channel with healthy core journeys. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-297.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause rollout and release the last compatible or corrected build. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-298"></a>

### Phase 298 — Controlled production AI cohort

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [220](#phase-220), [281](#phase-281), [296](#phase-296) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Enable only capabilities that passed AI gates for a small approved cohort. Recheck production secrets, processor settings, retrieval permissions, spend caps, and user controls. Monitor real quality without collecting excess transcripts, and keep ordinary search available throughout.

**Acceptance and verification:** The cohort stays within cost/quality limits with no critical disclosure or side-effect incident. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-298.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable AI immediately via server control. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-299"></a>

### Phase 299 — Post-deployment recovery rehearsal

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [281](#phase-281), [296](#phase-296), [297](#phase-297) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Verify rollback commands, feature shutdown, configuration restoration, and compatibility using controlled non-destructive production checks plus staging drills. Confirm operators can locate artifact versions and access recovery systems. Do not perform destructive live restores merely to tick a release checkbox.

**Acceptance and verification:** The on-call owner can explain and demonstrate the safe recovery path. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-299.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause rollout if recovery access or compatibility is uncertain. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-300"></a>

### Phase 300 — Deployment acceptance record

**Status:** Not started. **Suggested owner:** Release engineer and launch owner. **Effort:** 3–6 focused hours. **Release class:** Core launch.

**Prerequisites:** [007](#phase-007), [016](#phase-016), [020](#phase-020), [260](#phase-260), [280](#phase-280), [281](#phase-281), [282](#phase-282), [283](#phase-283), [284](#phase-284), [285](#phase-285), [286](#phase-286), [287](#phase-287), [288](#phase-288), [289](#phase-289), [290](#phase-290), [291](#phase-291), [292](#phase-292), [293](#phase-293), [294](#phase-294), [295](#phase-295), [296](#phase-296), [297](#phase-297), [298](#phase-298), [299](#phase-299) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `android/`, `pubspec.yaml`, `store/`, `.github/workflows/` (new), `DEPLOYMENT.md` (new when implemented), `docs/deploy/` (new), `website/` (new). Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Prepare and execute a reviewable deployment only when the required accounts, authorization, and evidence exist. Treat Android, website, backend, and AI as independently versioned surfaces with an explicit promotion sequence and rollback owner.

Record actual backend/site URLs, app package/version, store status, enabled flags, date, owners, verification evidence, known limits, and rollback locations. Separate published, submitted, approved, staged, and not-yet-enabled states. Require successful observed behavior before calling the system deployed.

**Acceptance and verification:** A new operator can identify exactly what is live and how to support/recover it. Verify the exact artifact, environment, domain, signing identity, and configuration being released. Keep approval/account blockers explicit; preparing commands or uploading a draft is not proof of a successful public deployment.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-300.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep uncertain surfaces explicitly unaccepted until verified. Preserve existing user data and document any irreversible boundary before execution.


## Workstream 16 — Post-launch validation, growth, and sustainable ownership

**Phases:** 301–320. **Lead:** Product operations and reliability lead. **Entry dependencies:** phase 010, phase 260, phase 280, phase 300. **Release class:** Post-launch; expansion and commercial work conditional.

<a id="phase-301"></a>

### Phase 301 — Production health baseline

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Collect the first defined observation window of availability, latency, crashes, failed auth/contact, deletion lag, and AI fallback. Separate bots/internal checks from genuine use and verify instrumentation itself. Compare against release objectives without declaring tiny samples statistically reassuring.

**Acceptance and verification:** A baseline dashboard names healthy areas, incidents, uncertainty, and accountable owners. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-301.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Reduce rollout exposure when core objectives fail. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-302"></a>

### Phase 302 — Pilot feedback synthesis

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Review consented customer/provider feedback by task, language, device, and locality. Separate repeated observed problems from preferences, feature requests, and support misunderstandings. Turn high-impact findings into bounded repair tickets with reproduction and success criteria rather than restarting design from anecdotes.

**Acceptance and verification:** Each priority fix links to evidence and a measurable affected journey. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-302.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revert fixes that demonstrably worsen task completion. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-303"></a>

### Phase 303 — Real supply quality audit

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Sample live providers for working contact, valid consent, declared coverage, current hours, and accurate trust claims. Contact or outreach requires applicable authorization and respectful participation. Remove stale or misleading information through existing review procedures, not unlogged direct edits.

**Acceptance and verification:** A quality report distinguishes unreachable, stale, disputed, and verified-current supply. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-303.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause inaccurate listings pending correction. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-304"></a>

### Phase 304 — Contact usefulness measurement

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Evaluate whether discovery leads to useful conversations using optional, minimally invasive user feedback. Keep tap counts separate from reported contact success and completed work. Document sampling bias and avoid asking for call histories or uploading external message contents by default.

**Acceptance and verification:** Metrics describe exactly what was observed without converting intent into verified jobs. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-304.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable intrusive questions and retain aggregate intent data. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-305"></a>

### Phase 305 — Trust explanation recalibration

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Test whether users interpret badges, source receipts, sponsorship, and freshness accurately after real use. Investigate misunderstanding of phone verification or credentials as blanket safety guarantees. Adjust wording and prominence using evidence while retaining truthful underlying states.

**Acceptance and verification:** Users distinguish checked facts from provider claims with improved comprehension. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-305.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Hide misleading presentation while preserving evidence records. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-306"></a>

### Phase 306 — Moderation and support capacity

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Measure queue age, urgent-case response, appeals, reversals, and operator workload. Identify staffing or workflow bottlenecks before increasing geographic reach. Review false positives and reporter protection, and revise service promises to match actual coverage instead of silently missing them.

**Acceptance and verification:** Operations can sustain current demand within approved response expectations. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-306.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Limit intake or rollout until capacity recovers. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-307"></a>

### Phase 307 — Search relevance maintenance

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Review anonymized/coarse no-result trends and newly encountered terminology using the established dataset and native-language review. Add labeled cases before tuning synonyms or rankers. Preserve a held-out set and monitor exposure changes so incremental improvements do not erode eligibility or fairness.

**Acceptance and verification:** A candidate update improves reviewed cases without held-out regression. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-307.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restore the prior ranking/catalog revision. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-308"></a>

### Phase 308 — AI quality and cost maintenance

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [220](#phase-220), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Review consented samples and aggregate failures for unsupported claims, weak languages, slow tools, and unnecessary token use. Compare new prompts/models on held-out data before promotion. Optimize measured bottlenecks without removing authorization, source checks, or abstention simply to lower cost.

**Acceptance and verification:** Each AI change has quality/safety/cost evidence and a reversible version. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-308.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pin the last evaluated model/prompt/retrieval combination. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-309"></a>

### Phase 309 — Real-device performance repairs

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Use actual low-end-device and poor-network evidence to prioritize startup, scrolling, memory, upload, and search fixes. Preserve accessible layouts and correctness while reducing payload or work. Reproduce problems with documented device conditions rather than pursuing synthetic benchmark scores alone.

**Acceptance and verification:** The targeted real journey improves without new crashes, leaks, or visual regressions. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-309.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Roll back the isolated performance change. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-310"></a>

### Phase 310 — Privacy lifecycle audit

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Sample synthetic access/export/deletion requests through live-approved procedures and reconcile source databases, blobs, caches, AI indexes, logs, and processors. Check that published retention matches behavior. Do not copy real private records into an audit document unnecessarily.

**Acceptance and verification:** Every sampled lifecycle completes within its approved scope and stated timing. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-310.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable affected collection until the lifecycle is repaired. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-311"></a>

### Phase 311 — Vulnerability and access review

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Review new dependency findings, secret exposure signals, privileged membership, stale accounts, and changed endpoints. Re-run focused negative tests after meaningful changes. Keep a risk owner and patch urgency proportional to exploitability, avoiding both ignored alerts and unreviewed mass upgrades.

**Acceptance and verification:** Actionable severe findings and unnecessary privileges are resolved with evidence. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-311.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Revoke suspect access and disable vulnerable features. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-312"></a>

### Phase 312 — Unit economics and quota review

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Reconcile actual per-active-provider and per-useful-discovery costs across SMS, hosting, storage, support, and AI. Separate fixed from variable costs and acknowledge immature sample sizes. Use current bills and agreed commercial assumptions, not fictional revenue or optimistic free-tier projections.

**Acceptance and verification:** A current cost model identifies budget risks and concrete efficiency options. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-312.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Cap optional usage before increasing infrastructure spend. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-313"></a>

### Phase 313 — Provider retention and freshness

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Test respectful reminders or dashboard guidance for stale hours and incomplete service information, subject to channel preferences. Measure useful updates and opt-outs rather than raw notification opens. Avoid coercive streaks or threats that providers must pay or constantly interact to remain credible.

**Acceptance and verification:** Freshness improves without excessive reminders, churn, or misleading trust incentives. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-313.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable the reminder experiment. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-314"></a>

### Phase 314 — Useful local-content maintenance

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Maintain reviewed locality/service guidance, supported language pages, and accurate provider-help material. Fix broken links and remove obsolete thin pages instead of scaling keyword content indiscriminately. Ensure organic growth reflects real local utility and never fabricated testimonials or reviews.

**Acceptance and verification:** Content changes improve relevant discovery with accurate claims and maintained sources. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-314.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Unpublish weak pages and remove them from indexing. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-315"></a>

### Phase 315 — Commercial pilot evaluation

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [259](#phase-259), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

If paid features passed their gates, run a limited transparent pilot with real pricing, entitlement, cancellation, refund, and support behavior. Measure provider value and complaints separately from revenue. Keep organic relevance and verified trust independent of payment throughout the experiment.

**Acceptance and verification:** Commercial benefits are understandable and lifecycle failures do not harm customers. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-315.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Pause new purchases while honoring verified obligations. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-316"></a>

### Phase 316 — Second-city readiness rehearsal

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Select a candidate city only after demand, supply recruitment, language, moderation capacity, legal scope, and support readiness are evidenced. Dry-run activation as configuration and verify isolation, category rules, search, website indexing, and AI locality handling. Do not mass-publish unconsented scraped providers.

**Acceptance and verification:** A second-city plan has real eligible supply and an executable activation/rollback checklist. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-316.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep the city inactive until prerequisites pass. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-317"></a>

### Phase 317 — Promote or remove differentiators

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [240](#phase-240), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Review selected phase-221–240 experiments using actual benefit, privacy, cost, and operator workload. Graduate a small number with maintainable contracts and support ownership. Remove failed flags/code through reviewed changes while preserving user exports or migrated data where necessary.

**Acceptance and verification:** Every retained feature has an evidence-backed purpose and maintenance owner. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-317.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Disable unsuccessful experiments with safe data handling. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-318"></a>

### Phase 318 — Recovery and incident follow-through

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Repeat restore drills after substantial schema or storage changes and close postmortem actions from real incidents. Verify alert routing, backup access, key recovery, and on-call handover after personnel changes. Record measured recovery instead of assuming the original launch drill remains valid forever.

**Acceptance and verification:** Current systems meet recovery targets and critical postmortem actions are closed. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-318.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Restrict rollout when recovery assurance degrades. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-319"></a>

### Phase 319 — Maintainer and operator handover

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Update setup, architecture, contracts, deployment, support, privacy, AI evaluation, cost, and incident documentation to the actual released state. Assign owners and review triggers, remove stale instructions carefully, and trial onboarding a new maintainer without relying on private chat history.

**Acceptance and verification:** A new maintainer can run, test, release, investigate, and recover the system safely. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-319.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Retain the previous verified runbook while correcting gaps. Preserve existing user data and document any irreversible boundary before execution.

<a id="phase-320"></a>

### Phase 320 — Program acceptance and next-quarter plan

**Status:** Not started. **Suggested owner:** Product operations and reliability lead. **Effort:** 2–5 focused hours. **Release class:** Post-launch; expansion and commercial work conditional.

**Prerequisites:** [010](#phase-010), [260](#phase-260), [280](#phase-280), [300](#phase-300), [301](#phase-301), [302](#phase-302), [303](#phase-303), [304](#phase-304), [305](#phase-305), [306](#phase-306), [307](#phase-307), [308](#phase-308), [309](#phase-309), [310](#phase-310), [311](#phase-311), [312](#phase-312), [313](#phase-313), [314](#phase-314), [315](#phase-315), [316](#phase-316), [317](#phase-317), [318](#phase-318), [319](#phase-319) Verify their evidence before dependent implementation; existing functionality may be reused only after validation.

**Starting points:** `docs/operations/` (new), `docs/experiments/` (new), `backend/ai-evals/` (new), `tasks/evidence/` (new as phases are executed), product modules identified by evidence. Paths labeled new are proposed additions. Trace relevant interfaces and callers before selecting the smallest change.

**Coding-agent prompt:** Validate that the released service works for real customers and can be maintained economically. Use measured behavior to improve the existing product, keep changes reversible, and expand only after supply, safety, and operating capacity support it.

Audit all 320 statuses and distinguish implemented, verified reuse, blocked, deferred, and cancelled work. Accept only evidence-backed release outcomes. Summarize real customer value, unresolved risks, sustainable operating cost, and ownership; create a bounded next-quarter backlog rather than claiming all future work is finished.

**Acceptance and verification:** The final record accurately states what is live, supported, measured, and intentionally deferred. Report sample sizes, observation windows, limitations, and attributable release/configuration revisions. Do not manufacture reviews, outcomes, usage, or success; defer decisions that lack enough evidence and assign a next review point.

**Required handoff:** Deliver the implementation, research result, or decision artifact specified above, with exact changed paths and evidence in `tasks/evidence/phase-320.md`. Include commands and actual results, relevant screenshots or fixtures, remaining uncertainty, migration/configuration effects, and the next integration action. Do not mark this phase done until its acceptance evidence has been reviewed.

**Rollback or safe stop:** Keep unresolved commitments visible with owners and next review dates. Preserve existing user data and document any irreversible boundary before execution.


## Final use checklist

1. Start with phases 001–020 to establish verified scope and prerequisites; reuse the existing code wherever evidence supports it.
2. Assign one bounded phase per coding-agent request using the master prompt, exact phase text, dependency evidence, and current file ownership.
3. Keep this plan separate from the earlier improvement documents. Reconcile conflicts explicitly in evidence rather than deleting previous work.
4. Track status inside each phase and create evidence notes only when work begins. Every release gate needs actual reviewed outcomes or an explicit safe deferral for optional disabled scope.
5. Use VS Code's Outline or search for `Phase 001` through `Phase 320`; Markdown preview provides the linked workstream index and dependency navigation.
6. Recheck external policies, model capabilities, pricing, and account prerequisites when implementing, and record the source and date of the decision.
7. Treat deployment as complete only after observing the intended public artifacts and real core journeys. A green local build, a written runbook, or a store submission alone is insufficient.

Document validation: 320 unique consecutively numbered phase headings, 16 workstreams, complete assignment/acceptance/handoff/recovery sections, and backward-only valid dependency references. These structural checks validate the plan's organization, not the app's production readiness.

