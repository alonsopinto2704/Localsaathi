// Provider mapping for the live SMS sender (phase 043).
//
// UNVERIFIED AGAINST ANY LIVE ACCOUNT. No provider account exists yet (see
// docs/sms-provider-evaluation.md). This is a generic JSON-over-HTTPS shape
// (auth key header, DLT template id, mobile, otp) that most Indian OTP APIs
// resemble; the field names below MUST be reconciled with the chosen
// provider's current documentation, and the DLT-registered template, before
// SMS_MODE=live is used. Its response mapping is covered by fixtures
// (backend/test/send-sms-hook.test.mjs) so a change in meaning is a test
// failure, not a surprise in production.
import type { HttpSenderConfig, SendResult } from "./logic.ts";

export function parseProviderResponse(status: number, bodyText: string): SendResult {
  if (status >= 500) return "rejected";
  let body: { type?: string; message?: string } = {};
  try {
    body = JSON.parse(bodyText);
  } catch { /* non-JSON body: decide on status alone */ }
  if (status === 409 || /already\s*(sent|exists)|duplicate/i.test(String(body.message ?? ""))) return "duplicate";
  if (status >= 200 && status < 300 && body.type !== "error") return "delivered";
  return "rejected";
}

export function providerConfigFromEnv(env: (k: string) => string): HttpSenderConfig | null {
  const url = env("SMS_PROVIDER_URL");
  const authKey = env("SMS_PROVIDER_AUTH_KEY");
  const templateId = env("SMS_DLT_TEMPLATE_ID");
  if (!url.startsWith("https://") || !authKey || !templateId) return null;
  return {
    timeoutMs: 3500,
    buildRequest: ({ to, otp }) => ({
      url,
      init: {
        method: "POST",
        headers: { "content-type": "application/json", authkey: authKey },
        body: JSON.stringify({ template_id: templateId, mobile: to.replace(/^\+/, ""), otp }),
      },
    }),
    parseResponse: parseProviderResponse,
  };
}
