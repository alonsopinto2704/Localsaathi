-- Phase 087 (migration 0036): atomic gallery updates. Phones +91900036xxxx.
-- PGlite is a single connection, so true parallel transactions are NOT run here;
-- the serialisation point (a row lock taken first in every gallery RPC) is
-- exercised by the sequential "one slot left, two candidates" case below and
-- should be re-run with parallel sessions on a hosted database.
begin;
select plan(28);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000360001')::text),
  ('other', tests.create_phone_user('+919000360002')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000360001', 'Gallery Listing')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000360002', 'Other Gallery Listing')::text;

create function pg_temp.upload(p_who text, p_status text default 'approved') returns text language plpgsql as $$
declare
  v_id uuid := tests.media_upload((select value::uuid from fx where key = case p_who when 'owner' then 'a' else 'b' end),
                                  (select value::uuid from fx where key = p_who), p_status);
begin
  return (select profile_id::text || '/' || id::text || '-full.webp' from private.media_uploads where id = v_id);
end;
$$;
create function pg_temp.add(p_profile text, p_path text) returns jsonb language sql as $$
  select public.add_provider_photo(p_profile::uuid, p_path, 'cap');
$$;
create function pg_temp.photos(p_profile text) returns text[] language sql as $$
  select coalesce(array_agg(storage_path order by uploaded_at), '{}') from public.provider_photos where provider_id = p_profile::uuid;
$$;

grant execute on function pg_temp.upload(text, text), pg_temp.add(text, text), pg_temp.photos(text) to anon, authenticated, service_role;

-- Legacy mode (pipeline off) keeps the owner-folder rule.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(format($sql$ select public.add_provider_photo(%L::uuid, %L, 'old') $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'a') || '/legacy.jpg'),
  'pipeline off: an own-folder path is accepted as before');
select throws_like(format($sql$ select public.add_provider_photo(%L::uuid, %L, 'old') $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'b') || '/x.jpg'),
  'validation_failed:%', 'pipeline off: another listing''s folder is still refused');
reset role;
delete from public.provider_photos;
select tests.set_flag('media_pipeline', true);

-- Pipeline mode: only approved, unattached uploads of this listing and account.
create temporary table up (key text primary key, value text);
select tests.share_fixture('up');
insert into up values
  ('ok1', pg_temp.upload('owner')), ('ok2', pg_temp.upload('owner')), ('ok3', pg_temp.upload('owner')),
  ('proc', pg_temp.upload('owner', 'processing')), ('rej', pg_temp.upload('owner', 'rejected')),
  ('theirs', pg_temp.upload('other'));
insert into up select 'orig', object_path from private.media_uploads where status = 'processing' and profile_id = (select value::uuid from fx where key = 'a');

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'a') || '/evil.jpg'),
  'validation_failed: photo is not an approved%', 'a hand-made path in the right folder is refused');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'orig')),
  'validation_failed: photo is not an approved%', 'the quarantine original path cannot be attached');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'proc')),
  'validation_failed: photo is not an approved%', 'an upload still processing cannot be attached');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'rej')),
  'validation_failed: photo is not an approved%', 'a rejected upload cannot be attached by supplying its URL');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'theirs')),
  'validation_failed: photo is not an approved%', 'another account''s approved upload cannot be attached');
select lives_ok(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'ok1')),
  'an approved, unattached upload of this listing can be attached');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'ok1')),
  'validation_failed: photo is not an approved%', 'the same upload cannot be attached twice');
reset role;
select is((select attached from private.media_uploads where full_path = (select value from up where key = 'ok1')), true, 'the upload is marked attached');
select is(pg_temp.photos((select value from fx where key = 'a')), array[(select value from up where key = 'ok1')], 'only the approved photo is in the gallery');
select ok(public.get_public_profile((select value::uuid from fx where key = 'a'))::text not like '%' || (select value from up where key = 'rej') || '%',
  'the public profile never mentions a rejected upload''s path');

-- Limit: configurable, enforced server-side; one slot left, two candidates.
update private.media_settings set int_value = 2 where key = 'max_photos';
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'ok2')),
  'the second photo fits a limit of 2');
select throws_like(format($sql$ select pg_temp.add(%L, %L) $sql$, (select value from fx where key = 'a'), (select value from up where key = 'ok3')),
  'validation_failed: free listings may publish at most 2%', 'the limit is read from settings and enforced');
reset role;
update private.media_settings set int_value = 5 where key = 'max_photos';
select is(cardinality(pg_temp.photos((select value from fx where key = 'a'))), 2, 'the gallery holds exactly the limit, no more');

-- Reorder.
insert into fx select 'p1', (select id::text from public.provider_photos where storage_path = (select value from up where key = 'ok1'));
insert into fx select 'p2', (select id::text from public.provider_photos where storage_path = (select value from up where key = 'ok2'));
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(format($sql$ select public.set_photo_order(%L::uuid, array[%L, %L]::uuid[]) $sql$, (select value from fx where key = 'a'),
  (select value from fx where key = 'p2'), (select value from fx where key = 'p1')), 'a full permutation reorders the gallery');
select is(pg_temp.photos((select value from fx where key = 'a')), array[(select value from up where key = 'ok2'), (select value from up where key = 'ok1')],
  'the new order is what the projection will return');
select throws_like(format($sql$ select public.set_photo_order(%L::uuid, array[%L]::uuid[]) $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'p1')),
  'validation_failed:%', 'a partial list is refused (nothing dropped silently)');
select throws_like(format($sql$ select public.set_photo_order(%L::uuid, array[%L, %L]::uuid[]) $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'p1'), (select value from fx where key = 'p1')),
  'validation_failed:%', 'duplicates are refused');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select throws_like(format($sql$ select public.set_photo_order(%L::uuid, array[%L, %L]::uuid[]) $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'p1'), (select value from fx where key = 'p2')),
  'not_owner:%', 'another account cannot reorder this gallery');
reset role;

-- Replacement is atomic: a bad replacement changes nothing; a good one swaps in place.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(format($sql$ select public.replace_provider_photo(%L::uuid, %L, 'new caption') $sql$, (select value from fx where key = 'p1'), (select value from up where key = 'rej')),
  'validation_failed:%', 'replacing with a rejected upload fails');
reset role;
select is(pg_temp.photos((select value from fx where key = 'a')), array[(select value from up where key = 'ok2'), (select value from up where key = 'ok1')],
  'after the failed replacement the previous gallery is exactly as it was');
select is((select status from private.media_uploads where full_path = (select value from up where key = 'ok1')), 'approved', 'and the old upload is still live');
insert into up select 'new', pg_temp.upload('owner');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(format($sql$ select public.replace_provider_photo(%L::uuid, %L, 'new caption') $sql$, (select value from fx where key = 'p1'), (select value from up where key = 'new')),
  'a valid replacement succeeds');
reset role;
select is(pg_temp.photos((select value from fx where key = 'a')), array[(select value from up where key = 'ok2'), (select value from up where key = 'new')],
  'the new photo takes the old one''s position, so the URL changes (old revision not reused)');
select is((select status from private.media_uploads where full_path = (select value from up where key = 'ok1')), 'retired', 'the replaced revision is retired so its blobs are swept');

-- Delete retires too, and anon cannot touch any of it.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select public.delete_provider_photo((select value::uuid from fx where key = 'p1'));
reset role;
select is((select status from private.media_uploads where full_path = (select value from up where key = 'new')), 'retired', 'deleting a photo retires its upload');
select tests.authenticate_as_anon();
select throws_ok(format($sql$ select public.set_photo_order(%L::uuid, array[]::uuid[]) $sql$, (select value from fx where key = 'a')), '42501', null, 'anon cannot reorder');
reset role;

select * from finish();
rollback;
