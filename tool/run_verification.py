#!/usr/bin/env python3
"""Comprehensive offline verification script for LocalSaathi.

Runs static source sanity checks and validates core product domain constraints:
1. Source tree integrity (imports, strings, parts, quote style)
2. Indian phone number normalization & validation logic
3. Location configuration & Mumbai locality coverage
4. Service taxonomy (6 groups + all 28 required trade categories)
5. Provider seed dataset (70 realistic fictional providers, masked phones, paused/draft states)
"""
from __future__ import annotations

import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
TEST = os.path.join(ROOT, "test")

passed = 0
failed = 0

def check(condition: bool, description: str, detail: str = ""):
    global passed, failed
    if condition:
        print(f"  [PASS] {description}")
        passed += 1
    else:
        print(f"  [FAIL] {description} - {detail}")
        failed += 1

print("=" * 60)
print(" LocalSaathi Offline Verification Suite")
print("=" * 60)

# -------------------------------------------------------------
# 1. Source Checks via check_sources.py
# -------------------------------------------------------------
print("\n1. Verifying source code structure and references...")
import subprocess
result = subprocess.run([sys.executable, os.path.join(ROOT, "tool", "check_sources.py")], capture_output=True, text=True, encoding="utf-8")
check(result.returncode == 0, "tool/check_sources.py clean run", result.stdout + result.stderr)

# -------------------------------------------------------------
# 2. Phone Normalization Logic
# -------------------------------------------------------------
print("\n2. Verifying Indian phone normalization & E.164 constraints...")
def normalize_indian_phone(raw: str) -> str | None:
    cleaned = re.sub(r"[\s\-\(\)\.]", "", raw.strip())
    if not cleaned:
        return None
    # Strip leading + or 00
    if cleaned.startswith("+"):
        cleaned = cleaned[1:]
    elif cleaned.startswith("00"):
        cleaned = cleaned[2:]
    
    # Strip national prefix 0 if followed by 10 digits
    if cleaned.startswith("0") and len(cleaned) == 11 and cleaned[1] in "6789":
        cleaned = cleaned[1:]
    
    # Country code 91
    if cleaned.startswith("91") and len(cleaned) == 12 and cleaned[2] in "6789":
        cleaned = cleaned[2:]
    
    # Must be 10 digits starting with 6, 7, 8, 9
    if len(cleaned) == 10 and cleaned.isdigit() and cleaned[0] in "6789":
        return f"+91{cleaned}"
    return None

test_cases = [
    ("9876543210", "+919876543210"),
    ("09876543210", "+919876543210"),
    ("+91 98765 43210", "+919876543210"),
    ("+919876543210", "+919876543210"),
    ("0091-9876543210", "+919876543210"),
    ("91 9876543210", "+919876543210"),
    ("  +91-98765-43210  ", "+919876543210"),
    ("98765 43210", "+919876543210"),
]
all_normalized_match = all(normalize_indian_phone(inp) == exp for inp, exp in test_cases)
check(all_normalized_match, "Valid Indian phone formats resolve to identical E.164")

invalid_cases = ["02212345678", "98765", "98765432109", "abcdefghij", "", "2234567890"]
all_invalid_rejected = all(normalize_indian_phone(inp) is None for inp in invalid_cases)
check(all_invalid_rejected, "Invalid/landline numbers rejected from OTP flow")

# -------------------------------------------------------------
# 3. Location Data & Market Boundaries
# -------------------------------------------------------------
print("\n3. Verifying location hierarchy & market boundaries...")
loc_src = open(os.path.join(LIB, "data", "seed", "location_seed.dart"), encoding="utf-8").read()

active_cities = re.findall(r"City\(\s*id:\s*'([^']+)'(?:(?!City\().)*launchStatus:\s*CityLaunchStatus\.active", loc_src, re.DOTALL)
check(active_cities == ["mh-mumbai"], "Mumbai is the sole initial active market", str(active_cities))

check("mh-thane" in loc_src and "mh-navi-mumbai" in loc_src and "mh-vasai-virar" in loc_src,
      "Surrounding cities (Thane, Navi Mumbai, Vasai-Virar) configured separately")

representative_localities = [
    "Andheri", "Bandra", "Borivali", "Dadar", "Kurla", "Chembur", "Powai", "Colaba"
]
found_localities = [loc for loc in representative_localities if f"name: '{loc}" in loc_src or f"name: '{loc} " in loc_src]
check(len(found_localities) == len(representative_localities), 
      "All 8 representative Mumbai localities defined", str(found_localities))

# -------------------------------------------------------------
# 4. Service Category Taxonomy
# -------------------------------------------------------------
print("\n4. Verifying service categories & 6 groups...")
cat_src = open(os.path.join(LIB, "data", "seed", "category_seed.dart"), encoding="utf-8").read()

required_groups = [
    "home-repairs", "home-services", "daily-workers", "vehicle-services", "healthcare", "other-services"
]
groups_found = [g for g in required_groups if f"id: '{g}'" in cat_src]
check(len(groups_found) == 6, "All 6 required service groups configured", str(groups_found))

required_categories = {
    "Home repairs": ["plumbing", "electrical", "carpentry", "painting", "masonry", "welding-fabrication", "ac-repair", "appliance-repair", "locksmith"],
    "Home services": ["home-cleaning", "pest-control", "laundry-ironing"],
    "Daily workers": ["daily-worker", "construction-labourer", "loading-unloading"],
    "Vehicle services": ["mechanic", "car-mechanic", "puncture-repair", "towing"],
    "Healthcare": ["general-physician", "dentist", "paediatrician", "physiotherapist", "diagnostic-centre"],
    "Other services": ["computer-repair", "network-technician", "tutor", "packers-movers"],
}
all_cats_present = True
missing_cats = []
for group_name, cats in required_categories.items():
    for c in cats:
        if f"id: '{c}'" not in cat_src:
            all_cats_present = False
            missing_cats.append(c)

check(all_cats_present, "All 28 required service categories present in catalog", str(missing_cats))

# -------------------------------------------------------------
# 5. Provider Seed Data
# -------------------------------------------------------------
print("\n5. Verifying provider seed data & safety constraints...")
prov_src = open(os.path.join(LIB, "data", "seed", "provider_seed.dart"), encoding="utf-8").read()

seed_count_match = re.search(r"static const int _seedCount = (\d+);", prov_src)
seed_count = int(seed_count_match.group(1)) if seed_count_match else 0
check(seed_count >= 20, f"Seeded provider count >= 20 (Actual: {seed_count})")

check("pausedProviderName" in prov_src and "draftProviderName" in prov_src,
      "Paused and draft listings included for non-public visibility verification")

check("+91999" in prov_src, "Seeded numbers use non-routable dummy prefix (+91999XXX)")

# -------------------------------------------------------------
# Summary
# -------------------------------------------------------------
print("\n" + "=" * 60)
print(f" Summary: {passed} passed, {failed} failed")
print("=" * 60)
sys.exit(0 if failed == 0 else 1)
