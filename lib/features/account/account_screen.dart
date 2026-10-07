import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../app/controllers/app_settings_controller.dart';
import '../../app/controllers/location_controller.dart';
import '../../app/controllers/session_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../legal/legal_documents.dart';
import '../legal/legal_screen.dart';
import '../location/location_sheets.dart';
import '../provider_profile/report_listing_sheet.dart';

/// Account and settings.
///
/// Usable as a guest: the only account that exists in this product is a
/// provider account, so a customer never sees a sign-in wall. The list is
/// therefore mostly settings, with the provider path as one clearly labelled row.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.embedded = false});

  /// True when hosted inside [HomeShell].
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LocationController location = context.watch<LocationController>();
    final SessionController session = context.watch<SessionController>();
    final AppSettingsController settings =
        context.watch<AppSettingsController>();

    final Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: <Widget>[
        _AccountHeader(session: session),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: strings.selectedLocation),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(strings.localityLabel),
                subtitle: Text(location.selection?.localityName ?? strings.notSet),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selection = location.selection;
                  if (selection == null) return;
                  final chosen = await showLocalityPickerSheet(
                    context,
                    cityId: selection.cityId,
                    selectedId: selection.localityId,
                  );
                  if (chosen == null) return;
                  await location.select(
                    cityId: selection.cityId,
                    localityId: chosen.id,
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(strings.cityLabel),
                subtitle: Text(location.selection?.cityName ?? strings.notSet),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.locationPicker),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.languagePreference),
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate),
            title: Text(settings.languageOptions
                .firstWhere(
                  (option) => option.code == settings.languageCode,
                  orElse: () => settings.languageOptions.first,
                )
                .name),
            subtitle: Text(strings.languagePreferenceSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.language),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.providerSpaceTitle),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(
                  session.hasProfile
                      ? strings.openProviderDashboard
                      : strings.providerSignIn,
                ),
                subtitle: Text(
                  session.hasProfile
                      ? (session.profile?.displayName ??
                          strings.signedInAsProvider)
                      : strings.providerSignInSubtitle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(
                  session.hasProfile
                      ? AppRoutes.providerDashboard
                      : AppRoutes.providerOnboarding,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(strings.inviteServiceProvider),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.inviteProvider),
              ),
              if (session.isSignedIn) ...<Widget>[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(strings.signOut),
                  onTap: () async {
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) => AlertDialog(
                        title: Text(strings.signOut),
                        content: Text(strings.signOutConfirm),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(strings.cancel),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(strings.signOut),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await session.signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.signedOut)),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.helpAndSupport),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(strings.reportAProblem),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHelpAndSupport(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(strings.aboutApp),
                subtitle: Text('${strings.versionLabel} ${AppConfig.appVersion}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.legalSectionTitle),
        Card(
          child: Column(
            children: <Widget>[
              for (final (LegalDoc doc, IconData icon, String label)
                  in <(LegalDoc, IconData, String)>[
                (LegalDoc.privacy, Icons.privacy_tip_outlined, strings.privacyPolicy),
                (LegalDoc.terms, Icons.description_outlined, strings.termsOfUse),
                (
                  LegalDoc.guidelines,
                  Icons.groups_outlined,
                  strings.communityGuidelinesTitle,
                ),
                (
                  LegalDoc.grievance,
                  Icons.support_agent_outlined,
                  strings.grievanceRedressal,
                ),
              ]) ...<Widget>[
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(legalRoute(doc)),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(strings.openSourceLicences),
                subtitle: Text(strings.mapDataCredit),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConfig.appName,
                  applicationVersion: AppConfig.appVersion,
                ),
              ),
            ],
          ),
        ),

        if (session.isSignedIn) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.deleteAccount),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(strings.deleteAccount),
              subtitle: Text(strings.deleteAccountConfirmBody),
              onTap: () => _confirmDeleteAccount(context, session),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(
          strings.accountFooterNote,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(strings.accountTitle)),
      body: body,
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    final strings = context.strings;
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.helpAndSupport,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(strings.helpAndSupportBody),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: Text(AppConfig.supportEmail),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language),
                title: Text(AppConfig.shareBaseUrl),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  showReportListingSheet(
                    context,
                    providerId: '',
                    providerName: strings.reportAProblem,
                  );
                },
                child: Text(strings.reportAProblem),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final strings = context.strings;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(strings.aboutApp),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.aboutBody),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${strings.versionLabel} ${AppConfig.appVersion}',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    SessionController session,
  ) async {
    final strings = context.strings;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: Text(strings.deleteAccountConfirmTitle),
        content: Text(strings.deleteAccountConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await session.deleteAccount();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.deleteAccountDone)),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final bool signedIn = session.hasProfile;

    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            signedIn ? Icons.storefront : Icons.person_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                signedIn
                    ? (session.profile?.displayName ?? strings.signedInAsProvider)
                    : strings.guestLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                signedIn
                    ? strings.signedInAsProvider
                    : strings.guestExplainer,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
