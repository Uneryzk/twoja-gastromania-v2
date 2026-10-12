import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';

/// Listing (equipment / rental) paid duration keys — days only, labels via i18n.
enum ListingDurationKey { d30, d60, d90 }

/// Restaurant paid duration keys.
enum RestaurantDurationKey { d90, d180, d365 }

extension ListingDurationKeyX on ListingDurationKey {
  int get days => switch (this) {
        ListingDurationKey.d30 => 30,
        ListingDurationKey.d60 => 60,
        ListingDurationKey.d90 => 90,
      };
}

extension RestaurantDurationKeyX on RestaurantDurationKey {
  int get days => switch (this) {
        RestaurantDurationKey.d90 => 90,
        RestaurantDurationKey.d180 => 180,
        RestaurantDurationKey.d365 => 365,
      };
}

/// Hero banner paid duration keys (VITRIN-3).
enum BannerDurationKey { w1, w2, m1 }

extension BannerDurationKeyX on BannerDurationKey {
  int get days => switch (this) {
        BannerDurationKey.w1 => 7,
        BannerDurationKey.w2 => 14,
        BannerDurationKey.m1 => 30,
      };

  /// i18n key for the duration label.
  String get labelKey => switch (this) {
        BannerDurationKey.w1 => 'ui_banner_dur_w1',
        BannerDurationKey.w2 => 'ui_banner_dur_w2',
        BannerDurationKey.m1 => 'ui_banner_dur_m1',
      };
}

/// Hero banner (AdSlot) commercial rules — brutto PLN.
@immutable
class BannerPricing {
  const BannerPricing({
    this.prices = const {
      BannerDurationKey.w1: 129,
      BannerDurationKey.w2: 199,
      BannerDurationKey.m1: 349,
    },
    this.maxSponsoredPerDay = 3,
    this.holdHours = 24,
    this.waitlistHorizonDays = 60,
    this.fullRefundDaysBeforeStart = 7,
    this.enterpriseFreeDuration = BannerDurationKey.w1,
    this.enterpriseFreePerMonth = 1,
    this.maxCorrections = 1,
    this.titleMaxChars = 60,
  });

  final Map<BannerDurationKey, int> prices;
  final int maxSponsoredPerDay;
  final int holdHours;
  final int waitlistHorizonDays;
  final int fullRefundDaysBeforeStart;
  final BannerDurationKey enterpriseFreeDuration;
  final int enterpriseFreePerMonth;
  final int maxCorrections;
  final int titleMaxChars;

  int pricePln(BannerDurationKey key) => prices[key] ?? 0;

  BannerPricing copyWith({
    Map<BannerDurationKey, int>? prices,
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
        enterpriseFreeDuration: enterpriseFreeDuration,
        enterpriseFreePerMonth: enterpriseFreePerMonth ?? this.enterpriseFreePerMonth,
        maxCorrections: maxCorrections,
        titleMaxChars: titleMaxChars,
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
    this.listingPrices = const {
      ListingDurationKey.d30: 49,
      ListingDurationKey.d60: 79,
      ListingDurationKey.d90: 99,
    },
    this.restaurantPrices = const {
      RestaurantDurationKey.d90: 149,
      RestaurantDurationKey.d180: 249,
      RestaurantDurationKey.d365: 399,
    },
    this.renewEarlyDays = 14,
    this.reservationHoldHours = 24,
    this.proCreditsPerPeriod = 3,
    this.basicStoreMonthlyPln = 199,
    this.storeNudgeMinListings = 4,
    this.storeNudgeThresholdPln = 196,
    this.promotions = PromotionConfig.defaults,
    this.banner = const BannerPricing(),
  });

  /// Free listing always lasts this many days.
  final int freeListingDays;
  final int freeListingQuota;
  final Map<ListingDurationKey, int> listingPrices;
  final Map<RestaurantDurationKey, int> restaurantPrices;
  final int renewEarlyDays;
  final int reservationHoldHours;
  final int proCreditsPerPeriod;
  final int basicStoreMonthlyPln;
  final int storeNudgeMinListings;
  final int storeNudgeThresholdPln;
  final PromotionConfig promotions;
  final BannerPricing banner;

  static const PricingConfig defaults = PricingConfig();

  int listingFeePln(ListingDurationKey key) => listingPrices[key] ?? 0;

  int restaurantFeePln(RestaurantDurationKey key) => restaurantPrices[key] ?? 0;

  int promoFeePln(PromotionTier tier, PromotionDurationKey duration) =>
      promotions.pricePln(tier, duration);

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
    required ListingDurationKey listing,
    PromotionTier? tier,
    PromotionDurationKey? promoDuration,
  }) {
    final base = listingFeePln(listing);
    if (tier == null || promoDuration == null) return base;
    return base + promoFeePln(tier, promoDuration);
  }

  int totalRestaurantPlusPromo({
    required RestaurantDurationKey listing,
    PromotionTier? tier,
    PromotionDurationKey? promoDuration,
  }) {
    final base = restaurantFeePln(listing);
    if (tier == null || promoDuration == null) return base;
    return base + promoFeePln(tier, promoDuration);
  }

  /// Upgrade cost: max(0, price(new)−price(old)) × remaining/total, ceil to PLN.
  int upgradeCostPln({
    required PromotionTier from,
    required PromotionTier to,
    required PromotionDurationKey duration,
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
    Map<ListingDurationKey, int>? listingPrices,
    Map<RestaurantDurationKey, int>? restaurantPrices,
    int? renewEarlyDays,
    int? reservationHoldHours,
    int? proCreditsPerPeriod,
    int? basicStoreMonthlyPln,
    int? storeNudgeMinListings,
    int? storeNudgeThresholdPln,
    PromotionConfig? promotions,
    BannerPricing? banner,
  }) =>
      PricingConfig(
        banner: banner ?? this.banner,
        freeListingDays: freeListingDays ?? this.freeListingDays,
        freeListingQuota: freeListingQuota ?? this.freeListingQuota,
        listingPrices: listingPrices ?? this.listingPrices,
        restaurantPrices: restaurantPrices ?? this.restaurantPrices,
        renewEarlyDays: renewEarlyDays ?? this.renewEarlyDays,
        reservationHoldHours: reservationHoldHours ?? this.reservationHoldHours,
        proCreditsPerPeriod: proCreditsPerPeriod ?? this.proCreditsPerPeriod,
        basicStoreMonthlyPln: basicStoreMonthlyPln ?? this.basicStoreMonthlyPln,
        storeNudgeMinListings: storeNudgeMinListings ?? this.storeNudgeMinListings,
        storeNudgeThresholdPln: storeNudgeThresholdPln ?? this.storeNudgeThresholdPln,
        promotions: promotions ?? this.promotions,
      );
}
