import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../app/app_routes.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/provider_avatar.dart';
import '../../core/widgets/provider_badges.dart';
import '../../core/widgets/provider_contact.dart';
import '../../core/widgets/provider_map.dart';
import '../../core/widgets/provider_photos.dart';
import '../../data/seed/locality_coordinates.dart';
import '../../domain/models/location.dart';
import '../../domain/models/provider.dart';
import '../../domain/models/service_category.dart';
import '../location/location_sheets.dart';
import 'working_hours_screen.dart';

/// Edit the provider's own public listing.
///
/// Only the owner can reach this: the session must own the profile, and the
/// repository re-checks ownership on write rather than trusting the screen. The
/// consent switches are repeated here rather than hidden in settings, because
/// withdrawing consent to show a number must immediately unpublish the Call
/// button — and, when WhatsApp is on, WhatsApp too.
class ProviderProfileEditorScreen extends StatefulWidget {
  const ProviderProfileEditorScreen({super.key});

  @override
  State<ProviderProfileEditorScreen> createState() =>
      _ProviderProfileEditorScreenState();
}

class _ProviderProfileEditorScreenState
    extends State<ProviderProfileEditorScreen> {
  bool _initialised = false;

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

  final Set<String> _categoryIds = <String>{};
  final Set<String> _serviceAreaIds = <String>{};
  final Set<String> _languages = <String>{};
  WorkingHours? _workingHours;
  bool _homeVisits = true;
  bool _phoneConsent = true;
  bool _whatsappEnabled = false;
  bool _requiresHealthcare = false;
  bool _saving = false;
  List<ProviderPhoto> _photos = <ProviderPhoto>[];
  bool _showOnMap = false;
  GeoPoint? _mapLocation;

  String? _cityId;
  List<Locality> _localities = <Locality>[];
  List<ServiceCategory> _catalog = <ServiceCategory>[];

  static const List<String> _languageOptions = <String>[
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _qualificationController.dispose();
    _specialtyController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _registrationNumberController.dispose();
    _registrationCouncilController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies dependencies = context.read<AppDependencies>();
    final SessionController session = context.read<SessionController>();
    final ProviderProfile? profile = session.profile;
    if (profile == null) return;

    final List<ServiceCategory> catalog =
        await dependencies.catalog.categories();
    final List<Locality> localities =
        await dependencies.locations.localities(profile.baseCityId);
    final bool healthcare =
        await dependencies.catalog.requiresHealthcareDetails(
      profile.categoryIds,
    );
    if (!mounted) return;

    final HealthcareDetails? details = profile.healthcareDetails;
    setState(() {
      _catalog = catalog;
      _localities = localities;
      _cityId = profile.baseCityId;
      _requiresHealthcare = healthcare;
      _nameController.text = profile.displayName;
      _descriptionController.text = profile.description ?? '';
      _categoryIds
        ..clear()
        ..addAll(profile.categoryIds);
      _serviceAreaIds
        ..clear()
        ..addAll(profile.serviceAreas.map((ProviderServiceArea a) => a.localityId));
      _serviceAreaIds.add(profile.baseLocalityId);
      _languages
        ..clear()
        ..addAll(profile.languages);
      _workingHours = profile.workingHours;
      _photos = profile.photos;
      _mapLocation = profile.mapLocation;
      _showOnMap = profile.mapLocation != null;
      _homeVisits = profile.homeVisits;
      _phoneConsent = profile.phoneDisplayConsented;
      _whatsappEnabled = profile.whatsappEnabled;
      _qualificationController.text = details?.qualification ?? '';
      _specialtyController.text = details?.specialty ?? '';
      _clinicNameController.text = details?.clinicName ?? '';
      _clinicAddressController.text = details?.clinicAddress ?? '';
      _registrationNumberController.text = details?.registrationNumber ?? '';
      _registrationCouncilController.text = details?.registrationCouncil ?? '';
    });
  }

  Future<void> _save() async {
    final strings = context.strings;
    final SessionController session = context.read<SessionController>();
    final ProviderProfile? profile = session.profile;
    if (profile == null) return;

    if (_nameController.text.trim().isEmpty) {
      _warn(strings.fieldRequired);
      return;
    }
    if (_categoryIds.isEmpty) {
      _warn(strings.selectAtLeastOneCategory);
      return;
    }
    if (_showOnMap && _mapLocation == null) {
      _warn(strings.mapPinNeeded);
      return;
    }
    if (!_phoneConsent) {
      // Withdrawing number consent is allowed, but it unpublishes the listing —
      // a public listing with no contact method is useless to a customer and
      // misleading about availability.
      _warn(strings.consentShowPhoneRequired);
      return;
    }

    setState(() => _saving = true);

    final HealthcareDetails? details = _requiresHealthcare
        ? HealthcareDetails(
            qualification: _qualificationController.text.trim(),
            specialty: _specialtyController.text.trim(),
            clinicName: _clinicNameController.text.trim(),
            clinicAddress: _clinicAddressController.text.trim(),
            registrationNumber: _registrationNumberController.text.trim(),
            registrationCouncil: _registrationCouncilController.text.trim(),
          )
        : null;

    final ProviderProfile updated = profile.copyWith(
      displayName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryIds: _categoryIds.toList(),
      serviceAreas: <ProviderServiceArea>[
        for (final String localityId in _serviceAreaIds)
          ProviderServiceArea(
            cityId: profile.baseCityId,
            localityId: localityId,
            isPrimary: localityId == profile.baseLocalityId,
          ),
      ],
      languages: _languages.toList(),
      workingHours: _workingHours,
      photos: _photos,
      // Turning the map off deletes the coordinates rather than hiding them.
      mapLocation: _showOnMap ? _mapLocation : null,
      clearMapLocation: !_showOnMap,
      homeVisits: _homeVisits,
      phoneDisplayConsented: _phoneConsent,
      whatsappEnabled: _whatsappEnabled && _phoneConsent,
      healthcareDetails: details,
    );

    final bool ok = await session.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _warn(strings.somethingWentWrong);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.saveChanges)),
    );
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editHours() async {
    final WorkingHours? result = await Navigator.of(context).push<WorkingHours>(
      MaterialPageRoute<WorkingHours>(
        builder: (BuildContext context) =>
            WorkingHoursScreen(initial: _workingHours),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _workingHours = result);
  }

  Future<void> _pickServiceAreas() async {
    final String? cityId = _cityId;
    final ProviderProfile? profile = context.read<SessionController>().profile;
    if (cityId == null || profile == null) return;
    final List<String>? chosen = await showLocalityMultiPickerSheet(
      context,
      cityId: cityId,
      selectedIds: _serviceAreaIds,
      baseLocalityId: profile.baseLocalityId,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _serviceAreaIds
        ..clear()
        ..addAll(chosen);
      _serviceAreaIds.add(profile.baseLocalityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final SessionController session = context.watch<SessionController>();
    final ProviderProfile? profile = session.profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.editProfile)),
        body: AppEmptyState(
          title: strings.providerSignIn,
          body: strings.providerSignInSubtitle,
          icon: Icons.storefront_outlined,
          actionLabel: strings.providerSignIn,
          onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.providerOnboarding,
            (Route<dynamic> r) => false,
          ),
        ),
      );
    }

    final Map<String, List<ServiceCategory>> byGroup =
        <String, List<ServiceCategory>>{};
    for (final ServiceCategory category in _catalog) {
      byGroup.putIfAbsent(category.groupId, () => <ServiceCategory>[]).add(category);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.editProfile),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(strings.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              ProviderAvatar(
                initials: profile.initials(),
                size: AppSpacing.avatarMd,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(profile.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    VerificationBadgeRow(
                      phoneVerified: profile.isPhoneVerified,
                      credentialsVerified: profile.isCredentialsVerified,
                      claimsCredentials:
                          profile.healthcareDetails?.hasClaimedRegistration ??
                              false,
                      showNotVerified: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: strings.businessNameLabel),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              helperText: strings.businessNameHelper,
              prefixIcon: const Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: strings.selectCategoriesTitle,
            subtitle: strings.addMoreServicesHint,
          ),
          for (final MapEntry<String, List<ServiceCategory>> entry
              in byGroup.entries) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                entry.key.replaceAll('-', ' '),
                style: theme.textTheme.labelLarge,
              ),
            ),
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
                      final bool required = await context
                          .read<AppDependencies>()
                          .catalog
                          .requiresHealthcareDetails(_categoryIds);
                      if (!mounted) return;
                      setState(() => _requiresHealthcare = required);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: strings.serviceAreasLabel,
            subtitle: strings.serviceAreasBody,
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(strings.serviceAreasLabel),
              subtitle: Text('${_serviceAreaIds.length}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickServiceAreas,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Locality locality in _localities)
                if (_serviceAreaIds.contains(locality.id))
                  AppBadgeInline.neutral(
                    label: locality.id == profile.baseLocalityId
                        ? '${locality.name} · ${strings.baseLocality}'
                        : locality.name,
                    icon: Icons.place_outlined,
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.localityOnlyPrivacyNote,
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.descriptionLabel),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 600,
            decoration: InputDecoration(hintText: strings.descriptionHint),
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: strings.languagesLabel),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String language in _languageOptions)
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

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.workingHours),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(strings.setWorkingHours),
              subtitle: Text(
                _workingHours == null || !_workingHours!.hasAnyHours
                    ? strings.openingHoursUnknown
                    : formatWorkingHoursSummary(
                        _workingHours,
                        closedLabel: strings.closedAllDay,
                      ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editHours,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.contactPreferencesTitle),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: _phoneConsent,
                  onChanged: (bool value) => setState(() {
                    _phoneConsent = value;
                    if (!value) _whatsappEnabled = false;
                  }),
                  title: Text(strings.consentShowPhoneTitle),
                  subtitle: Text(strings.consentShowPhoneBody),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _whatsappEnabled,
                  onChanged: !_phoneConsent
                      ? null
                      : (bool value) =>
                          setState(() => _whatsappEnabled = value),
                  title: Text(strings.consentWhatsappTitle),
                  subtitle: Text(strings.consentWhatsappBody),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _homeVisits,
                  onChanged: (bool value) =>
                      setState(() => _homeVisits = value),
                  title: Text(strings.homeVisitsToggleTitle),
                  subtitle: Text(strings.homeVisitsToggleBody),
                ),
              ],
            ),
          ),

          if (_requiresHealthcare) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: strings.healthcareSectionTitle,
              subtitle: strings.healthcareSectionBody,
            ),
            AppBanner(
              message: strings.credentialsReviewPending,
              tone: AppBannerTone.info,
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
            Text(
              strings.specialtyCareNote,
              style: theme.textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.photos),
          ProviderPhotoEditor(
            photos: _photos,
            onChanged: (List<ProviderPhoto> photos) =>
                setState(() => _photos = photos),
          ),

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.businessLocationTitle),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showOnMap,
            onChanged: (bool on) => setState(() {
              _showOnMap = on;
              if (!on) _mapLocation = null;
            }),
            title: Text(strings.showOnMapToggle),
            subtitle: Text(strings.showOnMapBody),
          ),
          if (_showOnMap) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.tapMapToPlacePin,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            MapLocationPicker(
              initialCentre: centreFor(
                localityId: profile.baseLocalityId,
                cityId: profile.baseCityId,
              ),
              value: _mapLocation,
              onChanged: (GeoPoint p) => setState(() => _mapLocation = p),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.listingStatus),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(strings.previewProfile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.providerProfile,
                    arguments: profile.id,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: profile.status == ListingStatus.published,
                  onChanged: (bool live) async {
                    await session.setListingStatus(
                      live ? ListingStatus.published : ListingStatus.paused,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          live ? strings.listingResumed : strings.listingPaused,
                        ),
                      ),
                    );
                  },
                  title: Text(
                    profile.status == ListingStatus.published
                        ? strings.pauseListing
                        : strings.resumeListing,
                  ),
                  subtitle: Text(strings.listingPausedExplainer),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(strings.saveChanges),
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            message: strings.oneNumberOneProfileStrong,
            tone: AppBannerTone.info,
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}
