-- Phases 035/036: append-only audit trail, deletion data map, retention.
-- Phone range +91900000130x.
begin;
select plan(15);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('admin', tests.create_admin('+919000001301')::text),
  ('owner', tests.create_phone_user('+919000001302')::text),
  ('plain', tests.create_phone_user('+919000001303')::text),
  ('keeper', tests.create_phone_user('+919000001304')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001302', 'Doomed Listing')::text;
insert into fx select 'k', tests.create_published_provider(
  (select value::uuid from fx where key = 'keeper'), '+919000001304', 'Kept Listing')::text;

select private.write_audit('test_event', 'test', 'x', 'seed row');

-- Append-only, even for a superuser.
select throws_like($sql$ update private.audit_events set reason = 'edited' $sql$, '%append-only%', 'audit_events UPDATE raises');
select throws_like($sql$ delete from private.audit_events $sql$, '%append-only%', 'audit_events DELETE raises');
select throws_like($sql$ truncate private.audit_events $sql$, '%append-only%', 'audit_events TRUNCATE raises');

-- API roles cannot read it.
select tests.authenticate_as_anon();
select throws_ok($sql$ select * from private.audit_events $sql$, '42501', null, 'anon cannot select audit_events');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'plain'));
select throws_ok($sql$ select * from private.audit_events $sql$, '42501', null, 'authenticated cannot select audit_events');
select throws_like($sql$ select public.admin_audit_events() $sql$, '%not_owner:%', 'admin_audit_events refuses a non-admin');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'admin'));
select is(jsonb_typeof(public.admin_audit_events(50)), 'array', 'admin_audit_events returns an array to an admin');
select ok(
  exists (select 1 from jsonb_array_elements(public.admin_audit_events(500)) e
          where e->>'action' = 'admin_granted' and e->>'target_id' = (select value from fx where key = 'admin')),
  'granting admin was itself audited');
select throws_like(
  format($sql$ select public.set_listing_moderation(%L::uuid, 'suspended', '') $sql$, (select value from fx where key = 'a')),
  '%validation_failed:%', 'suspending without a reason is rejected');
reset role;

select throws_like(
  $sql$ select private.write_audit('test_event', 'test', 'x', null, '{"phone":"9876543210"}') $sql$,
  '%audit_redaction:%', 'write_audit refuses details containing a 10-digit number');

-- Deleting a listing: reports survive with a snapshot, storage cleanup is queued, audit written.
insert into public.reports (provider_id, reason, details)
  values ((select value::uuid from fx where key = 'a'), 'other', 'evidence');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select public.delete_listing((select value::uuid from fx where key = 'a'));
reset role;

select is(
  (select count(*)::int from public.reports where provider_id is null and details = 'evidence'
     and provider_snapshot->>'displayName' = 'Doomed Listing'),
  1, 'the report survives with provider_id null and a snapshot carrying displayName');
select is(
  (select count(*)::int from private.storage_cleanup_queue
   where prefix = (select value from fx where key = 'owner') || '/' and processed_at is null),
  2, 'two storage_cleanup_queue rows are queued (photos, credential evidence)');
select ok(
  exists (select 1 from private.audit_events
          where action = 'listing_deleted' and target_id = (select value from fx where key = 'a')
            and details->>'by_owner' = 'true'),
  'listing_deleted is audited');

-- Retention.
insert into public.reports (provider_id, reason, created_at)
  values (null, 'other', now() - interval '181 days');
insert into public.reports (provider_id, reason, reporter_phone_e164, reporter_source, created_at)
  values ((select value::uuid from fx where key = 'k'), 'other', '+919000001399', 'u:x', now() - interval '91 days');
select private.purge_expired_records();
select is(
  (select count(*)::int from public.reports where provider_id is null and created_at < now() - interval '180 days'),
  0, 'purge deletes orphaned reports older than 180 days');
select ok(
  (select reporter_phone_e164 is null and reporter_source is null from public.reports
   where provider_id = (select value::uuid from fx where key = 'k')),
  'purge clears reporter phone and source after 90 days');

select * from finish();
rollback;
