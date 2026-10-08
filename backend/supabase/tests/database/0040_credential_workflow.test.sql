-- Phases 088/089 (migration 0040): private credential intake and the decision
-- workflow. Phones +91900040xxxx.
begin;
select plan(45);
select tests.ensure_reference_data();
select tests.set_flag('credential_intake', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000400001')::text),
  ('other', tests.create_phone_user('+919000400002')::text),
  ('rev', tests.create_admin('+919000400003')::text),      -- all four roles
  ('rev2', tests.create_admin('+919000400004')::text),
  ('sup', tests.create_phone_user('+919000400005')::text), -- support only
  ('selfadm', tests.create_admin('+919000400006')::text);  -- an admin who is also a provider
insert into public.app_admins (user_id) select value::uuid from fx where key = 'sup';
insert into private.admin_roles (user_id, role) values ((select value::uuid from fx where key = 'sup'), 'support');
insert into fx select 'a', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000400001', 'Credential Listing')::text;
insert into fx select 'b', tests.create_published_provider((select value::uuid from fx where key = 'other'), '+919000400002', 'Other Listing')::text;
insert into fx select 'self', tests.create_published_provider((select value::uuid from fx where key = 'selfadm'), '+919000400006', 'Self Reviewer Listing')::text;
grant all on fx to authenticated;

-- ---------------------------------------------------------------- intake
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ insert into public.credential_records (provider_id, title, evidence_storage_path) values (%L, 'Council registration', %L) $sql$,
         (select value from fx where key = 'a'), (select value from fx where key = 'owner') || '/reg.pdf'),
  'consent_required%', 'an upload without accepting the evidence notice is refused');
select throws_ok(
  format($sql$ insert into public.credential_records (provider_id, title, review_state) values (%L, 'x', 'approved') $sql$,
         (select value from fx where key = 'a')),
  '42501', null, 'a provider cannot choose a review state');
with ins as (
  insert into public.credential_records (provider_id, title, issuing_body, registration_number, evidence_storage_path, notice_version)
  values ((select value::uuid from fx where key = 'a'), 'Council registration', 'State Council', 'REG-1234',
          (select value from fx where key = 'owner') || '/reg.pdf', 'credential-notice-v1')
  returning id)
insert into fx select 'cred', id::text from ins;
select is(
  (select review_state || '/' || evidence_bucket || '/' || (notice_acknowledged_at is not null)::text
   from public.credential_records where id = (select value::uuid from fx where key = 'cred')),
  'submitted/credentials-private/true', 'an accepted notice lets the upload in; it starts as submitted in the private bucket');
select throws_ok(
  format($sql$ update public.credential_records set review_state = 'approved', status = 'approved' where id = %L $sql$, (select value from fx where key = 'cred')),
  '42501', null, 'a provider cannot approve their own credential');
select is((select count(*)::int from public.credential_records), 1, 'the owner sees their credential');
select throws_like($$ select public.list_credential_queue() $$, 'not_owner%', 'a provider cannot read the reviewer queue');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select is((select count(*)::int from public.credential_records), 0, 'another provider cannot read it');
select throws_like(format($sql$ select public.get_credential_status(%L) $sql$, (select value from fx where key = 'a')),
  'not_owner%', 'nor its status');
select throws_like(
  format($sql$ select public.begin_credential_evidence_view(%L, 'curious') $sql$, (select value from fx where key = 'cred')),
  'not_owner%', 'nor open its evidence');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select public.list_credential_queue() $$, '42501', null, 'a guest cannot call the reviewer functions');
select throws_ok($$ select count(*) from public.credential_records $$, '42501', null, 'a guest cannot read credential rows');
reset role;

-- Bytes: the old bucket no longer lets any administrator read evidence.
insert into storage.objects (bucket_id, name) values ('credential-evidence', (select value from fx where key = 'owner') || '/old.pdf');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select is((select count(*)::int from storage.objects where bucket_id = 'credential-evidence'), 0,
  'even a credential reviewer cannot read evidence straight from storage');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is((select count(*)::int from storage.objects where bucket_id = 'credential-evidence'), 1, 'the owner still can');
reset role;

-- ------------------------------------------------- who may review at all
select tests.authenticate_as_admin((select value::uuid from fx where key = 'sup'));
select throws_like($$ select public.list_credential_queue() $$, 'not_owner%', 'the support role has no credential access');
select is((select count(*)::int from public.credential_records), 0, 'and cannot read credential rows');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select is(jsonb_array_length(public.list_credential_queue()), 1, 'a credential reviewer sees the queue');
select throws_like(
  format($sql$ select public.begin_credential_evidence_view(%L, 'checking the register') $sql$, (select value from fx where key = 'cred')),
  'not_owner%claim%', 'evidence cannot be opened before the case is claimed');
select throws_like(
  format($sql$ select public.decide_credential(%L, 'approved', 'looks fine to me', 'document', 'doc-1', current_date + 100) $sql$, (select value from fx where key = 'cred')),
  'conflict%', 'an unclaimed case cannot be decided');
select lives_ok(format($sql$ select public.start_credential_review(%L) $sql$, (select value from fx where key = 'cred')), 'a reviewer claims the case');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev2'));
select throws_like(format($sql$ select public.start_credential_review(%L) $sql$, (select value from fx where key = 'cred')),
  'conflict%', 'a second reviewer cannot take a claimed case');
select throws_like(
  format($sql$ select public.begin_credential_evidence_view(%L, 'also curious') $sql$, (select value from fx where key = 'cred')),
  'not_owner%', 'nor open its evidence');
reset role;

-- A provider who is also a reviewer cannot touch their own case.
select tests.authenticate_as((select value::uuid from fx where key = 'selfadm'));
with ins as (insert into public.credential_records (provider_id, title) values ((select value::uuid from fx where key = 'self'), 'My own claim') returning id)
insert into fx select 'selfcred', id::text from ins;
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'selfadm'));
select throws_like(format($sql$ select public.start_credential_review(%L) $sql$, (select value from fx where key = 'selfcred')),
  'not_owner%own credential%', 'a provider cannot review (so cannot approve) their own credential');
select is(jsonb_array_length(public.list_credential_queue()), 0, 'their own case is never in their queue');
reset role;

-- ------------------------------------------------------ evidence access
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'), 1800);
select throws_like(
  format($sql$ select public.begin_credential_evidence_view(%L, 'stale session') $sql$, (select value from fx where key = 'cred')),
  'reauth_required%', 'a stale MFA session cannot open evidence');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select is(
  public.begin_credential_evidence_view((select value::uuid from fx where key = 'cred'), 'checking the register')->>'bucket',
  'credentials-private', 'a claimed case on a fresh MFA session returns the private bucket and path');
reset role;
select is((select count(*)::int from private.credential_access_log) || '/' ||
          (select count(*)::int from private.audit_events where action = 'credential_evidence_viewed'),
  '1/1', 'every view is logged and audited');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));

-- ------------------------------------------------------------- decisions
select throws_like(
  format($sql$ select public.decide_credential(%L, 'approved', 'matches the register entry', 'registry', null, current_date + 100) $sql$, (select value from fx where key = 'cred')),
  'validation_failed%source%', 'an approval needs a source reference');
select throws_like(
  format($sql$ select public.decide_credential(%L, 'approved', 'matches the register entry', 'registry', 'REG-1234', current_date + 2000) $sql$, (select value from fx where key = 'cred')),
  'validation_failed%3 years%', 'and a validity of at most 3 years');
select throws_like(
  format($sql$ select public.decide_credential(%L, 'rejected', 'short') $sql$, (select value from fx where key = 'cred')),
  'validation_failed%rationale%', 'and every decision needs a real rationale');
select throws_like(
  format($sql$ select public.record_credential_review(%L, %L, 'approved', 'quick') $sql$, (select value from fx where key = 'a'), (select value from fx where key = 'cred')),
  'validation_failed%decide_credential%', 'the old one-step approval is gone');
reset role;

-- A moderator cannot decide credentials.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'sup'));
select throws_like(
  format($sql$ select public.decide_credential(%L, 'approved', 'matches the register entry', 'registry', 'REG-1234', current_date + 100) $sql$, (select value from fx where key = 'cred')),
  'not_owner%', 'only the credential_review role can decide');
reset role;

-- needs_information round trip.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select lives_ok(
  format($sql$ select public.decide_credential(%L, 'needs_information', 'registration number is not legible', null, null, null, 'Please upload a clearer photo of the certificate') $sql$, (select value from fx where key = 'cred')),
  'a reviewer can ask for more information');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(public.get_credential_status((select value::uuid from fx where key = 'a'))->0->>'state', 'needs_information',
  'the provider sees the state and the request');
select is(public.resubmit_credential((select value::uuid from fx where key = 'cred'))->>'state', 'submitted', 'and can send it back');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select public.start_credential_review((select value::uuid from fx where key = 'cred'));
select is(public.decide_credential((select value::uuid from fx where key = 'cred'), 'approved', 'matches the register entry on the council site',
  'registry', 'council register, entry REG-1234', current_date + 365)->>'state', 'approved', 'an approval with source, rationale and validity is recorded');
reset role;

select is(
  (select reviewer_id::text || '/' || source_type || '/' || (valid_until > valid_from)::text from private.credential_decisions where decision = 'approved'),
  (select value from fx where key = 'rev') || '/registry/true', 'the decision is attributable to the reviewer, with source and validity');

-- ------------------------------------------------ what the public sees
select tests.authenticate_as_anon();
select is(public.get_public_profile((select value::uuid from fx where key = 'a'))->'verification'->>'credentials', 'approved',
  'the approved credential is public');
select is(public.get_trust_summary((select value::uuid from fx where key = 'a'))::text like '%council register%', false,
  'but the source reference and reviewer never are');
reset role;

-- Withdrawal removes it at once and re-queues the case.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'rev'));
select public.withdraw_credential_decision((select value::uuid from fx where key = 'cred'), 'provider disputed the registry match');
reset role;
select tests.authenticate_as_anon();
select is(public.get_public_profile((select value::uuid from fx where key = 'a'))->'verification' ? 'credentials', false,
  'a withdrawn credential disappears from the public profile');
reset role;

-- Expiry: the badge goes by date even before the job runs.
update private.credential_decisions set withdrawn_at = null, withdrawn_by = null, withdraw_reason = null;
update public.credential_records set review_state = 'approved' where id = (select value::uuid from fx where key = 'cred');
update private.credential_decisions set valid_from = current_date - 20, valid_until = current_date - 1;
select tests.authenticate_as_anon();
select is(public.get_public_profile((select value::uuid from fx where key = 'a'))->'verification' ? 'credentials', false,
  'an expired credential has no badge even before the expiry job runs');
reset role;
set local role service_role;
select is(public.expire_credential_decisions(), 1, 'the expiry job moves it to expired');
reset role;

-- Retention: stale rejected/expired evidence is queued for deletion.
update public.credential_records set reviewed_at = now() - interval '91 days';
set local role service_role;
select is(public.purge_stale_credential_evidence(), 1, 'old expired evidence is purged');
reset role;
select is((select bucket_id from private.storage_cleanup_queue where prefix like '%/reg.pdf' and processed_at is null), 'credentials-private',
  'the purged file is queued for deletion in the private bucket');
-- Deleting a credential queues its own object too.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
with i as (insert into public.credential_records (provider_id, title, evidence_storage_path, notice_version)
  values ((select value::uuid from fx where key = 'a'), 'Second', (select value from fx where key = 'owner') || '/two.pdf', 'credential-notice-v1') returning id)
insert into fx select 'two', id::text from i;
delete from public.credential_records where id = (select value::uuid from fx where key = 'two');
reset role;
select is((select bucket_id from private.storage_cleanup_queue where prefix like '%/two.pdf'), 'credentials-private',
  'deleting a credential queues its evidence object');
select throws_like(
  format($sql$ select public.begin_credential_evidence_view(%L, 'after delete') $sql$, gen_random_uuid()),
  'not_owner%', 'evidence functions refuse non-reviewers even for unknown ids');
select * from finish();
rollback;
