# Phase 090 Evidence - Truthful trust badges

**Status:** Done locally (database); Flutter labels not changed. hi/mr wording is an unreviewed draft. **Reviewer:** pending **Human sign-off:** pending

## Objective
Separate verified phone, reviewed listing, checked credential and self-reported information; localized scope/limits; no universal trusted/safe claims; no client-controlled flags; expiry and withdrawal affect every public display.

## Changed paths
- backend/supabase/migrations/20261008000041_truthful_trust_badges.sql (`public.trust_copy` en/hi/mr, `private.listing_reviews`, `review_listing`, `withdraw_listing_review`, `private.trust_state`/`trust_overlay`, `get_trust_summary`; `public.public_profile_json` is now a wrapper over `private.public_profile_json_base` so other phases' projection changes survive)
- backend/supabase/tests/database/0041_truthful_trust_badges.test.sql
- backend/supabase/tests/database/0006_privileges.test.sql (one allowlist entry added: `get_trust_summary` is anon-callable by design; **outside my test range, needed**)
- backend/test/trust-copy.test.mjs, backend/test/trust-contract.test.mjs
- docs/trust-and-credentials.md (section 3); docs/contracts/column-classification.json

## Commands run (actual results, 2026-10-08)
`ok 0041_truthful_trust_badges.test.sql (33 tests)`; full `Tests: 38/38 files passed, 582/582 assertions passed. PASS`; Node `tests 41, pass 41, fail 0` (11 are `trust-copy`/`trust-contract`, including a mutation test proving the wording lint fails on an over-claim). Baseline in phase-088.md. Before editing 0006, the first run failed 1 assertion (`Extra records: (get_trust_summary)`), then passed.

## Truth table (verified in 0041, seen by a guest)
| Server evidence | Public `verification` |
|---|---|
| none | `{}` |
| `credentials` row approved but no decision | `{}` |
| phone approved + auth phone confirmed | `{phone}` |
| auth phone unconfirmed, or newer non-approved phone record | `{}` |
| + moderator review, content unchanged | `{phone, listing}` |
| description edited after review / review withdrawn / review past 1 year / listing suspended | `listing` absent |
| approved, unwithdrawn, in-validity credential decision (0040 test) | `credentials` present; absent after withdrawal or expiry |
Search, profile and city lists agree (same projection). Client payload with `verification`/`isVerified`/`trusted` keys: accepted as ordinary input, creates no badge; direct inserts into `verification_records` and direct profile updates are 42501.

## Acceptance
| Requirement | Result |
|---|---|
| Badge truth tables match server evidence | Pass (0041) |
| Localized scope and limits | Pass for presence in en/hi/mr (4 keys each) and Node lint; **translation accuracy BLOCKED on a native-speaker review** |
| No universal trusted/safe guarantee | Server wording passes (SQL + Node lint). The app still says "Find trusted help near you" (`lib/core/l10n/app_strings.dart` tagline) - Flutter follow-up |
| Expiry/withdrawal hit every display | Pass for profile/search/city list; app-side caches or the website may still hold an old badge until refresh - not testable here |
| Synthetic images / storage | not applicable to this phase |

## Flutter follow-ups (not done; lib/ was out of scope)
1. Read `verification` keys `phone`, `listing`, `credentials` (add `listing` to `VerificationKind`; unknown keys are currently ignored safely). Never derive a badge from anything else.
2. Replace "Credentials verified" with the server's "Credential checked" wording and call `get_trust_summary(providerId, locale)` for the explainer sheet (`verification_explainer_sheet.dart`); show `selfReported` text near description, languages, prices, hours and professional details.
3. Remove or reword the "trusted help" tagline and any "safe"/"trusted" claims; keep "Phone verified does not mean credentials verified".
4. Use app locale (en/hi/mr) when calling the summary; fall back to English text from the server.
5. Owner screens: show credential state from `get_credential_status` (including expired), not from `verification_records`.

## Assumptions and uncertainty
- The listing review covers display name and description only (photos join when 092 lands).
- Owner `verification` in `get_owner_profile` still derives from raw `verification_records` (so an owner may see "approved" for something not public, e.g. an expired credential); use `get_credential_status` in the app.

## Rollback / safe stop
Hide a category: stop awarding it (withdraw reviews/decisions), or ship a hotfix to `private.trust_overlay` omitting a key (forward-only migration).

## Next action
Native-speaker review of hi/mr copy; Flutter changes above; add the website's badge display from the same summary.
