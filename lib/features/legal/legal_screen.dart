import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import 'legal_documents.dart';

/// Full-page reader for one legal document.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final LegalDocument document = legalDocument(doc);

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: Center(
        child: ConstrainedBox(
          // A readable measure, like any legal page on the web.
          constraints: const BoxConstraints(maxWidth: 720),
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.sm,
                AppSpacing.pagePadding,
                AppSpacing.huge,
              ),
              children: <Widget>[
                if (!AppConfig.legalTextReviewed) ...<Widget>[
                  AppBanner(
                    message: strings.legalDraftNotice,
                    tone: AppBannerTone.caution,
                    icon: Icons.edit_note,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  document.summary,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${strings.effectiveLabel} ${AppConfig.legalEffectiveDate} · ${strings.versionLabel} ${AppConfig.legalVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                for (final LegalSection section in document.sections) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(section.heading, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  for (final String p in section.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: p.startsWith('• ')
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.xs,
                                    right: AppSpacing.sm,
                                  ),
                                  child: Text('•', style: theme.textTheme.bodyMedium),
                                ),
                                Expanded(
                                  child: Text(
                                    p.substring(2),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            )
                          : Text(p, style: theme.textTheme.bodyMedium),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                LegalLinks(current: doc),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Route for each document, so the website can link to them directly.
String legalRoute(LegalDoc doc) => switch (doc) {
      LegalDoc.privacy => AppRoutes.privacy,
      LegalDoc.terms => AppRoutes.terms,
      LegalDoc.guidelines => AppRoutes.guidelines,
      LegalDoc.grievance => AppRoutes.grievance,
    };

/// A wrapping row of links to every legal page plus open-source licences, as
/// in any website footer.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.current, this.center = false});

  final LegalDoc? current;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
    );

    Widget link(String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(label, style: style),
          ),
        );

    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: AppSpacing.md,
          children: <Widget>[
            for (final LegalDoc d in LegalDoc.values)
              if (d != current)
                link(
                  legalDocument(d).title,
                  () => Navigator.of(context).pushNamed(legalRoute(d)),
                ),
            link(
              strings.openSourceLicences,
              () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '© ${DateTime.now().year} ${AppConfig.operatorLegalName} · ${strings.mapDataCredit}',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
