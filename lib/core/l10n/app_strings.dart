import 'package:flutter/widgets.dart';

part 'app_strings_home.dart';
part 'app_strings_provider.dart';

/// Interface strings for the whole app.
///
/// Every user-visible string lives in this library (or in one of its `part`
/// files). Screens never inline copy, which is what keeps the app ready for
/// Hindi, Marathi and other Indian languages.
///
/// English is the reference locale and is implemented directly on this class,
/// so a new language only overrides the strings it has translated and inherits
/// English for the rest. That is deliberate: a partial translation degrades
/// gracefully instead of breaking the build or showing blanks, which matters
/// for an app that will grow across many Indian languages.
///
/// To add a language:
///   1. Create `app_strings_<code>.dart` extending [AppStrings].
///   2. Override [languageCode], [languageName] and the strings you have.
///   3. Add the class to `AppLocalizations.supportedStrings`.
class AppStrings {
  const AppStrings();

  /// BCP-47 language code, e.g. `en`, `hi`, `mr`.
  String get languageCode => 'en';

  /// Endonym shown in the language picker, e.g. `हिन्दी`.
  String get languageName => 'English';

  /// The interface locale this bundle serves.
  ///
  /// Declared here so this library owns the contract it documents, and so the
  /// dependency on `flutter/widgets` is a real one rather than incidental.
  /// [AppStringsEn] and its siblings may override it; a bundle that does not
  /// gets a locale derived from [languageCode] by `AppLocalizations`.
  Locale get locale => Locale(languageCode);

  // ---------------------------------------------------------------- generic
  String get appName => 'LocalSaathi';
  String get tagline => 'Find trusted help near you';
  String get continueLabel => 'Continue';
  String get getStarted => 'Get started';
  String get skip => 'Skip';
  String get save => 'Save';
  String get saveChanges => 'Save changes';
  String get cancel => 'Cancel';
  String get close => 'Close';
  String get done => 'Done';
  String get next => 'Next';
  String get back => 'Back';
  String get edit => 'Edit';
  String get delete => 'Delete';
  String get retry => 'Try again';
  String get remove => 'Remove';
  String get add => 'Add';
  String get search => 'Search';
  String get clear => 'Clear';
  String get optionalLabel => 'Optional';
  String get requiredLabel => 'Required';
  String get yes => 'Yes';
  String get no => 'No';
  String get all => 'All';
  String get apply => 'Apply';
  String get reset => 'Reset';
  String get loading => 'Loading…';
  String get comingSoon => 'Coming soon';
  String get sampleDataLabel => 'Sample data';
  String get somethingWentWrong => 'Something went wrong. Please try again.';
  String get notSet => 'Not set';
  String get stepLabel => 'Step';
  String get stepOf => 'of';
  String get addHoursWindow => 'Add another time range';
  String get clinicAddressHelper =>
      'Clinic or practice address only. If you work from home, leave this blank — we never publish a residential address.';

  // ------------------------------------------------------- launch / location
  /// Templated so no city name is baked into reusable copy. Screens pass the
  /// name of whichever market is currently active.
  ///
  /// Renders as: "We're starting in Mumbai. More cities are coming soon."
  String launchAvailabilityMessageTemplate(String activeCity) =>
      "We're starting in $activeCity. More cities are coming soon.";

  /// Templated: "Mumbai is live. We will let you know when <city> opens."
  String activeMarketSummary(String activeCity, String requestedCity) =>
      '$activeCity is live. We will let you know when $requestedCity opens.';

  /// Templated: "Browse <city> anyway"
  String browseActiveCityAnywayTemplate(String activeCity) =>
      'Browse $activeCity anyway';

  String get launchAvailabilityTitle => 'Not in your city yet';
  String get browseActiveCityAnyway => 'Browse the live city anyway';
  String get requestMyCity => 'Request my city';
  String get requestMyCityBody =>
      'Tell us where you are. We use these requests to decide which city opens next.';
  String get requestMyCityHint => 'Your city or area';
  String get requestMyCitySubmitted =>
      'Thanks. We recorded your request for this city.';
  String get requestMyCityAlreadyRequested =>
      'You have already requested this city. We will let you know when it opens.';
  String get requestCityMockNotice =>
      'This build stores your request on this phone only. It is not sent to LocalSaathi yet. A production build posts it to the backend and feeds the market-expansion list.';
  String get chooseCity => 'Choose your city';
  String get chooseLocality => 'Choose your locality';
  String get changeLocation => 'Change location';
  String get useMyLocation => 'Use my current location';
  String get useMyLocationUnavailable =>
      'Location permission is optional in this build. Please pick your area manually.';
  String get cityNotActiveYet => 'Not active yet';
  String get stateLabel => 'State / Union Territory';
  String get cityLabel => 'City';
  String get localityLabel => 'Locality';
  String get pinCodeLabel => 'PIN code (optional)';
  String get noLocalitiesAvailable =>
      'Localities for this city are being prepared.';
  String get noDistanceDisclaimer =>
      'LocalSaathi does not show distances. Distances need exact coordinates from every provider, which we do not collect.';
  String get searchCityHint => 'Search city';
  String get activeMarkets => 'Available now';
  String get upcomingMarkets => 'Coming soon';
  String get seeUpcomingCities => 'See cities coming soon';

  // ------------------------------------------------------------- welcome
  String get welcomeTitle => 'Local help, one tap away';
  String get welcomeBody =>
      'Find plumbers, electricians, cleaners, tutors, clinics and more near you. Browse freely — no sign-up needed.';
  String get welcomePointOne => 'Search by service or locality';
  String get welcomePointTwo => 'Call or message directly';
  String get welcomePointThree => 'Save the providers you trust';
  String get iOfferServices => 'I offer services';
  String get chooseLocationToStart => 'Where do you need help?';

  // ---------------------------------------------------------------- home
  String get navHome => 'Home';
  String get navCategories => 'Categories';
  String get navSaved => 'Saved';
  String get navAccount => 'Account';
  String get languagePickerNote =>
      'Choose the language you want LocalSaathi to use. You can change this any time.';
  String get partialTranslationNotice =>
      'Partly translated — untranslated text stays in English.';
  String get searchHint => 'Search for a service or professional';
  String get popularCategories => 'Popular categories';
  String get viewAllCategories => 'View all categories';
  String get providersNearYou => 'Providers serving your area';
  String get sponsored => 'Sponsored';
  String get listYourServices => 'List your services';
  String get inviteServiceProvider => 'Invite a service provider';
  String get providerRulesTitle => 'How provider listings work';
  String get seeAll => 'See all';
  String get servingYourArea => 'Serving your area';
  String get allCategoriesTitle => 'All categories';

  // -------------------------------------------------------------- search
  String get searchResults => 'Results';
  String get searchEmptyTitle => 'Search for any local service';
  String get searchEmptyBody =>
      'Try "plumber", "AC repair", "tutor" or a locality like "Bandra".';
  String get filters => 'Filters';
  String get filterLocality => 'Locality';
  String get filterCategory => 'Service category';
  String get filterOpenNow => 'Open now';
  String get filterHomeVisits => 'Home visits available';
  String get openNowFilterNote =>
      'Only providers who have shared working hours can match this filter.';
  String get openNow => 'Open now';
  String get closedNow => 'Closed now';
  String get openingHoursUnknown => 'Working hours not provided';
  String get openingHoursUnknownShort => 'Hours not provided';
  String get homeVisitsAvailable => 'Home visits available';
  String get noHomeVisits => 'At provider location';
  String get resultsCount => 'results';
  String get noProvidersForFilters => 'No providers match your filters.';
  String get clearFilters => 'Clear filters';
  String get searchByServiceNameArea =>
      'Search by service, business name or locality';
  String get recentSearches => 'Recent searches';
  String get noCategoriesMatch => 'No categories match your search.';

  // ------------------------------------------------------- provider card
  String get callNow => 'Call';
  String get whatsapp => 'WhatsApp';
  String get share => 'Share';
  String get report => 'Report';
  String get saveProvider => 'Save';
  String get removeFromSaved => 'Remove from saved';
  String get savedConfirmation => 'Saved to your list';
  String get removedFromSaved => 'Removed from saved';
  String get verifiedPhoneLabel => 'Phone verified';
  String get verifiedCredentialsLabel => 'Credentials verified';
  String get notVerifiedLabel => 'Not verified';
  String get phoneVerifiedExplainer =>
      'Phone verified means this person confirmed control of the phone number. It is not a background check.';
  String get credentialsVerifiedExplainer =>
      'Credentials verified means professional documents passed a separate review. Phone verification alone never confirms a qualification.';
  String get claimsCredentialsLabel => 'Registration details provided';
  String get learnMoreShortLabel => 'What this means';
  String get verificationExplainerTitle => 'What our labels mean';
  String get verificationExplainerConsentNote =>
      'Labels describe verification of a phone number or of documents. They are never sold, and a paid placement never changes them.';

  // ----------------------------------------------------- provider profile
  String get aboutProvider => 'About';
  String get servicesOffered => 'Services offered';
  String get areasServed => 'Areas served';
  String get baseLocality => 'Base locality';
  String get languagesSpoken => 'Languages spoken';
  String get workingHours => 'Working hours';
  String get homeVisits => 'Home visits';
  String get startingPrices => 'Indicative starting prices';
  String get startingFrom => 'from';
  String get photos => 'Photos';
  String get credentials => 'Professional details';
  String get qualificationLabel => 'Qualification';
  String get specialtyLabel => 'Specialty';
  String get clinicNameLabel => 'Clinic / practice name';
  String get clinicAddressLabel => 'Clinic address';
  String get consultationHoursLabel => 'Consultation hours';
  String get professionalRegistrationLabel => 'Professional registration';
  String get registrationNumberLabel => 'Registration number';
  String get registrationCouncilLabel => 'Council / board';
  String get registrationNotProvided => 'Not provided';
  String get profileNotFound => 'Provider not found';
  String get profileUnavailable => 'This listing is not available';
  String get profileUnavailableBody =>
      'The provider paused or removed this listing. Browse other providers in your area.';
  String get shareProfileMessage => 'Check out this provider on LocalSaathi';
  String get contactNumberHidden =>
      'The provider has not shared a contact number.';
  String get contactNumberHiddenShort => 'No number shared';
  String get whatsappUnavailable => 'WhatsApp not enabled';
  String get dialerNotWired =>
      'Calling is not wired in this build. A production build opens the Android dialer with the provider\'s number.';
  String get whatsappNotWired =>
      'WhatsApp is not wired in this build. A production build opens WhatsApp only when the provider enabled it.';
  String get demoProfileNoticeTitle => 'Demo profile';
  String get demoProfileNotice =>
      'This is a demo profile with a masked number. No real person will be contacted.';
  String get profilePhotoOf => 'Photo of';
  String get similarProvidersTitle => 'Other providers nearby';
  String get doesNotServeYourArea =>
      'This provider does not list your selected locality as a service area.';
  String get localityOnlyPrivacyNote =>
      'Only localities are shown. LocalSaathi never publishes a provider\'s home address.';
  String get hoursIndicatorNote =>
      'Hours are set by the provider and are indicative, not a booking or a guarantee that they are free right now.';
  String get whatsappNotEnabledNote =>
      'This provider has not enabled WhatsApp. Calls only.';
  String get healthcareDirectoryOnlyNotice =>
      'LocalSaathi is a directory. We do not provide diagnosis, treatment advice or emergency services. In an emergency, contact local emergency services.';
  String get availabilityLabel => 'Availability';
  String get availabilityAvailable => 'Available this week';
  String get availabilityBusy => 'Busy right now';
  String get availabilityUnavailable => 'Not taking work';

  // ------------------------------------------------------------ favourites
  String get savedTitle => 'Saved providers';
  String get savedEmptyTitle => 'Nothing saved yet';
  String get savedEmptyBody =>
      'Tap the bookmark on any provider to keep them here for later.';
  String get savedExplainer =>
      'Saved providers stay on this phone. No account needed.';
  String get browseProviders => 'Browse providers';

  // ------------------------------------------------------------- account
  String get accountTitle => 'Account';
  String get languagePreferenceSubtitle =>
      'Hindi and Marathi translations are partly complete; anything not yet translated stays in English.';
  String get legalSectionTitle => 'Legal';
  String get communityGuidelinesTitle => 'Community guidelines';
  String get helpAndSupportBody =>
      'Tell us what went wrong and we will look at it. For anything involving a specific listing, use the Report action on that profile so we have the reference.';
  String get aboutBody =>
      'LocalSaathi helps people across India find and contact local service providers. We started in Mumbai and are opening more cities. Browsing and basic provider listings are free.';
  String get accountFooterNote =>
      'LocalSaathi is a discovery and contact directory. Payments, bookings and in-app chat are not part of this build.';
  String get selectedLocation => 'Selected location';
  String get languagePreference => 'Language';
  String get providerSignIn => 'Provider sign-in';
  String get providerSignInSubtitle =>
      'List your services and manage your own profile';
  String get helpAndSupport => 'Help and support';
  String get privacyPolicy => 'Privacy policy';
  String get termsOfUse => 'Terms of use';
  String get reportAProblem => 'Report a problem';
  String get deleteAccount => 'Delete my account';
  String get deleteAccountConfirmTitle => 'Delete your provider account?';
  String get deleteAccountConfirmBody =>
      'Your public listing, profile and statistics will be removed. This cannot be undone. Saved providers on this phone are not affected.';
  String get deleteAccountDone => 'Your provider account was deleted.';
  String get aboutApp => 'About LocalSaathi';
  String get versionLabel => 'Version';
  String get guestLabel => 'Browsing as guest';
  String get guestExplainer =>
      'You can browse and save providers without an account. Only providers sign in.';
  String get signedInAsProvider => 'Signed in as provider';
  String get openProviderDashboard => 'Open provider dashboard';

  // ---------------------------------------------------------- invite flow
  String get inviteTitle => 'Invite a service provider';
  String get inviteBody =>
      'Only providers can add their own number, so we cannot list someone on their behalf. Send them an invite instead.';
  String get inviteMessage =>
      'Namaste! I use LocalSaathi to find local service providers. You can list your services free and customers can call you directly. Join here: ';
  String get inviteMessagePreviewTitle => 'Message that will be sent';
  String get inviteOpenShareSheet => 'Open share sheet';
  String get inviteConsentNote =>
      'We never add someone to the directory on their behalf. The provider creates and owns their own listing, and verifies their own number.';
  String get inviteWhatTheyGetTitle => 'What the provider gets';
  String get inviteBenefitProfile =>
      'A free public profile with their services, areas and working hours';
  String get inviteBenefitCalls =>
      'Customers call or message them directly, with no commission';
  String get inviteBenefitControl =>
      'Full control: they can edit, pause or delete the listing at any time';
  String get inviteFreeNote =>
      'Listing is free in this build. Paid visibility options are shown to providers as a preview only, and are always labelled Sponsored.';

  // ------------------------------------------------------------- reports
  String get reportTitle => 'Report this listing';
  String get reportReasonWrongNumber => 'Wrong phone number';
  String get reportReasonWrongDetails => 'Incorrect details';
  String get reportReasonClosed => 'No longer in business';
  String get reportReasonSpam => 'Spam or misleading';
  String get reportReasonOther => 'Something else';
  String get reportDetailsHint => 'Add details (optional)';
  String get reportSubmitted =>
      'Thanks. Our team will review this listing. Customers cannot edit provider information.';
  String get reportNoteForCustomers =>
      'Reports go to the LocalSaathi review queue. You cannot change someone else\'s listing.';
  String get reportChooseReason => 'Choose a reason';

  // ------------------------------------------------ provider auth / otp
  String get providerAuthTitle => 'Provider sign-in';
  String get providerAuthBody =>
      'Enter the phone number customers should call. We will send a one-time code to verify it is yours.';
  String get phoneNumberLabel => 'Phone number';
  String get phoneNumberHint => '10-digit mobile number';
  String get sendOtp => 'Send code';
  String get enterOtpTitle => 'Enter the code';
  String get enterOtpBody => 'Enter the 6-digit code we sent to your number.';
  String get otpLabel => 'One-time code';
  String get verifyOtp => 'Verify and continue';
  String get resendOtp => 'Resend code';
  String get changeNumber => 'Change number';
  String get otpSentTo => 'Code sent to';
  String get otpInvalid => 'That code is not correct. Please try again.';
  String get otpExpired => 'This code has expired. Request a new one.';
  String get otpAttemptsExceeded =>
      'Too many wrong attempts. Request a new code.';
  String get otpResent => 'A new code was sent.';
  String get otpRateLimited =>
      'Too many codes requested. Please wait a little before asking again.';
  String otpResendInTemplate(int seconds) =>
      'You can ask for a new code in $seconds seconds.';
  String get otpResendWaitingLabel =>
      'Resend code is available after a short wait';
  String get otpDelayedHelp =>
      'Codes sent by SMS can take a few minutes. Keep this screen open; you can ask for a new code when the wait ends.';
  String get otpPasteHint => 'Type or paste the 6-digit code.';
  String get reauthRequired =>
      'For your security, confirm with a new code before doing this.';
  String get sessionExpired =>
      'You were signed out. Sign in again to continue; your draft is kept.';
  String get listingSuspendedNotice =>
      'This listing is suspended. You can sign in, but it cannot be published until it is reviewed.';
  String get invalidPhoneNumber =>
      'Enter a valid 10-digit Indian mobile number.';
  String get duplicateNumberTitle => 'This number already has a profile';
  String get duplicateNumberMessage =>
      'This number already has a profile. Verify it to sign in.';
  String get verifyToSignIn => 'Verify to sign in';
  String get developmentOtpNotice =>
      'Development build: the code is always 123456. No SMS is sent. Replace with backend OTP verification before release.';
  String get signOut => 'Sign out';
  String get signOutConfirm => 'Sign out of your provider account?';
  String get signedOut => 'Signed out.';

  // -------------------------------------------------- provider onboarding
  String get providerOnboardingTitle => 'Create your listing';
  String get stepNameTitle => 'Your name';
  String get stepCategoriesTitle => 'What do you do?';
  String get stepLocationTitle => 'Where do you work?';
  String get stepDetailsTitle => 'Describe your work';
  String get stepHoursTitle => 'Working hours';
  String get stepContactTitle => 'How customers reach you';
  String get stepPhotosTitle => 'Photos and prices';
  String get stepPreviewTitle => 'Review and publish';
  String get businessNameLabel => 'Your name or business name';
  String get businessNameHint => 'e.g. Sharma Plumbing Works';
  String get businessNameHelper =>
      'Customers see this name first. Use the name you are known by.';
  String get selectCategoriesTitle => 'Select your services';
  String get selectCategoriesBody =>
      'Choose every service you offer. One profile can cover many categories.';
  String get selectAtLeastOneCategory => 'Select at least one service.';
  String get baseCityLabel => 'Base city';
  String get baseLocalityLabel => 'Base locality';
  String get serviceAreasLabel => 'Service areas';
  String get serviceAreasBody =>
      'Customers in these localities will see your listing. Add others in the same city if you travel.';
  String get selectAtLeastOneServiceArea => 'Select at least one service area.';
  String get localityMustBeInCity =>
      'Pick a locality inside the selected city.';
  String get descriptionLabel => 'About your work';
  String get descriptionHint =>
      'What you do, how long you have worked, what customers can expect.';
  String get languagesLabel => 'Languages you speak';
  String get workingHoursTitle => 'When are you available?';
  String get workingHoursBody =>
      'Set the hours customers can expect. Days you leave closed are shown as closed.';
  String get dayMonday => 'Monday';
  String get dayTuesday => 'Tuesday';
  String get dayWednesday => 'Wednesday';
  String get dayThursday => 'Thursday';
  String get dayFriday => 'Friday';
  String get daySaturday => 'Saturday';
  String get daySunday => 'Sunday';
  String get closedAllDay => 'Closed';
  String get openAllDay => 'Open 24 hours';
  String get copyHoursToAllDays => 'Apply to all days';
  String get openingTimeLabel => 'Opens';
  String get closingTimeLabel => 'Closes';
  String get invalidTimeRange => 'Closing time must be after opening time.';
  String get contactPreferencesTitle => 'Contact preferences';
  String get consentShowPhoneTitle => 'Show my phone number to customers';
  String get consentShowPhoneBody =>
      'Required to publish. If you turn this off we cannot list your number.';
  String get consentShowPhoneRequired =>
      'Consent to display your number is required before publishing.';
  String get consentWhatsappTitle => 'Allow WhatsApp messages';
  String get consentWhatsappBody =>
      'Separate and optional. Customers will see a WhatsApp button only if you allow it.';
  String get whatsappNeedsPhoneConsent =>
      'WhatsApp needs your number consent as well.';
  String get homeVisitsToggleTitle => 'I visit customer locations';
  String get homeVisitsToggleBody =>
      'Customers can filter for providers who come to them.';
  String get photosOptionalTitle => 'Photos and prices';
  String get photosOptionalBody =>
      'Both are optional. Anything you add is shown on your public profile.';
  String get addPhoto => 'Add photo';
  String get photoLimitReached => 'Free listings can add up to 5 photos.';
  String get startingPriceLabel => 'Indicative starting price (₹)';
  String get startingPriceHint => 'e.g. 300';
  String get startingPriceDisclaimer =>
      'Shown as "from ₹300". Indicative only — you agree the final price with the customer.';
  String get previewTitle => 'Your public listing';
  String get previewBody => 'This is exactly what customers will see.';
  String get publishListing => 'Publish my listing';
  String get draftSaved => 'Progress saved on this phone.';
  String get draftRestored => 'We restored your unfinished listing.';
  String get saveAndExit => 'Save and exit';
  String get exitOnboarding => 'Exit setup?';
  String get discardDraft => 'Discard my draft';
  String get discardDraftConfirm =>
      'Your saved progress will be deleted from this phone.';
  String get draftDiscarded => 'Draft discarded.';
  String get fieldRequired => 'This field is required.';

  // ------------------------------------------------- healthcare extras
  String get healthcareSectionTitle => 'Healthcare details';
  String get healthcareSectionBody =>
      'Doctors, clinics and diagnostic centres can add professional details. These are displayed as provided by you and are not verified.';
  String get healthcareSpecialtyHint => 'e.g. General physician, Dentist';
  String get healthcareCredentialsNotice =>
      'Phone verification confirms your number only. It does not confirm any medical qualification.';
  String get registrationClaimedLabel =>
      'Registration shown as provided by provider';
  String get phoneVerifiedNotCredentials =>
      'Phone verified does not mean credentials verified.';

  // -------------------------------------------------- provider dashboard
  String get dashboardTitle => 'Your listing';
  String get listingStatus => 'Listing status';
  String get statusDraft => 'Draft';
  String get statusPublished => 'Published';
  String get statusPaused => 'Paused';
  String get previewProfile => 'Preview public profile';
  String get editProfile => 'Edit profile';
  String get setWorkingHours => 'Working hours';
  String get updateAvailability => 'Update availability';
  String get pauseListing => 'Pause listing';
  String get resumeListing => 'Resume listing';
  String get listingPaused =>
      'Listing paused. Customers will not see it while paused.';
  String get listingResumed => 'Listing is live again.';
  String get profileViews => 'Profile views';
  String get callButtonTaps => 'Call button taps';
  String get whatsappButtonTaps => 'WhatsApp button taps';
  String get engagementExplainer =>
      'These count in-app button taps only. We cannot know whether a customer completed a call, hired you or paid you, so we never report calls, leads or jobs.';
  String get sampleStatsNotice =>
      'Sample data. Engagement counting is mocked in this build.';
  String get growYourBusiness => 'Grow your business';
  String get publishedSuccessfully => 'Your listing is published.';
  String get availabilityUpdated => 'Availability updated.';

  // ---------------------------------------------- monetization preview
  String get monetizationTitle => 'Grow your business';
  String get monetizationSubtitle =>
      'Optional ways to be seen by more customers in your area. Browsing and basic listings stay free.';
  String get sponsoredListingsTitle => 'Sponsored placement';
  String get sponsoredListingsBody =>
      'Appear at the top of relevant categories and localities as a clearly labelled Sponsored result.';
  String get sponsoredListingBulletOne =>
      'Matched to the customer\'s selected category and locality';
  String get sponsoredListingBulletTwo =>
      'Always labelled "Sponsored" — never disguised as an organic result';
  String get sponsoredListingBulletThree =>
      'Organic results stay visible and are never hidden';
  String get subscriptionTitle => 'Business subscription';
  String get subscriptionBody => 'Extra profile and insight features.';
  String get pricingComingSoon => 'Pricing coming soon';
  String get monetizationDisclaimer =>
      'Nothing here is purchasable yet. No payments or checkout are implemented in this build.';
  String get noVerificationForSale =>
      'Verification labels can never be bought, and paying for placement never makes a provider more trustworthy or guarantees enquiries or jobs.';
  String get subscriptionFeaturePhotos => 'More portfolio photos';
  String get subscriptionFeatureContent => 'Expanded profile content';
  String get subscriptionFeatureStats => 'More detailed engagement statistics';
  String get subscriptionFeatureServiceAreas =>
      'Additional service areas within supported markets';
  String get notNow => 'Not now';
  String get registerInterest => 'Register interest';
  String get registerInterestDone =>
      'Interest recorded. We will contact you when this launches.';
  String get registeredInterestLabel => 'Interest recorded';
  String get popularChoiceLabel => 'Most requested';
  String get sponsoredPreviewTitle => 'How a sponsored slot looks';
  String get sponsoredPreviewYourListing =>
      'Your listing would appear here, above the usual results.';
  String get sponsoredPreviewOrganic =>
      'Regular results still appear below, exactly as they do today.';
  String get planVisibilityTitle => 'Visibility plan';
  String get planInsightsTitle => 'Insights plan';
  String get planCompleteTitle => 'Complete plan';
  String get commissionNotTrackedNote =>
      'Customers contact providers directly, so LocalSaathi cannot know which conversations turn into paid work. That is why there is no commission tracking and why we will never report enquiries as if they were jobs.';

  // ---------------------------------------------------------------- errors
  String get errorNetwork =>
      'We could not reach the network. Check your connection and try again.';
  String get errorNotFound => 'That information was not found.';
  String get errorUnknown => 'An unexpected problem occurred.';
  String get deleteListingTitle => 'Delete this listing?';
  String get deleteListingBody =>
      'Your public profile will be removed and your number released for a new registration.';
  String get deleteListingConfirm => 'Delete listing';
  String get listingDeleted => 'Your listing was deleted.';
  String get photosUnavailableNotice => 'No photos added yet.';
}

/// English locale. Provided as a named type so locale switches and tests read
/// clearly; it is simply the reference strings.
class AppStringsEn extends AppStrings {
  const AppStringsEn();
}
