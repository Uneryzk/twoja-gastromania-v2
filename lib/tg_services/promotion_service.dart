import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Unpaid capacity hold — released after [PricingConfig.reservationHoldHours].
@immutable
class PromotionReservation {
  const PromotionReservation({
    required this.id,
    required this.tier,
    required this.startsAt,
    required this.createdAt,
    required this.ownerId,
  });

  final String id;
  final PromotionTier tier;
  final DateTime startsAt;
  final DateTime createdAt;
  final String ownerId;

  bool isExpired(DateTime now, int holdHours) =>
      now.isAfter(createdAt.add(Duration(hours: holdHours)));
}

/// Pro Store Glow 1-month credit (does not roll over across billing periods).
@immutable
class PromotionCredit {
  const PromotionCredit({
    required this.id,
    required this.ownerId,
    required this.tier,
    required this.durationDays,
    required this.periodKey,
    this.used = false,
  });

  final String id;
  final String ownerId;
  /// Always Glow for Pro; Founder free credit = Glow 2 weeks.
  final PromotionTier tier;
  final int durationDays;
  final String periodKey;
  final bool used;

  PromotionCredit copyWith({bool? used}) => PromotionCredit(
        id: id,
        ownerId: ownerId,
        tier: tier,
        durationDays: durationDays,
        periodKey: periodKey,
        used: used ?? this.used,
      );
}

/// VITRIN-1 display + VITRIN-2 purchase / upgrade / credits / capacity.
class PromotionService extends ChangeNotifier {
  PromotionService._();
  static final PromotionService instance = PromotionService._();

  PromotionConfig _config = PromotionConfig.defaults;
  final List<Promotion> _items = [];
  final Map<String, PromotionStat> _stats = {};
  final List<PromotionReservation> _reservations = [];
  final List<PromotionCredit> _credits = [];
  bool _seeded = false;

  PromotionConfig get config => _config;
  List<Promotion> get all => List.unmodifiable(_items);
  List<PromotionCredit> get credits => List.unmodifiable(_credits);

  PricingConfig get pricing => PricingConfigService.instance.config;

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
    _releaseExpiredReservations();
    final t = now ?? TGClock.now();
    final hideMocks = TGRevenueConfigService.instance.productionMode;
    return [
      for (final p in _items)
        if (p.isActiveAt(t) && (kind == null || p.targetKind == kind))
          if (!(hideMocks && p.id.startsWith('promo-'))) p,
    ];
  }

  List<Promotion> forOwner(String ownerId, {DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    return [
      for (final p in _items)
        if (p.ownerId == ownerId &&
            (p.status == PromotionStatus.active ||
                p.status == PromotionStatus.scheduled ||
                p.status == PromotionStatus.ended))
          if (p.status != PromotionStatus.active || p.isActiveAt(t) || p.status == PromotionStatus.ended) p,
    ];
  }

  Promotion? activeFor({required PromotionTargetKind kind, required String targetRef, DateTime? now}) {
    final t = now ?? TGClock.now();
    for (final p in active(kind: kind, now: t)) {
      if (p.targetRef == targetRef) return p;
    }
    return null;
  }

  Promotion? byId(String id) {
    ensureSeeded();
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Effective paid promotion for a product (new model or legacy isPromoted → glow).
  Promotion? effectiveListingPromo(TGProduct product, {DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    final live = activeFor(kind: PromotionTargetKind.listing, targetRef: product.id, now: t);
    if (live != null) return live;
    // Also surface scheduled for owner chrome? No — display only active.
    if (!product.isPromoted) return null;
    final end = product.promotedUntil ?? DurationService.addDays(t, _config.defaultDays);
    if (!t.isBefore(end)) return null;
    return Promotion(
      id: 'legacy-${product.id}',
      ownerId: product.ownerId ?? product.seller.id,
      targetKind: PromotionTargetKind.listing,
      targetRef: product.id,
      tier: PromotionTier.glow,
      durationDays: _config.defaultDays,
      startsAt: t.subtract(const Duration(days: 1)),
      endsAt: end,
      status: PromotionStatus.active,
      pricePln: _config.pricePln(PromotionTier.glow, _config.defaultDays),
      source: PromotionSource.paid,
    );
  }

  Promotion? effectiveRestaurantPromo(RestaurantListing listing, {DateTime? now}) {
    ensureSeeded();
    final t = now ?? TGClock.now();
    final live = activeFor(kind: PromotionTargetKind.restaurant, targetRef: listing.id, now: t);
    if (live != null) return live;
    if (!listing.isPromoted) return null;
    final end = listing.promotedUntil ?? DurationService.addDays(t, _config.defaultDays);
    if (!t.isBefore(end)) return null;
    return Promotion(
      id: 'legacy-resto-${listing.id}',
      ownerId: listing.ownerId,
      targetKind: PromotionTargetKind.restaurant,
      targetRef: listing.id,
      tier: PromotionTier.glow,
      durationDays: _config.defaultDays,
      startsAt: t.subtract(const Duration(days: 1)),
      endsAt: end,
      status: PromotionStatus.active,
      pricePln: _config.pricePln(PromotionTier.glow, _config.defaultDays),
      source: PromotionSource.paid,
    );
  }

  int countOccupying(PromotionTier tier, {DateTime? now}) {
    ensureSeeded();
    _releaseExpiredReservations();
    final t = now ?? TGClock.now();
    var n = 0;
    for (final p in _items) {
      if (p.tier != tier) continue;
      if (p.status == PromotionStatus.active && p.isActiveAt(t)) n++;
      if (p.status == PromotionStatus.scheduled && !t.isAfter(p.startsAt)) n++;
    }
    for (final r in _reservations) {
      if (r.tier == tier && !r.isExpired(t, pricing.reservationHoldHours)) n++;
    }
    return n;
  }

  bool isAtCapacity(PromotionTier tier, {DateTime? now}) =>
      countOccupying(tier, now: now) >= _config.maxActive(tier);

  /// Earliest start date when a slot frees (today if capacity available).
  DateTime nextAvailableStart(PromotionTier tier, {DateTime? now}) {
    ensureSeeded();
    _releaseExpiredReservations();
    final t = now ?? TGClock.now();
    if (!isAtCapacity(tier, now: t)) return DateTime(t.year, t.month, t.day);

    final ends = <DateTime>[];
    for (final p in _items) {
      if (p.tier != tier) continue;
      if (p.status == PromotionStatus.active || p.status == PromotionStatus.scheduled) {
        ends.add(p.endsAt);
      }
    }
    if (ends.isEmpty) return DateTime(t.year, t.month, t.day);
    ends.sort();
    // When one ends, a slot frees.
    final free = ends.first;
    return DateTime(free.year, free.month, free.day);
  }

  /// Whether [promoDays] fits within listing remaining life from [listingEndsAt].
  bool promoFitsListing({
    required DateTime listingEndsAt,
    required int promoDays,
    DateTime? startAt,
  }) {
    final start = startAt ?? TGClock.now();
    final promoEnd = DurationService.addDays(start, promoDays);
    return !promoEnd.isAfter(listingEndsAt.add(const Duration(hours: 1)));
  }

  int unusedCredits(String ownerId) {
    ensureSeeded();
    return _credits.where((c) => c.ownerId == ownerId && !c.used).length;
  }

  List<PromotionCredit> unusedCreditList(String ownerId) {
    ensureSeeded();
    return [for (final c in _credits) if (c.ownerId == ownerId && !c.used) c];
  }

  /// Unused credits of one tier (Pro and Founder credits are Glow).
  int unusedCreditsOf(String ownerId, PromotionTier tier) =>
      unusedCreditList(ownerId).where((c) => c.tier == tier).length;

  /// Current-period Pro allowance: credits spent out of [PricingConfig.proCreditsPerPeriod].
  ({int used, int total}) proCreditUsage(String ownerId, {DateTime? now}) {
    ensureSeeded();
    final key = _periodKey(now ?? TGClock.now());
    final used = _credits.where((c) => c.ownerId == ownerId && c.periodKey == key && c.used).length;
    final total = pricing.proCreditsPerPeriod;
    return (used: used.clamp(0, total), total: total);
  }

  /// Spends one unused credit of [tier] (no payment). Null when none is left.
  Promotion? redeemCredit({
    required String ownerId,
    required PromotionTargetKind kind,
    required String targetRef,
    PromotionTier tier = PromotionTier.glow,
    DateTime? listingEndsAt,
  }) {
    final credit = unusedCreditList(ownerId).where((c) => c.tier == tier).firstOrNull;
    if (credit == null) return null;
    return purchase(
      ownerId: ownerId,
      kind: kind,
      targetRef: targetRef,
      tier: tier,
      durationDays: credit.durationDays,
      pricePln: 0,
      source: credit.periodKey == 'founder' ? PromotionSource.founderCredit : PromotionSource.proIncluded,
      listingEndsAt: listingEndsAt,
      creditId: credit.id,
    );
  }

  /// Grant Pro period credits (Glow, 1 month). Does not roll over — replaces unused for period.
  void grantProCredits(String ownerId, {String? periodKey, int? count}) {
    ensureSeeded();
    final key = periodKey ?? _periodKey(TGClock.now());
    final n = count ?? pricing.proCreditsPerPeriod;
    _credits.removeWhere((c) => c.ownerId == ownerId && c.periodKey != key);
    final existing = _credits.where((c) => c.ownerId == ownerId && c.periodKey == key).length;
    for (var i = existing; i < n; i++) {
      _credits.add(PromotionCredit(
        id: 'cred-$ownerId-$key-$i',
        ownerId: ownerId,
        tier: PromotionTier.glow,
        durationDays: _config.durations.last,
        periodKey: key,
      ));
    }
    notifyListeners();
  }

  /// Founder free promotion credit = Glow 2 weeks.
  void grantFounderCredit(String ownerId) {
    ensureSeeded();
    _credits.add(PromotionCredit(
      id: 'cred-founder-$ownerId-${TGClock.now().millisecondsSinceEpoch}',
      ownerId: ownerId,
      tier: PromotionTier.glow,
      durationDays: _config.durations.first,
      periodKey: 'founder',
    ));
    notifyListeners();
  }

  PromotionReservation? reserveSlot({
    required String ownerId,
    required PromotionTier tier,
    DateTime? startsAt,
  }) {
    ensureSeeded();
    _releaseExpiredReservations();
    final start = startsAt ?? nextAvailableStart(tier);
    if (isAtCapacity(tier) && start.isBefore(TGClock.now().add(const Duration(days: 1)))) {
      // Still full for immediate start.
    }
    final r = PromotionReservation(
      id: 'resv-${TGClock.now().millisecondsSinceEpoch}',
      tier: tier,
      startsAt: start,
      createdAt: TGClock.now(),
      ownerId: ownerId,
    );
    _reservations.add(r);
    notifyListeners();
    return r;
  }

  void releaseReservation(String id) {
    _reservations.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// Purchase (or schedule) a promotion. Returns the created record.
  Promotion purchase({
    required String ownerId,
    required PromotionTargetKind kind,
    required String targetRef,
    required PromotionTier tier,
    required int durationDays,
    required int pricePln,
    required PromotionSource source,
    DateTime? listingEndsAt,
    DateTime? startsAt,
    String? paymentId,
    String? creditId,
    String? reservationId,
    bool applyFounderDiscount = false,
  }) {
    ensureSeeded();
    _releaseExpiredReservations();
    final now = TGClock.now();
    var start = startsAt ?? now;
    if (isAtCapacity(tier, now: now) && (startsAt == null || !start.isAfter(now))) {
      start = nextAvailableStart(tier, now: now);
    }
    if (listingEndsAt != null &&
        !promoFitsListing(listingEndsAt: listingEndsAt, promoDays: durationDays, startAt: start)) {
      throw StateError('Promotion would outlast listing; renew first.');
    }

    if (creditId != null) {
      final idx = _credits.indexWhere((c) => c.id == creditId && c.ownerId == ownerId && !c.used);
      if (idx < 0) throw StateError('Credit unavailable');
      // Credit and Founder discount never combine.
      _credits[idx] = _credits[idx].copyWith(used: true);
    }

    if (reservationId != null) {
      _reservations.removeWhere((r) => r.id == reservationId);
    }

    final status = start.isAfter(now.add(const Duration(minutes: 1)))
        ? PromotionStatus.scheduled
        : PromotionStatus.active;
    final promo = Promotion(
      id: 'promo-buy-${now.millisecondsSinceEpoch}-${Random().nextInt(9999)}',
      ownerId: ownerId,
      targetKind: kind,
      targetRef: targetRef,
      tier: tier,
      durationDays: durationDays,
      startsAt: start,
      endsAt: DurationService.addDays(start, durationDays),
      status: status,
      pricePln: pricePln,
      source: source,
      paymentId: paymentId,
    );
    _items.add(promo);
    TGAnalytics.track('promo_purchase', {
      'promotionId': promo.id,
      'tier': tier.name,
      'days': durationDays,
      'pricePln': pricePln,
      'source': source.name,
      'scheduled': status == PromotionStatus.scheduled,
    });
    if (creditId != null) {
      TGAnalytics.track('promo_credit_use', {'creditId': creditId, 'promotionId': promo.id});
    }
    notifyListeners();
    return promo;
  }

  /// Bold→Glow→Spotlight; end date unchanged; cost from [PricingConfig.upgradeCostPln].
  Promotion upgrade({
    required String promotionId,
    required PromotionTier toTier,
    required int paidPln,
    String? paymentId,
  }) {
    ensureSeeded();
    final i = _items.indexWhere((p) => p.id == promotionId);
    if (i < 0) throw StateError('Promotion not found');
    final cur = _items[i];
    if (cur.status != PromotionStatus.active) throw StateError('Only active promotions upgrade');
    if (PricingConfig.tierRank(toTier) <= PricingConfig.tierRank(cur.tier)) {
      throw StateError('No downgrade');
    }
    final now = TGClock.now();
    final total = cur.endsAt.difference(cur.startsAt).inDays.clamp(1, 3650);
    final remaining = cur.endsAt.difference(now).inDays.clamp(0, total);
    final expected = pricing.upgradeCostPln(
      from: cur.tier,
      to: toTier,
      duration: cur.durationDays,
      remainingDays: remaining,
      totalDays: total,
    );
    if (paidPln < expected) throw StateError('Underpaid upgrade');

    final upgraded = Promotion(
      id: cur.id,
      ownerId: cur.ownerId,
      targetKind: cur.targetKind,
      targetRef: cur.targetRef,
      tier: toTier,
      durationDays: cur.durationDays,
      startsAt: cur.startsAt,
      endsAt: cur.endsAt,
      status: cur.status,
      pricePln: cur.pricePln + paidPln,
      source: cur.source,
      paymentId: paymentId ?? cur.paymentId,
      upgradedFrom: cur.id,
    );
    _items[i] = upgraded;
    TGAnalytics.track('promo_upgrade', {
      'promotionId': cur.id,
      'from': cur.tier.name,
      'to': toTier.name,
      'paidPln': paidPln,
    });
    notifyListeners();
    return upgraded;
  }

  /// New period starts at current end (no gap).
  Promotion extend({
    required String promotionId,
    required int durationDays,
    required int pricePln,
    String? paymentId,
  }) {
    ensureSeeded();
    final i = _items.indexWhere((p) => p.id == promotionId);
    if (i < 0) throw StateError('Promotion not found');
    final cur = _items[i];
    if (cur.status != PromotionStatus.active && cur.status != PromotionStatus.scheduled) {
      throw StateError('Cannot extend');
    }
    final newEnd = DurationService.addDays(cur.endsAt, durationDays);
    final extended = Promotion(
      id: cur.id,
      ownerId: cur.ownerId,
      targetKind: cur.targetKind,
      targetRef: cur.targetRef,
      tier: cur.tier,
      durationDays: durationDays,
      startsAt: cur.startsAt,
      endsAt: newEnd,
      status: cur.status,
      pricePln: cur.pricePln + pricePln,
      source: PromotionSource.paid,
      paymentId: paymentId ?? cur.paymentId,
      upgradedFrom: cur.upgradedFrom,
    );
    _items[i] = extended;
    TGAnalytics.track('promo_extend', {
      'promotionId': cur.id,
      'days': durationDays,
      'pricePln': pricePln,
    });
    notifyListeners();
    return extended;
  }

  /// Full refund only if scheduled (not yet started).
  Promotion cancelScheduled(String promotionId, {required bool refund}) {
    ensureSeeded();
    final i = _items.indexWhere((p) => p.id == promotionId);
    if (i < 0) throw StateError('Promotion not found');
    final cur = _items[i];
    final now = TGClock.now();
    if (cur.status != PromotionStatus.scheduled || !now.isBefore(cur.startsAt)) {
      throw StateError('Only not-yet-started promotions cancel with refund');
    }
    final next = Promotion(
      id: cur.id,
      ownerId: cur.ownerId,
      targetKind: cur.targetKind,
      targetRef: cur.targetRef,
      tier: cur.tier,
      durationDays: cur.durationDays,
      startsAt: cur.startsAt,
      endsAt: cur.endsAt,
      status: refund ? PromotionStatus.refunded : PromotionStatus.cancelled,
      pricePln: cur.pricePln,
      source: cur.source,
      paymentId: cur.paymentId,
      upgradedFrom: cur.upgradedFrom,
    );
    _items[i] = next;
    notifyListeners();
    return next;
  }

  /// Owner ends an active promotion now. Unused days are not refunded.
  String? stopEarly(String promotionId, {required String ownerId}) {
    ensureSeeded();
    final i = _items.indexWhere((p) => p.id == promotionId);
    if (i < 0) return 'ads_err_not_found';
    final cur = _items[i];
    if (cur.ownerId != ownerId) return 'ads_err_not_owner';
    final now = TGClock.now();
    if (cur.status != PromotionStatus.active || !cur.isActiveAt(now)) return 'ads_err_not_live';
    _items[i] = Promotion(
      id: cur.id,
      ownerId: cur.ownerId,
      targetKind: cur.targetKind,
      targetRef: cur.targetRef,
      tier: cur.tier,
      durationDays: cur.durationDays,
      startsAt: cur.startsAt,
      endsAt: now,
      status: PromotionStatus.ended,
      pricePln: cur.pricePln,
      source: cur.source,
      paymentId: cur.paymentId,
      upgradedFrom: cur.upgradedFrom,
    );
    TGAnalytics.track('promo_stop_early', {'promotionId': promotionId});
    notifyListeners();
    return null;
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

  /// Lifetime totals across days (dashboard).
  ({int impressions, int clicks}) totalsFor(String promotionId) {
    var impressions = 0;
    var clicks = 0;
    for (final s in _stats.values) {
      if (s.promotionId != promotionId) continue;
      impressions += s.impressions;
      clicks += s.clicks;
    }
    return (impressions: impressions, clicks: clicks);
  }

  /// Dev Switcher personas: adds a mock row (id must start with `promo-` so
  /// Production Mode hides it).
  void addMock(Promotion p) {
    ensureSeeded();
    assert(p.id.startsWith('promo-'));
    if (_items.any((e) => e.id == p.id)) return;
    _items.add(p);
    notifyListeners();
  }

  void resetForTests() {
    _items.clear();
    _stats.clear();
    _reservations.clear();
    _credits.clear();
    _seeded = false;
    _config = PromotionConfig.defaults;
  }

  void _releaseExpiredReservations() {
    final now = TGClock.now();
    final hold = pricing.reservationHoldHours;
    _reservations.removeWhere((r) => r.isExpired(now, hold));
  }

  String _periodKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}';

  void _seedMocks() {
    final now = TGClock.now();
    final short = _config.durations.first;
    final long = _config.durations.last;

    Promotion mk({
      required String id,
      required String ownerId,
      required PromotionTargetKind kind,
      required String ref,
      required PromotionTier tier,
      required int dur,
      required PromotionStatus status,
      int startOffsetDays = -1,
      PromotionSource source = PromotionSource.paid,
    }) {
      final start = DurationService.addDays(now, startOffsetDays);
      return Promotion(
        id: id,
        ownerId: ownerId,
        targetKind: kind,
        targetRef: ref,
        tier: tier,
        durationDays: dur,
        startsAt: start,
        endsAt: DurationService.addDays(start, dur),
        status: status,
        pricePln: source == PromotionSource.paid ? _config.pricePln(tier, dur) : 0,
        source: source,
        paymentId: source == PromotionSource.paid ? 'pay-$id' : null,
      );
    }

    // Catalogue seed (VITRIN-1 display) + compact VITRIN-2 owner set.
    _items.addAll([
      mk(id: 'promo-sp-1', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p001', tier: PromotionTier.spotlight, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-sp-2', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p002', tier: PromotionTier.spotlight, dur: long, status: PromotionStatus.active),
      mk(id: 'promo-sp-3', ownerId: 'seller_mateusz', kind: PromotionTargetKind.restaurant, ref: 'r001', tier: PromotionTier.spotlight, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-sp-4', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p003', tier: PromotionTier.spotlight, dur: short, status: PromotionStatus.active, source: PromotionSource.enterpriseIncluded),
      mk(id: 'promo-gl-1', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p004', tier: PromotionTier.glow, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-gl-2', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p005', tier: PromotionTier.glow, dur: long, status: PromotionStatus.active),
      mk(id: 'promo-gl-3', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p006', tier: PromotionTier.glow, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-gl-4', ownerId: 'seller_anna', kind: PromotionTargetKind.restaurant, ref: 'r002', tier: PromotionTier.glow, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-gl-5', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p008', tier: PromotionTier.glow, dur: long, status: PromotionStatus.active, source: PromotionSource.proIncluded),
      mk(id: 'promo-gl-6', ownerId: 'seller_mateusz', kind: PromotionTargetKind.listing, ref: 'p009', tier: PromotionTier.glow, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-1', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p010', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-2', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p011', tier: PromotionTier.bold, dur: long, status: PromotionStatus.active),
      mk(id: 'promo-bo-3', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p013', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-4', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p014', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-5', ownerId: 'seller_mateusz', kind: PromotionTargetKind.listing, ref: 'p015', tier: PromotionTier.bold, dur: long, status: PromotionStatus.active),
      mk(id: 'promo-bo-6', ownerId: 'seller_karol', kind: PromotionTargetKind.restaurant, ref: 'r003', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-7', ownerId: 'seller_primegastro', kind: PromotionTargetKind.listing, ref: 'p016', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-bo-8', ownerId: 'seller_gastropl', kind: PromotionTargetKind.listing, ref: 'p017', tier: PromotionTier.bold, dur: long, status: PromotionStatus.active),
      mk(id: 'promo-sched-1', ownerId: 'seller_anna', kind: PromotionTargetKind.listing, ref: 'p018', tier: PromotionTier.glow, dur: short, status: PromotionStatus.scheduled, startOffsetDays: 3),
      mk(id: 'promo-ended-1', ownerId: 'seller_technica', kind: PromotionTargetKind.listing, ref: 'p019', tier: PromotionTier.spotlight, dur: short, status: PromotionStatus.ended, startOffsetDays: -20),
      // VITRIN-2 dashboard demo: 3 active + 1 scheduled + 1 ended on mock store seller.
      mk(id: 'promo-dash-1', ownerId: FakeAuthIds.storeSeller, kind: PromotionTargetKind.listing, ref: 'p001', tier: PromotionTier.glow, dur: long, status: PromotionStatus.active, source: PromotionSource.proIncluded),
      // Ends in 2 days → Action Center "Promotion ends in 2 days" suggestion.
      mk(id: 'promo-dash-2', ownerId: FakeAuthIds.storeSeller, kind: PromotionTargetKind.listing, ref: 'p002', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active, startOffsetDays: 2 - short),
      mk(id: 'promo-dash-3', ownerId: FakeAuthIds.storeSeller, kind: PromotionTargetKind.listing, ref: 'p003', tier: PromotionTier.spotlight, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-dash-sched', ownerId: FakeAuthIds.storeSeller, kind: PromotionTargetKind.listing, ref: 'p004', tier: PromotionTier.glow, dur: short, status: PromotionStatus.scheduled, startOffsetDays: 5),
      mk(id: 'promo-dash-ended', ownerId: FakeAuthIds.storeSeller, kind: PromotionTargetKind.listing, ref: 'p005', tier: PromotionTier.bold, dur: short, status: PromotionStatus.ended, startOffsetDays: -(short + 2)),
      // Font-preview pack: Bold vs Spotlight vs Normal (p020/p021/p024 stay organic).
      mk(id: 'promo-font-bold', ownerId: 'seller_font_customkit', kind: PromotionTargetKind.listing, ref: 'p022', tier: PromotionTier.bold, dur: short, status: PromotionStatus.active),
      mk(id: 'promo-font-spot', ownerId: 'seller_font_rentline', kind: PromotionTargetKind.listing, ref: 'p023', tier: PromotionTier.spotlight, dur: long, status: PromotionStatus.active),
    ]);

    // Pro period allowance; promo-dash-1 already spent one credit.
    grantProCredits(FakeAuthIds.storeSeller);
    final spent = _credits.indexWhere((c) => c.ownerId == FakeAuthIds.storeSeller && !c.used);
    if (spent >= 0) _credits[spent] = _credits[spent].copyWith(used: true);
    // Recorded counters for the demo rows (same shape recordImpression/recordClick write).
    const demoStats = {'promo-dash-1': (412, 31), 'promo-dash-2': (138, 9), 'promo-dash-3': (655, 47)};
    demoStats.forEach((id, v) {
      _stats[_statKey(id)] = PromotionStat(promotionId: id, date: _day(now), impressions: v.$1, clicks: v.$2);
    });
  }

  String _statKey(String promotionId) {
    final d = _day(TGClock.now());
    return '$promotionId-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// Stable mock owner ids used by seeds (avoid importing FakeAuthState cycle).
abstract final class FakeAuthIds {
  static const storeSeller = 'seller_gastropl';
}
