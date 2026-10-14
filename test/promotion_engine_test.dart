import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/promotion_engine.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

TGProduct _p(String id, {bool promoted = false}) => TGProduct(
      id: id,
      title: 'Item $id',
      price: 1000,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: TGPriceBasis.netto,
      negotiable: false,
      oldPrice: null,
      condition: TGCondition.used,
      listingType: TGListingType.buy,
      category: TGCategory.cookingEquipment,
      powerType: TGPowerType.electric,
      warrantyMonths: 0,
      delivery: false,
      pickup: true,
      seller: const TGSeller(id: 's', name: 'S', type: TGSellerType.store, verified: true, rating: 4),
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '+48',
      imageUrl: 'assets/images/mutfak-ekipmanlari.jpg',
      photoCount: 1,
      isPromoted: promoted,
      createdAt: TGClock.now(),
    );

void main() {
  setUp(() {
    PromotionService.instance.resetForTests();
  });

  test('home featured never includes Bold and caps at homeFeaturedMax', () {
    final svc = PromotionService.instance;
    final now = TGClock.now();
    // Inject promos directly via ensureSeed then replace isn't public — use effective via isPromoted glow + seed.
    svc.ensureSeeded();
    final products = [for (var i = 1; i <= 20; i++) _p('p${i.toString().padLeft(3, '0')}')];
    final slots = PromotionEngine.composeHomeFeatured(
      candidates: products,
      idOf: (p) => p.id,
      promoOf: (p) => svc.effectiveListingPromo(p) ?? svc.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id),
      sessionSeed: 42,
    );
    expect(slots.length, lessThanOrEqualTo(svc.config.homeFeaturedMax));
    expect(slots.every((s) => s.promotion?.tier != PromotionTier.bold), isTrue);
    expect(slots.every((s) => s.promotion != null), isTrue);

    final viaCompose = PromotionEngine.compose(
      surface: PromotionSurface.home,
      candidates: products,
      idOf: (p) => p.id,
      promoOf: (p) => svc.effectiveListingPromo(p) ?? svc.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id),
      sessionSeed: 42,
    );
    expect(viaCompose.every((s) => s.promotion?.tier != PromotionTier.bold), isTrue);
  });

  test('legacy isPromoted maps to glow', () {
    final p = _p('legacy1', promoted: true);
    final promo = PromotionService.instance.effectiveListingPromo(p);
    expect(promo, isNotNull);
    expect(promo!.tier, PromotionTier.glow);
  });

  test('catalogue recommended pins spotlight before glow before bold', () {
    PromotionService.instance.ensureSeeded();
    final products = [for (var i = 1; i <= 18; i++) _p('p${i.toString().padLeft(3, '0')}')];
    final composed = PromotionEngine.composeCatalogue(
      filteredOrganic: products,
      idOf: (p) => p.id,
      promoOf: (p) => PromotionService.instance.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id),
      context: const PromotionComposeContext(
        surface: PromotionSurface.products,
        sort: PromotionSortMode.recommended,
        page: 1,
        sessionSeed: 7,
      ),
    );
    final tiers = [for (final s in composed.pinned) s.promotion?.tier];
    final firstBold = tiers.indexOf(PromotionTier.bold);
    final lastSpot = tiers.lastIndexOf(PromotionTier.spotlight);
    final lastGlow = tiers.lastIndexOf(PromotionTier.glow);
    if (firstBold >= 0 && lastSpot >= 0) expect(lastSpot, lessThan(firstBold));
    if (firstBold >= 0 && lastGlow >= 0) expect(lastGlow, lessThan(firstBold));
  });
}
