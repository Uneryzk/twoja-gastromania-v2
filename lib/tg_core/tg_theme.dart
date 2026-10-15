import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Material [ThemeData] for the Twoja Gastromania dark identity.
ThemeData buildTGDarkTheme() => buildTGTheme(TGPalette.dark, Brightness.dark);

/// Light companion: page #F8F9FA, cards #FFFFFF, copy #101828. Brand accents unchanged.
ThemeData buildTGLightTheme() => buildTGTheme(TGPalette.light, Brightness.light);

/// Shared Material mapping so stock widgets follow the TG palette.
ThemeData buildTGTheme(TGPalette p, Brightness brightness) {
  final scheme = brightness == Brightness.dark
      ? ColorScheme.dark(
          primary: TGColors.cta,
          onPrimary: TGColors.onCta,
          secondary: TGColors.accent,
          onSecondary: Colors.white,
          surface: p.surface,
          onSurface: p.textPrimary,
          error: TGColors.error,
          onError: Colors.white,
          outline: p.border,
        )
      : ColorScheme.light(
          primary: TGColors.cta,
          onPrimary: TGColors.onCta,
          secondary: TGColors.accent,
          onSecondary: Colors.white,
          surface: p.surface,
          onSurface: p.textPrimary,
          error: TGColors.error,
          onError: Colors.white,
          outline: p.border,
        );

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: false,
    colorScheme: scheme,
    primaryColor: TGColors.cta,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    cardColor: p.surface,
    dividerColor: p.border,
    hoverColor: p.surfaceHover,
    focusColor: TGColors.cta.withValues(alpha: 0.18),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  final rawTextTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: p.textPrimary,
    displayColor: p.textPrimary,
  );
  TextStyle heading(TextStyle? style, double letterSpacing) =>
      (style ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
      );
  final textTheme = rawTextTheme.copyWith(
    displayLarge: heading(rawTextTheme.displayLarge, 0.45),
    displayMedium: heading(rawTextTheme.displayMedium, 0.4),
    displaySmall: heading(rawTextTheme.displaySmall, 0.35),
    headlineLarge: heading(rawTextTheme.headlineLarge, 0.35),
    headlineMedium: heading(rawTextTheme.headlineMedium, 0.3),
    headlineSmall: heading(rawTextTheme.headlineSmall, 0.3),
    titleLarge: heading(rawTextTheme.titleLarge, 0.25),
    titleMedium: heading(rawTextTheme.titleMedium, 0.22),
    titleSmall: heading(rawTextTheme.titleSmall, 0.2),
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
      fillColor: p.surfaceHover,
      isDense: true,
      hintStyle: TextStyle(color: p.textSecondary),
      border: inputBorder(p.border),
      enabledBorder: inputBorder(p.border),
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
      backgroundColor: p.surfaceHover,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: p.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: TGColors.cta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        side: BorderSide(color: p.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.modal),
        side: BorderSide(color: p.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        side: BorderSide(color: p.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: p.textPrimary),
      waitDuration: const Duration(milliseconds: 350),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.verified : p.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? TGColors.verified.withValues(alpha: 0.38)
            : p.border,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.cta : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(TGColors.onCta),
      side: BorderSide(color: p.textSecondary, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TGColors.cta : p.textSecondary,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: TGColors.cta,
      inactiveTrackColor: p.border,
      thumbColor: TGColors.cta,
      overlayColor: TGColors.cta.withValues(alpha: 0.16),
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.border.withValues(alpha: 0.9)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TGColors.cta),
  );
}
