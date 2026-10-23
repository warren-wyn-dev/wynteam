import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'zoky_colors.dart';
import 'zoky_tokens.dart';
import 'zoky_typography.dart';

/// ColorScheme per design section 12.1. primary = Pink Deep #D61256 (D1);
/// the logo pink #F21967 stays in [ZokyColors.brand] for icons/indicators.
const ColorScheme zokyColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: ZokyColors.actionPrimary,
  onPrimary: ZokyColors.onAction,
  primaryContainer: ZokyColors.blush,
  onPrimaryContainer: ZokyColors.berry,
  secondary: ZokyColors.berry,
  onSecondary: ZokyColors.onAction,
  tertiary: ZokyColors.wine,
  onTertiary: ZokyColors.onAction,
  error: ZokyColors.error,
  onError: ZokyColors.onError,
  errorContainer: ZokyColors.errorContainer,
  onErrorContainer: ZokyColors.onErrorContainer,
  surface: ZokyColors.surface,
  onSurface: ZokyColors.textPrimary,
  onSurfaceVariant: ZokyColors.textSecondary,
  surfaceContainerLowest: ZokyColors.surface,
  surfaceContainerLow: ZokyColors.canvas,
  surfaceContainer: ZokyColors.sunken,
  surfaceContainerHigh: ZokyColors.chip,
  surfaceContainerHighest: ZokyColors.borderSubtle,
  outline: ZokyColors.borderControl,
  outlineVariant: ZokyColors.borderSubtle,
  shadow: ZokyColors.textPrimary,
  scrim: ZokyColors.textPrimary,
  inverseSurface: ZokyColors.neutral900,
  onInverseSurface: ZokyColors.neutral0,
  inversePrimary: ZokyColors.brandSoft,
  // Never let M3 tint cards/sheets pink (design 6.3).
  surfaceTint: Colors.transparent,
);

/// Light-only ThemeData for v1 (design 3.6 / Q1: web Food has no dark mode).
///
/// The platform is intentionally *not* fixed here: Theme.of(context).platform
/// follows defaultTargetPlatform, which is what the adaptive helpers switch
/// on (and what debugDefaultTargetPlatformOverride changes in tests).
ThemeData buildZokyTheme() {
  final textTheme = ZokyTextStyles.textTheme();
  const pillShape = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: zokyColorScheme,
    scaffoldBackgroundColor: ZokyColors.canvas,
    canvasColor: ZokyColors.canvas,
    fontFamily: ZokyTextStyles.fontFamily,
    fontFamilyFallback: ZokyTextStyles.fontFamilyFallback,
    textTheme: textTheme,
    focusColor: ZokyColors.focus.withValues(alpha: 0.12),
    splashFactory: InkSparkle.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ZokyColors.surface,
      foregroundColor: ZokyColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: const CardThemeData(
      color: ZokyColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: ZokyRadius.lg),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ZokyColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ZokyColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: ZokyColors.surface,
      showDragHandle: true,
      dragHandleColor: ZokyColors.neutral200,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ZokyRadius.xxlValue),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZokyColors.actionPrimary,
        foregroundColor: ZokyColors.onAction,
        disabledBackgroundColor: ZokyColors.actionDisabledBg,
        disabledForegroundColor: ZokyColors.actionDisabledText,
        minimumSize: const Size(64, ZokySizes.buttonMd),
        shape: pillShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ZokyColors.textLink,
        textStyle: ZokyTextStyles.weight(
          textTheme.labelMedium!,
          FontWeight.w700,
        ),
        shape: pillShape,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ZokyColors.actionPrimary
            : ZokyColors.neutral100,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ZokyColors.neutral0
            : ZokyColors.borderControl,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ZokyColors.actionPrimary
            : ZokyColors.borderControl,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ZokyColors.brand,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: ZokyColors.surface,
      hintStyle: TextStyle(color: ZokyColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: ZokyRadius.md,
        borderSide: BorderSide(color: ZokyColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: ZokyRadius.md,
        borderSide: BorderSide(color: ZokyColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: ZokyRadius.md,
        borderSide: BorderSide(color: ZokyColors.actionPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: ZokyRadius.md,
        borderSide: BorderSide(color: ZokyColors.error, width: 1.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ZokyColors.brand,
      selectionHandleColor: ZokyColors.brand,
    ),
    dividerTheme: const DividerThemeData(
      color: ZokyColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ZokyColors.neutral900,
      contentTextStyle: ZokyTextStyles.weight(
        textTheme.bodyMedium!.copyWith(
          color: ZokyColors.neutral0,
          fontSize: 14,
        ),
        FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: ZokyRadius.lg),
    ),
  );
}
