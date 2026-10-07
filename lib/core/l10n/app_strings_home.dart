part of 'app_strings.dart';

/// Strings for the customer-facing discovery surfaces.
///
/// Implemented as extension getters on [AppStrings] so the `part` file can add
/// copy without every locale subclass having to redeclare the full interface.
extension HomeStringsX on AppStrings {
  String get localityAndCityContext => 'Showing providers serving';
  String get sponsoredDisclosure =>
      'Sponsored placements are paid for by the provider and are always labelled.';
  String get categoryPickerTitle => 'Choose a service category';
  String get noProvidersInAreaTitle => 'No providers here yet';
  String get noProvidersInAreaBody =>
      'We are adding more providers in this locality every week. Try a nearby locality or another service.';
  String get popularInArea => 'Popular in';
  String get seeAllCategoriesHint => 'Browse every service category';

  // Design blueprint: home.
  String get servingArea => 'Serving area';
  String get liveArea => 'Live area';
  String get whatDoYouNeed => 'What do you need help with?';
  String providersInLocality(String locality) => 'Providers in $locality';
  // Phone verification only: never imply a professional check (phase 002).
  String get verifiedAndActive => 'Phone-verified & active';
  String get promotedByProvider => 'Promoted by the provider';
  String servesMoreAreas(int n) =>
      n == 1 ? 'serves 1 more area' : 'serves $n more areas';
  String get indicativeRate => 'Indicative rate';
  String get startingFromLabel => 'Starting from';
  String get offerServiceTitle => 'Offer a local service?';
  String get offerServiceBody =>
      'Create your free listing and get calls straight from your neighbours. No commission, no middlemen.';
  String get createFreeListing => 'Create free listing';
  String get knowHelperTitle => 'Know a reliable helper?';
  String get knowHelperBody =>
      'Invite them so your neighbourhood can find them too.';
  String get invite => 'Invite';
  String providersNearbyCount(int n) =>
      n == 1 ? '1 provider nearby' : '$n providers nearby';

  // Design blueprint: welcome.
  String get welcomeTagline => 'Find local help, nearby.';
  String get welcomeHeadline => 'Find the right help near you';
  String get welcomeSubhead =>
      'Connect directly with plumbers, electricians, mechanics and other local professionals in your neighbourhood. Every listed number is phone-confirmed.';
  String providersListedIn(int n, String city) =>
      n == 1 ? '1 provider listed in $city' : '$n providers listed in $city';
  String get directDiscovery => 'Direct contact · zero commission';
  String get chooseYourArea => 'Choose your area';
  String get activeCity => 'Active city';
  String get findServices => 'Find services';
  String get orLabel => 'or';
  String get areYouProTitle => 'Are you a service professional?';
  String get areYouProBody =>
      'List your work for free and get direct calls from customers nearby.';
  String get offerServicesCta => 'I offer services: create listing';
  String get browseNoSignIn =>
      'No sign-in needed to browse · Direct phone and WhatsApp contact';

  // Design blueprint: categories and search.
  String servicesCount(int n) => n == 1 ? '1 service' : '$n services';
  String get cantFindWorkerTitle => "Can't find a specific worker?";
  String get cantFindWorkerBody =>
      'Invite a local worker you trust so others nearby can reach them too.';
  String resultsServing(int n, String locality) =>
      n == 1 ? '1 provider serving $locality' : '$n providers serving $locality';
  String get cantFindRegularTitle => "Can't find your regular technician?";
  String get cantFindRegularBody =>
      'Invite trusted local pros to LocalSaathi and help your neighbourhood find good help.';

  // Design blueprint: provider profile.
  String detailsUpdated(String date) => 'Details updated $date';
  String get speaksLabel => 'Speaks';
  String get servesLabel => 'Serves';
  String get chargesTitle => 'Visit & charges';
  String get providerDetails => 'Provider details';

  // Map.
  String get locationTitle => 'Location';
  String get mapSharedByProvider =>
      'Shown because the provider chose to share their business location.';
  String get getDirections => 'Get directions';
  String approximateAreaNote(String locality) =>
      'Approximate service area around $locality (darker) and the other areas they serve. The exact address is never shown; ask the provider when you call.';
  String get showMap => 'Show map';
  String get showList => 'Show list';
  String onMapCount(int onMap, int total) => onMap == total
      ? '$onMap on the map'
      : '$onMap of $total on the map · others list only';
  String get viewProfile => 'View profile';

  // Legal.
  String get legalDraftNotice =>
      'Draft pending legal review. The bracketed details are filled in before launch.';
  String get effectiveLabel => 'Effective';
  String get openSourceLicences => 'Open-source licences';
  String get mapDataCredit => 'Map data © OpenStreetMap contributors';
  String get legalAgreementLine =>
      'By using LocalSaathi you agree to the Terms of Use and Privacy Policy.';
  String get acceptTermsTitle =>
      'I am 18 or older and agree to the Terms of Use and Privacy Policy';
  String get acceptTermsRequired =>
      'Please accept the Terms of Use and Privacy Policy to publish.';
  String get grievanceRedressal => 'Grievance redressal';
  String get verificationTitle => 'Verification';
  String get zeroCommission =>
      'LocalSaathi charges 0% commission. You contact the provider directly.';
}

/// Strings for the provider-facing surfaces.
extension ProviderStringsX on AppStrings {
  String get providerSpaceTitle => 'Provider space';
  String get providerSpaceBody =>
      'Only service providers can add their own contact details to LocalSaathi. Sign in with the phone number you want customers to call.';
  String get oneNumberOneProfile =>
      'One verified phone number is one provider account and one public profile.';
  String get addMoreServicesHint =>
      'Offer more than one service? Select extra categories on the same profile instead of creating a second listing.';
  String get changeNumberHint =>
      'Changing your registered number requires verifying the new number and a uniqueness check.';
  String get listingPausedExplainer =>
      'While your listing is paused it is hidden from customers. Your profile and statistics are kept.';
  String get oneNumberOneProfileStrong =>
      'Each phone-verified number can hold exactly one public profile.';
  String get whatsappSeparateConsent =>
      'WhatsApp visibility is a separate choice from showing your phone number.';
  String get homeBasedPrivacyTitle => 'Home-based providers';
  String get homeBasedPrivacyBody =>
      'LocalSaathi shows the locality you serve, never your street address. Do not enter your house number or flat number.';
  String get dashboardEngagementNote =>
      'These numbers count button taps inside the app. A tap does not mean the customer called, messaged, hired or paid you.';
  String get subscriptionDisclaimer =>
      'A subscription buys extra visibility features only. It never changes your verification labels and does not guarantee enquiries or jobs.';
  String get medicalDisclaimer =>
      'LocalSaathi is a contact directory only. We do not provide diagnosis, treatment or emergency services.';
}
