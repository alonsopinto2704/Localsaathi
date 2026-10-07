import 'package:flutter/animation.dart';

/// Spacing, radius and sizing scale (8dp rhythm from the design blueprint).
///
/// Values are deliberately generous: comfortable spacing and large touch
/// targets matter on affordable Android phones used one-handed.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Gap between major blocks of a screen.
  static const double section = 28;
  static const double huge = 48;

  // Radii: 12 for buttons and inputs, 16 for cards, pills for chips.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  /// Minimum interactive dimension. Material guidance is 48dp; we use 48 as the
  /// floor for every tappable element.
  static const double minTouchTarget = 48;

  /// Profile avatar / logo sizes.
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 88;

  /// Horizontal page padding used by every screen scaffold.
  static const double pagePadding = 16;

  /// Above this width the app lays out like a website: top navigation and a
  /// centred content column instead of a phone-width stack.
  static const double wideBreakpoint = 840;

  /// Widest the content column grows on desktop browsers.
  static const double maxContentWidth = 1120;
}

/// Animation durations and curves.
///
/// Durations scale with distance: a small press is fast, a page entering is
/// slower. Entrances decelerate (they arrive and settle); nothing is linear.
class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Content fading and rising into place when a screen first shows data.
  static const Duration reveal = Duration(milliseconds: 420);

  /// Delay between siblings in a staggered reveal.
  static const Duration stagger = Duration(milliseconds: 50);
}

class AppCurves {
  const AppCurves._();

  /// Entrances: quick start, long soft landing.
  static const Curve enter = Curves.easeOutCubic;

  /// Direct feedback on a tap (bookmark, toggle): a small overshoot so it
  /// feels physical.
  static const Curve press = Curves.easeOutBack;
}
