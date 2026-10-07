// One-command database verification, no Docker needed:
//
//   npm --prefix backend test        (or: node backend/scripts/verify-db.mjs)
//
// Boots Postgres in-process (PGlite), loads a stub of the Supabase platform
// (scripts/supabase-stub.sql), applies every migration in filename order and
// then seed.sql, and runs the pgTAP suite the way `supabase test db`
// (pg_prove) does: one session per file, real pgTAP installed in
// `extensions`, a file passes only if its plan is met and nothing fails.
// Exits non-zero on any failure.
import { readFileSync } from 'node:fs';
import { createDb, describe, migrate, read, searchPath, sqlFiles } from './db.mjs';

const db = await createDb();

async function main() {
  // Each file is one query string, i.e. one transaction, like the Supabase CLI.
  let migrations;
  try {
    migrations = await migrate(db);
  } catch (e) {
    console.log(`FAIL migration ${e.file}
      ${describe(e)}`);
    return false;
  }
  console.log(`Migrations applied: ${migrations.length}/${migrations.length}`);

  try {
    await db.exec(read('seed.sql'));
  } catch (e) {
    console.log(`FAIL seed.sql\n      ${describe(e)}`);
    return false;
  }
  console.log('Seed applied: seed.sql');

  // Phase 013: every public column must be classified, and nothing stale listed.
  const classified = Object.keys(
    JSON.parse(readFileSync(new URL('../../docs/contracts/column-classification.json', import.meta.url), 'utf8')).columns,
  );
  const { rows } = await db.query(
    `select c.table_name || '.' || c.column_name as k from information_schema.columns c
     join information_schema.tables t using (table_schema, table_name)
     where c.table_schema = 'public' and t.table_type = 'BASE TABLE'`,
  );
  const live = new Set(rows.map((r) => r.k));
  const unclassified = [...live].filter((k) => !classified.includes(k));
  const stale = classified.filter((k) => !live.has(k));
  if (unclassified.length || stale.length) {
    console.log(`FAIL column classification (docs/contracts/column-classification.json)
      unclassified: ${unclassified.join(', ') || '-'}
      stale: ${stale.join(', ') || '-'}`);
    return false;
  }
  console.log(`Column classification: ${live.size}/${live.size} public columns classified`);

  await db.exec('create extension if not exists pgtap with schema extensions');
  // Migration 0013 revokes the implicit PUBLIC EXECUTE on new functions, which
  // also covers pgTAP's. Suites switch to anon/authenticated mid-test and still
  // need to call ok()/is()/throws_like(), so grant them back -- test-only.
  await db.exec('grant execute on all functions in schema extensions to anon, authenticated');
  // Convention: `*.test.sql` are pgTAP suites; every other .sql in the
  // directory (0000_helpers.sql) is setup, loaded once and never run as a suite.
  const allFiles = sqlFiles('tests/database');
  const testFiles = allFiles.filter((f) => f.endsWith('.test.sql'));
  for (const file of allFiles.filter((f) => !f.endsWith('.test.sql'))) {
    try {
      await db.exec(read('tests/database', file));
    } catch (e) {
      console.log(`FAIL setup ${file}
      ${describe(e)}`);
      return false;
    }
    console.log(`Setup loaded: ${file}`);
  }
  if (testFiles.length === 0) {
    console.log('FAIL no *.test.sql suites found');
    return false;
  }
  let filesFailed = 0;
  let assertions = 0;
  let assertionsFailed = 0;
  for (const file of testFiles) {
    let output = [];
    let error = null;
    try {
      const results = await db.exec(read('tests/database', file));
      output = results.flatMap((r) => (r.fields.length === 1 ? r.rows.map((row) => Object.values(row)[0]) : []));
    } catch (e) {
      error = e;
    }
    // New session for the next file, as pg_prove gives each file its own psql.
    await db.exec('rollback');
    await db.exec('discard all');
    await searchPath(db);

    const lines = output.filter((v) => typeof v === 'string').flatMap((v) => v.split('\n'));
    const plan = lines.map((l) => /^1\.\.(\d+)/.exec(l)).find(Boolean);
    const results = lines.filter((l) => /^(not )?ok \d+/.test(l));
    const failures = results.filter((l) => l.startsWith('not ok') && !/# TODO/i.test(l));
    const problems = [];
    if (error) problems.push(`error: ${describe(error)}`);
    if (!plan) problems.push('no plan found in TAP output');
    else if (Number(plan[1]) !== results.length) problems.push(`planned ${plan[1]} tests but ran ${results.length}`);
    const outOfOrder = results.findIndex((l, i) => Number(/ok (\d+)/.exec(l)[1]) !== i + 1);
    if (outOfOrder !== -1) problems.push(`test numbers not sequential at "${results[outOfOrder]}"`);
    const bail = lines.find((l) => /^Bail out!/i.test(l));
    if (bail) problems.push(bail);
    assertions += results.length;
    assertionsFailed += failures.length;

    if (problems.length === 0 && failures.length === 0) {
      console.log(`ok   ${file} (${results.length} tests)`);
      continue;
    }
    filesFailed++;
    console.log(`FAIL ${file}`);
    for (const line of lines.filter((l) => l.startsWith('not ok') || l.startsWith('#'))) console.log(`      ${line}`);
    for (const p of problems) console.log(`      ${p}`);
  }

  const passed = filesFailed === 0;
  console.log(
    `Tests: ${testFiles.length - filesFailed}/${testFiles.length} files passed, ` +
      `${assertions - assertionsFailed}/${assertions} assertions passed. ${passed ? 'PASS' : 'FAIL'}`,
  );
  return passed;
}

let passed = false;
try {
  passed = await main();
} finally {
  await db.close();
}
process.exitCode = passed ? 0 : 1;
