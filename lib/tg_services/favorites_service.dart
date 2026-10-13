import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_favorite.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Per-user saved listings. Mock rows are hidden in Production Mode.
class TGFavoritesService extends ChangeNotifier {
  TGFavoritesService._();
  static final TGFavoritesService instance = TGFavoritesService._();

  final List<TGFavorite> _items = [];

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _items.clear();
    notifyListeners();
  }

  List<TGFavorite> forUser(String userId, {FavoriteKind? kind}) {
    final rows = _items
        .where((f) => f.userId == userId && (kind == null || f.kind == kind) && !(_hideMock && f.isMock))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return rows;
  }

  bool isFavorite(String userId, FavoriteKind kind, String listingId) =>
      _items.any((f) => f.userId == userId && f.kind == kind && f.listingId == listingId && !(_hideMock && f.isMock));

  void add(TGFavorite fav) {
    if (_items.any((f) => f.key == fav.key)) return;
    _items.add(fav);
    notifyListeners();
  }

  bool remove(String userId, FavoriteKind kind, String listingId, {String source = 'dashboard'}) {
    final before = _items.length;
    _items.removeWhere((f) => f.userId == userId && f.kind == kind && f.listingId == listingId);
    if (_items.length == before) return false;
    if (source == 'dashboard') {
      TGAnalytics.track('fav_remove', {'kind': kind.name, 'listingId': listingId});
    }
    notifyListeners();
    return true;
  }

  /// Card / PDP heart. Saving also counts a favorite for the listing's daily
  /// stats unless [countStat] is false (owner or staff).
  bool toggleProduct(String userId, TGProduct p, {required bool countStat}) {
    if (isFavorite(userId, FavoriteKind.equipment, p.id)) {
      remove(userId, FavoriteKind.equipment, p.id, source: 'card');
      return false;
    }
    add(TGFavorite(
      userId: userId,
      kind: FavoriteKind.equipment,
      listingId: p.id,
      savedAt: TGClock.now(),
      title: p.title,
      imageUrl: p.imageUrl,
      path: p.detailPath,
      listingNo: p.listingNo,
      city: p.city,
      priceAtSave: p.price,
    ));
    TGListingStatsService.instance.record(
      listingKey: TGListingStatsService.keyOfProduct(p),
      kind: ListingStatKind.favorite,
      visitorKey: userId,
      count: countStat,
    );
    return true;
  }

  bool setRestaurant(String userId, RestaurantListing r, {required bool on}) {
    if (!on) {
      remove(userId, FavoriteKind.restaurant, r.id, source: 'card');
      return false;
    }
    add(TGFavorite(
      userId: userId,
      kind: FavoriteKind.restaurant,
      listingId: r.id,
      savedAt: TGClock.now(),
      title: r.title,
      imageUrl: r.imageUrl,
      path: r.detailPath,
      listingNo: r.listingNo,
      city: r.city,
      priceAtSave: r.rentMonthly,
    ));
    return true;
  }
}

/// Recorded price edits; favorites derive "Price changed" labels from here.
class TGPriceHistoryService extends ChangeNotifier {
  TGPriceHistoryService._();
  static final TGPriceHistoryService instance = TGPriceHistoryService._();

  final List<PriceHistory> _items = [];

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _items.clear();
    notifyListeners();
  }

  void record({required String listingId, required int oldPln, required int newPln, DateTime? at, bool isMock = false}) {
    if (oldPln == newPln) return;
    _items.add(PriceHistory(listingId: listingId, at: at ?? TGClock.now(), oldPln: oldPln, newPln: newPln, isMock: isMock));
    notifyListeners();
  }

  List<PriceHistory> forListing(String listingId) => _items
      .where((h) => h.listingId == listingId && !(_hideMock && h.isMock))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));

  /// Latest change after [since] (e.g. the moment the listing was saved).
  PriceHistory? latestSince(String listingId, DateTime since) {
    final rows = forListing(listingId).where((h) => h.at.isAfter(since)).toList();
    return rows.isEmpty ? null : rows.last;
  }
}
