// media-process, pure logic (phases 083, 084, 086). Runs under Deno (index.ts)
// and Node (backend/test/media-process.test.mjs).
//
// POST /functions/v1/media-process   Authorization: Bearer <the owner's token>
//   { "uploadId": "<uuid>" }
//   -> 200 { status: "approved", thumbPath, fullPath, width, height }
//      422 { error: <code> }   the file was rejected (not_an_image, mime_mismatch,
//                              malformed, dimensions_too_large, too_large, ...)
//      404/409/410/401/405/400/502 with a stable code, never a message or a path.
//
// Order of events, and why:
//   1. who: the user comes from the verified JWT; the database ties the upload
//      to that account and returns the stored path (the body can carry only the
//      upload id);
//   2. the bytes are read from the PRIVATE quarantine bucket and judged on their
//      content: magic bytes, strict container walk, header dimensions (no pixel
//      decode before the pixel budget passes), size;
//   3. metadata is stripped; the thumbnail is always re-encoded, the full image
//      is re-encoded unless it already fits the budget, is upright and is small
//      enough (then the stripped original is used as is);
//   4. EVERY public derivative is re-stripped and must be unchanged by a further
//      strip (isClean), within edge and byte budgets, before it is written;
//   5. derivatives are written under keys built from the upload id, then the
//      database approves (and re-checks the budgets and that the objects exist);
//      any failure removes what was written, so nothing half-done is public;
//   6. the original is deleted right away (the sweep is the backstop).
// The decoder is injected (Codec): it is the only part that touches pixels.
import { inspect, isClean, type Mime, ProcessError, sniff, strip } from "./image.ts";

export interface Derivative { kind: "thumb" | "full"; maxEdge: number; maxBytes: number; quality: number }
export interface Policy { derivatives: Derivative[] }

/** Contract: decode, apply EXIF orientation to the pixels, scale DOWN so the longest edge <= maxEdge
 * (never up), encode as WebP at `quality` with NO metadata. */
export interface Codec {
  resize(bytes: Uint8Array, mime: Mime, opts: { maxEdge: number; quality: number }): Promise<Uint8Array>;
}

export type BeginResult =
  | { ok: true; status: "processing"; profileId: string; bucket: string; path: string; mime: string; maxBytes: number }
  | { ok: true; status: "approved" }
  | { ok: false; code: "not_found" | "conflict" | "rejected" | "expired" | "failed"; detail?: string };

export interface ProcessDeps {
  authenticate(jwt: string): Promise<string | null>;
  begin(uploadId: string, userId: string): Promise<BeginResult>;
  policy(): Promise<Policy>;
  download(bucket: string, path: string): Promise<Uint8Array | null>;
  putPublic(path: string, bytes: Uint8Array, mime: string): Promise<boolean>;
  removePublic(paths: string[]): Promise<void>;
  removeOriginal(bucket: string, path: string): Promise<void>;
  complete(a: { uploadId: string; thumbPath: string; fullPath: string; thumbBytes: number; fullBytes: number; width: number; height: number }): Promise<boolean>;
  reject(uploadId: string, code: string, retry: boolean): Promise<void>;
  codec: Codec;
  /** milliseconds allowed for one decode/encode */
  codecTimeoutMs?: number;
}

export interface ProcessResponse { status: number; body: Record<string, unknown> }
const json = (status: number, body: Record<string, unknown>): ProcessResponse => ({ status, body });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const EXT: Record<Mime, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

interface Made { bytes: Uint8Array; mime: Mime; width: number; height: number }

function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  let t: ReturnType<typeof setTimeout>;
  return Promise.race([p, new Promise<T>((_, rej) => { t = setTimeout(() => rej(new Error("timeout")), ms); })]).finally(() => clearTimeout(t));
}

/** Validates, strips and derives. Throws ProcessError for a bad FILE; any other throw is a processing fault. */
export async function makeDerivatives(
  bytes: Uint8Array, declared: string, maxBytes: number, policy: Policy, codec: Codec, timeoutMs = 20_000,
): Promise<{ thumb: Made; full: Made }> {
  if (bytes.length < 1 || bytes.length > maxBytes) throw new ProcessError("too_large");
  const mime = sniff(bytes);
  if (!mime) throw new ProcessError("not_an_image"); // renamed executables, HTML, SVG, PDF...
  if (mime !== declared) throw new ProcessError("mime_mismatch");
  const info = inspect(bytes, mime);            // dimensions come from the header, before any decode
  const clean = strip(bytes, mime);
  inspect(clean, mime);                          // the rewrite must itself be a valid image
  const spec = (k: string) => policy.derivatives.find((d) => d.kind === k)!;
  const [thumbSpec, fullSpec] = [spec("thumb"), spec("full")];

  const encode = async (src: Uint8Array, srcMime: Mime, s: Derivative): Promise<Made> => {
    for (const quality of [s.quality, Math.max(30, s.quality - 20)]) {
      const raw = await withTimeout(codec.resize(src, srcMime, { maxEdge: s.maxEdge, quality }), timeoutMs);
      let out: Uint8Array, i;
      try { out = strip(raw, "image/webp"); i = inspect(out, "image/webp"); } catch { throw new Error("codec_output_invalid"); } // our fault, not the file's: retriable
      if (Math.max(i.width, i.height) > s.maxEdge) throw new Error("codec_output_too_large");
      if (out.length <= s.maxBytes) return { bytes: out, mime: "image/webp", width: i.width, height: i.height };
    }
    throw new ProcessError("over_budget");
  };

  const thumb = await encode(clean, mime, thumbSpec);
  const passthrough = Math.max(info.width, info.height) <= fullSpec.maxEdge && clean.length <= fullSpec.maxBytes &&
    (mime === "image/jpeg" || info.orientation === 1); // JPEG keeps an orientation-only EXIF; others must be rotated by the codec
  const full: Made = passthrough
    ? { bytes: clean, mime, width: info.width, height: info.height }
    : await encode(clean, mime, fullSpec);
  for (const d of [thumb, full]) {
    if (!isClean(d.bytes, d.mime)) throw new ProcessError("metadata_remains"); // unreachable unless strip() is wrong
  }
  return { thumb, full };
}

export async function handleProcess(
  req: { method: string; authorization: string | null; body: string },
  deps: ProcessDeps,
): Promise<ProcessResponse> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const jwt = (req.authorization ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { error: "not_authenticated" });
  let uploadId = "";
  try {
    const v = JSON.parse(req.body)?.uploadId;
    if (typeof v === "string" && UUID.test(v)) uploadId = v;
  } catch { /* falls through */ }
  if (!uploadId) return json(400, { error: "invalid_request" });

  let userId: string | null;
  try { userId = await deps.authenticate(jwt); } catch { return json(502, { error: "auth_unavailable" }); }
  if (!userId) return json(401, { error: "not_authenticated" });

  let begin: BeginResult;
  try { begin = await deps.begin(uploadId, userId); } catch { return json(502, { error: "processing_failed" }); }
  if (!begin.ok) {
    const map = { not_found: 404, conflict: 409, expired: 410, rejected: 422, failed: 502 } as const;
    return json(map[begin.code], { error: begin.code === "failed" ? "processing_failed" : begin.code, ...(begin.detail ? { code: begin.detail } : {}) });
  }
  if (begin.status === "approved") return json(200, { status: "approved" });

  const written: string[] = [];
  const fail = async (code: string, retry: boolean) => {
    if (written.length) await deps.removePublic(written).catch(() => {});
    await deps.reject(uploadId, code, retry).catch(() => {});
  };
  try {
    const original = await deps.download(begin.bucket, begin.path);
    if (!original) { await fail("processing_failed", true); return json(502, { error: "processing_failed" }); }
    const policy = await deps.policy();
    let made;
    try {
      made = await makeDerivatives(original, begin.mime, begin.maxBytes, policy, deps.codec, deps.codecTimeoutMs);
    } catch (e) {
      if (e instanceof ProcessError) {
        await fail(e.code, false);
        await deps.removeOriginal(begin.bucket, begin.path).catch(() => {});
        return json(422, { error: e.code });
      }
      throw e;
    }
    const key = (kind: string, m: Mime) => `${begin.profileId}/${uploadId}-${kind}.${EXT[m]}`;
    const thumbPath = key("thumb", made.thumb.mime), fullPath = key("full", made.full.mime);
    for (const [path, d] of [[thumbPath, made.thumb], [fullPath, made.full]] as const) {
      written.push(path);
      if (!await deps.putPublic(path, d.bytes, d.mime)) throw new Error("write_failed");
    }
    const ok = await deps.complete({
      uploadId, thumbPath, fullPath, thumbBytes: made.thumb.bytes.length, fullBytes: made.full.bytes.length,
      width: made.full.width, height: made.full.height,
    });
    if (!ok) throw new Error("complete_failed");
    await deps.removeOriginal(begin.bucket, begin.path).catch(() => {});
    return json(200, { status: "approved", thumbPath, fullPath, width: made.full.width, height: made.full.height });
  } catch {
    await fail("processing_failed", true);   // transient: the owner may retry within the attempt limit
    return json(502, { error: "processing_failed" });
  }
}

