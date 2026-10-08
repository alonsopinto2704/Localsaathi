// media-upload-authorize (phase 082): see logic.ts for the contract.
//
// NOT DEPLOYED OR RUN. Unverified until a hosted project exists: that
// createSignedUploadUrl binds the token to the path, how long Storage honours the
// token (the database enforces its own 15-minute rule at processing time, so a
// longer token cannot extend it), and that a PUT with the token bypasses or
// satisfies bucket RLS the way this design assumes.
//
// Deploy: supabase functions deploy media-upload-authorize
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleAuthorize, type IssueResult } from "./logic.ts";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(URL_, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve(async (req: Request) => {
  const result = await handleAuthorize(
    { method: req.method, authorization: req.headers.get("Authorization"), body: await req.text() },
    {
      async issue(jwt, a): Promise<IssueResult> {
        // The caller's own token: auth.uid() inside the RPC is the owner check.
        const asUser = createClient(URL_, Deno.env.get("SUPABASE_ANON_KEY")!, {
          auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jwt}` } },
        });
        const { data, error } = await asUser.rpc("request_media_upload", {
          p_profile_id: a.profileId, p_class: "portfolio_original", p_declared_mime: a.mime, p_declared_bytes: a.bytes,
        });
        if (error) return { ok: false, code: (error.message ?? "").split(":")[0] };
        return { ok: true, issued: data };
      },
      async sign(bucket, path) {
        const { data, error } = await admin.storage.from(bucket).createSignedUploadUrl(path);
        return error || !data ? null : { token: data.token };
      },
    },
  );
  return new Response(JSON.stringify(result.body), { status: result.status, headers: { "Content-Type": "application/json" } });
});
