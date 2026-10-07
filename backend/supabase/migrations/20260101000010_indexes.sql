-- Indexes supporting search() and the other read paths at Mumbai-launch
-- scale. Added after the tables/policies so `create index` never blocks on a
-- lock held by DDL earlier in the same migration run.

-- Discovery's main filter: city + publication + moderation.
create index idx_provider_profiles_discovery
  on public.provider_profiles (base_city_id, status, moderation_status);

create index idx_provider_profiles_user on public.provider_profiles (user_id);

-- Text search on name/description (ILIKE '%term%').
create index idx_provider_profiles_name_trgm
  on public.provider_profiles using gin (display_name gin_trgm_ops);
create index idx_provider_profiles_description_trgm
  on public.provider_profiles using gin (description gin_trgm_ops);

-- "Providers being found through service areas": the search function's
-- EXISTS over provider_service_areas by locality_id is the hot path for
-- every single search request.
create index idx_service_areas_locality on public.provider_service_areas (locality_id);
create index idx_service_areas_provider on public.provider_service_areas (provider_id);

create index idx_provider_categories_category on public.provider_categories (category_id);

-- City/category free-text search, including the "fridge finds appliance
-- repair" keyword matching.
create index idx_localities_name_trgm on public.localities using gin (name gin_trgm_ops);
create index idx_cities_name_trgm on public.cities using gin (name gin_trgm_ops);
create index idx_service_categories_name_trgm on public.service_categories using gin (name gin_trgm_ops);
create index idx_service_categories_keywords on public.service_categories using gin (keywords);

-- Promotion matching inside search_providers()/active_promotions().
create index idx_promotions_active_window on public.promotions (state, starts_at, ends_at);

-- Engagement aggregation for engagement_summary_for().
create index idx_engagement_events_provider on public.engagement_events (provider_id, type, occurred_at);

-- Credential/verification lookups by provider.
create index idx_verification_records_provider on public.verification_records (provider_id, kind, created_at desc);
create index idx_credential_records_provider on public.credential_records (provider_id);
create index idx_consent_records_provider on public.consent_records (provider_id, kind, recorded_at desc);
create index idx_reports_provider on public.reports (provider_id);
create index idx_reports_status on public.reports (status);
