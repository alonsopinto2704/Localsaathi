part of 'app_strings.dart';

/// Provider-facing copy that is long enough to deserve its own part file:
/// onboarding helpers, consent wording and compliance notices.
extension ProviderCopyX on AppStrings {
  String get onboardingIntroName =>
      'Customers see this name first. A business name works well if you have one.';
  String get onboardingIntroCategories =>
      'Pick every service you actually offer. You can change this later.';
  String get onboardingIntroLocation =>
      'Choose the city you work in most, then the localities you are willing to travel to.';
  String get onboardingIntroDetails =>
      'A short honest description helps customers decide. Two or three lines is plenty.';
  String get onboardingIntroHours =>
      'Working hours power the "Open now" filter. Leave a day closed if you do not work it.';
  String get onboardingIntroContact =>
      'Your number is never shown until you allow it below.';
  String get onboardingIntroPhotos =>
      'Photos are optional. Real photos of your work build the most trust.';
  String get onboardingIntroPreview =>
      'This is exactly how customers will see your listing. Publish when it looks right.';

  String get consentShowPhoneHelp =>
      'Required to be listed. Customers can call you only if you agree. You can withdraw this later by pausing or deleting your listing.';
  String get consentWhatsappHelp =>
      'Optional and separate. Turn this off to receive calls only.';
  String get verificationCareNote =>
      'Phone verification only proves the number is yours. It is not a background check and it does not confirm any professional qualification.';
  String get credentialsReviewPending =>
      'Credentials review is not part of this build. Your profile will show "Phone verified" only.';
  String get specialtyCareNote =>
      'Enter your own specialty and registration details. LocalSaathi does not generate or invent professional credentials.';
  String get avatarInitialsHint =>
      'Your initials are shown until you add a photo.';
  String get previewProfileNotice =>
      'Preview shows your public listing exactly as customers see it.';
  String get publishedListingHelp =>
      'Customers in your service areas can now find and contact you.';

  // Photos of the provider's work.
  String get photoFromGallery => 'Choose from gallery';
  String get photoFromCamera => 'Take a photo';
  String get photoPickFailed =>
      'That photo could not be added. Check the app has permission and try again.';
  String get removePhoto => 'Remove photo';
  String get photoFormatUnsupported =>
      'Please choose a JPG or PNG photo.';
  String get photoHelp =>
      'Clear photos of finished work help customers trust you. Avoid faces of customers and house numbers.';
  String get recentWork => 'Recent work';
  String photoCount(int n) => n == 1 ? '1 photo' : '$n photos';

  // Optional business location on the map.
  String get businessLocationTitle => 'Business location on map';
  String get showOnMapToggle => 'Show my business location on the map';
  String get showOnMapBody =>
      'Optional. Only for a shop, clinic or workshop that customers can visit. Never pin your home. You can turn this off at any time and the pin is deleted.';
  String get tapMapToPlacePin =>
      'Tap the map where your entrance is. Drag to move around, pinch to zoom.';
  String get mapPinNeeded => 'Tap the map to place your pin, or turn the map off.';
}
