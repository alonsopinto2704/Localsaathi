// Phase 042: the server's definition of a supported mobile agrees with the Dart
// normaliser on the shared fixture (docs/contracts/fixtures/phone-cases.json).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { createDb, migrate } from '../scripts/db.mjs';

const fixture = JSON.parse(readFileSync(new URL('../../docs/contracts/fixtures/phone-cases.json', import.meta.url), 'utf8'));
let db;
before(async () => {
  db = await createDb();
  await migrate(db);
});
after(() => db.close());

const q = async (sql, params) => (await db.query(sql, params)).rows[0];

test('every fixture value the server could receive gets the same verdict as Dart', async () => {
  let checked = 0;
  for (const c of fixture.cases) {
    if (!c.server) continue;
    const e164 = await q('select private.normalize_e164($1) as v', [c.server]);
    // GoTrue stores numbers without "+"; normalize_e164 restores it. Values that
    // cannot be E.164 at all (null) are unsupported by definition.
    const supported = e164.v ? (await q('select private.is_supported_mobile($1) as v', [e164.v])).v : false;
    assert.equal(supported, c.e164 !== null, `${c.input} / ${c.server}`);
    if (c.e164) assert.equal(e164.v, c.e164, `${c.server} canonicalises to the Dart value`);
    checked++;
  }
  assert.ok(checked >= 8, `only ${checked} server cases`);
});

test('the gate refuses what the fixture says is unsupported, without a send', async () => {
  for (const c of fixture.cases.filter((x) => x.server && x.e164 === null)) {
    const { v } = await q('select public.otp_send_gate($1) as v', [c.server]);
    assert.equal(v.allowed, false, c.server);
  }
  const { v } = await q("select public.otp_send_gate('919000012345', now()) as v");
  assert.equal(v.allowed, true);
});
