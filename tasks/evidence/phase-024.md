# Phase 024 — Definer-function hardening

**Status:** In review. Verified locally (PGlite); HTTP verification Blocked (phases 006/039). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Every SECURITY DEFINER routine must validate its caller, use qualified names and a safe `search_path`, and bound its parameters. Admin checks must rely on server-controlled facts.

## Changed paths
- Migration `…13`: sets `search_path = ''` on every 0008/0012 definer function and on the invoker JSON helpers.
- Migrations `…14`–`…19`: every new or replaced function is created with `search_path = ''`.

## Audit of all definer functions
| Group | Caller check | Admin source | Bounds |
|---|---|---|---|
| Discovery | Public data, gated by `is_publicly_listed` | — | Phase 034 limits |
| Owner writes | `private.lock_owned_profile`: owner only, row lock, optional revision | — | `validate_profile_payload` |
| Admin | `is_admin()`: a row in `public.app_admins`, which has no client write path. Never the JWT `user_metadata`. | Table | Reason required; audit row |
| Guest writes | Target must be listed | — | Lengths, rate tokens |
| `handle_auth_phone_change` | Trigger on `auth.users` only | — | E.164 normalization |

Further checks:
- **Object shadowing.** With `search_path=''`, an object a caller creates cannot be resolved. API roles also have no CREATE on `public` (asserted).
- **Forged identity.** `auth.uid()` comes from the JWT that PostgREST verifies. No function trusts a client-supplied user id, phone or role. `request_city` derives the phone from the profile, never from input.
- **Admin bypass removed (reviewer change).** `lock_owned_profile` first let admins through the owner RPCs, which allowed silent, unaudited edits to a provider's content. It is now owner-only, and admins use the audited moderation RPCs. The worker on phase 039 flagged this.
- **Error prefixes.** 0012's bare `validation:` prefix is replaced by `validation_failed:` (`set_map_location`, `record_terms_acceptance`, redefined in `…17`).

## Verification
- `0006` asserts that every definer function's `proconfig` contains `search_path=""`.
- Owner, other-owner and admin denials are covered in suites `0008`–`0010` and `0013`.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Rollback
Disable an affected RPC by revoking its EXECUTE grant until it is verified.
