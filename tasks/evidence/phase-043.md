# Phase 043 Evidence - SMS provider contract

**Status:** Done locally (provider account and DLT approval not provisioned: needs the product owner and a vendor) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Research India delivery/DLT/pricing, and prepare the Supabase Send SMS hook with secret ownership, timeouts and a fake sender, without provisioning anything or sending a paid message.

## Changed paths
- backend/supabase/functions/send-sms-hook/logic.ts
- backend/supabase/functions/send-sms-hook/provider.ts
- backend/supabase/functions/send-sms-hook/index.ts
- backend/supabase/config.toml (`[auth.hook.send_sms]` disabled by default, `[auth.sms]` otp_length/expiry/max_frequency)
- docs/sms-provider-evaluation.md
- backend/test/send-sms-hook.test.mjs
- backend/README.md

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Adapter fixtures cover delivery success, rejection, duplication, timeout | send-sms-hook.test.mjs: delivered/rejected/duplicate/hang/throw outcomes; HTTP adapter fixtures: success, error body, 400, "already sent", 409, 503, abort, network error | Pass (9 tests) |
| Signature verification and replay window | Standard Webhooks HMAC: wrong secret, tampered body, missing header, stale (-1h) and future (+1h) timestamps all 401; nothing sent | Pass |
| No code/number in responses or logs | test captures console + responses for three outcomes and greps for the OTP and number | Pass |
| Fail closed | index.ts answers 503 without secret/mode; `fake` needs `SMS_ALLOW_FAKE=true`; `live` needs https URL, key and template id (tested via `providerConfigFromEnv`) | Pass (logic); index.ts is Deno-only and was not executed |
| Research result | docs/sms-provider-evaluation.md (DLT entity/header/template/chain, pricing questions, options, recommendation, secret ownership) | Written; vendor facts unverified today |

## Commands run for this phase (actual results)
- `node --test test/send-sms-hook.test.mjs` (in backend/) -> 9 tests, 9 pass, 0 fail

## Verification run (2026-10-07, after the last change of phases 041-060)
| Command | Actual result |
|---|---|
| `npm --prefix backend test` | `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, then Node: `tests 27, pass 27, fail 0` |
| `C:\Users\alonso\flutter\bin\flutter.bat test --no-pub -r failures-only` | `+360: All tests passed!` (0 skipped; the tree also contains concurrent phase-101 test work; the five identity files added by phases 041-060 contribute +110) |
| `flutter analyze` | 73 issues, all `info`; 0 errors, 0 warnings; none in files added by these phases |
| `node backend/scripts/rehearse-migrations.mjs` | `Rehearsal: 26/26 checks passed (2000 synthetic providers).` (upgrade 0001-0012 -> 0029) |
| `node backend/scripts/http-authz-pack.mjs --self-test` | `SELF-TEST PASSED` (the live run is still blocked: phases 006/039) |
| `node backend/scripts/check-identity-config.mjs` | `Identity config: PASS` |

## Assumptions and remaining uncertainty
- **Blocked externally:** no SMS vendor account, DLT registration or Supabase project exists. `provider.ts` uses a generic request shape (auth-key header, template id, mobile, otp) that is NOT any vendor's documented API; it must be reconciled at provisioning. This is stated in the file and in the evaluation doc.
- Market facts (DLT, price ranges) come from general knowledge and were not re-verified by web research in this run.
- `index.ts` (Deno, `jsr:@supabase/supabase-js`) was not run; its logic lives in `logic.ts`, which is.
- The hook timeout assumption (about 5 s) should be confirmed in Supabase's current docs; the code answers within 4 s regardless.

## Rollback / safe stop
Leave `[auth.hook.send_sms] enabled = false` (the default). Staging routes to the fake sender with `SMS_MODE=fake` + `SMS_ALLOW_FAKE=true`.

## Next action
Product owner: pick a vendor and complete DLT. Then replace `provider.ts` mapping, deploy the function, set secrets, enable the hook on a staging project.
