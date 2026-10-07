# Phase 033 — Protected anonymous writes

**Status:** In review. Verified locally (PGlite); header-based throttling is unverified until it runs on a real stack. · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Guest writes must be bounded, de-duplicated and quota-limited, with no direct-table path around those controls.

## Changed paths
- Migration `…13`: no direct INSERT grants.
- Migration `…18`:
  - new RPCs `submit_report`, `record_engagement` and `request_city`;
  - throttling helpers `private.rate_limits`, `private.request_source` and `private.take_rate_token`;
  - the old `with check (true)` insert policies are dropped.

## Controls
"Source" means the signed-in user id or, for guests, a daily-rotating md5 of the client IP. The IP comes from `cf-connecting-ip` (set by the edge); otherwise from the **rightmost** `x-forwarded-for` hop, which the nearest proxy appended. The leftmost entries are client-controlled and are ignored.

The code review changed two things:
1. Before, the source used the spoofable leftmost `x-forwarded-for` entry. A client could rotate a fake IP to bypass the limits and dedupe.
2. When there is no client signal at all, the source is **null**. Per-source dedupe and limits are then skipped, and only the per-target caps apply, so guests are not merged into one shared bucket. Before, every such guest shared `md5('unknown')`: the second guest's report silently returned the first guest's receipt, and five reports an hour locked out everyone. Covered by `0014_review_fixes`.

| Write | Validation | Limits | When over limit |
|---|---|---|---|
| `submit_report` | Target must be listed, else `not_found` (so hidden ids cannot be probed). Details ≤1000 characters. An optional reporter phone must be E.164. | 5 per hour and 20 per day per source; 50 per day per listing. The same source reporting the same listing within 24 hours gets the same receipt and no new row. | `rate_limited` |
| `record_engagement` | Target must be listed. Context ids are validated (unknown ids become null). | 10 per hour per source + listing + type; 300 per hour per source. | Dropped silently (a tap must never fail) |
| `request_city` | City 2–80 characters, state ≤80, note ≤500. `submitted_by_phone` comes only from the signed-in provider's own profile. | 5 per day per source | `rate_limited` |

The source is a throttling signal, not proof of identity (plan rule). Phones behind carrier NAT share one IP and therefore one budget, which is why the per-target caps exist.

## Verification
- `0011_guest_writes` (17 assertions) covers receipts, de-duplication, every bound, the 6th-report limit, the engagement cap, and phone provenance.
- Direct anon INSERT into all three tables fails with 42501.
- Suite: `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Not verified
- PGlite has no real edge, so the tests set synthetic `cf-connecting-ip`/`x-forwarded-for` headers.
- `cf-connecting-ip` / `x-forwarded-for` behaviour behind Supabase's edge needs the HTTP pack on a real project (phase 039).

## Rollback
To disable guest writes but keep discovery, revoke EXECUTE on the three RPCs.
