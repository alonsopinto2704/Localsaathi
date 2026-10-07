import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_dependencies.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/engagement_repository.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/phone_number.dart';
import '../utils/time_utils.dart';
import 'provider_badges.dart';

/// Everything a card or profile needs to know about a provider's contact
/// readiness, computed in one place so no screen has to re-derive the rules.
class ContactAvailability {
  const ContactAvailability({
    required this.canCall,
    required this.canWhatsApp,
    required this.isDemoProfile,
    required this.maskedNumber,
    required this.workingHoursStatus,
  });

  factory ContactAvailability.of(ProviderProfile provider, {DateTime? now}) {
    final DateTime moment = now ?? WorkingHours.indiaNow();
    final bool? open = provider.workingHours?.isOpenAt(moment);
    final bool hasHours = provider.workingHours?.hasAnyHours ?? false;
    return ContactAvailability(
      canCall: provider.canBeCalled && provider.phoneDisplayConsented,
      // WhatsApp is independently optional; the provider may accept calls only.
      canWhatsApp: provider.canBeCalled && provider.whatsappEnabled,
      isDemoProfile: provider.isDemoProfile,
      maskedNumber: PhoneUtils.mask(provider.phoneE164),
      // `null` means we genuinely do not know, which must render as
      // "hours not provided", never as "closed".
      workingHoursStatus: !hasHours ? null : (open == true),
    );
  }

  final bool canCall;
  final bool canWhatsApp;
  final bool isDemoProfile;

  /// Pre-masked number, safe to display: the app never shows a full number for
  /// a demo profile.
  final String maskedNumber;

  /// `null` = unknown, `true` = open now, `false` = closed now.
  final bool? workingHoursStatus;

  bool get hasKnownHours => workingHoursStatus != null;

  bool get isOpenNow => workingHoursStatus == true;
}

/// Fires the contact actions and records the corresponding in-app tap.
///
/// Two rules are enforced here rather than in each screen:
///
/// 1. Demo profiles never dial. They explain that the profile is fictional,
///    because the seeded directory must not put anyone on a call with a
///    fabricated number.
/// 2. Only button taps are recorded. Nothing here claims a call was completed
///    or a job happened — the app cannot observe that.
///
/// The messenger and navigator are captured synchronously at construction, which
/// is what makes it safe to use them after an `await` without holding a
/// `BuildContext` across an async gap.
class ProviderContactActions {
  ProviderContactActions(BuildContext context)
      : _messenger = ScaffoldMessenger.of(context),
        _navigator = Navigator.of(context),
        _strings = context.strings,
        _engagement = context.read<AppDependencies>().engagement;

  final ScaffoldMessengerState _messenger;
  final NavigatorState _navigator;
  final AppStrings _strings;
  final EngagementRepository _engagement;

  Future<void> call(ProviderProfile provider) async {
    if (provider.isDemoProfile) {
      await _showDemoNotice(provider);
      return;
    }
    await _record(provider, EngagementEventType.callButtonTap);
    // The dialer launch is intentionally not wired in this build: no real
    // numbers exist yet. See README "Before production" for the `url_launcher`
    // integration and the `tel:` intent.
    _messenger.showSnackBar(SnackBar(content: Text(_strings.dialerNotWired)));
  }

  Future<void> whatsapp(ProviderProfile provider) async {
    if (!provider.whatsappEnabled || !provider.phoneDisplayConsented) {
      // Handled gracefully: the button is normally absent entirely.
      _messenger.showSnackBar(
        SnackBar(content: Text(_strings.whatsappUnavailable)),
      );
      return;
    }
    if (provider.isDemoProfile) {
      await _showDemoNotice(provider);
      return;
    }
    await _record(provider, EngagementEventType.whatsappButtonTap);
    _messenger.showSnackBar(
      SnackBar(content: Text(_strings.whatsappNotWired)),
    );
  }

  /// Opens the native Android share sheet.
  Future<void> share(ProviderProfile provider, {String? cityName}) async {
    await _record(provider, EngagementEventType.shareTap);
    final String category = provider.categoryIds.isEmpty
        ? ''
        : provider.categoryIds.first.replaceAll('-', ' ');
    final StringBuffer buffer = StringBuffer()
      ..writeln(_strings.shareProfileMessage)
      ..writeln()
      ..writeln(provider.displayName);
    if (category.isNotEmpty) buffer.writeln(category);
    if (cityName != null) buffer.writeln(cityName);
    buffer.writeln('${AppConfig.shareBaseUrl}/p/${provider.id}');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: provider.displayName,
      ),
    );
  }

  Future<void> _record(ProviderProfile provider, EngagementEventType type) async {
    try {
      await _engagement.record(
        providerId: provider.id,
        type: type,
        cityId: provider.baseCityId,
        localityId: provider.baseLocalityId,
      );
    } on Object {
      // Analytics must never break a contact action.
    }
  }

  Future<void> _showDemoNotice(ProviderProfile provider) async {
    await showDialog<void>(
      context: _navigator.context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.science_outlined),
        title: Text(_strings.demoProfileNoticeTitle),
        content: Text(
          '${_strings.demoProfileNotice}\n\n'
          '${provider.displayName} · ${ContactAvailability.of(provider).maskedNumber}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_strings.close),
          ),
        ],
      ),
    );
  }
}

/// The row of contact buttons used on cards and on the profile.
///
/// WhatsApp renders as a disabled, explained control when the provider has not
/// enabled it, so its absence is never a mystery.
class ProviderContactButtons extends StatelessWidget {
  const ProviderContactButtons({
    super.key,
    required this.provider,
    this.compact = false,
    this.onCallStarted,
    this.onWhatsAppStarted,
  });

  final ProviderProfile provider;
  final bool compact;
  final VoidCallback? onCallStarted;
  final VoidCallback? onWhatsAppStarted;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ContactAvailability availability = ContactAvailability.of(provider);
    final ProviderContactActions actions = ProviderContactActions(context);
    final bool canCall = availability.canCall;
    final bool canWhatsApp = provider.whatsappEnabled;

    // No consent to display a number: an explained, disabled control instead
    // of a dead button.
    final Widget callButton = FilledButton.icon(
      onPressed: canCall
          ? () {
              onCallStarted?.call();
              actions.call(provider);
            }
          : null,
      icon: Icon(canCall ? Icons.call : Icons.phone_disabled_outlined, size: 20),
      label: Text(
        canCall ? strings.callNow : strings.contactNumberHiddenShort,
        overflow: TextOverflow.ellipsis,
      ),
    );

    void openWhatsApp() {
      onWhatsAppStarted?.call();
      actions.whatsapp(provider);
    }

    final ButtonStyle whatsAppStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.whatsapp,
      foregroundColor: Colors.white,
    );

    if (compact) {
      return Row(
        children: <Widget>[
          Expanded(child: callButton),
          if (canWhatsApp) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            SizedBox.square(
              dimension: AppSpacing.minTouchTarget,
              child: Tooltip(
                message: strings.whatsapp,
                child: FilledButton(
                  onPressed: openWhatsApp,
                  style: whatsAppStyle.copyWith(
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.zero,
                    ),
                  ),
                  child: const Icon(Icons.chat_outlined, size: 20),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: callButton),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: canWhatsApp
              ? FilledButton.icon(
                  onPressed: openWhatsApp,
                  style: whatsAppStyle,
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  label: Text(strings.whatsapp),
                )
              : OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  label: Text(
                    strings.whatsappUnavailable,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Formats an "Open now / Closed now" chip from a provider's hours.
///
/// Unknown hours render as "hours not provided", which is the requirement:
/// never imply availability we cannot support.
class WorkingHoursStatusChip extends StatelessWidget {
  const WorkingHoursStatusChip({super.key, required this.availability});

  final ContactAvailability availability;

  @override
  Widget build(BuildContext context) =>
      WorkingHoursChip(status: availability.workingHoursStatus);
}

/// Formats a working-hours summary line from the weekly schedule.
String formatWorkingHoursSummary(
  WorkingHours? hours, {
  required String closedLabel,
  bool use24Hour = false,
}) {
  if (hours == null || !hours.hasAnyHours) return '';
  if (hours.isOpenAroundTheClock) {
    return '24 h';
  }

  // Group consecutive days with identical windows so the summary stays short:
  // "Mon–Sat 9:00 am – 8:00 pm, Sun closed".
  final List<String> parts = <String>[];
  final List<DayHours> days = hours.days;
  int index = 0;
  while (index < days.length) {
    final DayHours start = days[index];
    int end = index;
    while (end + 1 < days.length &&
        days[end + 1].isClosed == start.isClosed &&
        days[end + 1].openMinutes == start.openMinutes &&
        days[end + 1].closeMinutes == start.closeMinutes) {
      end++;
    }
    final String range = index == end
        ? _shortDay(start.weekday)
        : '${_shortDay(start.weekday)}–${_shortDay(days[end].weekday)}';
    if (start.isClosed) {
      parts.add('$range $closedLabel');
    } else {
      parts.add('$range ${TimeUtils.formatMinutes(start.openMinutes!, use24Hour: use24Hour)}'
          ' – ${TimeUtils.formatMinutes(start.closeMinutes!, use24Hour: use24Hour)}');
    }
    index = end + 1;
  }
  return parts.join(', ');
}

String _shortDay(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
  }
}
