import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/async_states.dart';
import '../../../domain/models/provider.dart';
import 'onboarding_widgets.dart';

/// Working-hours step.
///
/// Days with no windows are stored as closed and shown as closed. That matters
/// downstream: a provider who leaves Sunday empty gets "Closed now" on Sunday
/// rather than a blank, and a provider who sets nothing at all gets "hours not
/// provided" instead of a fabricated open status.
class OnboardingHoursStep extends StatelessWidget {
  const OnboardingHoursStep({
    super.key,
    required this.days,
    required this.onChanged,
  });

  final List<DayAvailability> days;
  final ValueChanged<List<DayAvailability>> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.stepHoursTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.onboardingIntroHours,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        AppBanner(
          message: strings.hoursIndicatorNote,
          icon: Icons.info_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (int i = 0; i < days.length; i++) _dayCard(context, i),
      ],
    );
  }

  Widget _dayCard(BuildContext context, int index) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final DayAvailability day = days[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      weekdayName(context, day.weekday),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  // A switch is clearer than a checkbox here: the two states are
                  // "open on this day" and "closed all day".
                  Switch(
                    value: !day.isClosed,
                    onChanged: (bool open) => _update(
                      index,
                      open
                          ? <HoursWindow>[const HoursWindow.nineToSix()]
                          : <HoursWindow>[],
                    ),
                  ),
                ],
              ),
              if (day.isClosed)
                Text(
                  strings.closedAllDay,
                  style: theme.textTheme.bodySmall,
                )
              else ...<Widget>[
                for (int w = 0; w < day.windows.length; w++)
                  HoursWindowEditor(
                    window: day.windows[w],
                    onOpenChanged: (int minutes) => _updateWindow(
                      index,
                      w,
                      HoursWindow(
                        openMinutes: minutes,
                        closeMinutes: day.windows[w].closeMinutes,
                      ),
                    ),
                    onCloseChanged: (int minutes) => _updateWindow(
                      index,
                      w,
                      HoursWindow(
                        openMinutes: day.windows[w].openMinutes,
                        closeMinutes: minutes,
                      ),
                    ),
                    // Split hours are supported, but only one window can be
                    // removed: the last one.
                    onRemove: day.windows.length > 1
                        ? () {
                            final List<HoursWindow> windows =
                                List<HoursWindow>.from(day.windows)..removeAt(w);
                            _update(index, windows);
                          }
                        : null,
                  ),
                TextButton.icon(
                  onPressed: () => _update(
                    index,
                    <HoursWindow>[
                      ...day.windows,
                      HoursWindow(
                        openMinutes: day.windows.last.closeMinutes,
                        closeMinutes: day.windows.last.closeMinutes + 60,
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(strings.addHoursWindow),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _update(int index, List<HoursWindow> windows) {
    final List<DayAvailability> next = List<DayAvailability>.from(days);
    next[index] = next[index].copyWith(windows: windows);
    onChanged(next);
  }

  void _updateWindow(int dayIndex, int windowIndex, HoursWindow window) {
    final List<HoursWindow> windows =
        List<HoursWindow>.from(days[dayIndex].windows);
    windows[windowIndex] = window;
    _update(dayIndex, windows);
  }
}

/// Monday-first list of seven days, each with the standard 9am–6pm window and
/// Sunday closed — the most common Indian small-business week, offered as a
/// starting point rather than a default the provider is stuck with.
List<DayAvailability> defaultDayAvailability() => <DayAvailability>[
      for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        DayAvailability(
          weekday: weekday,
          windows: weekday == DateTime.sunday
              ? const <HoursWindow>[]
              : <HoursWindow>[const HoursWindow.nineToSix()],
        ),
    ];

/// Converts the wizard's windows into the domain model.
///
/// A day with several windows is stored as its earliest-to-latest span, because
/// [DayHours] models one window per day. The narrowest honest choice is taken:
/// the service area and availability text still describes the real opening
/// times, and "open now" uses the span, which can only ever be more permissive
/// by the length of the lunch break. That trade-off is documented here rather
/// than hidden.
WorkingHours? workingHoursFromAvailability(List<DayAvailability> days) {
  final List<DayHours> converted = <DayHours>[];
  for (final DayAvailability day in days) {
    if (day.isClosed) {
      converted.add(DayHours.closed(day.weekday));
      continue;
    }
    int open = day.windows.first.openMinutes;
    int close = day.windows.first.closeMinutes;
    for (final HoursWindow window in day.windows) {
      if (window.openMinutes < open) open = window.openMinutes;
      if (window.closeMinutes > close) close = window.closeMinutes;
    }
    converted.add(
      DayHours(weekday: day.weekday, openMinutes: open, closeMinutes: close),
    );
  }
  final WorkingHours hours = WorkingHours(converted);
  return hours.hasAnyHours ? hours : null;
}

/// Rebuilds the editor's windows from stored hours.
List<DayAvailability> dayAvailabilityFromWorkingHours(WorkingHours hours) =>
    <DayAvailability>[
      for (final DayHours day in hours.days)
        DayAvailability(
          weekday: day.weekday,
          windows: day.isClosed
              ? const <HoursWindow>[]
              : <HoursWindow>[
                  HoursWindow(
                    openMinutes: day.openMinutes!,
                    closeMinutes: day.closeMinutes!,
                  ),
                ],
        ),
    ];
