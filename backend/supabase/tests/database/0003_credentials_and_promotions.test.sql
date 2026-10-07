begin;
select plan(4);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000000021')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000021', 'Credentialed Provider'
)::text;

select tests.set_flag('credential_intake', true);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));

-- A provider claiming a credential cannot even send a status: since 0013
-- the column-level INSERT grant omits status/reviewed_*.
select throws_ok(
  format($sql$ insert into public.credential_records (provider_id, title, status) values (%L, 'MBBS', 'approved') $sql$,
         (select value from fx where key = 'a')),
  '42501', null,
  'a provider cannot submit a credential with a self-chosen status'
);

-- A plain claim is stored as pending (force_pending_credential_status is the
-- second line of defence).
with ins as (
  insert into public.credential_records (provider_id, title)
  values ((select value::uuid from fx where key = 'a'), 'MBBS')
  returning id
)
insert into fx select 'cred', id::text from ins;

select is(
  (select status::text from public.credential_records where id = (select value::uuid from fx where key = 'cred')),
  'pending',
  'a claimed credential is stored as pending'
);

-- Nor can the provider flip it to approved afterwards: no UPDATE grant.
select throws_ok(
  format($sql$ update public.credential_records set status = 'approved' where id = %L $sql$,
         (select value from fx where key = 'cred')),
  '42501', null,
  'a provider cannot later update their own credential to approved'
);

-- A provider cannot grant themselves a paid placement: promotions has no
-- insert policy for a non-admin at all.
select throws_like(
  format(
    $sql$ insert into public.promotions (provider_id, placement, starts_at, ends_at, priority)
          values (%L, 'search_top', now(), now() + interval '30 days', 999) $sql$,
    (select value::uuid from fx where key = 'a')
  ),
  '%new row violates row-level security policy%',
  'a provider cannot create their own sponsored placement'
);

reset role;
select * from finish();
rollback;
