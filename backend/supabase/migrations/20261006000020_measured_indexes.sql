-- Phase 038: the one index the benchmark justified.
--
-- search_providers ranks every match by photo count, and public_profile_json
-- aggregates photos per listing; provider_photos had no index on provider_id
-- (its PK is the photo id), so each lookup scanned the whole table. Measured in
-- tasks/evidence/phase-038.md: at 50k synthetic providers, locality-only search
-- p95 65 s -> under 0.5 s with this index; write cost is one btree entry per
-- photo (about 2.2 MB at 125k photos).
create index if not exists idx_provider_photos_provider on public.provider_photos (provider_id);

-- Phase 038 (second finding): provider_count_by_locality and
-- providers_published_in_city called is_publicly_listed() once per row --
-- ~1.2 s each at 50k listings. The rule now lives once, as a view the planner
-- can join set-based; is_publicly_listed() and every list path read it, so
-- there is still exactly one definition of "publicly listed".
create view private.listed_providers as
  select pp.id, pp.base_city_id
  from public.provider_profiles pp
  join public.cities c on c.id = pp.base_city_id and c.launch_status = 'active'
  where pp.status = 'published'
    and pp.moderation_status = 'active'
    and pp.phone_display_consented
    and exists (
      select 1 from public.provider_categories pc
      join public.service_categories sc on sc.id = pc.category_id
      where pc.provider_id = pp.id and sc.is_approved_for_launch)
    and exists (select 1 from public.provider_service_areas sa where sa.provider_id = pp.id);
revoke all on private.listed_providers from public, anon, authenticated;

create or replace function public.is_publicly_listed(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from private.listed_providers l where l.id = p_id);
$$;

create or replace function public.provider_count_by_locality(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(x.locality_id, x.cnt), '{}'::jsonb)
  from (
    -- (provider_id, locality_id) is the PK, so count(*) counts providers.
    select sa.locality_id, count(*) as cnt
    from private.listed_providers l
    join public.provider_service_areas sa on sa.provider_id = l.id
    where l.base_city_id = p_city_id
    group by sa.locality_id
  ) x;
$$;

create or replace function public.providers_published_in_city(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with picked as (
    select pp.id, pp.display_name
    from private.listed_providers l
    join public.provider_profiles pp on pp.id = l.id
    where l.base_city_id = p_city_id
    order by pp.display_name, pp.id
    limit 500
  )
  select coalesce(jsonb_agg(public.public_profile_json(id) order by display_name, id), '[]'::jsonb) from picked;
$$;
