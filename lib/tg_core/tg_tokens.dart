import 'package:flutter/material.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';

/// Twoja Gastromania design system – single source of truth.
///
/// Every colour / radius / duration used by the TG components should come from
/// here (directly or through `FlutterFlowTheme`, which is wired to these
/// constants) so the identity can never drift between screens.
/// Left dark scrim for sponsored hero slides — rgba(18,18,18,.88) fading right.
const LinearGradient tgBannerScrim = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xE0121212), Color(0x99121212), Color(0x00121212)],
  stops: [0, 0.45, 0.85],
);

/// Surfaces and copy colours for one brightness. Brand accents stay on [TGColors].
@immutable
class TGPalette {
  const TGPalette({
    required this.background,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.adminBar,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color adminBar;
  final Color info;

  /// Existing Twoja Gastromania dark identity — do not restyle.
  static const dark = TGPalette(
    background: Color(0xFF252525),
    surface: Color(0xFF1F1F1F),
    surfaceHover: Color(0xFF2A2A2A),
    border: Color(0xFF3A3A3A),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB8BEC2),
    adminBar: Color(0xFF181818),
    info: Color(0xFFFFFFFF),
  );

  /// Light companion: kırık beyaz page/cards, copy #101828. Not pure white.
  static const light = TGPalette(
    background: Color(0xFFEFEBE4),
    surface: Color(0xFFF4F1EB),
    surfaceHover: Color(0xFFE6E1D8),
    border: Color(0xFFD9D3C8),
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF5C564C),
    adminBar: Color(0xFFE6E1D8),
    info: Color(0xFF101828),
  );
}

/// In-memory theme preference. Persisted via [FlutterFlowTheme.saveThemeMode]
/// / SharedPreferences; [reset] keeps widget tests on the dark palette.
class TGThemeController extends ChangeNotifier {
  TGThemeController._();
  static final TGThemeController instance = TGThemeController._();

  ThemeMode _mode = ThemeMode.light;
  Brightness _platform = Brightness.dark;
  Brightness? _syncedFromTheme;

  ThemeMode get mode => _mode;
  Brightness get platformBrightness => _platform;
  Brightness get brightness =>
      _syncedFromTheme ??
      switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => _platform,
      };
  bool get isDark => brightness == Brightness.dark;
  TGPalette get palette => isDark ? TGPalette.dark : TGPalette.light;

  /// Keep [TGColors] in lockstep with [ThemeData.brightness] (same frame, no notify).
  void syncFromTheme(Brightness value) {
    _syncedFromTheme = value;
  }

  void bindPlatformBrightness(Brightness value) {
    if (_platform == value) return;
    _platform = value;
    if (_mode == ThemeMode.system) notifyListeners();
  }

  /// Tests and [pumpTgApp] call this so leftover light mode cannot leak.
  void reset({ThemeMode mode = ThemeMode.dark, Brightness platform = Brightness.dark}) {
    _mode = mode;
    _platform = platform;
    _syncedFromTheme = null;
  }

  void setMode(ThemeMode mode) {
    final resolved = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => _platform,
    };
    if (_mode == mode && _syncedFromTheme == resolved) return;
    _mode = mode;
    if (mode != ThemeMode.system) _syncedFromTheme = resolved;
    notifyListeners();
  }
}

abstract final class TGColors {
  static TGPalette get _p => TGThemeController.instance.palette;

  /// Primary page background.
  static Color get background => _p.background;

  /// Card / sheet / footer surface.
  static Color get surface => _p.surface;

  /// Hover state and input fill.
  static Color get surfaceHover => _p.surfaceHover;

  /// Hairline borders and dividers.
  static Color get border => _p.border;

  /// Primary call-to-action (turquoise). Same in light and dark.
  static const Color cta = Color(0xFF26E6B3);

  /// Text/icon colour that sits on top of [cta].
  static const Color onCta = Color(0xFF0E1A16);

  /// Accent / badge colour (pink).
  static const Color accent = Color(0xFFF73887);

  /// Verified-seller badge.
  static const Color verified = Color(0xFF00E676);

  /// Rating stars.
  static const Color rating = Color(0xFFFFC107);

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static const Color error = Color(0xFFFF5252);

  /// Internal moderation chrome.
  static Color get adminBar => _p.adminBar;
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
///
/// VITRIN-2: prefer [PricingConfigService] for listing/promo fees. These
/// constants match [PricingConfig.defaults] for legacy call sites / tests.
abstract final class TGPricing {
  /// Number of free listings every account gets. Slots never expire.
  static int get freeListingQuota => PricingConfigService.instance.config.freeListingQuota;

  /// Each free listing stays live this many days from publish.
  static int get freePeriodDays => PricingConfigService.instance.config.freeListingDays;

  /// Shortest paid listing fee — brutto PLN. Prefer PricingConfig.
  static int get listingFeePln => PricingConfigService.instance.config.defaultListingFeePln;
  static int get listingPeriodDays => PricingConfigService.instance.config.defaultListingDays;

  static const double vatRate = 0.23;

  static List<TGStorePlan> get storePlans {
    final c = PricingConfigService.instance.config;
    return [
      TGStorePlan(name: 'Basic', monthlyPricePln: c.basicStoreMonthlyPln),
      TGStorePlan(name: 'Pro', monthlyPricePln: c.proStoreMonthlyPln),
      TGStorePlan(name: 'Enterprise', monthlyPricePln: c.enterpriseStoreMonthlyPln),
    ];
  }

  /// Net amount of a gross (VAT-inclusive) price.
  static double netFromGross(num gross) => gross / (1 + vatRate);

  /// VAT contained in a gross price.
  static double vatFromGross(num gross) => gross - netFromGross(gross);

  static int storeSixMonths(int monthly) => PricingConfigService.instance.config.storeSixMonthsPln(monthly);

  static int storeYearly(int monthly) => PricingConfigService.instance.config.storeYearlyPln(monthly);

  static double storeSixMonthsMonthlyEq(int monthly) => storeSixMonths(monthly) / 6;

  static double storeYearlyMonthlyEq(int monthly) => storeYearly(monthly) / 12;

  static double storePrice(int monthly, TGBillingPeriod period) => switch (period) {
        TGBillingPeriod.monthly => monthly.toDouble(),
        TGBillingPeriod.sixMonths => storeSixMonths(monthly).toDouble(),
        TGBillingPeriod.yearly => storeYearly(monthly).toDouble(),
      };
}

/// Locale-safe uppercase for visible Turkish (and ASCII) letters.
/// Dart [String.toUpperCase] maps `i` → `I` and drops the dot on `İ`.
String tgToUpperTr(String value) {
  const map = {'i': 'İ', 'ı': 'I', 'ğ': 'Ğ', 'ü': 'Ü', 'ş': 'Ş', 'ö': 'Ö', 'ç': 'Ç'};
  return value.split('').map((c) => map[c] ?? c.toUpperCase()).join();
}

const kLangCodeLabel = {
  'en': 'EN',
  'pl': 'PL',
  'tr': 'TR',
  'de': 'DE',
  'cs': 'CS',
  'sk': 'SK',
  'uk': 'UK',
  'be': 'BE',
  'lt': 'LT',
  'ru': 'RU',
};

enum TGBillingPeriod { monthly, sixMonths, yearly }

/// Bundled image assets used by marketplace chrome (not listing photos).
abstract final class TGAssets {
  /// Store-with-pin glyph for in-person pickup / odbiór osobisty / elden teslim.
  static const String pickupStore = 'assets/images/icon_pickup_store.png';
}
