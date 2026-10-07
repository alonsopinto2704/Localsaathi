import 'package:flutter/material.dart';

/// Brand palette, from the "Local Utility Trust" design blueprint
/// (stitch_localsaathi_android_ui_ux_blueprint/local_utility_trust/DESIGN.md).
///
/// Deep teal for actions and navigation, cool neutral surfaces, and one warm
/// accent used sparingly. Two blueprint values were darkened because they fail
/// 4.5:1 with their text: the WhatsApp green (#16A34A → #15803D) and the
/// verified-badge text (#0D9488 → primary teal).
class AppColors {
  const AppColors._();

  // Primary: deep teal.
  static const Color teal900 = Color(0xFF0B4F4A);
  static const Color teal800 = Color(0xFF115E59); // pressed / hover
  static const Color teal700 = Color(0xFF0F766E); // primary
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal100 = Color(0xFFD5EEEA);
  static const Color teal50 = Color(0xFFE6F4F2); // primary tint

  // Warm accent: used for one or two focal moments per screen.
  static const Color accent700 = Color(0xFF92400E); // text on accent100
  static const Color accent500 = Color(0xFFF4B740);
  static const Color accent100 = Color(0xFFFEF3C7);

  // Neutrals.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9FA);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF172B35);
  static const Color textSecondary = Color(0xFF52616B);
  static const Color textTertiary = Color(0xFF64748B);

  /// Decorative only (inactive icons, dividers): fails text contrast.
  static const Color muted = Color(0xFF94A3B8);

  // Status.
  static const Color success = Color(0xFF15803D);
  static const Color successSurface = Color(0xFFE9F7EF);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color infoSurface = Color(0xFFE8F1FE);
  static const Color info = Color(0xFF1B5FB8);

  static const Color whatsapp = Color(0xFF15803D);
}
