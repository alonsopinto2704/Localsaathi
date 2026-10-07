#!/usr/bin/env python3
"""Exports the app's seed data as the Floot directory site's data helper.

    python tool/export_web_data.py      # refreshes showcase/data.js from the Dart seed
    python tool/export_floot_data.py    # writes build/floot/directoryData.tsx

The output is uploaded to the Floot project as helpers/directoryData.tsx. It
carries only what the public site shows: phone numbers are masked (demo
listings), and map pins follow the same rule as the app (premises-based demo
providers opt in, pinned near their locality centre; lib/data/seed/
provider_seed.dart _demoPin).
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY_ID = "mh-mumbai"

src = open(os.path.join(ROOT, "showcase", "data.js"), encoding="utf-8").read()
data = json.loads(src[src.index("{"): src.rindex("}") + 1])

coords_src = open(os.path.join(ROOT, "lib", "data", "seed", "locality_coordinates.dart"), encoding="utf-8").read()
centres = {
    m.group(1): (float(m.group(2)), float(m.group(3)))
    for m in re.finditer(r"'([a-z0-9-]+)': GeoPoint\(([\d.]+), ([\d.]+)\)", coords_src)
}
city_centre = centres.pop(CITY_ID, (19.0760, 72.8777))

HOURS = {
    "standard": "Mon–Sat 9:00 am – 8:00 pm · Sunday closed",
    "early": "Mon–Sat 7:00 am – 5:00 pm · Sunday closed",
    "late": "Mon–Sat 10:00 am – 10:00 pm · Sunday closed",
    "afternoon": "Mon–Sat 2:00 pm – 9:00 pm · Sunday closed",
    "roundTheClock": "Open 24 hours, every day",
    "clinicEvening": "Mon–Sat 10:00 am – 9:00 pm · Sunday closed",
    "clinicMorning": "Mon–Sat 8:00 am – 1:00 pm · Sunday closed",
    "flexibleNoHours": None,
}


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def demo_pin(index, base):
    lat, lng = centres.get(base, city_centre)
    d_lat = ((index * 37) % 9 - 4) * 0.0009
    d_lng = ((index * 53) % 9 - 4) * 0.0009
    return {"lat": round(lat + d_lat, 6), "lng": round(lng + d_lng, 6)}


localities = [
    {
        "id": l["id"],
        "slug": l["id"].removeprefix(CITY_ID + "-"),
        "name": l["name"],
        "pinCode": l.get("pinCode"),
        "centre": {"lat": centres[l["id"]][0], "lng": centres[l["id"]][1]} if l["id"] in centres else None,
    }
    for l in data["localities"]
    if l["cityId"] == CITY_ID
]
groups = sorted(
    ({"id": g["id"], "name": g["name"], "description": g.get("description", "")} for g in data["groups"]),
    key=lambda g: next(x["sortOrder"] for x in data["groups"] if x["id"] == g["id"]),
)
categories = [
    {
        "id": c["id"],
        "slug": c["id"],
        "name": c["name"],
        "groupId": c["groupId"],
        "isPopular": bool(c.get("isPopular")),
        "keywords": c.get("keywords", []),
    }
    for c in sorted(data["categories"], key=lambda c: c.get("sortOrder", 0))
]

providers, seen = [], set()
for p in data["providers"]:
    if p.get("status") != "published":
        continue
    index = int(p["id"].rsplit("-", 1)[1])
    slug = slugify(p["name"])
    while slug in seen:
        slug += "-2"
    seen.add(slug)
    digits = re.sub(r"\D", "", p["phone"])
    providers.append({
        "id": p["id"],
        "slug": slug,
        "name": p["name"],
        "maskedPhone": "+91 •••••• ••" + digits[-2:],
        "categoryIds": p["categories"],
        "baseLocalityId": p["baseLocalityId"],
        "serviceAreaIds": p.get("serviceAreaIds") or [p["baseLocalityId"]],
        "description": p.get("description") or "",
        "languages": p.get("languages") or [],
        "hours": HOURS.get(p.get("hoursType")),
        "homeVisits": bool(p.get("homeVisits")),
        "whatsapp": bool(p.get("whatsapp")),
        "prices": [{"categoryId": k, "amount": v} for k, v in (p.get("prices") or {}).items()],
        "isSponsored": bool(p.get("isSponsored")),
        "healthcare": p.get("healthcare"),
        "mapPin": None if p.get("homeVisits") else demo_pin(index, p["baseLocalityId"]),
    })

directory = {
    "city": {"id": CITY_ID, "slug": "mumbai", "name": "Mumbai", "centre": {"lat": city_centre[0], "lng": city_centre[1]}},
    "groups": groups,
    "categories": categories,
    "localities": localities,
    "providers": providers,
}

TYPES = """type GeoPoint = { lat: number; lng: number };
type Locality = { id: string; slug: string; name: string; pinCode: string | null; centre: GeoPoint | null };
type Group = { id: string; name: string; description: string };
type Category = { id: string; slug: string; name: string; groupId: string; isPopular: boolean; keywords: string[] };
type Provider = {
  id: string;
  slug: string;
  name: string;
  maskedPhone: string;
  categoryIds: string[];
  baseLocalityId: string;
  serviceAreaIds: string[];
  description: string;
  languages: string[];
  hours: string | null;
  homeVisits: boolean;
  whatsapp: boolean;
  prices: { categoryId: string; amount: number }[];
  isSponsored: boolean;
  healthcare: Record<string, unknown> | null;
  mapPin: GeoPoint | null;
};
type Directory = {
  city: { id: string; slug: string; name: string; centre: GeoPoint };
  groups: Group[];
  categories: Category[];
  localities: Locality[];
  providers: Provider[];
};
"""

out_dir = os.path.join(ROOT, "build", "floot")
os.makedirs(out_dir, exist_ok=True)
for old in os.listdir(out_dir):
    os.remove(os.path.join(out_dir, old))
HEADER = ("// Generated by tool/export_floot_data.py from the LocalSaathi app's seed data.\n"
          "// Do not edit by hand: re-run the script. Fictional demo listings, numbers masked.\n\n")


def dumps(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


# Providers are split across a few helpers so each file stays small enough to
# upload in one call; directoryData stitches them back together.
PARTS = ["A", "B", "C"]
size = -(-len(providers) // len(PARTS))
for i, part in enumerate(PARTS):
    chunk = providers[i * size:(i + 1) * size]
    with open(os.path.join(out_dir, f"directoryProviders{part}.tsx"), "w", encoding="utf-8") as f:
        f.write(HEADER)
        f.write(f"export const directoryProviders{part}: unknown[] = {dumps(chunk)};\n")

core = {k: v for k, v in directory.items() if k != "providers"}
with open(os.path.join(out_dir, "directoryData.tsx"), "w", encoding="utf-8") as f:
    f.write(HEADER)
    for part in PARTS:
        f.write(f'import {{ directoryProviders{part} }} from "./directoryProviders{part}";\n')
    f.write("\n" + TYPES)
    f.write(f"\nconst core = {dumps(core)};\n\n")
    f.write("export const directoryData: Directory = {\n  ...core,\n  providers: [\n"
            + "".join(f"    ...directoryProviders{p},\n" for p in PARTS)
            + "  ] as Provider[],\n};\n")

# Legal pages: the same text as the app (lib/features/legal/legal_documents.dart),
# with the AppConfig placeholders filled in.
DART_STR = r"'((?:[^'\\]|\\.)*)'"
config_src = open(os.path.join(ROOT, "lib", "core", "config", "app_config.dart"), encoding="utf-8").read()
config = {m.group(1): m.group(2) for m in re.finditer(r"static const String (\w+)\s*=\s*" + DART_STR + ";", config_src)}
config["_app"], config["_operator"] = config["appName"], config["operatorLegalName"]
legal_src = open(os.path.join(ROOT, "lib", "features", "legal", "legal_documents.dart"), encoding="utf-8").read()
legal_src = re.sub(r"^(\s*)(AppConfig\.\w+|_operator),$", r"\1'${\2}',", legal_src, flags=re.M)
legal_src = re.sub(r"\$\{(?:AppConfig\.)?(\w+)\}|\$(_app|_operator)\b",
                   lambda m: config[m.group(1) or m.group(2)], legal_src)


def unescape(s):
    return s.replace("\\'", "'")


legal = []
for m in re.finditer(r"const LegalDocument _(\w+) = LegalDocument\((.*?)\n\);", legal_src, re.S):
    body = m.group(2)
    legal.append({
        "slug": m.group(1),
        "title": unescape(re.search(r"title: " + DART_STR, body).group(1)),
        "summary": unescape(re.search(r"summary:\s*" + DART_STR, body).group(1)),
        "sections": [
            {"heading": unescape(s.group(1)), "paragraphs": [unescape(p) for p in re.findall(DART_STR, s.group(2))]}
            for s in re.finditer(r"LegalSection\(" + DART_STR + r", <String>\[(.*?)\]\)", body, re.S)
        ],
    })
assert [d["slug"] for d in legal] == ["privacy", "terms", "guidelines", "grievance"], legal
assert all(d["sections"] and all(s["paragraphs"] for s in d["sections"]) for d in legal)
assert "$" not in dumps(legal) and "AppConfig" not in dumps(legal), "unresolved placeholder"
reviewed = "true" if re.search(r"legalTextReviewed = true", config_src) else "false"
with open(os.path.join(out_dir, "legalData.tsx"), "w", encoding="utf-8") as f:
    f.write(HEADER.replace("Fictional demo listings, numbers masked.", "Source: lib/features/legal/legal_documents.dart."))
    f.write("export type LegalDoc = { slug: string; title: string; summary: string; "
            "sections: { heading: string; paragraphs: string[] }[] };\n\n")
    f.write(f"export const legalTextReviewed = {reviewed};\n")
    f.write(f'export const legalVersion = "{config["legalVersion"]}";\n\n')
    f.write(f"export const legalDocs: LegalDoc[] = {dumps(legal)};\n")

for name in sorted(os.listdir(out_dir)):
    print(name, os.path.getsize(os.path.join(out_dir, name)) // 1024, "KB")
print(f"{len(localities)} localities, {len(categories)} categories, {len(providers)} providers, "
      f"{sum(1 for p in providers if p['mapPin'])} with map pins")
