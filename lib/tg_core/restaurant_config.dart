import 'package:flutter/foundation.dart';

/// Promote packages for restaurant listings (PLN, VAT-inclusive).
@immutable
class RestaurantPromotePrices {
  const RestaurantPromotePrices({required this.pln14, required this.pln30});

  final int pln14;
  final int pln30;

  RestaurantPromotePrices copyWith({int? pln14, int? pln30}) =>
      RestaurantPromotePrices(pln14: pln14 ?? this.pln14, pln30: pln30 ?? this.pln30);

  Map<String, dynamic> toJson() => {'pln14': pln14, 'pln30': pln30};

  static RestaurantPromotePrices fromJson(Map<String, dynamic> json) => RestaurantPromotePrices(
        pln14: (json['pln14'] as num?)?.toInt() ?? 39,
        pln30: (json['pln30'] as num?)?.toInt() ?? 69,
      );
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
    required this.adSlotPln14,
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
  final int adSlotPln14;

  static const RestaurantConfig defaults = RestaurantConfig(
    freeDays: 30,
    freeExtensionDays: 30,
    paidPricePln: 149,
    paidDays: 90,
    renewEarlyDays: 14,
    promote: RestaurantPromotePrices(pln14: 39, pln30: 69),
    freeStartCapPer12m: 3,
    perPremisesMax: 3,
    dailyListingCap: 3,
    lowViewsHint: 30,
    soldItemReviewBusinessDays: 5,
    adSlotPln14: 249,
  );

  /// CTA label for hub / banners (config-driven free period).
  String get listCtaLabel => 'List your business · free for $freeDays days';

  String get listBannerTitle => 'Selling your business? List it free for $freeDays days';

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
    int? adSlotPln14,
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
        adSlotPln14: adSlotPln14 ?? this.adSlotPln14,
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
        'adSlotPln14': adSlotPln14,
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
        adSlotPln14: (json['adSlotPln14'] as num?)?.toInt() ?? defaults.adSlotPln14,
      );
}

/// Mutable holder so admin can edit config without baking values into widgets.
class RestaurantConfigService extends ChangeNotifier {
  RestaurantConfigService._();
  static final RestaurantConfigService instance = RestaurantConfigService._();

  RestaurantConfig _config = RestaurantConfig.defaults;

  RestaurantConfig get config => _config;

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
