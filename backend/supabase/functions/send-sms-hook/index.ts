// Supabase Auth "Send SMS" hook (phases 043, 047). Deploy:
//   supabase functions deploy send-sms-hook --no-verify-jwt
// (Auth signs the call with the Standard Webhooks secret instead of a JWT; the
// signature is verified in logic.ts.) Then enable [auth.hook.send_sms] and set:
//   supabase secrets set SEND_SMS_HOOK_SECRET=<v1,whsec_... from the dashboard>
//   supabase secrets set SMS_MODE=live|fake
//   (live) SMS_PROVIDER_URL, SMS_PROVIDER_AUTH_KEY, SMS_DLT_TEMPLATE_ID
//
// Fails closed: with no secret, no mode, or "live" without provider settings,
// every request is answered 503 and nothing is sent. "fake" never sends an SMS
// and is refused unless SMS_ALLOW_FAKE=true (a staging-only switch).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createFakeSender, createHttpSender, handleSendSms, type Gate, type SmsSender } from "./logic.ts";
import { providerConfigFromEnv } from "./provider.ts";

const env = (k: string) => Deno.env.get(k) ?? "";

function buildSender(): SmsSender | null {
  const mode = env("SMS_MODE");
  if (mode === "fake") return env("SMS_ALLOW_FAKE") === "true" ? createFakeSender("delivered") : null;
  if (mode === "live") {
    const cfg = providerConfigFromEnv(env);
    return cfg ? createHttpSender(cfg) : null;
  }
  return null;
}

const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
  auth: { persistSession: false },
});

const gate: Gate = {
  async check(phone) {
    const { data, error } = await admin.rpc("otp_send_gate", { p_phone: phone });
    // If the gate cannot answer, do not send: unbounded spend is the failure
    // this exists to prevent.
    if (error || !data) return { allowed: false, reason: "service_paused" };
    return { allowed: !!data.allowed, reason: data.reason, retryAfterSeconds: data.retryAfterSeconds };
  },
  async record(outcome) {
    await admin.rpc("otp_record_delivery", { p_outcome: outcome });
  },
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const sender = buildSender();
  const secret = env("SEND_SMS_HOOK_SECRET");
  if (!sender || !secret) {
    console.error("send-sms-hook: not configured; refusing to send");
    return Response.json(
      { error: { http_code: 503, code: "not_configured", message: "Sign-in codes are temporarily unavailable." } },
      { status: 503 },
    );
  }
  const body = await req.text();
  const result = await handleSendSms(
    {
      body,
      headers: {
        id: req.headers.get("webhook-id"),
        timestamp: req.headers.get("webhook-timestamp"),
        signature: req.headers.get("webhook-signature"),
      },
    },
    { secret, gate, sender, nowMs: Date.now() },
  );
  // Aggregate outcome only: never the number, the code or the provider body.
  console.log(`send-sms-hook: status=${result.status}`);
  return Response.json(result.body, { status: result.status });
});
