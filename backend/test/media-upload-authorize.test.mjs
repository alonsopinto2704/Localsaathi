// Phase 082: upload authorization logic against fakes. The database side
// (ownership, expiry, ceilings) is covered by 0031_media_upload_auth.test.sql;
// Storage's own enforcement of the signed token is UNVERIFIED (no hosted project).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleAuthorize } from '../supabase/functions/media-upload-authorize/logic.ts';

const PROFILE = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const ISSUED = { uploadId: '11111111-2222-4333-8444-555555555555', bucket: 'media-quarantine', path: `${PROFILE}/11111111-2222-4333-8444-555555555555`, expiresAt: '2026-10-08T10:15:00Z', maxBytes: 200000, mime: 'image/jpeg' };

function world({ issue, sign } = {}) {
  const w = { issued: [], signed: [] };
  w.deps = {
    issue: async (jwt, a) => { w.issued.push({ jwt, ...a }); return issue ? issue(jwt, a) : { ok: true, issued: ISSUED }; },
    sign: async (bucket, path) => { w.signed.push({ bucket, path }); return sign ? sign() : { token: 'signed-token' }; },
  };
  return w;
}
const call = (w, { token = 'owner-token', body = { profileId: PROFILE, mime: 'image/jpeg', bytes: 200000 }, method = 'POST' } = {}) =>
  handleAuthorize({ method, authorization: token ? `Bearer ${token}` : null, body: typeof body === 'string' ? body : JSON.stringify(body) }, w.deps);

test('the token is minted for exactly the path the database generated', async () => {
  const w = world();
  const res = await call(w);
  assert.equal(res.status, 200);
  assert.deepEqual(w.signed, [{ bucket: ISSUED.bucket, path: ISSUED.path }]);
  assert.equal(res.body.token, 'signed-token');
  assert.equal(res.body.path, ISSUED.path);
  assert.equal(w.issued[0].jwt, 'owner-token', "the database is asked with the caller's own token");
});

test('a body cannot choose the path, bucket, class or owner', async () => {
  const w = world();
  await call(w, { body: { profileId: PROFILE, mime: 'image/png', bytes: 5, path: '../other/x.jpg', bucket: 'provider-photos', class: 'credential_evidence', userId: 'victim' } });
  assert.deepEqual(Object.keys(w.issued[0]).sort(), ['bytes', 'jwt', 'mime', 'profileId']);
  assert.equal(w.signed[0].bucket, ISSUED.bucket, "the signed bucket/path are the database's, not the request's");
});

test('bad input never reaches the database', async () => {
  const w = world();
  const bad = [
    { profileId: 'not-a-uuid', mime: 'image/jpeg', bytes: 10 },
    { profileId: PROFILE, mime: 'image/svg+xml', bytes: 10 },
    { profileId: PROFILE, mime: 'application/x-msdownload', bytes: 10 },
    { profileId: PROFILE, mime: 'image/jpeg', bytes: 0 },
    { profileId: PROFILE, mime: 'image/jpeg', bytes: 1.5 },
    { profileId: PROFILE, mime: 'image/jpeg', bytes: '100' },
    '{not json',
  ];
  for (const body of bad) assert.equal((await call(w, { body })).status, 400);
  assert.equal((await call(w, { token: null })).status, 401);
  assert.equal((await call(w, { method: 'GET' })).status, 405);
  assert.equal(w.issued.length, 0);
});

test('database refusals map to stable statuses and never leak details', async () => {
  const cases = { not_owner: 403, rate_limited: 429, feature_disabled: 503, validation_failed: 400, not_found: 404, weird_internal_code: 502 };
  for (const [code, status] of Object.entries(cases)) {
    const res = await call(world({ issue: async () => ({ ok: false, code }) }));
    assert.equal(res.status, status);
    assert.deepEqual(Object.keys(res.body), ['error']);
    if (status === 502) assert.equal(res.body.error, 'authorize_failed');
  }
});

test('if signing fails or the database throws, no token is returned', async () => {
  const a = await call(world({ sign: () => null }));
  assert.equal(a.status, 502);
  assert.equal(a.body.token, undefined);
  const b = await call(world({ issue: async () => { throw new Error('connection string postgres://secret'); } }));
  assert.equal(b.status, 502);
  assert.ok(!JSON.stringify(b.body).includes('secret'));
});
