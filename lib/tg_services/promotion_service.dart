import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// VITRIN-1 promotions + daily stats. Legacy `promotedUntil` maps to glow.
class PromotionService extends ChangeNotifier {
  PromotionService._();
  static final PromotionService instance = PromotionService._();

  PromotionConfig _config = PromotionConfig.defaults;
  final List<Promotion> _items = [];
  final Map<String, PromotionStat> _stats = {};
  bool _seeded = false;

  PromotionConfig get config => _config;
  List<Promotion> get all => List.unmodifiable(_items);

  void setConfig(PromotionConfig next) {
    _config = next;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    if (!TGRevenueConfigService.instance.productionMode) {
      _seedMocks();
    }
  }

  List<Promotion> active({PromotionTargetKind? kind, DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    return [
      for (final p in _items)
        if (p.isActiveAt(t) && (kind == null || p.targetKind == kind)) p,
    ];
  }

  Promotion? activeFor({required PromotionTargetKind kind, required String targetRef, DateTime? now}) {
    final t = now ?? TGClock.now();
    for (final p in active(kind: kind, now: t)) {
      if (p.targetRef == targetRef) return p;
    }
    return null;
  }

  /// Effective paid promotion for a product (new model or legacy isPromoted → glow).
  Promotion? effectiveListingPromo(TGProduct product, {DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    final live = activeFor(kind: PromotionTargetKind.listing, targetRef: product.id, now: t);
    if (live != null) return live;
    if (!product.isPromoted) return null;
    final end = product.promotedUntil ?? t.add(const Duration(days: 14));
    if (!t.isBefore(end)) return null;
    return Promotion(
      id: 'legacy-${product.id}',
      ownerId: product.ownerId ?? product.seller.id,
      targetKind: PromotionTargetKind.listing,
      targetRef: product.id,
      tier: PromotionTier.glow,
      durationKey: PromotionDurationKey.week2,
      startsAt: t.subtract(const Duration(days: 1)),
      endsAt: end,
      status: PromotionStatus.active,
      pricePln: _config.pricePln(PromotionTier.glow, PromotionDurationKey.week2),
      source: PromotionSource.paid,
    );
  }

  Promotion? effectiveRestaurantPromo(RestaurantListing listing, {DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    final live = activeFor(kind: PromotionTargetKind.restaurant, targetRef: listing.id, now: t);
    if (live != null) return live;
    if (!listing.isPromoted) return null;
    final end = listing.promotedUntil ?? t.add(const Duration(days: 14));
    if (!t.isBefore(end)) return null;
    return Promotion(
      id: 'legacy-resto-${listing.id}',
      ownerId: listing.ownerId,
      targetKind: PromotionTargetKind.restaurant,
      targetRef: listing.id,
      tier: PromotionTier.glow,
      durationKey: PromotionDurationKey.week2,
      startsAt: t.subtract(const Duration(days: 1)),
      endsAt: end,
      status: PromotionStatus.active,
      pricePln: _config.pricePln(PromotionTier.glow, PromotionDurationKey.week2),
      source: PromotionSource.paid,
    );
  }

  void recordImpression(String promotionId, {required bool count}) {
    if (!count || promotionId.isEmpty) return;
    final key = _statKey(promotionId);
    final cur = _stats[key] ?? PromotionStat(promotionId: promotionId, date: _day(TGClock.now()));
    _stats[key] = cur.copyWith(impressions: cur.impressions + 1);
  }

  void recordClick(String promotionId, {required bool count}) {
    if (!count || promotionId.isEmpty) return;
    final key = _statKey(promotionId);
    final cur = _stats[key] ?? PromotionStat(promotionId: promotionId, date: _day(TGClock.now()));
    _stats[key] = cur.copyWith(clicks: cur.clicks + 1);
  }

  PromotionStat? statFor(String promotionId) => _stats[_statKey(promotionId)];

  void resetForTests() {
    _items.clear();
    _stats.clear();
    _seeded = false;
    _config = PromotionConfig.defaults;
  }

  void _seedMocks() {
    final now = TGClock.now();

    Promotion mk({
      required String id,
      required String ownerId,
      required PromotionTargetKind kind,
      required String ref,
      required PromotionTier tier,
      required PromotionDurationKey dur,
      required PromotionStatus status,
      int startOffsetDays = -1,
      PromotionSource source = PromotionSource.paid,
    }) {
      final start = now.add(Duration(days: startOffsetDays));
      return Promotion(
        id: id,
        ownerId: ownerId,
        targetKind: kind,
        targetRef: ref,
        tier: tier,
        durationKey: dur,
        startsAt: start,
        endsAt: start.add(Duration(days: dur.days)),
        status: status,
        pricePln: _config.pricePln(tier, dur),
        source: source,
        paymentId: source == PromotionSource.paid ? 'pay-$id' : null,
      );
    }

    // 4 Spotlight · 6 Glow · 8 Bold · 1 scheduled · 1 ended (mixed targets).
    _items.addAll([
      mk(id: 'promo-sp-1', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p001', tier: PromotionTier.spotlight, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-sp-2', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p002', tier: PromotionTier.spotlight, dur: PromotionDurationKey.month1, status: PromotionStatus.active),
      mk(id: 'promo-sp-3', ownerId: 'seller_mateusz', kind: PromotionTargetKind.restaurant, ref: 'r001', tier: PromotionTier.spotlight, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-sp-4', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p003', tier: PromotionTier.spotlight, dur: PromotionDurationKey.week2, status: PromotionStatus.active, source: PromotionSource.enterpriseIncluded),
      mk(id: 'promo-gl-1', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p004', tier: PromotionTier.glow, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-gl-2', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p005', tier: PromotionTier.glow, dur: PromotionDurationKey.month1, status: PromotionStatus.active),
      mk(id: 'promo-gl-3', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p006', tier: PromotionTier.glow, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-gl-4', ownerId: 'seller_anna', kind: PromotionTargetKind.restaurant, ref: 'r002', tier: PromotionTier.glow, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-gl-5', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p008', tier: PromotionTier.glow, dur: PromotionDurationKey.month1, status: PromotionStatus.active, source: PromotionSource.proIncluded),
      mk(id: 'promo-gl-6', ownerId: 'seller_mateusz', kind: PromotionTargetKind.listing, ref: 'p009', tier: PromotionTier.glow, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-1', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p010', tier: PromotionTier.bold, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-2', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p011', tier: PromotionTier.bold, dur: PromotionDurationKey.month1, status: PromotionStatus.active),
      mk(id: 'promo-bo-3', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p013', tier: PromotionTier.bold, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-4', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p014', tier: PromotionTier.bold, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-5', ownerId: 'seller_mateusz', kind: PromotionTargetKind.listing, ref: 'p015', tier: PromotionTier.bold, dur: PromotionDurationKey.month1, status: PromotionStatus.active),
      mk(id: 'promo-bo-6', ownerId: 'seller_karol', kind: PromotionTargetKind.restaurant, ref: 'r003', tier: PromotionTier.bold, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-7', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p016', tier: PromotionTier.bold, dur: PromotionDurationKey.week2, status: PromotionStatus.active),
      mk(id: 'promo-bo-8', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p017', tier: PromotionTier.bold, dur: PromotionDurationKey.month1, status: PromotionStatus.active),
      mk(id: 'promo-sched-1', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p018', tier: PromotionTier.glow, dur: PromotionDurationKey.week2, status: PromotionStatus.scheduled, startOffsetDays: 3),
      mk(id: 'promo-ended-1', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p019', tier: PromotionTier.spotlight, dur: PromotionDurationKey.week2, status: PromotionStatus.ended, startOffsetDays: -20),
    ]);
  }

  String _statKey(String promotionId) {
    final d = _day(TGClock.now());
    return '$promotionId-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
