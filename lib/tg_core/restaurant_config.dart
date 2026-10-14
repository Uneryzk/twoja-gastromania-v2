import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';

/// Promote packages for restaurant listings: `{days: PLN}` (VAT-inclusive).
@immutable
class RestaurantPromotePrices {
  RestaurantPromotePrices({Map<int, int>? prices})
      : prices = prices ?? Map<int, int>.from(PromotionConfig.defaults.prices[PromotionTier.glow] ?? const {});

  final Map<int, int> prices;

  List<int> get durations => prices.keys.toList()..sort();

  int pricePln(int days) => prices[days] ?? 0;

  RestaurantPromotePrices copyWith({Map<int, int>? prices}) => RestaurantPromotePrices(prices: prices ?? this.prices);

  Map<String, dynamic> toJson() => {'prices': {for (final e in prices.entries) '${e.key}': e.value}};

  /// Also reads the legacy `pln14` / `pln30` keys.
  static RestaurantPromotePrices fromJson(Map<String, dynamic> json) {
    final raw = json['prices'];
    if (raw is Map) {
      return RestaurantPromotePrices(prices: {
        for (final e in raw.entries) int.parse('${e.key}'): (e.value as num).toInt(),
      });
    }
    final glow = PromotionConfig.defaults.prices[PromotionTier.glow] ?? const {};
    return RestaurantPromotePrices(prices: {
      14: (json['pln14'] as num?)?.toInt() ?? glow[14] ?? 0,
      30: (json['pln30'] as num?)?.toInt() ?? glow[30] ?? 0,
    });
  }
}

/// Single source of truth for restaurant listing commercial rules.
///
/// Durations, prices and thresholds are editable (admin later) — never hard-coded
/// in UI or lifecycle logic. Defaults match RESTO-1.
@immutable
class RestaurantConfig {
  const RestaurantConfig({
    required this.freeDays,
    required this.freeExtensionDays,
    required this.paidPricePln,
    required this.paidDays,
    required this.renewEarlyDays,
    required this.promote,
    required this.freeStartCapPer12m,
    required this.perPremisesMax,
    required this.dailyListingCap,
    required this.lowViewsHint,
    required this.soldItemReviewBusinessDays,
  });

  final int freeDays;
  final int freeExtensionDays;
  final int paidPricePln;
  final int paidDays;
  final int renewEarlyDays;
  final RestaurantPromotePrices promote;
  final int freeStartCapPer12m;
  final int perPremisesMax;
  final int dailyListingCap;
  final int lowViewsHint;
  final int soldItemReviewBusinessDays;

  /// Mirrors [PricingConfig.defaults] so PLN / day figures are not a second source.
  static RestaurantConfig get defaults {
    const p = PricingConfig.defaults;
    return RestaurantConfig(
      freeDays: p.freeListingDays,
      freeExtensionDays: p.freeListingDays,
      paidPricePln: p.restaurantFeePln(p.defaultRestaurantDays),
      paidDays: p.defaultRestaurantDays,
      renewEarlyDays: p.renewEarlyDays,
      promote: RestaurantPromotePrices(prices: Map<int, int>.from(p.promotions.prices[PromotionTier.glow] ?? const {})),
      freeStartCapPer12m: p.freeListingQuota,
      perPremisesMax: 3,
      dailyListingCap: 3,
      lowViewsHint: 30,
      soldItemReviewBusinessDays: 5,
    );
  }

  /// CTA label for hub / banners (config-driven free period).
  String get listCtaLabel => 'List your business · free for ${DurationFormatter.days(freeDays, 'en')}';

  String get listBannerTitle => 'Selling your business? List it free for ${DurationFormatter.days(freeDays, 'en')}';

  RestaurantConfig copyWith({
    int? freeDays,
    int? freeExtensionDays,
    int? paidPricePln,
    int? paidDays,
    int? renewEarlyDays,
    RestaurantPromotePrices? promote,
    int? freeStartCapPer12m,
    int? perPremisesMax,
    int? dailyListingCap,
    int? lowViewsHint,
    int? soldItemReviewBusinessDays,
  }) =>
      RestaurantConfig(
        freeDays: freeDays ?? this.freeDays,
        freeExtensionDays: freeExtensionDays ?? this.freeExtensionDays,
        paidPricePln: paidPricePln ?? this.paidPricePln,
        paidDays: paidDays ?? this.paidDays,
        renewEarlyDays: renewEarlyDays ?? this.renewEarlyDays,
        promote: promote ?? this.promote,
        freeStartCapPer12m: freeStartCapPer12m ?? this.freeStartCapPer12m,
        perPremisesMax: perPremisesMax ?? this.perPremisesMax,
        dailyListingCap: dailyListingCap ?? this.dailyListingCap,
        lowViewsHint: lowViewsHint ?? this.lowViewsHint,
        soldItemReviewBusinessDays: soldItemReviewBusinessDays ?? this.soldItemReviewBusinessDays,
      );

  Map<String, dynamic> toJson() => {
        'freeDays': freeDays,
        'freeExtensionDays': freeExtensionDays,
        'paidPricePln': paidPricePln,
        'paidDays': paidDays,
        'renewEarlyDays': renewEarlyDays,
        'promote': promote.toJson(),
        'freeStartCapPer12m': freeStartCapPer12m,
        'perPremisesMax': perPremisesMax,
        'dailyListingCap': dailyListingCap,
        'lowViewsHint': lowViewsHint,
        'soldItemReviewBusinessDays': soldItemReviewBusinessDays,
      };

  static RestaurantConfig fromJson(Map<String, dynamic> json) => RestaurantConfig(
        freeDays: (json['freeDays'] as num?)?.toInt() ?? defaults.freeDays,
        freeExtensionDays: (json['freeExtensionDays'] as num?)?.toInt() ?? defaults.freeExtensionDays,
        paidPricePln: (json['paidPricePln'] as num?)?.toInt() ?? defaults.paidPricePln,
        paidDays: (json['paidDays'] as num?)?.toInt() ?? defaults.paidDays,
        renewEarlyDays: (json['renewEarlyDays'] as num?)?.toInt() ?? defaults.renewEarlyDays,
        promote: json['promote'] is Map<String, dynamic>
            ? RestaurantPromotePrices.fromJson(json['promote'] as Map<String, dynamic>)
            : defaults.promote,
        freeStartCapPer12m: (json['freeStartCapPer12m'] as num?)?.toInt() ?? defaults.freeStartCapPer12m,
        perPremisesMax: (json['perPremisesMax'] as num?)?.toInt() ?? defaults.perPremisesMax,
        dailyListingCap: (json['dailyListingCap'] as num?)?.toInt() ?? defaults.dailyListingCap,
        lowViewsHint: (json['lowViewsHint'] as num?)?.toInt() ?? defaults.lowViewsHint,
        soldItemReviewBusinessDays:
            (json['soldItemReviewBusinessDays'] as num?)?.toInt() ?? defaults.soldItemReviewBusinessDays,
      );
}

/// Mutable holder so admin can edit config without baking values into widgets.
class RestaurantConfigService extends ChangeNotifier {
  RestaurantConfigService._();
  static final RestaurantConfigService instance = RestaurantConfigService._();

  RestaurantConfig _config = RestaurantConfig.defaults;

  RestaurantConfig get config {
    final p = PricingConfigService.instance.config;
    final glow = p.promotions.prices[PromotionTier.glow] ?? const <int, int>{};
    return _config.copyWith(
      freeDays: p.freeListingDays,
      paidDays: p.defaultRestaurantDays,
      paidPricePln: p.restaurantFeePln(p.defaultRestaurantDays),
      renewEarlyDays: p.renewEarlyDays,
      promote: RestaurantPromotePrices(prices: Map<int, int>.from(glow)),
    );
  }

  void reset() {
    _config = RestaurantConfig.defaults;
    notifyListeners();
  }

  void apply(RestaurantConfig next) {
    _config = next;
    notifyListeners();
  }

  void update(RestaurantConfig Function(RestaurantConfig c) fn) => apply(fn(_config));
}
