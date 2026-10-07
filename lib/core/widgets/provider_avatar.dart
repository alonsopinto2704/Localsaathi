import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Circular avatar that shows a provider's initials until they add a photo.
///
/// Initials fall back gracefully: no provider is ever rendered as a blank
/// circle, which matters on a card list where the image is the fastest way to
/// recognise a familiar name.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.assetPath,
    this.size = AppSpacing.avatarMd,
    this.isVerified = false,
  });

  final String initials;
  final String? imageUrl;
  final String? assetPath;
  final double size;

  /// Draws a small verified check on the avatar. Only used for phone
  /// verification, never for claims.
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget inner;
    if (assetPath != null) {
      inner = Image.asset(
        assetPath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing bundled asset must not break the card.
        errorBuilder: (_, __, ___) => _initials(theme),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      inner = Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) =>
            progress == null ? child : _initials(theme),
        errorBuilder: (_, __, ___) => _initials(theme),
      );
    } else {
      inner = _initials(theme);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipOval(
            child: SizedBox(width: size, height: size, child: inner),
          ),
          if (isVerified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  size: size * 0.32,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initials(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

/// A selected-tile used by category and locality pickers.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.bodyLarge),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
