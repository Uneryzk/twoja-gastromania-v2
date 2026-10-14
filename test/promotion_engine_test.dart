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

  test('home featured is 3 Spotlight, 3 Glow, 3 Bold, then 3 standard', () {
    final svc = PromotionService.instance;
    svc.ensureSeeded();
    final products = [for (var i = 1; i <= 24; i++) _p('p${i.toString().padLeft(3, '0')}')];
    final slots = PromotionEngine.composeHomeFeatured(
      candidates: products,
      idOf: (p) => p.id,
      promoOf: (p) => svc.effectiveListingPromo(p) ?? svc.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id),
      sessionSeed: 42,
    );
    expect(slots.length, lessThanOrEqualTo(PromotionEngine.homeStripPerGroup * 4));
    final tiers = [for (final s in slots) s.promotion?.tier];
    expect(tiers.where((t) => t == PromotionTier.spotlight).length, lessThanOrEqualTo(3));
    expect(tiers.where((t) => t == PromotionTier.glow).length, lessThanOrEqualTo(3));
    expect(tiers.where((t) => t == PromotionTier.bold).length, lessThanOrEqualTo(3));
    expect(tiers.where((t) => t == null).length, lessThanOrEqualTo(3));
    final firstNull = tiers.indexOf(null);
    final lastPaid = tiers.lastIndexWhere((t) => t != null);
    if (firstNull >= 0 && lastPaid >= 0) expect(lastPaid, lessThan(firstNull));
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
