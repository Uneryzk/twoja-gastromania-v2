import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Material [ThemeData] for the Twoja Gastromania dark identity.
///
/// `FlutterFlowTheme` already drives our custom widgets; this makes the stock
/// Material widgets (text fields, snackbars, sheets, dialogs, switches, ...)
/// follow the same design system without per-widget overrides.
ThemeData buildTGDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: TGColors.cta,
    onPrimary: TGColors.onCta,
    secondary: TGColors.accent,
    onSecondary: Colors.white,
    surface: TGColors.surface,
    onSurface: TGColors.textPrimary,
    error: TGColors.error,
    onError: Colors.white,
    outline: TGColors.border,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false,
    colorScheme: scheme,
    primaryColor: TGColors.cta,
    scaffoldBackgroundColor: TGColors.background,
    canvasColor: TGColors.surface,
    cardColor: TGColors.surface,
    dividerColor: TGColors.border,
    hoverColor: TGColors.surfaceHover,
    focusColor: TGColors.cta.withValues(alpha: 0.18),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: TGColors.textPrimary,
    displayColor: TGColors.textPrimary,
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TGColors.surfaceHover,
      isDense: true,
      hintStyle: const TextStyle(color: TGColors.textSecondary),
      border: inputBorder(TGColors.border),
      enabledBorder: inputBorder(TGColors.border),
      focusedBorder: inputBorder(TGColors.cta, 2),
      errorBorder: inputBorder(TGColors.error),
      focusedErrorBorder: inputBorder(TGColors.error, 1.6),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: TGColors.cta,
      selectionColor: TGColors.cta.withValues(alpha: 0.30),
      selectionHandleColor: TGColors.cta,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TGColors.surfaceHover,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: TGColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: TGColors.cta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        side: const BorderSide(color: TGColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TGColors.surface,
      modalBackgroundColor: TGColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TGColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.modal),
        side: const BorderSide(color: TGColors.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: TGColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        side: const BorderSide(color: TGColors.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: TGColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TGColors.border),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: TGColors.textPrimary),
      waitDuration: const Duration(milliseconds: 350),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.verified : TGColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? TGColors.verified.withValues(alpha: 0.38)
            : TGColors.border,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.cta : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(TGColors.onCta),
      side: const BorderSide(color: TGColors.textSecondary, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.cta : TGColors.textSecondary,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: TGColors.cta,
      inactiveTrackColor: TGColors.border,
      thumbColor: TGColors.cta,
      overlayColor: TGColors.cta.withValues(alpha: 0.16),
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(TGColors.border.withValues(alpha: 0.9)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    dividerTheme: const DividerThemeData(color: TGColors.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TGColors.cta),
  );
}
