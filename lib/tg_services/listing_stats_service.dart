import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Daily per-listing counters behind the dashboard metrics and insights.
/// Mock (seeded) rows are hidden in Production Mode.
class TGListingStatsService extends ChangeNotifier {
  TGListingStatsService._();
  static final TGListingStatsService instance = TGListingStatsService._();

  /// Charts and comparisons need at least this many days of data.
  static const minDays = 7;
  static const comparisonBeforeDays = 14;
  static const periods = [30, 90];

  static String productKey(String id) => 'p:$id';
  static String restaurantKey(String id) => 'r:$id';
  static String keyOfProduct(TGProduct p) => productKey(p.id);
  static String keyOfRestaurant(RestaurantListing r) => restaurantKey(r.id);

  final Map<String, Map<DateTime, ListingStatsDaily>> _rows = {};
  final Set<String> _seen = {};

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _rows.clear();
    _seen.clear();
    notifyListeners();
  }

  /// Records one event. Returns false when it is not counted: [count] is false
  /// for owner / staff traffic, and every visitor counts once per kind per day.
  bool record({
    required String listingKey,
    required ListingStatKind kind,
    required String visitorKey,
    required bool count,
    DateTime? at,
  }) {
    if (!count) return false;
    final day = tgStatsDay(at ?? TGClock.now());
    final seenKey = '$listingKey|${kind.name}|$visitorKey|${day.toIso8601String()}';
    if (!_seen.add(seenKey)) return false;
    final byDay = _rows.putIfAbsent(listingKey, () => {});
    final cur = byDay[day] ?? ListingStatsDaily(listingKey: listingKey, day: day);
    byDay[day] = cur.bump(kind);
    notifyListeners();
    return true;
  }

  Iterable<ListingStatsDaily> _visible(String key) {
    final rows = _rows[key]?.values ?? const <ListingStatsDaily>[];
    return _hideMock ? rows.where((r) => !r.isMock) : rows;
  }

  bool hasAny(String key) => _visible(key).isNotEmpty;

  DateTime? firstDay(String key) {
    DateTime? first;
    for (final r in _visible(key)) {
      if (first == null || r.day.isBefore(first)) first = r.day;
    }
    return first;
  }

  /// Zero-filled series, oldest first, ending today.
  List<ListingStatsDaily> daily(String key, {int days = 30, DateTime? now}) {
    final today = tgStatsDay(now ?? TGClock.now());
    final byDay = {for (final r in _visible(key)) r.day: r};
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return byDay[d] ?? ListingStatsDaily(listingKey: key, day: d);
        }(),
    ];
  }

  ListingStatsTotals totals(String key, {int days = 30, DateTime? now}) {
    final today = tgStatsDay(now ?? TGClock.now());
    final from = DateTime(today.year, today.month, today.day - (days - 1));
    var t = ListingStatsTotals.zero;
    for (final r in _visible(key)) {
      if (!r.day.isBefore(from) && !r.day.isAfter(today)) t = t + r;
    }
    return t;
  }

  ListingStatsTotals totalsFor(Iterable<String> keys, {int days = 30, DateTime? now}) {
    var t = ListingStatsTotals.zero;
    for (final k in keys) {
      t = t.plus(totals(k, days: days, now: now));
    }
    return t;
  }

  /// Days of the window the listing has been tracked: from the later of the
  /// window start, [liveSince] and the first recorded day, up to today.
  int coverageDays(String key, {int days = 30, DateTime? liveSince, DateTime? now}) {
    final first = firstDay(key);
    if (first == null) return 0;
    final today = tgStatsDay(now ?? TGClock.now());
    var start = DateTime(today.year, today.month, today.day - (days - 1));
    if (first.isAfter(start)) start = first;
    if (liveSince != null && tgStatsDay(liveSince).isAfter(start)) start = tgStatsDay(liveSince);
    if (start.isAfter(today)) return 0;
    return today.difference(start).inDays + 1;
  }

  bool hasEnoughData(String key, {int days = 30, DateTime? liveSince, DateTime? now}) =>
      coverageDays(key, days: days, liveSince: liveSince, now: now) >= minDays;

  PromotionComparison compareWithPromotion(String key, Promotion promo, {DateTime? now}) {
    final today = tgStatsDay(now ?? TGClock.now());
    final start = tgStatsDay(promo.startsAt);
    final endRaw = tgStatsDay(promo.endsAt);
    final end = endRaw.isAfter(today) ? today : endRaw;
    final beforeFrom = DateTime(start.year, start.month, start.day - comparisonBeforeDays);
    final first = firstDay(key);
    var during = ListingStatsTotals.zero;
    var before = ListingStatsTotals.zero;
    for (final r in _visible(key)) {
      if (!r.day.isBefore(start) && !r.day.isAfter(end)) during = during + r;
      if (!r.day.isBefore(beforeFrom) && r.day.isBefore(start)) before = before + r;
    }
    final duringDays = end.isBefore(start) ? 0 : end.difference(start).inDays + 1;
    var beforeStart = beforeFrom;
    if (first != null && first.isAfter(beforeStart)) beforeStart = first;
    final beforeDays = first == null || !beforeStart.isBefore(start) ? 0 : start.difference(beforeStart).inDays;
    return PromotionComparison(
      duringDays: duringDays,
      beforeDays: beforeDays,
      during: during,
      before: before,
      enoughData: duringDays >= minDays && beforeDays >= minDays,
    );
  }

  /// Seeds a deterministic mock history from [from] to [to] (default today),
  /// hidden in Production Mode. [boostFrom] lifts views from that day on.
  void seedHistory(String key, {required DateTime from, DateTime? to, int seed = 1, int baseViews = 14, DateTime? boostFrom}) {
    final today = tgStatsDay(TGClock.now());
    var end = tgStatsDay(to ?? today);
    if (end.isAfter(today)) end = today;
    final rnd = Random(seed);
    final byDay = _rows.putIfAbsent(key, () => {});
    final boost = boostFrom == null ? null : tgStatsDay(boostFrom);
    for (var d = tgStatsDay(from); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (byDay.containsKey(d)) continue;
      final weekend = d.weekday >= DateTime.saturday;
      final lift = boost != null && !d.isBefore(boost) ? baseViews ~/ 2 : 0;
      final v = max(0, baseViews + lift + rnd.nextInt(9) - 4 - (weekend ? 3 : 0));
      byDay[d] = ListingStatsDaily(
        listingKey: key,
        day: d,
        views: v,
        callTaps: v ~/ 7 + (rnd.nextInt(5) == 0 ? 1 : 0),
        messages: v ~/ 9 + (rnd.nextInt(6) == 0 ? 1 : 0),
        favorites: rnd.nextInt(4) == 0 ? 1 : 0,
        isMock: true,
      );
    }
    notifyListeners();
  }
}
