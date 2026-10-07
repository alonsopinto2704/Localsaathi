// Supabase Auth "Send SMS" hook, pure logic (phases 043, 047).
//
// Auth calls this hook for EVERY code it wants to send, whoever asked for it
// (the app, curl, a script), so it is the one place spend can be controlled
// that direct Auth requests cannot bypass. Nothing here touches Deno APIs, so
// the same file runs under Deno (Edge Function) and Node (backend/test).
//
// Hard rules: the OTP and the phone number are never logged, never echoed in a
// response and never stored here. Responses carry only a stable machine code.

export type SendResult = "delivered" | "rejected" | "duplicate" | "timeout";

export interface SmsSender {
  send(args: { to: string; otp: string }): Promise<SendResult>;
}

export interface GateAnswer {
  allowed: boolean;
  reason?: string;
  retryAfterSeconds?: number;
}

export interface Gate {
  /** public.otp_send_gate: per-number, per-block and global limits + breaker. */
  check(phoneE164: string): Promise<GateAnswer>;
  /** public.otp_record_delivery: a counter only. */
  record(outcome: SendResult): Promise<void>;
}

export interface HookResponse {
  status: number;
  body: Record<string, unknown>;
}

const enc = new TextEncoder();

function b64decode(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64encode(bytes: ArrayBuffer): string {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Standard Webhooks signature check (what Supabase hooks use): header
 * `webhook-signature: v1,<base64 hmac-sha256(id.timestamp.body)>`, secret
 * `v1,whsec_<base64>`. Rejects timestamps more than `toleranceSeconds` away.
 */
export async function verifySignature(
  secret: string,
  headers: { id?: string | null; timestamp?: string | null; signature?: string | null },
  body: string,
  nowMs: number,
  toleranceSeconds = 300,
): Promise<boolean> {
  const { id, timestamp, signature } = headers;
  if (!secret || !id || !timestamp || !signature) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(nowMs / 1000 - ts) > toleranceSeconds) return false;
  const raw = secret.replace(/^v1,/, "").replace(/^whsec_/, "");
  let key: Uint8Array;
  try {
    key = b64decode(raw);
  } catch {
    return false;
  }
  const cryptoKey = await crypto.subtle.importKey(
    "raw", key as unknown as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = b64encode(await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(`${id}.${timestamp}.${body}`)));
  return signature.split(" ").some((part) => {
    const [version, sig] = part.split(",");
    return version === "v1" && !!sig && timingSafeEqual(sig, mac);
  });
}

export function withTimeout<T>(p: Promise<T>, ms: number, onTimeout: T): Promise<T> {
  return new Promise<T>((resolve) => {
    const timer = setTimeout(() => resolve(onTimeout), ms);
    p.then(
      (v) => { clearTimeout(timer); resolve(v); },
      () => { clearTimeout(timer); resolve(onTimeout); },
    );
  });
}

const fail = (status: number, code: string, message: string): HookResponse => ({
  status,
  body: { error: { http_code: status, message, code } },
});

export interface HookDeps {
  secret: string;
  gate: Gate;
  sender: SmsSender;
  nowMs: number;
  /** Auth gives hooks ~5 s; stay well inside it. */
  sendTimeoutMs?: number;
}

export async function handleSendSms(
  req: { body: string; headers: { id?: string | null; timestamp?: string | null; signature?: string | null } },
  deps: HookDeps,
): Promise<HookResponse> {
  if (!(await verifySignature(deps.secret, req.headers, req.body, deps.nowMs))) {
    return fail(401, "invalid_signature", "Request not authorised.");
  }
  let phone: string;
  let otp: string;
  try {
    const parsed = JSON.parse(req.body);
    const raw = String(parsed?.user?.phone ?? "");
    phone = raw.startsWith("+") ? raw : `+${raw}`;
    otp = String(parsed?.sms?.otp ?? "");
  } catch {
    return fail(400, "bad_request", "Malformed request.");
  }
  if (!/^\d{4,10}$/.test(otp)) return fail(400, "bad_request", "Malformed request.");

  // Spend control first: nothing is sent to a number the gate refuses, and the
  // refusal says nothing about whether the number has an account.
  const verdict = await deps.gate.check(phone);
  if (!verdict.allowed) {
    const paused = verdict.reason === "service_paused";
    return {
      status: paused ? 503 : 429,
      body: {
        error: {
          http_code: paused ? 503 : 429,
          code: verdict.reason ?? "rate_limited",
          message: paused ? "Sign-in codes are temporarily unavailable." : "Too many codes requested. Try again later.",
          ...(verdict.retryAfterSeconds ? { retry_after_seconds: verdict.retryAfterSeconds } : {}),
        },
      },
    };
  }

  const result = await withTimeout<SendResult>(
    deps.sender.send({ to: phone, otp }).catch((): SendResult => "rejected"),
    deps.sendTimeoutMs ?? 4000,
    "timeout",
  );
  await deps.gate.record(result).catch(() => {});

  switch (result) {
    case "delivered":
    case "duplicate": // provider already had this message: success for us
      return { status: 200, body: {} };
    case "timeout":
      return fail(504, "sms_timeout", "The code could not be sent in time. Try again.");
    default:
      return fail(502, "sms_rejected", "The code could not be sent. Try again later.");
  }
}

// ---------------------------------------------------------------- senders
/** Deterministic sender for staging/CI. Never contacts anything. */
export function createFakeSender(mode: SendResult | "hang" = "delivered"): SmsSender & { sent: number } {
  const sender = {
    sent: 0,
    send(): Promise<SendResult> {
      sender.sent++;
      return mode === "hang" ? new Promise(() => {}) : Promise.resolve(mode);
    },
  };
  return sender;
}

export interface HttpSenderConfig {
  /** Build the provider request. Secrets come from env, never from code. */
  buildRequest(args: { to: string; otp: string }): { url: string; init: RequestInit };
  /** Map the provider's answer onto our four outcomes. */
  parseResponse(status: number, bodyText: string): SendResult;
  timeoutMs?: number;
}

/**
 * Generic HTTP adapter. The provider-specific request/response mapping lives in
 * `HttpSenderConfig` (to be written and verified against the chosen India
 * provider's current docs and DLT template at provisioning time; see
 * docs/sms-provider-evaluation.md). Timeouts abort the request.
 */
export function createHttpSender(cfg: HttpSenderConfig, fetchImpl: typeof fetch = fetch): SmsSender {
  return {
    async send(args) {
      const { url, init } = cfg.buildRequest(args);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), cfg.timeoutMs ?? 3500);
      try {
        const res = await fetchImpl(url, { ...init, signal: controller.signal });
        return cfg.parseResponse(res.status, await res.text());
      } catch (e) {
        return (e as { name?: string })?.name === "AbortError" ? "timeout" : "rejected";
      } finally {
        clearTimeout(timer);
      }
    },
  };
}
