import 'dart:math';

import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// How many promoted listings are pinned above the organic results.
const int kPromotedSlots = 3;

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
  if (q.verifiedOnly) it = it.where((p) => p.seller.verified);
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

/// Picks up to [limit] promoted listings out of [filtered].
///
/// Promoted listings obey the active filters (a promoted fridge never shows up
/// in a "Rent" search) but are NEVER re-ordered by the sort option – they are
/// rotated with a per-session [seed] so every promoted seller gets exposure.
List<TGProduct> pickPromoted(Iterable<TGProduct> filtered, {required int seed, int limit = kPromotedSlots}) {
  final promoted = filtered.where((p) => p.isPromoted).toList()..sort((a, b) => a.id.compareTo(b.id));
  if (promoted.isEmpty) return const [];
  promoted.shuffle(Random(seed));
  return promoted.take(limit).toList(growable: false);
}

/// Filtered results split into the sticky promoted block and the sorted rest.
class TGProductResults {
  const TGProductResults({required this.promoted, required this.organic});

  static const empty = TGProductResults(promoted: [], organic: []);

  /// Always rendered first, whatever the sort order is.
  final List<TGProduct> promoted;

  /// Everything else, in the requested sort order.
  final List<TGProduct> organic;

  /// Total number of matching listings (promoted + organic).
  int get total => promoted.length + organic.length;
}

TGProductResults computeResults(
  Iterable<TGProduct> all,
  TGProductsQueryState q, {
  required int promotedSeed,
}) {
  final filtered = applyFilters(all, q);
  final promoted = pickPromoted(filtered, seed: promotedSeed);
  final promotedIds = promoted.map((p) => p.id).toSet();
  final organic = sortProducts(filtered.where((p) => !promotedIds.contains(p.id)), q);
  return TGProductResults(promoted: promoted, organic: organic);
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
