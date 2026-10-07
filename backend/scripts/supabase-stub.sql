-- The parts of a Supabase project that our migrations and tests depend on,
-- for the PGlite harness only (scripts/verify-db.mjs). Never apply this to a
-- real Supabase project, which already has all of it.
--
-- Modelled on supabase/postgres init scripts, GoTrue's auth.users schema and
-- storage-api's storage schema. Only what this repo uses is included.
-- Known difference: the session user here is a superuser. In hosted Supabase
-- `postgres` is not, but it owns everything the migrations create.

-- API roles, the GoTrue and Storage service roles.
create role anon nologin noinherit;
create role authenticated nologin noinherit;
create role service_role nologin noinherit bypassrls;
create role authenticator login noinherit;
grant anon, authenticated, service_role to authenticator;
create role supabase_auth_admin login noinherit createrole;
create role supabase_storage_admin login noinherit createrole;

-- Supabase pre-installs these in `extensions`, which is on postgres's
-- search_path ("$user", public, extensions).
create schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;
create extension pgcrypto with schema extensions;

-- Every table/function/sequence `postgres` creates in public is granted to
-- the API roles. RLS, not grants, is the boundary in Supabase.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- auth -------------------------------------------------------------------
create schema auth authorization supabase_auth_admin;
grant usage on schema auth to anon, authenticated, service_role;

-- GoTrue's users table. GoTrue stores `phone` WITHOUT the leading '+'
-- (internal/api/phone.go formatPhoneNumber), e.g. '919876543210'.
create table auth.users (
  instance_id uuid,
  id uuid not null primary key,
  aud varchar(255),
  role varchar(255),
  email varchar(255),
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  invited_at timestamptz,
  confirmation_token varchar(255),
  confirmation_sent_at timestamptz,
  recovery_token varchar(255),
  recovery_sent_at timestamptz,
  email_change_token_new varchar(255),
  email_change varchar(255),
  email_change_sent_at timestamptz,
  last_sign_in_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  is_super_admin boolean,
  created_at timestamptz,
  updated_at timestamptz,
  phone text unique default null,
  phone_confirmed_at timestamptz,
  phone_change text default '',
  phone_change_token varchar(255) default '',
  phone_change_sent_at timestamptz,
  confirmed_at timestamptz generated always as (least(email_confirmed_at, phone_confirmed_at)) stored,
  email_change_token_current varchar(255) default '',
  email_change_confirm_status smallint default 0 check (email_change_confirm_status between 0 and 2),
  banned_until timestamptz,
  reauthentication_token varchar(255) default '',
  reauthentication_sent_at timestamptz,
  is_sso_user boolean not null default false,
  deleted_at timestamptz,
  is_anonymous boolean not null default false
);
alter table auth.users owner to supabase_auth_admin;
-- No grant to anon/authenticated: they cannot read auth.users.

-- Same definitions Supabase ships: PostgREST sets request.jwt.claims (and
-- older versions request.jwt.claim.*) from the verified JWT of each request.
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
create function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;
alter function auth.uid() owner to supabase_auth_admin;
alter function auth.role() owner to supabase_auth_admin;
alter function auth.jwt() owner to supabase_auth_admin;

-- storage ----------------------------------------------------------------
create schema storage authorization supabase_storage_admin;
grant usage on schema storage to anon, authenticated, service_role;

create table storage.buckets (
  id text not null primary key,
  name text not null,
  owner uuid,
  owner_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  public boolean default false,
  avif_autodetection boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create unique index bname on storage.buckets (name);

create table storage.objects (
  id uuid not null default gen_random_uuid() primary key,
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid,
  owner_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_accessed_at timestamptz default now(),
  metadata jsonb,
  path_tokens text[] generated always as (string_to_array(name, '/')) stored,
  version text,
  user_metadata jsonb
);
create unique index bucketid_objname on storage.objects (bucket_id, name);

alter table storage.buckets enable row level security;
alter table storage.objects enable row level security;
alter table storage.buckets owner to supabase_storage_admin;
alter table storage.objects owner to supabase_storage_admin;
-- The Storage API runs each request as the caller's role, under RLS.
grant all on storage.buckets, storage.objects to anon, authenticated, service_role;

-- storage-api's definition: every path segment except the file name.
create function storage.foldername(name text) returns text[] language plpgsql as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end
$$;
alter function storage.foldername(text) owner to supabase_storage_admin;
