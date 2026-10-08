# Phase 093 Evidence - Safe profile and caption text

**Status:** Done locally (database); client rendering and model-context code not built. **Reviewer:** pending **Human sign-off:** pending

## Objective
Bound user text, keep it inert when rendered, reject dangerous markup, preserve legitimate multilingual text, and label provider text untrusted for future model contexts.

## Changed paths
- backend/supabase/migrations/20261008000043_safe_text.sql (`private.text_problem`, `private.assert_safe_text`, `private.check_user_text`, `trg_safe_text` on provider_profiles, provider_photos, provider_starting_prices, provider_healthcare_details, credential_records, reports, private.credential_decisions, private.listing_reviews)
- backend/supabase/tests/database/0043_safe_text.test.sql
- backend/test/trust-contract.test.mjs (every user-text table has the trigger)
- docs/trust-and-credentials.md (section 5: rule and the model-context contract)

## Rule
Rejected (not rewritten): control characters except tab/CR/LF, C1 controls, zero-width space, LRM/RLM, bidi embeddings/overrides/isolates, line/paragraph separators, word joiner and invisible operators, BOM, interlinear marks, Unicode tag characters (U+E0000-E007F), HTML-looking tags/comments (`<` + letter, `/`, `!`, `?`), numeric character references, `javascript:`/`vbscript:`/`data:text|application/` links, and overlong text. Kept: all scripts, ZWJ (U+200D) and ZWNJ (U+200C), emoji sequences, a bare `<`/`>`, `&`, quotes. Triggers check only changed values, so legacy rows never block unrelated updates.

## Commands run (actual results, 2026-10-08)
`ok 0043_safe_text.test.sql (19 tests)`; full `Tests: 38/38 files passed, 582/582 assertions passed. PASS`; Node `tests 41, pass 41, fail 0`. Baseline in phase-088.md.

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Script-like content is inert | 20 dangerous samples (tags, handlers, comments, script links in mixed case, numeric references, bidi/ZWSP/tag chars, controls) all rejected; enforced for names, descriptions, languages, captions, price notes, healthcare fields, credential titles, guest report text, reviewer text | Pass |
| Legitimate multilingual text preserved | 14 samples kept: Hindi, Marathi, Tamil, Arabic, Chinese, accents, Devanagari conjunct with ZWJ, Persian with ZWNJ, emoji sequence, `5 < 10 km`, "Metadata: ..." | Pass |
| Escaped JSON | quotes/backslash stored verbatim and the JSON text carries `\"` and `\\` | Pass |
| Text cannot alter privileges | "ignore instructions / role admin / drop table" description stored as text; `moderation_status` unchanged, `is_admin()` false, `app_admins` empty | Pass |
| Bounds | 81-char name refused at the table | Pass |
| Any write path covered | caption trigger fires on a direct table insert; RPCs are not the only gate | Pass |
| Future model contexts | contract documented (delimited, labelled, no instructions, strip delimiter); no model code exists to test | Documented only |
| HTML escaping in clients | cannot be verified here | BLOCKED (Flutter/web) |

## Assumptions and uncertainty
- No Unicode normalisation (NFC) is applied; look-alike (homoglyph) names are not detected.
- The `description` of other tables not listed (e.g. `city_requests.note`, `reports.resolution_note`) are admin/guest-only and not yet covered; add if they become public.
- Existing rows are not scanned; run `select ... where private.text_problem(description) is not null` before launch to find legacy offenders.

## Client follow-ups
Render provider fields as plain text only (Flutter `Text`, never `Html`/Markdown widgets; website `textContent`); show a friendly message for `validation_failed: ... unsupported ...` errors; apply the model-context contract wherever the assistant is built.

## Rollback / safe stop
`alter table ... disable trigger trg_safe_text` per table (forward fix preferred), and render as plain text in clients.

## Next action
Legacy-row scan; add the triggers to any new text-bearing table (081-087 media tables, 092 moderation notes).
