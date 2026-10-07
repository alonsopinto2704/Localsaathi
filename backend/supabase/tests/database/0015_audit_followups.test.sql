-- Regressions for migration 0022 (2026-10-07 audits of phases 001-040).
-- Phone range +91900000150x.
begin;
select plan(14);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000001501')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001501', 'Followup Listing')::text;
insert into public.service_categories (id, group_id, name, icon_key, is_approved_for_launch)
  select 'test-category-unapproved', group_id, 'Unapproved', 'other', false
  from public.service_categories where id = 'test-category-plumbing';

-- 1. A public listing with a photo never carries the owner's auth user id.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select public.add_provider_photo((select value::uuid from fx where key = 'a'),
  (select value from fx where key = 'a') || '/p1.jpg', 'work');
reset role;
insert into public.provider_photos (provider_id, caption, storage_path, is_placeholder)
  values ((select value::uuid from fx where key = 'a'), 'legacy',
          (select value from fx where key = 'owner') || '/legacy.jpg', false);
select tests.authenticate_as_anon();
select ok(
  position((select value from fx where key = 'owner') in
           public.get_public_profile((select value::uuid from fx where key = 'a'))::text) = 0,
  'public profile JSON contains no trace of the owner''s user id (new and legacy photo paths)');
select is(
  (select count(*)::int from jsonb_array_elements(public.get_public_profile((select value::uuid from fx where key = 'a'))->'photos') p
   where p->>'storagePath' like (select value from fx where key = 'a') || '/%'),
  1, 'a profile-keyed photo path is still public');
reset role;

-- 2. Publication invariant survives edits; 4. one revision per call; typed payloads.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"categoryIds":["test-category-unapproved"]}') $sql$,
         (select value from fx where key = 'a')),
  '%validation_failed:%category open for listings%', 'a published listing cannot drop to only unapproved categories');
select is(
  (select category_id from public.provider_categories where provider_id = (select value::uuid from fx where key = 'a')),
  'test-category-plumbing', 'the rejected edit left the categories unchanged');
insert into fx select 'rev0', (public.get_owner_profile((select value::uuid from fx where key = 'a'))->>'revision');
select is(
  (public.update_profile_full((select value::uuid from fx where key = 'a'),
     '{"phoneDisplayConsented": false, "description": "x"}')->>'revision')::bigint,
  (select value::bigint from fx where key = 'rev0') + 1,
  'a consent change plus an edit bumps revision exactly once');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"serviceAreas": 5}') $sql$, (select value from fx where key = 'a')),
  '%validation_failed:%', 'a scalar serviceAreas is validation_failed, not a raw 22023');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"pinCodes": ["40005"]}') $sql$, (select value from fx where key = 'a')),
  '%validation_failed:%pin codes%', 'a malformed pin code is rejected rather than truncated');
reset role;

-- 1. Flags: off means feature_disabled for end users; only admins change them, audited.
select tests.set_flag('media_intake', false);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.add_provider_photo(%L::uuid, %L) $sql$, (select value from fx where key = 'a'),
         (select value from fx where key = 'a') || '/p2.jpg'),
  '%feature_disabled:%', 'photo upload is refused while media_intake is off');
select throws_like($sql$ select public.set_feature_flag('media_intake', true, 'try') $sql$,
  '%not_owner:%', 'a provider cannot change a feature flag');
reset role;
insert into fx values ('admin', tests.create_admin('+919000001502')::text);
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin'));
select public.set_feature_flag('media_intake', true, 'pilot cohort ready');
reset role;
select ok(
  exists (select 1 from private.audit_events where action = 'feature_flag_set' and target_id = 'media_intake'),
  'a flag change is audited');

-- 5. Credential evidence must be the owner's own object.
select tests.set_flag('credential_intake', true);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ insert into public.credential_records (provider_id, title, evidence_storage_path) values (%L, 'MBBS', %L) $sql$,
         (select value from fx where key = 'a'), (select value from fx where key = 'admin') || '/doc.pdf'),
  '%validation_failed:%own folder%', 'credential evidence pointing at another user''s folder is rejected');
reset role;

-- 6. Deleting a photo queues that exact object, nothing broader.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select public.delete_provider_photo((select id from public.provider_photos where storage_path like '%/p1.jpg'));
reset role;
select is(
  (select prefix from private.storage_cleanup_queue where bucket_id = 'provider-photos' and processed_at is null),
  (select value from fx where key = 'a') || '/p1.jpg', 'a deleted photo queues its exact path');

-- 7. Formatted phone numbers are refused by the audit writer; timestamps are not.
select throws_like(
  $sql$ select private.write_audit('test_action', 'x', 'x', 'call +91 98765 43210') $sql$,
  '%audit_redaction%', 'a spaced phone number in the reason is refused');
select lives_ok(
  $sql$ select private.write_audit('test_action', 'x', 'x', null, jsonb_build_object('at', '2026-10-07T10:00:00Z', 'epoch', 1759831200)) $sql$,
  'an ISO timestamp is not mistaken for a phone number');

select * from finish();
rollback;
