-- Engagement events and monetization preparation (no checkout).
--
-- Mirrors lib/domain/models/moderation.dart's EngagementEvent/Promotion/
-- SubscriptionPlan. Only taps and views are recorded -- there is deliberately
-- no "call completed", "lead" or "job" type, matching the client model
-- exactly, because the app hands off to the dialer/WhatsApp and cannot
-- observe what happens next.

create type public.engagement_event_type as enum (
  'profile_view', 'call_button_tap', 'whatsapp_button_tap', 'share_tap',
  'sponsor_impression', 'sponsor_tap'
);
create type public.promotion_placement as enum ('home_featured', 'search_top', 'category_top');
create type public.promotion_state as enum ('draft', 'scheduled', 'active', 'expired');

create table public.engagement_events (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  type public.engagement_event_type not null,
  occurred_at timestamptz not null default now(),
  -- Context only, never customer-identifying data.
  city_id text references public.cities(id),
  locality_id text references public.localities(id),
  category_id text references public.service_categories(id)
);

-- Sponsored placements. Writable by admins only (0009_rls.sql) -- a provider
-- can express *interest* (promotion_interest, below) but can never create,
-- edit, or activate a promotion, and a promotion never touches verification.
create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  state public.promotion_state not null default 'draft',
  placement public.promotion_placement not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- Empty = "all categories" / "all localities in city_id", matching
  -- Promotion.matches() in the client model.
  category_ids text[] not null default '{}',
  locality_ids text[] not null default '{}',
  city_id text references public.cities(id),
  priority int not null default 0,
  created_by uuid references auth.users(id),
  check (ends_at > starts_at)
);

-- Always unpriced in this build -- "Pricing coming soon" in the client. Admin
-- maintained; public read-only.
create table public.subscription_plans (
  id text primary key,
  title_key text not null,
  feature_keys text[] not null default '{}',
  is_recommended boolean not null default false,
  price_label text
);

-- A provider's recorded interest in a future paid plan. No payment, no
-- entitlement -- this table grants nothing by itself.
create table public.promotion_interest (
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  plan_id text not null references public.subscription_plans(id),
  recorded_at timestamptz not null default now(),
  primary key (provider_id, plan_id)
);
