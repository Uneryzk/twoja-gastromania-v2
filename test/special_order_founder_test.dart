import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGClock.reset();
    TGSellerProfileService.instance.reset();
    TGRevenueConfigService.instance.reset();
    TGFounderService.instance.reset();
  });

  test('founder seed: 9 applications, real quota counter', () {
    final svc = TGFounderService.instance..ensureSeeded();
    expect(svc.applications.length, 9);
    expect(svc.enrolledCount, 4); // ended program not counted
    expect(svc.cfg.quota, 20);
    expect(svc.spotsLabel(), '20 founding manufacturer spots'); // < counterMinReal (5)
    expect(svc.founderFor('seller_gastropl').tier, 2);
    expect(svc.founderFor('seller_inoxline').tier, 1);
    expect(svc.founderFor('seller_nordinox').isInProgram(TGClock.now()), isFalse);
  });

  test('NIP uniqueness and waitlist when quota full', () {
    final svc = TGFounderService.instance..ensureSeeded();
    expect(svc.nipAlreadyUsed('5252341134'), isTrue);
    expect(
      svc.canApply(sellerId: 'seller_x', nip: '5252341134', profilePct: 90, projects: 3, feedbackCallDone: true),
      'This company already joined the program',
    );
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config.copyWith(founder: svc.cfg.copyWith(quota: svc.spotsTaken)),
      actorId: 'test',
      action: 'test_quota',
      reason: 'test',
    );
    expect(svc.quotaFull, isTrue);
    expect(svc.spotsLabel(), 'Applications are on a waitlist');
  });

  test('discount prices: Priority / Promote 14 / 30 brutto examples', () {
    final svc = TGFounderService.instance..ensureSeeded();
    // gastropl: tier 2 (40%), past free months
    expect(svc.discountedPrice('seller_gastropl', 349), 209);
    expect(svc.discountedPrice('seller_gastropl', 39), 23);
    expect(svc.discountedPrice('seller_gastropl', 69), 41);
    expect(svc.discountedPrice('seller_gastropl', 399), 239);
    // inoxline: tier 1 (20%)
    expect(svc.discountedPrice('seller_inoxline', 349), 279);
    expect(svc.discountedPrice('seller_inoxline', 39), 31);
    expect(svc.discountedPrice('seller_inoxline', 69), 55);
    // metalgast still in free months → no tier discount
    expect(svc.activeDiscountRate('seller_metalgast'), 0);
  });

  test('qualified listing rules', () {
    final svc = TGFounderService.instance..ensureSeeded();
    final good = TGProduct(
      id: 'q1',
      title: 'Stainless prep table 1200',
      description: 'Solid commercial prep table with shelf and adjustable feet for kitchens.',
      price: 1200,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: TGPriceBasis.brutto,
      negotiable: false,
      oldPrice: null,
      condition: TGCondition.used,
      listingType: TGListingType.buy,
      category: TGCategory.cookingEquipment,
      powerType: TGPowerType.electric,
      warrantyMonths: 0,
      delivery: true,
      pickup: true,
      seller: const TGSeller(id: 'seller_inoxline', name: 'Inoxline', type: TGSellerType.store, verified: true, rating: 4.5),
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '+48111',
      imageUrl: 'assets/images/x.webp',
      imageUrls: const ['a', 'b', 'c'],
      photoCount: 3,
      isPromoted: false,
      createdAt: TGClock.now(),
      status: TGListingStatus.active,
      ownerId: 'seller_inoxline',
    );
    expect(svc.evaluateListing(good).qualified, isTrue);
    final bad = good.copyWith(imageUrls: const ['a'], title: 'COPY table short');
    final info = svc.evaluateListing(bad);
    expect(info.qualified, isFalse);
    expect(info.reasons.any((r) => r.contains('photos') || r.contains('Completion') || r.contains('copy') || r.contains('COPY')), isTrue);
  });

  test('free months and tier discounts are consecutive', () {
    final svc = TGFounderService.instance..ensureSeeded();
    final stalbar = svc.founderFor('seller_stalbar');
    expect(stalbar.isInFreeMonths(TGClock.now()), isTrue);
    expect(svc.activeDiscountRate('seller_stalbar'), 0);
    expect(svc.founderFor('seller_gastropl').isInFreeMonths(TGClock.now()), isFalse);
    expect(svc.activeDiscountRate('seller_gastropl'), 0.40);
  });

  testWidgets('founders page shows rules and real spot label', (tester) async {
    final app = await pumpTgApp(tester, location: '/founders', size: TGSizes.desktop);
    await tester.pumpAndSettle();
    expect(find.text('Founding manufacturers'), findsWidgets);
    expect(find.textContaining('No badge is awarded'), findsWidgets);
    expect(find.text('20 founding manufacturer spots'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(app.location, '/founders');
  });
}
