-- 0030: phase 081, storage classification contract.
--
-- One table says what every media class IS: which bucket holds it, whether it
-- is public, how big/what type, how long it may exist, how long a signed link
-- lives, and who may upload/read/publish/delete. The buckets below are created
-- FROM that table so the two cannot drift (tests compare them).
--
-- Classes (docs/media-storage.md has the human-readable matrix):
--   portfolio_original  private quarantine. Server-issued path, service-role
--                       writes only, deleted within an hour of being processed.
--   portfolio_public    the public CDN bucket. Holds ONLY server-made derivatives
--                       of approved originals (phases 083-086).
--   credential_evidence private; unchanged until phase 088 moves intake behind
--                       the same pipeline.
--   ai_attachment       reserved: bucket exists, private, no client policy, no
--                       issuance function. Nothing can use it yet.
--
-- Unclassified buckets/objects stay private: new buckets are created private by
-- default in Storage and nothing here grants a client policy to them.
--
-- Staged cutover: the flag media_pipeline (default OFF) switches photo intake to
-- the pipeline. While it is off the pre-081 behaviour is untouched, which keeps
-- the earlier phases' suites valid; media_intake is also off in every
-- environment, so no photo can be uploaded either way. Turn media_pipeline on
-- BEFORE media_intake. Real Storage/CDN behaviour is unverified (no hosted
-- project yet): see tasks/evidence/phase-081.md.

create table private.media_classes (
  class text primary key check (class ~ '^[a-z_]{3,30}$'),
  bucket_id text not null,
  is_public boolean not null,
  max_bytes int not null check (max_bytes > 0),
  allowed_mime text[] not null,
  expires_after interval,                   -- how long an object may live unreferenced/unfinished
  signed_url_ttl_s int check (signed_url_ttl_s is null or signed_url_ttl_s between 30 and 3600),
  status text not null check (status in ('active', 'reserved')),
  upload_authority text not null,
  read_authority text not null,
  publish_authority text not null,
  delete_authority text not null
);
revoke all on private.media_classes from public, anon, authenticated;

insert into private.media_classes
  (class, bucket_id, is_public, max_bytes, allowed_mime, expires_after, signed_url_ttl_s, status,
   upload_authority, read_authority, publish_authority, delete_authority)
values
  ('portfolio_original', 'media-quarantine', false, 8388608, array['image/jpeg', 'image/png', 'image/webp'],
   interval '1 hour', null, 'active',
   'owner, only to a server-issued path and token (request_media_upload); no client storage policy',
   'service role only; no client or admin read of originals',
   'never published; the pipeline writes derivatives to portfolio_public',
   'service role: removed within an hour of processing or rejection, or by the orphan sweep'),
  ('portfolio_public', 'provider-photos', true, 524288, array['image/jpeg', 'image/png', 'image/webp'],
   null, null, 'active',
   'service role only (pipeline output); clients write here only while media_pipeline is off',
   'anyone, by unguessable object key, via the CDN; keys are shown only for published listings',
   'automatic: a derivative exists only after validation and stripping passed',
   'owner through delete_provider_photo, which queues the blobs; the orphan sweep removes them'),
  ('credential_evidence', 'credential-evidence', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'], null, 300, 'active',
   'owner, into own folder (policy; moves behind the pipeline in phase 088)',
   'owner and administrators, by signed link only',
   'never public',
   'owner; the retention job when the listing is deleted'),
  ('ai_attachment', 'ai-attachments', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'],
   interval '24 hours', 300, 'reserved',
   'nobody yet (no issuance function, no policy)',
   'nobody yet', 'never public', 'automatic expiry after 24 hours');

-- Derivative specs: the SMALL fixed set (phase 086). max_bytes is the budget.
create table private.media_derivatives (
  kind text primary key check (kind in ('thumb', 'full')),
  max_edge int not null check (max_edge between 64 and 4096),
  max_bytes int not null check (max_bytes > 0),
  quality int not null check (quality between 30 and 95)
);
revoke all on private.media_derivatives from public, anon, authenticated;
insert into private.media_derivatives values ('thumb', 320, 40960, 70), ('full', 1280, 307200, 80);

-- Server-side knobs that were hard-coded (phase 087 reads max_photos).
create table private.media_settings (
  key text primary key,
  int_value int not null check (int_value > 0)
);
revoke all on private.media_settings from public, anon, authenticated;
insert into private.media_settings values
  ('max_photos', 5),               -- was a literal in check_photo_limit
  ('upload_ttl_minutes', 15),      -- upload authorisation lifetime
  ('max_open_uploads', 10),        -- issued + processing per listing
  ('max_attempts', 3),             -- processing attempts per upload
  ('processing_timeout_minutes', 10),
  ('original_retention_minutes', 60),
  ('orphan_grace_minutes', 120);

-- Buckets are created from the table (existing ones are aligned to it).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
select bucket_id, bucket_id, is_public, max_bytes, allowed_mime from private.media_classes
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into public.feature_flags (key, enabled, reason) values
  ('media_pipeline', false, 'photo intake via quarantine + server processing (081-087); turn on before media_intake'),
  ('media_cleanup', true, 'orphan sweep; turn off to pause deletion when reference checks look wrong');

-- With the pipeline on, no client may write or remove objects in the public
-- bucket: the pipeline (service role, bypasses RLS) is the only writer. media-
-- quarantine and ai-attachments have no permissive policy at all, so clients
-- are denied by default there.
create policy "pipeline owns provider photos" on storage.objects as restrictive for all
  using (bucket_id <> 'provider-photos' or not public.flag_enabled('media_pipeline'))
  with check (bucket_id <> 'provider-photos' or not public.flag_enabled('media_pipeline'));
