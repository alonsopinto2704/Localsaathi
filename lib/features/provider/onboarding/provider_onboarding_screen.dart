import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../app/app_routes.dart';
import '../../../app/controllers/session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/provider_avatar.dart';
import '../../../core/widgets/provider_photos.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/location.dart';
import '../../../domain/models/provider.dart';
import '../../../domain/models/service_category.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../location/location_sheets.dart';
import 'onboarding_hours_step.dart';
import 'onboarding_widgets.dart';

/// Provider onboarding.
///
/// Ten steps, matching the product flow: phone, code, name, services, location,
/// details, hours, contact preferences, photos and prices, then preview and
/// publish. Everything except the final publish is saved as a draft on the
/// device, so a provider who is interrupted can resume.
///
/// Two rules are structural rather than cosmetic:
/// * the phone is verified **before** any profile form is reachable, and a
///   number that already owns a profile is signed in rather than re-registered;
/// * consent to display the number is a blocking toggle — publish is disabled
///   until it is granted, and WhatsApp cannot be enabled without it.
class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

enum _Step {
  phone,
  name,
  categories,
  location,
  details,
  hours,
  contact,
  photos,
  preview,
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  Timer? _resendTicker;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _clinicNameController = TextEditingController();
  final TextEditingController _clinicAddressController =
      TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _registrationCouncilController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  late final ProviderSignInViewState _signInState;
  late final SessionController _session;

  _Step _step = _Step.phone;
  bool _loadingDraft = true;
  bool _restoredDraft = false;
  bool _publishing = false;

  // Wizard data.
  final Set<String> _categoryIds = <String>{};
  String? _cityId;
  String? _baseLocalityId;
  final Set<String> _serviceAreaIds = <String>{};
  final Set<String> _languages = <String>{};
  List<DayAvailability> _hours = defaultDayAvailability();
  bool _homeVisits = true;
  bool _phoneConsent = false;
  bool _whatsappEnabled = false;
  // ponytail: photos are kept in memory only, not in the resumable draft (they
  // would bloat local storage); a provider who leaves mid-flow re-adds them.
  List<ProviderPhoto> _photos = <ProviderPhoto>[];
  bool _termsAccepted = false;

  List<ServiceCategory> _catalog = <ServiceCategory>[];
  List<Locality> _localities = <Locality>[];
  bool _requiresHealthcare = false;

  /// Ordered so the progress indicator and the "step n of m" label agree.
  static const List<_Step> _order = <_Step>[
    _Step.phone,
    _Step.name,
    _Step.categories,
    _Step.location,
    _Step.details,
    _Step.hours,
    _Step.contact,
    _Step.photos,
    _Step.preview,
  ];

  @override
  void initState() {
    super.initState();
    _signInState = ProviderSignInViewState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _session = context.read<SessionController>();
      final AppDependencies dependencies = context.read<AppDependencies>();
      final List<ServiceCategory> catalog =
          await dependencies.catalog.categories();
      final City activeCity = await dependencies.locations.activeLaunchCity();
      final List<Locality> localities =
          await dependencies.locations.localities(activeCity.id);
      if (!mounted) return;

      setState(() {
        _catalog = catalog;
        _cityId = activeCity.id;
        _cityNames[activeCity.id] = activeCity.name;
        _localities = localities;
      });

      // Resume an unfinished draft when there is no active session.
      if (_session.status == SessionStatus.signedOut) {
        final ProviderDraft? draft = await dependencies.drafts.load();
        if (draft != null && draft.isResumable && mounted) {
          _applyDraft(draft);
          setState(() => _restoredDraft = true);
        }
      } else if (_session.hasProfile) {
        // This provider already owns a listing. Editing is the profile editor's
        // job, so send them there rather than starting a second registration —
        // which the uniqueness rule would reject anyway.
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.providerEdit);
        return;
      }
      setState(() => _loadingDraft = false);
    });
  }

  @override
  void dispose() {
    _resendTicker?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _qualificationController.dispose();
    _specialtyController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _registrationNumberController.dispose();
    _registrationCouncilController.dispose();
    _priceController.dispose();
    _signInState.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- drafts
  void _applyDraft(ProviderDraft draft) {
    _nameController.text = draft.displayName ?? '';
    _descriptionController.text = draft.description ?? '';
    _categoryIds
      ..clear()
      ..addAll(draft.categoryIds);
    _cityId = draft.cityId ?? _cityId;
    _baseLocalityId = draft.baseLocalityId;
    _serviceAreaIds
      ..clear()
      ..addAll(draft.serviceAreaIds);
    _languages
      ..clear()
      ..addAll(draft.languages);
    _homeVisits = draft.homeVisits;
    _phoneConsent = draft.phoneDisplayConsented;
    _whatsappEnabled = draft.whatsappEnabled;
    if (draft.workingHours != null) {
      _hours = dayAvailabilityFromWorkingHours(draft.workingHours!);
    }
    if (draft.healthcareDetails != null) {
      _qualificationController.text =
          draft.healthcareDetails!.qualification ?? '';
      _specialtyController.text = draft.healthcareDetails!.specialty ?? '';
      _clinicNameController.text = draft.healthcareDetails!.clinicName ?? '';
      _clinicAddressController.text =
          draft.healthcareDetails!.clinicAddress ?? '';
      _registrationNumberController.text =
          draft.healthcareDetails!.registrationNumber ?? '';
      _registrationCouncilController.text =
          draft.healthcareDetails!.registrationCouncil ?? '';
    }
  }

  ProviderDraft _currentDraft() => ProviderDraft(
        phoneE164: _session.session?.phoneE164 ?? '',
        updatedAt: DateTime.now(),
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        categoryIds: _categoryIds.toList(),
        cityId: _cityId,
        baseLocalityId: _baseLocalityId,
        serviceAreaIds: _serviceAreaIds.toList(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        languages: _languages.toList(),
        workingHours: _buildWorkingHours(),
        homeVisits: _homeVisits,
        phoneDisplayConsented: _phoneConsent,
        whatsappEnabled: _whatsappEnabled,
        healthcareDetails: _requiresHealthcare ? _buildHealthcare() : null,
        lastStepIndex: _order.indexOf(_step),
      );

  Future<void> _saveDraft() async {
    if (_session.status == SessionStatus.signedOut) return;
    try {
      await context.read<AppDependencies>().drafts.save(_currentDraft());
    } on Object {
      // Losing a draft must never block the wizard.
    }
  }

  WorkingHours? _buildWorkingHours() => workingHoursFromAvailability(_hours);

  HealthcareDetails? _buildHealthcare() {
    final HealthcareDetails details = HealthcareDetails(
      qualification: _qualificationController.text.trim(),
      specialty: _specialtyController.text.trim(),
      clinicName: _clinicNameController.text.trim(),
      clinicAddress: _clinicAddressController.text.trim(),
      registrationNumber: _registrationNumberController.text.trim(),
      registrationCouncil: _registrationCouncilController.text.trim(),
    );
    return details.hasAnyDetail ? details : null;
  }

  // ------------------------------------------------------------- sign-in
  Future<void> _requestCode() async {
    _signInState.isBusy = true;
    _signInState.notify();
    final bool ok = await _session.requestCode(_phoneController.text);
    _signInState
      ..isBusy = false
      ..phase = ok ? SignInPhase.otp : SignInPhase.phone
      ..pendingPhonePretty = _session.pendingPhonePretty
      ..resendAvailableAt = _resendAt();
    _signInState.notify();
    _startResendTicker();
    if (!ok) _showError();
  }

  DateTime? _resendAt() {
    final int wait = _session.resendWaitSeconds;
    return wait > 0 ? DateTime.now().add(Duration(seconds: wait)) : null;
  }

  /// Repaints the countdown once a second while it is running. The server
  /// enforces the real limit; this only keeps the visible wait honest.
  void _startResendTicker() {
    _resendTicker?.cancel();
    if (_signInState.resendSecondsLeft == 0) return;
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted || _signInState.resendSecondsLeft == 0) t.cancel();
      if (mounted) _signInState.notify();
    });
  }

  Future<void> _verifyCode() async {
    _signInState.isBusy = true;
    _signInState.notify();
    final bool ok = await _session.verifyCode(_otpController.text);
    _signInState.isBusy = false;
    if (!ok) {
      _signInState.notify();
      _showError();
      return;
    }
    if (_session.existingProfileId != null) {
      // The number already has a profile. Sign in; never re-register.
      _signInState
        ..phase = SignInPhase.verifiedExisting
        ..notify();
      return;
    }
    _signInState.notify();
    await _session.refreshProfile();
    if (!mounted) return;
    setState(() => _step = _Step.name);
    await _saveDraft();
  }

  Future<void> _resend() async {
    _signInState.isBusy = true;
    _signInState.notify();
    final bool ok = await _session.resendCode();
    _signInState
      ..isBusy = false
      ..pendingPhonePretty = _session.pendingPhonePretty
      ..resendAvailableAt = _resendAt();
    _signInState.notify();
    _startResendTicker();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.otpResent)),
      );
    } else {
      _showError();
    }
  }

  void _changeNumber() {
    _session.cancelVerification();
    _otpController.clear();
    _signInState
      ..phase = SignInPhase.phone
      ..pendingPhonePretty = null;
    _signInState.notify();
  }

  void _showError() {
    final String? key = _session.errorKey;
    if (key == null) return;
    final strings = context.strings;
    final String message = switch (key) {
      'otpInvalid' => strings.otpInvalid,
      'otpExpired' => strings.otpExpired,
      'otpAttemptsExceeded' => strings.otpAttemptsExceeded,
      'otpRateLimited' => strings.otpRateLimited,
      'reauthRequired' => strings.reauthRequired,
      'sessionExpired' => strings.sessionExpired,
      'invalidPhoneNumber' => strings.invalidPhoneNumber,
      'duplicateNumberMessage' => strings.duplicateNumberMessage,
      'fieldRequired' => strings.fieldRequired,
      _ => strings.somethingWentWrong,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ navigation
  bool get _isPhoneStep => _step == _Step.phone;

  String? _validateCurrentStep() {
    final strings = context.strings;
    switch (_step) {
      case _Step.phone:
        return null;
      case _Step.name:
        return _nameController.text.trim().isEmpty
            ? strings.fieldRequired
            : null;
      case _Step.categories:
        return _categoryIds.isEmpty ? strings.selectAtLeastOneCategory : null;
      case _Step.location:
        if (_baseLocalityId == null) return strings.fieldRequired;
        if (_serviceAreaIds.isEmpty) {
          return strings.selectAtLeastOneServiceArea;
        }
        return null;
      case _Step.details:
        return null;
      case _Step.hours:
        for (final DayAvailability day in _hours) {
          for (final HoursWindow window in day.windows) {
            if (!window.isValid) return strings.invalidTimeRange;
          }
        }
        return null;
      case _Step.contact:
        return _phoneConsent ? null : strings.consentShowPhoneRequired;
      case _Step.photos:
        return null;
      case _Step.preview:
        return _termsAccepted ? null : strings.acceptTermsRequired;
    }
  }

  Future<void> _next() async {
    final String? error = _validateCurrentStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final int index = _order.indexOf(_step);
    if (index >= _order.length - 1) return;
    setState(() => _step = _order[index + 1]);
    // The catalog has to know whether healthcare fields are required for the
    // categories just selected.
    await _refreshHealthcareFlag();
    await _saveDraft();
  }

  void _back() {
    final int index = _order.indexOf(_step);
    if (index == 0) return;
    if (_order[index - 1] == _Step.phone) {
      // Going back past verification is not allowed: the session stays.
      return;
    }
    setState(() => _step = _order[index - 1]);
  }

  Future<void> _refreshHealthcareFlag() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final bool required =
        await dependencies.catalog.requiresHealthcareDetails(_categoryIds);
    if (!mounted) return;
    setState(() => _requiresHealthcare = required);
  }

  Future<void> _publish() async {
    final strings = context.strings;
    final String? error = _validateCurrentStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final ProviderSession? session = _session.session;
    final String? cityId = _cityId;
    final String? baseLocalityId = _baseLocalityId;
    if (session == null || cityId == null || baseLocalityId == null) return;

    setState(() => _publishing = true);
    final ProviderProfile? created = await _session.createProfile(
      RegistrationSubmission(
        phoneE164: session.phoneE164,
        session: session,
        displayName: _nameController.text.trim(),
        baseCityId: cityId,
        baseLocalityId: baseLocalityId,
        categoryIds: _categoryIds.toList(),
        serviceAreaIds: _serviceAreaIds.toList(),
        description: _descriptionController.text.trim(),
        languages: _languages.toList(),
        workingHours: _buildWorkingHours(),
        homeVisits: _homeVisits,
        phoneDisplayConsented: _phoneConsent,
        whatsappEnabled: _whatsappEnabled,
        healthcareDetails: _requiresHealthcare ? _buildHealthcare() : null,
        photos: _photos,
        startingPrices: _buildStartingPrices(),
        termsAcceptedVersion: AppConfig.legalVersion,
      ),
    );

    if (!mounted) return;
    if (created == null) {
      setState(() => _publishing = false);
      _showError();
      return;
    }

    final bool published = await _session.publish();
    if (!mounted) return;
    setState(() => _publishing = false);

    if (!published) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.consentShowPhoneRequired)),
      );
      return;
    }

    await context.read<AppDependencies>().drafts.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.publishedSuccessfully)),
    );
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.providerDashboard, (Route<dynamic> r) => false);
  }

  List<StartingPrice> _buildStartingPrices() {
    final int? amount = int.tryParse(_priceController.text.trim());
    if (amount == null || amount <= 0 || _categoryIds.isEmpty) {
      return const <StartingPrice>[];
    }
    return <StartingPrice>[
      StartingPrice(categoryId: _categoryIds.first, amount: amount),
    ];
  }

  Future<void> _exit() async {
    await _saveDraft();
    if (!mounted) return;
    // Leaving before verification creates no session, so there is nothing to
    // preserve beyond the draft.
    if (_session.status == SessionStatus.signedOut) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop();
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.providerOnboardingTitle),
        leading: _isPhoneStep
            ? IconButton(
                onPressed: _exit,
                icon: const Icon(Icons.close),
                tooltip: strings.close,
              )
            : IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                tooltip: strings.back,
              ),
      ),
      body: _loadingDraft
          ? const AppLoadingState()
          : Column(
              children: <Widget>[
                if (!_isPhoneStep)
                  LinearProgressIndicator(
                    value: (_order.indexOf(_step) + 1) / _order.length,
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl,
                    ),
                    children: <Widget>[
                      if (_restoredDraft && _step == _Step.name) ...<Widget>[
                        AppBanner(
                          message: strings.draftRestored,
                          tone: AppBannerTone.info,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (!_isPhoneStep)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            '${strings.stepLabel} '
                            '${_order.indexOf(_step)} ${strings.stepOf} '
                            '${_order.length - 1}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      _buildStep(),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.phone:
        return ChangeNotifierProvider<ProviderSignInViewState>.value(
          value: _signInState,
          child: PhoneVerificationPanel(
            phoneController: _phoneController,
            otpController: _otpController,
            onRequestCode: _requestCode,
            onVerifyCode: _verifyCode,
            onChangeNumber: _changeNumber,
            onResend: _resend,
            onContinue: () async {
              await _session.refreshProfile();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.providerDashboard,
                (Route<dynamic> r) => false,
              );
            },
          ),
        );
      case _Step.name:
        return _buildNameStep();
      case _Step.categories:
        return _buildCategoriesStep();
      case _Step.location:
        return _buildLocationStep();
      case _Step.details:
        return _buildDetailsStep();
      case _Step.hours:
        return OnboardingHoursStep(
          days: _hours,
          onChanged: (List<DayAvailability> days) =>
              setState(() => _hours = days),
        );
      case _Step.contact:
        return _buildContactStep();
      case _Step.photos:
        return _buildPhotosStep();
      case _Step.preview:
        return _buildPreviewStep();
    }
  }

  Widget _buildBottomBar() {
    final strings = context.strings;
    if (_isPhoneStep) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.lg,
        ),
        child: Column(
          children: <Widget>[
            if (_step == _Step.preview)
              FilledButton(
                onPressed: _publishing ? null : _publish,
                child: _publishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        strings.publishListing,
                      ),
              )
            else
              FilledButton(
                onPressed: _next,
                child: Text(strings.next),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _exit,
              child: Text(strings.saveAndExit),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ steps
  Widget _buildNameStep() {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.stepNameTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(strings.onboardingIntroName, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: strings.businessNameLabel,
            hintText: strings.businessNameHint,
            helperText: strings.businessNameHelper,
            prefixIcon: const Icon(Icons.storefront_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppBanner(
          message: strings.avatarInitialsHint,
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }

  Widget _buildCategoriesStep() {
    final strings = context.strings;
    final Map<String, List<ServiceCategory>> byGroup =
        <String, List<ServiceCategory>>{};
    for (final ServiceCategory category in _catalog) {
      byGroup.putIfAbsent(category.groupId, () => <ServiceCategory>[]).add(category);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepCategoriesTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroCategories,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppBanner(
          message: strings.oneNumberOneProfileStrong,
          tone: AppBannerTone.info,
          icon: Icons.info_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final MapEntry<String, List<ServiceCategory>> entry
            in byGroup.entries) ...<Widget>[
          SectionHeader(title: _groupName(entry.key)),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ServiceCategory category in entry.value)
                FilterChip(
                  label: Text(category.name),
                  selected: _categoryIds.contains(category.id),
                  onSelected: (bool selected) async {
                    setState(() {
                      if (selected) {
                        _categoryIds.add(category.id);
                      } else {
                        _categoryIds.remove(category.id);
                      }
                    });
                    await _refreshHealthcareFlag();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  String _groupName(String groupId) {
    for (final ServiceCategory category in _catalog) {
      if (category.groupId == groupId) {
        return groupId.replaceAll('-', ' ');
      }
    }
    return groupId;
  }

  Widget _buildLocationStep() {
    final strings = context.strings;
    final Locality? base = _baseLocalityId == null
        ? null
        : _localities
            .where((Locality l) => l.id == _baseLocalityId)
            .cast<Locality?>()
            .firstWhere((Locality? l) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroLocation,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_city),
          title: Text(strings.baseCityLabel),
          subtitle: Text(_currentCityName),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickCity,
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.home_outlined),
          title: Text(strings.baseLocalityLabel),
          subtitle: Text(base?.name ?? strings.notSet),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickBaseLocality,
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.map_outlined),
          title: Text(strings.serviceAreasLabel),
          subtitle: Text(
            _serviceAreaIds.isEmpty
                ? strings.selectAtLeastOneServiceArea
                : '${_serviceAreaIds.length}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickServiceAreas,
        ),
        const SizedBox(height: AppSpacing.md),
        AppBanner(
          message: strings.homeBasedPrivacyBody,
          title: strings.homeBasedPrivacyTitle,
          tone: AppBannerTone.info,
        ),
      ],
    );
  }

  String get _currentCityName {
    // The active market name is data, never a literal.
    return _cityNames[_cityId] ?? '';
  }

  final Map<String, String> _cityNames = <String, String>{};

  Future<void> _pickCity() async {
    final City? chosen = await showCityPickerSheet(context, activeCityId: _cityId);
    if (chosen == null || !mounted) return;
    if (!chosen.isSelectable) {
      final strings = context.strings;
      final AppDependencies dependencies = context.read<AppDependencies>();
      final City active = await dependencies.locations.activeLaunchCity();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.launchAvailabilityMessageTemplate(active.name)),
        ),
      );
      return;
    }
    final AppDependencies dependencies = context.read<AppDependencies>();
    final List<Locality> localities =
        await dependencies.locations.localities(chosen.id);
    if (!mounted) return;
    setState(() {
      _cityId = chosen.id;
      _cityNames[chosen.id] = chosen.name;
      _localities = localities;
      _baseLocalityId = null;
      _serviceAreaIds.clear();
    });
  }

  Future<void> _pickBaseLocality() async {
    final String? cityId = _cityId;
    if (cityId == null) return;
    final Locality? chosen = await showLocalityPickerSheet(
      context,
      cityId: cityId,
      selectedId: _baseLocalityId,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _baseLocalityId = chosen.id;
      // The base locality is always a service area: a provider necessarily
      // serves the place they are based.
      _serviceAreaIds.add(chosen.id);
    });
  }

  Future<void> _pickServiceAreas() async {
    final String? cityId = _cityId;
    if (cityId == null) return;
    final List<String>? chosen = await showLocalityMultiPickerSheet(
      context,
      cityId: cityId,
      selectedIds: _serviceAreaIds,
      baseLocalityId: _baseLocalityId,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _serviceAreaIds
        ..clear()
        ..addAll(chosen);
      if (_baseLocalityId != null) _serviceAreaIds.add(_baseLocalityId!);
    });
  }

  Widget _buildDetailsStep() {
    final strings = context.strings;
    const List<String> languageOptions = <String>[
      'Hindi',
      'Marathi',
      'English',
      'Gujarati',
      'Urdu',
      'Tamil',
      'Telugu',
      'Kannada',
      'Malayalam',
      'Bengali',
      'Punjabi',
      'Odia',
      'Nepali',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepDetailsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroDetails,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          maxLength: 600,
          decoration: InputDecoration(
            labelText: strings.descriptionLabel,
            hintText: strings.descriptionHint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(strings.languagesLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String language in languageOptions)
              FilterChip(
                label: Text(language),
                selected: _languages.contains(language),
                onSelected: (bool selected) => setState(() {
                  if (selected) {
                    _languages.add(language);
                  } else {
                    _languages.remove(language);
                  }
                }),
              ),
          ],
        ),
        if (_requiresHealthcare) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(
            title: strings.healthcareSectionTitle,
            subtitle: strings.healthcareSectionBody,
          ),
          AppBanner(
            message: strings.specialtyCareNote,
            tone: AppBannerTone.caution,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _qualificationController,
            decoration: InputDecoration(labelText: strings.qualificationLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _specialtyController,
            decoration: InputDecoration(
              labelText: strings.specialtyLabel,
              hintText: strings.healthcareSpecialtyHint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _clinicNameController,
            decoration: InputDecoration(labelText: strings.clinicNameLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _clinicAddressController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: strings.clinicAddressLabel,
              helperText: strings.clinicAddressHelper,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _registrationNumberController,
            decoration:
                InputDecoration(labelText: strings.registrationNumberLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _registrationCouncilController,
            decoration:
                InputDecoration(labelText: strings.registrationCouncilLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            message: strings.credentialsReviewPending,
            tone: AppBannerTone.info,
          ),
        ],
      ],
    );
  }

  Widget _buildContactStep() {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepContactTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroContact,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.consentShowPhoneTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Switch(
                      value: _phoneConsent,
                      onChanged: (bool value) => setState(() {
                        _phoneConsent = value;
                        // WhatsApp depends on the number being visible.
                        if (!value) _whatsappEnabled = false;
                      }),
                    ),
                  ],
                ),
                Text(
                  strings.consentShowPhoneBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.consentShowPhoneHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!_phoneConsent) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  AppBanner(
                    message: strings.consentShowPhoneRequired,
                    tone: AppBannerTone.caution,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.consentWhatsappTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Switch(
                      value: _whatsappEnabled,
                      onChanged: !_phoneConsent
                          ? null
                          : (bool value) =>
                              setState(() => _whatsappEnabled = value),
                    ),
                  ],
                ),
                Text(
                  strings.consentWhatsappBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.consentWhatsappHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!_phoneConsent) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.whatsappNeedsPhoneConsent,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            value: _homeVisits,
            onChanged: (bool value) => setState(() => _homeVisits = value),
            title: Text(strings.homeVisitsToggleTitle),
            subtitle: Text(strings.homeVisitsToggleBody),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          strings.verificationCareNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepPhotosTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroPhotos,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ProviderPhotoEditor(
          photos: _photos,
          onChanged: (List<ProviderPhoto> photos) =>
              setState(() => _photos = photos),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          strings.startingPriceLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: strings.startingPriceHint,
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.startingPriceDisclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final String localityName = _localities
        .where((Locality l) => l.id == _baseLocalityId)
        .map((Locality l) => l.name)
        .join();
    final List<ServiceCategory> selected = _catalog
        .where((ServiceCategory c) => _categoryIds.contains(c.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.stepPreviewTitle,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(strings.previewBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppBanner(message: strings.previewProfileNotice, icon: Icons.visibility),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ProviderAvatar(
                      initials: _initials(_nameController.text),
                      size: AppSpacing.avatarMd,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _nameController.text.trim().isEmpty
                                ? strings.notSet
                                : _nameController.text.trim(),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            selected.map((ServiceCategory c) => c.name).join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            [_currentCityName, localityName]
                                .where((String s) => s.isNotEmpty)
                                .join(', '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(
                      _phoneConsent
                          ? Icons.phone_enabled_outlined
                          : Icons.phone_disabled_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _phoneConsent
                            ? strings.consentShowPhoneTitle
                            : strings.consentShowPhoneRequired,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      _whatsappEnabled
                          ? Icons.chat_outlined
                          : Icons.chat_bubble_outline,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _whatsappEnabled
                            ? strings.consentWhatsappTitle
                            : strings.whatsappUnavailable,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_descriptionController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              _descriptionController.text.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (_serviceAreaIds.isNotEmpty) ...<Widget>[
          SectionHeader(title: strings.areasServed),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Locality locality in _localities)
                if (_serviceAreaIds.contains(locality.id))
                  Chip(label: Text(locality.name)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_languages.isNotEmpty) ...<Widget>[
          SectionHeader(title: strings.languagesSpoken),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String language in _languages) Chip(label: Text(language)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_phoneConsent)
          AppBanner(
            message: strings.publishedListingHelp,
            tone: AppBannerTone.success,
            icon: Icons.check_circle_outline,
          ),
        const SizedBox(height: AppSpacing.lg),
        // Explicit, unticked by default: consent must be an affirmative act.
        CheckboxListTile(
          value: _termsAccepted,
          onChanged: (bool? v) => setState(() => _termsAccepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(strings.acceptTermsTitle),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.terms),
              child: Text(strings.termsOfUse),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.privacy),
              child: Text(strings.privacyPolicy),
            ),
          ],
        ),
      ],
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
