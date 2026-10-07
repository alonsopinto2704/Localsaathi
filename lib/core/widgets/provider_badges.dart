import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'verification_explainer_sheet.dart';

/// Compact inline badge for dense rows (cards, chips).
///
/// Kept in its own file so card-level widgets can use badges without pulling in
/// the sheet-based explainer, which would create an import cycle.
class AppBadgeInline extends StatelessWidget {
  const AppBadgeInline({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.border,
    this.dense = true,
  });

  factory AppBadgeInline.neutral({
    Key? key,
    required String label,
    IconData? icon,
    bool dense = true,
  }) =>
      AppBadgeInline(
        key: key,
        label: label,
        icon: icon,
        foreground: AppColors.textSecondary,
        background: AppColors.surfaceMuted,
        dense: dense,
      );

  /// Phone verified: teal on the primary tint, per the design blueprint.
  factory AppBadgeInline.verified({
    Key? key,
    required String label,
    IconData icon = Icons.check_circle_outline,
    bool dense = true,
  }) =>
      AppBadgeInline(
        key: key,
        label: label,
        icon: icon,
        foreground: AppColors.teal700,
        background: AppColors.teal50,
        dense: dense,
      );

  factory AppBadgeInline.claimed({
    Key? key,
    required String label,
    IconData icon = Icons.description_outlined,
    bool dense = true,
  }) =>
      AppBadgeInline(
        key: key,
        label: label,
        icon: icon,
        foreground: AppColors.accent700,
        background: AppColors.accent100,
        dense: dense,
      );

  /// Paid placement: a neutral slate outline, deliberately quieter than the
  /// trust badges so it can never read as an endorsement.
  factory AppBadgeInline.sponsored({
    Key? key,
    required String label,
    bool dense = true,
  }) =>
      AppBadgeInline(
        key: key,
        label: label.toUpperCase(),
        foreground: AppColors.textTertiary,
        background: Colors.transparent,
        border: AppColors.textTertiary,
        dense: dense,
      );

  final String label;
  final Color foreground;
  final Color background;
  final Color? border;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 14 : 16, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: (dense
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.labelMedium)
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two trust labels for a compact card row.
///
/// They are rendered from one widget so the separation between "phone verified"
/// and "credentials verified" cannot be lost by a screen rendering only one of
/// them. Tapping opens the explainer.
class VerificationBadgeRow extends StatelessWidget {
  const VerificationBadgeRow({
    super.key,
    required this.phoneVerified,
    required this.credentialsVerified,
    this.claimsCredentials = false,
    this.showNotVerified = false,
  });

  final bool phoneVerified;

  /// Only true after a separate review. Never set from OTP success.
  final bool credentialsVerified;

  /// Provider supplied registration details that have not been reviewed.
  final bool claimsCredentials;

  /// Whether to show a neutral "not verified" badge. Off by default on cards:
  /// a wall of negative badges is noise, and the absence of the green label
  /// already communicates it.
  final bool showNotVerified;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (phoneVerified)
          AppBadgeInline.verified(
            label: strings.verifiedPhoneLabel,
            icon: Icons.phone_android,
          )
        else if (showNotVerified)
          AppBadgeInline.neutral(
            label: strings.notVerifiedLabel,
            icon: Icons.phone_disabled_outlined,
          ),
        if (credentialsVerified)
          AppBadgeInline.verified(
            label: strings.verifiedCredentialsLabel,
            icon: Icons.school_outlined,
          )
        else if (claimsCredentials)
          // Amber, never green: a claim is not a verification.
          AppBadgeInline.claimed(label: strings.registrationClaimedLabel),
        InkWell(
          onTap: () => showVerificationExplainer(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            child: Text(
              strings.learnMoreShortLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Open/closed chip.
///
/// [status] must be `null` when working hours are unknown, which renders as
/// "hours not provided" rather than guessing.
class WorkingHoursChip extends StatelessWidget {
  const WorkingHoursChip({super.key, required this.status});

  final bool? status;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final AppSemanticColors semantic = context.semantic;
    switch (status) {
      case true:
        return AppBadgeInline(
          label: strings.openNow,
          icon: Icons.circle,
          foreground: semantic.success,
          background: semantic.successSurface,
        );
      case false:
        return AppBadgeInline(
          label: strings.closedNow,
          icon: Icons.schedule,
          foreground: semantic.warning,
          background: semantic.warningSurface,
        );
      case null:
        return AppBadgeInline.neutral(
          label: strings.openingHoursUnknownShort,
          icon: Icons.schedule,
        );
    }
  }
}
