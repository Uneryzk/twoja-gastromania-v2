import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_card_title.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_price.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/standard_member_seeds.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    TGSellerProfileService.instance.reset();
    await TGProductService.instance.resetToSeed();
  });

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('each category has five new standard listings from unique new members', () async {
    expect(kStandardMemberSeeds, hasLength(30));
    expect(kStandardMemberSeeds.map((s) => s.sellerId).toSet(), hasLength(30));
    expect(kStandardMemberSeeds.map((s) => s.publicId).toSet(), hasLength(30));
    for (final c in TGCategory.values) {
      expect(kStandardMemberSeeds.where((s) => s.category == c), hasLength(5));
    }

    final all = await TGProductService.instance.getAll();
    final pack = [for (final s in kStandardMemberSeeds) all.singleWhere((p) => p.id == s.id)];
    expect(pack, hasLength(30));
    expect(pack.every((p) => p.isPromoted == false), isTrue);
    expect(pack.every((p) => p.listingType == TGListingType.buy), isTrue);
    expect(pack.every((p) => TGListingPrice.isValid(p.price)), isTrue);
    expect(pack.every((p) => p.seller.type == TGSellerType.private), isTrue);
    expect(pack.map((p) => p.seller.id).toSet(), hasLength(30));

    final profiles = TGSellerProfileService.instance.all;
    for (final s in kStandardMemberSeeds) {
      final profile = profiles.singleWhere((p) => p.publicId == s.publicId);
      expect(profile.sellerKey, s.sellerId);
      expect(profile.type, TGSellerType.private);
      expect(TGSellerProfileService.seedPublicIds.contains(s.publicId), isTrue);
    }
  });

  testWidgets('new standard member cards use Inter Tight Light w300 titles', (tester) async {
    final all = await TGProductService.instance.getAll();
    final first = all.singleWhere((p) => p.id == 'pstd18');
    expect(first.seller.name, 'Bartek Z.');
    expect(first.isPromoted, isFalse);

    await tester.runAsync(loadRealisticFonts);
    tester.view.physicalSize = const Size(400, 900);
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
          home: Scaffold(body: TGProductCard(product: first)),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text(first.title).first);
    expect(title.style?.fontWeight, FontWeight.w300);
    expect(title.style?.fontSize, TGListingCardTitle.fontSize);
    expect(title.style?.letterSpacing, TGListingCardTitle.letterSpacing);
    expect(title.style?.fontFamily, isNot(contains('700')));
    expect(title.style?.fontFamily?.toLowerCase().replaceAll(' ', ''), contains('intertight'));
  });
}
