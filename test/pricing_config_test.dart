import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

void main() {
  setUp(() {
    PricingConfigService.instance.resetForTests();
    PromotionService.instance.resetForTests();
  });

  test('defaults match VITRIN-2 examples', () {
    const c = PricingConfig.defaults;
    expect(c.listingFeePln(ListingDurationKey.d30), 49);
    expect(c.listingFeePln(ListingDurationKey.d90), 99);
    expect(c.restaurantFeePln(RestaurantDurationKey.d90), 149);
    expect(c.promoFeePln(PromotionTier.glow, PromotionDurationKey.month1), 79);
    expect(c.promoFeePln(PromotionTier.spotlight, PromotionDurationKey.month1), 99);
    // equipment 30d + Glow 1m = 128; equipment 90d + Spotlight 1m = 198; resto 90d + Glow 2w = 198
    expect(c.totalListingPlusPromo(listing: ListingDurationKey.d30, tier: PromotionTier.glow, promoDuration: PromotionDurationKey.month1), 128);
    expect(c.totalListingPlusPromo(listing: ListingDurationKey.d90, tier: PromotionTier.spotlight, promoDuration: PromotionDurationKey.month1), 198);
    expect(c.totalRestaurantPlusPromo(listing: RestaurantDurationKey.d90, tier: PromotionTier.glow, promoDuration: PromotionDurationKey.week2), 198);
  });

  test('per-day label uses comma decimal', () {
    const c = PricingConfig.defaults;
    expect(c.perDayLabel(49, 30), '1,63 PLN/day');
  });

  test('upgrade cost rounds up remaining fraction', () {
    const c = PricingConfig.defaults;
    // Bold 2w=15 → Glow 2w=49; delta 34; half period → 17
    expect(
      c.upgradeCostPln(
        from: PromotionTier.bold,
        to: PromotionTier.glow,
        duration: PromotionDurationKey.week2,
        remainingDays: 7,
        totalDays: 14,
      ),
      17,
    );
  });

  test('purchase creates active promotion', () {
    final p = PromotionService.instance.purchase(
      ownerId: 'u1',
      kind: PromotionTargetKind.listing,
      targetRef: 'x1',
      tier: PromotionTier.bold,
      durationKey: PromotionDurationKey.week2,
      pricePln: 15,
      source: PromotionSource.paid,
      listingEndsAt: DateTime.now().add(const Duration(days: 60)),
    );
    expect(p.status, PromotionStatus.active);
    expect(PromotionService.instance.activeFor(kind: PromotionTargetKind.listing, targetRef: 'x1'), isNotNull);
  });
}
