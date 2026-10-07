import 'app_strings.dart';

/// Hindi strings — starter translation.
///
/// Only the highest-traffic customer strings are translated here. Anything not
/// overridden falls back to English, so the app stays fully usable while the
/// translation is finished. Hand this file to a translator: the list of
/// untranslated keys is simply the getters not overridden below.
class AppStringsHi extends AppStrings {
  const AppStringsHi();

  @override
  String get languageCode => 'hi';
  @override
  String get languageName => 'हिन्दी';

  @override
  String get tagline => 'अपने आस-पास भरोसेमंद मदद पाएँ';
  @override
  String get continueLabel => 'आगे बढ़ें';
  @override
  String get getStarted => 'शुरू करें';
  @override
  String get save => 'सहेजें';
  @override
  String get cancel => 'रद्द करें';
  @override
  String get next => 'आगे';
  @override
  String get back => 'पीछे';
  @override
  String get search => 'खोजें';
  @override
  String get clear => 'हटाएँ';
  @override
  String get loading => 'लोड हो रहा है…';
  @override
  String get optionalLabel => 'वैकल्पिक';
  @override
  String get comingSoon => 'जल्द आ रहा है';

  @override
  String launchAvailabilityMessageTemplate(String activeCity) =>
      'हम $activeCity से शुरू कर रहे हैं। और शहर जल्द आ रहे हैं।';
  @override
  String browseActiveCityAnywayTemplate(String activeCity) =>
      'फिर भी $activeCity देखें';
  @override
  String get launchAvailabilityTitle => 'आपके शहर में अभी उपलब्ध नहीं';
  @override
  String get requestMyCity => 'मेरा शहर जोड़ने का अनुरोध करें';
  @override
  String get chooseCity => 'अपना शहर चुनें';
  @override
  String get chooseLocality => 'अपना इलाका चुनें';
  @override
  String get changeLocation => 'स्थान बदलें';
  @override
  String get stateLabel => 'राज्य / केंद्र शासित प्रदेश';
  @override
  String get cityLabel => 'शहर';
  @override
  String get localityLabel => 'इलाका';

  @override
  String get welcomeTitle => 'स्थानीय मदद, बस एक टैप दूर';
  @override
  String get welcomeBody =>
      'प्लंबर, इलेक्ट्रिशियन, सफ़ाई कर्मचारी, ट्यूटर और क्लिनिक अपने आस-पास खोजें। बिना साइन-अप के देखें।';
  @override
  String get iOfferServices => 'मैं सेवाएँ देता/देती हूँ';

  @override
  String get navHome => 'होम';
  @override
  String get navCategories => 'श्रेणियाँ';
  @override
  String get navSaved => 'सहेजे गए';
  @override
  String get navAccount => 'खाता';
  @override
  String get searchHint => 'सेवा या पेशेवर खोजें';
  @override
  String get popularCategories => 'लोकप्रिय श्रेणियाँ';
  @override
  String get viewAllCategories => 'सभी श्रेणियाँ देखें';
  @override
  String get providersNearYou => 'आपके इलाके में सेवा देने वाले';
  @override
  String get sponsored => 'प्रायोजित';
  @override
  String get listYourServices => 'अपनी सेवाएँ दर्ज करें';
  @override
  String get inviteServiceProvider => 'सेवा देने वाले को आमंत्रित करें';

  @override
  String get filters => 'फ़िल्टर';
  @override
  String get filterLocality => 'इलाका';
  @override
  String get filterCategory => 'सेवा श्रेणी';
  @override
  String get filterOpenNow => 'अभी खुला है';
  @override
  String get filterHomeVisits => 'घर पर सेवा उपलब्ध';
  @override
  String get openNow => 'अभी खुला है';
  @override
  String get closedNow => 'अभी बंद है';
  @override
  String get homeVisitsAvailable => 'घर पर सेवा उपलब्ध';

  @override
  String get callNow => 'कॉल करें';
  @override
  String get share => 'शेयर करें';
  @override
  String get report => 'रिपोर्ट करें';
  @override
  String get saveProvider => 'सहेजें';
  @override
  String get verifiedPhoneLabel => 'फ़ोन सत्यापित';
  @override
  String get verifiedCredentialsLabel => 'योग्यता सत्यापित';

  @override
  String get aboutProvider => 'परिचय';
  @override
  String get servicesOffered => 'दी जाने वाली सेवाएँ';
  @override
  String get areasServed => 'सेवा क्षेत्र';
  @override
  String get languagesSpoken => 'बोली जाने वाली भाषाएँ';
  @override
  String get workingHours => 'कार्य समय';
  @override
  String get photos => 'फ़ोटो';

  @override
  String get savedTitle => 'सहेजे गए प्रोवाइडर';
  @override
  String get savedEmptyTitle => 'अभी कुछ सहेजा नहीं गया';
  @override
  String get accountTitle => 'खाता';
  @override
  String get selectedLocation => 'चुना गया स्थान';
  @override
  String get languagePreference => 'भाषा';
  @override
  String get providerSignIn => 'प्रोवाइडर साइन-इन';
  @override
  String get helpAndSupport => 'सहायता';
  @override
  String get privacyPolicy => 'गोपनीयता नीति';
  @override
  String get termsOfUse => 'उपयोग की शर्तें';

  @override
  String get phoneNumberLabel => 'फ़ोन नंबर';
  @override
  String get sendOtp => 'कोड भेजें';
  @override
  String get verifyOtp => 'सत्यापित करें';
  @override
  String get resendOtp => 'कोड फिर भेजें';
  @override
  String get otpLabel => 'वन-टाइम कोड';
  @override
  String get duplicateNumberMessage =>
      'इस नंबर का प्रोफ़ाइल पहले से है। साइन इन करने के लिए इसे सत्यापित करें।';

  @override
  String get publishListing => 'मेरी लिस्टिंग प्रकाशित करें';
  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';
  @override
  String get growYourBusiness => 'अपना व्यवसाय बढ़ाएँ';
  @override
  String get pricingComingSoon => 'मूल्य निर्धारण जल्द आ रहा है';
  @override
  String get dashboardTitle => 'आपकी लिस्टिंग';
  @override
  String get listingStatus => 'लिस्टिंग स्थिति';
  @override
  String get statusPublished => 'प्रकाशित';
  @override
  String get statusPaused => 'रोका गया';
  @override
  String get statusDraft => 'ड्राफ़्ट';
  @override
  String get pauseListing => 'लिस्टिंग रोकें';
  @override
  String get resumeListing => 'लिस्टिंग फिर चालू करें';
}
