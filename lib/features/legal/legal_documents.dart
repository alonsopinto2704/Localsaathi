import '../../core/config/app_config.dart';

/// The legal pages, in plain language.
///
/// Written for an Indian listing directory: the Digital Personal Data
/// Protection Act 2023 (notice, consent, rights, grievance), the Information
/// Technology Act 2000 (s. 79 intermediary) and the IT (Intermediary
/// Guidelines and Digital Media Ethics Code) Rules 2021 (user agreement,
/// Grievance Officer, 24-hour / 15-day timelines).
///
/// IMPORTANT: this is a carefully drafted starting point, not legal advice. It
/// must be reviewed by a lawyer, and every bracketed value in [AppConfig] filled
/// in, before launch. Until [AppConfig.legalTextReviewed] is true the screens
/// say so. The text is English-only on purpose: translated legal text needs its
/// own review.
enum LegalDoc { privacy, terms, guidelines, grievance }

class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;

  /// A paragraph starting with "• " renders as a bullet.
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;

  /// One or two sentences shown above the full text.
  final String summary;
  final List<LegalSection> sections;
}

const String _app = AppConfig.appName;
const String _operator = AppConfig.operatorLegalName;

LegalDocument legalDocument(LegalDoc doc) => switch (doc) {
      LegalDoc.privacy => _privacy,
      LegalDoc.terms => _terms,
      LegalDoc.guidelines => _guidelines,
      LegalDoc.grievance => _grievance,
    };

const LegalDocument _privacy = LegalDocument(
  title: 'Privacy Policy',
  summary:
      'Customers can use $_app without an account; what you save stays on your device. Providers choose what to publish, can change it at any time, and can delete their listing and data.',
  sections: <LegalSection>[
    LegalSection('Who we are', <String>[
      '$_app is operated by $_operator, ${AppConfig.operatorAddress} ("we", "us"). For the purposes of the Digital Personal Data Protection Act, 2023 we are the Data Fiduciary for the personal data described here.',
      'Questions about this policy: ${AppConfig.privacyEmail}. Complaints: our Grievance Officer (see "Grievances" below).',
    ]),
    LegalSection('If you are looking for help (customers)', <String>[
      '• You do not need an account. We do not ask for your name, phone number or email to browse.',
      '• The locality you choose, your language and the providers you save are stored only on your device. Clearing the app\'s data or uninstalling removes them.',
      '• We count anonymous events such as "profile viewed" or "Call tapped" so providers can see interest in their listing. These counts are not linked to you.',
      '• If you report a listing or request a new city, we keep what you write in that form so we can act on it.',
      '• We do not access your device location. You pick your locality by hand.',
    ]),
    LegalSection('If you list your services (providers)', <String>[
      'To publish a listing we process: your mobile number (verified by a one-time code), your name or business name, the services you offer, your city, base locality and service areas, working hours, languages, description, indicative prices, any photos you add, any healthcare qualifications you enter, and, only if you switch it on, the map location of your business premises.',
      'We also keep a record of each consent you give or withdraw (with the date and the wording version) and of verification checks.',
    ]),
    LegalSection('What is public', <String>[
      'Your listing is public once you publish it: anyone, including people who do not use the app, may see it. Specifically:',
      '• Name, services, localities, hours, languages, description, prices and photos.',
      '• Your phone number and the Call button, only with your consent, which is required to publish.',
      '• WhatsApp, only if you switch it on.',
      '• A map pin of your premises, only if you switch it on. Never pin a home address. Turning the map off deletes the stored location.',
      'We never publish a street address, and we remove location and camera details (EXIF metadata such as GPS coordinates and device serial numbers) from photos on your device before they are uploaded.',
    ]),
    LegalSection('Why we use your data', <String>[
      '• To show your listing to customers and let them contact you (your consent).',
      '• To verify that you control the phone number and to keep one listing per number (your consent; preventing fraud and impersonation).',
      '• To act on reports, keep the directory safe and comply with law (legitimate uses permitted by section 7 of the Act).',
      'We do not sell personal data, and we do not use it for advertising profiles.',
    ]),
    LegalSection('Who else receives data', <String>[
      '• Service providers that process data for us under contract: cloud hosting and database, and the SMS provider that sends one-time codes.',
      '• Map tiles are loaded from OpenStreetMap servers when a map is shown; those servers see your device\'s IP address, as with any website (OpenStreetMap Foundation privacy policy applies).',
      '• If you tap "Get directions", the location is opened in Google Maps or your maps app, whose own policy applies. Calls and WhatsApp messages go through your phone\'s apps; we do not see their content.',
      '• Government agencies or courts, when the law requires it.',
      'Data may be processed on servers outside India, except in countries to which transfer is restricted by the Government of India under section 16 of the Act.',
    ]),
    LegalSection('How long we keep it', <String>[
      '• Listing data, photos and map location: while your listing exists. When you delete your listing we delete or anonymise this data within 30 days.',
      '• Consent, verification and grievance records: for as long as the law requires us to keep them as evidence, then deleted.',
      '• Reports and city requests: until resolved, then up to 12 months.',
    ]),
    LegalSection('Your rights', <String>[
      'Under the Digital Personal Data Protection Act, 2023 you may:',
      '• Get a summary of the personal data we hold about you and how it is used.',
      '• Correct, complete or update it. Most of it you can edit yourself under "Edit listing".',
      '• Erase it. Use "Delete account" in the app or write to us.',
      '• Withdraw any consent, as easily as you gave it, using the switches in "Edit listing". Withdrawal does not affect what happened before it.',
      '• Raise a grievance with us, and then with the Data Protection Board of India.',
      '• Nominate a person to exercise these rights if you die or become incapacitated.',
      'Write to ${AppConfig.privacyEmail} and include the phone number on your listing so we can verify the request. We reply within 15 days.',
    ]),
    LegalSection('Children', <String>[
      'Providers must be 18 or older. We do not knowingly collect personal data from anyone under 18 and will delete it if we learn that we have.',
    ]),
    LegalSection('Security', <String>[
      'We use reasonable security practices, including encryption in transit, access controls and row-level permissions on the database. If a personal data breach occurs we will inform affected people and the Data Protection Board as the law requires.',
    ]),
    LegalSection('Grievances', <String>[
      'Grievance Officer: ${AppConfig.grievanceOfficerName}, $_operator, ${AppConfig.operatorAddress}. Email: ${AppConfig.grievanceOfficerEmail}.',
      'We acknowledge complaints within 24 hours and resolve them within 15 days.',
    ]),
    LegalSection('Changes', <String>[
      'If we change this policy materially we will tell providers in the app and ask for consent again where the law requires. Effective date: ${AppConfig.legalEffectiveDate} (version ${AppConfig.legalVersion}).',
    ]),
  ],
);

const LegalDocument _terms = LegalDocument(
  title: 'Terms of Use',
  summary:
      '$_app is a free directory that helps you find and contact local service providers. Agreements for any work are between the customer and the provider.',
  sections: <LegalSection>[
    LegalSection('About these terms', <String>[
      'These terms are an agreement between you and $_operator, ${AppConfig.operatorAddress}. By using $_app you accept them and our Privacy Policy. If you do not agree, please do not use the service.',
    ]),
    LegalSection('What $_app is, and is not', <String>[
      '$_app is an intermediary under the Information Technology Act, 2000: providers publish their own listings and customers contact them directly.',
      '• We do not employ, recommend or supervise providers, and we are not a party to any agreement between a customer and a provider.',
      '• We do not take bookings or payments, set prices, or guarantee availability, quality, safety or results.',
      '• Prices shown are indicative, written by the provider. Agree the final price before work starts.',
    ]),
    LegalSection('What the labels mean', <String>[
      '• "Phone verified" means the provider proved control of that phone number with a one-time code. It is not a background check, a licence check or an endorsement.',
      '• "Credentials verified" appears only after a separate review of documents.',
      '• "Sponsored" listings are paid placements. They are always labelled, and other listings are never hidden to make room for them.',
    ]),
    LegalSection('Health services', <String>[
      '$_app lists doctors, clinics and other health professionals as a contact directory only. Nothing in the app is medical advice. In an emergency call 112.',
    ]),
    LegalSection('If you list your services', <String>[
      '• You must be 18 or older, use a phone number you control, and keep only one listing per number.',
      '• Your listing must be accurate and current, describe only services you genuinely offer, and must not impersonate anyone.',
      '• You are responsible for holding any licence, registration or qualification the law requires for your work, and for the work itself.',
      '• Photos must be your own work, taken by you or with permission. Do not include identifiable people without their consent, customers\' homes or house numbers.',
      '• A map pin may only mark business premises you are entitled to show, never a home.',
      '• You give us a free, non-exclusive licence to display, resize and share your listing content inside $_app while it is listed. You keep ownership, and the licence ends when you remove the content (apart from copies we must keep by law).',
    ]),
    LegalSection('Everyone must not', <String>[
      'In line with Rule 3(1)(b) of the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, you must not publish or share anything that:',
      '• belongs to someone else and that you have no right to share;',
      '• is obscene, pornographic, invasive of another person\'s privacy, harassing, defamatory, or insulting on the basis of gender, religion, caste or ethnicity;',
      '• is harmful to children;',
      '• infringes a patent, trademark, copyright or other proprietary right;',
      '• deceives or misleads, or knowingly spreads false or misleading information;',
      '• impersonates another person;',
      '• threatens the unity, integrity, defence, security or sovereignty of India, friendly relations with other states, or public order, or incites an offence;',
      '• contains malware, or breaks any law for the time being in force.',
      'You also must not copy phone numbers or listings in bulk, send spam, or misuse the report feature.',
    ]),
    LegalSection('Reports, removal and suspension', <String>[
      'Anyone can report a listing from its profile. We review reports and may edit, hide or remove content and suspend listings that break these terms or the law, including when a court or the Government lawfully directs us to. Listings involving impersonation or intimate images are acted on within 24 hours of a complaint.',
    ]),
    LegalSection('Liability', <String>[
      'The service is provided "as is". To the extent the law allows, we are not liable for the acts or omissions of providers or customers, for work done or not done, or for indirect losses. Nothing in these terms limits liability that cannot be limited by law.',
      'If you list your services, you agree to compensate us for claims arising from your listing or your work that result from your breach of these terms.',
    ]),
    LegalSection('Law and disputes', <String>[
      'These terms are governed by the laws of India. Courts at ${AppConfig.jurisdictionCity} have jurisdiction, subject to any consumer forum you are entitled to approach.',
    ]),
    LegalSection('Grievances and contact', <String>[
      'Grievance Officer: ${AppConfig.grievanceOfficerName}, ${AppConfig.grievanceOfficerEmail}. We acknowledge complaints within 24 hours and resolve them within 15 days.',
    ]),
    LegalSection('Changes', <String>[
      'We may update these terms. Material changes will be shown in the app before they apply. Effective date: ${AppConfig.legalEffectiveDate} (version ${AppConfig.legalVersion}).',
    ]),
  ],
);

const LegalDocument _guidelines = LegalDocument(
  title: 'Community Guidelines',
  summary:
      'Honest listings, respectful contact, and reporting instead of arguing. These guidelines sit alongside the Terms of Use.',
  sections: <LegalSection>[
    LegalSection('For providers', <String>[
      '• List only services you actually offer, in the areas you actually serve.',
      '• Keep your hours, prices and contact details current. Pause your listing when you are not taking work.',
      '• Use your real name or registered business name. No fake reviews, paid "verification" or invented credentials.',
      '• Photos of your own work only. No customers\' faces, homes or house numbers.',
      '• Pin only a shop, clinic or workshop on the map.',
    ]),
    LegalSection('For customers', <String>[
      '• Contact providers for genuine enquiries only, at reasonable hours.',
      '• Agree price and scope before work starts.',
      '• Do not harass, threaten or abuse anyone, or collect numbers for marketing.',
    ]),
    LegalSection('When something is wrong', <String>[
      'Use "Report" on the listing instead of arguing in calls or messages. We read every report. For urgent safety issues, contact the police on 112.',
    ]),
  ],
);

const LegalDocument _grievance = LegalDocument(
  title: 'Grievance Redressal',
  summary:
      'How to complain about a listing, about content, or about how we handle your personal data, and how fast we respond.',
  sections: <LegalSection>[
    LegalSection('Grievance Officer', <String>[
      AppConfig.grievanceOfficerName,
      _operator,
      AppConfig.operatorAddress,
      'Email: ${AppConfig.grievanceOfficerEmail}',
      'Appointed under Rule 3(2) of the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021 and section 8(10) of the Digital Personal Data Protection Act, 2023.',
    ]),
    LegalSection('What to include', <String>[
      '• For a listing: the provider\'s name and locality, or use "Report" on their profile, which attaches the reference for you.',
      '• What is wrong, and what you would like us to do.',
      '• How to reach you. For requests about your own data, the phone number on your listing so we can verify you.',
    ]),
    LegalSection('Timelines', <String>[
      '• Acknowledgement within 24 hours.',
      '• Resolution within 15 days.',
      '• Impersonation, or content showing a person\'s private areas or intimate images: action within 24 hours of the complaint.',
    ]),
    LegalSection('If you are not satisfied', <String>[
      'For personal data complaints you may approach the Data Protection Board of India once our process is complete. For other disputes, the Terms of Use describe the applicable law and courts.',
    ]),
  ],
);
