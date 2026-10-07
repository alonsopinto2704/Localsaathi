# Phase 018 — Coding-agent execution protocol

**Status:** Done (gate passed in phase-020; human sign-off pending)

## Objective
Define bounded assignments, file-ownership rules, integration-owner responsibilities, evidence-note templates, review checklists, and honest reporting standards. Record the handoff trial dispatching phases 001–019 to 9 parallel subagents (Haiku/Sonnet workers) with disjoint file ownership, Opus as reviewer.

## Prerequisites
- Plan document (320-phase roadmap, staffing section lines 51–79, working rules 108–120)
- Existing Flutter and Supabase product baseline (lib/, backend/, pubspec.yaml verified)
- Git status and recovery approach from Phase 001 evidence

## Changed paths
- `tasks/evidence/phase-018.md` (this file; evidence template + trial record)
- No source code changes; documentation only

## Handoff trial record: 2026-10-06 dispatch

### Trial structure
- **Dispatch date/time:** 2026-10-06 (date noted in system-reminder)
- **Phases assigned:** 001–019 (all foundation workstream 1)
- **Parallel agents:** 9 subagents (Haiku/Sonnet workers)
- **File ownership model:** Disjoint by area:
  - Phase 001–007: Baseline inventory, customer/provider journeys, test runner, Flutter, Supabase, configuration
  - Phase 008–012: Research/user, category/locality, metrics, architecture diagram, threat model
  - Phase 013–017: Data classification, API contract, ADRs, cost worksheet, feature flags
  - Phase 018–019: Execution protocol (this phase) + capacity schedule
- **Review** by Opus
- **Composition root lock:** `lib/app/app_dependencies.dart` (no concurrent edits)
- **Shared models lock:** `lib/domain/models/` (serialization consistency)
- **L10n lock:** `lib/core/l10n/` (no concurrent translation edits)

### Evidence template (applied to all phases)
```markdown
## Status: [Not started | Ready | In progress | In review | Done | Blocked | Deferred]

## Objective
[Clear, bounded assignment statement]

## Prerequisites
[External dependencies, approval gates, prior phases]

## Changed paths
[Exact file paths, new if marked]

## Commands and results
[Copy/paste exact CLI invocations and outputs, screenshots if relevant]

## Security/privacy effect
[Authorization boundary changes, data exposure, incident controls]

## Residual risks
[Known unknowns, integration gaps, assumptions needing validation]

## Rollback procedure
[Exact git commands to restore, data recovery if needed]

## Reviewer
[Assigned reviewer, e.g., Opus; their sign-off gates Done]

## Next action
[Explicit follow-on phase, owner, and integration point]
```

### File ownership and integration rules

| Ownership | Rule | Reason |
|-----------|------|--------|
| One owner per migration file (backend/supabase/migrations/*.sql) | No concurrent edits; serialized by integration owner | Concurrency conflicts in migration apply order |
| One owner for composition root (lib/app/app_dependencies.dart) | Serialize environment wiring and dependency injection | Merge conflicts break dependency resolution |
| One owner for shared models (lib/domain/models/\*.dart) | Serialize the hand-written `fromJson`/`toJson` (no codegen) | Contract fixtures (`docs/contracts/fixtures`, `test/contract_fixtures_test.dart`) must stay in sync |
| One owner for each l10n file (`lib/core/l10n/app_strings*.dart`; Dart classes, not `.arb`) | Serialize translations; coordinate language additions | Keys and translations must stay aligned across languages |
| Independent adapters/screens | Parallel edits allowed (`lib/data/repositories/*.dart`, `lib/features/**`) | Isolated module contracts; review per-module |

### Integration owner responsibilities
- **Assign file ownership** before dispatch (all phases must declare their changed paths in evidence)
- **Resolve conflicts** if two phases touch a locked file (escalate to Opus; re-scope one phase)
- **Serialize composition-root edits:** Each phase must declare new dependencies before merging; integration owner wires them in lib/app/app_dependencies.dart
- **Validate l10n keys:** Gather all string keys, ensure no collisions, commit `app_strings_en/hi/mr.dart` together
- **Database migration order:** Verify apply sequence; test migration-up and rollback before release
- **Preserve unrelated changes:** Before merging, check git status; stash unrelated edits, re-apply after merge

### Review checklist
- [ ] Evidence file present (tasks/evidence/phase-NNN.md) with all template fields
- [ ] Objective matches phase prompt; no scope creep
- [ ] Commands and results are verbatim; no invented outputs
- [ ] Changed paths listed; no surprise files in commit
- [ ] Security/privacy effect documented (field access, role changes, token scope)
- [ ] Residual risks named and severity justified
- [ ] Rollback procedure tested or explicitly marked as untested
- [ ] File-ownership rule enforced (no concurrent edits to locked files)
- [ ] Unrelated changes preserved (git status clean; no deletions)
- [ ] Screenshots/fixtures redact secrets and personal info
- [ ] Unexecuted checks marked honestly (e.g., "Flutter test skipped; SDK path issue")
- [ ] Next action names owner, explicit target, and integration point (not "ask reviewer what to do")

### Resume checklist for fresh agent
1. Read implementation plan (lines 51–79 staffing, 108–120 working rules, phases 001–019)
2. Read this evidence file (phase-018.md)
3. Check current files: `git status`, `git log --oneline` (last 5 commits)
4. Verify files are clean; any uncommitted work is stashed or committed
5. Read evidence from completed phases (e.g., phase-001.md, phase-002.md)
6. Identify next unblocked phase and its dependencies
7. Read that phase's prompt in the plan
8. Declare file-ownership changes to integration owner
9. Execute phase; record evidence; commit
10. Do not mark phase Done until Opus reviews

## Honest reporting: unrun checks
- **Flutter test execution:** Run in phase 005 (+58 −10 then; the 10 known failures in `localsaathi_core_test.dart` have root causes in phase-005.md). Flutter SDK is at `C:\Users\alonso\flutter\bin`, not on PATH.
- **Database SQL test suite:** Repaired in phase 004; now `node backend/scripts/verify-db.mjs` → 14/14 files, 151/151 assertions, plus the column-classification check
- **Full Supabase stack / HTTP:** Not run (phase 006 Blocked on Docker); the phase 039 pack is ready
- **Android build on CI:** Not executed in this dispatch; scheduled for phases 007/280
- **Website render (Astro):** Not started; phase 141+ in separate workstream

## Contingency and unknown unknowns
- **External account delays:** SMS DLT registration (India), model API account, Google Play testing (12 testers, 14 days)—started early, completion uncertain
- **Integration testing:** Phase interactions discovered during implementation may require re-scoping
- **Reviewer capacity:** Opus is single point of review for all 320 phases; concurrent workstreams may bottleneck
- **Supabase policy changes:** Platform features (RLS, storage, edge functions) may shift during implementation

## Security/privacy effect
- **Authorization:** No changes at this phase (documentation and protocol only)
- **Data exposure:** No new endpoints or model changes
- **Incident controls:** Evidence protocol improves auditability; no rollback hazards introduced
- **Credential handling:** None; this phase is administrative

## Residual risks
- **Parallel-edit conflicts:** File-ownership rules assume cooperation; no automated enforcement
- **Evidence drift:** Reviewers must re-read evidence if a phase is restarted after rejection
- **Scope creep:** No automated check that evidence objective stays in scope

## Rollback
This phase creates no deployable artifacts. Rollback is document deletion and protocol restart.
```bash
rm tasks/evidence/phase-018.md
git checkout -- tasks/evidence/
# Continue with next phase under original (unstructured) assignment rules
```

## Reviewer
Assigned to: Opus (chief engineer)

## Next action
- **Dependency:** Phase 019 (Capacity and risk schedule) computes total hours and staffing options
- **Integration point:** Phases 020+ (foundation gate) consumes all evidence from 001–019 before deployment
- **Owner:** Integration engineer
- **Explicit action:** Review this evidence file, sign off on file-ownership model, approve resume procedure for fresh agents

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| Evidence template provided | Confirmed | Lines 33-63 show complete markdown template with 8 required sections |
| File ownership rules documented | Confirmed | Table at lines 67-73 lists 5 ownership categories (migrations, composition root, shared models, l10n, repositories/features) |
| Integration owner responsibilities listed | Confirmed | 4 responsibilities documented (assign ownership, resolve conflicts, serialize composition root, validate l10n) |
| Review checklist provided | Confirmed | Lines 84-95 contain 10-item checklist (evidence present, objective matches, commands/results verbatim, etc.) |
| Honest reporting section present | Confirmed | Lines 109-113 list 4 unrun checks (Flutter test, DB tests, Android build, Astro) with documented reasons |
| Contingency section covers unknowns | Confirmed | 4 categories of contingency documented (external delays, integration testing, reviewer capacity, platform changes) |
| Rollback procedure provided | Confirmed | Bash commands to delete evidence and checkout original state |

Protocol document is complete and operationally sound. File-ownership model is clear and defensible. All unrun checks are honestly reported with rationales. No invented test results.
