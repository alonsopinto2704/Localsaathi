-- Audit follow-up (migration 0050): remaining is_admin() surfaces are role-gated.
-- Phones +91900050xxxx.
begin;
select plan(18);
select tests.ensure_reference_data();

create function pg_temp.rows_changed(p_sql text) returns int language plpgsql as $$
declare n int;
begin execute p_sql; get diagnostics n = row_count; return n; end;
$$;
grant execute on function pg_temp.rows_changed(text) to authenticated;
create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('sup', tests.create_phone_user('+919000500001')::text),
  ('mod', tests.create_phone_user('+919000500002')::text),
  ('inf', tests.create_phone_user('+919000500003')::text),
  ('all', tests.create_admin('+919000500004')::text),
  ('owner', tests.create_phone_user('+919000500005')::text);
insert into public.app_admins (user_id) select value::uuid from fx where key in ('sup', 'mod', 'inf');
insert into private.admin_roles (user_id, role) values
  ((select value::uuid from fx where key = 'sup'), 'support'),
  ((select value::uuid from fx where key = 'mod'), 'moderation'),
  ((select value::uuid from fx where key = 'inf'), 'infrastructure');
insert into fx select 'p', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000500005', 'Role Gate Listing')::text;
insert into public.reports (provider_id, reason) values ((select value::uuid from fx where key = 'p'), 'other');
grant all on fx to authenticated;

-- set_listing_moderation: moderation role only.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'sup'));
select throws_like(
  format($sql$ select public.set_listing_moderation(%L::uuid, 'suspended', 'support must not do this') $sql$, (select value from fx where key = 'p')),
  'not_owner%', 'a support-only administrator cannot suspend a listing');
select throws_like($$ select public.admin_audit_events() $$, 'not_owner%', 'a support-only administrator cannot read the audit trail');
select is((select count(*)::int from public.city_requests), 0, 'support may read the city request queue (policy evaluates without error)');
select is((select count(*)::int from public.reports), 0, 'a support-only administrator sees no reports');
select is((select count(*)::int from public.engagement_events), 0, 'and no raw engagement events');
select throws_ok(
  format($sql$ insert into public.promotions (provider_id, placement, starts_at, ends_at) values (%L::uuid, 'home_featured', now(), now() + interval '1 day') $sql$, (select value from fx where key = 'p')),
  '42501', null, 'and cannot create a promotion');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select lives_ok(
  format($sql$ select public.set_listing_moderation(%L::uuid, 'suspended', 'moderation role test') $sql$, (select value from fx where key = 'p')),
  'the moderation role can suspend');
select is((select count(*)::int from public.reports), 1, 'and read the report queue');
select is(
  pg_temp.rows_changed($$ update public.reports set status = 'actioned' $$),
  1, 'and resolve a report');
select throws_like($$ select public.admin_audit_events() $$, 'not_owner%', 'but cannot read the audit trail');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'inf'));
select ok(jsonb_typeof(public.admin_audit_events()) = 'array', 'the infrastructure role reads the audit trail');
select lives_ok(
  format($sql$ insert into public.promotions (provider_id, placement, starts_at, ends_at) values (%L::uuid, 'home_featured', now(), now() + interval '1 day') $sql$, (select value from fx where key = 'p')),
  'and manages promotions');
select is(
  pg_temp.rows_changed($$ update public.reports set status = 'dismissed' $$),
  0, 'but cannot resolve reports');
select is((select count(*)::int from public.app_admins), 4, 'and lists the administrators');
reset role;

-- A support-only admin cannot even see the admin list.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'sup'));
select is((select count(*)::int from public.app_admins), 0, 'support cannot list administrators');
reset role;

-- Reference data: no direct-write policy remains, even if a grant were added later.
select is((select count(*)::int from pg_policies where policyname = 'only admins write reference data'), 0,
  'no direct-write policy remains on reference tables');
grant insert, update on public.cities, public.service_categories to authenticated;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'all'));
select throws_ok($$ insert into public.cities (id, state_id, name) values ('x-city', 'in-mh', 'X') $$,
  '42501', null, 'even an administrator with every role cannot write a city directly');
select is(
  pg_temp.rows_changed($$ update public.service_categories set is_approved_for_launch = not is_approved_for_launch $$),
  0, 'nor flip a category approval without the audited RPC');
reset role;

select * from finish();
rollback;
