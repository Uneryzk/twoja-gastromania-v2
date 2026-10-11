import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class TGSponsorSlotService extends ChangeNotifier {
  TGSponsorSlotService._();
  static final TGSponsorSlotService instance = TGSponsorSlotService._();

  static const int pricePln = 399;
  static const int durationDays = 30;

  final List<TGSponsorSlot> slots = [];
  final Set<String> _endingReminded = {};
  bool _seeded = false;
  int _seq = 1;

  void reset() {
    slots.clear();
    _endingReminded.clear();
    _seeded = false;
    _seq = 1;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedAll();
  }

  bool get enabled => TGRevenueConfigService.instance.flags.sponsorSlots;

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

  TGSponsorSlot? activeFor(TGStoreSpecialty specialty, String region) {
    ensureSeeded();
    final now = TGClock.now();
    return slots.where((s) =>
        s.specialty == specialty &&
        s.region == region &&
        s.status == TGSponsorSlotStatus.active &&
        s.endsAt != null &&
        now.isBefore(s.endsAt!)).firstOrNull;
  }

  TGSponsorSlot? slotAt(TGStoreSpecialty specialty, String region) {
    ensureSeeded();
    return slots.where((s) => s.specialty == specialty && s.region == region).firstOrNull;
  }

  String? eligibilityError(String sellerId) {
    final p = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (p == null) return 'Manufacturer profile required';
    if (p.plan != TGStorePlanKind.pro && p.plan != TGStorePlanKind.enterprise) {
      return 'Active Pro or Enterprise plan required';
    }
    return null;
  }

  int priceForSeller(String sellerId) => TGFounderService.instance.discountedPrice(sellerId, pricePln);

  TGSponsorSlot reserve({
    required String sellerId,
    required TGStoreSpecialty specialty,
    required String region,
    required String title,
    required String imageUrl,
    String? projectLink,
  }) {
    ensureSeeded();
    final err = eligibilityError(sellerId);
    if (err != null) throw StateError(err);
    if (title.trim().length > 60) throw StateError('Title max 60 characters');
    final existing = activeFor(specialty, region);
    if (existing != null) throw StateError('Segment already booked');
    final paid = priceForSeller(sellerId);
    final rate = TGFounderService.instance.activeDiscountRate(sellerId);
    if (rate > 0 && paid < pricePln) {
      TGFounderService.instance.recordSavings(
        sellerId: sellerId,
        item: TGFounderDiscountItem.sponsorSlot,
        listPrice: pricePln,
        paidPrice: paid,
        discountPct: rate,
      );
    }
    final now = TGClock.now();
    final slot = TGSponsorSlot(
      id: 'SLOT-${_seq++}',
      specialty: specialty,
      region: region,
      status: TGSponsorSlotStatus.contentPending,
      sellerId: sellerId,
      title: title.trim(),
      imageUrl: imageUrl,
      projectLink: projectLink,
      startsAt: now,
      endsAt: now.add(const Duration(days: durationDays)),
      paidAmount: paid,
    );
    slots.removeWhere((s) => s.specialty == specialty && s.region == region && s.status != TGSponsorSlotStatus.active);
    slots.add(slot);
    TGAnalytics.track('slot_reserve', {'id': slot.id, 'sellerId': sellerId, 'paid': paid});
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
      slots[i] = s.copyWith(status: TGSponsorSlotStatus.active, decisionNote: note);
    } else {
      slots[i] = s.copyWith(status: TGSponsorSlotStatus.cancelled, decisionNote: note);
      // Full refund on content rejection (mock)
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
    slots[i] = s.copyWith(status: TGSponsorSlotStatus.cancelled, decisionNote: reason);
    if (refund && s.sellerId != null) {
      NotificationService.instance.add(
        userId: s.sellerId!,
        type: 'slot_cancelled',
        dealId: s.id,
        title: 'Sponsor slot cancelled',
        body: refund ? 'Slot cancelled with refund.' : 'Slot cancelled.',
        deepLink: '/dashboard/manufacturer?tab=sponsor',
      );
    }
    notifyListeners();
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
    final now = TGClock.now();
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
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
    slots.addAll([
      TGSponsorSlot(
        id: 'SLOT-seed-1',
        specialty: TGStoreSpecialty.extractionHoods,
        region: 'Śląskie',
        status: TGSponsorSlotStatus.active,
        sellerId: 'seller_gastropl',
        title: 'Custom extraction hoods for kitchens',
        imageUrl: 'assets/images/blog-26.jpg',
        projectLink: '/s/gastropl',
        startsAt: now.subtract(const Duration(days: 10)),
        endsAt: now.add(const Duration(days: 20)),
        paidAmount: 399,
      ),
      TGSponsorSlot(
        id: 'SLOT-seed-2',
        specialty: TGStoreSpecialty.worktopsTables,
        region: 'Śląskie',
        status: TGSponsorSlotStatus.contentPending,
        sellerId: 'seller_inoxline',
        title: 'Stainless worktops — fast lead times',
        imageUrl: 'assets/images/blog-26.jpg',
        startsAt: now.subtract(const Duration(days: 1)),
        endsAt: now.add(const Duration(days: 29)),
        paidAmount: 319,
      ),
      TGSponsorSlot(
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
        startsAt: now.subtract(const Duration(days: 40)),
        endsAt: now.subtract(const Duration(days: 10)),
        paidAmount: 399,
      ),
    ]);
  }
}
