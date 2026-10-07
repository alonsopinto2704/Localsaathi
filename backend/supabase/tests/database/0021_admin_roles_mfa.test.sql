-- Phase 054/055 (migration 0027): administrator MFA and separate roles. Phones +91900021xxxx.
begin;
select plan(17);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('full', tests.create_admin('+919000210001')::text),       -- all four roles
  ('plain', tests.create_phone_user('+919000210002')::text),
  ('legacy', tests.create_phone_user('+919000210003')::text),
  ('meta', tests.create_phone_user('+919000210004')::text),
  ('mod', tests.create_phone_user('+919000210005')::text),
  ('sup', tests.create_phone_user('+919000210006')::text);
insert into public.app_admins (user_id) select value::uuid from fx where key in ('legacy', 'mod', 'sup');
insert into private.admin_roles (user_id, role) values
  ((select value::uuid from fx where key = 'mod'), 'moderation'),
  ((select value::uuid from fx where key = 'sup'), 'support');
update auth.users set raw_app_meta_data = '{"role":"admin","roles":["moderation"]}',
  raw_user_meta_data = '{"is_admin":true,"role":"admin"}' where id = (select value::uuid from fx where key = 'meta');
insert into fx select 'p', tests.create_published_provider((select value::uuid from fx where key = 'plain'), '+919000210002', 'Admin Test Listing')::text;
grant all on fx to authenticated;

-- Strength of the session.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'full'));
select lives_ok($$ select public.set_feature_flag('media_intake', true, 'role test') $$,
  'an MFA session with a recent TOTP proof and the infrastructure role may change a flag');
reset role;

select tests.authenticate_with_amr((select value::uuid from fx where key = 'full'), 30, 'aal1', 'otp');
select throws_like($$ select public.set_feature_flag('media_intake', false, 'no mfa') $$, 'reauth_required%',
  'the same person without MFA (aal1) is refused');
select is(public.is_admin(), false, 'and is not treated as an administrator by RLS or helper functions');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'full'), 1800);
select throws_like($$ select public.set_feature_flag('media_intake', false, 'stale') $$, 'reauth_required%',
  'a stale privileged session (TOTP proof 30 min old) cannot perform a sensitive admin action');
select is(public.is_admin(), true, 'but it still counts as an MFA administrator for non-sensitive reads');
reset role;

-- Roles are separate.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select throws_like($$ select public.set_feature_flag('media_intake', false, 'wrong role') $$, 'not_owner%',
  'the moderation role cannot change feature flags');
select throws_like(
  format($sql$ select public.record_credential_review(%L::uuid, gen_random_uuid(), 'approved', 'x') $sql$, (select value from fx where key = 'p')),
  'not_owner%', 'the moderation role cannot review credentials');
reset role;

select set_config('request.jwt.claims', json_build_object('sub', (select value from fx where key = 'sup'), 'role', 'authenticated', 'aal', 'aal2')::text, true);
select throws_like(
  format($sql$ update public.provider_profiles set moderation_status = 'suspended', suspension_reason = 'x' where id = %L $sql$, (select value from fx where key = 'p')),
  'not_owner%', 'the support role cannot change moderation status');
select set_config('request.jwt.claims', json_build_object('sub', (select value from fx where key = 'mod'), 'role', 'authenticated', 'aal', 'aal2')::text, true);
select lives_ok(
  format($sql$ update public.provider_profiles set moderation_status = 'suspended', suspension_reason = 'role test' where id = %L $sql$, (select value from fx where key = 'p')),
  'the moderation role can');
select set_config('request.jwt.claims', '', true);

-- Privilege cannot be conferred by data the user controls.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'legacy'));
select is(public.is_admin(), false, 'an app_admins row with no role grants nothing');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', (select value from fx where key = 'meta'), 'role', 'authenticated', 'aal', 'aal2',
  'user_metadata', json_build_object('is_admin', true), 'app_metadata', json_build_object('role', 'admin', 'roles', json_build_array('infrastructure')))::text, true);
select set_config('role', 'authenticated', true);
select is(public.is_admin(), false, 'user/app metadata and claims saying "admin" confer nothing');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'plain'));
select throws_ok($$ insert into public.app_admins (user_id) values (gen_random_uuid()) $$, '42501', null,
  'an ordinary account cannot add administrators');
select throws_ok($$ insert into private.admin_roles (user_id, role) values (gen_random_uuid(), 'support') $$, '42501', null,
  'nor roles');
reset role;
select tests.authenticate_as_anon();
select is(public.is_admin(), false, 'anon is not an administrator');
reset role;

-- Audit of role changes.
select is((select count(*)::int from private.audit_events
           where action = 'admin_role_granted' and target_id = (select value from fx where key = 'full')), 4,
  'each granted role is audited');
delete from private.admin_roles where user_id = (select value::uuid from fx where key = 'full') and role = 'infrastructure';
select is((select count(*)::int from private.audit_events
           where action = 'admin_role_revoked' and target_id = (select value from fx where key = 'full')), 1,
  'a revocation is audited and takes effect immediately');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'full'));
select throws_like($$ select public.set_feature_flag('media_intake', false, 'revoked') $$, 'not_owner%',
  'a revoked role cannot be used with an otherwise valid MFA session');
reset role;

select * from finish();
rollback;
