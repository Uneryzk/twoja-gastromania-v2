import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// 24 h lock on a segment window between date pick and payment.
@immutable
class TGSponsorHold {
  const TGSponsorHold({
    required this.sellerId,
    required this.specialty,
    required this.region,
    required this.startsAt,
    required this.durationDays,
    required this.expiresAt,
  });
  final String sellerId;
  final TGStoreSpecialty specialty;
  final String region;
  final DateTime startsAt;
  final int durationDays;
  final DateTime expiresAt;
  DateTime get endsAt => TGSponsorSlotService.addDays(startsAt, durationDays);
}

/// Project type × region sponsorship (VITRIN-4): one sponsor per segment per day,
/// prices from [PricingConfig.sponsorSlot], payment → admin approval → live.
class TGSponsorSlotService extends ChangeNotifier {
  TGSponsorSlotService._();
  static final TGSponsorSlotService instance = TGSponsorSlotService._();

  final List<TGSponsorSlot> slots = [];
  final List<TGSponsorHold> _holds = [];
  final Set<String> _endingReminded = {};
  final Map<String, ({int impressions, int clicks})> _counters = {};
  final Set<String> _counted = {};
  bool _seeded = false;
  int _seq = 1;

  SponsorSlotPricing get pricing => PricingConfigService.instance.config.sponsorSlot;
  int priceFor(int key) => pricing.pricePln(key);

  void reset() {
    slots.clear();
    _holds.clear();
    _endingReminded.clear();
    _counters.clear();
    _counted.clear();
    _seeded = false;
    _seq = 1;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedAll();
  }

  bool get enabled => TGRevenueConfigService.instance.flags.sponsorSlots;

  /// Warsaw calendar day containing [t].
  static DateTime dayOf(DateTime t) => DurationService.dayStart(t);

  /// Same Warsaw wall-clock time [n] calendar days later (DST-safe).
  static DateTime addDays(DateTime day, int n) => DurationService.addDays(day, n);

  List<({TGStoreSpecialty specialty, String region})> get segments {
    const specs = [
      TGStoreSpecialty.extractionHoods,
      TGStoreSpecialty.worktopsTables,
      TGStoreSpecialty.barCounters,
      TGStoreSpecialty.coldRooms,
    ];
    const regions = ['Śląskie', 'Mazowieckie'];
    return [for (final s in specs) for (final r in regions) (specialty: s, region: r)];
  }

  bool _occupies(TGSponsorSlot s) =>
      s.startsAt != null &&
      s.endsAt != null &&
      (s.status == TGSponsorSlotStatus.contentPending ||
          s.status == TGSponsorSlotStatus.reserved ||
          s.status == TGSponsorSlotStatus.active);

  TGSponsorSlot? activeFor(TGStoreSpecialty specialty, String region) {
    ensureSeeded();
    final now = TGClock.now();
    return slots
        .where((s) =>
            s.specialty == specialty &&
            s.region == region &&
            s.status == TGSponsorSlotStatus.active &&
            s.endsAt != null &&
            now.isBefore(s.endsAt!))
        .firstOrNull;
  }

  /// Most relevant record for the segment tile: live, then pending / scheduled, then latest.
  TGSponsorSlot? slotAt(TGStoreSpecialty specialty, String region) {
    ensureSeeded();
    final mine = slots.where((s) => s.specialty == specialty && s.region == region).toList();
    return mine.where((s) => s.status == TGSponsorSlotStatus.active).firstOrNull ??
        mine.where(_occupies).firstOrNull ??
        mine.firstOrNull;
  }

  String? eligibilityError(String sellerId) {
    final p = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (p == null) return 'Manufacturer profile required';
    if (p.plan != TGStorePlanKind.pro && p.plan != TGStorePlanKind.enterprise) {
      return 'Active Pro or Enterprise plan required';
    }
    return null;
  }

  int priceForSeller(String sellerId, int key) =>
      TGFounderService.instance.discountedPrice(sellerId, priceFor(key));

  // ---------------------------------------------------------------------------
  // Calendar (VITRIN-3 rules: 24 h hold, earliest free window)
  // ---------------------------------------------------------------------------

  void _dropExpiredHolds() {
    final now = TGClock.now();
    _holds.removeWhere((h) => !h.expiresAt.isAfter(now));
  }

  TGSponsorHold? holdFor(String sellerId) {
    _dropExpiredHolds();
    return _holds.where((h) => h.sellerId == sellerId).firstOrNull;
  }

  bool isDayTaken(TGStoreSpecialty specialty, String region, DateTime day, {String? ignoreHoldOf}) {
    ensureSeeded();
    _dropExpiredHolds();
    final d = dayOf(day);
    bool covers(DateTime s, DateTime e) => !d.isBefore(dayOf(s)) && d.isBefore(dayOf(e));
    for (final s in slots) {
      if (s.specialty == specialty && s.region == region && _occupies(s) && covers(s.startsAt!, s.endsAt!)) return true;
    }
    for (final h in _holds) {
      if (h.specialty == specialty && h.region == region && h.sellerId != ignoreHoldOf && covers(h.startsAt, h.endsAt)) {
        return true;
      }
    }
    return false;
  }

  bool windowFree(TGStoreSpecialty specialty, String region, DateTime start, int duration,
      {String? ignoreHoldOf}) {
    final s = dayOf(start);
    for (var i = 0; i < duration; i++) {
      if (isDayTaken(specialty, region, addDays(s, i), ignoreHoldOf: ignoreHoldOf)) return false;
    }
    return true;
  }

  DateTime? nextAvailableStart(TGStoreSpecialty specialty, String region, int duration,
      {DateTime? from, String? ignoreHoldOf}) {
    final first = dayOf(TGClock.now());
    final last = addDays(first, pricing.horizonDays - 1);
    var d = dayOf(from ?? first);
    if (d.isBefore(first)) d = first;
    while (!d.isAfter(last)) {
      if (windowFree(specialty, region, d, duration, ignoreHoldOf: ignoreHoldOf)) return d;
      d = addDays(d, 1);
    }
    return null;
  }

  TGSponsorHold hold({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
    required DateTime startsAt,
    required int durationDays,
  }) {
    final duration = durationDays;
    final err = eligibilityError(sellerId);
    if (err != null) throw StateError(err);
    final start = dayOf(startsAt);
    if (start.isBefore(dayOf(TGClock.now()))) throw StateError('ui_banner_err_past');
    if (!windowFree(specialty, region, start, duration, ignoreHoldOf: sellerId)) throw StateError('ui_banner_err_full');
    _holds.removeWhere((h) => h.sellerId == sellerId);
    final h = TGSponsorHold(
      sellerId: sellerId,
      specialty: specialty,
      region: region,
      startsAt: start,
      durationDays: duration,
      expiresAt: TGClock.now().add(Duration(hours: pricing.holdHours)),
    );
    _holds.add(h);
    TGAnalytics.track('slot_hold', {'sellerId': sellerId, 'segment': '${specialty.name}|$region', 'days': duration});
    notifyListeners();
    return h;
  }

  void releaseHold(String sellerId) {
    final before = _holds.length;
    _holds.removeWhere((h) => h.sellerId == sellerId);
    if (before != _holds.length) notifyListeners();
  }

  /// After successful payment: slot waits for admin content approval.
  TGSponsorSlot purchase({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
    required DateTime startsAt,
    required int durationDays,
    required String title,
    required String imageUrl,
    String? projectLink,
  }) {
    final duration = durationDays;
    ensureSeeded();
    final err = eligibilityError(sellerId);
    if (err != null) throw StateError(err);
    if (title.trim().isEmpty || title.trim().length > 60) throw StateError('ui_banner_err_title');
    final start = dayOf(startsAt);
    if (!windowFree(specialty, region, start, duration, ignoreHoldOf: sellerId)) throw StateError('ui_banner_err_full');
    final list = priceFor(duration);
    final paid = priceForSeller(sellerId, duration);
    final rate = TGFounderService.instance.activeDiscountRate(sellerId);
    if (rate > 0 && paid < list) {
      TGFounderService.instance.recordSavings(
        sellerId: sellerId,
        item: TGFounderDiscountItem.sponsorSlot,
        listPrice: list,
        paidPrice: paid,
        discountPct: rate,
      );
    }
    _holds.removeWhere((h) => h.sellerId == sellerId);
    final slot = TGSponsorSlot(
      id: 'SLOT-${_seq++}',
      specialty: specialty,
      region: region,
      status: TGSponsorSlotStatus.contentPending,
      sellerId: sellerId,
      title: title.trim(),
      imageUrl: imageUrl,
      projectLink: projectLink,
      startsAt: start,
      endsAt: addDays(start, duration),
      paidAmount: paid,
      durationDays: duration,
    );
    slots.add(slot);
    TGAnalytics.track('slot_purchase', {'id': slot.id, 'sellerId': sellerId, 'paid': paid, 'days': duration});
    notifyListeners();
    return slot;
  }

  void decideContent({
    required String slotId,
    required bool approve,
    required String actorId,
    required String note,
  }) {
    ensureSeeded();
    final i = slots.indexWhere((s) => s.id == slotId);
    if (i < 0) return;
    final s = slots[i];
    if (approve) {
      final now = TGClock.now();
      final live = s.startsAt == null || !now.isBefore(s.startsAt!);
      slots[i] = s.copyWith(status: live ? TGSponsorSlotStatus.active : TGSponsorSlotStatus.reserved, decisionNote: note);
    } else {
      slots[i] = s.copyWith(status: TGSponsorSlotStatus.cancelled, decisionNote: note, refundPln: s.paidAmount ?? 0);
      if (s.sellerId != null) {
        NotificationService.instance.add(
          userId: s.sellerId!,
          type: 'slot_refund',
          dealId: s.id,
          title: 'Sponsor slot',
          body: 'Content was not approved. Full refund issued.',
          deepLink: '/dashboard/manufacturer?tab=sponsor',
        );
      }
    }
    TGAnalytics.track('slot_content_decision', {'id': slotId, 'approve': approve, 'actor': actorId});
    notifyListeners();
  }

  void cancel({required String slotId, required String actorId, required String reason, bool refund = false}) {
    ensureSeeded();
    final i = slots.indexWhere((s) => s.id == slotId);
    if (i < 0) return;
    final s = slots[i];
    slots[i] = s.copyWith(
      status: TGSponsorSlotStatus.cancelled,
      decisionNote: reason,
      refundPln: refund ? (s.paidAmount ?? 0) : null,
    );
    if (refund && s.sellerId != null) {
      NotificationService.instance.add(
        userId: s.sellerId!,
        type: 'slot_cancelled',
        dealId: s.id,
        title: 'Sponsor slot cancelled',
        body: 'Slot cancelled with refund.',
        deepLink: '/dashboard/manufacturer?tab=sponsor',
      );
    }
    notifyListeners();
  }

  List<TGSponsorSlot> forSeller(String sellerId) {
    ensureSeeded();
    return [for (final s in slots) if (s.sellerId == sellerId) s]..sort((a, b) => (b.startsAt ?? DateTime(0)).compareTo(a.startsAt ?? DateTime(0)));
  }

  /// Live slot of [sellerId] now, used to attribute hub impressions / clicks.
  TGSponsorSlot? liveSlotOf(String sellerId) {
    ensureSeeded();
    final now = TGClock.now();
    return slots
        .where((s) => s.sellerId == sellerId && s.status == TGSponsorSlotStatus.active && s.endsAt != null && now.isBefore(s.endsAt!))
        .firstOrNull;
  }

  ({int impressions, int clicks}) countersFor(String slotId) => _counters[slotId] ?? (impressions: 0, clicks: 0);

  /// Real counters: one impression and one click per visitor per day;
  /// the owner's and staff traffic is not counted ([count] false).
  bool recordImpression(String slotId, {required String visitorKey, required bool count}) => _bump(slotId, visitorKey, count, click: false);

  bool recordClick(String slotId, {required String visitorKey, required bool count}) => _bump(slotId, visitorKey, count, click: true);

  bool _bump(String slotId, String visitorKey, bool count, {required bool click}) {
    if (!count) return false;
    final d = dayOf(TGClock.now());
    if (!_counted.add('$slotId|$visitorKey|${click ? 'c' : 'i'}|${d.toIso8601String()}')) return false;
    final c = countersFor(slotId);
    _counters[slotId] = click ? (impressions: c.impressions, clicks: c.clicks + 1) : (impressions: c.impressions + 1, clicks: c.clicks);
    if (click) notifyListeners();
    return true;
  }

  /// Owner ends a live slot today. Unused days are not refunded.
  String? stopByOwner(String slotId, {required String sellerId}) {
    ensureSeeded();
    final i = slots.indexWhere((s) => s.id == slotId);
    if (i < 0) return 'ads_err_not_found';
    final s = slots[i];
    if (s.sellerId != sellerId) return 'ads_err_not_owner';
    if (s.status != TGSponsorSlotStatus.active) return 'ads_err_not_live';
    final now = TGClock.now();
    slots[i] = s.copyWith(status: TGSponsorSlotStatus.expired, endsAt: now, decisionNote: 'owner_stop');
    TGAnalytics.track('slot_stop_early', {'id': slotId, 'sellerId': sellerId});
    notifyListeners();
    return null;
  }

  /// Active sponsored manufacturer for hub (specialty × region filter).
  TGStoreProfile? sponsoredFor({TGStoreSpecialty? specialty, String? region}) {
    ensureSeeded();
    if (!enabled) return null;
    final now = TGClock.now();
    final active = slots.where((s) =>
        s.status == TGSponsorSlotStatus.active &&
        s.endsAt != null &&
        now.isBefore(s.endsAt!) &&
        (specialty == null || s.specialty == specialty) &&
        (region == null || region.isEmpty || s.region == region));
    final hit = active.firstOrNull;
    if (hit?.sellerId == null) return null;
    return TGSellerProfileService.instance.bySellerKey(hit!.sellerId!);
  }

  void onClockAdvanced() {
    ensureSeeded();
    _dropExpiredHolds();
    final now = TGClock.now();
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.status == TGSponsorSlotStatus.reserved && s.startsAt != null && !now.isBefore(s.startsAt!)) {
        slots[i] = s.copyWith(status: TGSponsorSlotStatus.active);
        continue;
      }
      if (s.status != TGSponsorSlotStatus.active || s.endsAt == null) continue;
      final days = s.endsAt!.difference(now).inDays;
      if (days == 7 && s.sellerId != null && _endingReminded.add(s.id)) {
        NotificationService.instance.add(
          userId: s.sellerId!,
          type: 'slot_ending',
          dealId: s.id,
          title: 'Sponsor slot ending',
          body: 'Your sponsor slot ends in 7 days.',
          deepLink: '/dashboard/manufacturer?tab=sponsor',
        );
      }
      if (!now.isBefore(s.endsAt!)) {
        slots[i] = s.copyWith(status: TGSponsorSlotStatus.expired);
      }
    }
    notifyListeners();
  }

  void _seedAll() {
    final now = TGClock.now();
    final today = dayOf(now);
    slots.addAll([
      TGSponsorSlot(
        id: 'SLOT-seed-1',
        specialty: TGStoreSpecialty.extractionHoods,
        region: 'Śląskie',
        status: TGSponsorSlotStatus.active,
        sellerId: 'seller_gastropl',
        title: 'Custom extraction hoods for kitchens',
        imageUrl: TGListingImages.seedCover(
          id: 'SLOT-seed-1',
          category: TGCategory.stainlessSteelFurniture,
          title: 'Custom extraction hoods for kitchens',
        ),
        projectLink: '/s/gastropl',
        startsAt: addDays(today, -10),
        endsAt: addDays(today, 20),
        paidAmount: priceFor(30),
        durationDays: 30,
      ),
      TGSponsorSlot(
        id: 'SLOT-seed-2',
        specialty: TGStoreSpecialty.worktopsTables,
        region: 'Śląskie',
        status: TGSponsorSlotStatus.contentPending,
        sellerId: 'seller_inoxline',
        title: 'Stainless worktops — fast lead times',
        imageUrl: TGListingImages.seedCover(
          id: 'SLOT-seed-2',
          category: TGCategory.stainlessSteelFurniture,
          title: 'Stainless worktops — fast lead times',
        ),
        startsAt: addDays(today, 2),
        endsAt: addDays(today, 16),
        paidAmount: priceFor(14),
        durationDays: 14,
      ),
      const TGSponsorSlot(
        id: 'SLOT-seed-3',
        specialty: TGStoreSpecialty.barCounters,
        region: 'Mazowieckie',
        status: TGSponsorSlotStatus.available,
      ),
      TGSponsorSlot(
        id: 'SLOT-seed-4',
        specialty: TGStoreSpecialty.coldRooms,
        region: 'Śląskie',
        status: TGSponsorSlotStatus.expired,
        sellerId: 'seller_stalbar',
        title: 'Cold room fit-outs',
        startsAt: addDays(today, -40),
        endsAt: addDays(today, -10),
        paidAmount: priceFor(30),
        durationDays: 30,
      ),
    ]);
  }
}
