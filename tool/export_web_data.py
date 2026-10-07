#!/usr/bin/env python3
"""Parses LocalSaathi Dart seed files and exports clean JSON data for the web showcase."""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_SEED = os.path.join(ROOT, "lib", "data", "seed")
L10N = os.path.join(ROOT, "lib", "core", "l10n")
WEB_DIR = os.path.join(ROOT, "showcase")

os.makedirs(WEB_DIR, exist_ok=True)

def read_file(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()

# 1. Parse Groups & Categories
cat_src = read_file(os.path.join(LIB_SEED, "category_seed.dart"))

groups = []
group_matches = re.finditer(
    r"ServiceGroup\(\s*id:\s*'([^']+)',\s*name:\s*'([^']+)',\s*iconKey:\s*CategoryIconKeys\.(\w+),\s*sortOrder:\s*(\d+),\s*description:\s*'([^']+)',\s*\)",
    cat_src
)
for m in group_matches:
    groups.append({
        "id": m.group(1),
        "name": m.group(2),
        "iconKey": m.group(3),
        "sortOrder": int(m.group(4)),
        "description": m.group(5),
    })

categories = []
def extract_blocks(src: str, ctor: str) -> list[str]:
    blocks = []
    for m in re.finditer(re.escape(ctor) + r"\(", src):
        start = m.end()
        depth = 1
        i = start
        while depth > 0 and i < len(src):
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

def field_bool(block: str, name: str, default: bool = False) -> bool:
    m = re.search(name + r":\s*(true|false)", block)
    return (m.group(1) == "true") if m else default

def field_int(block: str, name: str, default: int = 0) -> int:
    m = re.search(name + r":\s*(\d+)", block)
    return int(m.group(1)) if m else default

def field_list(block: str, name: str) -> list[str]:
    m = re.search(name + r":\s*(?:<String>)?\[([^\]]*)\]", block)
    if not m:
        return []
    return re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(1))

def field_map(block: str, name: str) -> dict[str, int]:
    m = re.search(name + r":\s*<String,\s*int>\{([^}]*)\}", block)
    if not m:
        return {}
    res = {}
    for pair in re.finditer(r"'([^']+)':\s*(\d+)", m.group(1)):
        res[pair.group(1)] = int(pair.group(2))
    return res

for block in extract_blocks(cat_src, "ServiceCategory"):
    cid = field(block, "id")
    if not cid:
        continue
    categories.append({
        "id": cid,
        "groupId": field(block, "groupId"),
        "name": field(block, "name"),
        "iconKey": re.search(r"iconKey:\s*CategoryIconKeys\.(\w+)", block).group(1) if "iconKey:" in block else "other",
        "sortOrder": field_int(block, "sortOrder", 99),
        "keywords": field_list(block, "keywords"),
        "isPopular": field_bool(block, "isPopular", False),
    })

# 2. Parse Location Seed
loc_src = read_file(os.path.join(LIB_SEED, "location_seed.dart"))

cities = []
for block in extract_blocks(loc_src, "City"):
    cid = field(block, "id")
    if not cid:
        continue
    status_m = re.search(r"launchStatus:\s*CityLaunchStatus\.(\w+)", block)
    status = status_m.group(1) if status_m else "comingSoon"
    cities.append({
        "id": cid,
        "stateId": field(block, "stateId"),
        "name": field(block, "name"),
        "launchStatus": status,
        "isMetro": field_bool(block, "isMetro", False),
        "aliases": field_list(block, "aliases"),
    })

localities = []
for block in extract_blocks(loc_src, "Locality"):
    lid = field(block, "id")
    if not lid:
        continue
    localities.append({
        "id": lid,
        "cityId": field(block, "cityId"),
        "name": field(block, "name"),
        "pinCode": field(block, "pinCode"),
        "isPopular": field_bool(block, "isPopular", False),
    })

# 3. Parse Providers
prov_src = read_file(os.path.join(LIB_SEED, "provider_seed.dart"))

def phone_for(index: int) -> str:
    a = (index * 37 + 11) % 1000
    b = (index * 91 + 7) % 1000
    return f"+91999{a:03d}{b:03d}"

providers = []
idx = 0
for block in extract_blocks(prov_src, "_Entry"):
    name = field(block, "name")
    if not name:
        continue
    cats = field_list(block, "categories")
    base = field(block, "base")
    areas = field_list(block, "areas")
    desc = field(block, "description")
    langs = field_list(block, "languages")
    home_visits = field_bool(block, "homeVisits", True)
    whatsapp = field_bool(block, "whatsapp", False)
    prices = field_map(block, "prices")
    photos = field_list(block, "photoCaptions")
    
    hours_m = re.search(r"hours:\s*_Hours\.(\w+)", block)
    hours_type = hours_m.group(1) if hours_m else "standard"

    # Healthcare details if any
    healthcare = None
    if "HealthcareDetails(" in block:
        h_m = re.search(r"HealthcareDetails\((.*?)\)", block, re.DOTALL)
        if h_m:
            h_block = h_m.group(1)
            healthcare = {
                "qualification": field(h_block, "qualification"),
                "specialty": field(h_block, "specialty"),
                "clinicName": field(h_block, "clinicName"),
                "clinicAddress": field(h_block, "clinicAddress"),
                "consultationHoursNote": field(h_block, "consultationHoursNote"),
                "isDiagnosticCentre": field_bool(h_block, "isDiagnosticCentre", False),
            }

    phone = phone_for(idx)
    pid = f"provider-seed-{idx:03d}"

    providers.append({
        "id": pid,
        "name": name,
        "phone": phone,
        "categories": cats,
        "baseLocalityId": base,
        "serviceAreaIds": areas,
        "description": desc,
        "languages": langs,
        "hoursType": hours_type,
        "homeVisits": home_visits,
        "whatsapp": whatsapp,
        "prices": prices,
        "photos": photos,
        "healthcare": healthcare,
        "status": "published",
        "isSponsored": (idx == 0),  # provider-seed-000 is the sponsored plumber in seed
    })
    idx += 1

# Add the paused and draft listings
providers.append({
    "id": "provider-seed-paused-001",
    "name": "Verma Plumbing (paused listing)",
    "phone": phone_for(71),
    "categories": ["plumbing"],
    "baseLocalityId": "mh-mumbai-andheri-west",
    "serviceAreaIds": ["mh-mumbai-andheri-west"],
    "description": "Seeded paused listing. It must never appear in customer results.",
    "languages": ["Hindi"],
    "hoursType": "standard",
    "homeVisits": True,
    "whatsapp": False,
    "prices": {},
    "photos": [],
    "healthcare": None,
    "status": "paused",
    "isSponsored": False,
})

providers.append({
    "id": "provider-seed-draft-001",
    "name": "New Age Electricals (unpublished draft)",
    "phone": phone_for(72),
    "categories": ["electrical"],
    "baseLocalityId": "mh-mumbai-borivali-west",
    "serviceAreaIds": ["mh-mumbai-borivali-west"],
    "description": "Seeded draft listing.",
    "languages": ["Hindi", "English"],
    "hoursType": "standard",
    "homeVisits": True,
    "whatsapp": True,
    "prices": {},
    "photos": [],
    "healthcare": None,
    "status": "draft",
    "isSponsored": False,
})

# 4. Translations
i18n = {
    "en": {
        "appName": "LocalSaathi",
        "tagline": "Find trusted help near you",
        "subTagline": "Connect with verified local technicians, handymen and daily services across Mumbai.",
        "searchPlaceholder": "Search for plumber, electrician, AC repair, clinic...",
        "popularCategories": "Popular Services",
        "allCategoriesTitle": "All Services",
        "viewAllCategories": "View All",
        "sponsored": "Sponsored",
        "sponsoredDisclosure": "Promoted placement. Always verified, transparent and clearly separated.",
        "whySponsored": "Why Sponsored?",
        "whySponsoredDetail": "Local providers can optionally promote their listing to the top of relevant search results. Sponsored listings are verified just like any other provider, and organic results below are never hidden.",
        "trustedLocal": "Verified Providers Near You",
        "savedTitle": "Saved Providers",
        "noSaved": "No saved providers yet",
        "noSavedSub": "Tap the bookmark icon on any provider profile to easily find them later without an account.",
        "accountTitle": "Account & Settings",
        "changeLocation": "Change Area",
        "callNow": "Call",
        "whatsapp": "WhatsApp",
        "homeVisits": "Home visits available",
        "workshopOnly": "Workshop / Clinic visits only",
        "phoneVerified": "Phone Verified",
        "demoNotice": "Demo Profile",
        "demoDialogTitle": "Simulated Provider Contact",
        "demoDialogBody": "This is a fictional demo listing created to preview LocalSaathi. In production, tapping Call or WhatsApp opens your device's native dialler or WhatsApp chat with the verified provider.",
        "gotIt": "Understood",
        "openNow": "Open Now",
        "closed": "Closed",
        "startingFrom": "Starting from",
        "providerOnboarding": "Register as a Provider",
        "providerOnboardingSub": "One phone number = one provider account. Grow your local customer base with free listing.",
        "stepPhone": "Phone Verification",
        "stepProfile": "Business Details",
        "stepLocation": "Service Areas",
        "stepPublish": "Listing Published",
        "enterPhone": "Enter your 10-digit mobile number",
        "enterOtp": "Enter 6-digit OTP",
        "devOtpHint": "Development simulated OTP is 123456",
        "verifyOtp": "Verify & Continue",
        "businessName": "Full Name / Business Name",
        "primaryTrade": "Primary Service",
        "baseLocality": "Your Base Locality",
        "serviceLocalities": "Areas You Can Visit",
        "publishListing": "Publish Free Listing",
        "listingActive": "Your listing is now live in the directory!",
        "unsupportedCityTitle": "Coming Soon to",
        "unsupportedCityBody": "We are currently live and serving Mumbai. Other cities across Maharashtra and India are launching soon!",
        "browseMumbai": "Browse Mumbai anyway",
        "requestCity": "Notify me when launched",
        "requestSubmitted": "Thank you! We've recorded your city request.",
        "dashboardTitle": "Provider Dashboard",
        "listingStatus": "Listing Status",
        "statusActive": "Active & Visible",
        "statusPaused": "Paused (Hidden)",
        "pauseNotice": "While your listing is paused, it vanishes from public search results immediately.",
        "statViews": "Profile Views",
        "statCalls": "Call Taps",
        "statWhatsapp": "WhatsApp Taps",
        "sampleDataNotice": "Numbers shown are simulated demonstration metrics.",
        "language": "Interface Language",
        "navHome": "Home",
        "navCategories": "Categories",
        "navSaved": "Saved",
        "navAccount": "Account",
        "filters": "Filters",
        "clear": "Clear",
        "results": "results found",
        "noResults": "No matching providers found",
        "noResultsSub": "Try searching for a different trade or selecting another locality.",
        "reportListing": "Report Listing",
        "reportSuccess": "Thank you for keeping LocalSaathi safe. Listing reported for review.",
        "languagesSpoken": "Languages Spoken",
        "workingHours": "Working Hours",
        "qualification": "Provider Qualifications",
        "healthcareDisclaimer": "Qualifications are stated by the provider and not independently accredited by LocalSaathi."
    },
    "hi": {
        "appName": "लोकल साथी",
        "tagline": "अपने आस-पास भरोसेमंद मदद पाएँ",
        "subTagline": "मुंबई में सत्यापित तकनीशियनों, कामगारों और दैनिक सेवाओं से सीधे जुड़ें।",
        "searchPlaceholder": "प्लंबर, इलेक्ट्रीशियन, एसी रिपेयर, क्लिनिक खोजें...",
        "popularCategories": "लोकप्रिय सेवाएँ",
        "allCategoriesTitle": "सभी सेवाएँ",
        "viewAllCategories": "सभी देखें",
        "sponsored": "प्रायोजित",
        "sponsoredDisclosure": "प्रायोजित सूची। हमेशा सत्यापित और स्पष्ट रूप से अलग।",
        "whySponsored": "प्रायोजित क्यों?",
        "whySponsoredDetail": "स्थानीय कारीगर अपने विज्ञापन को ऊपर दिखा सकते हैं। वे सामान्य सेवा प्रदाताओं की तरह ही पूरी तरह सत्यापित हैं।",
        "trustedLocal": "आपके क्षेत्र में भरोसेमंद साथी",
        "savedTitle": "सहेजे गए साथी",
        "noSaved": "कोई सहेजा हुआ साथी नहीं",
        "noSavedSub": "बिना अकाउंट बनाए आसानी से खोजने के लिए किसी भी प्रोफाइल पर बुकमार्क दबाएँ।",
        "accountTitle": "खाता और सेटिंग्स",
        "changeLocation": "इलाका बदलें",
        "callNow": "कॉल करें",
        "whatsapp": "व्हाट्सएप",
        "homeVisits": "घर पर सेवा उपलब्ध",
        "workshopOnly": "केवल दुकान / क्लिनिक पर",
        "phoneVerified": "फ़ोन सत्यापित",
        "demoNotice": "डेमो प्रोफाइल",
        "demoDialogTitle": "डेमो संपर्क सूचना",
        "demoDialogBody": "यह लोकल साथी का काल्पनिक डेमो प्रोफाइल है। प्रोडक्शन में कॉल या व्हाट्सएप सीधे आपके फ़ोन के डायलर या ऐप को खोलता है।",
        "gotIt": "समझ गया",
        "openNow": "अभी खुला है",
        "closed": "बंद है",
        "startingFrom": "न्यूनतम शुल्क",
        "providerOnboarding": "कारीगर / सेवा प्रदाता के रूप में जुड़ें",
        "providerOnboardingSub": "एक फ़ोन नंबर = एक खाता। मुफ़्त में अपनी दुकान और सेवा पंजीकृत करें।",
        "stepPhone": "फ़ोन सत्यापन",
        "stepProfile": "काम की जानकारी",
        "stepLocation": "कार्य क्षेत्र",
        "stepPublish": "पंजीकरण संपन्न",
        "enterPhone": "अपना 10 अंकों का मोबाइल नंबर दर्ज करें",
        "enterOtp": "6 अंकों का OTP दर्ज करें",
        "devOtpHint": "डेवलपमेंट डेमो OTP: 123456",
        "verifyOtp": "सत्यापित करें और आगे बढ़ें",
        "businessName": "नाम / दुकान का नाम",
        "primaryTrade": "मुख्य काम / पेशा",
        "baseLocality": "आपका मुख्य इलाका",
        "serviceLocalities": "आप जिन इलाकों में जा सकते हैं",
        "publishListing": "निःशुल्क प्रोफ़ाइल प्रकाशित करें",
        "listingActive": "आपकी प्रोफ़ाइल अब डायरेक्टरी में लाइव है!",
        "unsupportedCityTitle": "जल्द आ रहा है",
        "unsupportedCityBody": "हम अभी मुंबई से शुरू कर रहे हैं। आपके शहर में सेवा जल्द शुरू होगी!",
        "browseMumbai": "फिर भी मुंबई देखें",
        "requestCity": "शुरू होने पर मुझे सूचित करें",
        "requestSubmitted": "धन्यवाद! हमने आपका अनुरोध दर्ज कर लिया है।",
        "dashboardTitle": "कारीगर डैशबोर्ड",
        "listingStatus": "प्रोफ़ाइल स्थिति",
        "statusActive": "सक्रिय (ग्राहकों को दिखाई दे रहा है)",
        "statusPaused": "रोकी गई (छिपी हुई)",
        "pauseNotice": "जब प्रोफ़ाइल रोकी जाती है, तो यह तुरंत खोज से गायब हो जाती है।",
        "statViews": "प्रोफ़ाइल व्यूज़",
        "statCalls": "कॉल अनुरोध",
        "statWhatsapp": "व्हाट्सएप संदेश",
        "sampleDataNotice": "दिखाए गए आंकड़े डेमो प्रदर्शन के लिए हैं।",
        "language": "भाषा चुनें",
        "navHome": "होम",
        "navCategories": "श्रेणियाँ",
        "navSaved": "सहेजे गए",
        "navAccount": "खाता",
        "filters": "फ़िल्टर",
        "clear": "हटाएँ",
        "results": "परिणाम मिले",
        "noResults": "कोई सेवा प्रदाता नहीं मिला",
        "noResultsSub": "कृपया दूसरा काम खोजें या अन्य इलाका चुनें।",
        "reportListing": "शिकायत दर्ज करें",
        "reportSuccess": "धन्यवाद! आपकी रिपोर्ट समीक्षा के लिए भेज दी गई है।",
        "languagesSpoken": "बोली जाने वाली भाषाएँ",
        "workingHours": "कार्य समय",
        "qualification": "योग्यता",
        "healthcareDisclaimer": "योग्यताएँ प्रदाता द्वारा घोषित हैं और लोकल साथी द्वारा अलग से प्रमाणित नहीं हैं।"
    },
    "mr": {
        "appName": "लोकल साथी",
        "tagline": "तुमच्या जवळचे विश्वासू मदतनीस शोधा",
        "subTagline": "मुंबईतील पडताळणी झालेले तंत्रज्ञ, कारागीर आणि घरगुती सेवा देणाऱ्यांशी थेट संपर्क साधा.",
        "searchPlaceholder": "प्लंबर, इलेक्ट्रिशियन, एसी दुरुस्ती, क्लिनिक शोधा...",
        "popularCategories": "लोकप्रिय सेवा",
        "allCategoriesTitle": "सर्व सेवा",
        "viewAllCategories": "सर्व पहा",
        "sponsored": "प्रायोजित",
        "sponsoredDisclosure": "प्रायोजित नोंदणी. नेहमी पडताळणी केलेली आणि स्पष्टपणे वेगळी.",
        "whySponsored": "प्रायोजित का?",
        "whySponsoredDetail": "स्थानिक कारागीर आपली नोंदणी वर दाखवू शकतात. ते नेहमीच्या कारागिरांप्रमाणेच पूर्ण पडताळणी झालेले असतात.",
        "trustedLocal": "तुमच्या परिसरातील विश्वासू साथी",
        "savedTitle": "जतन केलेले साथी",
        "noSaved": "कोणताही साथी जतन केलेला नाही",
        "noSavedSub": "कोणत्याही प्रोफाइलवर बुकमार्क दाबून नंतर सहज शोधण्यासाठी जतन करा (खाते उघडण्याची गरज नाही).",
        "accountTitle": "खाते आणि सेटिंग्ज",
        "changeLocation": "परिसर बदला",
        "callNow": "कॉल करा",
        "whatsapp": "व्हॉट्सॲप",
        "homeVisits": "घरी येऊन काम उपलब्ध",
        "workshopOnly": "फक्त दुकानात / क्लिनिकमध्ये",
        "phoneVerified": "फोन पडताळणी पूर्ण",
        "demoNotice": "डेमो प्रोफाइल",
        "demoDialogTitle": "डेमो संपर्क माहिती",
        "demoDialogBody": "हे लोकल साथीचे काल्पनिक डेमो प्रोफाइल आहे. प्रत्यक्ष वापरात कॉल किंवा व्हॉट्सॲप थेट तुमच्या फोनच्या डायलरमध्ये उघडेल.",
        "gotIt": "समजले",
        "openNow": "सध्या सुरू आहे",
        "closed": "बंद आहे",
        "startingFrom": "किमान दर",
        "providerOnboarding": "सेवा प्रदाता म्हणून नोंदणी करा",
        "providerOnboardingSub": "एक फोन नंबर = एक खाते. मोफत नोंदणी करा आणि नवीन ग्राहक मिळवा.",
        "stepPhone": "फोन पडताळणी",
        "stepProfile": "कामाचा तपशील",
        "stepLocation": "कार्यक्षेत्र",
        "stepPublish": "नोंदणी पूर्ण",
        "enterPhone": "तुमचा १० अंकी मोबाईल नंबर टाका",
        "enterOtp": "६ अंकी OTP टाका",
        "devOtpHint": "डेमो चाचणी OTP: 123456",
        "verifyOtp": "पडताळणी करा आणि पुढे जा",
        "businessName": "नाव / दुकानाचे नाव",
        "primaryTrade": "मुख्य काम / व्यवसाय",
        "baseLocality": "तुमचा मुख्य परिसर",
        "serviceLocalities": "तुम्ही ज्या भागात जाऊ शकता",
        "publishListing": "मोफत प्रोफाइल प्रकाशित करा",
        "listingActive": "तुमची प्रोफाइल आता डिरेक्टरीमध्ये थेट दिसेल!",
        "unsupportedCityTitle": "लवकरच येत आहे",
        "unsupportedCityBody": "आम्ही सध्या मुंबईत सुरू केले आहे. तुमच्या शहरात सेवा लवकरच सुरू होईल!",
        "browseMumbai": "तरीही मुंबई पहा",
        "requestCity": "सुरू झाल्यावर मला कळवा",
        "requestSubmitted": "धन्यवाद! आम्ही तुमची विनंती नोंदवून घेतली आहे.",
        "dashboardTitle": "कारागीर डॅशबोर्ड",
        "listingStatus": "नोंदणी स्थिती",
        "statusActive": "सक्रिय (ग्राहकांना दिसत आहे)",
        "statusPaused": "थांबवलेली (लपवलेली)",
        "pauseNotice": "नोंदणी थांबवलेली असताना शोध परिणामांमधून त्वरित गायब होते.",
        "statViews": "प्रोफाइल पाहिली",
        "statCalls": "कॉल केले",
        "statWhatsapp": "व्हॉट्सॲप संदेश",
        "sampleDataNotice": "दाखवलेली आकडेवारी डेमो प्रात्यक्षिकासाठी आहे.",
        "language": "भाषा निवडा",
        "navHome": "होम",
        "navCategories": "श्रेणी",
        "navSaved": "जतन केलेले",
        "navAccount": "खाते",
        "filters": "फिल्टर",
        "clear": "साफ करा",
        "results": "परिणाम सापडले",
        "noResults": "कोणताही सेवा प्रदाता सापडला नाही",
        "noResultsSub": "कृपया वेगळा व्यवसाय शोधा किंवा दुसरा परिसर निवडा.",
        "reportListing": "तक्रार नोंदवा",
        "reportSuccess": "धन्यवाद! तुमची तक्रार पुनरावलोकनासाठी पाठवली आहे.",
        "languagesSpoken": "बोलल्या जाणाऱ्या भाषा",
        "workingHours": "कामाची वेळ",
        "qualification": "पात्रता",
        "healthcareDisclaimer": "पात्रता प्रदात्याने सांगितलेली आहे, लोकल साथीने स्वतंत्रपणे प्रमाणित केलेली नाही."
    }
}

data = {
    "groups": groups,
    "categories": categories,
    "cities": cities,
    "localities": localities,
    "providers": providers,
    "i18n": i18n,
    "defaultCityId": "mh-mumbai",
    "defaultLocalityId": "mh-mumbai-andheri-west",
}

out_file = os.path.join(WEB_DIR, "data.js")
with open(out_file, "w", encoding="utf-8") as f:
    f.write("// LocalSaathi extracted seed data & localizations\n")
    f.write("window.LOCAL_SAATHI_DATA = " + json.dumps(data, indent=2, ensure_ascii=False) + ";\n")

print(f"Exported data to {out_file}:")
print(f"  Groups: {len(groups)}")
print(f"  Categories: {len(categories)}")
print(f"  Cities: {len(cities)}")
print(f"  Localities: {len(localities)}")
print(f"  Providers: {len(providers)}")
