-- 0050: audit follow-up (phase 054). 0027 introduced separate administrator
-- roles but applied them to only a few functions; every other privileged
-- surface still answered to bare is_admin() (any role, aal2). Inventory of
-- every is_admin() use and the decision for each is in
-- tasks/evidence/audit-fixes-2026-10-08.md.
--
-- Changed here:
--   * set_listing_moderation            -> moderation role
--   * admin_audit_events                -> infrastructure role
--   * reports read/resolve (RLS)        -> moderation role
--   * promotions, promotion_interest admin branch, raw engagement events,
--     the admin list (RLS)              -> infrastructure role
--   * city_requests admin read (RLS)    -> support role
--   * reference-data "for all" policies -> dropped. Reference data changes only
--     through the audited, role-gated RPCs (set_city_launch_status,
--     set_category_launch_approval); a direct table write has no policy.

-- RLS policies call has_admin_role() while evaluating a signed-in query
-- (same reason is_admin() is executable by them); it only answers about the caller.
grant execute on function public.has_admin_role(text) to authenticated;

drop policy "only admins write reference data" on public.countries;
drop policy "only admins write reference data" on public.state_regions;
drop policy "only admins write reference data" on public.cities;
drop policy "only admins write reference data" on public.localities;
drop policy "only admins write reference data" on public.service_groups;
drop policy "only admins write reference data" on public.service_categories;
drop policy "only admins write reference data" on public.subscription_plans;

drop policy "only admins read the report queue" on public.reports;
drop policy "only admins resolve reports" on public.reports;
create policy "moderators read the report queue" on public.reports for select
  using (public.has_admin_role('moderation'));
create policy "moderators resolve reports" on public.reports for update
  using (public.has_admin_role('moderation')) with check (public.has_admin_role('moderation'));

drop policy "only admins read raw engagement events" on public.engagement_events;
create policy "infrastructure admins read raw engagement events" on public.engagement_events for select
  using (public.has_admin_role('infrastructure'));

drop policy "only admins manage promotions" on public.promotions;
create policy "infrastructure admins manage promotions" on public.promotions for all
  using (public.has_admin_role('infrastructure')) with check (public.has_admin_role('infrastructure'));

drop policy "owner manages own promotion interest" on public.promotion_interest;
create policy "owner manages own promotion interest" on public.promotion_interest for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid())
  or public.has_admin_role('infrastructure')
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid())
  or public.has_admin_role('infrastructure')
);

drop policy "admins read the admin list" on public.app_admins;
create policy "infrastructure admins read the admin list" on public.app_admins for select
  using (public.has_admin_role('infrastructure'));

drop policy "requester or admin may read city requests" on public.city_requests;
create policy "requester or support may read city requests" on public.city_requests for select using (
  public.has_admin_role('support')
  or (auth.uid() is not null and submitted_by_phone = (select phone_e164 from public.provider_profiles where user_id = auth.uid()))
);

-- Bodies as in 0014 with only the authorisation line changed. Not-recent: the
-- action is audited and reversible; the sensitive-recent tier stays with 0027.
create or replace function public.set_listing_moderation(
  p_provider_id uuid, p_status public.moderation_status, p_reason text default null
)
returns public.provider_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
  v_old public.moderation_status;
begin
  perform private.require_admin_role('moderation', false);
  if p_status = 'suspended' and coalesce(btrim(p_reason), '') = '' then
    raise exception 'validation_failed: a suspension needs a reason';
  end if;
  select moderation_status into v_old from public.provider_profiles where id = p_provider_id for update;
  if not found then
    raise exception 'not_found: profile not found';
  end if;
  update public.provider_profiles
    set moderation_status = p_status, suspension_reason = case when p_status = 'suspended' then p_reason end
    where id = p_provider_id
    returning * into v_row;
  perform private.write_audit('listing_moderation_set', 'provider_profile', p_provider_id::text, p_reason,
    jsonb_build_object('from', v_old, 'to', p_status));
  return v_row;
end;
$$;

create or replace function public.admin_audit_events(p_limit int default 100, p_before_id bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin_role('infrastructure', false);
  return coalesce((
    select jsonb_agg(to_jsonb(e) order by e.id desc)
    from (
      select * from private.audit_events
      where p_before_id is null or id < p_before_id
      order by id desc
      limit least(greatest(coalesce(p_limit, 100), 1), 500)
    ) e
  ), '[]'::jsonb);
end;
$$;
