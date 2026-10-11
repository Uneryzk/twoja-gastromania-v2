import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

/// Priority Manufacturer seats, waitlist, and quiet-month billing.
class TGPriorityService extends ChangeNotifier {
  TGPriorityService._();
  static final TGPriorityService instance = TGPriorityService._();

  final Map<String, TGSellerPriority> bySeller = {};
  final List<TGPriorityWaitlistEntry> waitlist = [];
  bool _seeded = false;

  void reset() {
    bySeller.clear();
    waitlist.clear();
    _seeded = false;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    final now = TGClock.now();
    // Enterprise Priority (included)
    bySeller['seller_rm'] = TGSellerPriority(
      status: TGPriorityStatus.active,
      source: TGPrioritySource.enterprise,
      activeSince: now.subtract(const Duration(days: 40)),
      nextBillingAt: null,
      segments: const [
        TGPrioritySegment(specialty: TGStoreSpecialty.fullFitout, region: 'Śląskie', seat: true),
        TGPrioritySegment(specialty: TGStoreSpecialty.coldRooms, region: 'Śląskie', seat: true),
      ],
    );
    // Addon Priority
    bySeller['seller_gastropl'] = TGSellerPriority(
      status: TGPriorityStatus.active,
      source: TGPrioritySource.addon,
      activeSince: now.subtract(const Duration(days: 20)),
      nextBillingAt: now.add(const Duration(days: 10)),
      segments: const [
        TGPrioritySegment(specialty: TGStoreSpecialty.worktopsTables, region: 'Śląskie', seat: true),
        TGPrioritySegment(specialty: TGStoreSpecialty.extractionHoods, region: 'Śląskie', seat: true),
      ],
    );
    // Waitlist
    bySeller['seller_metalgast'] = const TGSellerPriority(
      status: TGPriorityStatus.waitlist,
      segments: [
        TGPrioritySegment(specialty: TGStoreSpecialty.laserBending, region: 'Śląskie', waitlisted: true),
      ],
    );
    waitlist.add(TGPriorityWaitlistEntry(
      sellerId: 'seller_metalgast',
      specialty: TGStoreSpecialty.laserBending,
      region: 'Śląskie',
      joinedAt: now.subtract(const Duration(days: 3)),
    ));
    // Founder free
    bySeller['seller_inoxline'] = TGSellerPriority(
      status: TGPriorityStatus.active,
      source: TGPrioritySource.founderFree,
      activeSince: now.subtract(const Duration(days: 5)),
      nextBillingAt: now.add(const Duration(days: 65)),
      segments: const [
        TGPrioritySegment(specialty: TGStoreSpecialty.worktopsTables, region: 'Śląskie', seat: true),
      ],
    );
  }

  TGSellerPriority priorityFor(String sellerId) {
    ensureSeeded();
    return bySeller[sellerId] ?? const TGSellerPriority();
  }

  bool hasPrioritySeat(String sellerId, {TGStoreSpecialty? specialty}) {
    final p = priorityFor(sellerId);
    if (!p.hasEarlyAccess && !p.isActive) return false;
    if (specialty == null) return p.segments.any((s) => s.seat) || p.source == TGPrioritySource.enterprise;
    if (p.source == TGPrioritySource.enterprise) {
      final profile = TGSellerProfileService.instance.bySellerKey(sellerId);
      return profile?.specialties.contains(specialty) ?? false;
    }
    return p.coversSpecialty(specialty);
  }

  int seatsTaken(TGStoreSpecialty specialty, String region) {
    ensureSeeded();
    var n = 0;
    for (final e in bySeller.entries) {
      final p = e.value;
      if (p.source == TGPrioritySource.enterprise) continue; // Enterprise seats don't count toward cap
      if (!p.isActive && p.status != TGPriorityStatus.waitlist) continue;
      for (final s in p.segments) {
        if (s.seat && s.specialty == specialty && s.region.toLowerCase() == region.toLowerCase()) n++;
      }
    }
    return n;
  }

  int waitlistCount(TGStoreSpecialty specialty, String region) => waitlist
      .where((w) => w.specialty == specialty && w.region.toLowerCase() == region.toLowerCase())
      .length;

  bool segmentSaleOpen(TGStoreSpecialty specialty, String region) {
    final cfg = TGRevenueConfigService.instance;
    if (!cfg.flags.priorityForSale) return false;
    final matching = matchingRequests30d(specialty, region);
    return cfg.isSegmentGateOpen(specialty: specialty, region: region, matchingRequests30d: matching);
  }

  int matchingRequests30d(TGStoreSpecialty specialty, String region) {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    final now = TGClock.now();
    final from = now.subtract(const Duration(days: 30));
    return svc.requests.where((r) {
      if (r.createdAt.isBefore(from)) return false;
      if (r.status == TGSpecialRequestStatus.draft || r.status == TGSpecialRequestStatus.rejected) return false;
      final typeOk = r.projectTypes.contains(specialty);
      final regionOk = r.voivodeship.toLowerCase() == region.toLowerCase();
      return typeOk && regionOk;
    }).length;
  }

  int matchingRequestsThisMonth(String sellerId) {
    final profile = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (profile == null) return 0;
    final now = TGClock.now();
    final start = DateTime(now.year, now.month, 1);
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    return svc.requests.where((r) {
      if (r.createdAt.isBefore(start)) return false;
      if (r.status == TGSpecialRequestStatus.draft || r.status == TGSpecialRequestStatus.rejected) return false;
      final typeOk = r.projectTypes.any(profile.specialties.contains);
      final regionOk = profile.serviceRegions.any((reg) =>
          reg.toLowerCase() == 'nationwide' || reg.toLowerCase() == r.voivodeship.toLowerCase());
      return typeOk && regionOk;
    }).length;
  }

  /// Price brutto for billing period.
  int priceFor(TGPriorityBillingPeriod period) {
    final cfg = TGRevenueConfigService.instance.config.priority;
    final monthly = cfg.priceMonthly;
    return switch (period) {
      TGPriorityBillingPeriod.monthly => monthly,
      TGPriorityBillingPeriod.sixMonths => (monthly * 6 * (1 - cfg.bulk.sixMonthDiscount)).round(),
      TGPriorityBillingPeriod.yearly => monthly * (12 - cfg.bulk.yearlyFreeMonths),
    };
  }

  void joinWaitlist({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
  }) {
    ensureSeeded();
    if (waitlist.any((w) => w.sellerId == sellerId && w.specialty == specialty && w.region == region)) return;
    waitlist.add(TGPriorityWaitlistEntry(sellerId: sellerId, specialty: specialty, region: region, joinedAt: TGClock.now()));
    final cur = priorityFor(sellerId);
    final segs = [...cur.segments.where((s) => !(s.specialty == specialty && s.region == region))];
    segs.add(TGPrioritySegment(specialty: specialty, region: region, waitlisted: true));
    bySeller[sellerId] = cur.copyWith(status: TGPriorityStatus.waitlist, segments: segs);
    TGAnalytics.track('priority_waitlist_join', {'sellerId': sellerId, 'specialty': specialty.name, 'region': region});
    notifyListeners();
  }

  void grantFounderFree({
    required String sellerId,
    required List<TGPrioritySegment> segments,
    required DateTime freeUntil,
  }) {
    ensureSeeded();
    final now = TGClock.now();
    bySeller[sellerId] = TGSellerPriority(
      status: TGPriorityStatus.active,
      source: TGPrioritySource.founderFree,
      activeSince: now,
      nextBillingAt: freeUntil,
      segments: segments.map((s) => s.copyWith(seat: true, waitlisted: false)).toList(),
    );
    notifyListeners();
  }

  void activateAddon({
    required String sellerId,
    required List<TGPrioritySegment> segments,
    required TGPriorityBillingPeriod period,
    required String paymentMethod,
  }) {
    ensureSeeded();
    final now = TGClock.now();
    final months = switch (period) {
      TGPriorityBillingPeriod.monthly => 1,
      TGPriorityBillingPeriod.sixMonths => 6,
      TGPriorityBillingPeriod.yearly => 12,
    };
    bySeller[sellerId] = TGSellerPriority(
      status: TGPriorityStatus.active,
      source: TGPrioritySource.addon,
      activeSince: now,
      nextBillingAt: now.add(Duration(days: 30 * months)),
      segments: segments.map((s) => s.copyWith(seat: true, waitlisted: false)).toList(),
    );
    waitlist.removeWhere((w) => w.sellerId == sellerId);
    TGAnalytics.track('priority_purchase', {
      'sellerId': sellerId,
      'period': period.name,
      'method': paymentMethod,
      'amount': priceFor(period),
    });
    NotificationService.instance.add(
      userId: sellerId,
      type: 'priority_active',
      dealId: 'priority',
      title: 'Priority active',
      body: 'Your Priority Manufacturer subscription is active.',
      deepLink: '/dashboard/manufacturer?tab=early',
    );
    notifyListeners();
  }

  void cancelAtPeriodEnd(String sellerId) {
    ensureSeeded();
    final cur = priorityFor(sellerId);
    if (!cur.isActive || cur.source != TGPrioritySource.addon) return;
    bySeller[sellerId] = cur.copyWith(cancelAtPeriodEnd: true);
    TGAnalytics.track('priority_cancel', {'sellerId': sellerId});
    notifyListeners();
  }

  void grantSeatManual({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
    required String actorId,
    required String reason,
  }) {
    ensureSeeded();
    final cur = priorityFor(sellerId);
    final segs = [...cur.segments.where((s) => s.key != '${specialty.name}|$region')];
    segs.add(TGPrioritySegment(specialty: specialty, region: region, seat: true));
    bySeller[sellerId] = cur.copyWith(
      status: TGPriorityStatus.active,
      source: cur.source ?? TGPrioritySource.addon,
      activeSince: cur.activeSince ?? TGClock.now(),
      segments: segs,
    );
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config,
      actorId: actorId,
      action: 'priority_seat_grant',
      reason: reason,
      detail: '$sellerId ${specialty.name}|$region',
    );
    TGAnalytics.track('priority_seat_override', {'sellerId': sellerId, 'action': 'grant'});
    notifyListeners();
  }

  void revokeSeatManual({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
    required String actorId,
    required String reason,
  }) {
    ensureSeeded();
    final cur = priorityFor(sellerId);
    final segs = cur.segments.map((s) {
      if (s.specialty == specialty && s.region == region) return s.copyWith(seat: false);
      return s;
    }).toList();
    final anySeat = segs.any((s) => s.seat);
    bySeller[sellerId] = cur.copyWith(
      status: anySeat ? TGPriorityStatus.active : TGPriorityStatus.cancelled,
      segments: segs,
    );
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config,
      actorId: actorId,
      action: 'priority_seat_revoke',
      reason: reason,
      detail: '$sellerId ${specialty.name}|$region',
    );
    notifyListeners();
  }

  /// Called when mock clock advances — process billing quiet-month credits.
  void onClockAdvanced() {
    ensureSeeded();
    final cfg = TGRevenueConfigService.instance.config;
    final now = TGClock.now();
    var changed = false;
    for (final id in bySeller.keys.toList()) {
      final p = bySeller[id]!;
      if (p.source != TGPrioritySource.addon || !p.isActive || p.nextBillingAt == null) continue;
      if (p.nextBillingAt!.isAfter(now)) continue;
      if (p.cancelAtPeriodEnd) {
        bySeller[id] = p.copyWith(status: TGPriorityStatus.cancelled, clearBilling: true);
        changed = true;
        continue;
      }
      final matching = matchingRequestsThisMonth(id);
      if (matching < cfg.quietMonthThreshold) {
        final extended = p.nextBillingAt!.add(const Duration(days: 30));
        final credits = [
          ...p.quietMonthCredits,
          TGQuietMonthCredit(periodStart: p.nextBillingAt!.subtract(const Duration(days: 30)), matchingRequests: matching, extendedUntil: extended),
        ];
        bySeller[id] = p.copyWith(nextBillingAt: extended, quietMonthCredits: credits);
        NotificationService.instance.add(
          userId: id,
          type: 'priority_quiet_month',
          dealId: 'priority',
          title: 'Quiet month credit',
          body: 'Quiet month credit: your subscription was extended by one month.',
          deepLink: '/dashboard/manufacturer',
        );
        changed = true;
      } else {
        bySeller[id] = p.copyWith(nextBillingAt: p.nextBillingAt!.add(const Duration(days: 30)));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  List<({TGStoreSpecialty specialty, String region})> allSegments() {
    final out = <String, ({TGStoreSpecialty specialty, String region})>{};
    for (final p in TGSellerProfileService.instance.specialOrderManufacturers) {
      for (final s in p.specialties) {
        final key = '${s.name}|${p.voivodeship}';
        out[key] = (specialty: s, region: p.voivodeship);
      }
    }
    return out.values.toList();
  }
}
