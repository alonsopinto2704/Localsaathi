// media-upload-authorize, pure logic (phase 082). Runs under Deno (index.ts)
// and Node (backend/test/media-upload-authorize.test.mjs).
//
// POST /functions/v1/media-upload-authorize   Authorization: Bearer <the owner's token>
//   { "profileId": "<uuid>", "mime": "image/jpeg|png|webp", "bytes": <int> }
//   -> 200 { uploadId, bucket, path, token, expiresAt, maxBytes, mime }
//      400 invalid_request | validation_failed   401 not_authenticated
//      403 not_owner   404 not_found   429 rate_limited   503 feature_disabled
//
// The body can NOT name a path, bucket, class or owner: those are generated or
// looked up by public.request_media_upload under the caller's own token (so the
// database checks that this account owns that listing). The signed upload token
// is then minted for exactly the returned path. The client PUTs the bytes with
// that token and calls media-process with the upload id.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const MIMES = ["image/jpeg", "image/png", "image/webp"];

export interface Issued { uploadId: string; bucket: string; path: string; expiresAt: string; maxBytes: number; mime: string }
export type IssueResult = { ok: true; issued: Issued } | { ok: false; code: string };

export interface AuthorizeDeps {
  /** RPC public.request_media_upload with the CALLER's token; ok:false carries the error prefix. */
  issue(jwt: string, a: { profileId: string; mime: string; bytes: number }): Promise<IssueResult>;
  /** Storage signed upload token for exactly this bucket/path; null on failure. */
  sign(bucket: string, path: string): Promise<{ token: string } | null>;
}

export interface AuthorizeResponse { status: number; body: Record<string, unknown> }
const json = (status: number, body: Record<string, unknown>): AuthorizeResponse => ({ status, body });
const STATUS: Record<string, number> = {
  validation_failed: 400, not_owner: 403, not_found: 404, rate_limited: 429, feature_disabled: 503, not_authenticated: 401,
};

export async function handleAuthorize(
  req: { method: string; authorization: string | null; body: string },
  deps: AuthorizeDeps,
): Promise<AuthorizeResponse> {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const jwt = (req.authorization ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { error: "not_authenticated" });
  let body: Record<string, unknown>;
  try { body = JSON.parse(req.body); } catch { return json(400, { error: "invalid_request" }); }
  const { profileId, mime, bytes } = body ?? {};
  if (typeof profileId !== "string" || !UUID.test(profileId) || typeof mime !== "string" || !MIMES.includes(mime) ||
      typeof bytes !== "number" || !Number.isInteger(bytes) || bytes < 1) {
    return json(400, { error: "invalid_request" });
  }
  let result: IssueResult;
  try { result = await deps.issue(jwt, { profileId, mime, bytes }); } catch { return json(502, { error: "authorize_failed" }); }
  if (!result.ok) {
    const code = result.code in STATUS ? result.code : "authorize_failed";
    return json(STATUS[code] ?? 502, { error: code });
  }
  const signed = await deps.sign(result.issued.bucket, result.issued.path).catch(() => null);
  if (!signed) return json(502, { error: "authorize_failed" }); // the issued row simply expires unused
  return json(200, { ...result.issued, token: signed.token });
}
