-- Row Level Security: the actual enforcement layer behind every requirement
-- in section 4 ("Access control") of the backend brief. Hiding a button in
-- the Flutter UI is not access control; these policies are what makes the
-- rule true even against a client that was modified or replaced.
--
-- Function EXECUTE grants: Postgres checks EXECUTE privilege against the
-- role that is nominally running at the time of the call. A SECURITY
-- DEFINER function (get_public_profile, search_providers, register_profile's
-- few invoker-mode nested calls, trigger functions that are *not* marked
-- SECURITY DEFINER) still needs its callee functions to be executable by
-- whichever role is actually running the statement, so the simplest correct
-- rule is: every function in this schema is safe to execute by anyone --
-- the functions themselves are what perform the authorization checks -- so
-- grant EXECUTE broadly rather than trying to enumerate call graphs.
grant usage on schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reference data: public read, admin write.
alter table public.countries enable row level security;
alter table public.state_regions enable row level security;
alter table public.cities enable row level security;
alter table public.localities enable row level security;
alter table public.service_groups enable row level security;
alter table public.service_categories enable row level security;
alter table public.subscription_plans enable row level security;

grant select on public.countries, public.state_regions, public.cities, public.localities,
  public.service_groups, public.service_categories, public.subscription_plans to anon, authenticated;
grant insert, update, delete on public.countries, public.state_regions, public.cities, public.localities,
  public.service_groups, public.service_categories, public.subscription_plans to authenticated;

create policy "reference data is publicly readable" on public.countries for select using (true);
create policy "reference data is publicly readable" on public.state_regions for select using (true);
create policy "reference data is publicly readable" on public.cities for select using (true);
create policy "reference data is publicly readable" on public.localities for select using (true);
create policy "reference data is publicly readable" on public.service_groups for select using (true);
create policy "reference data is publicly readable" on public.service_categories for select using (true);
create policy "reference data is publicly readable" on public.subscription_plans for select using (true);

create policy "only admins write reference data" on public.countries for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.state_regions for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.cities for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.localities for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.service_groups for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.service_categories for all using (public.is_admin()) with check (public.is_admin());
create policy "only admins write reference data" on public.subscription_plans for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- City requests: anyone may ask; only the requester (when signed in and the
-- phone matches) or an admin may read the queue.
alter table public.city_requests enable row level security;
grant select, insert on public.city_requests to anon, authenticated;

create policy "anyone may request a city" on public.city_requests for insert with check (true);
create policy "requester or admin may read city requests" on public.city_requests for select using (
  public.is_admin()
  or (auth.uid() is not null and submitted_by_phone = (select phone_e164 from public.provider_profiles where user_id = auth.uid()))
);

-- ---------------------------------------------------------------------------
-- provider_profiles: public sees published+active rows only; owner sees and
-- edits their own row (moderation fields excepted -- see
-- enforce_profile_mutation_rules() in 0008_functions.sql); admin sees/edits
-- all. Direct SELECT of this table never exposes suspension_reason or
-- moderation_status to anyone but the affected owner and admins, because the
-- "public" policy branch only matches rows that are already published+active.
alter table public.provider_profiles enable row level security;
grant select, insert, update, delete on public.provider_profiles to authenticated;
grant select on public.provider_profiles to anon;

create policy "published and active listings are public" on public.provider_profiles for select using (
  status = 'published' and moderation_status = 'active'
);
create policy "owner reads own profile" on public.provider_profiles for select using (
  auth.uid() = user_id or public.is_admin()
);
create policy "owner creates own profile" on public.provider_profiles for insert with check (
  auth.uid() = user_id
);
create policy "owner updates own profile" on public.provider_profiles for update using (
  auth.uid() = user_id or public.is_admin()
) with check (
  auth.uid() = user_id or public.is_admin()
);
create policy "owner deletes own profile" on public.provider_profiles for delete using (
  auth.uid() = user_id or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Provider detail tables: owner (+ admin) only via direct table access.
-- Public discovery never reads these tables directly -- it goes through
-- get_public_profile()/search_providers(), which are SECURITY DEFINER and
-- therefore unaffected by these (deliberately narrow) policies.
alter table public.provider_categories enable row level security;
alter table public.provider_service_areas enable row level security;
alter table public.provider_working_hours enable row level security;
alter table public.provider_photos enable row level security;
alter table public.provider_starting_prices enable row level security;
alter table public.provider_healthcare_details enable row level security;

grant select, insert, update, delete on public.provider_categories, public.provider_service_areas,
  public.provider_working_hours, public.provider_photos, public.provider_starting_prices,
  public.provider_healthcare_details to authenticated;

create policy "owner manages own categories" on public.provider_categories for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);
create policy "owner manages own service areas" on public.provider_service_areas for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);
create policy "owner manages own working hours" on public.provider_working_hours for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);
create policy "owner manages own photos" on public.provider_photos for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);
create policy "owner manages own starting prices" on public.provider_starting_prices for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);
create policy "owner manages own healthcare details" on public.provider_healthcare_details for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and (pp.user_id = auth.uid() or public.is_admin()))
);

-- ---------------------------------------------------------------------------
-- Consent records: append-only audit trail. Owner may add rows (including
-- withdrawal rows with granted = false); nobody may UPDATE or DELETE history,
-- not even the owner. Admins read everything for audit purposes.
alter table public.consent_records enable row level security;
grant select, insert on public.consent_records to authenticated;

create policy "owner reads own consent history" on public.consent_records for select using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);
create policy "owner appends own consent record" on public.consent_records for insert with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Verification records: read-only to everyone except the system. No INSERT/
-- UPDATE policy is granted to `authenticated` at all -- the only writers are
-- handle_auth_phone_change() (kind = 'phone', on a real OTP confirmation) and
-- record_credential_review() (kind = 'credentials', admin-only), both
-- SECURITY DEFINER and therefore unaffected by the absence of a policy here.
-- This is the server-side half of "a provider cannot self-verify".
alter table public.verification_records enable row level security;
grant select on public.verification_records to authenticated;

create policy "owner reads own verification records" on public.verification_records for select using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Credential records: owner may claim (insert, forced to 'pending' by the
-- trigger in 0005) and read their own; only record_credential_review() (also
-- SECURITY DEFINER) may move status to approved/rejected, so there is no
-- UPDATE policy for `authenticated` here either.
alter table public.credential_records enable row level security;
grant select, insert, delete on public.credential_records to authenticated;

create policy "owner reads own credentials" on public.credential_records for select using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);
create policy "owner claims own credential" on public.credential_records for insert with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid())
);
create policy "owner removes own claimed credential" on public.credential_records for delete using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Reports: anyone may file one (customers are guests by design -- see
-- docs/backend-contract.md for why "already reported" is tracked on-device
-- rather than server-side). Only admins may read the queue; there is no
-- UPDATE policy for non-admins, so a report can never be edited once filed.
alter table public.reports enable row level security;
grant select, insert on public.reports to anon, authenticated;
grant update on public.reports to authenticated;

create policy "anyone may file a report" on public.reports for insert with check (true);
create policy "only admins read the report queue" on public.reports for select using (public.is_admin());
create policy "only admins resolve reports" on public.reports for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Engagement events: write-only for everyone (including guests); not
-- directly selectable by anyone except admins -- owners read their numbers
-- through engagement_summary_for(), which is SECURITY DEFINER.
alter table public.engagement_events enable row level security;
grant select, insert on public.engagement_events to anon, authenticated;

create policy "anyone may record an engagement event" on public.engagement_events for insert with check (true);
create policy "only admins read raw engagement events" on public.engagement_events for select using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Promotions: admin-only, full stop. "Do not let providers set their own
-- paid entitlements" is this table having no policy branch for a provider at
-- all; public customers read active matches only through active_promotions(),
-- which is SECURITY DEFINER and returns a curated shape.
alter table public.promotions enable row level security;
grant select, insert, update, delete on public.promotions to authenticated;

create policy "only admins manage promotions" on public.promotions for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Promotion interest: a provider may record/withdraw interest in their own
-- name only, never activate anything.
alter table public.promotion_interest enable row level security;
grant select, insert, update, delete on public.promotion_interest to authenticated;

create policy "owner manages own promotion interest" on public.promotion_interest for all using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
) with check (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid()) or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Admin allowlist: readable by admins (so an admin tool can list other
-- admins); writable by nobody through the API -- grant admin by inserting a
-- row from the Supabase SQL editor/service role, not from the app.
alter table public.app_admins enable row level security;
grant select on public.app_admins to authenticated;
create policy "admins read the admin list" on public.app_admins for select using (public.is_admin());
