// Phase 085: orphan sweep logic against fakes. Which objects are eligible is
// decided in SQL (0034_media_orphans.test.sql); this checks the removal loop:
// re-check before delete, pause handling, circuit breaker, operator-only access.
// Real blob removal through Storage is UNVERIFIED (no hosted project).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleGc } from '../supabase/functions/media-gc/logic.ts';

const orphan = (n) => ({ bucket: 'provider-photos', name: `aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/${n}.webp`, reason: 'unreferenced' });

function world({ items = [orphan(1), orphan(2), orphan(3)], paused = null, stillOrphan = () => true, removeOk = () => true } = {}) {
  const w = { expired: 0, listed: [], removed: [], rechecked: [] };
  w.deps = {
    isOperator: (a) => a === 'Bearer service-key',
    expire: async () => { w.expired++; },
    list: async (limit, accept) => { w.listed.push({ limit, accept }); return { paused, items }; },
    deletable: async (b, n) => { w.rechecked.push(n); return stillOrphan(n); },
    remove: async (b, n) => { w.removed.push(n); return removeOk(n); },
  };
  return w;
}
const call = (w, { auth = 'Bearer service-key', body = '', method = 'POST' } = {}) => handleGc({ method, authorization: auth, body }, w.deps);

test('only the operator (service role) may run it', async () => {
  const w = world();
  assert.equal((await call(w, { auth: null })).status, 401);
  assert.equal((await call(w, { auth: 'Bearer some-user-jwt' })).status, 401);
  assert.equal((await call(w, { method: 'GET' })).status, 405);
  assert.equal(w.removed.length + w.listed.length, 0);
});

test('every object is re-checked right before deletion; a changed answer skips it', async () => {
  const w = world({ stillOrphan: (n) => !n.endsWith('/2.webp') });
  const res = await call(w);
  assert.deepEqual(res.body, { paused: null, deleted: 2, skipped: 1, failed: 0 });
  assert.equal(w.rechecked.length, 3);
  assert.ok(!w.removed.some((n) => n.endsWith('/2.webp')));
});

test('a paused sweep deletes nothing', async () => {
  for (const paused of ['media_cleanup_off', 'anomaly']) {
    const w = world({ paused });
    const res = await call(w);
    assert.equal(res.body.paused, paused);
    assert.equal(w.removed.length, 0);
    assert.equal(w.rechecked.length, 0);
  }
});

test('repeated Storage failures stop the run (circuit breaker); counts only are reported', async () => {
  const w = world({ items: Array.from({ length: 12 }, (_, i) => orphan(i)), removeOk: () => false });
  const res = await call(w);
  assert.equal(res.body.failed, 5);
  assert.equal(w.removed.length, 5, 'no further delete attempts after the fifth failure');
  assert.deepEqual(Object.keys(res.body).sort(), ['deleted', 'failed', 'paused', 'skipped']);
});

test('limit is bounded and the anomaly override is explicit', async () => {
  const w = world();
  await call(w, { body: JSON.stringify({ limit: 100000, acceptAnomaly: true }) });
  await call(w, { body: JSON.stringify({ limit: -5 }) });
  await call(w, { body: JSON.stringify({ limit: 'many', acceptAnomaly: 'yes' }) });
  assert.deepEqual(w.listed, [{ limit: 200, accept: true }, { limit: 1, accept: false }, { limit: 100, accept: false }]);
  assert.equal((await call(w, { body: '{broken' })).status, 400);
});

test('an infrastructure failure is a 502 with no detail', async () => {
  const w = world();
  w.deps.list = async () => { throw new Error('relation storage.objects secret-detail'); };
  const res = await call(w);
  assert.deepEqual(res, { status: 502, body: { error: 'gc_failed' } });
});
