// Phase 038: database search benchmark on PGlite with SYNTHETIC data.
//   node scripts/bench-search.mjs --providers 5000 [--baseline] [--calls 200]
//        [--explain DIR] [--extra-sql FILE] [--json FILE]
// --baseline  apply only the 20260101* migrations (old search_providers)
// --extra-sql run FILE (e.g. a proposed CREATE INDEX) before ANALYZE; never
//             touches supabase/migrations.
// All inserted rows are labelled: display_name 'SYNTH ...', phones +9199xxxxxxxx,
// auth.users with phone_confirmed_at set. Reference data comes from seed.sql.
// PGlite is single-process WASM: numbers are relative evidence, not hosted
// Postgres latency.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { createDb, migrate, read, searchPath } from './db.mjs';

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(`--${n}`); return i < 0 ? d : argv[i + 1]; };
const N = Number(opt('providers', 5000));
const CALLS = Number(opt('calls', 200));
const baseline = argv.includes('--baseline');
const explainDir = opt('explain');
const extraSql = opt('extra-sql');
const jsonOut = opt('json');
const HEAVY = Number(opt('heavy-calls', 20));

const t0 = performance.now();
const db = await createDb();
await migrate(db, baseline ? (f) => f.startsWith('20260101') : () => true);
await searchPath(db);
await db.exec(read('seed.sql'));
console.error(`boot+migrate+seed ${((performance.now() - t0) / 1000).toFixed(1)}s (${baseline ? 'baseline' : 'hardened'})`);

// ---- synthetic data (superuser, triggers off: set-based) -------------------
const t1 = performance.now();
await db.exec(`
set session_replication_role = replica;
create temp table sloc as select (row_number() over (order by id) - 1)::int n, id from public.localities where city_id = 'mh-mumbai';
create temp table scat as select (row_number() over (order by id) - 1)::int n, id from public.service_categories where is_approved_for_launch;
create temp table sgen as select i,
  md5('p' || i)::uuid pid, md5('u' || i)::uuid uid,
  '+9199' || lpad(i::text, 8, '0') phone,
  (select count(*) from sloc)::int nloc, (select count(*) from scat)::int ncat
  from generate_series(1, ${N}) i;

insert into auth.users (id, aud, role, phone, phone_confirmed_at, created_at, updated_at)
select uid, 'authenticated', 'authenticated', substr(phone, 2), now(), now(), now() from sgen;

insert into public.provider_profiles
  (id, user_id, phone_e164, display_name, base_city_id, base_locality_id, description, home_visits,
   phone_display_consented, status, moderation_status, published_at)
select g.pid, g.uid, g.phone,
  'SYNTH ' || (array['Ravi','Asha','Imran','Meera','Sanjay','Neha','Joseph','Pooja'])[1 + g.i % 8] || ' Services ' || g.i,
  'mh-mumbai', (select id from sloc where n = g.i % g.nloc),
  case when g.i % 20 = 3 then 'SYNTH plumbing and fitting expert, ' else 'SYNTH general home service, ' end || 'listing ' || g.i,
  g.i % 3 <> 0,
  g.i % 33 <> 5,                                            -- ~3% published without phone consent
  case when g.i % 10 = 1 then 'paused'::public.listing_status else 'published'::public.listing_status end,
  case when g.i % 20 = 0 then 'suspended'::public.moderation_status else 'active'::public.moderation_status end,
  now()
from sgen g;

insert into public.provider_categories (provider_id, category_id)
select g.pid, (select id from scat where n = (g.i * 7 + j * 13) % g.ncat)
from sgen g, generate_series(0, 2) j where j < 1 + g.i % 3;

insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
select g.pid, 'mh-mumbai', (select id from sloc where n = (g.i + j * 5) % g.nloc), j = 0
from sgen g, generate_series(0, 3) j where j < 1 + g.i % 4;

insert into public.provider_working_hours (provider_id, weekday, open_minutes, close_minutes)
select g.pid, d,
  case when d = 7 and g.i % 3 = 0 then null else 480 + (g.i % 4) * 30 end,
  case when d = 7 and g.i % 3 = 0 then null when g.i % 17 = 0 then 120 else 1020 + (g.i % 5) * 60 end
from sgen g, generate_series(1, 7) d;

insert into public.provider_photos (provider_id, caption, storage_path)
select g.pid, 'SYNTH photo', 'synth/' || g.i || '/' || p || '.jpg'
from sgen g, generate_series(1, 5) p where p <= g.i % 6;

set session_replication_role = origin;
`);
if (extraSql) await db.exec(readFileSync(extraSql, 'utf8'));
await db.exec('analyze');
const insertS = (performance.now() - t1) / 1000;
console.error(`synthetic insert+analyze ${insertS.toFixed(1)}s`);

const one = async (sql) => (await db.query(sql)).rows[0];
const counts = await one(`select
  (select count(*) from public.provider_profiles) providers,
  (select count(*) from public.provider_profiles where status='published' and moderation_status='active') published_active,
  (select count(*) from public.provider_profiles where status='published' and moderation_status='active' and phone_display_consented) published_active_consented,
  (select count(*) from public.provider_categories) provider_categories,
  (select count(*) from public.provider_service_areas) service_areas,
  (select count(*) from public.provider_working_hours) hours,
  (select count(*) from public.provider_photos) photos,
  (select count(*) from sloc) mumbai_localities, (select count(*) from scat) categories`);
const sizes = Object.fromEntries((await db.query(`select indexrelid::regclass::text n, pg_relation_size(indexrelid) b
  from pg_index where indrelid in ('public.provider_profiles'::regclass,'public.provider_service_areas'::regclass,'public.provider_categories'::regclass,'public.provider_working_hours'::regclass,'public.provider_photos'::regclass)`)).rows.map((r) => [r.n, Number(r.b)]));

// ---- measurement as role anon ---------------------------------------------
const LOC = 'mh-mumbai-andheri-west';
const sample = (await one(`select id from public.provider_profiles where status='published' and moderation_status='active' and phone_display_consented and base_locality_id='${LOC}' limit 1`)).id;
const S = (args) => `select public.search_providers('mh-mumbai','${LOC}', ${args})`;
const cases = [
  ['locality only', S(`''`), CALLS],
  ['locality+category (plumbing)', S(`'', '{plumbing}'`), CALLS],
  ["text 'plumb'", S(`'plumb'`), CALLS],
  ['text matching nothing', S(`'zzzqx'`), CALLS],
  ['open_now_only', S(`'', '{}', '{}', true`), CALLS],
  ['page 10 (limit 50, offset 450)', S(`'', '{}', '{}', false, false, 50, 450`), CALLS],
  ['p_limit 50', S(`'', '{}', '{}', false, false, 50, 0`), CALLS],
  ['get_public_profile', `select public.get_public_profile('${sample}')`, CALLS],
  ['provider_count_by_locality', `select public.provider_count_by_locality('mh-mumbai')`, Math.min(CALLS, HEAVY)],
  ['providers_published_in_city', `select public.providers_published_in_city('mh-mumbai')`, Math.min(CALLS, HEAVY)],
];
const pct = (a, p) => a[Math.min(a.length - 1, Math.ceil(p * a.length) - 1)];
const rowsOf = (v) => v == null ? null : v.items ? [v.totalCount, v.items.length] : Array.isArray(v) ? [v.length, v.length] : [null, null];
await db.exec(`set role anon; select set_config('request.jwt.claims', '{"role":"anon"}', false)`);
const results = [];
for (const [name, sql, n] of cases) {
  let out;
  try { out = (await db.query(sql)).rows[0]; } catch (e) { results.push({ name, error: e.message.split('\n')[0] }); continue; } // warm-up
  const val = Object.values(out)[0];
  const ms = [];
  for (let i = 0; i < n; i++) { const s = performance.now(); await db.query(sql); ms.push(performance.now() - s); }
  ms.sort((a, b) => a - b);
  const [total, ret] = rowsOf(val);
  results.push({ name, calls: n, p50: pct(ms, 0.5), p95: pct(ms, 0.95), max: ms[ms.length - 1], total, returned: ret });
  console.error(`${name}: p50 ${pct(ms, 0.5).toFixed(1)} p95 ${pct(ms, 0.95).toFixed(1)}`);
}
await db.exec(`reset role`);

// ---- EXPLAIN of the `matches` CTE (hardened semantics) ---------------------
if (explainDir) {
  mkdirSync(explainDir, { recursive: true });
  const catIds = (await db.query(`select coalesce(array_agg(sc.id),'{}') ids from public.service_categories sc where sc.is_approved_for_launch and (sc.name ilike '%plumb%' or exists (select 1 from unnest(sc.keywords) k where k ilike '%plumb%'))`)).rows[0].ids;
  const matches = (cat, textPred) => `select pp.* from public.provider_profiles pp
 join public.cities c on c.id = pp.base_city_id and c.launch_status = 'active'
 where pp.status='published' and pp.moderation_status='active' and pp.phone_display_consented and pp.base_city_id='mh-mumbai'
 and exists (select 1 from public.provider_service_areas sa where sa.provider_id=pp.id and sa.locality_id = any(array['${LOC}']))
 and exists (select 1 from public.provider_categories pc join public.service_categories sc on sc.id=pc.category_id and sc.is_approved_for_launch
             where pc.provider_id=pp.id ${cat})
 ${textPred}`;
  const text = `and (pp.display_name ilike '%plumb%' or coalesce(pp.description,'') ilike '%plumb%'
   or exists (select 1 from public.provider_categories pc where pc.provider_id=pp.id and pc.category_id = any('{${catIds.join(',')}}'))
   or exists (select 1 from public.provider_service_areas sa join public.localities l on l.id=sa.locality_id where sa.provider_id=pp.id and l.name ilike '%plumb%')
   or exists (select 1 from public.localities l where l.id=pp.base_locality_id and l.name ilike '%plumb%'))`;
  for (const [file, q] of [['locality-category', matches(`and pc.category_id = any('{plumbing}')`, '')], ['text-plumb', matches('', text)]]) {
    const plan = (await db.query(`explain (analyze, buffers) select count(*) from (${q}) m`)).rows.map((r) => r['QUERY PLAN']).join('\n');
    writeFileSync(`${explainDir}/${baseline ? 'baseline' : 'hardened'}-${N}-${file}.txt`, plan);
  }
  // Whole function body for locality-only (matches + sponsor + ranked + paged + count), no jsonb build.
  const full = `with matches as (${matches('', '')}),
 sponsor_matches as (select m.id provider_id, max(pr.priority) priority from matches m join public.promotions pr on pr.provider_id=m.id where pr.state='active' and now()>=pr.starts_at and now()<pr.ends_at group by m.id),
 ranked as (select m.id, m.display_name, (sm.provider_id is not null) is_sponsored, coalesce(sm.priority,-1) sponsor_priority,
   (select count(*) from public.provider_photos ph where ph.provider_id=m.id) photo_count,
   (select count(*) from public.provider_categories pc where pc.provider_id=m.id) category_count
   from matches m left join sponsor_matches sm on sm.provider_id=m.id),
 paged as (select * from ranked order by is_sponsored desc, sponsor_priority desc, photo_count desc, category_count desc, display_name, id limit 20)
 select (select count(*) from ranked), (select count(*) from paged)`;
  const plan = (await db.query(`explain (analyze, buffers) ${full}`)).rows.map((r) => r['QUERY PLAN']).join('\n');
  writeFileSync(`${explainDir}/${baseline ? 'baseline' : 'hardened'}-${N}-locality-only-ranked.txt`, plan);
  const pj = (await db.query(`explain (analyze, buffers) select public.public_profile_json(id) from public.provider_profiles where base_locality_id='${LOC}' limit 20`)).rows.map((r) => r['QUERY PLAN']).join('\n');
  writeFileSync(`${explainDir}/${baseline ? 'baseline' : 'hardened'}-${N}-public-profile-json-x20.txt`, pj);
}

const report = { mode: baseline ? 'baseline' : 'hardened', providers: N, insertSeconds: insertS, counts, indexSizes: sizes, results };
if (jsonOut) writeFileSync(jsonOut, JSON.stringify(report, null, 1));
console.log(JSON.stringify(report, null, 1));
