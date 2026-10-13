import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGAnalytics.reset();
    TGRevenueConfigService.instance.reset();
  });

  test('store nudge and plan prices come from PricingConfig', () {
    final cfg = PricingConfigService.instance.config;
    final nudge = kUiTranslations['ui_store_nudge']!['en']!;
    expect(nudge, contains('{fee}'));
    expect(nudge, contains('{store}'));
    expect(nudge.contains('49'), isFalse);
    expect(nudge.contains('199'), isFalse);
    expect(cfg.defaultListingFeePln, 49);
    expect(cfg.basicStoreMonthlyPln, 199);
    expect(cfg.restaurantFeePln(cfg.defaultRestaurantDays), 149);
  });

  test('duration copy uses {period} instead of a hard-coded 30 days', () {
    for (final key in [
      'ui_free_listing_help',
      'ui_free_listing_help_last',
      'ui_free_listing_n',
      'ui_standard_listing_n',
      'ui_tooltip_first_three',
      'ui_sell_banner_title',
      'ui_first_three_free_detail',
    ]) {
      expect(kUiTranslations[key]!['en'], contains('{period}'), reason: key);
    }
  });

  test('productionMode hides seed listings and Best Sellers', () async {
    await TGProductService.instance.resetToSeed();
    expect((await TGProductService.instance.getAll()).length, greaterThan(0));
    expect(TGSellerProfileService.instance.bestSellers, isNotEmpty);

    TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
    expect(await TGProductService.instance.getAll(), isEmpty);
    expect(TGProductService.instance.cachedAll, isEmpty);
    expect(TGSellerProfileService.instance.bestSellers, isEmpty);

    TGRevenueConfigService.instance.reset();
    await TGProductService.instance.resetToSeed();
    expect((await TGProductService.instance.getAll()).length, greaterThan(0));
  });

  test('productionMode also hides cachedByNo seed lookups', () async {
    await TGProductService.instance.resetToSeed();
    final sample = TGProductService.instance.cachedAll.first;
    expect(TGProductService.instance.cachedByNo(sample.listingNo ?? ''), isNotNull);

    TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
    expect(TGProductService.instance.cachedByNo(sample.listingNo ?? ''), isNull);
    TGRevenueConfigService.instance.reset();
  });

  test('Best Sellers shield follows VERIFY-1, not a blanket label', () {
    for (final p in TGSellerProfileService.instance.bestSellers) {
      final seller = tgSellerFromProfile(p);
      expect(tgShowsVerifiedSellerBadge(seller), tgVerifiedBasis(seller) != null);
    }
  });

  test('ask-for-price key is the Polish Zapytaj o cenę source', () {
    expect(kUiTranslations['ui_ask_price']!['pl'], 'Zapytaj o cenę');
  });

  test('tier brand is authored, not runtime toUpperCase', () {
    expect(PromotionTier.glow.brand, 'Glow');
    expect(PromotionTier.bold.brand, 'Bold');
    expect(PromotionTier.spotlight.brand, 'Spotlight');
  });

  test('slot_reserve is tracked alongside slot_hold', () {
    final svc = TGSponsorSlotService.instance..ensureSeeded();
    final start = TGSponsorSlotService.dayOf(TGClock.now().add(const Duration(days: 10)));
    svc.hold(
      sellerId: 'seller_gastropl',
      specialty: TGStoreSpecialty.coldRooms,
      region: 'Pomorskie',
      startsAt: start,
      durationDays: PricingConfigService.instance.config.sponsorSlot.durations.first,
    );
    expect(TGAnalytics.has('slot_reserve'), isTrue);
    expect(TGAnalytics.has('slot_hold'), isTrue);
  });

  test('leftover promote copy uses {fee}/{period}, not hard-coded PLN or days', () {
    for (final key in ['ui_promote_14', 'ui_promote_30', 'ui_renew_promote_14', 'ui_renew_promote_30', 'ui_trial_help', 'ui_plans_sponsor_desc']) {
      final en = kUiTranslations[key]!['en']!;
      expect(en, contains('{period}'), reason: key);
      expect(en.contains('39'), isFalse, reason: key);
      expect(en.contains('69'), isFalse, reason: key);
    }
  });

  test('Bold never gets a featured badge', () {
    expect(TGProductCard.showsFeaturedBadge(tier: PromotionTier.bold, force: true), isFalse);
    expect(TGProductCard.showsFeaturedBadge(tier: PromotionTier.glow, force: false), isTrue);
    expect(TGProductCard.showsFeaturedBadge(tier: PromotionTier.spotlight, force: false), isTrue);
    expect(TGProductCard.showsFeaturedBadge(tier: null, force: false), isFalse);
  });

  test('WatermarkedImage strips originalRef from public URLs', () {
    expect(WatermarkedImage.publicUrl('originals/product:p001/0-abc'), isEmpty);
    expect(WatermarkedImage.isPrivateOriginalRef('https://cdn.example/img.jpg?originalRef=secret'), isTrue);
    expect(WatermarkedImage.publicUrl('assets/images/fridge.jpg'), 'assets/images/fridge.jpg');
  });

  test('empty manufacturer match fires so_admin_crosscheck_none', () {
    final so = TGSpecialOrderService.instance..ensureSeeded();
    final r = so.requests.first;
    so.matchManufacturers(r.id, const [], actorId: 'admin', actorRole: 'admin');
    expect(TGAnalytics.has('so_admin_crosscheck_none'), isTrue);
  });
}
