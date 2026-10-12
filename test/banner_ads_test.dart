import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart' show TGStorePlanKind;

void main() {
  final ads = AdSlotService.instance;
  late DateTime today;

  TGAdSlot buy(String owner, DateTime start, BannerDurationKey d, {bool entitlement = false}) => ads.purchaseAndSubmit(
        ownerId: owner,
        kind: TGAdSlotKind.listing,
        targetUrl: '/products',
        title: 'Banner $owner',
        imageUrl: 'assets/images/mutfak-ekipmanlari.jpg',
        startsAt: start,
        duration: d,
        useEnterpriseEntitlement: entitlement,
      );

  setUp(() {
    TGClock.reset();
    PricingConfigService.instance.resetForTests();
    TGRevenueConfigService.instance.reset();
    TGRevenueConfigService.instance.setPhase(2, actorId: 'test');
    ads.reset();
    ads.ensureSeeded();
    today = AdSlotService.dayOf(TGClock.now());
  });

  test('banner prices come from PricingConfig.banner (1w/2w/1m)', () {
    final b = PricingConfig.defaults.banner;
    expect(b.pricePln(BannerDurationKey.w1), 129);
    expect(b.pricePln(BannerDurationKey.w2), 199);
    expect(b.pricePln(BannerDurationKey.m1), 349);
    expect(BannerDurationKey.m1.days, 30);
    expect(PricingConfig.defaults.perDayLabel(129, 7), '18,43 PLN/day');
    expect(PricingConfig.defaults.perDayLabel(349, 30), '11,63 PLN/day');
    final slot = buy('u1', today.add(const Duration(days: 20)), BannerDurationKey.m1);
    expect(slot.pricePln, 349);
    expect(slot.endsAt.difference(slot.startsAt).inDays, 30);
  });

  test('purchase is hidden unless bannerAds flag + phase 2', () {
    expect(ads.purchaseVisible, isTrue);
    TGRevenueConfigService.instance.setPhase(1, actorId: 'test');
    expect(ads.purchaseVisible, isFalse);
    expect(() => buy('u1', today.add(const Duration(days: 20)), BannerDurationKey.w1), throwsStateError);
  });

  test('max 3 sponsored per day; full days suggest the next free window', () {
    final full = today.add(const Duration(days: 5));
    expect(ads.seatsTaken(full), 3);
    expect(ads.isDayFull(full), isTrue);
    expect(ads.windowFree(full, BannerDurationKey.w1), isFalse);
    final next = ads.nextAvailableStart(BannerDurationKey.w1, from: full)!;
    expect(ads.windowFree(next, BannerDurationKey.w1), isTrue);
    expect(next.isAfter(full), isTrue);
    expect(() => buy('u1', full, BannerDurationKey.w1), throwsStateError);
  });

  test('24 h hold locks the window for others until it expires', () {
    final start = today.add(const Duration(days: 30));
    ads.reserve(ownerId: 'a', startsAt: start, duration: BannerDurationKey.w1);
    ads.reserve(ownerId: 'b', startsAt: start, duration: BannerDurationKey.w1);
    expect(ads.seatsTaken(start), 2);
    buy('c', start, BannerDurationKey.w1);
    expect(ads.isDayFull(start), isTrue);
    expect(() => ads.reserve(ownerId: 'd', startsAt: start, duration: BannerDurationKey.w1), throwsStateError);
    // The holder itself can still pay.
    expect(ads.windowFree(start, BannerDurationKey.w1, ignoreHoldOf: 'a'), isTrue);
    TGClock.advance(const Duration(hours: 25));
    expect(ads.seatsTaken(start), 1);
  });

  test('60 days full → waitlist; seat freed → waitlist notified and cleared', () {
    var n = 0;
    for (var start = ads.nextAvailableStart(BannerDurationKey.w1);
        start != null;
        start = ads.nextAvailableStart(BannerDurationKey.w1)) {
      buy('fill${n++}', start, BannerDurationKey.w1);
    }
    expect(ads.horizonFull(BannerDurationKey.w1), isTrue);
    ads.joinWaitlist('w', BannerDurationKey.w1);
    expect(ads.isOnWaitlist('w'), isTrue);
    final victim = ads.slots.firstWhere((s) => s.ownerId == 'fill0');
    ads.reject(victim.id, actorId: 'admin', actorRole: 'admin', reason: 'Quality');
    expect(ads.isOnWaitlist('w'), isFalse);
  });

  test('admin: one correction round, reject = automatic full refund', () {
    final s = buy('u1', today.add(const Duration(days: 20)), BannerDurationKey.w2);
    expect(ads.canRequestChanges(s), isTrue);
    expect(ads.requestChanges(s.id, actorId: 'adm', actorRole: 'admin', reason: 'Logo too small'), isNull);
    expect(ads.slots.first.status, TGAdSlotStatus.changesRequested);
    expect(ads.slots.first.occupiesSeat, isTrue);
    expect(ads.resubmit(s.id, ownerId: 'u1', title: 'Fixed', imageUrl: s.imageUrl), isNull);
    final again = ads.slots.first;
    expect(again.correctionsUsed, 1);
    expect(ads.canRequestChanges(again), isFalse);
    expect(ads.requestChanges(s.id, actorId: 'adm', actorRole: 'admin', reason: 'x'), isNotNull);
    ads.reject(s.id, actorId: 'adm', actorRole: 'admin', reason: 'Still unclear');
    expect(ads.slots.first.status, TGAdSlotStatus.rejected);
    expect(ads.slots.first.refundPln, 199);
  });

  test('approve before start → scheduled, goes live on start date', () {
    final s = buy('u1', today.add(const Duration(days: 20)), BannerDurationKey.w1);
    ads.approve(s.id, actorId: 'adm', actorRole: 'admin');
    expect(ads.slots.first.status, TGAdSlotStatus.approved);
    TGClock.advance(const Duration(days: 20, hours: 1));
    ads.onClockAdvanced();
    expect(ads.slots.firstWhere((x) => x.id == s.id).status, TGAdSlotStatus.live);
    expect(ads.liveSlides.length, lessThanOrEqualTo(3));
  });

  test('owner cancel ≥ 7 days before start = full refund; later = refused', () {
    final early = buy('u1', today.add(const Duration(days: 20)), BannerDurationKey.w1);
    expect(ads.cancelByOwner(early.id, ownerId: 'u1'), isNull);
    final c = ads.slots.firstWhere((x) => x.id == early.id);
    expect(c.status, TGAdSlotStatus.cancelled);
    expect(c.refundPln, 129);
    expect(c.occupiesSeat, isFalse);

    final late = buy('u2', today.add(const Duration(days: 16)), BannerDurationKey.w1);
    TGClock.advance(const Duration(days: 10));
    expect(ads.canCancel(ads.slots.firstWhere((x) => x.id == late.id)), isFalse);
    expect(ads.cancelByOwner(late.id, ownerId: 'u2'), 'ui_banner_err_cancel_late');
  });

  test('Enterprise: one free 1-week banner per month only', () {
    final profile = TGSellerProfileService.instance.bySellerKey('seller_rm');
    if (profile?.plan != TGStorePlanKind.enterprise) return;
    expect(ads.enterpriseRemaining('seller_rm'), 1);
    expect(() => buy('seller_rm', today.add(const Duration(days: 20)), BannerDurationKey.w2, entitlement: true), throwsStateError);
    final free = buy('seller_rm', today.add(const Duration(days: 20)), BannerDurationKey.w1, entitlement: true);
    expect(free.pricePln, 0);
    expect(ads.enterpriseRemaining('seller_rm'), 0);
    ads.reject(free.id, actorId: 'adm', actorRole: 'admin', reason: 'x');
    expect(ads.enterpriseRemaining('seller_rm'), 1);
  });

  test('admin seat grid has exactly maxPerDay seats per day', () {
    final grid = ads.seatGrid(days: 14);
    expect(grid.length, 14);
    expect(grid.every((r) => r.seats.length == 3), isTrue);
    expect(ads.overbookedDays(), isEmpty);
  });
}
