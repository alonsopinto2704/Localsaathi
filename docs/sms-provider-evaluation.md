# SMS provider evaluation for India OTP (phase 043)

**Status:** research and adapter contract only. **No provider account exists, no
paid message has been sent, and nothing below was verified against a live
vendor account.** Statements about carriers, prices and rules come from general
knowledge of the Indian market and must be re-checked against current vendor
quotes and the TRAI/operator DLT portals before anything is provisioned.

## What the app needs

Phone OTP sign-in for providers on Android (Mumbai first). Roughly one code per
sign-in, a few per recovery. Delivery speed matters (users wait on the screen),
and spend must be capped (phase 047).

## India-specific constraints (confirm before provisioning)

| Topic | What to confirm | Why it matters |
|---|---|---|
| DLT registration | A registered **principal entity**, an approved **sender ID (header)** and an approved **OTP content template** with its **template ID** on an operator DLT portal. | Commercial SMS that does not match a registered template is blocked by carriers. Lead time is days to weeks and needs the operator's real business documents (see the placeholder legal details in the plan). |
| Telemarketer chain | The chosen aggregator must be bound to the entity/template on the DLT chain. | Without it, accepted API calls can still be dropped downstream. |
| Template text | The SMS must contain only the registered wording plus the code variable. | Supabase's default message text cannot be used; the Send SMS hook sends the code as a template variable. |
| Delivery receipts | Whether the vendor returns DLRs and how quickly. | Needed to tell "slow" from "dropped" (phase 046 messaging). |
| Pricing | Per-message price for domestic OTP, minimums, template/sender fees, expiry of credits. | Sets the real cost of an attack: with the default global ceiling of 1,500 codes a day the worst-case daily spend is 1,500 x the per-message price (order of a few hundred rupees at domestic aggregator rates, several times that on international routes; get a written quote). |
| Outages | Status page, failover option, support SLA. | The hook fails closed (no code, clear error); a second provider is a later option, not a launch need. |
| Data | Where message logs live and for how long. | Message content contains the code; ask for the shortest retention. |

## Options

| Option | Fits Supabase how | Notes |
|---|---|---|
| Supabase built-in Twilio / Twilio Verify / Vonage / MessageBird | Configured in the dashboard, no code | Simple, but international routes are costlier and DLT template binding is the buyer's problem; confirm India sender/template handling before choosing. |
| Indian aggregator (MSG91, Gupshup, Kaleyra and similar) via the **Send SMS hook** | `[auth.hook.send_sms]` -> `send-sms-hook` Edge Function (this repo) | Natural DLT fit. The hook is also where spend control lives, so this is the recommended path regardless of vendor. |
| Firebase phone auth | Would replace Supabase Auth phone sign-in | Rejected: breaks the one-account-per-verified-number model enforced from `auth.users` (backend-contract section 2). |

**Recommendation:** Send SMS hook + one DLT-capable Indian aggregator, chosen
after at least two written quotes. This is a product-owner decision (cost,
vendor relationship); the code does not depend on which vendor wins.

## What is built (all local, fake-backed)

* `backend/supabase/functions/send-sms-hook/` verifies the Standard Webhooks
  signature, calls `public.otp_send_gate` (limits and circuit breaker, migration
  0024), then sends through an `SmsSender`.
* Senders: `createFakeSender` (staging/CI, never sends) and
  `createHttpSender` with a provider mapping in `provider.ts`. **The mapping's
  field names are a placeholder shape**, not any vendor's documented API; it is
  covered by fixtures for delivery success, rejection, duplicate, 5xx and
  timeout so a change of meaning is a test failure.
* Timeouts: the sender aborts after 3.5 s and the hook answers after 4 s,
  inside the roughly five seconds Auth allows a hook. A timeout is reported as
  a failure, never as success; a late delivery is harmless (the user can ask
  again after the 60 s cooldown and the older code still works until it
  expires).
* Fail closed: no `SEND_SMS_HOOK_SECRET`, no `SMS_MODE`, `SMS_MODE=fake`
  without `SMS_ALLOW_FAKE=true`, or `live` without provider settings all answer
  503 and send nothing.

## Secret ownership and setup (when an account exists)

| Secret | Owner | Where |
|---|---|---|
| `SEND_SMS_HOOK_SECRET` (`v1,whsec_...`) | Backend/security engineer | Generated in the Supabase dashboard when the hook is enabled; `supabase secrets set`. Never in `config.toml` (checked by `check-identity-config.mjs`). |
| `SMS_PROVIDER_AUTH_KEY` | Backend/security engineer | `supabase secrets set`; rotate on staff change. |
| `SMS_DLT_TEMPLATE_ID`, `SMS_PROVIDER_URL` | Product owner supplies, backend sets | `supabase secrets set`. |

Staging: deploy with `SMS_MODE=fake` and `SMS_ALLOW_FAKE=true` first (exercises
the gate and hook end to end without any message), then switch to `live` with
a DLT-approved template and a small prepaid balance.

## Open items (need a human or an account)

1. Choose the vendor and obtain DLT approvals (owner; legal details required).
2. Replace `provider.ts` mapping with the vendor's real request/response and
   re-run the fixtures with the vendor's documented success/error bodies.
3. Send the first real staging OTPs to isolated test numbers and record
   delivery latency (phase 060 evidence, not claimed here).
