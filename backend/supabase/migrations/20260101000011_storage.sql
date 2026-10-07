-- Storage buckets for provider photos (public) and credential evidence
-- (private). Convention: every object's path starts with the owning
-- provider's auth user id, e.g. `{user_id}/{photo_id}.jpg` -- that single
-- convention is what the policies below check, so Antigravity's upload code
-- just needs to upload to `${supabase.auth.currentUser.id}/...`.
insert into storage.buckets (id, name, public)
values
  ('provider-photos', 'provider-photos', true),
  ('credential-evidence', 'credential-evidence', false)
on conflict (id) do nothing;

-- provider-photos: public read (bucket is public, so no SELECT policy is
-- even required for anon -- Storage serves public-bucket objects directly);
-- the owner may upload/replace/remove only inside their own folder.
create policy "owner uploads own provider photos" on storage.objects for insert
  with check (bucket_id = 'provider-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner replaces own provider photos" on storage.objects for update
  using (bucket_id = 'provider-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner deletes own provider photos" on storage.objects for delete
  using (bucket_id = 'provider-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- credential-evidence: private. Owner may upload/read/delete their own
-- evidence files; admins may read any (to actually review a claim); nobody
-- else can read anything in this bucket, including other providers.
create policy "owner uploads own credential evidence" on storage.objects for insert
  with check (bucket_id = 'credential-evidence' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owner reads own credential evidence" on storage.objects for select
  using (bucket_id = 'credential-evidence' and (
    (storage.foldername(name))[1] = auth.uid()::text or public.is_admin()
  ));
create policy "owner deletes own credential evidence" on storage.objects for delete
  using (bucket_id = 'credential-evidence' and (storage.foldername(name))[1] = auth.uid()::text);
