// Phase 057: delete-account logic against fakes. Users are synthetic ids.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleDeleteAccount } from '../supabase/functions/delete-account/logic.ts';

const A = '00000000-0000-0000-0000-00000000000a';
const B = '00000000-0000-0000-0000-00000000000b';
const KEY = 'retry-key-0001';

function world({ grants = new Set([A, B]), failStorage = false, failAuth = false, throwWith } = {}) {
  const w = {
    jobs: new Map(), users: new Set([A, B]), storageCleaned: [], authDeleted: [], advanced: [], failStorage, failAuth,
    deps: {
      authenticate: async (jwt) => (jwt === 'token-a' ? (w.users.has(A) ? A : null) : jwt === 'token-b' ? (w.users.has(B) ? B : null) : null),
      begin: async (userId, key) => {
        if (throwWith) throw new Error(throwWith);
        let job = w.jobs.get(userId);
        if (job) return { ok: true, jobId: job.id, status: job.status, resumed: true };
        if (!grants.has(userId)) return { ok: false, reason: 'reauth_required' };
        grants.delete(userId);
        job = { id: `job-${userId.slice(-1)}`, status: 'requested', key };
        w.jobs.set(userId, job);
        return { ok: true, jobId: job.id, status: 'requested', resumed: false };
      },
      cleanupStorage: async (userId) => { if (w.failStorage) throw new Error('bucket path /secret/internal'); w.storageCleaned.push(userId); return true; },
      deleteAuthUser: async (userId) => { if (w.failAuth) return false; w.users.delete(userId); w.authDeleted.push(userId); return true; },
      advance: async (jobId, status) => { w.advanced.push(`${jobId}:${status}`); for (const j of w.jobs.values()) if (j.id === jobId) j.status = status; },
      markCleaned: async () => {},
    },
  };
  return w;
}
const call = (w, { token = 'token-a', body = { idempotencyKey: KEY }, method = 'POST' } = {}) =>
  handleDeleteAccount({ method, authorization: token ? `Bearer ${token}` : null, body: JSON.stringify(body) }, w.deps);

test('happy path: one job, storage then auth, ends completed', async () => {
  const w = world();
  const res = await call(w);
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'completed');
  assert.deepEqual(w.storageCleaned, [A]);
  assert.deepEqual(w.authDeleted, [A]);
  assert.deepEqual(w.advanced, ['job-a:storage_cleaned', 'job-a:completed']);
});

test('the caller is the JWT user: a victim id in the body is ignored', async () => {
  const w = world();
  const res = await call(w, { body: { idempotencyKey: KEY, userId: B, user_id: B, id: B } });
  assert.equal(res.status, 200);
  assert.deepEqual(w.authDeleted, [A], 'only the authenticated user is deleted');
  assert.ok(w.users.has(B));
});

test('unauthenticated, bad token, wrong method and bad body never reach any deletion', async () => {
  const w = world();
  assert.equal((await call(w, { token: null })).status, 401);
  assert.equal((await call(w, { token: 'garbage' })).status, 401);
  assert.equal((await call(w, { method: 'GET' })).status, 405);
  assert.equal((await call(w, { body: { idempotencyKey: 'x' } })).status, 400);
  assert.equal((await call(w, { body: {} })).status, 400);
  assert.equal((await handleDeleteAccount({ method: 'POST', authorization: 'Bearer token-a', body: '{not json' }, w.deps)).status, 400);
  assert.deepEqual(w.authDeleted, []);
  assert.deepEqual(w.storageCleaned, []);
});

test('no recent-authentication grant: 403 reauth_required and nothing is touched', async () => {
  const w = world({ grants: new Set() });
  const res = await call(w);
  assert.equal(res.status, 403);
  assert.deepEqual(res.body, { error: 'reauth_required' });
  assert.deepEqual(w.authDeleted, []);
  assert.deepEqual(w.storageCleaned, []);
});

test("one account's grant does not authorise another's deletion", async () => {
  const w = world({ grants: new Set([A]) });
  assert.equal((await call(w, { token: 'token-b' })).status, 403);
  assert.ok(w.users.has(B));
});

test('storage failure: generic 502, account intact, job failed; the retry completes with ONE job', async () => {
  const w = world({ failStorage: true });
  const first = await call(w);
  assert.equal(first.status, 502);
  assert.deepEqual(first.body, { error: 'delete_failed', jobId: 'job-a' }, 'no internal message or path');
  assert.doesNotMatch(JSON.stringify(first.body), /secret|internal|bucket/);
  assert.ok(w.users.has(A), 'auth user untouched when cleanup failed');
  w.failStorage = false;
  const retry = await call(w); // no new grant needed: the job exists
  assert.equal(retry.status, 200);
  assert.equal(w.jobs.size, 1);
  assert.deepEqual(w.authDeleted, [A]);
});

test('auth-delete failure is retryable and reported generically', async () => {
  const w = world({ failAuth: true });
  assert.equal((await call(w)).status, 502);
  w.failAuth = false;
  assert.equal((await call(w)).status, 200);
  assert.equal(w.jobs.size, 1);
});

test('after success the token is dead (401) and a replay deletes nothing more', async () => {
  const w = world();
  await call(w);
  assert.equal((await call(w)).status, 401);
  assert.deepEqual(w.authDeleted, [A]);
});

test('an already completed job answers 200 without repeating work', async () => {
  const w = world();
  w.jobs.set(A, { id: 'job-a', status: 'completed', key: KEY });
  const res = await call(w);
  assert.deepEqual(res.body, { ok: true, jobId: 'job-a', status: 'completed' });
  assert.deepEqual(w.storageCleaned, []);
});

test('thrown internals never reach the response', async () => {
  const w = world({ throwWith: 'pg: relation private.deletion_jobs password=hunter2' });
  const res = await call(w);
  assert.equal(res.status, 500);
  assert.doesNotMatch(JSON.stringify(res.body), /hunter2|relation|private/);
});
