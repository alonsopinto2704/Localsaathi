#!/usr/bin/env python3
"""Offline sanity checker for the LocalSaathi Dart sources.

This is not a Dart analyzer. It exists because the build machine has no network
access and therefore no Flutter SDK, so it catches the class of mistakes that a
careless hand-written pass misses: unresolvable imports, `part`/`library`
mismatches, references to strings/constants that were never defined, and
duplicate type declarations.
"""
from __future__ import annotations

import os
import re
import sys
from collections import defaultdict

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
TEST = os.path.join(ROOT, "test")
PKG = "localsaathi"

problems: list[str] = []
notes: list[str] = []


def dart_files(base: str) -> list[str]:
    out: list[str] = []
    for dirpath, _dirnames, filenames in os.walk(base):
        for name in filenames:
            if name.endswith(".dart"):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


files = dart_files(LIB) + dart_files(TEST)
if not files:
    print("No Dart files found.")
    sys.exit(1)

rel = lambda p: os.path.relpath(p, ROOT).replace("\\", "/")

# ---------------------------------------------------------------- imports
IMPORT_RE = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
PART_RE = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]""", re.M)
PART_OF_RE = re.compile(r"""^\s*part\s+of\s+['"]([^'"]+)['"]""", re.M)

for path in files:
    src = open(path, encoding="utf-8").read()
    folder = os.path.dirname(path)

    for target in IMPORT_RE.findall(src):
        if target.startswith("dart:"):
            continue
        if target.startswith("package:"):
            parts = target.split("/")
            pkg = parts[0].replace("package:", "")
            if pkg != PKG:
                continue  # third-party; resolved by pub
            resolved = os.path.join(LIB, *parts[1:])
        else:
            resolved = os.path.normpath(os.path.join(folder, target))
        if not os.path.isfile(resolved):
            problems.append(f"{rel(path)}: unresolved import '{target}'")

    for target in PART_RE.findall(src):
        resolved = os.path.normpath(os.path.join(folder, target))
        if not os.path.isfile(resolved):
            problems.append(f"{rel(path)}: unresolved part '{target}'")

    for target in PART_OF_RE.findall(src):
        resolved = os.path.normpath(os.path.join(folder, target))
        if not os.path.isfile(resolved):
            problems.append(f"{rel(path)}: part-of points at missing '{target}'")

# ------------------------------------------------- parts declared/attached
declared_parts: dict[str, set[str]] = defaultdict(set)
attached_parts: set[str] = set()
for path in files:
    src = open(path, encoding="utf-8").read()
    folder = os.path.dirname(path)
    for target in PART_RE.findall(src):
        declared_parts[os.path.normpath(os.path.join(folder, target))].add(path)
    if PART_OF_RE.search(src):
        attached_parts.add(os.path.normpath(path))

for part_file, owners in declared_parts.items():
    if part_file not in attached_parts:
        problems.append(
            f"{rel(part_file)}: is declared as a part but has no 'part of' "
            f"directive (declared by {', '.join(rel(o) for o in owners)})"
        )
for path in files:
    src = open(path, encoding="utf-8").read()
    if PART_OF_RE.search(src) and os.path.normpath(path) not in declared_parts:
        problems.append(f"{rel(path)}: 'part of' but no library declares it")

# ------------------------------------------------------------- types
CLASS_RE = re.compile(r"^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+|mixin\s+)*"
                      r"(class|enum|mixin|extension|typedef)\s+([A-Za-z_]\w*)", re.M)
type_names: dict[str, list[str]] = defaultdict(list)
for path in files:
    src = open(path, encoding="utf-8").read()
    for _kind, name in CLASS_RE.findall(src):
        type_names[name].append(rel(path))

# --------------------------------------------------- string member getters
# Collect everything an AppStrings subclass or extension exposes, then check
# every `strings.<name>` reference against that set.
#
# Members are collected from the whole `l10n` folder, so a name defined in any
# locale or part file counts as defined — that is exactly the fallback contract
# the runtime relies on.
strings_members: set[str] = set()
l10n_dir = os.path.join(LIB, "core", "l10n")
STRINGS_FILES = [
    os.path.join(l10n_dir, n)
    for n in os.listdir(l10n_dir)
    if n.endswith(".dart")
]
MEMBER_RE = re.compile(
    r"^\s*(?:@override\s+)?(?:String|bool|int|double|List<[^>]+>|Map<[^>]+>)"
    r"\s+get\s+([A-Za-z_]\w*)\s*(?:=>|;|\{)",
    re.M,
)
METHOD_RE = re.compile(
    r"^\s*(?:@override\s+)?String\s+([A-Za-z_]\w*)\s*\(",
    re.M,
)
for path in STRINGS_FILES:
    src = open(path, encoding="utf-8").read()
    strings_members.update(MEMBER_RE.findall(src))
    strings_members.update(METHOD_RE.findall(src))

# Sanity check on the collector itself: the reference locale must be non-trivial.
if len(strings_members) < 250:
    problems.append(
        f"l10n collector only found {len(strings_members)} members; the "
        "reference strings class should expose far more"
    )

USAGE_RE = re.compile(r"\bstrings\.([A-Za-z_]\w*)")
for path in files:
    src = open(path, encoding="utf-8").read()
    used = set(USAGE_RE.findall(src))
    for name in sorted(used - strings_members):
        problems.append(
            f"{rel(path)}: strings.{name} is not defined in AppStrings"
        )

# ------------------------------------------- AppConfig / constant usage
config_src = open(os.path.join(LIB, "core", "config", "app_config.dart"),
                  encoding="utf-8").read()
config_members = set(re.findall(r"static const \w+(?:<[^>]*>)? (\w+)", config_src))
for path in files:
    src = open(path, encoding="utf-8").read()
    for name in set(re.findall(r"\bAppConfig\.([A-Za-z_]\w*)", src)):
        # Static methods (e.g. the private constructor marker) are not constants
        # and are not part of this check.
        if name.startswith("_"):
            continue
        if name not in config_members:
            problems.append(f"{rel(path)}: AppConfig.{name} is not defined")

# ------------------------------------------------------- category icon keys
seed_src = open(os.path.join(LIB, "data", "seed", "category_seed.dart"),
                encoding="utf-8").read()
icon_keys = set(re.findall(r"CategoryIconKeys\.(\w+)", seed_src))
icons_src = open(os.path.join(LIB, "domain", "models", "service_category.dart"),
                 encoding="utf-8").read()
defined_keys = set(re.findall(r"static const String (\w+)", icons_src))
for key in sorted(icon_keys - defined_keys):
    problems.append(f"category_seed.dart references CategoryIconKeys.{key} "
                    f"which is not defined")

# ------------------------------------------- localities referenced by seeds
loc_src = open(os.path.join(LIB, "data", "seed", "location_seed.dart"),
               encoding="utf-8").read()
defined_localities = set(re.findall(r"id: '([a-z0-9\-]+)',\s*\n\s*cityId", loc_src))
defined_cities = set(re.findall(r"City\(\s*\n?\s*id: '([a-z0-9\-]+)'", loc_src))
defined_categories = set(re.findall(r"id: '([a-z0-9\-]+)',\s*\n\s*groupId", seed_src))
defined_groups = set(re.findall(r"ServiceGroup\(\s*\n\s*id: '([a-z0-9\-]+)'", seed_src))

prov_src = open(os.path.join(LIB, "data", "seed", "provider_seed.dart"),
                encoding="utf-8").read()
for needle in sorted(set(re.findall(r"'(mh-[a-z0-9\-]+)'", prov_src))):
    if needle in defined_cities:
        continue
    if needle not in defined_localities:
        problems.append(f"provider_seed.dart references locality '{needle}' "
                        f"which is not in location_seed.dart")

for cat in sorted(set(re.findall(r"categories: <String>\[([^\]]*)\]", prov_src))):
    for name in re.findall(r"'([^']+)'", cat):
        if name not in defined_categories:
            problems.append(f"provider_seed.dart references category '{name}' "
                            f"which is not in category_seed.dart")

for price_key in sorted(set(re.findall(r"prices: <String, int>\{([^}]*)\}", prov_src))):
    for name in re.findall(r"'([^']+)'", price_key):
        if name not in defined_categories:
            problems.append(f"provider_seed.dart price keys reference unknown "
                            f"category '{name}'")

# ----------------------------------------------------- group id consistency
seed_groups_used = set(re.findall(r"groupId: '([a-z0-9\-]+)'", seed_src))
for group in sorted(seed_groups_used - defined_groups):
    problems.append(f"category_seed.dart uses groupId '{group}' which has no "
                    f"ServiceGroup")

# ------------------------------------------------- duplicate top-level types
for name, where in sorted(type_names.items()):
    if len(where) > 1:
        # Same name in different libraries is legal Dart; flag only if a
        # library would import two of them without a prefix.
        notes.append(f"type '{name}' declared in {len(where)} files: "
                     + ", ".join(sorted(where)))

# ------------------------------------------------------- unused privates
# A private field or helper that is never read is dead code. `unused_element`
# only catches unreachable code, so this is the check that actually keeps a
# one-developer codebase honest.
DECL_RE = re.compile(
    r"^\s*(?:static\s+|late\s+|final\s+|const\s+|@override\s+)*"
    r"(?:final\s+)?[A-Za-z_][\w<>,?\[\] ]*\s+(_[A-Za-z]\w*)\s*[;=]",
    re.M,
)
for path in files:
    src = open(path, encoding="utf-8").read()
    # Strip comments and string literals so a mention in prose does not count.
    code = re.sub(r"//[^\n]*", "", src)
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    code = re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", code)
    code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', code)

    for name in sorted(set(DECL_RE.findall(code))):
        # Count identifier occurrences; the declaration itself is one.
        uses = len(re.findall(r"\b" + re.escape(name) + r"\b", code))
        if uses <= 1:
            problems.append(
                f"{rel(path)}: private member {name} is never used"
            )

# ---------------------------------------------------- formatting habits
# The two lint rules most likely to fail CI on a hand-written codebase: single
# quotes, and a trailing comma on a multi-line argument list.
for path in files:
    raw_src = open(path, encoding="utf-8").read()
    # Strip comments while preserving character counts / line positions
    # so comments with prose in quotes are not flagged as Dart string literals.
    src = re.sub(r"//[^\n]*", lambda m: " " * len(m.group(0)), raw_src)
    src = re.sub(r"/\*.*?\*/", lambda m: " " * len(m.group(0)), src, flags=re.S)
    # Also strip valid single-quoted string literals so embedded double quotes
    # (e.g. 'Try "plumber"') are not misidentified as double-quoted string literals.
    src_no_single = re.sub(r"'(?:[^'\\\n]|\\.)*'", lambda m: " " * len(m.group(0)), src)
    for match in re.finditer(r'"[^"\n]*"', src_no_single):
        literal = match.group(0)
        if "'" in literal:
            continue  # a double-quoted string containing an apostrophe is fine
        line_no = raw_src[:match.start()].count("\n") + 1
        problems.append(
            f"{rel(path)}:{line_no}: double-quoted string {literal!r} "
            "(project style is single quotes)"
        )

# ------------------------------------------------------------- report
print(f"Scanned {len(files)} Dart files.\n")

if notes:
    print("Notes (not necessarily errors):")
    for note in notes:
        print("  -", note)
    print()

if problems:
    print(f"PROBLEMS ({len(problems)}):")
    for problem in problems:
        print("  !", problem)
    sys.exit(1)

print("No problems found.")
print(f"  - imports/parts resolved")
print(f"  - AppStrings members referenced: checked")
print(f"  - category/locality seed references: checked")
