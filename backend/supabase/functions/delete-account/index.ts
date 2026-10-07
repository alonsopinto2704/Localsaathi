// Account deletion.
//
// Why this is the one piece of custom server code in the whole backend: SQL
// running as the table owner can delete rows in `public.*`, but it cannot
// delete a row from `auth.users` -- that table is managed by Supabase Auth
// (GoTrue) and the only supported way to remove a user is the Auth Admin
// API, which requires the service_role key. A key with that power must never
// ship inside the Flutter app, so it lives here instead, in an Edge Function
// that runs the one privileged call on the caller's behalf after checking
// that the caller IS that user.
//
// ProviderAuthRepository.deleteAccount() "permanently deletes the provider
// account and its listing" -- deleting the auth.users row cascades (via
// `on delete cascade` on provider_profiles.user_id) through every table that
// references the profile, so the listing and its history disappear in the
// same transaction Supabase Auth runs internally for the admin delete.
//
// Deploy: supabase functions deploy delete-account
// Call from Flutter: supabase.functions.invoke('delete-account')
// (no body needed; the function reads the caller's identity from the
// Authorization header Supabase's client SDK attaches automatically).
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "not_authenticated" }), { status: 401 });
  }

  // Identify the caller from their own access token; never trust a body.
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await adminClient.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "not_authenticated" }), { status: 401 });
  }
  const userId = userData.user.id;

  // Phase 035: no SQL cascade removes Storage objects. Remove the caller's
  // photos and credential evidence BEFORE the auth user, so a failure here
  // leaves the account intact and the user can retry.
  // Objects live flat at `<folder>/<file>`: photos under the listing's
  // profile id (since migration 0022; legacy ones under the user id), credential
  // evidence under the user id. Only file entries (id != null) are removed;
  // folder placeholders are ignored. Bounded passes: if a pass removes nothing
  // new, stop rather than loop until the runtime times out.
  const { data: profile, error: profileError } = await adminClient
    .from("provider_profiles").select("id").eq("user_id", userId).maybeSingle();
  if (profileError) {
    console.error("delete-account: profile lookup failed", profileError.message);
    return new Response(JSON.stringify({ error: "delete_failed" }), { status: 500 });
  }
  const targets: Array<[string, string]> = [
    ["provider-photos", userId],
    ["credential-evidence", userId],
    ...(profile ? [["provider-photos", profile.id] as [string, string]] : []),
  ];
  for (const [bucket, folder] of targets) {
    for (let pass = 0; pass < 50; pass++) {
      const { data: entries, error: listError } = await adminClient.storage
        .from(bucket)
        .list(folder, { limit: 100 });
      if (listError) {
        console.error("delete-account: list failed", bucket, listError.message);
        return new Response(JSON.stringify({ error: "delete_failed" }), { status: 500 });
      }
      const files = (entries ?? []).filter((e) => e.id !== null);
      if (files.length === 0) break;
      const { data: removed, error: removeError } = await adminClient.storage
        .from(bucket)
        .remove(files.map((f) => `${folder}/${f.name}`));
      if (removeError || !removed || removed.length === 0) {
        console.error("delete-account: remove failed", bucket, removeError?.message ?? "nothing removed");
        return new Response(JSON.stringify({ error: "delete_failed" }), { status: 500 });
      }
    }
  }

  // Cascades through provider_profiles; the delete trigger snapshots reports,
  // queues storage prefixes and writes the audit event.
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error("delete-account: auth delete failed", deleteError.message);
    return new Response(JSON.stringify({ error: "delete_failed" }), { status: 500 });
  }
  // Objects were already removed above; close the queued cleanup rows.
  // A failure here only leaves queue rows for the lifecycle job to retry.
  const { error: markError } = await adminClient.rpc("mark_storage_cleaned", {
    p_user_id: userId,
    p_profile_id: profile?.id ?? null,
  });
  if (markError) console.error("delete-account: mark_storage_cleaned failed", markError.message);

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
