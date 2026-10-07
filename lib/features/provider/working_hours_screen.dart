import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/provider.dart';
import 'onboarding/onboarding_hours_step.dart';
import 'onboarding/onboarding_widgets.dart';

/// Working hours editor.
///
/// Opened from onboarding and from the dashboard, so a provider can fix their
/// hours without walking the whole wizard again. Hours are the input to the
/// "Open now" filter, which is why they are editable directly rather than buried.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key, required this.initial});

  final WorkingHours? initial;

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  late List<DayAvailability> _days;

  @override
  void initState() {
    super.initState();
    _days = widget.initial == null
        ? defaultDayAvailability()
        : dayAvailabilityFromWorkingHours(widget.initial!);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.workingHoursTitle)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: OnboardingHoursStep(
              days: _days,
              onChanged: (List<DayAvailability> days) =>
                  setState(() => _days = days),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.md,
                AppSpacing.pagePadding,
                AppSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(
                        () => _days = defaultDayAvailability(),
                      ),
                      child: Text(strings.reset),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        workingHoursFromAvailability(_days),
                      ),
                      child: Text(strings.save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
