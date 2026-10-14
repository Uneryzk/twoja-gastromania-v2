import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';

/// Sorted duration options (days) of a `{days: price}` table.
List<int> tgDurationOptions(Map<int, int> prices) => prices.keys.toList()..sort();

/// Hero banner (AdSlot) commercial rules — brutto PLN, durations in days.
@immutable
class BannerPricing {
  const BannerPricing({
    this.prices = const {7: 129, 14: 199, 30: 349},
    this.maxSponsoredPerDay = 3,
    this.holdHours = 24,
    this.waitlistHorizonDays = 60,
    this.fullRefundDaysBeforeStart = 7,
    this.enterpriseFreeDays = 7,
    this.enterpriseFreePerMonth = 1,
    this.maxCorrections = 1,
    this.titleMaxChars = 60,
  });

  /// `{durationDays: pricePln}`.
  final Map<int, int> prices;
  final int maxSponsoredPerDay;
  final int holdHours;
  final int waitlistHorizonDays;
  final int fullRefundDaysBeforeStart;
  final int enterpriseFreeDays;
  final int enterpriseFreePerMonth;
  final int maxCorrections;
  final int titleMaxChars;

  List<int> get durations => tgDurationOptions(prices);

  int pricePln(int days) => prices[days] ?? 0;

  BannerPricing copyWith({
    Map<int, int>? prices,
    int? maxSponsoredPerDay,
    int? holdHours,
    int? waitlistHorizonDays,
    int? fullRefundDaysBeforeStart,
    int? enterpriseFreePerMonth,
  }) =>
      BannerPricing(
        prices: prices ?? this.prices,
        maxSponsoredPerDay: maxSponsoredPerDay ?? this.maxSponsoredPerDay,
        holdHours: holdHours ?? this.holdHours,
        waitlistHorizonDays: waitlistHorizonDays ?? this.waitlistHorizonDays,
        fullRefundDaysBeforeStart: fullRefundDaysBeforeStart ?? this.fullRefundDaysBeforeStart,
        enterpriseFreeDays: enterpriseFreeDays,
        enterpriseFreePerMonth: enterpriseFreePerMonth ?? this.enterpriseFreePerMonth,
        maxCorrections: maxCorrections,
        titleMaxChars: titleMaxChars,
      );
}

/// Special Order sponsor slot (project type × region) — one sponsor per
/// segment per day; brutto PLN, durations in days.
@immutable
class SponsorSlotPricing {
  const SponsorSlotPricing({
    this.prices = const {7: 89, 14: 149, 30: 249},
    this.holdHours = 24,
    this.horizonDays = 60,
  });

  /// `{durationDays: pricePln}`.
  final Map<int, int> prices;
  final int holdHours;
  final int horizonDays;

  List<int> get durations => tgDurationOptions(prices);

  int pricePln(int days) => prices[days] ?? 0;

  SponsorSlotPricing copyWith({Map<int, int>? prices, int? holdHours, int? horizonDays}) =>
      SponsorSlotPricing(
        prices: prices ?? this.prices,
        holdHours: holdHours ?? this.holdHours,
        horizonDays: horizonDays ?? this.horizonDays,
      );
}

/// Admin-editable commercial prices (brutto, VAT included). VITRIN-2 single source.
///
/// Promotions prices live in [promotions] ([PromotionConfig]). Never hard-code
/// fees in wizards or renew sheets — read via [PricingConfigService].
@immutable
class PricingConfig {
  const PricingConfig({
    this.freeListingDays = 30,
    this.freeListingQuota = 3,
    this.listingPrices = const {30: 49, 60: 79, 90: 99},
    this.restaurantPrices = const {90: 149, 180: 249, 365: 399},
    this.renewEarlyDays = 14,
    this.reservationHoldHours = 24,
    this.proCreditsPerPeriod = 3,
    this.basicStoreMonthlyPln = 199,
    this.proStoreMonthlyPln = 499,
    this.enterpriseStoreMonthlyPln = 899,
    this.storeSixMonthDiscountBps = 1000,
    this.storeYearlyFreeMonths = 2,
    this.storeNudgeMinListings = 4,
    this.storeNudgeThresholdPln = 196,
    this.promotions = PromotionConfig.defaults,
    this.banner = const BannerPricing(),
    this.sponsorSlot = const SponsorSlotPricing(),
  });

  /// Free listing always lasts this many days.
  final int freeListingDays;
  final int freeListingQuota;
  /// `{durationDays: pricePln}` for equipment / rental listings.
  final Map<int, int> listingPrices;

  /// `{durationDays: pricePln}` for restaurant listings.
  final Map<int, int> restaurantPrices;
  final int renewEarlyDays;
  final int reservationHoldHours;
  final int proCreditsPerPeriod;
  final int basicStoreMonthlyPln;
  final int proStoreMonthlyPln;
  final int enterpriseStoreMonthlyPln;
  /// Prepaid 6-month discount in basis points (1000 = 10%).
  final int storeSixMonthDiscountBps;
  /// Months waived on a yearly plan (2 → pay 10 × monthly).
  final int storeYearlyFreeMonths;
  final int storeNudgeMinListings;
  final int storeNudgeThresholdPln;
  final PromotionConfig promotions;
  final BannerPricing banner;
  final SponsorSlotPricing sponsorSlot;

  static const PricingConfig defaults = PricingConfig();

  List<int> get listingDurations => tgDurationOptions(listingPrices);
  List<int> get restaurantDurations => tgDurationOptions(restaurantPrices);

  /// Shortest paid listing period (the default choice).
  int get defaultListingDays => listingDurations.first;
  int get defaultRestaurantDays => restaurantDurations.first;

  int listingFeePln(int days) => listingPrices[days] ?? 0;

  int get defaultListingFeePln => listingFeePln(defaultListingDays);

  /// Monthly gross price by plan id (`basic` / `pro` / `enterprise`).
  int? storeMonthlyPln(String plan) {
    final k = plan.trim().replaceAll(' Store', '').replaceAll(' store', '');
    return switch (k) {
      'basic' || 'Basic' => basicStoreMonthlyPln,
      'pro' || 'Pro' => proStoreMonthlyPln,
      'enterprise' || 'Enterprise' => enterpriseStoreMonthlyPln,
      _ => null,
    };
  }

  int storeSixMonthsPln(int monthly) => monthly * 6 * (10000 - storeSixMonthDiscountBps) ~/ 10000;

  int storeYearlyPln(int monthly) => monthly * (12 - storeYearlyFreeMonths);

  int restaurantFeePln(int days) => restaurantPrices[days] ?? 0;

  int promoFeePln(PromotionTier tier, int days) => promotions.pricePln(tier, days);

  /// Per-day equivalent (brutto). Example: 49/30 → 1.63.
  double perDay(int pricePln, int days) => days <= 0 ? 0 : pricePln / days;

  /// "1,63 PLN/day" style (comma decimal, 2 places).
  String perDayLabel(int pricePln, int days, {String unit = 'PLN/day'}) {
    final v = perDay(pricePln, days);
    final whole = v.floor();
    final frac = ((v - whole) * 100).round().clamp(0, 99);
    final fracStr = frac.toString().padLeft(2, '0');
    return '$whole,$fracStr $unit';
  }

  int totalListingPlusPromo({
    required int listing,
    PromotionTier? tier,
    int? promoDuration,
  }) {
    final base = listingFeePln(listing);
    if (tier == null || promoDuration == null) return base;
    return base + promoFeePln(tier, promoDuration);
  }

  int totalRestaurantPlusPromo({
    required int listing,
    PromotionTier? tier,
    int? promoDuration,
  }) {
    final base = restaurantFeePln(listing);
    if (tier == null || promoDuration == null) return base;
    return base + promoFeePln(tier, promoDuration);
  }

  /// Upgrade cost: max(0, price(new)−price(old)) × remaining/total, ceil to PLN.
  int upgradeCostPln({
    required PromotionTier from,
    required PromotionTier to,
    required int duration,
    required int remainingDays,
    required int totalDays,
  }) {
    if (tierRank(to) <= tierRank(from)) return 0;
    final delta = promoFeePln(to, duration) - promoFeePln(from, duration);
    if (delta <= 0 || totalDays <= 0) return 0;
    final raw = delta * remainingDays / totalDays;
    return raw.ceil();
  }

  static int tierRank(PromotionTier t) => switch (t) {
        PromotionTier.bold => 1,
        PromotionTier.glow => 2,
        PromotionTier.spotlight => 3,
      };

  /// Basic Store nudge when paid basket (≥ same period) hits threshold.
  bool shouldNudgeBasicStore({required int paidBasket30dEqPln, required int listingCount}) {
    return paidBasket30dEqPln >= storeNudgeThresholdPln || listingCount >= storeNudgeMinListings;
  }

  PricingConfig copyWith({
    int? freeListingDays,
    int? freeListingQuota,
    Map<int, int>? listingPrices,
    Map<int, int>? restaurantPrices,
    int? renewEarlyDays,
    int? reservationHoldHours,
    int? proCreditsPerPeriod,
    int? basicStoreMonthlyPln,
    int? proStoreMonthlyPln,
    int? enterpriseStoreMonthlyPln,
    int? storeSixMonthDiscountBps,
    int? storeYearlyFreeMonths,
    int? storeNudgeMinListings,
    int? storeNudgeThresholdPln,
    PromotionConfig? promotions,
    BannerPricing? banner,
    SponsorSlotPricing? sponsorSlot,
  }) =>
      PricingConfig(
        banner: banner ?? this.banner,
        sponsorSlot: sponsorSlot ?? this.sponsorSlot,
        freeListingDays: freeListingDays ?? this.freeListingDays,
        freeListingQuota: freeListingQuota ?? this.freeListingQuota,
        listingPrices: listingPrices ?? this.listingPrices,
        restaurantPrices: restaurantPrices ?? this.restaurantPrices,
        renewEarlyDays: renewEarlyDays ?? this.renewEarlyDays,
        reservationHoldHours: reservationHoldHours ?? this.reservationHoldHours,
        proCreditsPerPeriod: proCreditsPerPeriod ?? this.proCreditsPerPeriod,
        basicStoreMonthlyPln: basicStoreMonthlyPln ?? this.basicStoreMonthlyPln,
        proStoreMonthlyPln: proStoreMonthlyPln ?? this.proStoreMonthlyPln,
        enterpriseStoreMonthlyPln: enterpriseStoreMonthlyPln ?? this.enterpriseStoreMonthlyPln,
        storeSixMonthDiscountBps: storeSixMonthDiscountBps ?? this.storeSixMonthDiscountBps,
        storeYearlyFreeMonths: storeYearlyFreeMonths ?? this.storeYearlyFreeMonths,
        storeNudgeMinListings: storeNudgeMinListings ?? this.storeNudgeMinListings,
        storeNudgeThresholdPln: storeNudgeThresholdPln ?? this.storeNudgeThresholdPln,
        promotions: promotions ?? this.promotions,
      );
}
