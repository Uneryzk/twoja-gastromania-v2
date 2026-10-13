import 'dart:math';

import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/tg_core/promotion_engine.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// Legacy constant — catalogue pinned capacity now comes from [PromotionConfig].
@Deprecated('Use PromotionConfig.pinnedMaxOnSort / composeCatalogue')
const int kPromotedSlots = 6;

// ---------------------------------------------------------------------------
// Price helpers. Filters always compare on a *net* basis so a brutto and a
// netto listing of the same real price are treated identically.
// ---------------------------------------------------------------------------

int? productPriceNet(TGProduct p) {
  final price = p.price;
  if (price == null) return null;
  return p.priceBasis == TGPriceBasis.brutto ? (price / (1 + TGPricing.vatRate)).round() : price;
}

int basisToNet(int value, TGPriceFilterBasis basis) =>
    basis == TGPriceFilterBasis.brutto ? (value / (1 + TGPricing.vatRate)).round() : value;

int netToBasis(int net, TGPriceFilterBasis basis) =>
    basis == TGPriceFilterBasis.brutto ? (net * (1 + TGPricing.vatRate)).round() : net;

int? productPriceForBasis(TGProduct p, TGPriceFilterBasis basis) {
  final net = productPriceNet(p);
  return net == null ? null : netToBasis(net, basis);
}

/// Best-effort brand guess: the part of the title after the last dash.
String productBrand(TGProduct p) {
  final title = p.title;
  if (title.contains('–')) return title.split('–').last.trim();
  if (title.contains('-')) return title.split('-').last.trim();
  return '';
}

// ---------------------------------------------------------------------------
// Filtering
// ---------------------------------------------------------------------------

bool _cityMatches(TGProduct p, TGProductsQueryState q) {
  final city = q.city!.trim();
  if (TGGeo.sameName(p.city, city)) return true;
  if (q.radiusKm <= 0) return false;
  final km = TGGeo.distanceBetween(city, p.city);
  return km != null && km <= q.radiusKm;
}

List<TGProduct> publicActiveOnly(Iterable<TGProduct> all) =>
    all.where((p) => p.isPubliclyVisible).toList(growable: false);

List<TGProduct> mergeOwnedListings(Iterable<TGProduct> seed, Iterable<TGProduct> owned) {
  final map = <String, TGProduct>{for (final p in seed) p.id: p};
  for (final p in owned) {
    map.putIfAbsent(p.id, () => p);
  }
  return map.values.toList(growable: false);
}

/// Applies every filter in [q] (but not sorting or pagination).
List<TGProduct> applyFilters(Iterable<TGProduct> all, TGProductsQueryState q) {
  Iterable<TGProduct> it = publicActiveOnly(all);

  if (q.listingType != null) it = it.where((p) => p.listingType == q.listingType);
  if (q.verifiedOnly) it = it.where((p) => tgShowsVerifiedSellerBadge(p.seller));
  if (q.conditions.isNotEmpty) it = it.where((p) => q.conditions.contains(p.condition));
  if (q.categories.isNotEmpty) it = it.where((p) => q.categories.contains(p.category));
  if (q.voivodeships.isNotEmpty) {
    final wanted = q.voivodeships.map(TGGeo.normalize).toSet();
    it = it.where((p) => wanted.contains(TGGeo.normalize(p.voivodeship)));
  }
  if (q.hasCity) it = it.where((p) => _cityMatches(p, q));
  if (q.powerTypes.isNotEmpty) it = it.where((p) => q.powerTypes.contains(p.powerType));
  if (q.delivery != null) it = it.where((p) => p.delivery == q.delivery);
  if (q.pickup != null) it = it.where((p) => p.pickup == q.pickup);
  if (q.warrantyMinMonths != null) it = it.where((p) => p.warrantyMonths >= q.warrantyMinMonths!);
  if (q.sellerTypes.isNotEmpty) it = it.where((p) => q.sellerTypes.contains(p.seller.type));
  if (q.hasBrand) {
    final b = q.brand!.trim().toLowerCase();
    it = it.where((p) => productBrand(p).toLowerCase().contains(b) || p.title.toLowerCase().contains(b));
  }
  if (q.hasSearch) {
    final needle = q.search!.trim().toLowerCase();
    it = it.where((p) =>
        p.title.toLowerCase().contains(needle) ||
        (p.description ?? '').toLowerCase().contains(needle) ||
        productBrand(p).toLowerCase().contains(needle));
  }

  final minNet = q.minPrice == null ? null : basisToNet(q.minPrice!, q.priceFilterBasis);
  final maxNet = q.maxPrice == null ? null : basisToNet(q.maxPrice!, q.priceFilterBasis);
  it = it.where((p) {
    final net = productPriceNet(p);
    if (net == null) return q.includeNoPrice;
    if (minNet != null && net < minNet) return false;
    if (maxNet != null && net > maxNet) return false;
    return true;
  });

  return it.toList(growable: false);
}

// ---------------------------------------------------------------------------
// Sorting
// ---------------------------------------------------------------------------

/// Returns a new list sorted according to [q.sort]. Never mutates the input.
List<TGProduct> sortProducts(Iterable<TGProduct> input, TGProductsQueryState q) {
  final list = input.toList();

  int byNewest(TGProduct a, TGProduct b) => b.createdAt.compareTo(a.createdAt);
  int thenNewest(int c, TGProduct a, TGProduct b) => c != 0 ? c : byNewest(a, b);

  switch (q.sort) {
    case TGProductsSort.recommended:
      list.sort((a, b) {
        final r = b.seller.rating.compareTo(a.seller.rating);
        return thenNewest(r, a, b);
      });
    case TGProductsSort.newest:
      list.sort(byNewest);
    case TGProductsSort.priceLowHigh:
      // Listings without a price always go last.
      list.sort((a, b) {
        final pa = productPriceNet(a);
        final pb = productPriceNet(b);
        if (pa == null && pb == null) return byNewest(a, b);
        if (pa == null) return 1;
        if (pb == null) return -1;
        return thenNewest(pa.compareTo(pb), a, b);
      });
    case TGProductsSort.priceHighLow:
      list.sort((a, b) {
        final pa = productPriceNet(a);
        final pb = productPriceNet(b);
        if (pa == null && pb == null) return byNewest(a, b);
        if (pa == null) return 1;
        if (pb == null) return -1;
        return thenNewest(pb.compareTo(pa), a, b);
      });
    case TGProductsSort.nearest:
      if (q.hasCity && TGGeo.lookup(q.city) != null) {
        double dist(TGProduct p) => TGGeo.distanceBetween(q.city!, p.city) ?? double.infinity;
        list.sort((a, b) => thenNewest(dist(a).compareTo(dist(b)), a, b));
      } else {
        list.sort(byNewest);
      }
    case TGProductsSort.longestWarranty:
      list.sort((a, b) => thenNewest(b.warrantyMonths.compareTo(a.warrantyMonths), a, b));
  }
  return list;
}

// ---------------------------------------------------------------------------
// Promoted listings
// ---------------------------------------------------------------------------

/// Picks promoted listings (legacy helper). Prefer [computeResults] / engine.
List<TGProduct> pickPromoted(Iterable<TGProduct> filtered, {required int seed, int limit = 40}) {
  PromotionService.instance.ensureSeeded();
  final list = filtered.toList();
  final slots = PromotionEngine.composeCatalogue<TGProduct>(
    filteredOrganic: list,
    idOf: (p) => p.id,
    promoOf: (p) => PromotionService.instance.effectiveListingPromo(p),
    context: PromotionComposeContext(
      surface: PromotionSurface.products,
      sort: PromotionSortMode.recommended,
      page: 1,
      sessionSeed: seed,
    ),
  ).pinned;
  return [for (final s in slots.take(limit)) s.item];
}

/// Filtered results split into the sticky promoted block and the sorted rest.
class TGProductResults {
  const TGProductResults({
    required this.promoted,
    required this.organic,
    this.promoById = const {},
    this.promoIdByTarget = const {},
    this.spotlightPromos = const [],
    this.sessionSeed = 0,
    this.sortMode = PromotionSortMode.recommended,
  });

  static const empty = TGProductResults(promoted: [], organic: []);

  /// Always rendered first, whatever the sort order is.
  final List<TGProduct> promoted;

  /// Organic feed without spotlight repeats (repeats are page-local).
  final List<TGProduct> organic;

  /// Tier lookup for card chrome.
  final Map<String, PromotionTier?> promoById;

  /// Promotion id by listing id (for impression/click).
  final Map<String, String> promoIdByTarget;

  /// Active spotlights used for per-page repeat injection.
  final List<Promotion> spotlightPromos;

  final int sessionSeed;
  final PromotionSortMode sortMode;

  /// Total number of matching listings (promoted + organic; repeats excluded).
  int get total => promoted.length + organic.length;

  /// Organic page slice with Spotlight repeats injected (not counted in [total]).
  List<PromotionSlot<TGProduct>> visibleOrganicSlots({
    required int page,
    required int perPage,
    required bool accumulate,
  }) {
    final slice = accumulate
        ? organic.take(page * perPage).toList()
        : paginate(organic, page, perPage: perPage);
    Promotion? promoFor(TGProduct p) {
      final id = promoIdByTarget[p.id];
      if (id == null) return null;
      return PromotionService.instance.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id) ??
          PromotionService.instance.effectiveListingPromo(p);
    }

    final slots = [for (final p in slice) PromotionSlot(item: p, promotion: promoFor(p))];
    if (sortMode != PromotionSortMode.recommended || spotlightPromos.isEmpty) return slots;

    final byId = {for (final p in [...promoted, ...organic]) p.id: p};
    final shown = {...promoted.map((p) => p.id), ...slice.map((p) => p.id)};
    return PromotionEngine.withSpotlightRepeats(
      pageOrganic: slots,
      spotlights: spotlightPromos,
      byId: byId,
      alreadyShownOnPage: shown,
      page: page,
      sessionSeed: sessionSeed,
    );
  }
}

TGProductResults computeResults(
  Iterable<TGProduct> all,
  TGProductsQueryState q, {
  required int promotedSeed,
  int page = 1,
}) {
  PromotionService.instance.ensureSeeded();
  final filtered = applyFilters(all, q);
  final sortMode = q.sort == TGProductsSort.recommended ? PromotionSortMode.recommended : PromotionSortMode.other;
  final sortedOrganic = sortProducts(filtered, q);
  final composed = PromotionEngine.composeCatalogue<TGProduct>(
    filteredOrganic: sortedOrganic,
    idOf: (p) => p.id,
    promoOf: (p) => PromotionService.instance.effectiveListingPromo(p),
    context: PromotionComposeContext(
      surface: PromotionSurface.products,
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
  return TGProductResults(
    promoted: [for (final s in composed.pinned) s.item],
    organic: [for (final s in composed.feed) s.item],
    promoById: promoById,
    promoIdByTarget: promoIdByTarget,
    spotlightPromos: composed.spotlights,
    sessionSeed: promotedSeed,
    sortMode: sortMode,
  );
}

/// Total number of results [q] would show – used for the live counter in the
/// mobile filter sheet.
int countResults(Iterable<TGProduct> all, TGProductsQueryState q) => applyFilters(all, q).length;

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

List<T> paginate<T>(List<T> items, int page, {required int perPage}) {
  final p = max(1, page);
  final start = (p - 1) * perPage;
  if (start >= items.length) return const [];
  return items.sublist(start, min(items.length, start + perPage));
}

int pageCount(int itemCount, int perPage) => max(1, (itemCount / perPage).ceil());
