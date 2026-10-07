import 'app_strings.dart';

/// Marathi strings — starter translation.
///
/// Marathi matters because the launch market is Mumbai. As with Hindi, only
/// high-traffic strings are translated; the rest fall back to English so a
/// partial translation never leaves a blank label on screen.
class AppStringsMr extends AppStrings {
  const AppStringsMr();

  @override
  String get languageCode => 'mr';
  @override
  String get languageName => 'मराठी';

  @override
  String get tagline => 'तुमच्या जवळची विश्वासार्ह मदत';
  @override
  String get continueLabel => 'पुढे';
  @override
  String get getStarted => 'सुरू करा';
  @override
  String get save => 'जतन करा';
  @override
  String get cancel => 'रद्द करा';
  @override
  String get next => 'पुढे';
  @override
  String get back => 'मागे';
  @override
  String get search => 'शोधा';
  @override
  String get clear => 'साफ करा';
  @override
  String get loading => 'लोड होत आहे…';
  @override
  String get optionalLabel => 'ऐच्छिक';
  @override
  String get comingSoon => 'लवकरच येत आहे';

  @override
  String launchAvailabilityMessageTemplate(String activeCity) =>
      'आम्ही $activeCityतून सुरुवात करत आहोत. अधिक शहरे लवकरच येत आहेत.';
  @override
  String browseActiveCityAnywayTemplate(String activeCity) =>
      'तरीही $activeCity पहा';
  @override
  String get launchAvailabilityTitle => 'तुमच्या शहरात अजून उपलब्ध नाही';
  @override
  String get requestMyCity => 'माझे शहर जोडण्याची विनंती करा';
  @override
  String get chooseCity => 'तुमचे शहर निवडा';
  @override
  String get chooseLocality => 'तुमचा परिसर निवडा';
  @override
  String get changeLocation => 'ठिकाण बदला';
  @override
  String get stateLabel => 'राज्य / केंद्रशासित प्रदेश';
  @override
  String get cityLabel => 'शहर';
  @override
  String get localityLabel => 'परिसर';

  @override
  String get welcomeTitle => 'स्थानिक मदत, एका टॅपवर';
  @override
  String get welcomeBody =>
      'प्लंबर, इलेक्ट्रिशियन, स्वच्छता कर्मचारी, शिक्षक आणि दवाखाने जवळ शोधा. साइन-अप न करता पहा.';
  @override
  String get iOfferServices => 'मी सेवा देतो/देते';

  @override
  String get navHome => 'मुख्यपृष्ठ';
  @override
  String get navCategories => 'श्रेणी';
  @override
  String get navSaved => 'जतन केलेले';
  @override
  String get navAccount => 'खाते';
  @override
  String get searchHint => 'सेवा किंवा व्यावसायिक शोधा';
  @override
  String get popularCategories => 'लोकप्रिय श्रेणी';
  @override
  String get viewAllCategories => 'सर्व श्रेणी पहा';
  @override
  String get providersNearYou => 'तुमच्या परिसरात सेवा देणारे';
  @override
  String get sponsored => 'प्रायोजित';
  @override
  String get listYourServices => 'तुमच्या सेवा नोंदवा';
  @override
  String get inviteServiceProvider => 'सेवा देणाऱ्याला आमंत्रित करा';

  @override
  String get filters => 'गाळण्या';
  @override
  String get filterLocality => 'परिसर';
  @override
  String get filterCategory => 'सेवा श्रेणी';
  @override
  String get filterOpenNow => 'आता सुरू आहे';
  @override
  String get filterHomeVisits => 'घरी सेवा उपलब्ध';
  @override
  String get openNow => 'आता सुरू आहे';
  @override
  String get closedNow => 'आता बंद आहे';
  @override
  String get homeVisitsAvailable => 'घरी सेवा उपलब्ध';

  @override
  String get callNow => 'कॉल करा';
  @override
  String get share => 'शेअर करा';
  @override
  String get report => 'तक्रार करा';
  @override
  String get saveProvider => 'जतन करा';
  @override
  String get verifiedPhoneLabel => 'फोन सत्यापित';
  @override
  String get verifiedCredentialsLabel => 'पात्रता सत्यापित';

  @override
  String get aboutProvider => 'माहिती';
  @override
  String get servicesOffered => 'दिल्या जाणाऱ्या सेवा';
  @override
  String get areasServed => 'सेवा क्षेत्र';
  @override
  String get languagesSpoken => 'बोलल्या जाणाऱ्या भाषा';
  @override
  String get workingHours => 'कामाची वेळ';
  @override
  String get photos => 'फोटो';

  @override
  String get savedTitle => 'जतन केलेले प्रोव्हायडर';
  @override
  String get savedEmptyTitle => 'अजून काही जतन केलेले नाही';
  @override
  String get accountTitle => 'खाते';
  @override
  String get selectedLocation => 'निवडलेले ठिकाण';
  @override
  String get languagePreference => 'भाषा';
  @override
  String get providerSignIn => 'प्रोव्हायडर साइन-इन';
  @override
  String get helpAndSupport => 'मदत';
  @override
  String get privacyPolicy => 'गोपनीयता धोरण';
  @override
  String get termsOfUse => 'वापराच्या अटी';

  @override
  String get phoneNumberLabel => 'फोन नंबर';
  @override
  String get sendOtp => 'कोड पाठवा';
  @override
  String get verifyOtp => 'सत्यापित करा';
  @override
  String get resendOtp => 'कोड पुन्हा पाठवा';
  @override
  String get otpRateLimited =>
      'खूप जास्त कोड मागवले गेले. पुन्हा मागण्यापूर्वी थोडा वेळ थांबा.';
  @override
  String otpResendInTemplate(int seconds) =>
      'तुम्ही $seconds सेकंदांत नवीन कोड मागू शकता.';
  @override
  String get otpResendWaitingLabel => 'थोड्या वेळाने कोड पुन्हा पाठवता येईल';
  @override
  String get otpDelayedHelp =>
      'SMS द्वारे कोड येण्यास काही मिनिटे लागू शकतात. ही स्क्रीन उघडी ठेवा; प्रतीक्षा संपल्यावर नवीन कोड मागू शकता.';
  @override
  String get otpPasteHint => '6 अंकी कोड टाइप करा किंवा पेस्ट करा.';
  @override
  String get reauthRequired =>
      'तुमच्या सुरक्षिततेसाठी, हे करण्यापूर्वी नवीन कोडने खात्री करा.';
  @override
  String get sessionExpired =>
      'तुम्ही साइन आउट झाला आहात. पुढे जाण्यासाठी पुन्हा साइन इन करा; तुमचा मसुदा जपून ठेवला आहे.';
  @override
  String get listingSuspendedNotice =>
      'ही लिस्टिंग निलंबित आहे. तुम्ही साइन इन करू शकता, पण पुनरावलोकनापर्यंत ती प्रकाशित करता येणार नाही.';
  @override
  String get otpLabel => 'वन-टाइम कोड';
  @override
  String get duplicateNumberMessage =>
      'या नंबरचे प्रोफाइल आधीच आहे. साइन इन करण्यासाठी ते सत्यापित करा.';

  @override
  String get publishListing => 'माझी लिस्टिंग प्रकाशित करा';
  @override
  String get editProfile => 'प्रोफाइल संपादित करा';
  @override
  String get growYourBusiness => 'तुमचा व्यवसाय वाढवा';
  @override
  String get pricingComingSoon => 'किंमत लवकरच येत आहे';
  @override
  String get dashboardTitle => 'तुमची लिस्टिंग';
  @override
  String get listingStatus => 'लिस्टिंग स्थिती';
  @override
  String get statusPublished => 'प्रकाशित';
  @override
  String get statusPaused => 'थांबवलेले';
  @override
  String get statusDraft => 'मसुदा';
  @override
  String get pauseListing => 'लिस्टिंग थांबवा';
  @override
  String get resumeListing => 'लिस्टिंग पुन्हा सुरू करा';
}
