# Phase 009 — Launch category and locality boundaries

**Status:** In review

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

| Category | Approved | Healthcare | Credential | Rationale |
|----------|----------|-----------|-----------|-----------|
| Plumbing | Yes | No | None (phone verify only) | High volume, low safety bar |
| Electrician | Yes | No | **Maharashtra wireman licence** (to confirm with counsel) | Electrical safety; human review recommended |
| Carpenter | Yes | No | None | Property-focused, customer-initiated vetting |
| Painter | Yes | No | None | Low-stakes cosmetic service |
| Mason | Yes | No | None | Structural but customer-managed |
| Welding & fabrication | Yes | No | None | Customer responsibility |
| AC repair & service | Yes | No | None | Appliance focused |
| Appliance repair | Yes | No | None | Consumer electronics |
| Locksmith & key maker | Yes | No | None | Low-safety service |
| TV & electronics repair | Yes | No | None | Consumer goods |
| Tiles & marble work | Yes | No | None | Cosmetic/finishing |
| Waterproofing | Yes | No | None | Property-focused |
| Interior & false ceiling | Yes | No | None | Cosmetic/finishing |
| Home deep cleaning | Yes | No | None | Low-stakes service |
| Pest control | Yes | No | None | High urgency, common need |
| Laundry & ironing | Yes | No | None | Repeat transaction |
| Sofa & carpet cleaning | Yes | No | None | Low-stakes |
| Water tank cleaning | Yes | No | None | Utility service |
| General helper | Yes | No | None | High volume, recurring |
| Construction labourer | Yes | No | None | Short-term work |
| Loading & unloading worker | Yes | No | None | Transactional |
| Gardening | Yes | No | None | Property service |
| Security guard | Yes | No | None | Customer-managed hiring |
| Two-wheeler mechanic | Yes | No | None | Hobby/commute focus |
| Car mechanic | Yes | No | None | Owner manages follow-up |
| Puncture repair | Yes | No | None | Quick service |
| Towing service | Yes | No | None | Emergency-adjacent but not dispatch |
| Driver | Yes | No | None | Transactional hiring |
| **General physician** | **Recommended: No** | **Yes** | **Medical council registration (NEET/state) — human review required** | **Directory-only rule: no booking, no medical advice, no outcome claims. Clinic staff offline appointments only.** |
| **Dentist** | **Recommended: No** | **Yes** | **Dental council registration — human review required** | **Same directory-only rule.** |
| **Paediatrician** | **Recommended: No** | **Yes** | **Medical council registration — human review required** | **Same directory-only rule.** |
| **Physiotherapist** | **Recommended: No** | **Yes** | **Physiotherapy council registration — human review required** | **Same directory-only rule.** |
| **Diagnostic centre** | **Recommended: No** | **Yes** | **Lab registration (NABL/state) — human review required** | **Same directory-only rule. No lab bookings through app.** |
| **Home nursing & attendant** | **Recommended: No** | **Yes** | **Nursing council/senior care credential — human review. Person-safety category.** | **Same directory-only rule. Explicit person-care safety review.** |
| **Veterinary doctor** | **Recommended: No** | **Yes** | **Veterinary council registration — human review required** | **Directory-only rule; pet owner manages follow-up.** |
| Computer & laptop repair | Yes | No | None | Consumer electronics |
| Network technician | Yes | No | None | Customer-managed tech |
| Tutor | Yes | No | None | Educational; parent vetting |
| Packers & movers | Yes | No | None | Transactional, offline quotes |
| Internet & WiFi setup | Yes | No | None | Customer-managed tech |
| Mobile repair | Yes | No | None | Consumer electronics |
| Beauty services at home | Yes | No | None | Cosmetic; customer comfort = vetting |
| Tailoring & alteration | Yes | No | None | Apparel-focused |
| Event & catering help | Yes | No | None | Seasonal; reputation-driven |
| Other local services | Yes | No | None | Catch-all; low volume |

**Summary:** 28 recommended for `is_approved_for_launch=true` at Phase 1 (home repair/service, vehicles, generic labor). 7 healthcare categories recommended `is_approved_for_launch=false` pending credential review workflow (human reviewer signs off on registration scan, then flipped to true). All rows kept in database; disabled via flag, never deleted.

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
3. **Support capacity:** Can one person cover proposed cluster? If not, recommend starting 2–3 localities only.

## Next integration action

1. Query `public.service_categories` for real category list; confirm `is_healthcare` flag matches table above.
2. Implement credential-review workflow for healthcare (phase 021+).
3. Set `is_approved_for_launch=false` for healthcare categories in seed.
4. Finalize proposed cluster with operations + legal.

---

**Attribution:** Phase 009 evidence, LocalSaathi implementation plan.
