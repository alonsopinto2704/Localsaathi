#!/usr/bin/env python3
"""Generates backend/supabase/seed.sql from the Flutter client's own seed data.

Why generate instead of hand-type: lib/data/seed/location_seed.dart and
category_seed.dart are the single source of truth for every city/locality/
category id the client already ships with (and that provider_profiles rows
will foreign-key against). Hand-transcribing ~130 rows invites a typo that
silently breaks a foreign key. Parsing the Dart source keeps the two sides
byte-for-byte identical and re-runnable if Antigravity edits the seed data.

Not a Dart parser: this is a small set of targeted regexes over the specific
literal shapes those two files use. Re-run this script (and re-apply the
seed) whenever location_seed.dart or category_seed.dart changes.
"""
from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB_SEED = os.path.join(ROOT, "lib", "data", "seed")
OUT_PATH = os.path.join(ROOT, "backend", "supabase", "seed.sql")


def sql_str(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def sql_str_array(values: list[str]) -> str:
    if not values:
        return "'{}'"
    return "ARRAY[" + ",".join(sql_str(v) for v in values) + "]::text[]"


def sql_bool(value: bool) -> str:
    return "true" if value else "false"


def read(name: str) -> str:
    with open(os.path.join(LIB_SEED, name), encoding="utf-8") as f:
        return f.read()


def extract_blocks(src: str, ctor: str) -> list[str]:
    """Returns the argument text of every `Ctor(...)` call, handling one level
    of nested parens/brackets (enough for these two files)."""
    blocks = []
    for m in re.finditer(re.escape(ctor) + r"\(", src):
        start = m.end()
        depth = 1
        i = start
        while depth > 0:
            if src[i] in "([":
                depth += 1
            elif src[i] in ")]":
                depth -= 1
            i += 1
        blocks.append(src[start : i - 1])
    return blocks


def field(block: str, name: str) -> str | None:
    m = re.search(name + r":\s*'((?:[^'\\]|\\.)*)'", block)
    return m.group(1).replace("\\'", "'") if m else None


def field_bool(block: str, name: str, default: bool) -> bool:
    m = re.search(name + r":\s*(true|false)", block)
    return (m.group(1) == "true") if m else default


def field_enum(block: str, name: str) -> str | None:
    m = re.search(name + r":\s*\w+\.(\w+)", block)
    return m.group(1) if m else None


def field_list(block: str, name: str) -> list[str]:
    m = re.search(name + r":\s*<String>\[([^\]]*)\]", block)
    if not m:
        return []
    return re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(1))


LAUNCH_STATUS_SQL = {
    "active": "active",
    "comingSoon": "coming_soon",
    "inactive": "inactive",
}


def build_locations_sql() -> str:
    src = read("location_seed.dart")
    lines: list[str] = []

    lines.append("-- States / Union Territories --------------------------------------------")
    for block in extract_blocks(src, "StateRegion"):
        row_id = field(block, "id")
        if row_id is None:
            continue
        name = field(block, "name")
        is_ut = field_bool(block, "isUnionTerritory", False)
        lines.append(
            "insert into public.state_regions (id, country_id, name, is_union_territory) "
            f"values ({sql_str(row_id)}, 'in', {sql_str(name)}, {sql_bool(is_ut)}) "
            "on conflict (id) do update set name = excluded.name, "
            "is_union_territory = excluded.is_union_territory;"
        )

    lines.append("")
    lines.append("-- Cities -------------------------------------------------------------------")
    for block in extract_blocks(src, "City"):
        row_id = field(block, "id")
        if row_id is None:
            continue
        state_id = field(block, "stateId")
        name = field(block, "name")
        launch = field_enum(block, "launchStatus") or "inactive"
        aliases = field_list(block, "aliases")
        is_metro = field_bool(block, "isMetro", False)
        lines.append(
            "insert into public.cities (id, state_id, name, launch_status, aliases, is_metro) "
            f"values ({sql_str(row_id)}, {sql_str(state_id)}, {sql_str(name)}, "
            f"{sql_str(LAUNCH_STATUS_SQL[launch])}, {sql_str_array(aliases)}, {sql_bool(is_metro)}) "
            "on conflict (id) do update set state_id = excluded.state_id, "
            "name = excluded.name, launch_status = excluded.launch_status, "
            "aliases = excluded.aliases, is_metro = excluded.is_metro;"
        )

    lines.append("")
    lines.append("-- Localities -----------------------------------------------------------")
    for block in extract_blocks(src, "Locality"):
        row_id = field(block, "id")
        if row_id is None:
            continue
        city_id = field(block, "cityId")
        name = field(block, "name")
        pin = field(block, "pinCode")
        popular = field_bool(block, "isPopular", False)
        lines.append(
            "insert into public.localities (id, city_id, name, pin_code, is_popular) "
            f"values ({sql_str(row_id)}, {sql_str(city_id)}, {sql_str(name)}, "
            f"{sql_str(pin)}, {sql_bool(popular)}) "
            "on conflict (id) do update set city_id = excluded.city_id, "
            "name = excluded.name, pin_code = excluded.pin_code, "
            "is_popular = excluded.is_popular;"
        )

    return "\n".join(lines)


def build_catalog_sql() -> str:
    src = read("category_seed.dart")
    lines: list[str] = []

    lines.append("-- Service groups -------------------------------------------------------")
    for block in extract_blocks(src, "ServiceGroup"):
        row_id = field(block, "id")
        if row_id is None:
            continue
        name = field(block, "name")
        icon = re.search(r"iconKey:\s*CategoryIconKeys\.(\w+)", block)
        icon_key = icon.group(1) if icon else "other"
        sort_order = re.search(r"sortOrder:\s*(\d+)", block)
        description = field(block, "description")
        lines.append(
            "insert into public.service_groups (id, name, icon_key, sort_order, description) "
            f"values ({sql_str(row_id)}, {sql_str(name)}, {sql_str(icon_key)}, "
            f"{sort_order.group(1) if sort_order else 0}, {sql_str(description)}) "
            "on conflict (id) do update set name = excluded.name, "
            "icon_key = excluded.icon_key, sort_order = excluded.sort_order, "
            "description = excluded.description;"
        )

    lines.append("")
    lines.append("-- Service categories ----------------------------------------------------")
    for block in extract_blocks(src, "ServiceCategory"):
        row_id = field(block, "id")
        if row_id is None:
            continue
        group_id = field(block, "groupId")
        name = field(block, "name")
        icon = re.search(r"iconKey:\s*CategoryIconKeys\.(\w+)", block)
        icon_key = icon.group(1) if icon else "other"
        sort_order = re.search(r"sortOrder:\s*(\d+)", block)
        keywords = field_list(block, "keywords")
        is_healthcare = field_bool(block, "isHealthcare", False)
        is_popular = field_bool(block, "isPopular", False)
        is_approved = field_bool(block, "isApprovedForLaunch", True)
        lines.append(
            "insert into public.service_categories "
            "(id, group_id, name, icon_key, sort_order, keywords, is_healthcare, "
            "is_popular, is_approved_for_launch) values ("
            f"{sql_str(row_id)}, {sql_str(group_id)}, {sql_str(name)}, {sql_str(icon_key)}, "
            f"{sort_order.group(1) if sort_order else 0}, {sql_str_array(keywords)}, "
            f"{sql_bool(is_healthcare)}, {sql_bool(is_popular)}, {sql_bool(is_approved)}) "
            "on conflict (id) do update set group_id = excluded.group_id, "
            "name = excluded.name, icon_key = excluded.icon_key, "
            "sort_order = excluded.sort_order, keywords = excluded.keywords, "
            "is_healthcare = excluded.is_healthcare, is_popular = excluded.is_popular, "
            "is_approved_for_launch = excluded.is_approved_for_launch;"
        )

    return "\n".join(lines)


def main() -> None:
    header = (
        "-- GENERATED FILE. Do not hand-edit.\n"
        "-- Produced by backend/scripts/generate_seed_sql.py from\n"
        "-- lib/data/seed/location_seed.dart and lib/data/seed/category_seed.dart.\n"
        "-- Re-run that script after either file changes, then re-apply:\n"
        "--   supabase db reset   (local)\n"
        "--   psql \"$DATABASE_URL\" -f backend/supabase/seed.sql   (any environment)\n\n"
        "insert into public.countries (id, name, iso_code, dial_code, is_active) "
        "values ('in', 'India', 'IN', '91', true) on conflict (id) do nothing;\n"
    )
    body = build_locations_sql() + "\n\n" + build_catalog_sql() + "\n"
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(header + "\n" + body)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
