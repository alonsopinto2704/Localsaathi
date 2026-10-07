import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';

/// Small pill-shaped label.
///
/// Every badge in the app goes through this widget so the visual language for
/// trust labels, availability and sponsorship stays consistent — and so the
/// distinction between "Phone verified" and "Credentials verified" is carried
/// by shape and colour, not just by reading the text.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.foreground,
    this.background,
    this.border,
    this.dense = false,
  });

  /// Green: a state we can assert as fact (phone control verified, open now).
  factory AppBadge.verified(
    BuildContext context, {
    required String label,
    IconData icon = Icons.verified_user_outlined,
    bool dense = false,
  }) {
    return AppBadge(
      label: label,
      icon: icon,
      foreground: AppColors.teal700,
      background: AppColors.teal50,
      border: Colors.transparent,
      dense: dense,
    );
  }

  /// Amber: a claim that has not been reviewed. Used for credentials stated by
  /// a provider so it can never be mistaken for the green verified badge.
  factory AppBadge.claimed(
    BuildContext context, {
    required String label,
    IconData icon = Icons.info_outline,
    bool dense = false,
  }) {
    final AppSemanticColors semantic = context.semantic;
    return AppBadge(
      label: label,
      icon: icon,
      foreground: semantic.warning,
      background: semantic.warningSurface,
      border: semantic.warning.withValues(alpha: 0.25),
      dense: dense,
    );
  }

  /// Warm accent: paid placement. Deliberately *not* green, so a sponsored tag
  /// can never read as a trust signal.
  factory AppBadge.sponsored(
    BuildContext context, {
    required String label,
    bool dense = false,
  }) {
    return AppBadge(
      label: label,
      icon: Icons.campaign_outlined,
      foreground: AppColorsIndicator.sponsoredForeground,
      background: AppColorsIndicator.sponsoredBackground,
      border: AppColorsIndicator.sponsoredBorder,
      dense: dense,
    );
  }

  /// Neutral: informational, no claim implied.
  factory AppBadge.neutral(
    BuildContext context, {
    required String label,
    IconData? icon,
    bool dense = false,
  }) {
    return AppBadge(
      label: label,
      icon: icon,
      foreground: AppColorsIndicator.neutralForeground,
      background: AppColorsIndicator.neutralBackground,
      border: AppColorsIndicator.neutralBorder,
      dense: dense,
    );
  }

  /// Red-ish: a closed or unavailable state.
  factory AppBadge.closed(BuildContext context, {required String label}) {
    return AppBadge(
      label: label,
      icon: Icons.schedule,
      foreground: AppColorsIndicator.closedForeground,
      background: AppColorsIndicator.closedBackground,
      border: AppColorsIndicator.closedBorder,
      dense: true,
    );
  }

  final String label;
  final IconData? icon;
  final Color? foreground;
  final Color? background;
  final Color? border;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = context.semantic;
    final Color fg = foreground ?? semantic.info;
    final Color bg = background ?? semantic.infoSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: border ?? fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: (dense
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.labelMedium)
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge colours that are specific to labels rather than to the palette, kept
/// together so sponsorship can never accidentally borrow the trust green.
class AppColorsIndicator {
  const AppColorsIndicator._();

  static const Color sponsoredForeground = AppColors.textTertiary;
  static const Color sponsoredBackground = Colors.transparent;
  static const Color sponsoredBorder = AppColors.textTertiary;

  static const Color neutralForeground = AppColors.textSecondary;
  static const Color neutralBackground = AppColors.surfaceMuted;
  static const Color neutralBorder = AppColors.border;

  static const Color closedForeground = Color(0xFF8A5A00);
  static const Color closedBackground = Color(0xFFFFF3E0);
  static const Color closedBorder = Color(0xFFEFD9B4);
}

/// The pair of trust labels, rendered together so their separation is visually
/// obvious and neither can be shown alone by accident.
class VerificationLabels extends StatelessWidget {
  const VerificationLabels({
    super.key,
    required this.phoneVerified,
    required this.credentialsVerified,
    this.claimsCredentials = false,
    this.dense = false,
    this.onExplain,
  });

  final bool phoneVerified;

  /// Only ever true after a real review. OTP never sets this.
  final bool credentialsVerified;

  /// True when the provider supplied registration details that have not been
  /// reviewed. Rendered as an amber claim, never as a green badge.
  final bool claimsCredentials;

  final bool dense;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final List<Widget> badges = <Widget>[
      if (phoneVerified)
        AppBadge.verified(
          context,
          label: strings.verifiedPhoneLabel,
          icon: Icons.phone_android,
          dense: dense,
        )
      else
        AppBadge.neutral(
          context,
          label: strings.notVerifiedLabel,
          icon: Icons.phone_disabled_outlined,
          dense: dense,
        ),
      if (credentialsVerified)
        AppBadge.verified(
          context,
          label: strings.verifiedCredentialsLabel,
          icon: Icons.school_outlined,
          dense: dense,
        )
      else if (claimsCredentials)
        AppBadge.claimed(
          context,
          label: strings.registrationClaimedLabel,
          icon: Icons.description_outlined,
          dense: dense,
        ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ...badges,
        if (onExplain != null)
          TextButton(
            onPressed: onExplain,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(strings.learnMoreShortLabel),
          ),
      ],
    );
  }
}
