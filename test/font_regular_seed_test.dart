import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

Finder _within(Finder of, Finder matching) => find.descendant(of: of, matching: matching);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() {
    TGClock.reset();
    TGSellerProfileService.instance.reset();
    PromotionService.instance.resetForTests();
  });

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('font pack seeds exactly five typed listings with Regular-ready titles', () async {
    final all = await TGProductService.instance.getAll();
    const ids = ['p020', 'p021', 'p022', 'p023', 'p024'];
    final pack = [for (final id in ids) all.singleWhere((p) => p.id == id)];
    expect(pack, hasLength(5));
    expect(all, hasLength(23));

    expect(pack[0].seller.type, TGSellerType.private);
    expect(pack[0].seller.id, 'seller_font_piotr');
    expect(pack[0].listingType, TGListingType.buy);
    expect(pack[0].isPromoted, isFalse);

    expect(pack[1].seller.type, TGSellerType.store);
    expect(pack[1].seller.id, 'seller_font_inoxcorp');
    expect(pack[1].listingType, TGListingType.buy);
    expect(pack[1].isPromoted, isFalse);

    expect(pack[2].seller.id, 'seller_font_customkit');
    expect(pack[2].category, TGCategory.stainlessSteelFurniture);
    expect(pack[2].isPromoted, isTrue);

    expect(pack[3].seller.id, 'seller_font_rentline');
    expect(pack[3].listingType, TGListingType.rent);
    expect(pack[3].category, TGCategory.cookingEquipment);
    expect(pack[3].isPromoted, isTrue);

    expect(pack[4].seller.id, 'seller_font_proheat');
    expect(pack[4].seller.type, TGSellerType.store);
    expect(pack[4].isPromoted, isFalse);

    expect(
      pack.every((p) =>
          p.category == TGCategory.cookingEquipment ||
          p.category == TGCategory.stainlessSteelFurniture),
      isTrue,
    );
    expect(pack.map((p) => p.listingNo).toSet(), {
      '28270615',
      '29381726',
      '30492837',
      '31503948',
      '32614059',
    });
  });

  test('font pack seller profiles: private, enterprise, special-order, rental, Pro', () {
    final svc = TGSellerProfileService.instance;
    final private = svc.bySellerKey('seller_font_piotr')!;
    expect(private.type, TGSellerType.private);
    expect(private.isSpecialOrderManufacturer, isFalse);

    final corp = svc.bySellerKey('seller_font_inoxcorp')!;
    expect(corp.type, TGSellerType.store);
    expect(corp.plan, TGStorePlanKind.enterprise);
    expect(corp.isSpecialOrderManufacturer, isFalse);

    final so = svc.bySellerKey('seller_font_customkit')!;
    expect(so.isSpecialOrderManufacturer, isTrue);
    expect(so.plan, TGStorePlanKind.pro);
    expect(so.acceptsSpecialOrder, isTrue);

    final rent = svc.bySellerKey('seller_font_rentline')!;
    expect(rent.services, contains(TGStoreService.leasing));
    expect(rent.isSpecialOrderManufacturer, isFalse);

    final pro = svc.bySellerKey('seller_font_proheat')!;
    expect(pro.plan, TGStorePlanKind.pro);
    expect(pro.isSpecialOrderManufacturer, isFalse);

    expect(TGSellerProfileService.demoBestSellerPublicIds.contains('8810'), isFalse);
    expect(TGSellerProfileService.seedPublicIds.containsAll({8810, 8811, 8812, 8813, 8814}), isTrue);
  });

  test('font pack promo mocks: Bold + Spotlight ready; three stay Normal', () {
    PromotionService.instance.ensureSeeded();
    final all = PromotionService.instance.all;
    final bold = all.singleWhere((p) => p.id == 'promo-font-bold');
    final spot = all.singleWhere((p) => p.id == 'promo-font-spot');
    expect(bold.targetRef, 'p022');
    expect(bold.tier, PromotionTier.bold);
    expect(bold.status, PromotionStatus.active);
    expect(spot.targetRef, 'p023');
    expect(spot.tier, PromotionTier.spotlight);
    expect(spot.status, PromotionStatus.active);
    expect(all.where((p) => p.targetRef == 'p020' || p.targetRef == 'p021' || p.targetRef == 'p024'), isEmpty);
  });

  testWidgets('font pack cards: Normal Regular, Bold/Spotlight Medium, no Black', (tester) async {
    final all = await TGProductService.instance.getAll();
    PromotionService.instance.ensureSeeded();
    const ids = ['p020', 'p021', 'p022', 'p023', 'p024'];
    final pack = [for (final id in ids) all.singleWhere((p) => p.id == id)];

    await tester.runAsync(loadRealisticFonts);
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FakeAuthState>.value(
        value: FakeAuthState(isLoggedIn: true),
        child: MaterialApp(
          localizationsDelegates: const [
            FFLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('pl'),
          supportedLocales: const [Locale('pl'), Locale('en'), Locale('tr')],
          theme: buildTGDarkTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                for (final p in pack)
                  SizedBox(
                    height: TGProductCard.listExtent(900),
                    child: TGProductCard(product: p, layout: TGProductCardLayout.list),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    void expectTitle(String id, FontWeight weight) {
      final card = find.byWidgetPredicate((w) => w is TGProductCard && w.product.id == id);
      expect(card, findsOneWidget);
      final product = tester.widget<TGProductCard>(card).product;
      final title = tester.widget<Text>(_within(card, find.text(product.title)).first);
      expect(title.style?.fontWeight, weight);
      expect(title.style?.letterSpacing, greaterThanOrEqualTo(0.2));
      expect(title.style?.letterSpacing, lessThanOrEqualTo(0.4));
    }

    expectTitle('p020', FontWeight.w400);
    expectTitle('p021', FontWeight.w400);
    expectTitle('p024', FontWeight.w400);
    expectTitle('p022', FontWeight.w700);
    expectTitle('p023', FontWeight.w700);
  });
}
