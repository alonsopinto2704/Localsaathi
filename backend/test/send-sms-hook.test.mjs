// Phases 043/047: Send SMS hook logic against fake senders and a fake gate.
// No network, no provider account, no real number: every phone is synthetic.
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { test } from 'node:test';
import {
  createFakeSender, createHttpSender, handleSendSms, verifySignature, withTimeout,
} from '../supabase/functions/send-sms-hook/logic.ts';
import { parseProviderResponse, providerConfigFromEnv } from '../supabase/functions/send-sms-hook/provider.ts';

const SECRET_BYTES = Buffer.from('synthetic-test-secret-not-real!!');
const SECRET = `v1,whsec_${SECRET_BYTES.toString('base64')}`;
const NOW = Date.parse('2026-10-07T10:00:00Z');
const PHONE = '919000012345'; // GoTrue form, synthetic
const OTP = '482913';

const body = (over = {}) => JSON.stringify({ user: { id: 'u1', phone: PHONE }, sms: { otp: OTP }, ...over });
function signed(b, { id = 'msg_1', ts = NOW / 1000, secret = SECRET_BYTES } = {}) {
  const sig = createHmac('sha256', secret).update(`${id}.${ts}.${b}`).digest('base64');
  return { body: b, headers: { id, timestamp: String(ts), signature: `v1,${sig}` } };
}
const gate = (answer = { allowed: true }) => {
  const g = { checked: [], recorded: [], check: async (p) => (g.checked.push(p), answer), record: async (o) => void g.recorded.push(o) };
  return g;
};

test('a correctly signed request is delivered through the sender', async () => {
  const g = gate();
  const sender = createFakeSender('delivered');
  const res = await handleSendSms(signed(body()), { secret: SECRET, gate: g, sender, nowMs: NOW });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, {});
  assert.equal(sender.sent, 1);
  assert.deepEqual(g.checked, ['+919000012345'], 'the gate sees an E.164 number');
  assert.deepEqual(g.recorded, ['delivered']);
});

test('bad, missing, stale and replayed-timestamp signatures are refused before anything else', async () => {
  const sender = createFakeSender();
  const g = gate();
  const deps = { secret: SECRET, gate: g, sender, nowMs: NOW };
  const good = signed(body());
  const cases = {
    'wrong secret': signed(body(), { secret: Buffer.from('another-secret-another-secret-!!') }),
    'tampered body': { ...good, body: body({ sms: { otp: '000000' } }) },
    'missing header': { body: good.body, headers: { ...good.headers, signature: null } },
    'stale timestamp': signed(body(), { ts: NOW / 1000 - 3600 }),
    'future timestamp': signed(body(), { ts: NOW / 1000 + 3600 }),
  };
  for (const [name, req] of Object.entries(cases)) {
    const res = await handleSendSms(req, deps);
    assert.equal(res.status, 401, name);
  }
  assert.equal(sender.sent, 0);
  assert.equal(g.checked.length, 0);
  assert.equal(await verifySignature('', good.headers, good.body, NOW), false, 'empty secret never verifies');
});

test('the gate runs first: refusal is 429/503, nothing is sent, and it never mentions accounts', async () => {
  const sender = createFakeSender();
  for (const [verdict, status] of [
    [{ allowed: false, reason: 'number_limit', retryAfterSeconds: 120 }, 429],
    [{ allowed: false, reason: 'block_limit', retryAfterSeconds: 600 }, 429],
    [{ allowed: false, reason: 'unsupported_number' }, 429],
    [{ allowed: false, reason: 'service_paused', retryAfterSeconds: 3600 }, 503],
  ]) {
    const res = await handleSendSms(signed(body()), { secret: SECRET, gate: gate(verdict), sender, nowMs: NOW });
    assert.equal(res.status, status);
    assert.doesNotMatch(JSON.stringify(res.body), /account|registered|profile|exists/i);
  }
  assert.equal(sender.sent, 0);
});

test('provider outcomes: duplicate is success; rejection, timeout and thrown errors are generic failures', async () => {
  const run = (sender) => handleSendSms(signed(body()), { secret: SECRET, gate: gate(), sender, nowMs: NOW, sendTimeoutMs: 30 });
  assert.equal((await run(createFakeSender('duplicate'))).status, 200);
  assert.equal((await run(createFakeSender('rejected'))).status, 502);
  assert.equal((await run(createFakeSender('hang'))).status, 504, 'a provider that never answers times out');
  const thrower = { send: async () => { throw new Error(`boom ${OTP} ${PHONE}`); } };
  const res = await run(thrower);
  assert.equal(res.status, 502);
  assert.doesNotMatch(JSON.stringify(res.body), new RegExp(`${OTP}|${PHONE}|boom`));
});

test('responses and logs never contain the code or the number', async () => {
  const logged = [];
  const orig = { log: console.log, error: console.error, warn: console.warn };
  console.log = console.error = console.warn = (...a) => logged.push(a.join(' '));
  try {
    for (const mode of ['delivered', 'rejected', 'duplicate']) {
      const res = await handleSendSms(signed(body()), { secret: SECRET, gate: gate(), sender: createFakeSender(mode), nowMs: NOW });
      logged.push(JSON.stringify(res));
    }
  } finally {
    Object.assign(console, orig);
  }
  assert.doesNotMatch(logged.join('\n'), new RegExp(`${OTP}|${PHONE}|9000012345`));
});

test('malformed payloads are 400s', async () => {
  const sender = createFakeSender();
  for (const b of ['not json', body({ sms: { otp: 'abc' } }), body({ sms: {} })]) {
    const res = await handleSendSms(signed(b), { secret: SECRET, gate: gate(), sender, nowMs: NOW });
    assert.equal(res.status, 400);
  }
  assert.equal(sender.sent, 0);
});

test('withTimeout resolves with the fallback and clears when the promise wins', async () => {
  assert.equal(await withTimeout(new Promise(() => {}), 10, 'late'), 'late');
  assert.equal(await withTimeout(Promise.resolve('fast'), 1000, 'late'), 'fast');
  assert.equal(await withTimeout(Promise.reject(new Error('x')), 1000, 'fallback'), 'fallback');
});

test('HTTP adapter fixtures: success, rejection, duplicate, server error, abort', async () => {
  const cfg = providerConfigFromEnv((k) => ({
    SMS_PROVIDER_URL: 'https://sms.example.invalid/otp', SMS_PROVIDER_AUTH_KEY: 'k', SMS_DLT_TEMPLATE_ID: 't',
  })[k] ?? '');
  assert.ok(cfg);
  const respond = (status, bodyText) => async (_url, init) => {
    const sent = JSON.parse(init.body);
    assert.equal(sent.mobile, '919000012345', 'no leading plus on the wire');
    assert.equal(init.headers.authkey, 'k');
    return new Response(bodyText, { status });
  };
  const send = (fetchImpl) => createHttpSender(cfg, fetchImpl).send({ to: '+919000012345', otp: OTP });
  assert.equal(await send(respond(200, '{"type":"success"}')), 'delivered');
  assert.equal(await send(respond(200, '{"type":"error","message":"template mismatch"}')), 'rejected');
  assert.equal(await send(respond(400, '{"message":"bad number"}')), 'rejected');
  assert.equal(await send(respond(200, '{"message":"OTP already sent"}')), 'duplicate');
  assert.equal(await send(respond(409, '')), 'duplicate');
  assert.equal(await send(respond(503, 'upstream')), 'rejected');
  const aborting = async (_u, init) => new Promise((_, rej) => init.signal.addEventListener('abort', () => rej(Object.assign(new Error('a'), { name: 'AbortError' }))));
  assert.equal(await createHttpSender({ ...cfg, timeoutMs: 20 }, aborting).send({ to: '+919000012345', otp: OTP }), 'timeout');
  assert.equal(await send(async () => { throw new TypeError('network down'); }), 'rejected');
});

test('live mode refuses incomplete or non-https provider configuration', () => {
  const env = (o) => (k) => o[k] ?? '';
  assert.equal(providerConfigFromEnv(env({})), null);
  assert.equal(providerConfigFromEnv(env({ SMS_PROVIDER_URL: 'http://x', SMS_PROVIDER_AUTH_KEY: 'k', SMS_DLT_TEMPLATE_ID: 't' })), null);
  assert.equal(providerConfigFromEnv(env({ SMS_PROVIDER_URL: 'https://x', SMS_PROVIDER_AUTH_KEY: '', SMS_DLT_TEMPLATE_ID: 't' })), null);
  assert.equal(parseProviderResponse(200, 'not json'), 'delivered');
});
