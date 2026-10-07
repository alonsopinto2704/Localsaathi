import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';

/// Invite a service provider.
///
/// This screen is the answer to "customers cannot add another person's phone
/// number": rather than a form, the customer is given the native Android share
/// sheet with an invitation the provider can act on themselves. That keeps the
/// directory provider-owned without making the customer's helpfulness useless.
class InviteProviderScreen extends StatelessWidget {
  const InviteProviderScreen({super.key});

  Future<void> _share(BuildContext context) async {
    final strings = context.strings;
    final String message =
        '${strings.inviteMessage}${AppConfig.shareBaseUrl}/join';
    await SharePlus.instance.share(
      ShareParams(text: message, subject: strings.inviteTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.inviteTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          AppBanner(
            message: strings.inviteBody,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.inviteMessagePreviewTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${strings.inviteMessage}${AppConfig.shareBaseUrl}/join',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => _share(context),
            icon: const Icon(Icons.ios_share),
            label: Text(strings.inviteOpenShareSheet),
          ),
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            message: strings.inviteConsentNote,
            tone: AppBannerTone.caution,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.inviteWhatTheyGetTitle),
          _Benefit(
            icon: Icons.badge_outlined,
            text: strings.inviteBenefitProfile,
          ),
          _Benefit(
            icon: Icons.call_outlined,
            text: strings.inviteBenefitCalls,
          ),
          _Benefit(
            icon: Icons.lock_outline,
            text: strings.inviteBenefitControl,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(strings.inviteFreeNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
