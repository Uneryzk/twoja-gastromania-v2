import 'package:flutter/foundation.dart';

/// Paid / included listing promotion tiers (VITRIN-1).
enum PromotionTier { bold, glow, spotlight }

/// Product names stay untranslated in every locale.
extension PromotionTierBrand on PromotionTier {
  String get brand => switch (this) {
        PromotionTier.bold => 'Bold',
        PromotionTier.glow => 'Glow',
        PromotionTier.spotlight => 'Spotlight',
      };
}

enum PromotionTargetKind { listing, restaurant, manufacturer }

enum PromotionStatus { scheduled, active, ended, cancelled, refunded }

enum PromotionSource { paid, proIncluded, enterpriseIncluded, founderCredit, bundle }

/// Admin-editable capacity / placement / pricing (single source of truth).
@immutable
class PromotionConfig {
  const PromotionConfig({
    this.spotlightMaxActive = 8,
    this.glowMaxActive = 16,
    this.boldMaxActive = 40,
    this.homeFeaturedMax = 10,
    this.homeRestaurantMax = 4,
    this.pinnedMaxOnSort = 6,
    this.spotlightRepeatEvery = 12,
    this.spotlightRepeatMax = 2,
    this.labelBold = false,
    this.prices = const {
      PromotionTier.bold: {14: 15, 30: 25},
      PromotionTier.glow: {14: 49, 30: 79},
      PromotionTier.spotlight: {14: 69, 30: 99},
    },
  });

  final int spotlightMaxActive;
  final int glowMaxActive;
  final int boldMaxActive;
  final int homeFeaturedMax;
  final int homeRestaurantMax;
  final int pinnedMaxOnSort;
  final int spotlightRepeatEvery;
  final int spotlightRepeatMax;
  /// Kept for stored-config compatibility; Bold cards never show a label.
  final bool labelBold;
  /// `{tier: {durationDays: pricePln}}`.
  final Map<PromotionTier, Map<int, int>> prices;

  int pricePln(PromotionTier tier, int days) => prices[tier]?[days] ?? 0;

  /// Duration options (days) offered for any tier, ascending.
  List<int> get durations => {for (final m in prices.values) ...m.keys}.toList()..sort();

  /// Shortest offered promotion period.
  int get defaultDays => durations.first;

  int maxActive(PromotionTier tier) => switch (tier) {
        PromotionTier.spotlight => spotlightMaxActive,
        PromotionTier.glow => glowMaxActive,
        PromotionTier.bold => boldMaxActive,
      };

  PromotionConfig copyWith({
    int? spotlightMaxActive,
    int? glowMaxActive,
    int? boldMaxActive,
    int? homeFeaturedMax,
    int? homeRestaurantMax,
    int? pinnedMaxOnSort,
    int? spotlightRepeatEvery,
    int? spotlightRepeatMax,
    bool? labelBold,
    Map<PromotionTier, Map<int, int>>? prices,
  }) =>
      PromotionConfig(
        spotlightMaxActive: spotlightMaxActive ?? this.spotlightMaxActive,
        glowMaxActive: glowMaxActive ?? this.glowMaxActive,
        boldMaxActive: boldMaxActive ?? this.boldMaxActive,
        homeFeaturedMax: homeFeaturedMax ?? this.homeFeaturedMax,
        homeRestaurantMax: homeRestaurantMax ?? this.homeRestaurantMax,
        pinnedMaxOnSort: pinnedMaxOnSort ?? this.pinnedMaxOnSort,
        spotlightRepeatEvery: spotlightRepeatEvery ?? this.spotlightRepeatEvery,
        spotlightRepeatMax: spotlightRepeatMax ?? this.spotlightRepeatMax,
        labelBold: labelBold ?? this.labelBold,
        prices: prices ?? this.prices,
      );

  static const PromotionConfig defaults = PromotionConfig();
}

@immutable
class Promotion {
  const Promotion({
    required this.id,
    required this.ownerId,
    required this.targetKind,
    required this.targetRef,
    required this.tier,
    required this.durationDays,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.pricePln,
    required this.source,
    this.paymentId,
    this.upgradedFrom,
  });

  final String id;
  final String ownerId;
  final PromotionTargetKind targetKind;
  final String targetRef;
  final PromotionTier tier;
  /// Paid period length in days.
  final int durationDays;
  final DateTime startsAt;
  final DateTime endsAt;
  final PromotionStatus status;
  final int pricePln;
  final PromotionSource source;
  final String? paymentId;
  final String? upgradedFrom;

  bool isActiveAt(DateTime now) =>
      status == PromotionStatus.active && !now.isBefore(startsAt) && now.isBefore(endsAt);

  Promotion copyWith({
    PromotionStatus? status,
    DateTime? startsAt,
    DateTime? endsAt,
    PromotionTier? tier,
    String? upgradedFrom,
  }) =>
      Promotion(
        id: id,
        ownerId: ownerId,
        targetKind: targetKind,
        targetRef: targetRef,
        tier: tier ?? this.tier,
        durationDays: durationDays,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        status: status ?? this.status,
        pricePln: pricePln,
        source: source,
        paymentId: paymentId,
        upgradedFrom: upgradedFrom ?? this.upgradedFrom,
      );
}

@immutable
class PromotionStat {
  const PromotionStat({
    required this.promotionId,
    required this.date,
    this.impressions = 0,
    this.clicks = 0,
  });

  final String promotionId;
  final DateTime date;
  final int impressions;
  final int clicks;

  PromotionStat copyWith({int? impressions, int? clicks}) => PromotionStat(
        promotionId: promotionId,
        date: date,
        impressions: impressions ?? this.impressions,
        clicks: clicks ?? this.clicks,
      );
}

/// Surface context for [PromotionEngine.compose].
enum PromotionSurface { homeFeatured, homeRestaurant, products, restaurants }

enum PromotionSortMode { recommended, other }

@immutable
class PromotionComposeContext {
  const PromotionComposeContext({
    required this.surface,
    required this.sort,
    required this.page,
    required this.sessionSeed,
    this.deviceIsPhone = false,
  });

  final PromotionSurface surface;
  final PromotionSortMode sort;
  final int page;
  final int sessionSeed;
  final bool deviceIsPhone;
}

/// One slot in a composed feed (organic or paid).
@immutable
class PromotionSlot<T> {
  const PromotionSlot({
    required this.item,
    this.promotion,
    this.isRepeat = false,
  });

  final T item;
  final Promotion? promotion;
  final bool isRepeat;

  PromotionTier? get tier => promotion?.tier;
  bool get isPaid => promotion != null;
}
