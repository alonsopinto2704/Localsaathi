# Media storage (phases 081-087)

Status: implemented and tested locally on PGlite and Node with fakes. **Real Supabase Storage / CDN behaviour has not been observed** (no hosted project, no Docker). Items that depend on it are marked UNVERIFIED and are listed in the evidence files (`tasks/evidence/phase-081.md` to `phase-087.md`).

## 1. Classes and who may do what

Source of truth: `private.media_classes` (migration `20261008000030`). Buckets are created from that table and a test compares them.

| Class | Bucket | Public | Limit / types | Upload | Read | Publish | Delete / expiry |
|---|---|---|---|---|---|---|---|
| `portfolio_original` | `media-quarantine` | no | 8 MiB; JPEG, PNG, WebP | Owner, only to a server-issued path with a signed token (no client storage policy) | Service role only | Never; the pipeline writes derivatives | Service role: removed right after processing, backstop 1 h after processed/rejected, abandoned after expiry + 2 h |
| `portfolio_public` | `provider-photos` | yes (CDN) | 512 KiB bucket cap; budgets 40 KB thumb / 300 KB full | Service role only when `media_pipeline` is on (pre-081 owner-folder rule while off) | Anyone with the unguessable key; keys are exposed only for published listings | Automatic: exists only after validation + stripping | Owner via `delete_provider_photo` (retires the upload), blobs removed by the sweep |
| `credential_evidence` | `credential-evidence` | no | 10 MiB; JPEG, PNG, WebP, PDF | Owner, own folder (moves behind the pipeline in phase 088) | Owner + admins, signed link 300 s | Never public | Owner; retention job on listing deletion |
| `ai_attachment` | `ai-attachments` | no | 5 MiB; images | Nobody yet (reserved) | Nobody yet | Never public | 24 h expiry |

Unclassified buckets get no policy, so they are private by default.

## 2. Flow (with `media_pipeline` and `media_intake` on)

1. `media-upload-authorize` (caller's JWT) calls `request_media_upload`: the database checks the caller owns the (active) listing, picks the class/bucket, **generates the path** `<profile_id>/<upload_id>`, stores account + MIME + byte ceiling + 15-minute expiry, and the function mints a signed upload token for exactly that path. The body cannot carry a path, bucket, class or owner.
2. The client uploads to quarantine with the token.
3. `media-process` (caller's JWT, body `{uploadId}`): `begin_media_processing` ties the upload to that account, requires the object to exist at the stored path, to have been written before expiry and to fit the ceiling, and bounds attempts (3). The function reads the **bytes** from quarantine and judges them: magic bytes (not name or declared type), strict container walk, header dimensions before any pixel decode (max 8000 px edge, 16 MP), size.
4. Metadata is stripped (JPEG keeps only an orientation EXIF; PNG/WebP/JPEG drop EXIF, XMP, ICC, text/time chunks, comments, JFIF thumbnails and trailing bytes). Thumbnail (<= 320 px, <= 40 KB) always goes through the codec; the full image (<= 1280 px, <= 300 KB) is the stripped original when it already fits and is upright, otherwise re-encoded. Every derivative is re-stripped and must be unchanged by a further strip before it is written.
5. Derivatives are written to `provider-photos` as `<profile>/<upload>-thumb.webp` and `-full.<ext>` (upload id in the key: a replacement is a new URL, the old revision is never overwritten; cache-control is immutable). `complete_media_upload` approves only if both objects exist, keys are generated for this upload, budgets hold and the caller attests clean. Any failure removes what was written and records a short code.
6. The original is deleted immediately.
7. `add_provider_photo(profile, fullPath)` attaches only an approved, unattached upload of that account and listing. `replace_provider_photo`, `delete_provider_photo`, `set_photo_order` are single transactions behind a listing row lock; the limit is `private.media_settings.max_photos` (5).
8. `media-gc` (scheduled, service role): `expire_media_uploads`, then `list_media_orphans` (SQL decides; ownership-scoped reference checks), re-check with `media_object_deletable`, delete through the Storage API.

## 3. Switches and cutover order

| Flag | Default | Meaning |
|---|---|---|
| `media_intake` | off | Existing photo kill switch (all photo writes). |
| `media_pipeline` | off | Photo intake goes through quarantine + processing; clients lose direct write access to `provider-photos`. |
| `media_cleanup` | on | Orphan sweep kill switch (also pauses on a mass-deletion anomaly). |

Turn on **`media_pipeline` before `media_intake`**. With `media_pipeline` off and `media_intake` on, the pre-081 behaviour (client uploads to the owner folder) applies; that is the only reason the flag exists, so earlier phases' suites stay valid. Remove the legacy branch (and this flag) once the Flutter client uses the pipeline.

Safe stops: `media_pipeline` off stops issuing uploads (approved reads continue); `media_cleanup` off pauses deletion; setting `media_intake` off stops all photo writes.

## 4. Known limits

- Ordering is `uploaded_at`; `set_photo_order` rewrites it (a `position` column needs a projection change owned elsewhere).
- Public bucket: anyone who knows a key can fetch it, including for an unpublished or suspended listing. Keys are uuid-based and shown only for published listings; hard revocation means deleting the object. Making the bucket private with signed URLs is the alternative if that residual is unacceptable.
- ICC profiles are dropped (wide-gamut colours may shift), as the Flutter client already does.
- Placeholders (blur hash / dominant colour) are not implemented.
- The ImageMagick WASM codec, signed-upload semantics, bucket file-size/MIME enforcement, CDN caching and blob deletion are unverified.
