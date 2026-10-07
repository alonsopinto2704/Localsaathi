import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_states.dart';

/// Daily availability for a single weekday, as a list of one or more windows.
///
/// A list rather than a single range because split hours are the norm for Indian
/// clinics and many small trades ("10am–1pm and 6pm–9pm"), and forcing that into
/// one range would lose real information.
class DayAvailability {
  const DayAvailability({required this.weekday, this.windows = const <HoursWindow>[]});

  final int weekday;
  final List<HoursWindow> windows;

  bool get isClosed => windows.isEmpty;

  DayAvailability copyWith({List<HoursWindow>? windows}) =>
      DayAvailability(weekday: weekday, windows: windows ?? this.windows);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'weekday': weekday,
        'windows': windows.map((HoursWindow w) => w.toJson()).toList(),
      };

  static DayAvailability fromJson(Map<String, dynamic> json) => DayAvailability(
        weekday: (json['weekday'] as num).toInt(),
        windows: (json['windows'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(HoursWindow.fromJson)
            .toList(),
      );
}

/// One opening window, in minutes since midnight.
class HoursWindow {
  const HoursWindow({required this.openMinutes, required this.closeMinutes});

  const HoursWindow.nineToSix()
      : openMinutes = 9 * 60,
        closeMinutes = 18 * 60;

  final int openMinutes;
  final int closeMinutes;

  bool get isValid => closeMinutes > openMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'open': openMinutes,
        'close': closeMinutes,
      };

  static HoursWindow fromJson(Map<String, dynamic> json) => HoursWindow(
        openMinutes: (json['open'] as num).toInt(),
        closeMinutes: (json['close'] as num).toInt(),
      );
}

/// One editable window row inside a weekday card.
class HoursWindowEditor extends StatelessWidget {
  const HoursWindowEditor({
    super.key,
    required this.window,
    required this.onOpenChanged,
    required this.onCloseChanged,
    this.onRemove,
  });

  final HoursWindow window;
  final ValueChanged<int> onOpenChanged;
  final ValueChanged<int> onCloseChanged;
  final VoidCallback? onRemove;

  Future<void> _pick(
    BuildContext context, {
    required int current,
    required ValueChanged<int> onChanged,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      // 12-hour clock with am/pm matches how the copy is written elsewhere.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TimeField(
              label: strings.openingTimeLabel,
              minutes: window.openMinutes,
              onTap: () => _pick(
                context,
                current: window.openMinutes,
                onChanged: onOpenChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _TimeField(
              label: strings.closingTimeLabel,
              minutes: window.closeMinutes,
              onTap: () => _pick(
                context,
                current: window.closeMinutes,
                onChanged: onCloseChanged,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: strings.remove,
              icon: const Icon(Icons.close),
            ),
          if (!window.isValid)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(Icons.error_outline, size: 18),
            ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        child: Text(
          _format(minutes),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  static String _format(int minutes) {
    final int hour = (minutes ~/ 60) % 24;
    final int minute = minutes % 60;
    final String suffix = hour < 12 ? 'am' : 'pm';
    int display = hour % 12;
    if (display == 0) display = 12;
    final String mm = minute < 10 ? '0$minute' : '$minute';
    return '$display:$mm $suffix';
  }
}

/// Provider sign-in / verification.
///
/// Three phases on one screen: enter the number, enter the code, then continue.
/// The important behaviour is what happens *after* a correct code — if the
/// number already owns a profile the provider is signed in to it, never asked to
/// register again, and never shown profile data before verifying.
class PhoneVerificationPanel extends StatelessWidget {
  const PhoneVerificationPanel({
    super.key,
    required this.phoneController,
    required this.otpController,
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.onChangeNumber,
    required this.onResend,
    this.onContinue,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final Future<void> Function() onRequestCode;
  final Future<void> Function() onVerifyCode;
  final VoidCallback onChangeNumber;
  final Future<void> Function() onResend;

  /// Shown after a successful verification of a number with an existing
  /// profile: continuing goes to the dashboard, not to the wizard.
  final Future<void> Function()? onContinue;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ProviderSignInViewState>();
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.providerAuthTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(strings.providerAuthBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),

        if (settings.showDevelopmentNotice)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppBanner.development(
              message: strings.developmentOtpNotice,
              title: strings.sampleDataLabel,
            ),
          ),

        if (settings.phase == SignInPhase.phone) ...<Widget>[
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 14,
            decoration: InputDecoration(
              labelText: strings.phoneNumberLabel,
              hintText: strings.phoneNumberHint,
              prefixText: '${AppConfig.defaultDialCode} ',
              counterText: '',
              prefixIcon: const Icon(Icons.phone_android),
            ),
            onChanged: (_) => settings.notify(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: settings.isBusy ? null : () => onRequestCode(),
            child: settings.isBusy
                ? const _ButtonSpinner()
                : Text(strings.sendOtp),
          ),
        ],

        if (settings.phase == SignInPhase.otp) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${strings.otpSentTo} ${settings.pendingPhonePretty ?? ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: onChangeNumber,
                child: Text(strings.changeNumber),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: strings.otpLabel,
              counterText: '',
              prefixIcon: const Icon(Icons.password),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: settings.isBusy ? null : () => onVerifyCode(),
            child: settings.isBusy
                ? const _ButtonSpinner()
                : Text(strings.verifyOtp),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: settings.isBusy ? null : () => onResend(),
            child: Text(strings.resendOtp),
          ),
        ],

        if (settings.phase == SignInPhase.verifiedExisting) ...<Widget>[
          AppBanner(
            message: strings.duplicateNumberMessage,
            title: strings.duplicateNumberTitle,
            tone: AppBannerTone.info,
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onContinue != null)
            FilledButton(
              onPressed: () => onContinue!(),
              child: Text(strings.openProviderDashboard),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onChangeNumber,
            child: Text(strings.changeNumber),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.providerRulesTitle),
        _Rule(text: strings.oneNumberOneProfile),
        _Rule(text: strings.addMoreServicesHint),
        _Rule(text: strings.changeNumberHint),
        _Rule(text: strings.whatsappSeparateConsent),
        const SizedBox(height: AppSpacing.md),
        AppBanner(
          message: strings.verificationCareNote,
          tone: AppBannerTone.caution,
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
}

/// The phases of the provider sign-in panel.
enum SignInPhase { phone, otp, verifiedExisting }

/// Small view-model the panel reads.
///
/// Kept separate from [SessionController] so the panel can be rendered in
/// isolation by a test without a real session, and so the phone field's
/// rebuild-on-keystroke behaviour does not touch the auth controller.
class ProviderSignInViewState extends ChangeNotifier {
  ProviderSignInViewState({
    this.phase = SignInPhase.phone,
    this.isBusy = false,
    this.pendingPhonePretty,
    this.showDevelopmentNotice = AppConfig.useDevelopmentOtpSimulation,
  });

  SignInPhase phase;
  bool isBusy;
  String? pendingPhonePretty;
  final bool showDevelopmentNotice;

  void notify() => notifyListeners();
}
