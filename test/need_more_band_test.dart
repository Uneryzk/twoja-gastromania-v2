import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/tg_components/tg_special_order_band.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  testWidgets('sale catalogue band offers Special Order and For rent', (tester) async {
    await pumpTgApp(tester, location: '/products?type=buy', size: TGSizes.desktop);
    expect(find.byType(TGSpecialOrderBand), findsOneWidget);
    expect(find.text("Can't find the product you need?"), findsWidgets);
    expect(find.text('Place a special order or rent instead!'), findsOneWidget);
    final band = find.byType(TGSpecialOrderBand);
    expect(find.descendant(of: band, matching: find.text('Special Order')), findsOneWidget);
    expect(find.descendant(of: band, matching: find.text('For rent')), findsOneWidget);
  });

  testWidgets('rent catalogue band offers Special Order and For sale', (tester) async {
    await pumpTgApp(tester, location: '/products?type=rent', size: TGSizes.desktop);
    expect(find.text('Place a special order or browse items for sale!'), findsOneWidget);
    final band = find.byType(TGSpecialOrderBand);
    expect(find.descendant(of: band, matching: find.text('Special Order')), findsOneWidget);
    expect(find.descendant(of: band, matching: find.text('For sale')), findsOneWidget);
  });

  testWidgets('restaurants hub band offers For sale and For rent', (tester) async {
    await pumpTgApp(tester, location: '/restaurants', size: TGSizes.desktop);
    expect(find.text('You may not have found the restaurant you were looking for'), findsOneWidget);
    expect(find.text('But take a look at gastronomy equipment!'), findsOneWidget);
    final band = find.byType(TGSpecialOrderBand);
    expect(find.descendant(of: band, matching: find.text('For sale')), findsOneWidget);
    expect(find.descendant(of: band, matching: find.text('For rent')), findsOneWidget);
  });
}
