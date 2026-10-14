import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/add_product/publish_success_page.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

import 'helpers/tg_test_app.dart';

TGProduct _liveListing(String ownerId) {
  final now = TGClock.now();
  return TGProduct(
    id: 'showcase-live-1',
    title: 'Piec konwekcyjny łódź',
    price: 12500,
    priceUnit: TGPriceUnit.oneTime,
    priceBasis: TGPriceBasis.brutto,
    negotiable: false,
    oldPrice: null,
    condition: TGCondition.used,
    listingType: TGListingType.buy,
    category: TGCategory.cookingEquipment,
    powerType: TGPowerType.electric,
    warrantyMonths: 0,
    delivery: false,
    pickup: true,
    seller: TGSeller(id: ownerId, name: 'Jan', type: TGSellerType.private, verified: false, rating: 0),
    city: 'Warszawa',
    voivodeship: 'Mazowieckie',
    phone: '+48501234567',
    imageUrl: 'assets/images/mutfak-ekipmanlari.jpg',
    photoCount: 1,
    isPromoted: false,
    createdAt: now,
    status: TGListingStatus.active,
    publishedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
    source: TGListingSource.free,
    ownerId: ownerId,
    listingNo: '12345678',
  );
}

void main() {
  testWidgets('post-publish showcase is a single-page split with Regular free preview', (tester) async {
    final app = await pumpTgApp(tester, size: TGSizes.desktop, location: '/');
    final product = _liveListing(app.auth.userId);
    app.auth.upsertOwned(product);
    await tester.pump();
    app.router.go('${PublishSuccessPage.routePath}?id=${product.id}');
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(find.byKey(const Key('showcase-single-page')), findsOneWidget);
    expect(find.byType(VerticalDivider), findsWidgets);
    expect(find.text('Standard listing'), findsOneWidget);
    expect(find.byKey(const Key('showcase-tier-bold')), findsOneWidget);
    expect(find.byKey(const Key('showcase-tier-glow')), findsOneWidget);
    expect(find.byKey(const Key('showcase-tier-spotlight')), findsOneWidget);
    expect(find.text('BLIK'), findsOneWidget);
    expect(find.text('Przelewy24'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    final preview = tester.widget<TGProductCard>(
      find.descendant(of: find.byKey(const Key('showcase-standard-preview')), matching: find.byType(TGProductCard)),
    );
    expect(preview.previewAsStandard, isTrue);
    final title = tester.widget<Text>(
      find.descendant(of: find.byKey(const Key('showcase-standard-preview')), matching: find.text(product.title)),
    );
    expect(title.style?.fontWeight, FontWeight.w400);
    expect(title.style?.fontWeight, isNot(FontWeight.w700));
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
    _expectNoErrors(app);
  });
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
