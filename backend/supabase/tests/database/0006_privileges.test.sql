-- Phases 023/024: closed-by-default privileges. Phone range +91900000060x.
begin;
select plan(10);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000000601')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000601', 'Privilege Listing')::text;

-- anon's executable surface in schema public is exactly the allowlist.
select set_eq(
  $$ select p.proname::text from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       and has_function_privilege('anon', p.oid, 'EXECUTE') $$,
  $$ values ('search_providers'), ('get_public_profile'), ('similar_providers'),
            ('provider_count_by_locality'), ('providers_published_in_city'),
            ('active_promotions'), ('flag_enabled'), ('get_client_flags'), ('search_cities'), ('search_categories'),
            ('submit_report'), ('record_engagement'), ('request_city'), ('is_admin'), ('get_trust_summary') $$,
  'anon can execute exactly the discovery allowlist, guest writes and is_admin'
);

-- Internal/owner-shaped helpers are not callable by anon (42501).
select tests.authenticate_as_anon();
select throws_ok(
  format($sql$ select public.provider_profile_json(%L::uuid) $sql$, (select value from fx where key = 'a')),
  '42501', null, 'anon cannot call provider_profile_json');
select throws_ok(
  format($sql$ select public.is_publicly_listed(%L::uuid) $sql$, (select value from fx where key = 'a')),
  '42501', null, 'anon cannot call is_publicly_listed');
select throws_ok(
  format($sql$ select public.public_profile_json(%L::uuid) $sql$, (select value from fx where key = 'a')),
  '42501', null, 'anon cannot call public_profile_json');
select throws_ok(
  $$ select 1 from private.audit_events $$,
  '42501', null, 'anon cannot use schema private');
reset role;

select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
     and p.prosecdef
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
     and not coalesce(p.proconfig @> array['search_path=""'], false)),
  0,
  'every SECURITY DEFINER function in public/private pins search_path to empty'
);

select ok(
  not has_schema_privilege('anon', 'public', 'CREATE')
  and not has_schema_privilege('authenticated', 'public', 'CREATE'),
  'anon and authenticated cannot create objects in schema public'
);

select is(
  (select n.nspname::text from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pg_trgm'),
  'extensions', 'pg_trgm lives in the extensions schema'
);

select is_empty(
  $$ select c.relname from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
       and (has_table_privilege('anon', c.oid, 'INSERT')
         or has_table_privilege('anon', c.oid, 'UPDATE')
         or has_table_privilege('anon', c.oid, 'DELETE')) $$,
  'anon has no write privilege on any public table'
);

select ok(
  not has_schema_privilege('anon', 'private', 'USAGE')
  and not has_schema_privilege('authenticated', 'private', 'USAGE'),
  'API roles have no USAGE on schema private'
);

select * from finish();
rollback;
