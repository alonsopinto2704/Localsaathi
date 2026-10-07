// Prints the database's callable/readable surface as Markdown, straight from
// the catalog after all migrations: every function in public/private with its
// security mode, search_path and who may EXECUTE it; every table with RLS
// state, per-role table grants and policies; and default privileges.
//
//   node backend/scripts/db-inventory.mjs > inventory.md
import { createDb, migrate } from './db.mjs';

const db = await createDb();
await migrate(db);
const q = async (sql) => (await db.query(sql)).rows;
const yes = (b) => (b ? 'Y' : '·');

const fns = await q(`
  select n.nspname as schema, p.proname as name, pg_get_function_identity_arguments(p.oid) as args,
         p.prosecdef as definer, pg_get_userbyid(p.proowner) as owner,
         coalesce((select string_agg(c, ',') from unnest(p.proconfig) c where c like 'search_path=%'), '') as path,
         (select bool_or(acl::text like '=X%') from unnest(coalesce(p.proacl, acldefault('f', p.proowner))) acl) as public_exec,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as authn,
         p.prorettype = 'trigger'::regtype as is_trigger
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private') and p.prokind = 'f'
  order by 1, 2`);

console.log(`## Functions (${fns.length})\n`);
console.log('| schema.function(args) | definer | search_path | PUBLIC | anon | authenticated | trigger |');
console.log('|---|---|---|---|---|---|---|');
for (const f of fns) {
  console.log(`| \`${f.schema}.${f.name}(${f.args})\` | ${yes(f.definer)} | ${f.path.replace('search_path=', '') || '—'} | ${yes(f.public_exec)} | ${yes(f.anon)} | ${yes(f.authn)} | ${yes(f.is_trigger)} |`);
}

const tables = await q(`
  select n.nspname as schema, c.relname as name, c.relrowsecurity as rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'private', 'storage') and c.relkind = 'r'
  order by 1, 2`);
console.log(`\n## Tables (${tables.length})\n`);
console.log('| table | RLS | anon | authenticated | policies (cmd: roles) |');
console.log('|---|---|---|---|---|');
for (const t of tables) {
  const fq = `${t.schema}.${t.name}`;
  const privs = async (role) => {
    const r = await q(`select string_agg(p, '') as s from (values ('S','SELECT'),('I','INSERT'),('U','UPDATE'),('D','DELETE')) v(p, priv)
      where has_table_privilege('${role}', '${fq}', priv)`);
    return r[0].s || '·';
  };
  const pols = await q(`select cmd, array_to_string(roles, ',') as roles from pg_policies where schemaname = '${t.schema}' and tablename = '${t.name}' order by cmd`);
  const polText = pols.map((p) => `${p.cmd}:${p.roles}`).join('; ') || '—';
  console.log(`| \`${fq}\` | ${yes(t.rls)} | ${await privs('anon')} | ${await privs('authenticated')} | ${polText} |`);
}

const defaults = await q(`
  select pg_get_userbyid(d.defaclrole) as owner, coalesce(n.nspname, '(all)') as schema, d.defaclobjtype as type, d.defaclacl::text as acl
  from pg_default_acl d left join pg_namespace n on n.oid = d.defaclnamespace order by 1, 2, 3`);
console.log(`\n## Default privileges\n`);
console.log('| owner | schema | object type (r=table f=function S=sequence) | ACL |');
console.log('|---|---|---|---|');
for (const d of defaults) console.log(`| ${d.owner} | ${d.schema} | ${d.type} | \`${d.acl}\` |`);

const schemaCreate = await q(`select r as role, has_schema_privilege(r, 'public', 'CREATE') as can_create
  from unnest(array['anon', 'authenticated']) r`);
console.log(`\n## CREATE on schema public\n`);
for (const s of schemaCreate) console.log(`- ${s.role}: ${s.can_create ? '**yes**' : 'no'}`);

await db.close();
