import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/go_live_checks.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';
import 'package:twoja_gastromania/tm_sayfalar/home_page/home_manufacturers_strip.dart';

void main() {
  final slots = TGSponsorSlotService.instance;
  late DateTime today;

  setUp(() {
    TGClock.reset();
    PricingConfigService.instance.resetForTests();
    PromotionService.instance.resetForTests();
    TGRevenueConfigService.instance.reset();
    TGRevenueConfigService.instance.setPhase(2, actorId: 'test');
    TGSellerProfileService.instance.reset();
    TGSpecialOrderService.instance.reset();
    slots.reset();
    slots.ensureSeeded();
    today = TGSponsorSlotService.dayOf(TGClock.now());
  });

  group('audit program removed', () {
    test('legacy audit payment kind still parses but is not sellable', () {
      expect(TGPaymentKind.fromName('audit'), TGPaymentKind.audit);
      expect(TGPaymentKind.audit.sellable, isFalse);
      expect(TGPaymentKind.sponsorSlot.sellable, isTrue);
    });

    test('FAQ explains verification without workmanship audits', () {
      expect(kUiTranslations['ui_so_faq_a5']!['en'], contains('company details (NIP) and an active subscription'));
      expect(kUiTranslations['ui_so_faq_a5']!['en'], contains("We don't audit workmanship; quality is shown through buyer reviews."));
      expect(kUiTranslations['ui_so_faq_a5']!['tr'], contains('NIP'));
      expect(kUiTranslations.containsKey('ui_audited_manufacturer'), isFalse);
      expect(kUiTranslations.containsKey('ui_mfr_tab_audit'), isFalse);
    });

    test('go-live checklist has no audit items', () {
      final ids = tgGoLiveChecks().map((c) => c.id).toList();
      expect(ids.any((id) => id.contains('audit')), isFalse);
      expect(ids, containsAll(['production_mode', 'promo_prices', 'ranking_disclosure', 'sponsor_prices']));
    });
  });

  group('sponsor slot (project type × region)', () {
    test('prices come from PricingConfig.sponsorSlot with per-day labels', () {
      final p = PricingConfig.defaults.sponsorSlot;
      expect(p.pricePln(7), 89);
      expect(p.pricePln(14), 149);
      expect(p.pricePln(30), 249);
      expect(p.holdHours, 24);
      expect(PricingConfig.defaults.perDayLabel(89, 7), '12,71 PLN/day');
      expect(PricingConfig.defaults.perDayLabel(249, 30), '8,30 PLN/day');
      expect(slots.priceFor(30), 249);
    });

    test('earliest free window starts after the live sponsor ends', () {
      final live = slots.activeFor(TGStoreSpecialty.extractionHoods, 'Śląskie')!;
      final next = slots.nextAvailableStart(TGStoreSpecialty.extractionHoods, 'Śląskie', 7);
      expect(next, TGSponsorSlotService.dayOf(live.endsAt!));
      expect(slots.windowFree(TGStoreSpecialty.extractionHoods, 'Śląskie', today, 7), isFalse);
    });

    test('24 h hold blocks other sellers and expires', () {
      slots.hold(
        sellerId: 'seller_gastropl',
        specialty: TGStoreSpecialty.coldRooms,
        region: 'Mazowieckie',
        startsAt: today,
        durationDays: 14,
      );
      expect(slots.windowFree(TGStoreSpecialty.coldRooms, 'Mazowieckie', today, 7), isFalse);
      expect(
        slots.windowFree(TGStoreSpecialty.coldRooms, 'Mazowieckie', today, 7, ignoreHoldOf: 'seller_gastropl'),
        isTrue,
      );
      expect(
        slots.nextAvailableStart(TGStoreSpecialty.coldRooms, 'Mazowieckie', 7),
        TGSponsorSlotService.addDays(today, 14),
      );
      TGClock.advance(const Duration(hours: 25));
      expect(slots.holdFor('seller_gastropl'), isNull);
      expect(slots.windowFree(TGStoreSpecialty.coldRooms, 'Mazowieckie', TGClock.now(), 7), isTrue);
    });

    test('payment → admin approval → live on start date', () {
      final start = TGSponsorSlotService.addDays(today, 3);
      final s = slots.purchase(
        sellerId: 'seller_gastropl',
        specialty: TGStoreSpecialty.barCounters,
        region: 'Śląskie',
        startsAt: start,
        durationDays: 14,
        title: 'Bar counters',
        imageUrl: 'x',
      );
      expect(s.status, TGSponsorSlotStatus.contentPending);
      expect(s.endsAt!.difference(s.startsAt!).inDays, 14);
      expect(slots.sponsoredFor(specialty: TGStoreSpecialty.barCounters, region: 'Śląskie'), isNull);

      slots.decideContent(slotId: s.id, approve: true, actorId: 'admin', note: 'ok');
      expect(slots.slots.firstWhere((x) => x.id == s.id).status, TGSponsorSlotStatus.reserved);

      TGClock.advance(const Duration(days: 3, hours: 1));
      slots.onClockAdvanced();
      expect(slots.slots.firstWhere((x) => x.id == s.id).status, TGSponsorSlotStatus.active);
      expect(slots.sponsoredFor(specialty: TGStoreSpecialty.barCounters, region: 'Śląskie')?.sellerKey, 'seller_gastropl');
    });

    test('rejected content is refunded and frees the window', () {
      final s = slots.purchase(
        sellerId: 'seller_gastropl',
        specialty: TGStoreSpecialty.barCounters,
        region: 'Mazowieckie',
        startsAt: today,
        durationDays: 7,
        title: 'Bar counters',
        imageUrl: 'x',
      );
      expect(slots.windowFree(TGStoreSpecialty.barCounters, 'Mazowieckie', today, 7), isFalse);
      slots.decideContent(slotId: s.id, approve: false, actorId: 'admin', note: 'logo missing');
      final after = slots.slots.firstWhere((x) => x.id == s.id);
      expect(after.status, TGSponsorSlotStatus.cancelled);
      expect(after.refundPln, s.paidAmount);
      expect(slots.windowFree(TGStoreSpecialty.barCounters, 'Mazowieckie', today, 7), isTrue);
    });

    test('basic plan sellers cannot buy', () {
      expect(
        () => slots.hold(
          sellerId: 'seller_ek',
          specialty: TGStoreSpecialty.coldRooms,
          region: 'Mazowieckie',
          startsAt: today,
          durationDays: 7,
        ),
        throwsStateError,
      );
    });
  });

  group('manufacturer card promotions', () {
    test('Spotlight → Glow → Bold → organic in /special-order list', () {
      final svc = TGSpecialOrderService.instance;
      final organic = svc.manufacturers();
      expect(organic.length, greaterThanOrEqualTo(4));
      final bold = organic[0].sellerKey, glow = organic[1].sellerKey, spot = organic[3].sellerKey;
      void buy(String key, PromotionTier tier) => PromotionService.instance.purchase(
            ownerId: key,
            kind: PromotionTargetKind.manufacturer,
            targetRef: key,
            tier: tier,
            durationDays: 14,
            pricePln: PricingConfigService.instance.config.promoFeePln(tier, 14),
            source: PromotionSource.paid,
          );
      buy(bold, PromotionTier.bold);
      buy(glow, PromotionTier.glow);
      buy(spot, PromotionTier.spotlight);
      final layered = svc.manufacturers().map((p) => p.sellerKey).toList();
      expect(layered.take(3), [spot, glow, bold]);
      expect(svc.promotionTierFor(glow), PromotionTier.glow);
      expect(PricingConfigService.instance.config.promoFeePln(PromotionTier.spotlight, 30), 99);
    });
  });

  group('home Special Order Manufacturers section', () {
    test('max 6 cards', () {
      expect(HomeManufacturersStrip.items().length, lessThanOrEqualTo(HomeManufacturersStrip.maxCards));
      expect(HomeManufacturersStrip.items(), isNotEmpty);
    });

    test('hidden when fewer than 3 real manufacturers in production mode', () {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 'test', reason: 'test');
      final real = TGSpecialOrderService.instance.manufacturers();
      expect(real.any((p) => p.sellerKey == 'seller_inoxline'), isFalse);
      if (real.length < 3) {
        expect(HomeManufacturersStrip.items(), isEmpty);
      } else {
        expect(HomeManufacturersStrip.items().length, real.length.clamp(0, 6));
      }
    });
  });

  test('admin promotion edits flow into PromotionService', () {
    final svc = PricingConfigService.instance;
    svc.setConfig(svc.config.copyWith(promotions: svc.config.promotions.copyWith(glowMaxActive: 2)));
    expect(PromotionService.instance.config.glowMaxActive, 2);
    final ranking = tgGoLiveChecks().firstWhere((c) => c.id == 'ranking_disclosure');
    expect(ranking.ok, isTrue);
    expect(ranking.blocking, isTrue);
  });
}
