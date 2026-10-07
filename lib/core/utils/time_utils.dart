import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Helpers for working with times of day, opening hours and formatting.
///
/// Kept dependency-free (no `intl` formatting) so the build stays lightweight;
/// this is intentional under "avoid packages that solve trivial problems".
class TimeUtils {
  const TimeUtils._();

  /// Minutes since midnight -> "9:30 am".
  static String formatMinutes(int minutesSinceMidnight, {bool use24Hour = false}) {
    final int m = ((minutesSinceMidnight % 1440) + 1440) % 1440;
    final int hour = m ~/ 60;
    final int minute = m % 60;
    if (use24Hour) {
      return '${_two(hour)}:${_two(minute)}';
    }
    final String suffix = hour < 12 ? 'am' : 'pm';
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return '$displayHour:${_two(minute)} $suffix';
  }

  static String formatTimeOfDay(TimeOfDay time, {bool use24Hour = false}) =>
      formatMinutes(time.hour * 60 + time.minute, use24Hour: use24Hour);

  static int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay timeOf(int minutesSinceMidnight) {
    final int m = ((minutesSinceMidnight % 1440) + 1440) % 1440;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static String _two(int value) => value < 10 ? '0$value' : '$value';
}

/// Localised weekday name from `DateTime.monday`-style numbering (1–7).
///
/// Lives in the theme/utils layer rather than in a screen because the working
/// hours editor and the public profile both need it, and they must agree.
String weekdayName(BuildContext context, int weekday) {
  final strings = context.strings;
  switch (weekday) {
    case DateTime.monday:
      return strings.dayMonday;
    case DateTime.tuesday:
      return strings.dayTuesday;
    case DateTime.wednesday:
      return strings.dayWednesday;
    case DateTime.thursday:
      return strings.dayThursday;
    case DateTime.friday:
      return strings.dayFriday;
    case DateTime.saturday:
      return strings.daySaturday;
    default:
      return strings.daySunday;
  }
}

/// Human-readable relative time for "requested on" style labels.
String formatShortDate(DateTime date) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Groups an integer using the Indian convention: 1,23,456.
/// Implemented directly rather than pulling in `intl`, which the MVP does not
/// otherwise need. When localization lands properly, `intl`'s
/// `NumberFormat.currency(locale: ...)` replaces this.
String groupIndianDigits(int value) {
  final bool negative = value < 0;
  final String digits = value.abs().toString();
  final String head = digits.length <= 3
      ? ''
      : digits.substring(0, digits.length - 3);
  final String tail = digits.length <= 3
      ? digits
      : digits.substring(digits.length - 3);

  final List<String> groups = <String>[];
  String remaining = head;
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  if (remaining.isNotEmpty) groups.insert(0, remaining);

  final String joined = <String>[...groups, tail].where((s) => s.isNotEmpty).join(',');
  return negative ? '-$joined' : joined;
}

/// Formats a rupee amount, e.g. `₹1,23,456`.
String formatRupees(num amount) => '₹${groupIndianDigits(amount.round())}';

/// Number formatting for dashboard statistics.
String formatCount(int value) => groupIndianDigits(value);
