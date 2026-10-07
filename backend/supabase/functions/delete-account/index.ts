// Account deletion (phases 035, 057).
//
// Why this is custom server code: deleting an auth.users row needs the Auth
// Admin API (service role), a key that must never ship in the app. The function
// therefore does the one privileged thing after proving WHO is asking.
//
// Contract (see logic.ts for the rules and backend/test/delete-account.test.mjs):
//   POST /functions/v1/delete-account
//   Authorization: Bearer <the caller's own access token>
//   { "idempotencyKey": "<8-64 URL-safe chars, reused on retry>" }
//   -> 200 { ok, jobId, status }   403 { error: "reauth_required" }
//      401 { error: "not_authenticated" }   502 { error: "delete_failed", jobId }
//
// Call public.request_sensitive_action('delete_account') first (the app does);
// without a fresh grant the first request is refused. A retry after a dropped
// response, or after success (401, the user no longer exists), is safe.
//
// Deploy: supabase functions deploy delete-account
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleDeleteAccount, type BeginResult } from "./logic.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

/** Removes every object the user owns. Objects live flat at `<folder>/<file>`:
 * photos under the profile id (legacy: the user id), credential evidence under
 * the user id. Bounded passes; stops if a pass removes nothing new. */
async function cleanupStorage(userId: string, onProfile: (id: string | null) => void): Promise<boolean> {
  const { data: profile, error } = await admin.from("provider_profiles").select("id").eq("user_id", userId).maybeSingle();
  if (error) return false;
  onProfile(profile?.id ?? null);
  const targets: Array<[string, string]> = [
    ["provider-photos", userId],
    ["credential-evidence", userId],
    ...(profile ? [["provider-photos", profile.id] as [string, string]] : []),
  ];
  for (const [bucket, folder] of targets) {
    for (let pass = 0; pass < 50; pass++) {
      const { data: entries, error: listError } = await admin.storage.from(bucket).list(folder, { limit: 100 });
      if (listError) return false;
      const files = (entries ?? []).filter((e) => e.id !== null);
      if (files.length === 0) break;
      const { data: removed, error: removeError } = await admin.storage.from(bucket).remove(files.map((f) => `${folder}/${f.name}`));
      if (removeError || !removed || removed.length === 0) return false;
    }
  }
  return true;
}

Deno.serve(async (req: Request) => {
  let profileId: string | null = null;
  const result = await handleDeleteAccount(
    { method: req.method, authorization: req.headers.get("Authorization"), body: await req.text() },
    {
      async authenticate(jwt) {
        const { data, error } = await admin.auth.getUser(jwt);
        return error || !data?.user ? null : data.user.id;
      },
      async begin(userId, key): Promise<BeginResult> {
        const { data, error } = await admin.rpc("begin_account_deletion", { p_user_id: userId, p_idempotency_key: key });
        if (error) {
          // Log the stable prefix only; the message may name internals.
          console.error("delete-account: begin failed", String(error.message).split(":")[0]);
          return { ok: false, reason: String(error.message).startsWith("reauth_required") ? "reauth_required" : "failed" };
        }
        return { ok: true, jobId: data.jobId, status: data.status, resumed: !!data.resumed };
      },
      cleanupStorage: (userId) => cleanupStorage(userId, (id) => { profileId = id; }),
      async deleteAuthUser(userId) {
        const { error } = await admin.auth.admin.deleteUser(userId);
        if (error) console.error("delete-account: auth delete failed");
        return !error;
      },
      async advance(jobId, status, errorCode) {
        const { error } = await admin.rpc("advance_account_deletion", { p_job_id: jobId, p_status: status, p_error: errorCode ?? null });
        if (error) console.error("delete-account: advance failed", status);
      },
      async markCleaned(userId) {
        const { error } = await admin.rpc("mark_storage_cleaned", { p_user_id: userId, p_profile_id: profileId });
        if (error) console.error("delete-account: mark_storage_cleaned failed");
      },
    },
  );
  console.log(`delete-account: status=${result.status}`);
  return Response.json(result.body, { status: result.status });
});
