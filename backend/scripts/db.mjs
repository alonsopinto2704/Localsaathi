// Shared PGlite boot for the backend scripts (verify-db, inventory, rehearsal,
// benchmarks): Supabase stub + every migration in filename order (+ seed).
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { pgtap } from '@electric-sql/pglite-pgtap';

const here = dirname(fileURLToPath(import.meta.url));
export const supabaseDir = join(here, '..', 'supabase');
export const read = (...parts) => readFileSync(join(supabaseDir, ...parts), 'utf8');
export const sqlFiles = (dir) => readdirSync(join(supabaseDir, dir)).filter((f) => f.endsWith('.sql')).sort();
export const describe = (e) =>
  [e.message, e.detail && `DETAIL: ${e.detail}`, e.where && `CONTEXT: ${e.where}`].filter(Boolean).join('\n      ');

// Supabase's search_path for `postgres`. Must run on its own: a SET sent in
// the same query string as a later BEGIN ... ROLLBACK is rolled back with it.
export const searchPath = (db) => db.exec(`set search_path = "$user", public, extensions`);

export async function createDb() {
  const db = await PGlite.create({ extensions: { pg_trgm, pgcrypto, pgtap } });
  await db.exec(readFileSync(join(here, 'supabase-stub.sql'), 'utf8'));
  await searchPath(db);
  return db;
}

// Applies migrations (optionally only those accepted by `filter`) one file per
// transaction, like the Supabase CLI. Throws with the failing file name.
export async function migrate(db, filter = () => true) {
  const files = sqlFiles('migrations').filter(filter);
  for (const file of files) {
    try {
      await db.exec(read('migrations', file));
    } catch (e) {
      e.file = file;
      throw e;
    }
  }
  return files;
}
