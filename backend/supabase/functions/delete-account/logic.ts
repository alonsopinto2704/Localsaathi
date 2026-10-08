// delete-account, pure logic (phase 057). Runs under Deno (index.ts) and Node
// (backend/test/delete-account.test.mjs).
//
// Rules this encodes:
//  * the user is whoever the verified JWT says; the body can carry only an
//    idempotency key, and any other field (a "victim" id) is ignored;
//  * recent authentication is required for the first request (a grant minted
//    by public.request_sensitive_action); retries of an existing job are not
//    blocked while the job is fresh (10 min, same key), so a dropped response
//    cannot strand a half-deleted user; later, a different key, or no grant
//    is refused (reauth_required / conflict) and the owner can cancel via
//    public.cancel_account_deletion;
//  * one deletion state per user (public.begin_account_deletion);
//  * order: storage objects first, auth user last, so a failure before the
//    auth delete leaves a fully working account the user can retry;
//  * responses carry stable codes only: never an internal message, id of
//    another user, path or stack.

export interface DeleteResponse {
  status: number;
  body: Record<string, unknown>;
}

export type BeginResult =
  | { ok: true; jobId: string; status: string; resumed: boolean }
  | { ok: false; reason: "reauth_required" | "conflict" | "failed" };

export interface DeleteDeps {
  /** Verify the bearer token with Auth; the user id, or null. */
  authenticate(jwt: string): Promise<string | null>;
  begin(userId: string, idempotencyKey: string): Promise<BeginResult>;
  /** Remove every storage object of the user; false on any failure. */
  cleanupStorage(userId: string): Promise<boolean>;
  /** Auth Admin API delete; false on failure. */
  deleteAuthUser(userId: string): Promise<boolean>;
  advance(jobId: string, status: "storage_cleaned" | "completed" | "failed", errorCode?: string): Promise<void>;
  /** Close queued storage-cleanup rows; best effort. */
  markCleaned(userId: string): Promise<void>;
}

const json = (status: number, body: Record<string, unknown>): DeleteResponse => ({ status, body });
const KEY = /^[A-Za-z0-9_-]{8,64}$/;

export async function handleDeleteAccount(
  req: { method: string; authorization: string | null; body: string },
  deps: DeleteDeps,
): Promise<DeleteResponse> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const jwt = (req.authorization ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { error: "not_authenticated" });
  let userId: string | null = null;
  try {
    userId = await deps.authenticate(jwt);
  } catch {
    userId = null;
  }
  if (!userId) return json(401, { error: "not_authenticated" });

  let key = "";
  try {
    const parsed = JSON.parse(req.body || "{}");
    key = typeof parsed?.idempotencyKey === "string" ? parsed.idempotencyKey : "";
  } catch {
    return json(400, { error: "bad_request" });
  }
  if (!KEY.test(key)) return json(400, { error: "bad_request" });

  let begun: BeginResult;
  try {
    begun = await deps.begin(userId, key);
  } catch {
    return json(500, { error: "delete_failed" });
  }
  if (!begun.ok) {
    if (begun.reason === "reauth_required") return json(403, { error: "reauth_required" });
    if (begun.reason === "conflict") return json(409, { error: "deletion_in_progress" });
    return json(500, { error: "delete_failed" });
  }
  if (begun.status === "completed") {
    return json(200, { ok: true, jobId: begun.jobId, status: "completed" });
  }

  const fail = async (code: string): Promise<DeleteResponse> => {
    await deps.advance(begun.ok ? begun.jobId : "", "failed", code).catch(() => {});
    return json(502, { error: "delete_failed", jobId: begun.ok ? begun.jobId : undefined });
  };

  let cleaned = false;
  try {
    cleaned = await deps.cleanupStorage(userId);
  } catch {
    cleaned = false;
  }
  if (!cleaned) return fail("storage_cleanup_failed");
  await deps.advance(begun.jobId, "storage_cleaned").catch(() => {});

  let deleted = false;
  try {
    deleted = await deps.deleteAuthUser(userId);
  } catch {
    deleted = false;
  }
  if (!deleted) return fail("auth_delete_failed");

  // The user is gone; a bookkeeping failure must not turn success into an error.
  await deps.advance(begun.jobId, "completed").catch(() => {});
  await deps.markCleaned(userId).catch(() => {});
  return json(200, { ok: true, jobId: begun.jobId, status: "completed" });
}
