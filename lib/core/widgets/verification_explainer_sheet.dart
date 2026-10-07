import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

/// Explains the trust labels.
///
/// This sheet exists because the two signals are easy to confuse and the
/// confusion is harmful: a customer who reads "verified" as "qualified doctor"
/// could be misled about medical care. The copy therefore states, in the sheet
/// itself, that OTP confirms a phone number only.
Future<void> showVerificationExplainer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final strings = sheetContext.strings;
      final ThemeData theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.verificationExplainerTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ExplainerRow(
                icon: Icons.phone_android,
                title: strings.verifiedPhoneLabel,
                body: strings.phoneVerifiedExplainer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ExplainerRow(
                icon: Icons.school_outlined,
                title: strings.verifiedCredentialsLabel,
                body: strings.credentialsVerifiedExplainer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ExplainerRow(
                icon: Icons.description_outlined,
                title: strings.registrationClaimedLabel,
                body: strings.healthcareCredentialsNotice,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                strings.verificationExplainerConsentNote,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(strings.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
