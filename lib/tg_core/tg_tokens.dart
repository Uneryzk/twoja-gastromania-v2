import 'package:flutter/material.dart';

/// Twoja Gastromania design system – single source of truth.
///
/// Every colour / radius / duration used by the TG components should come from
/// here (directly or through `FlutterFlowTheme`, which is wired to these
/// constants) so the identity can never drift between screens.
abstract final class TGColors {
  /// Primary page background.
  static const Color background = Color(0xFF252525);

  /// Card / sheet / footer surface.
  static const Color surface = Color(0xFF1F1F1F);

  /// Hover state and input fill.
  static const Color surfaceHover = Color(0xFF2A2A2A);

  /// Hairline borders and dividers.
  static const Color border = Color(0xFF3A3A3A);

  /// Primary call-to-action (turquoise).
  static const Color cta = Color(0xFF26E6B3);

  /// Text/icon colour that sits on top of [cta].
  static const Color onCta = Color(0xFF0E1A16);

  /// Accent / badge colour (pink).
  static const Color accent = Color(0xFFF73887);

  /// Verified-seller badge.
  static const Color verified = Color(0xFF00E676);

  /// Rating stars.
  static const Color rating = Color(0xFFFFC107);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB8BEC2);
  static const Color error = Color(0xFFFF5252);

  /// Internal moderation chrome.
  static const Color adminBar = Color(0xFF181818);
  static const Color slaAmber = Color(0xFFFFB300);
}

abstract final class TGRadius {
  /// Text fields, dropdowns, small buttons.
  static const double input = 12;

  /// Cards.
  static const double card = 16;

  /// Modals and bottom sheets.
  static const double modal = 16;

  /// Fully rounded pills.
  static const double pill = 9999;
}

abstract final class TGMotion {
  /// Grid <-> list layout switch on the products page.
  static const Duration layoutSwitch = Duration(milliseconds: 220);

  /// Card hover lift / glow.
  static const Duration hover = Duration(milliseconds: 180);

  static const Duration quick = Duration(milliseconds: 140);
  static const Duration stepper = Duration(milliseconds: 250);
  static const Duration slide = Duration(milliseconds: 200);
  static const Duration fade = Duration(milliseconds: 150);
  static const Duration settle = Duration(milliseconds: 180);
  static const Duration delete = Duration(milliseconds: 120);
  static const Duration promote = Duration(milliseconds: 300);
  static const Duration barFill = Duration(milliseconds: 400);
  static const Duration tick = Duration(milliseconds: 400);
  static const Duration price = Duration(milliseconds: 200);
  static const Duration skeleton = Duration(milliseconds: 1200);

  static const Curve layoutCurve = Curves.easeInOutCubic;

  /// Pixels a card rises on hover.
  static const double hoverLift = 4;

  /// Zero when the OS "reduce motion" setting is on.
  static Duration of(BuildContext context, Duration d) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduce ? Duration.zero : d;
  }
}

abstract final class TGBreakpoints {
  /// Below this width product cards collapse to one column / compact rows.
  static const double phone = 700;

  /// Below this width the filter sidebar is replaced by a bottom sheet.
  static const double desktop = 1024;
}

/// A B2B store subscription tier.
@immutable
class TGStorePlan {
  const TGStorePlan({required this.name, required this.monthlyPricePln});

  final String name;

  /// Gross price (23% VAT included) in PLN per month.
  final int monthlyPricePln;
}

/// Commercial rules of the classifieds model (no escrow, no in-platform
/// checkout – the platform only monetises listings and stores).
abstract final class TGPricing {
  /// Number of free listings every account gets. Slots never expire.
  static const int freeListingQuota = 3;

  /// Each listing (free or paid) stays live this many days from publish.
  static const int freePeriodDays = 30;

  /// Fee per listing after the free tier is used up (PLN, VAT included).
  static const int listingFeePln = 49;
  static const int listingPeriodDays = 30;
  static const int promote14Pln = 39;
  static const int promote30Pln = 69;

  static const double vatRate = 0.23;

  static const List<TGStorePlan> storePlans = [
    TGStorePlan(name: 'Basic', monthlyPricePln: 199),
    TGStorePlan(name: 'Pro', monthlyPricePln: 499),
    TGStorePlan(name: 'Enterprise', monthlyPricePln: 899),
  ];

  /// Net amount of a gross (VAT-inclusive) price.
  static double netFromGross(num gross) => gross / (1 + vatRate);

  /// VAT contained in a gross price.
  static double vatFromGross(num gross) => gross - netFromGross(gross);

  /// 6 months prepaid at −10%.
  static double storeSixMonths(int monthly) => monthly * 6 * 0.9;

  /// Yearly: 2 months free (10 × monthly).
  static int storeYearly(int monthly) => monthly * 10;

  static double storeSixMonthsMonthlyEq(int monthly) => storeSixMonths(monthly) / 6;

  static double storeYearlyMonthlyEq(int monthly) => storeYearly(monthly) / 12;

  static double storePrice(int monthly, TGBillingPeriod period) => switch (period) {
        TGBillingPeriod.monthly => monthly.toDouble(),
        TGBillingPeriod.sixMonths => storeSixMonths(monthly),
        TGBillingPeriod.yearly => storeYearly(monthly).toDouble(),
      };
}

enum TGBillingPeriod { monthly, sixMonths, yearly }

/// Bundled image assets used by marketplace chrome (not listing photos).
abstract final class TGAssets {
  /// Store-with-pin glyph for in-person pickup / odbiór osobisty / elden teslim.
  static const String pickupStore = 'assets/images/icon_pickup_store.png';
}
