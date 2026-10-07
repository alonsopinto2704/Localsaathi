# Phase 032 — Consent withdrawal propagation

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Revoking phone or WhatsApp consent must change publication and contact eligibility on every path, with private, versioned consent events.

## Changed paths
- Migration `…15`: `private.apply_consent`, `public.record_consent` and the trigger rules.
- Migration `…16`: the public JSON gates contact fields on consent.
- Migration `…17`:
  - `update_profile_full` routes consent fields through `apply_consent`. Before, it flipped them **without recording anything**.
  - `set_map_location` records `withdrawn_at`.
  - The owner's direct consent INSERT policy is dropped.

## Rules
| Consent withdrawn | Effect |
|---|---|
| `display_phone_number` | `phone_display_consented=false`. A published listing is auto-**paused**, WhatsApp is forced off, and `phoneE164` is null in any public JSON. The listing stays paused until the owner consents again and republishes. |
| `whatsapp_contact` | `whatsapp_enabled=false`. Granting it requires phone consent (`consent_required`). |
| `public_profile` | The listing is paused. |
| `show_map_location` | Coordinates are deleted (unchanged since 0012). The event is recorded with `withdrawn_at`. |

Every change appends a `consent_records` row with `granted`, `wording_version` and `withdrawn_at` (a CHECK keeps `withdrawn_at` only on withdrawals). Clients can no longer insert consent rows directly, so history cannot be forged.

## Beyond the database
- **Caches and AI.** None exist yet.
  - The website (phase 141+) must render provider pages live, or purge on revoke (phase 015 correction).
  - AI retrieval (phase 181+) must read through `public_profile_json`.
- **Unavoidable limit.** A number someone has already seen or downloaded cannot be recalled.

## Verification
- `0009`:
  - withdrawal pauses the listing;
  - WhatsApp is turned off;
  - a consent row is written with `withdrawn_at`;
  - `get_public_profile` returns null;
  - enabling WhatsApp without phone consent returns `consent_required`.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.
