-- Service taxonomy: groups and categories.
--
-- Mirrors lib/domain/models/service_category.dart. `is_healthcare` is the
-- same switch the client uses to turn on the healthcare-specific onboarding
-- fields -- adding a trade, or flagging one as healthcare, is a data change.

create table public.service_groups (
  id text primary key,
  name text not null,
  icon_key text not null,
  sort_order int not null default 0,
  description text
);

create table public.service_categories (
  id text primary key,
  group_id text not null references public.service_groups(id),
  name text not null,
  icon_key text not null,
  sort_order int not null default 0,
  -- Everyday-language search terms ("fridge", "leak", "nurse"). Matched with
  -- pg_trgm, see 0010_indexes.sql.
  keywords text[] not null default '{}',
  is_healthcare boolean not null default false,
  is_popular boolean not null default false,
  is_approved_for_launch boolean not null default true
);
