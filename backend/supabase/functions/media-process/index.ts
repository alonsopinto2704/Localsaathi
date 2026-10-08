// media-process (phases 083, 084, 086): see logic.ts for the contract and rules.
//
// NOT DEPLOYED OR RUN. The pure logic is tested in backend/test/media-process.test.mjs
// against a FAKE codec. Everything in this file is unverified until it runs on a
// hosted project: the supabase-js calls, Storage upload/remove semantics, and
// above all the ImageMagick WASM codec (cold start, memory ceiling for a 16 MP
// decode, WebP output size at the configured quality). Measure before enabling
// the media_pipeline flag.
//
// Deploy: supabase functions deploy media-process   (service role is injected)
import { createClient } from "jsr:@supabase/supabase-js@2";
import { ImageMagick, initializeImageMagick, MagickFormat, MagickGeometry } from "npm:@imagemagick/magick-wasm@0.0.30";
import { type BeginResult, type Codec, handleProcess, type Policy } from "./logic.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

await initializeImageMagick(await Deno.readFile(new URL("magick.wasm", import.meta.resolve("npm:@imagemagick/magick-wasm@0.0.30"))));

// Decode -> rotate pixels upright -> scale down only -> drop every profile/comment -> WebP.
const codec: Codec = {
  resize: (bytes, _mime, { maxEdge, quality }) =>
    Promise.resolve(ImageMagick.read(bytes, (img) => {
      img.autoOrient();
      const geometry = new MagickGeometry(maxEdge, maxEdge);
      geometry.greater = true; // "only shrink larger images" (ImageMagick '>' flag)
      img.resize(geometry);
      img.strip();
      img.quality = quality;
      return img.write(MagickFormat.WebP, (data) => data.slice());
    })),
};

const rpcError = (e: { message?: string }): BeginResult => {
  const code = (e.message ?? "").split(":")[0];
  return { ok: false, code: code === "not_found" ? "not_found" : code === "conflict" ? "conflict" : "failed" };
};

Deno.serve(async (req: Request) => {
  const result = await handleProcess(
    { method: req.method, authorization: req.headers.get("Authorization"), body: await req.text() },
    {
      codec,
      async authenticate(jwt) {
        const { data, error } = await admin.auth.getUser(jwt);
        return error || !data?.user ? null : data.user.id;
      },
      async begin(uploadId, userId): Promise<BeginResult> {
        const { data, error } = await admin.rpc("begin_media_processing", { p_upload_id: uploadId, p_user_id: userId });
        if (error) return rpcError(error);
        if (data.status === "approved") return { ok: true, status: "approved" };
        if (data.status === "rejected" || data.status === "expired") return { ok: false, code: data.status, detail: data.code };
        return { ok: true, status: "processing", profileId: data.profileId, bucket: data.bucket, path: data.path, mime: data.mime, maxBytes: data.maxBytes };
      },
      async policy(): Promise<Policy> {
        const { data, error } = await admin.rpc("media_policy");
        if (error) throw new Error("policy_unavailable");
        return { derivatives: data.derivatives };
      },
      async download(bucket, path) {
        const { data, error } = await admin.storage.from(bucket).download(path);
        return error || !data ? null : new Uint8Array(await data.arrayBuffer());
      },
      async putPublic(path, bytes, mime) {
        // upsert:false -- a key is written once; a replacement is a new upload id and a new URL.
        const { error } = await admin.storage.from("provider-photos").upload(path, bytes, { contentType: mime, upsert: false, cacheControl: "31536000" });
        return !error;
      },
      async removePublic(paths) { await admin.storage.from("provider-photos").remove(paths); },
      async removeOriginal(bucket, path) { await admin.storage.from(bucket).remove([path]); },
      async complete(a) {
        const { error } = await admin.rpc("complete_media_upload", {
          p_upload_id: a.uploadId, p_thumb_path: a.thumbPath, p_full_path: a.fullPath, p_thumb_bytes: a.thumbBytes,
          p_full_bytes: a.fullBytes, p_width: a.width, p_height: a.height, p_clean: true,
        });
        return !error;
      },
      async reject(uploadId, code, retry) {
        await admin.rpc("reject_media_upload", { p_upload_id: uploadId, p_code: code, p_retry: retry });
      },
    },
  );
  return new Response(JSON.stringify(result.body), { status: result.status, headers: { "Content-Type": "application/json" } });
});
