import 'dart:math';

import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/restaurants/restaurant_query.dart';
import 'package:twoja_gastromania/tg_core/promotion_engine.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

@Deprecated('Use PromotionConfig / composeCatalogue')
const int kRestoPromotedSlots = 6;
const int kRestoPerPage = 24;
const int kRestoMobilePageSize = 12;
const int kRestoBannerAfterCard = 9;

int? rentNet(RestaurantListing r) {
  if (r.rentBasis == RestaurantVatBasis.vatUnspecified) return null;
  return r.rentBasis == RestaurantVatBasis.brutto
      ? (r.rentMonthly / (1 + TGPricing.vatRate)).round()
      : r.rentMonthly;
}

int? feeNet(RestaurantListing r) {
  if (r.transferFee.isNone) return 0;
  final amount = r.transferFee.amountPln;
  if (amount == null) return null;
  if (r.transferFee.basis == RestaurantVatBasis.vatUnspecified) return null;
  return r.transferFee.basis == RestaurantVatBasis.brutto
      ? (amount / (1 + TGPricing.vatRate)).round()
      : amount;
}

int basisToNet(int value, RestaurantVatBasis basis) =>
    basis == RestaurantVatBasis.brutto ? (value / (1 + TGPricing.vatRate)).round() : value;

bool _cityMatches(RestaurantListing r, RestaurantQueryState q) {
  final city = q.city!.trim();
  if (TGGeo.sameName(r.city, city)) return true;
  if (q.radiusKm <= 0) return false;
  final km = TGGeo.distanceBetween(city, r.city);
  return km != null && km <= q.radiusKm;
}

bool _featureMatches(RestaurantListing r, RestaurantFeature f) => switch (f) {
      RestaurantFeature.terrace => (r.terraceM2 ?? 0) > 0,
      RestaurantFeature.garden => r.details.garden.hasGarden,
      RestaurantFeature.playArea => r.details.playArea.hasPlayArea,
      RestaurantFeature.extraction => r.extractionSystem,
      RestaurantFeature.parking => r.parking,
      RestaurantFeature.equipmentList => r.inventory.isNotEmpty,
      RestaurantFeature.alcoholPermit => r.alcoholPermit.inPlace,
      RestaurantFeature.takeawayDelivery => r.details.deliveryOnline,
    };

bool _leaseMatches(RestaurantListing r, RestaurantLeaseMin min) {
  if (min == RestaurantLeaseMin.any) return true;
  if (min == RestaurantLeaseMin.indefinite) return r.leaseType == RestaurantLeaseType.indefinite;
  if (r.leaseType == RestaurantLeaseType.indefinite) return true;
  final ends = r.leaseEndsAt;
  if (ends == null) return false;
  final months = ends.difference(DateTime.now()).inDays / 30.0;
  final need = switch (min) {
    RestaurantLeaseMin.m12 => 12,
    RestaurantLeaseMin.m24 => 24,
    RestaurantLeaseMin.m36 => 36,
    _ => 0,
  };
  return months >= need;
}

bool _availMatches(RestaurantListing r, RestaurantAvailFilter a) {
  if (a == RestaurantAvailFilter.any) return true;
  final days = r.availableFrom.difference(DateTime.now()).inDays;
  return switch (a) {
    RestaurantAvailFilter.immediately => days <= 0,
    RestaurantAvailFilter.within1m => days <= 31,
    RestaurantAvailFilter.within3m => days <= 93,
    RestaurantAvailFilter.any => true,
  };
}

List<RestaurantListing> applyRestaurantFilters(Iterable<RestaurantListing> all, RestaurantQueryState q) {
  Iterable<RestaurantListing> it = all.where((r) => r.isPubliclyVisible);

  if (q.verifiedOnly) it = it.where((r) => r.seller.verified);
  if (q.businessTypes.isNotEmpty) it = it.where((r) => q.businessTypes.contains(r.businessType));
  if (q.voivodeships.isNotEmpty) {
    final wanted = q.voivodeships.map(TGGeo.normalize).toSet();
    it = it.where((r) => wanted.contains(TGGeo.normalize(r.voivodeship)));
  }
  if (q.hasCity) it = it.where((r) => _cityMatches(r, q));
  if (q.areaMin != null) it = it.where((r) => r.totalAreaM2 >= q.areaMin!);
  if (q.areaMax != null) it = it.where((r) => r.totalAreaM2 <= q.areaMax!);

  if (q.rentMax != null) {
    final maxNet = basisToNet(q.rentMax!, q.rentBasis);
    it = it.where((r) {
      final net = rentNet(r);
      if (net == null) return q.includeVatUnspecified;
      return net <= maxNet;
    });
  } else if (!q.includeVatUnspecified) {
    it = it.where((r) => r.rentBasis != RestaurantVatBasis.vatUnspecified);
  }

  if (q.feeMax != null) {
    final maxNet = basisToNet(q.feeMax!, q.feeBasis);
    it = it.where((r) {
      if (r.transferFee.isNone) return q.includeNoTransferFee;
      final net = feeNet(r);
      if (net == null) return q.includeVatUnspecified;
      return net <= maxNet;
    });
  } else if (!q.includeNoTransferFee) {
    it = it.where((r) => !r.transferFee.isNone);
  }

  if (q.leaseMin != RestaurantLeaseMin.any) it = it.where((r) => _leaseMatches(r, q.leaseMin));
  for (final f in q.features) {
    it = it.where((r) => _featureMatches(r, f));
  }
  if (q.avail != RestaurantAvailFilter.any) it = it.where((r) => _availMatches(r, q.avail));
  if (q.sellerFilters.isNotEmpty) {
    it = it.where((r) {
      if (q.sellerFilters.contains(RestaurantSellerFilter.owner) && r.posterRole == RestaurantPosterRole.owner) {
        return true;
      }
      if (q.sellerFilters.contains(RestaurantSellerFilter.agent) && r.posterRole == RestaurantPosterRole.agent) {
        return true;
      }
      return false;
    });
  }

  return it.toList(growable: false);
}

List<RestaurantListing> sortRestaurants(Iterable<RestaurantListing> input, RestaurantQueryState q) {
  final list = input.toList();
  int byNewest(RestaurantListing a, RestaurantListing b) =>
      (b.publishedAt ?? DateTime(2000)).compareTo(a.publishedAt ?? DateTime(2000));
  int thenNewest(int c, RestaurantListing a, RestaurantListing b) => c != 0 ? c : byNewest(a, b);

  switch (q.sort) {
    case RestaurantSort.recommended:
      list.sort((a, b) {
        final r = b.seller.rating.compareTo(a.seller.rating);
        return thenNewest(r, a, b);
      });
    case RestaurantSort.newest:
      list.sort(byNewest);
    case RestaurantSort.rentLowHigh:
      list.sort((a, b) {
        final ra = rentNet(a) ?? 1 << 30;
        final rb = rentNet(b) ?? 1 << 30;
        return thenNewest(ra.compareTo(rb), a, b);
      });
    case RestaurantSort.rentHighLow:
      list.sort((a, b) {
        final ra = rentNet(a) ?? -1;
        final rb = rentNet(b) ?? -1;
        return thenNewest(rb.compareTo(ra), a, b);
      });
    case RestaurantSort.feeLowHigh:
      list.sort((a, b) {
        final fa = feeNet(a) ?? (a.transferFee.isNone ? 0 : 1 << 30);
        final fb = feeNet(b) ?? (b.transferFee.isNone ? 0 : 1 << 30);
        return thenNewest(fa.compareTo(fb), a, b);
      });
    case RestaurantSort.feeHighLow:
      list.sort((a, b) {
        final fa = feeNet(a) ?? (a.transferFee.isNone ? -1 : -1);
        final fb = feeNet(b) ?? (b.transferFee.isNone ? -1 : -1);
        return thenNewest(fb.compareTo(fa), a, b);
      });
    case RestaurantSort.area:
      list.sort((a, b) => thenNewest(b.totalAreaM2.compareTo(a.totalAreaM2), a, b));
    case RestaurantSort.nearest:
      if (q.hasCity && TGGeo.lookup(q.city) != null) {
        double dist(RestaurantListing r) => TGGeo.distanceBetween(q.city!, r.city) ?? double.infinity;
        list.sort((a, b) => thenNewest(dist(a).compareTo(dist(b)), a, b));
      } else {
        list.sort(byNewest);
      }
  }
  return list;
}

List<RestaurantListing> pickPromotedRestaurants(
  Iterable<RestaurantListing> filtered, {
  required int seed,
  int limit = 40,
}) {
  PromotionService.instance.ensureSeeded();
  final list = filtered.toList();
  final slots = PromotionEngine.composeCatalogue<RestaurantListing>(
    filteredOrganic: list,
    idOf: (r) => r.id,
    promoOf: (r) => PromotionService.instance.effectiveRestaurantPromo(r),
    context: PromotionComposeContext(
      surface: PromotionSurface.restaurants,
      sort: PromotionSortMode.recommended,
      page: 1,
      sessionSeed: seed,
    ),
  ).pinned;
  return [for (final s in slots.take(limit)) s.item];
}

class RestaurantResults {
  const RestaurantResults({
    required this.promoted,
    required this.organic,
    this.promoById = const {},
    this.promoIdByTarget = const {},
    this.spotlightPromos = const [],
    this.sessionSeed = 0,
    this.sortMode = PromotionSortMode.recommended,
  });
  static const empty = RestaurantResults(promoted: [], organic: []);
  final List<RestaurantListing> promoted;
  final List<RestaurantListing> organic;
  final Map<String, PromotionTier?> promoById;
  final Map<String, String> promoIdByTarget;
  final List<Promotion> spotlightPromos;
  final int sessionSeed;
  final PromotionSortMode sortMode;
  int get total => promoted.length + organic.length;
  List<RestaurantListing> get allOrdered => [...promoted, ...organic];
}

RestaurantResults computeRestaurantResults(
  Iterable<RestaurantListing> all,
  RestaurantQueryState q, {
  required int promotedSeed,
  int page = 1,
}) {
  PromotionService.instance.ensureSeeded();
  final filtered = applyRestaurantFilters(all, q);
  final sortMode = q.sort == RestaurantSort.recommended ? PromotionSortMode.recommended : PromotionSortMode.other;
  final sorted = sortRestaurants(filtered, q);
  final composed = PromotionEngine.composeCatalogue<RestaurantListing>(
    filteredOrganic: sorted,
    idOf: (r) => r.id,
    promoOf: (r) => PromotionService.instance.effectiveRestaurantPromo(r),
    context: PromotionComposeContext(
      surface: PromotionSurface.restaurants,
      sort: sortMode,
      page: page,
      sessionSeed: promotedSeed,
    ),
  );
  final promoById = <String, PromotionTier?>{};
  final promoIdByTarget = <String, String>{};
  for (final s in [...composed.pinned, ...composed.feed]) {
    if (s.promotion == null) continue;
    promoById[s.item.id] = s.promotion!.tier;
    promoIdByTarget[s.item.id] = s.promotion!.id;
  }
  for (final p in composed.spotlights) {
    promoById[p.targetRef] = p.tier;
    promoIdByTarget[p.targetRef] = p.id;
  }
  return RestaurantResults(
    promoted: [for (final s in composed.pinned) s.item],
    organic: [for (final s in composed.feed) s.item],
    promoById: promoById,
    promoIdByTarget: promoIdByTarget,
    spotlightPromos: composed.spotlights,
    sessionSeed: promotedSeed,
    sortMode: sortMode,
  );
}

int countRestaurantResults(Iterable<RestaurantListing> all, RestaurantQueryState q) =>
    applyRestaurantFilters(all, q).length;

List<T> restoPaginate<T>(List<T> items, int page, {required int perPage}) {
  final p = max(1, page);
  final start = (p - 1) * perPage;
  if (start >= items.length) return const [];
  return items.sublist(start, min(items.length, start + perPage));
}

int restoPageCount(int itemCount, int perPage) => max(1, (itemCount / perPage).ceil());
