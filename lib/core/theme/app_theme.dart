import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// The single source of truth for the app's look and feel.
///
/// Screens must not construct ad-hoc [TextStyle]s or hardcode colours; they
/// should pull from [Theme.of] or from the extensions registered in
/// [AppTheme.light].
class AppTheme {
  const AppTheme._();

  /// Bundled in assets/fonts (Plus Jakarta Sans, SIL Open Font License).
  /// Devanagari falls back to the system Noto Sans Devanagari.
  static const String fontFamily = 'PlusJakartaSans';

  /// Level 1 elevation from the blueprint: a hairline plus a very soft shadow.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F172B35),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color(0x0A172B35),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal700,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.teal700,
      onPrimary: Colors.white,
      primaryContainer: AppColors.teal50,
      onPrimaryContainer: AppColors.teal900,
      secondary: AppColors.accent500,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: AppColors.accent100,
      onSecondaryContainer: AppColors.accent700,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.textTertiary,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
    );

    final TextTheme text = _textTheme();
    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _RiseInPageTransitionsBuilder(),
          // Same motion in browsers, where the app runs as the website.
          TargetPlatform.windows: _RiseInPageTransitionsBuilder(),
          TargetPlatform.macOS: _RiseInPageTransitionsBuilder(),
          TargetPlatform.linux: _RiseInPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // A faint rule appears only once content slides under the bar.
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + AppSpacing.xxs,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textTertiary),
        prefixIconColor: AppColors.textTertiary,
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.teal700, width: 2),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          shape: buttonShape,
        ).copyWith(
          // Blueprint pressed state: #115E59.
          overlayColor: const WidgetStatePropertyAll<Color>(Color(0x1F000000)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: const BorderSide(color: AppColors.teal700, width: 1.5),
          foregroundColor: AppColors.teal700,
          textStyle: text.labelLarge,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          foregroundColor: AppColors.teal700,
          textStyle: text.labelLarge,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.teal700,
        secondarySelectedColor: AppColors.teal700,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.teal700,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: text.labelSmall,
        unselectedLabelStyle: text.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.teal50,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.teal700
                : AppColors.textTertiary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.teal700
                : AppColors.textTertiary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        // Sheets stay phone-width even when the app runs as a wide website.
        constraints: BoxConstraints(maxWidth: 640),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.teal700,
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal700,
        linearMinHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teal700;
          return AppColors.border;
        }),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppSemanticColors.light,
      ],
    );
  }

  /// Dark theme is intentionally not designed yet. Providing it keeps layout
  /// tests honest; the brand direction for the MVP is light backgrounds.
  static ThemeData dark() => light();

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Blueprint type scale: headline-lg 24, headline-md 20, headline-sm 18,
  /// body 16/15, labels 15/13/12.
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineMedium: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.24),
      headlineSmall: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      titleLarge: TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
      bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, letterSpacing: 0.075),
      bodySmall: TextStyle(fontSize: 13, height: 18 / 13),
      labelLarge: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      labelMedium: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, letterSpacing: 0.13),
      labelSmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.24),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
  }
}

/// Pushed screens fade in while rising a short distance; popping plays it in
/// reverse, so the leaving screen accelerates away instead of drifting.
///
/// Opacity finishes early (first 60%) so the two screens overlap only briefly.
class _RiseInPageTransitionsBuilder extends PageTransitionsBuilder {
  const _RiseInPageTransitionsBuilder();

  static final Animatable<double> _fade =
      CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut));
  static final Animatable<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).chain(CurveTween(curve: AppCurves.enter));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(_fade),
      child: SlideTransition(position: animation.drive(_rise), child: child),
    );
  }
}

/// Semantic colours that are not part of [ColorScheme], exposed as a theme
/// extension so widgets never import the palette directly.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.errorSurface,
    required this.info,
    required this.infoSurface,
    required this.accentSurface,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.success,
    successSurface: AppColors.successSurface,
    warning: AppColors.warning,
    warningSurface: AppColors.warningSurface,
    errorSurface: AppColors.errorSurface,
    info: AppColors.info,
    infoSurface: AppColors.infoSurface,
    accentSurface: AppColors.accent100,
  );

  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color errorSurface;
  final Color info;
  final Color infoSurface;
  final Color accentSurface;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? errorSurface,
    Color? info,
    Color? infoSurface,
    Color? accentSurface,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      errorSurface: errorSurface ?? this.errorSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      accentSurface: accentSurface ?? this.accentSurface,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
    );
  }
}

/// Convenience accessor: `context.semantic.success`.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
