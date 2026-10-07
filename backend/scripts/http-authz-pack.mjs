#!/usr/bin/env node
// Phase 039: HTTP authorization regression pack. Plain Node 24 (global fetch).
//
// Runs against a REAL Supabase project's PostgREST (/rest/v1) and Storage
// (/storage/v1) with real role tokens: what a hostile client could actually
// send. Complements the SQL-level suites (PGlite) that cannot see the HTTP
// layer: API grants, schema exposure, Storage policies.
//
// Env:  SUPABASE_URL SUPABASE_ANON_KEY OWNER_JWT OTHER_JWT ADMIN_JWT
//       OWNER_PROFILE_ID HIDDEN_PROFILE_ID (draft/suspended) OWNER_USER_ID
//       optional: SEARCH_CITY_ID (mh-mumbai) SEARCH_LOCALITY_ID (mh-mumbai-andheri-west)
// Refuses to run if SUPABASE_SERVICE_ROLE_KEY is set or any token is service_role:
// customer authorization is never tested with a privileged key.
//
// DESTRUCTIVE-IF-BROKEN: the OTHER_JWT delete_listing probe would delete
// OWNER_PROFILE_ID if the authz it checks had regressed. Use a disposable project.
//
//   node backend/scripts/http-authz-pack.mjs
//   node backend/scripts/http-authz-pack.mjs --self-test   (no network, no env)

// Keys public_profile_json() (0016) emits. Anything else is a leak.
export const PUBLIC_KEYS = new Set([
  'id', 'displayName', 'baseCityId', 'baseLocalityId', 'status', 'createdAt', 'updatedAt',
  'phoneE164', 'phoneDisplayConsented', 'whatsappEnabled', 'categoryIds', 'serviceAreas',
  'description', 'languages', 'workingHours', 'photos', 'startingPrices', 'healthcareDetails',
  'homeVisits', 'availability', 'verification', 'pinCodes', 'mapLocation',
]);
const FORBIDDEN = new Set(['user_id', 'userId', 'moderationStatus', 'suspensionReason', 'revision', 'isPubliclyListed']);

// Pure: returns a list of violations for a search_providers response body.
export function checkSearchKeys(body) {
  const bad = [];
  const items = body?.items;
  if (!Array.isArray(items)) return ['response has no items array'];
  if (items.length === 0) return ['no listed providers returned: seed at least one published, consented listing'];
  const walk = (v, path) => {
    if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${path}[${i}]`));
    else if (v && typeof v === 'object') {
      for (const [k, x] of Object.entries(v)) {
        if (FORBIDDEN.has(k) || k.includes('_')) bad.push(`forbidden key ${path}.${k}`);
        walk(x, `${path}.${k}`);
      }
    }
  };
  items.forEach((it, i) => {
    const p = it?.provider;
    if (!p || typeof p !== 'object') return bad.push(`items[${i}].provider missing`);
    for (const k of Object.keys(p)) if (!PUBLIC_KEYS.has(k)) bad.push(`items[${i}].provider.${k} not in allowlist`);
    walk(p, `items[${i}].provider`);
    if (p.phoneE164 != null && (p.phoneDisplayConsented !== true || !String(p.phoneE164).startsWith('+')))
      bad.push(`items[${i}] phoneE164 exposed without consent or without '+'`);
    const m = p.mapLocation;
    if (m && [m.lat, m.lng].some((n) => String(n).split('.')[1]?.length > 2)) bad.push(`items[${i}] mapLocation not rounded to 2 dp`);
  });
  return bad;
}

if (process.argv.includes('--self-test')) {
  const clean = { items: [{ isSponsored: false, provider: { id: 'x', displayName: 'A', phoneE164: '+919876543210', phoneDisplayConsented: true, mapLocation: { lat: 19.12, lng: 72.84 } } }] };
  const leaky = { items: [{ isSponsored: false, provider: { id: 'x', displayName: 'A', phone_e164: '+919876543210', moderationStatus: 'active' } }] };
  const results = [
    { name: 'search keys: clean response', expect: 'PASS', got: checkSearchKeys(clean).length ? 'FAIL' : 'PASS' },
    { name: 'search keys: injected phone_e164 + moderationStatus', expect: 'FAIL', got: checkSearchKeys(leaky).length ? 'FAIL' : 'PASS' },
  ];
  for (const r of results) console.log(`${r.got === r.expect ? 'OK ' : 'BAD'}  ${r.name}: pack reports ${r.got} (expected ${r.expect})`);
  console.log('violations found in leaky fixture:', checkSearchKeys(leaky));
  const ok = results.every((r) => r.got === r.expect);
  console.log(ok ? 'SELF-TEST PASSED: a forbidden-field regression makes the pack fail' : 'SELF-TEST FAILED');
  process.exit(ok ? 0 : 1);
}

// ---------------------------------------------------------------------------
const env = process.env;
if (env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Refusing to run: SUPABASE_SERVICE_ROLE_KEY is set. Never test customer authorization with a service-role key; unset it.');
  process.exit(2);
}
const need = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'OWNER_JWT', 'OTHER_JWT', 'ADMIN_JWT', 'OWNER_PROFILE_ID', 'HIDDEN_PROFILE_ID', 'OWNER_USER_ID'];
const missing = need.filter((k) => !env[k]);
if (missing.length) { console.error('Missing env: ' + missing.join(', ')); process.exit(2); }

const role = (jwt) => {
  try { return JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString()).role; } catch { return 'undecodable'; }
};
for (const k of ['SUPABASE_ANON_KEY', 'OWNER_JWT', 'OTHER_JWT', 'ADMIN_JWT']) {
  const r = role(env[k]);
  if (r === 'service_role') { console.error(`Refusing to run: ${k} is a service_role token.`); process.exit(2); }
  if (r === 'undecodable') { console.error(`Refusing to run: ${k} is not a decodable JWT.`); process.exit(2); }
}

const base = env.SUPABASE_URL.replace(/\/$/, '');
const { SUPABASE_ANON_KEY: ANON, OWNER_JWT, OTHER_JWT, ADMIN_JWT, OWNER_PROFILE_ID: OWNER_PID, HIDDEN_PROFILE_ID: HIDDEN_PID, OWNER_USER_ID } = env;
const CITY = env.SEARCH_CITY_ID ?? 'mh-mumbai';
const LOC = env.SEARCH_LOCALITY_ID ?? 'mh-mumbai-andheri-west';

async function call(method, path, { jwt, body, headers = {}, raw } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { apikey: ANON, authorization: `Bearer ${jwt ?? ANON}`, ...(body !== undefined && !raw ? { 'content-type': 'application/json' } : {}), ...headers },
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { /* non-JSON */ }
  return { status: res.status, text, json };
}
const rpc = (fn, args, jwt) => call('POST', `/rest/v1/rpc/${fn}`, { jwt, body: args });
const isErr = (r) => r.status >= 400 && r.status < 500;
const msg = (r) => `${r.json?.message ?? ''} ${r.json?.code ?? ''} ${r.text}`;

const checks = [];
const add = (name, expected, fn) => checks.push({ name, expected, fn });
// fn returns [ok, detail]
const errCheck = (name, run) => add(name, 'HTTP 4xx error', async () => { const r = await run(); return [isErr(r), `status ${r.status} ${r.json?.code ?? ''}`]; });

for (const t of ['provider_profiles', 'consent_records', 'verification_records', 'reports', 'engagement_events', 'app_admins'])
  errCheck(`anon GET ${t} is denied (0 rows is not acceptable)`, () => call('GET', `/rest/v1/${t}?select=*`));

const junk = { provider_id: OWNER_PID };
errCheck('anon POST reports denied', () => call('POST', '/rest/v1/reports', { body: { ...junk, reason: 'spam' } }));
errCheck('anon POST engagement_events denied', () => call('POST', '/rest/v1/engagement_events', { body: { ...junk, type: 'profile_view' } }));
errCheck('anon POST city_requests denied', () => call('POST', '/rest/v1/city_requests', { body: { city_name: 'Authzville' } }));

errCheck('anon rpc provider_profile_json denied', () => rpc('provider_profile_json', { p_id: OWNER_PID }));
errCheck('anon rpc public_profile_json denied', () => rpc('public_profile_json', { p_id: OWNER_PID }));
errCheck('anon rpc is_publicly_listed denied', () => rpc('is_publicly_listed', { p_id: OWNER_PID }));
errCheck('anon rpc admin_audit_events denied', () => rpc('admin_audit_events', {}));

add('anon search_providers returns only allowlisted keys, no leaks', 'status 200, 0 violations', async () => {
  const r = await rpc('search_providers', { p_city_id: CITY, p_locality_id: LOC, p_limit: 50 });
  if (r.status !== 200) return [false, `status ${r.status} ${r.text.slice(0, 120)}`];
  const v = checkSearchKeys(r.json);
  return [v.length === 0, v.length ? v.slice(0, 5).join('; ') : `${r.json.items.length} items clean`];
});
add('anon get_public_profile(HIDDEN) is null', 'status 200, body null', async () => {
  const r = await rpc('get_public_profile', { p_id: HIDDEN_PID });
  return [r.status === 200 && r.json === null, `status ${r.status} body ${r.text.slice(0, 80)}`];
});

for (const [fn, args] of [
  ['update_profile_full', { p_profile_id: OWNER_PID, p_patch: { description: 'authz probe' } }],
  ['set_listing_status', { p_profile_id: OWNER_PID, p_status: 'paused' }],
  ['delete_listing', { p_profile_id: OWNER_PID }], // last: destructive if authz is broken
]) add(`OTHER_JWT rpc ${fn} on owner profile -> not_owner`, "error containing 'not_owner'", async () => {
  const r = await rpc(fn, args, OTHER_JWT);
  return [isErr(r) && msg(r).includes('not_owner'), `status ${r.status} ${(r.json?.message ?? r.text).slice(0, 100)}`];
});

errCheck('OWNER_JWT direct PATCH provider_profiles denied', () =>
  call('PATCH', `/rest/v1/provider_profiles?id=eq.${OWNER_PID}`, { jwt: OWNER_JWT, body: { status: 'published' }, headers: { prefer: 'return=representation' } }));
add('OWNER_JWT rpc get_owner_profile (own) has revision', "status 200, 'revision' present", async () => {
  const r = await rpc('get_owner_profile', { p_id: OWNER_PID }, OWNER_JWT);
  return [r.status === 200 && r.json && 'revision' in r.json, `status ${r.status} keys ${Object.keys(r.json ?? {}).length}`];
});

add('anon GET credential-evidence object is not 200', '400/403/404', async () => {
  const r = await call('GET', `/storage/v1/object/credential-evidence/${OWNER_USER_ID}/probe.txt`);
  return [[400, 403, 404].includes(r.status), `status ${r.status}`];
});
errCheck('OTHER_JWT upload into OWNER folder of provider-photos denied', () =>
  call('POST', `/storage/v1/object/provider-photos/${OWNER_USER_ID}/authz-probe-${Date.now()}.txt`,
    { jwt: OTHER_JWT, raw: 'probe', headers: { 'content-type': 'text/plain' } }));

add('ADMIN_JWT rpc admin_audit_events returns array', 'status 200, JSON array', async () => {
  const r = await rpc('admin_audit_events', { p_limit: 5 }, ADMIN_JWT);
  return [r.status === 200 && Array.isArray(r.json), `status ${r.status}`];
});

// ---------------------------------------------------------------------------
const rows = [];
for (const c of checks) {
  let ok, detail;
  try { [ok, detail] = await c.fn(); } catch (e) { ok = false; detail = 'exception: ' + e.message; }
  rows.push({ result: ok ? 'PASS' : 'FAIL', check: c.name, expected: c.expected, actual: detail });
}
console.table(rows);
const failed = rows.filter((r) => r.result === 'FAIL').length;
console.log(`${rows.length - failed}/${rows.length} passed`);
process.exit(failed ? 1 : 0);
