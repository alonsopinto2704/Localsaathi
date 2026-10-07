import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controllers/app_settings_controller.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';

/// Language preference.
///
/// The picker is built from the localization layer, so a language becomes
/// selectable the moment its `AppStrings` subclass is registered. Partially
/// translated languages are labelled as such rather than hidden, because a
/// half-translated interface is still better than none for many users.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final AppSettingsController settings =
        context.watch<AppSettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text(strings.languagePreference)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Text(
            strings.languagePickerNote,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final ({String code, String name}) option
              in settings.languageOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () => settings.setLanguage(option.code),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: option.code == settings.languageCode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: option.code == settings.languageCode ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(option.name, style: theme.textTheme.bodyLarge),
                              if (option.code != 'en') ...<Widget>[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  strings.partialTranslationNotice,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (option.code == settings.languageCode)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
