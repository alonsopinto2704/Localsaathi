// media-gc, pure logic (phase 085). Runs under Deno (index.ts) and Node
// (backend/test/media-gc.test.mjs).
//
// POST /functions/v1/media-gc   Authorization: Bearer <service role key>
//   { "limit": 1..200, "acceptAnomaly": false }   (both optional)
//   -> 200 { paused: null|"media_cleanup_off"|"anomaly", deleted, skipped, failed }
//
// Run on a schedule (e.g. every 15 minutes). The database decides what is
// removable (public.list_media_orphans: references and ownership checked in
// SQL); this function removes blobs THROUGH THE STORAGE API (deleting a
// storage.objects row would orphan the blob) and asks the database again right
// before each delete. It stops early after repeated delete failures and
// reports counts only. Safe to re-run: an already-removed object is simply gone.
export interface Orphan { bucket: string; name: string; reason: string }
export interface GcDeps {
  isOperator(authorization: string | null): boolean;
  expire(): Promise<void>;
  list(limit: number, acceptAnomaly: boolean): Promise<{ paused: string | null; items: Orphan[] }>;
  deletable(bucket: string, name: string): Promise<boolean>;
  remove(bucket: string, name: string): Promise<boolean>;
}
export interface GcResponse { status: number; body: Record<string, unknown> }
const MAX_FAILURES = 5;

export async function handleGc(
  req: { method: string; authorization: string | null; body: string },
  deps: GcDeps,
): Promise<GcResponse> {
  if (req.method !== "POST") return { status: 405, body: { error: "method_not_allowed" } };
  if (!deps.isOperator(req.authorization)) return { status: 401, body: { error: "not_authenticated" } };
  let limit = 100, acceptAnomaly = false;
  try {
    const b = req.body ? JSON.parse(req.body) : {};
    if (Number.isInteger(b.limit)) limit = Math.min(200, Math.max(1, b.limit));
    acceptAnomaly = b.acceptAnomaly === true;
  } catch { return { status: 400, body: { error: "invalid_request" } }; }

  try {
    await deps.expire();
    const { paused, items } = await deps.list(limit, acceptAnomaly);
    if (paused) return { status: 200, body: { paused, expired: 0, deleted: 0, skipped: 0, failed: 0 } };
    let deleted = 0, skipped = 0, failed = 0;
    for (const o of items) {
      if (failed >= MAX_FAILURES) { skipped += 1; continue; }          // circuit breaker: something is wrong with Storage
      if (!await deps.deletable(o.bucket, o.name)) { skipped += 1; continue; } // flag flipped or a reference appeared
      if (await deps.remove(o.bucket, o.name)) deleted += 1; else failed += 1;
    }
    return { status: 200, body: { paused: null, deleted, skipped, failed } };
  } catch {
    return { status: 502, body: { error: "gc_failed" } };
  }
}
