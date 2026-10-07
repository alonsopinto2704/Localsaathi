import '../config/app_config.dart';

/// Result of normalising a user-supplied phone number.
class NormalizedPhone {
  const NormalizedPhone({
    required this.e164,
    required this.dialCode,
    required this.nationalNumber,
  });

  /// Canonical form stored and compared everywhere: `+91XXXXXXXXXX`.
  ///
  /// Uniqueness is enforced on this exact string (see the mock repository and
  /// README "Production work": a database unique constraint on this column).
  final String e164;

  /// Dialling code without the leading `+`, e.g. `91`.
  final String dialCode;

  /// Subscriber number without the dialling code, e.g. `9876543210`.
  final String nationalNumber;

  String get pretty => '$dialCode $nationalNumber';

  @override
  String toString() => e164;

  @override
  bool operator ==(Object other) =>
      other is NormalizedPhone && other.e164 == e164;

  @override
  int get hashCode => e164.hashCode;
}

/// Why a phone number failed to normalise.
enum PhoneValidationError {
  empty,
  tooShort,
  tooLong,
  notNumeric,
  unsupportedDialCode,
  invalidIndianMobile,
}

/// Normalises and validates phone numbers.
///
/// Deliberately strict about the launch market: Indian mobiles are 10 digits
/// starting 6-9. Everything is reduced to E.164 before storage or comparison so
/// that `098765 43210`, `+91 98765-43210` and `9876543210` cannot become three
/// accounts.
class PhoneUtils {
  const PhoneUtils._();

  /// Dial codes the normaliser understands. Adding a country is a data change.
  static const Map<String, int> supportedDialCodes = <String, int>{
    '91': 10,
  };

  static final RegExp _digitsOnly = RegExp(r'\D');

  /// Strips formatting and returns digits plus a leading `+` when present.
  static bool looksLikeInternational(String raw) =>
      raw.trimLeft().startsWith('+');

  /// Returns the national significant digits for [raw], ignoring formatting.
  static String digitsOf(String raw) => raw.replaceAll(_digitsOnly, '');

  /// Converts [raw] to a canonical [NormalizedPhone].
  ///
  /// Accepts, for a +91 number: `9876543210`, `09876543210`,
  /// `+91 98765 43210`, `0091-9876543210`, `91 9876543210`.
  static NormalizedPhone? tryNormalize(
    String raw, {
    String? defaultDialCode,
    void Function(PhoneValidationError)? onError,
  }) {
    final String defaultCode =
        (defaultDialCode ?? AppConfig.defaultDialCode).replaceAll('+', '');
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      onError?.call(PhoneValidationError.empty);
      return null;
    }

    final String digits = digitsOf(trimmed);
    if (digits.isEmpty) {
      onError?.call(PhoneValidationError.notNumeric);
      return null;
    }

    // Strip an international prefix written as 00.
    String working = digits;
    if (working.startsWith('00')) working = working.substring(2);

    String? dialCode;
    String national = working;

    if (trimmed.startsWith('+')) {
      for (final String code in supportedDialCodes.keys) {
        if (working.startsWith(code)) {
          dialCode = code;
          national = working.substring(code.length);
          break;
        }
      }
      if (dialCode == null) {
        onError?.call(PhoneValidationError.unsupportedDialCode);
        return null;
      }
    } else if (working.startsWith(defaultCode) &&
        working.length > supportedDialCodes[defaultCode]!) {
      // Bare dial code without a plus, e.g. 919876543210.
      dialCode = defaultCode;
      national = working.substring(defaultCode.length);
    } else if (working.startsWith('0')) {
      // Domestic trunk prefix.
      national = working.replaceFirst(RegExp(r'^0+'), '');
      dialCode = defaultCode;
    } else {
      dialCode = defaultCode;
    }

    final int? expectedLength = supportedDialCodes[dialCode];
    if (expectedLength == null) {
      onError?.call(PhoneValidationError.unsupportedDialCode);
      return null;
    }
    if (national.length < expectedLength) {
      onError?.call(PhoneValidationError.tooShort);
      return null;
    }
    if (national.length > expectedLength) {
      onError?.call(PhoneValidationError.tooLong);
      return null;
    }
    // Indian mobile numbers start 6-9. Landlines are not supported for
    // provider accounts because OTP delivery and WhatsApp both need a mobile.
    if (dialCode == '91' && !RegExp(r'^[6-9]').hasMatch(national)) {
      onError?.call(PhoneValidationError.invalidIndianMobile);
      return null;
    }

    return NormalizedPhone(
      e164: '+$dialCode$national',
      dialCode: dialCode,
      nationalNumber: national,
    );
  }

  static NormalizedPhone? tryNormalizeNational(
    String raw, {
    void Function(PhoneValidationError)? onError,
  }) =>
      tryNormalize(raw,
          defaultDialCode: AppConfig.defaultDialCode, onError: onError);

  static bool isValid(String raw) => tryNormalize(raw) != null;

  /// `+919876543210` -> `+91 98765 43210`
  static String formatPretty(String e164) {
    final String digits = digitsOf(e164);
    if (digits.length == 12 && digits.startsWith('91')) {
      final String n = digits.substring(2);
      return '+91 ${n.substring(0, 5)} ${n.substring(5)}';
    }
    return e164;
  }

  /// Local-call friendly form, e.g. `98765 43210`.
  static String formatNational(String e164) {
    final String digits = digitsOf(e164);
    if (digits.length == 12 && digits.startsWith('91')) {
      final String n = digits.substring(2);
      return '${n.substring(0, 5)} ${n.substring(5)}';
    }
    return digits;
  }

  /// Masks all but the last two digits. Used by demo profiles so the seeded
  /// directory never contains a usable real-looking phone number.
  static String mask(String e164) {
    final String digits = digitsOf(e164);
    if (digits.length < 4) return '••••';
    final String tail = digits.substring(digits.length - 2);
    final String head = digits.substring(0, digits.length - 2);
    return '+${'•' * head.length}$tail';
  }

  /// Demo numbers use this reserved-for-fiction prefix pattern so they are
  /// obviously not real subscriber numbers.
  static const String demoNumberSuffix = '000';
}
