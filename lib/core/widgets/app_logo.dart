import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The LocalSaathi mark: a teal tile, a white map pin standing on a soft
/// "neighbourhood" ground, and an amber check in the pin head (a verified,
/// trusted local). Painted from geometry, so it is crisp at any size and the
/// launcher/web icons (tool/make_icons.py) share the same proportions.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LocalSaathi',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: const LogoPainter()),
    );
  }
}

class LogoPainter extends CustomPainter {
  const LogoPainter({this.tile = true});

  /// False paints only the pin and check (for an adaptive launcher icon's
  /// foreground, where the platform supplies the tile shape).
  final bool tile;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.28)),
        Paint()..color = AppColors.teal700,
      );
    }

    // Ground: where the pin stands.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, w * 0.80),
        width: w * 0.46,
        height: w * 0.12,
      ),
      Paint()..color = AppColors.teal600,
    );

    // Teardrop pin: a circle joined to the tip by its two tangents.
    final double cx = w * 0.5;
    final double cy = w * 0.40;
    final double r = w * 0.22;
    final double tipY = w * 0.80;
    final double phi = math.acos(r / (tipY - cy));
    final Path pin = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx - r * math.sin(phi), cy + r * math.cos(phi))
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi / 2 + phi,
        2 * math.pi - 2 * phi,
        false,
      )
      ..close();
    canvas.drawPath(pin, Paint()..color = Colors.white);

    // Check mark in the pin head.
    final Path check = Path()
      ..moveTo(cx - w * 0.095, cy + w * 0.005)
      ..lineTo(cx - w * 0.025, cy + w * 0.07)
      ..lineTo(cx + w * 0.10, cy - w * 0.065);
    canvas.drawPath(
      check,
      Paint()
        ..color = AppColors.accent500
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(LogoPainter oldDelegate) => oldDelegate.tile != tile;
}

/// Logo plus a two-tone wordmark, with an optional line underneath (e.g. the
/// current tab).
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.subtitle, this.logoSize = 34});

  final String? subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? base = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppLogo(size: logoSize),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: 'Local'),
                  TextSpan(
                    text: 'Saathi',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ),
              style: base,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
