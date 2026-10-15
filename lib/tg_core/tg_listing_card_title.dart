import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Product-card listing title.
///
/// Must call [GoogleFonts.interTight] with the weight — `titleMedium.override(fontWeight: w300)`
/// keeps the Bold file from `titleMedium` (w700) and looks like Inter Tight Bold.
///
/// Standard (no Bold / Spotlight, including Glow): Inter Tight Light w300.
/// Paid Bold / Spotlight: Inter Tight Bold w700, tracking 0.40.
abstract final class TGListingCardTitle {
  static const double fontSize = 16;
  static const double letterSpacing = 0.25;
  static const double boldLetterSpacing = 0.40;
  static const double lineHeight = 1.3;

  static FontWeight weight({required bool paid}) => paid ? FontWeight.w700 : FontWeight.w300;

  static TextStyle style({required Color color, required bool paid}) {
    return GoogleFonts.interTight(
      color: color,
      fontSize: fontSize,
      fontWeight: weight(paid: paid),
      letterSpacing: paid ? boldLetterSpacing : letterSpacing,
      height: lineHeight,
    );
  }
}
