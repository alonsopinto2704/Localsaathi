// Phase 037: forward-migration rehearsal on a database that looks like the
// previous release (migrations up to 20260101000012 + seed + synthetic rows
// written the old way), then the new migrations one by one with timings, an
// injected mid-migration failure, and old-client call compatibility.
//
//   node backend/scripts/rehearse-migrations.mjs [--providers 2000]
import { createDb, describe, migrate, read, sqlFiles } from './db.mjs';

const n = Number(process.argv[process.argv.indexOf('--providers') + 1]) || 2000;
const isOld = (f) => f < '20261006';
const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ` -- ${detail}` : ''}`);
};

async function priorRelease() {
  const db = await createDb();
  await migrate(db, isOld);
  await db.exec(read('seed.sql'));
  // Old-release data: GoTrue-format phones (no '+'), some published without
  // consent drift, all SYNTHETIC.
  await db.exec(`
    insert into auth.users (id, instance_id, aud, role, phone, phone_confirmed_at, created_at, updated_at)
    select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
           '9199' || lpad(g::text, 8, '0'), now(), now(), now()
    from generate_series(1, ${n}) g;
    insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id,
                                          phone_display_consented, whatsapp_enabled)
    select u.id, u.phone, 'SYNTH provider ' || row_number() over (), 'mh-mumbai', 'mh-mumbai-andheri-west', true, true
    from auth.users u where u.phone like '9199%';
    insert into public.provider_categories (provider_id, category_id)
    select id, 'plumbing' from public.provider_profiles where display_name like 'SYNTH %';
    insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
    select id, 'mh-mumbai', 'mh-mumbai-andheri-west', true from public.provider_profiles where display_name like 'SYNTH %';
    update public.provider_profiles set status = 'published' where display_name like 'SYNTH %';
    insert into public.consent_records (provider_id, kind, granted, phone_e164)
    select id, 'display_phone_number', true, phone_e164 from public.provider_profiles where display_name like 'SYNTH %';
  `);
  return db;
}

const asAnon = `set role anon; select set_config('request.jwt.claims', '{"role":"anon"}', false);`;

// 1. Upgrade with realistic volume, timing each file.
const db = await priorRelease();
const before = await db.query(`select count(*)::int as c from public.provider_profiles where phone_e164 !~ '^\\+'`);
check('prior release holds GoTrue-format phones (the backfill case)', before.rows[0].c === n, `${before.rows[0].c} rows`);
// Old client call shapes against the old schema, for comparison.
await db.exec(asAnon);
const oldSearch = await db.query(`select jsonb_array_length(public.search_providers('mh-mumbai','mh-mumbai-andheri-west')->'items') as c`);
await db.exec('reset role');
for (const file of sqlFiles('migrations').filter((f) => !isOld(f))) {
  const t = performance.now();
  try {
    await db.exec(read('migrations', file));
    check(`apply ${file}`, true, `${(performance.now() - t).toFixed(0)} ms`);
  } catch (e) {
    check(`apply ${file}`, false, describe(e));
    process.exit(1);
  }
}
const after = await db.query(`select count(*)::int as c from public.provider_profiles where phone_e164 !~ '^\\+[1-9][0-9]{7,14}$'`);
check('every phone is E.164 after upgrade', after.rows[0].c === 0);
const revs = await db.query(`select count(*)::int as c from public.provider_profiles where revision <> 1`);
check('backfill did not bump revisions or re-run publication rules', revs.rows[0].c === 0);

// 2. Old client call shapes (same RPC names/arguments) still work for guests.
await db.exec(asAnon);
const s = await db.query(`select public.search_providers('mh-mumbai','mh-mumbai-andheri-west') as r`);
const items = s.rows[0].r.items;
check('old search_providers(city, locality) call shape still works', Array.isArray(items) && items.length > 0,
  `${items.length} items (old schema returned ${oldSearch.rows[0].c}; limit default 20)`);
check('results keep the client keys (id, displayName, phoneE164, workingHours...)',
  ['id', 'displayName', 'phoneE164', 'categoryIds', 'serviceAreas', 'workingHours'].every((k) => k in items[0].provider));
const p = await db.query(`select public.get_public_profile(($1)::uuid) as r`, [items[0].provider.id]);
check('old get_public_profile(id) call shape still works', p.rows[0].r?.id === items[0].provider.id);
let directWrite = 'allowed';
try { await db.query(`insert into public.reports (provider_id, reason) values ($1, 'other')`, [items[0].provider.id]); }
catch (e) { directWrite = e.code; }
check('old direct-table report insert is now refused (documented breaking change)', directWrite === '42501', directWrite);
await db.exec('reset role');
await db.close();

// 3. Interrupted migration: a failure inside a file leaves the database at the
// previous migration (one file = one transaction), and re-running succeeds.
const db2 = await priorRelease();
const newFiles = sqlFiles('migrations').filter((f) => !isOld(f));
// The file that defines set_listing_status, so its absence proves the rollback.
const victim = newFiles.find((f) => f.includes('owner_writes'));
for (const f of newFiles.slice(0, newFiles.indexOf(victim))) await db2.exec(read('migrations', f));
let interrupted = false;
try { await db2.exec(`${read('migrations', victim)}\nselect 1/0;`); } catch { interrupted = true; }
await db2.exec('rollback').catch(() => {});
const leftover = await db2.query(`select count(*)::int as c from pg_proc where proname = 'set_listing_status'`);
check(`injected failure in ${victim} rolls the whole file back`, interrupted && leftover.rows[0].c === 0);
for (const f of newFiles.slice(newFiles.indexOf(victim))) await db2.exec(read('migrations', f));
const recovered = await db2.query(`select count(*)::int as c from pg_proc where proname = 'set_listing_status'`);
check('re-running the remaining migrations after the failure succeeds', recovered.rows[0].c === 1);
await db2.close();

const failed = results.filter((r) => !r.ok).length;
console.log(`Rehearsal: ${results.length - failed}/${results.length} checks passed (${n} synthetic providers).`);
process.exitCode = failed ? 1 : 0;
