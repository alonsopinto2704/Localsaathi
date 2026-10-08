// media-gc (phase 085): see logic.ts for the contract.
//
// NOT DEPLOYED OR RUN. Unverified until a hosted project exists: that
// Storage's remove() deletes the blob and its storage.objects row together, that
// the schedule fires, and the cost of list_media_orphans on a large bucket (it
// scans every object of two buckets; add an index on storage.objects
// (bucket_id, created_at) or batch by prefix if that is slow).
//
// Deploy: supabase functions deploy media-gc ; schedule with pg_cron + pg_net or
// the dashboard cron, sending the service role key as the bearer token.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleGc } from "./logic.ts";

const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

Deno.serve(async (req: Request) => {
  const result = await handleGc(
    { method: req.method, authorization: req.headers.get("Authorization"), body: await req.text() },
    {
      isOperator: (a) => a === `Bearer ${SERVICE_ROLE_KEY}`,
      async expire() {
        const { error } = await admin.rpc("expire_media_uploads");
        if (error) throw new Error("expire_failed");
      },
      async list(limit, acceptAnomaly) {
        const { data, error } = await admin.rpc("list_media_orphans", { p_limit: limit, p_accept_anomaly: acceptAnomaly });
        if (error) throw new Error("list_failed");
        return data;
      },
      async deletable(bucket, name) {
        const { data, error } = await admin.rpc("media_object_deletable", { p_bucket: bucket, p_name: name });
        return !error && data === true;
      },
      async remove(bucket, name) {
        const { data, error } = await admin.storage.from(bucket).remove([name]);
        return !error && (data?.length ?? 0) > 0;
      },
    },
  );
  return new Response(JSON.stringify(result.body), { status: result.status, headers: { "Content-Type": "application/json" } });
});
