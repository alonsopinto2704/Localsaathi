# Phase 009 — Launch category and locality boundaries

**Status:** Done (gate passed in phase-020; human sign-off pending)

**Objective:** Define a small operational slice of Mumbai for launch; classify all categories; exclude unsupported features explicitly; provide launch matrix.

## Changed paths

None (planning document; activation via `backend/supabase/migrations/20260101000003_catalog.sql` columns `is_approved_for_launch`, `is_healthcare`).

## Inputs reviewed

- `lib/data/seed/category_seed.dart`: verified `grep -c "groupId:" = 45` categories
- `lib/data/seed/location_seed.dart`: verified `grep "cityId: 'mh-mumbai'" | wc -l = 43` active localities
- `backend/supabase/migrations/20260101000003_catalog.sql` lines 15–27: real schema (`is_healthcare`, `is_approved_for_launch`)

## Content

### Actual categories (verified by command)

**Command:** `grep -c "groupId:" lib/data/seed/category_seed.dart` → **45 total**

| Group | Count |
|-------|-------|
| Home repairs | 13 |
| Home services | 5 |
| Daily workers | 5 |
| Vehicle services | 5 |
| Healthcare | 7 |
| Other services | **10** |
| **Total** | **45** |

Source: `lib/data/seed/category_seed.dart` lines 12–452.

### Actual Mumbai localities (verified by command)

**Command:** `grep "cityId: 'mh-mumbai'" lib/data/seed/location_seed.dart | wc -l` → **43 total**

Real locality IDs from lines 539–773:
```
mh-mumbai-andheri-west
mh-mumbai-andheri-east
mh-mumbai-jogeshwari
mh-mumbai-goregaon
mh-mumbai-malad
mh-mumbai-kandivali
mh-mumbai-borivali-west
mh-mumbai-borivali-east
mh-mumbai-dahisar
mh-mumbai-bandra-west
mh-mumbai-bandra-east
mh-mumbai-khar
mh-mumbai-santacruz
mh-mumbai-vile-parle
mh-mumbai-juhu
mh-mumbai-powai
mh-mumbai-vikhroli
mh-mumbai-ghatkopar
mh-mumbai-bhandup
mh-mumbai-mulund
mh-mumbai-chembur
mh-mumbai-kurla
mh-mumbai-sion
mh-mumbai-wadala
mh-mumbai-dadar-west
mh-mumbai-dadar-east
mh-mumbai-parel
mh-mumbai-lower-parel
mh-mumbai-worli
mh-mumbai-prabhadevi
mh-mumbai-mahim
mh-mumbai-matunga
mh-mumbai-colaba
mh-mumbai-fort
mh-mumbai-churchgate
mh-mumbai-marine-lines
mh-mumbai-charni-road
mh-mumbai-malabar-hill
mh-mumbai-byculla
mh-mumbai-mazgaon
mh-mumbai-wadala-sewri
mh-mumbai-mankhurd
mh-mumbai-kanjurmarg
```

### Launch operational slice: Phase 1 (proposal — owner to confirm)

**Single contiguous cluster (one support person handles all; provider multi-locality areas extend reach):**

**Proposed:** `mh-mumbai-andheri-west`, `mh-mumbai-andheri-east`, `mh-mumbai-jogeshwari`, `mh-mumbai-vile-parle`

**Alternative:** `mh-mumbai-dadar-west`, `mh-mumbai-dadar-east`, `mh-mumbai-mahim`, `mh-mumbai-parel`

**Rationale:** Small walkable cluster for rapid support iteration, provider verification, issue response. Seed data includes providers with multi-locality service areas, extending effective coverage.

### Launch category matrix (45 categories)

Compact format: **Category | is_approved_for_launch | is_healthcare | Credential required | Why**

| Category | Pilot (approved) | Healthcare | Verification | Support owner / escalation | Rationale |
|---|---|---|---|---|---|
| Plumbing | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | High volume, low safety bar |
| Electrician | **Yes** | No | Phone OTP + licence check (confirm with counsel) | Pilot ops lead; **trust-sensitive (electrical safety)**: report → hide pending review, 24 h response | Electrical safety; human review recommended |
| Carpenter | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Property-focused, customer-initiated vetting |
| Painter | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Low-stakes cosmetic service |
| Mason | Later (wave 2) | No | Phone OTP | Pilot ops lead | Structural but customer-managed |
| Welding & fabrication | Later (wave 2) | No | Phone OTP | Pilot ops lead | Customer responsibility |
| AC repair & service | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Appliance focused |
| Appliance repair | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Consumer electronics |
| Locksmith & key maker | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (enters/unlocks homes)**: needs a written escalation rule before enabling | Low-safety service |
| TV & electronics repair | Later (wave 2) | No | Phone OTP | Pilot ops lead | Consumer goods |
| Tiles & marble work | Later (wave 2) | No | Phone OTP | Pilot ops lead | Cosmetic/finishing |
| Waterproofing | Later (wave 2) | No | Phone OTP | Pilot ops lead | Property-focused |
| Interior & false ceiling | Later (wave 2) | No | Phone OTP | Pilot ops lead | Cosmetic/finishing |
| Home deep cleaning | **Yes** | No | Phone OTP | Pilot ops lead; **trust-sensitive (in-home)**: report → hide pending review, 24 h response | Low-stakes service |
| Pest control | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | High urgency, common need |
| Laundry & ironing | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Repeat transaction |
| Sofa & carpet cleaning | Later (wave 2) | No | Phone OTP | Pilot ops lead | Low-stakes |
| Water tank cleaning | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Utility service |
| General helper | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (in-home)**: needs a written escalation rule before enabling | High volume, recurring |
| Construction labourer | Later (wave 2) | No | Phone OTP | Pilot ops lead | Short-term work |
| Loading & unloading worker | Later (wave 2) | No | Phone OTP | Pilot ops lead | Transactional |
| Gardening | Later (wave 2) | No | Phone OTP | Pilot ops lead | Property service |
| Security guard | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (person safety)**: needs a written escalation rule before enabling | Customer-managed hiring |
| Two-wheeler mechanic | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Hobby/commute focus |
| Car mechanic | Later (wave 2) | No | Phone OTP | Pilot ops lead | Owner manages follow-up |
| Puncture repair | Later (wave 2) | No | Phone OTP | Pilot ops lead | Quick service |
| Towing service | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (roadside, vulnerable customer)**: needs a written escalation rule before enabling | Emergency-adjacent but not dispatch |
| Driver | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (person safety, vehicle)**: needs a written escalation rule before enabling | Transactional hiring |
| General physician | No (hidden until credential workflow) | Yes | Medical council registration (NEET/state) — human review required | Credential reviewer (human); report → hide listing pending review | Directory-only rule: no booking, no medical advice, no outcome claims. Clinic staff offline appointments only. |
| Dentist | No (hidden until credential workflow) | Yes | Dental council registration — human review required | Credential reviewer (human); report → hide listing pending review | Same directory-only rule. |
| Paediatrician | No (hidden until credential workflow) | Yes | Medical council registration — human review required | Credential reviewer (human); report → hide listing pending review | Same directory-only rule. |
| Physiotherapist | No (hidden until credential workflow) | Yes | Physiotherapy council registration — human review required | Credential reviewer (human); report → hide listing pending review | Same directory-only rule. |
| Diagnostic centre | No (hidden until credential workflow) | Yes | Lab registration (NABL/state) — human review required | Credential reviewer (human); report → hide listing pending review | Same directory-only rule. No lab bookings through app. |
| Home nursing & attendant | No (hidden until credential workflow) | Yes | Nursing council/senior care credential — human review. Person-safety category. | Credential reviewer (human); report → hide listing pending review | Same directory-only rule. Explicit person-care safety review. |
| Veterinary doctor | No (hidden until credential workflow) | Yes | Veterinary council registration — human review required | Credential reviewer (human); report → hide listing pending review | Directory-only rule; pet owner manages follow-up. |
| Computer & laptop repair | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Consumer electronics |
| Network technician | Later (wave 2) | No | Phone OTP | Pilot ops lead | Customer-managed tech |
| Tutor | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (minors)**: needs a written escalation rule before enabling | Educational; parent vetting |
| Packers & movers | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (handles belongings)**: needs a written escalation rule before enabling | Transactional, offline quotes |
| Internet & WiFi setup | Later (wave 2) | No | Phone OTP | Pilot ops lead | Customer-managed tech |
| Mobile repair | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Consumer electronics |
| Beauty services at home | Later (wave 2) | No | Phone OTP | Pilot ops lead; **trust-sensitive (in-home, personal contact)**: needs a written escalation rule before enabling | Cosmetic; customer comfort = vetting |
| Tailoring & alteration | **Yes** | No | Phone OTP | Pilot ops lead; report → review within 72 h | Apparel-focused |
| Event & catering help | Later (wave 2) | No | Phone OTP | Pilot ops lead | Seasonal; reputation-driven |
| Other local services | Later (wave 2) | No | Phone OTP | Pilot ops lead | Catch-all; low volume |

**Summary (corrected 2026-10-07):** 45 categories total = **14 approved for the pilot** + 24 later (wave 2) + 7 healthcare hidden. The first draft said "28 + 7" (= 35, not 45) while its table marked 38 `Yes`; launching 38 categories in a 4-locality pilot contradicted the Idea Council (`council/verdicts.md`: ~10–15 categories) and would make Phase 010's ≥10 providers per locality/category threshold unreachable. The pilot slice is now 14: high-volume home repair/upkeep where density is plausible. All rows stay in the database; wave-2 and healthcare rows are disabled via `is_approved_for_launch=false`, never deleted.

**Support ownership rule:** every enabled category has a named support owner (the pilot ops lead) and an escalation path. Trust-sensitive trades (in-home entry, person safety, minors) get "report → hide pending review, 24 h response"; wave-2 trust-sensitive trades (locksmith, security guard, home beauty, tutor, driver, towing, packers) need a written escalation rule before they are enabled.

### Explicitly excluded from launch (configuration, not deletion)

| Feature | Reason |
|---------|--------|
| Emergency dispatch | Not a directory feature; LocalSaathi is discovery only |
| Booking guarantees | Liability & payment complexity; deferred to post-launch |
| Escrow payments | PCI/DSS & consumer protection — post-launch commercial phase |
| Outcome claims | Consumer protection risk + healthcare liability |
| Reviews/ratings | Phase 221+ experiment; launch shows only freshness |
| Booking confirmation | Manual coordination offline; app role is discovery |

## Residual uncertainty / decisions needing the owner

1. **Healthcare launch:** Proceed with all 7 disabled + credential-review workflow, or disable only highest-risk (physician, dentist, home nursing)? Legal + operations.
2. **Electrician credential:** Maharashtra wireman licence requirement — confirm with counsel before enforcing.
3. **Pilot category pick (assumption, 2026-10-07):** the 14 pilot categories were chosen by the reviewer for volume and low trust risk; the owner should confirm or swap them after the Phase 008 incumbent test.
4. **Support capacity:** Can one person cover proposed cluster? If not, recommend starting 2–3 localities only.

## Next integration action

1. Query `public.service_categories` for real category list; confirm `is_healthcare` flag matches table above.
2. Implement credential-review workflow for healthcare (phases 081–100, Workstream 5).
3. Set `is_approved_for_launch=false` for healthcare and wave-2 categories in seed (only the 14 pilot categories true).
4. Finalize proposed cluster with operations + legal.

---

**Attribution:** Phase 009 evidence, LocalSaathi implementation plan.

## 2026-10-07 audit follow-up
See `tasks/evidence/audit-2026-10-07-followup.md`. The 14-category pilot is now applied in data: `category_seed.dart` + regenerated `seed.sql` (31 categories not approved) and the mock app hides listings without an approved category.
