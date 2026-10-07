import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/l10n/app_localizations.dart';
import 'package:localsaathi/features/provider/onboarding/onboarding_widgets.dart';
import 'package:provider/provider.dart';

// Phase 058: the verification panel in every supported language, at 2x text,
// with assistive technology on. Real TalkBack on a device is NOT covered here
// (tasks/evidence/phase-058.md lists that as a manual step).
Widget _host(Locale locale, ProviderSignInViewState state, {double scale = 1}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ChangeNotifierProvider<ProviderSignInViewState>.value(
          value: state,
          child: PhoneVerificationPanel(
            phoneController: TextEditingController(),
            otpController: TextEditingController(),
            onRequestCode: () async {},
            onVerifyCode: () async {},
            onChangeNumber: () {},
            onResend: () async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final String code in <String>['en', 'hi', 'mr']) {
    final AppStrings strings = AppLocalizations.stringsForCode(code);

    group('verification panel [$code]', () {
      testWidgets('phone step at 2x text: no overflow, labelled field, fillable', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(Locale(code), ProviderSignInViewState(), scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(strings.sendOtp), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(strings.phoneNumberLabel))), findsWidgets);
        final TextField field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.autofillHints, contains(AutofillHints.telephoneNumberNational));
        expect(field.keyboardType, TextInputType.phone);
        handle.dispose();
      });

      testWidgets('code step at 2x text: paste hint, one-time-code autofill, delayed-SMS help', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final ProviderSignInViewState state = ProviderSignInViewState(
          phase: SignInPhase.otp,
        )..pendingPhonePretty = '+91 90000 40001';
        await tester.pumpWidget(_host(Locale(code), state, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(strings.otpPasteHint), findsOneWidget);
        expect(find.text(strings.otpDelayedHelp), findsOneWidget);
        final TextField field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
        expect(field.keyboardType, TextInputType.number);
        handle.dispose();
      });

      testWidgets('resend is disabled with a stable spoken description while waiting', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final ProviderSignInViewState state = ProviderSignInViewState(phase: SignInPhase.otp)
          ..resendAvailableAt = DateTime.now().add(const Duration(seconds: 45));
        await tester.pumpWidget(_host(Locale(code), state));
        await tester.pumpAndSettle();
        final Finder resend = find.bySemanticsLabel(RegExp(RegExp.escape(strings.otpResendWaitingLabel)));
        expect(resend, findsOneWidget);
        final SemanticsNode node = tester.getSemantics(resend);
        // ignore: deprecated_member_use
        expect(node.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
        // ignore: deprecated_member_use
        expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
        expect(find.textContaining('45'), findsWidgets, reason: 'visible countdown');
        // Once the wait is over the button is enabled and the plain label returns.
        state.resendAvailableAt = DateTime.now().subtract(const Duration(seconds: 1));
        state.notify();
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(strings.resendOtp)}\$')), findsOneWidget);
        handle.dispose();
      });
    });
  }

  testWidgets('pasted codes keep digits in any script and spaces; letters are dropped', (WidgetTester tester) async {
    final ProviderSignInViewState state = ProviderSignInViewState(phase: SignInPhase.otp);
    await tester.pumpWidget(_host(const Locale('en'), state));
        await tester.pumpAndSettle();
    final Finder field = find.byType(TextField).first;
    await tester.enterText(field, '१२३ 456 abc');
    expect(tester.widget<TextField>(field).controller!.text, '१२३ 456 ');
  });

  testWidgets('pasted numbers keep +, separators and digits', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const Locale('en'), ProviderSignInViewState()));
        await tester.pumpAndSettle();
    final Finder field = find.byType(TextField).first;
    await tester.enterText(field, '+91 (90000)-12345 x#');
    expect(tester.widget<TextField>(field).controller!.text, '+91 (90000)-12345 ');
  });

  testWidgets('the development banner is a demo-only element and says so', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const Locale('en'), ProviderSignInViewState()));
        await tester.pumpAndSettle();
    expect(find.text(const AppStringsEn().developmentOtpNotice), findsOneWidget);
    await tester.pumpWidget(_host(const Locale('en'), ProviderSignInViewState(showDevelopmentNotice: false)));
        await tester.pumpAndSettle();
    expect(find.text(const AppStringsEn().developmentOtpNotice), findsNothing);
  });
}
