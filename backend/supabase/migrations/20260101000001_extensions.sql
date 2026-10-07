-- Extensions used across the schema.
--
-- pgcrypto: gen_random_uuid() for primary keys.
-- pg_trgm:  trigram indexes for ILIKE text search (provider name/description,
--           locality name, category name/keywords) without standing up a
--           separate search service.
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
