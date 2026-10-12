import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart' show TGStorePlanKind;
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// One day on the banner calendar.
@immutable
class TGAdDay {
  const TGAdDay({required this.day, required this.taken, required this.capacity});
  final DateTime day;
  final int taken;
  final int capacity;
  bool get isFull => taken >= capacity;
  int get free => (capacity - taken).clamp(0, capacity);
}

/// Hero banner AdSlots (VITRIN-3): day-seat capacity, 24 h holds, waitlist,
/// admin review with one correction round, refunds. Prices from [PricingConfig.banner].
class AdSlotService extends ChangeNotifier {
  AdSlotService._();
  static final AdSlotService instance = AdSlotService._();

  final List<TGAdSlot> slots = [];
  final List<TGAdHold> _holds = [];
  final List<TGAdWaitlistEntry> waitlist = [];
  final Map<String, _AdUndo> _undos = {};
  final Map<String, int> _enterpriseUsedThisMonth = {};
  bool _seeded = false;
  int _seq = 1;

  BannerPricing get pricing => PricingConfigService.instance.config.banner;

  bool get purchaseVisible {
    final cfg = TGRevenueConfigService.instance.config;
    return cfg.flags.bannerAds && cfg.phase >= 2;
  }

  int priceFor(BannerDurationKey key) => pricing.pricePln(key);
  int get maxPerDay => pricing.maxSponsoredPerDay;

  void reset() {
    slots.clear();
    _holds.clear();
    waitlist.clear();
    _undos.clear();
    _enterpriseUsedThisMonth.clear();
    _seeded = false;
    _seq = 1;
    notifyListeners();
  }

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    final today = dayOf(TGClock.now());
    slots.addAll([
      TGAdSlot(
        id: 'ad_live_1',
        ownerId: 'seller_tg',
        kind: TGAdSlotKind.restaurantListing,
        targetUrl: '/restaurants/51010001-restaurant-with-terrace-mariacka-katowice',
        title: 'Restaurant with terrace – Katowice',
        imageUrl: TGListingImages.heroSlide(0),
        startsAt: today.subtract(const Duration(days: 2)),
        endsAt: today.add(const Duration(days: 12)),
        status: TGAdSlotStatus.live,
        duration: BannerDurationKey.w2,
        impressions: 1840,
        clicks: 62,
        pricePln: priceFor(BannerDurationKey.w2),
        isMock: true,
      ),
      TGAdSlot(
        id: 'ad_pending_1',
        ownerId: 'seller_gastropl',
        kind: TGAdSlotKind.store,
        targetUrl: '/seller/1847-gastrosilesia',
        title: 'GastroPL Outlet – kitchen equipment',
        imageUrl: TGListingImages.heroSlide(1),
        startsAt: today.add(const Duration(days: 1)),
        endsAt: today.add(const Duration(days: 15)),
        status: TGAdSlotStatus.pendingReview,
        duration: BannerDurationKey.w2,
        pricePln: priceFor(BannerDurationKey.w2),
        isMock: true,
      ),
      TGAdSlot(
        id: 'ad_sched_1',
        ownerId: 'seller_tg',
        kind: TGAdSlotKind.listing,
        targetUrl: '/products',
        title: 'Combi ovens – spring offer',
        imageUrl: TGListingImages.heroSlide(3),
        startsAt: today.add(const Duration(days: 4)),
        endsAt: today.add(const Duration(days: 11)),
        status: TGAdSlotStatus.approved,
        duration: BannerDurationKey.w1,
        pricePln: priceFor(BannerDurationKey.w1),
        isMock: true,
      ),
    ]);
  }

  bool _visible(TGAdSlot s) {
    if (TGRevenueConfigService.instance.productionMode && s.isMock) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Capacity / calendar
  // ---------------------------------------------------------------------------

  void _dropExpiredHolds() {
    final now = TGClock.now();
    _holds.removeWhere((h) => !h.expiresAt.isAfter(now));
  }

  TGAdHold? holdFor(String ownerId) {
    _dropExpiredHolds();
    for (final h in _holds) {
      if (h.ownerId == ownerId) return h;
    }
    return null;
  }

  static bool _covers(DateTime start, DateTime end, DateTime day) => !day.isBefore(dayOf(start)) && day.isBefore(dayOf(end));

  /// Seats used on [day] (slots + live holds). [ignoreHoldOf] skips that owner's hold.
  int seatsTaken(DateTime day, {String? ignoreHoldOf}) {
    ensureSeeded();
    _dropExpiredHolds();
    final d = dayOf(day);
    var n = 0;
    for (final s in slots) {
      if (s.occupiesSeat && _visible(s) && _covers(s.startsAt, s.endsAt, d)) n++;
    }
    for (final h in _holds) {
      if (h.ownerId != ignoreHoldOf && _covers(h.startsAt, h.endsAt, d)) n++;
    }
    return n;
  }

  bool isDayFull(DateTime day, {String? ignoreHoldOf}) => seatsTaken(day, ignoreHoldOf: ignoreHoldOf) >= maxPerDay;

  bool windowFree(DateTime start, BannerDurationKey duration, {String? ignoreHoldOf}) {
    final s = dayOf(start);
    for (var i = 0; i < duration.days; i++) {
      if (isDayFull(s.add(Duration(days: i)), ignoreHoldOf: ignoreHoldOf)) return false;
    }
    return true;
  }

  /// Bookable start days are today … today + horizon − 1.
  DateTime get firstBookableDay => dayOf(TGClock.now());
  DateTime get lastBookableDay => firstBookableDay.add(Duration(days: pricing.waitlistHorizonDays - 1));

  List<TGAdDay> calendar({DateTime? from, int? days, String? ignoreHoldOf}) {
    final start = dayOf(from ?? firstBookableDay);
    final n = days ?? pricing.waitlistHorizonDays;
    return [
      for (var i = 0; i < n; i++)
        TGAdDay(
          day: start.add(Duration(days: i)),
          taken: seatsTaken(start.add(Duration(days: i)), ignoreHoldOf: ignoreHoldOf),
          capacity: maxPerDay,
        ),
    ];
  }

  /// Earliest start ≥ [from] whose full window fits within the horizon; null → waitlist.
  DateTime? nextAvailableStart(BannerDurationKey duration, {DateTime? from, String? ignoreHoldOf}) {
    var d = dayOf(from ?? firstBookableDay);
    if (d.isBefore(firstBookableDay)) d = firstBookableDay;
    while (!d.isAfter(lastBookableDay)) {
      if (windowFree(d, duration, ignoreHoldOf: ignoreHoldOf)) return d;
      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  bool horizonFull(BannerDurationKey duration, {String? ignoreHoldOf}) =>
      nextAvailableStart(duration, ignoreHoldOf: ignoreHoldOf) == null;

  /// Locks the window for [BannerPricing.holdHours]. Replaces the owner's previous hold.
  TGAdHold reserve({required String ownerId, required DateTime startsAt, required BannerDurationKey duration}) {
    if (!purchaseVisible) throw StateError('ui_banner_err_unavailable');
    final start = dayOf(startsAt);
    if (start.isBefore(firstBookableDay)) throw StateError('ui_banner_err_past');
    if (!windowFree(start, duration, ignoreHoldOf: ownerId)) throw StateError('ui_banner_err_full');
    _holds.removeWhere((h) => h.ownerId == ownerId);
    final hold = TGAdHold(
      id: 'hold_${_seq++}',
      ownerId: ownerId,
      startsAt: start,
      duration: duration,
      expiresAt: TGClock.now().add(Duration(hours: pricing.holdHours)),
    );
    _holds.add(hold);
    TGAnalytics.track('banner_hold', {'start': start.toIso8601String(), 'days': duration.days});
    notifyListeners();
    return hold;
  }

  void releaseHold(String ownerId) {
    final before = _holds.length;
    _holds.removeWhere((h) => h.ownerId == ownerId);
    if (_holds.length != before) notifyListeners();
  }

  bool isOnWaitlist(String ownerId) => waitlist.any((w) => w.ownerId == ownerId);

  void joinWaitlist(String ownerId, BannerDurationKey duration) {
    if (isOnWaitlist(ownerId)) return;
    waitlist.add(TGAdWaitlistEntry(ownerId: ownerId, duration: duration, createdAt: TGClock.now()));
    TGAnalytics.track('banner_waitlist_join', {'days': duration.days});
    notifyListeners();
  }

  void _notifyWaitlist() {
    if (waitlist.isEmpty) return;
    final remaining = <TGAdWaitlistEntry>[];
    for (final w in waitlist) {
      final start = nextAvailableStart(w.duration);
      if (start == null) {
        remaining.add(w);
        continue;
      }
      NotificationService.instance.add(
        userId: w.ownerId,
        type: 'ad_waitlist_open',
        dealId: 'waitlist',
        title: 'Banner dates available',
        body: 'A hero banner window is free again.',
        deepLink: '/dashboard/advertising',
      );
    }
    waitlist
      ..clear()
      ..addAll(remaining);
  }

  /// Greedy lane assignment for the admin "3 seats × day" grid.
  /// Returns, per day, [maxPerDay] entries (null = free seat).
  List<({DateTime day, List<TGAdSlot?> seats})> seatGrid({DateTime? from, int days = 21}) {
    ensureSeeded();
    final start = dayOf(from ?? TGClock.now());
    final occupying = slots.where((s) => s.occupiesSeat && _visible(s)).toList()
      ..sort((a, b) {
        final c = a.startsAt.compareTo(b.startsAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final laneEnds = <DateTime>[];
    final laneOf = <String, int>{};
    for (final s in occupying) {
      var lane = laneEnds.indexWhere((e) => !e.isAfter(dayOf(s.startsAt)));
      if (lane < 0) {
        laneEnds.add(dayOf(s.endsAt));
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = dayOf(s.endsAt);
      }
      laneOf[s.id] = lane;
    }
    return [
      for (var i = 0; i < days; i++)
        () {
          final d = start.add(Duration(days: i));
          final seats = List<TGAdSlot?>.filled(maxPerDay, null);
          for (final s in occupying) {
            final lane = laneOf[s.id]!;
            if (lane < maxPerDay && _covers(s.startsAt, s.endsAt, d)) seats[lane] = s;
          }
          return (day: d, seats: seats);
        }(),
    ];
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  List<TGAdSlot> get pendingReview =>
      slots.where((s) => s.status == TGAdSlotStatus.pendingReview && _visible(s)).toList();

  List<TGAdSlot> get liveSlides {
    ensureSeeded();
    final now = TGClock.now();
    final live = slots
        .where((s) => _visible(s) && s.status == TGAdSlotStatus.live && !now.isBefore(s.startsAt) && now.isBefore(s.endsAt))
        .toList();
    live.sort((a, b) => a.id.compareTo(b.id));
    live.shuffle(Random(now.day * 31 + now.month));
    return live.take(maxPerDay).toList(growable: false);
  }

  List<TGAdSlot> ownedBy(String ownerId) {
    ensureSeeded();
    return slots.where((s) => s.ownerId == ownerId && _visible(s)).toList();
  }

  bool _isEnterprise(String ownerId) => TGSellerProfileService.instance.bySellerKey(ownerId)?.plan == TGStorePlanKind.enterprise;

  bool canUseEnterpriseEntitlement(String ownerId) => enterpriseRemaining(ownerId) > 0;

  int enterpriseRemaining(String ownerId) {
    if (!_isEnterprise(ownerId)) return 0;
    final cap = pricing.enterpriseFreePerMonth;
    final used = _enterpriseUsedThisMonth[_monthKey(ownerId)] ?? 0;
    return (cap - used).clamp(0, cap);
  }

  String _monthKey(String ownerId) {
    final n = TGClock.now();
    return '$ownerId-${n.year}-${n.month}';
  }

  void _restoreEntitlement(TGAdSlot s) {
    if (!s.enterpriseEntitlement) return;
    final key = _monthKey(s.ownerId);
    _enterpriseUsedThisMonth[key] = ((_enterpriseUsedThisMonth[key] ?? 1) - 1).clamp(0, 99);
  }

  /// Platform-internal paths only.
  static String? validateTargetUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Target URL is required';
    if (t.startsWith('http://') || t.startsWith('https://')) {
      if (!t.contains('twojagastromania.pl')) return 'Platform-internal links only';
    }
    if (!t.startsWith('/')) return 'Use an internal path starting with /';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Purchase → review
  // ---------------------------------------------------------------------------

  /// Called after successful payment (or Enterprise free week). Consumes the hold.
  TGAdSlot purchaseAndSubmit({
    required String ownerId,
    required TGAdSlotKind kind,
    required String targetUrl,
    required String title,
    required String imageUrl,
    required DateTime startsAt,
    BannerDurationKey duration = BannerDurationKey.w2,
    bool useEnterpriseEntitlement = false,
  }) {
    if (!purchaseVisible) throw StateError('ui_banner_err_unavailable');
    final err = validateTargetUrl(targetUrl);
    if (err != null) throw StateError(err);
    final t = title.trim();
    if (t.isEmpty || t.length > pricing.titleMaxChars) throw StateError('ui_banner_err_title');
    final start = dayOf(startsAt);
    if (!windowFree(start, duration, ignoreHoldOf: ownerId)) throw StateError('ui_banner_err_full');
    final entitlement =
        useEnterpriseEntitlement && duration == pricing.enterpriseFreeDuration && canUseEnterpriseEntitlement(ownerId);
    if (useEnterpriseEntitlement && !entitlement) throw StateError('ui_banner_err_entitlement');
    final price = entitlement ? 0 : priceFor(duration);
    if (entitlement) {
      final key = _monthKey(ownerId);
      _enterpriseUsedThisMonth[key] = (_enterpriseUsedThisMonth[key] ?? 0) + 1;
    }
    _holds.removeWhere((h) => h.ownerId == ownerId);
    final slot = TGAdSlot(
      id: 'ad_${_seq++}_${TGClock.now().millisecondsSinceEpoch}',
      ownerId: ownerId,
      kind: kind,
      targetUrl: targetUrl.trim(),
      title: t,
      imageUrl: imageUrl,
      startsAt: start,
      endsAt: start.add(Duration(days: duration.days)),
      status: TGAdSlotStatus.pendingReview,
      duration: duration,
      pricePln: price,
      enterpriseEntitlement: entitlement,
    );
    slots.insert(0, slot);
    TGAnalytics.track('ad_purchase', {
      'id': slot.id,
      'price': price,
      'days': duration.days,
      'entitlement': entitlement,
      'kind': kind.name,
    });
    notifyListeners();
    return slot;
  }

  bool canRequestChanges(TGAdSlot s) => s.status == TGAdSlotStatus.pendingReview && s.correctionsUsed < pricing.maxCorrections;

  String? approve(String id, {required String actorId, required String actorRole}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.status != TGAdSlotStatus.pendingReview) return 'Not pending';
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    final now = TGClock.now();
    final nextStatus = now.isBefore(prev.startsAt) ? TGAdSlotStatus.approved : TGAdSlotStatus.live;
    slots[i] = prev.copyWith(status: nextStatus, clearReject: true, clearChangesNote: true);
    _audit(actorId, actorRole, id, 'Approved ad ${prev.title}');
    TGAnalytics.track('ad_content_decision', {'id': id, 'decision': 'approve', 'status': nextStatus.name});
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_approved',
      dealId: id,
      title: 'Banner ad approved',
      body: nextStatus == TGAdSlotStatus.live
          ? 'Your banner is live on the homepage.'
          : 'Approved. It goes live on the booked start date.',
      deepLink: '/dashboard/advertising',
    );
    notifyListeners();
    return null;
  }

  /// One correction round: seat stays held, owner edits title/image and resubmits.
  String? requestChanges(String id, {required String actorId, required String actorRole, required String reason}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (!canRequestChanges(prev)) return 'ui_banner_err_no_corrections';
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    slots[i] = prev.copyWith(status: TGAdSlotStatus.changesRequested, changesNote: reason);
    _audit(actorId, actorRole, id, 'Changes requested for ad ${prev.title}', reason: reason);
    TGAnalytics.track('ad_content_decision', {'id': id, 'decision': 'changes'});
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_changes_requested',
      dealId: id,
      title: 'Banner ad needs a correction',
      body: reason,
      deepLink: '/dashboard/advertising',
    );
    notifyListeners();
    return null;
  }

  String? resubmit(String id, {required String ownerId, required String title, required String imageUrl}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.ownerId != ownerId || prev.status != TGAdSlotStatus.changesRequested) return 'ui_banner_err_not_editable';
    final t = title.trim();
    if (t.isEmpty || t.length > pricing.titleMaxChars) return 'ui_banner_err_title';
    slots[i] = prev.copyWith(
      status: TGAdSlotStatus.pendingReview,
      title: t,
      imageUrl: imageUrl,
      correctionsUsed: prev.correctionsUsed + 1,
    );
    TGAnalytics.track('ad_resubmit', {'id': id});
    notifyListeners();
    return null;
  }

  /// Rejection always refunds in full (or restores the Enterprise week) and frees the seat.
  String? reject(String id, {required String actorId, required String actorRole, required String reason}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    slots[i] = prev.copyWith(status: TGAdSlotStatus.rejected, rejectReason: reason, refundPln: prev.pricePln);
    _audit(actorId, actorRole, id, 'Rejected ad · refund ${prev.pricePln} PLN', reason: reason);
    TGAnalytics.track('ad_content_decision', {'id': id, 'decision': 'reject', 'refund': prev.pricePln});
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_rejected',
      dealId: id,
      title: 'Banner ad not published',
      body: prev.pricePln > 0
          ? 'Your content was not approved. A full refund of ${prev.pricePln} PLN was issued.'
          : 'Your content was not approved. Your Enterprise entitlement was restored.',
      deepLink: '/dashboard/advertising',
    );
    _restoreEntitlement(prev);
    _notifyWaitlist();
    notifyListeners();
    return null;
  }

  /// Full refund when cancelled ≥ [BannerPricing.fullRefundDaysBeforeStart] days before start.
  bool canCancel(TGAdSlot s) {
    if (!s.occupiesSeat || s.status == TGAdSlotStatus.live) return false;
    final lead = dayOf(s.startsAt).difference(dayOf(TGClock.now())).inDays;
    return lead >= pricing.fullRefundDaysBeforeStart;
  }

  String? cancelByOwner(String id, {required String ownerId}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.ownerId != ownerId) return 'ui_banner_err_not_editable';
    if (!canCancel(prev)) return 'ui_banner_err_cancel_late';
    slots[i] = prev.copyWith(status: TGAdSlotStatus.cancelled, refundPln: prev.pricePln);
    _restoreEntitlement(prev);
    TGAnalytics.track('ad_cancel', {'id': id, 'refund': prev.pricePln});
    _notifyWaitlist();
    notifyListeners();
    return null;
  }

  bool undo(String id) {
    final u = _undos.remove(id);
    if (u == null || !u.until.isAfter(DateTime.now())) return false;
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) {
      slots.insert(0, u.snapshot);
    } else {
      slots[i] = u.snapshot;
    }
    notifyListeners();
    return true;
  }

  String? terminateEarly(String id, {required String actorId, required String actorRole, required String reason}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.status != TGAdSlotStatus.live && prev.status != TGAdSlotStatus.approved) return 'Not live';
    final now = TGClock.now();
    final total = prev.endsAt.difference(prev.startsAt).inDays.clamp(1, 365);
    final left = prev.endsAt.difference(now.isBefore(prev.startsAt) ? prev.startsAt : now).inDays.clamp(0, total);
    final refund = prev.pricePln <= 0 ? 0 : ((prev.pricePln * left) / total).round();
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    slots[i] = prev.copyWith(status: TGAdSlotStatus.ended, endsAt: now, endedEarlyReason: reason, refundPln: refund);
    _audit(actorId, actorRole, id, 'Early termination · prorated refund $refund PLN', reason: reason);
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_ended_early',
      dealId: id,
      title: 'Banner ad ended',
      body: refund > 0 ? 'Prorated refund: $refund PLN.' : 'Your banner was ended by moderation.',
      deepLink: '/dashboard/advertising',
    );
    _notifyWaitlist();
    notifyListeners();
    return null;
  }

  void recordImpression(String id) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    slots[i] = slots[i].copyWith(impressions: slots[i].impressions + 1);
  }

  void recordClick(String id) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    slots[i] = slots[i].copyWith(clicks: slots[i].clicks + 1);
    notifyListeners();
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    var changed = false;
    _dropExpiredHolds();
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if ((s.status == TGAdSlotStatus.live || s.status == TGAdSlotStatus.approved) && !s.endsAt.isAfter(now)) {
        slots[i] = s.copyWith(status: TGAdSlotStatus.ended);
        changed = true;
        NotificationService.instance.add(
          userId: s.ownerId,
          type: 'ad_impression_report',
          dealId: s.id,
          title: 'Banner ad ended · report',
          body: '${s.impressions} impressions · ${s.clicks} clicks. Reach depends on homepage traffic.',
          deepLink: '/dashboard/advertising',
        );
        TGAnalytics.track('ad_impression_report', {'id': s.id, 'impressions': s.impressions, 'clicks': s.clicks});
      } else if (s.status == TGAdSlotStatus.approved && !now.isBefore(s.startsAt)) {
        slots[i] = s.copyWith(status: TGAdSlotStatus.live);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Days where seat demand exceeds capacity (should stay empty; admin sanity check).
  List<TGAdDay> overbookedDays({int days = 60}) =>
      calendar(from: firstBookableDay, days: days).where((d) => d.taken > d.capacity).toList();

  void _audit(String actorId, String actorRole, String id, String summary, {String? reason}) {
    ModerationService.instance.recordRestoDescriptionAudit(
      listingNo: id,
      actorId: actorId,
      actorRole: actorRole,
      summary: summary,
      reason: reason,
    );
  }
}

class _AdUndo {
  _AdUndo({required this.snapshot, required this.until});
  final TGAdSlot snapshot;
  final DateTime until;
}
