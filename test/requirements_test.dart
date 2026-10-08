import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/nav/nav.dart';
import 'package:twoja_gastromania/products/products_filters.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_core/tg_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

import 'helpers/tg_test_app.dart';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

List<TGProductCard> _cards(WidgetTester t) => t.widgetList<TGProductCard>(find.byType(TGProductCard)).toList();

List<String> _cardIds(WidgetTester t) => _cards(t).map((c) => c.product.id).toList();

Finder get _verticalScrollable => find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first;

Future<List<TGProduct>> _catalogue(WidgetTester t) async => (await t.runAsync(() => TGProductService.instance.getAll()))!;

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await pumpFor(t, const Duration(milliseconds: 600));
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}

Matrix4 _cardTransform(WidgetTester t, Finder card) {
  final ac = t.widget<AnimatedContainer>(find.descendant(of: card, matching: find.byType(AnimatedContainer)).first);
  return ac.transform!;
}

BoxDecoration _cardDecoration(WidgetTester t, Finder card) {
  final ac = t.widget<AnimatedContainer>(find.descendant(of: card, matching: find.byType(AnimatedContainer)).first);
  return ac.decoration! as BoxDecoration;
}

void main() {
  // =========================================================================
  group('1. Routing & navigation', () {
    testWidgets('the router opens on the home page ("/")', (tester) async {
      // Previously the app booted into /products and "/" rendered Products.
      final router = createRouter(AppStateNotifier.instance);
      expect(router.routeInformationProvider.value.uri.toString(), '/');
    });

    testWidgets('legacy /homePage URL redirects to "/"', (tester) async {
      final app = await pumpTgApp(tester, location: '/homePage');
      expect(app.location, '/');
      _expectNoErrors(app);
    });

    testWidgets('home "Buy" opens /products?type=buy and shows only buy listings', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await _tapText(tester, 'Buy');
      expect(app.location, '/products?type=buy');
      expect(find.text('13 results'), findsOneWidget);
      expect(_cards(tester).every((c) => c.product.listingType == TGListingType.buy), isTrue);
      _expectNoErrors(app);
    });

    testWidgets('home "Rent" opens /products?type=rent and shows only rent listings', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await _tapText(tester, 'Rent');
      expect(app.location, '/products?type=rent');
      expect(find.text('3 results'), findsOneWidget);
      expect(_cards(tester).every((c) => c.product.listingType == TGListingType.rent), isTrue);
      _expectNoErrors(app);
    });

    const categoryTitles = {
      TGCategory.cookingEquipment: 'Cooking Equipment',
      TGCategory.refrigerationEquipment: 'Refrigeration Equipment',
      TGCategory.warewashing: 'Warewashing',
      TGCategory.foodPreparation: 'Food Preparation',
      TGCategory.stainlessSteelFurniture: 'Stainless Steel Furniture',
      TGCategory.barAndBeverageEquipment: 'Bar & Beverage Equipment',
    };
    for (final e in categoryTitles.entries) {
      testWidgets('home category card "${e.value}" opens /products?cat=${encodeCategory(e.key)}', (tester) async {
        final app = await pumpTgApp(tester, location: '/');
        await _tapText(tester, e.value); // first match = the category card (footer comes later)
        expect(app.location, '/products?cat=${encodeCategory(e.key)}');
        expect(_cards(tester), isNotEmpty);
        expect(_cards(tester).every((c) => c.product.category == e.key), isTrue);
        _expectNoErrors(app);
      });
    }

    testWidgets('header search opens /products?q=...', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await tester.enterText(find.byType(TextField).first, 'piec');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/products?q=piec');
      expect(_cards(tester).every((c) => c.product.title.toLowerCase().contains('piec') || (c.product.description ?? '').toLowerCase().contains('piec')), isTrue);
      _expectNoErrors(app);
    });

    testWidgets('brand in the header and the "Home" breadcrumb return to the home page', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      await tester.tap(find.text('Home').first); // breadcrumb
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/');

      app.router.go('/products');
      await pumpFor(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Twoja Gastromania').first); // header brand
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/');
      _expectNoErrors(app);
    });

    testWidgets('the global header is sticky: it stays visible after scrolling the page', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final before = tester.getTopLeft(find.text('Twoja Gastromania').first);
      await tester.drag(_verticalScrollable, const Offset(0, -1500));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(tester.getTopLeft(find.text('Twoja Gastromania').first), before);
      _expectNoErrors(app);
    });

    testWidgets('header shows expired listings with priority over trial copy', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      expect(find.text('2 expired · Renew'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('on phones the pill is short and the site name stays in the header', (tester) async {
      final app = await pumpTgApp(tester, location: '/', size: TGSizes.phone);
      expect(find.text('Renew'), findsOneWidget);
      expect(find.text('2 expired · Renew'), findsNothing);
      expect(tester.getTopLeft(find.text('Twoja Gastromania').first).dy, lessThan(80));
      _expectNoErrors(app);
    });

    testWidgets('on phones restaurants and special order sit under Others', (tester) async {
      final app = await pumpTgApp(tester, location: '/', size: TGSizes.phone);
      expect(find.text('Buy'), findsWidgets);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('+ Add Product'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsWidgets);
      expect(find.text('Restaurants for Sale'), findsNothing);
      expect(find.text('Special Order'), findsNothing);

      await tester.tap(find.text('Others'));
      await tester.pumpAndSettle();
      expect(find.text('Restaurants for Sale'), findsOneWidget);
      expect(find.text('Special Order'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('signed-out visitors see "Login" and can log in (mock) to get the pill', (tester) async {
      final app = await pumpTgApp(tester, location: '/', signedIn: false);
      expect(find.text('2 expired · Renew'), findsNothing);
      await _tapText(tester, 'Login');
      expect(app.location, '/login');

      await tester.enterText(find.byType(TextField).at(0), 'jan@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await _tapText(tester, 'LOG IN', last: true);
      expect(app.location, '/');
      expect(app.auth.isLoggedIn, isTrue);
      expect(find.text('2 expired · Renew'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('account pill reflects all seven mock entitlement scenarios', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      expect(find.text('2 expired · Renew'), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.noListings);
      await tester.pump();
      expect(find.text('3 free listings'), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.freeActive);
      await tester.pump();
      expect(find.text('2 free left'), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.freeNoListingsLeft);
      await tester.pump();
      expect(find.text('0 free left'), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.needsAttention);
      await tester.pump();
      expect(find.text('1 listing needs attention'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_maybe_outlined), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.listingExpiringSoon);
      await tester.pump();
      expect(find.text('1 listing ends in 3d'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      app.auth.setScenario(TGEntitlementScenario.storeSubscriber);
      await tester.pump();
      expect(find.text('Basic Store · 11/15 active'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      _expectNoErrors(app);
    });
  });

  // =========================================================================
  group('2. Products page', () {
    testWidgets('left sidebar has every required filter', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      // Verified toggle
      expect(find.text('Verified sellers only'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      // Listing type
      expect(find.text('Listing type'), findsOneWidget);
      for (final t in ['All', 'Buy', 'Rent']) {
        expect(find.text(t), findsWidgets);
      }
      // Condition
      expect(find.text('New'), findsWidgets);
      expect(find.text('Used'), findsWidgets);
      // Category tree
      expect(find.text('All categories'), findsOneWidget);
      for (final c in TGCategory.values) {
        expect(find.text(categoryLabel(c)), findsWidgets);
      }
      // Price slider + numeric inputs
      expect(find.byType(RangeSlider), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Min'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Max'), findsOneWidget);
      // Location autocomplete + radius
      expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'City, e.g. Katowice'), findsOneWidget);
      for (final r in ['Exact', '+10 km', '+25 km', '+50 km', '+100 km']) {
        expect(find.text(r), findsOneWidget);
      }
      expect(find.byTooltip('Prices are compared on a net basis'), findsOneWidget);
      expect(find.text('Delivery'), findsWidgets);
      expect(find.text('Pickup'), findsWidgets);
      _expectNoErrors(app);
    });

    testWidgets('main area has a toolbar with grid/list toggle and a sort dropdown', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      expect(find.byTooltip('Grid view'), findsOneWidget);
      expect(find.byTooltip('List view'), findsOneWidget);
      expect(find.byType(DropdownButton<TGProductsSort>), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('verified toggle filters the results and keeps the page alive (no reload flash)', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final all = await _catalogue(tester);
      final expected = countResults(all, const TGProductsQueryState(verifiedOnly: true));

      await tester.tap(find.byType(Switch));
      await tester.pump(); // one frame after the tap
      // The page must not be re-created (that would flash the skeleton).
      expect(find.byType(TGProductCardSkeleton), findsNothing);
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(app.location, '/products?verified=1');
      expect(find.text('$expected results'), findsOneWidget);
      expect(_cards(tester).every((c) => c.product.seller.verified), isTrue);
      _expectNoErrors(app);
    });

    testWidgets('listing type, condition and category filters update the URL and the results', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final all = await _catalogue(tester);

      await tester.tap(find.text('Rent').first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(app.location, '/products?type=rent');
      expect(find.text('${countResults(all, const TGProductsQueryState(listingType: TGListingType.rent))} results'), findsOneWidget);

      await tester.tap(find.text('Used').first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(app.location, contains('condition=used'));
      expect(_cards(tester).every((c) => c.product.condition == TGCondition.used), isTrue);
      _expectNoErrors(app);
    });

    testWidgets('price: numeric inputs commit to the URL and filter the results', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final all = await _catalogue(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Min'), '1000');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '3000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFor(tester, const Duration(milliseconds: 700));

      expect(app.location, contains('min=1000'));
      expect(app.location, contains('max=3000'));
      const q = TGProductsQueryState(minPrice: 1000, maxPrice: 3000);
      expect(find.text('${countResults(all, q)} results'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('price slider thumb follows the drag (it used to stay frozen until release)', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final slider = find.byType(RangeSlider);
      final before = tester.widget<RangeSlider>(slider).values;
      final rect = tester.getRect(slider);
      // Drag the right thumb from the far right towards the left.
      final gesture = await tester.startGesture(Offset(rect.right - 12, rect.center.dy));
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      final during = tester.widget<RangeSlider>(slider).values;
      expect(during.end, lessThan(before.end));
      await gesture.up();
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, contains('max='));
      _expectNoErrors(app);
    });

    testWidgets('location: city + radius is a real distance filter', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final all = await _catalogue(tester);

      final cityField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'City, e.g. Katowice');
      await tester.enterText(cityField, 'Katowice');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, contains('city=Katowice'));
      final exact = countResults(all, const TGProductsQueryState(city: 'Katowice'));
      expect(find.text('$exact results'), findsOneWidget);

      await tester.tap(find.text('+50 km'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, contains('r=50'));
      final within50 = countResults(all, const TGProductsQueryState(city: 'Katowice', radiusKm: 50));
      expect(within50, greaterThan(exact), reason: 'Gliwice and Rybnik listings are within 50 km of Katowice');
      expect(find.text('$within50 results'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('promoted listings stay pinned at the top whatever the sort order', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');

      List<String> firstThree() => _cardIds(tester).take(3).toList();
      final initialTop = firstThree();
      expect(initialTop, hasLength(3));
      expect(_cards(tester).take(3).every((c) => c.product.isPromoted), isTrue);
      expect(find.text('Featured · Promoted'), findsOneWidget);

      for (final label in ['Price: low to high', 'Price: high to low', 'Newest', 'Longest warranty']) {
        await tester.tap(find.byType(DropdownButton<TGProductsSort>));
        await pumpFor(tester, const Duration(milliseconds: 400));
        await tester.tap(find.text(label).last);
        await pumpFor(tester, const Duration(milliseconds: 600));

        expect(firstThree(), initialTop, reason: 'promoted block changed for "$label"');
        // The promoted header is rendered above the "All listings" header.
        expect(tester.getTopLeft(find.text('Featured · Promoted')).dy, lessThan(tester.getTopLeft(find.text('All listings')).dy));
      }

      // And low->high really sorts the *organic* part ascending.
      await tester.tap(find.byType(DropdownButton<TGProductsSort>));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Price: low to high').last);
      await pumpFor(tester, const Duration(milliseconds: 600));
      final organicPrices = _cards(tester).skip(3).map((c) => productPriceNet(c.product)).whereType<int>().toList();
      expect(organicPrices, [...organicPrices]..sort());
      _expectNoErrors(app);
    });

    testWidgets('grid <-> list switch: 3 columns, then horizontal rows, with a 220 ms transition', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');

      // 3-column grid at desktop width.
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
      expect(_cards(tester).every((c) => c.layout == TGProductCardLayout.grid), isTrue);

      // The transition is configured for exactly 220 ms.
      final switcher = find.descendant(of: find.byType(AnimatedSize), matching: find.byType(AnimatedSwitcher));
      expect(tester.widget<AnimatedSwitcher>(switcher).duration, const Duration(milliseconds: 220));
      expect(tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration, const Duration(milliseconds: 220));
      expect(TGMotion.layoutSwitch, const Duration(milliseconds: 220));

      await tester.tap(find.byTooltip('List view'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110)); // half-way: both layouts alive, cross-fading
      expect(_cards(tester).any((c) => c.layout == TGProductCardLayout.grid), isTrue);
      expect(_cards(tester).any((c) => c.layout == TGProductCardLayout.list), isTrue);

      await pumpFor(tester, const Duration(milliseconds: 400)); // transition over
      expect(app.location, contains('view=list'));
      expect(_cards(tester).every((c) => c.layout == TGProductCardLayout.list), isTrue);

      // Horizontal list rows: the image sits to the left of the text.
      final firstCard = find.byType(TGProductCard).first;
      expect(tester.getSize(firstCard).width, greaterThan(tester.getSize(firstCard).height * 2));

      // And back.
      await tester.tap(find.byTooltip('Grid view'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(_cards(tester).every((c) => c.layout == TGProductCardLayout.grid), isTrue);
      _expectNoErrors(app);
    });

    testWidgets('the sidebar is sticky: it rides along while scrolling and stops above the footer', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      final heading = find.text('Filters').first;
      final before = tester.getTopLeft(heading).dy;

      await tester.drag(_verticalScrollable, const Offset(0, -1100));
      await pumpFor(tester, const Duration(milliseconds: 500));
      final after = tester.getTopLeft(heading).dy;
      // Still in the viewport, close to the top (it did not scroll away with the page).
      expect(after, inInclusiveRange(0, 160));
      expect(after, lessThan(before));

      // Scrolled to the very bottom, the panel must not overlap the footer.
      await tester.scrollUntilVisible(find.byType(TGFooter), 600, scrollable: _verticalScrollable, maxScrolls: 60);
      await pumpFor(tester, const Duration(milliseconds: 500));
      final panelBottom = tester.getRect(find.byType(TGFiltersPanel)).bottom;
      final footerTop = tester.getRect(find.byType(TGFooter)).top;
      expect(panelBottom, lessThanOrEqualTo(footerTop + 1));
      _expectNoErrors(app);
    });

    testWidgets('empty results offer a way out', (tester) async {
      final app = await pumpTgApp(tester, location: '/products?q=zzzzzz');
      expect(find.text('No results'), findsOneWidget);
      await tester.tap(find.text('Clear all filters'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/products');
      expect(_cards(tester), isNotEmpty);
      _expectNoErrors(app);
    });
  });

  // =========================================================================
  group('3. Micro-interactions', () {
    testWidgets('phone click copies the number and shows a "Number copied" toast', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      expect(find.text('Number copied'), findsNothing);

      final phone = find.text('+48 (532) 784-074').first;
      await tester.ensureVisible(phone);
      await tester.pump();
      await tester.tap(phone);
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(app.log.clipboard, ['+48 (532) 784-074']);
      expect(find.text('Number copied'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      // The toast goes away on its own.
      await pumpFor(tester, const Duration(seconds: 4));
      expect(find.text('Number copied'), findsNothing);
      _expectNoErrors(app);
    });

    testWidgets('list-view phone number is fully visible and copies on tap', (tester) async {
      final app = await pumpTgApp(tester, location: '/products?view=list');
      expect(find.text('+48 (532) 784-074'), findsWidgets);
      await _tapText(tester, '+48 (532) 784-074');
      expect(app.log.clipboard, isNotEmpty);
      expect(find.text('Number copied'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('compact list cards also show the full phone number', (tester) async {
      final app = await pumpTgApp(tester, location: '/products?view=list', size: TGSizes.phone);
      expect(find.text('+48 (532) 784-074'), findsWidgets);
      expect(find.text('Show number'), findsNothing);
      expect(find.text('Katowice'), findsWidgets);
      expect(find.text('Pickup'), findsWidgets);
      expect(find.textContaining('PrimeGastro'), findsWidgets);
      _expectNoErrors(app);
    });

    testWidgets('grid cards show power type first and a single fulfillment chip', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      expect(find.text('Electric'), findsWidgets);
      expect(find.text('Customer preference'), findsWidgets);
      expect(find.text('Pickup'), findsWidgets);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == TGAssets.pickupStore),
        findsWidgets,
      );
      _expectNoErrors(app);
    });

    for (final view in ['grid', 'list']) {
      testWidgets('card hover ($view): translateY(-4px) + turquoise glow, reset on exit', (tester) async {
        final app = await pumpTgApp(tester, location: view == 'list' ? '/products?view=list' : '/products');
        final card = find.byType(TGHoverCard).first;
        await tester.ensureVisible(card);
        await pumpFor(tester, const Duration(milliseconds: 300));

        // Idle.
        expect(_cardTransform(tester, card).getTranslation().y, 0);
        expect(_cardDecoration(tester, card).boxShadow, anyOf(isNull, isEmpty));

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        addTearDown(mouse.removePointer);
        await tester.pump();

        await mouse.moveTo(tester.getCenter(card));
        await pumpFor(tester, const Duration(milliseconds: 400));
        expect(_cardTransform(tester, card).getTranslation().y, -TGMotion.hoverLift);
        expect(TGMotion.hoverLift, 4);
        final glow = _cardDecoration(tester, card).boxShadow;
        expect(glow, isNotNull);
        expect(glow, isNotEmpty);
        // Glow is the turquoise CTA colour (alpha applied on top).
        expect(glow!.first.color.withValues(alpha: 1), TGColors.cta);

        await mouse.moveTo(const Offset(1, 1));
        await pumpFor(tester, const Duration(milliseconds: 400));
        expect(_cardTransform(tester, card).getTranslation().y, 0);
        _expectNoErrors(app);
      });
    }

    testWidgets('mobile: filters open in a 90%-height bottom sheet with a live result counter', (tester) async {
      final app = await pumpTgApp(tester, location: '/products', size: TGSizes.phone);
      final all = await _catalogue(tester);
      final total = countResults(all, const TGProductsQueryState());
      final verified = countResults(all, const TGProductsQueryState(verifiedOnly: true));

      // No sidebar on a phone: filters are behind the "Filters" button.
      expect(find.widgetWithText(TextField, 'Min'), findsNothing);
      await tester.tap(find.widgetWithText(InkWell, 'Filters').first);
      await pumpFor(tester, const Duration(milliseconds: 700));

      // Exactly 90% of the screen height.
      final sheet = find.byWidgetPredicate((w) => w is SizedBox && w.height != null && (w.height! - TGSizes.phone.height * 0.9).abs() < 0.01);
      expect(sheet, findsOneWidget);
      expect(tester.getSize(sheet).height, closeTo(TGSizes.phone.height * 0.9, 0.5));

      // Live counter: shown in the header chip and on the apply button.
      expect(find.text('Show $total results'), findsOneWidget);
      expect(find.text('$total results'), findsWidgets);

      await tester.tap(find.byType(Switch));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('Show $verified results'), findsOneWidget, reason: 'the counter must update live');
      expect(find.text('Show $total results'), findsNothing);
      // Nothing is applied until the button is pressed.
      expect(app.location, '/products');

      await tester.tap(find.text('Show $verified results'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('Show $verified results'), findsNothing, reason: 'sheet closed');
      expect(app.location, '/products?verified=1');
      expect(find.text('$verified results'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('below 1024px there is no sidebar (tablet too); at 1024px and above there is', (tester) async {
      var app = await pumpTgApp(tester, location: '/products', size: const Size(1023, 800));
      expect(find.widgetWithText(TextField, 'Min'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Filters'), findsWidgets);
      _expectNoErrors(app);

      app = await pumpTgApp(tester, location: '/products', size: const Size(1024, 800));
      expect(find.widgetWithText(TextField, 'Min'), findsOneWidget);
      _expectNoErrors(app);
    });
  });

  // =========================================================================
  group('4. Dark footer', () {
    testWidgets('has contact info, B2B categories, platform links and a map card', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await tester.scrollUntilVisible(find.byType(TGFooter), 600, scrollable: _verticalScrollable, maxScrolls: 80);
      await pumpFor(tester, const Duration(milliseconds: 300));
      final footer = find.byType(TGFooter);
      Finder inFooter(String text) => find.descendant(of: footer, matching: find.text(text));

      // Company contact info
      expect(inFooter('Twoja Gastromania'), findsOneWidget);
      expect(inFooter('ul. Example 12, Warszawa'), findsOneWidget);
      expect(inFooter('+48 000 000 000'), findsOneWidget);
      expect(inFooter('hello@twojagastromania.com'), findsOneWidget);
      expect(inFooter('Mon–Fri 09:00–18:00'), findsOneWidget);
      // B2B categories
      expect(inFooter('B2B Categories'), findsOneWidget);
      for (final c in TGCategory.values) {
        expect(inFooter(categoryLabel(c)), findsOneWidget);
      }
      // Platform links
      expect(inFooter('Platform'), findsOneWidget);
      for (final l in ['Pricing', 'For sellers', 'Help', 'Contact']) {
        expect(inFooter(l), findsOneWidget);
      }
      // Location map card
      expect(inFooter('Location'), findsOneWidget);
      expect(inFooter('Open in Maps'), findsOneWidget);

      // Dark surface from the design system.
      final bg = tester.widget<Container>(find.descendant(of: footer, matching: find.byType(Container)).first);
      expect((bg.decoration! as BoxDecoration).color, TGColors.surface);
      _expectNoErrors(app);
    });

    testWidgets('"Open in Maps" opens the map location', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await tester.scrollUntilVisible(find.text('Open in Maps'), 600, scrollable: _verticalScrollable, maxScrolls: 80);
      await tester.tap(find.text('Open in Maps'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(app.log.launchedUrls, hasLength(1));
      expect(app.log.launchedUrls.single, allOf(contains('google.com/maps'), contains('52.2297')));
      _expectNoErrors(app);
    });

    testWidgets('footer phone number copies with the same toast', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await tester.scrollUntilVisible(find.text('+48 000 000 000'), 600, scrollable: _verticalScrollable, maxScrolls: 80);
      await tester.tap(find.text('+48 000 000 000'));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(app.log.clipboard, ['+48 000 000 000']);
      expect(find.text('Number copied'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('footer B2B category links open /products?cat=...', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      await tester.scrollUntilVisible(find.byType(TGFooter), 600, scrollable: _verticalScrollable, maxScrolls: 80);
      await tester.pump(const Duration(milliseconds: 300));
      final link = find.descendant(of: find.byType(TGFooter), matching: find.text('Refrigeration Equipment'));
      await tester.tap(link);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/products?cat=refrigeration');
      _expectNoErrors(app);
    });

    testWidgets('footer "Pricing" shows the business model incl. VAT note', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await tester.scrollUntilVisible(find.text('Pricing'), 600, scrollable: _verticalScrollable, maxScrolls: 80);
      await tester.tap(find.text('Pricing'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('First 3 listings are free'), findsOneWidget);
      expect(find.text('49 PLN / 30 days per listing'), findsOneWidget);
      for (final p in ['199 PLN', '499 PLN', '899 PLN']) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.textContaining('All prices include 23% VAT'), findsOneWidget);
      _expectNoErrors(app);
    });
  });

  // =========================================================================
  group('5. Design system', () {
    test('palette matches the spec', () {
      expect(TGColors.background, const Color(0xFF252525));
      expect(TGColors.surface, const Color(0xFF1F1F1F));
      expect(TGColors.surfaceHover, const Color(0xFF2A2A2A));
      expect(TGColors.border, const Color(0xFF3A3A3A));
      expect(TGColors.cta, const Color(0xFF26E6B3));
      expect(TGColors.onCta, const Color(0xFF0E1A16));
      expect(TGColors.accent, const Color(0xFFF73887));
      expect(TGColors.verified, const Color(0xFF00E676));
      expect(TGColors.rating, const Color(0xFFFFC107));
    });

    test('radii: inputs 12px, cards/modals 16px', () {
      expect(TGRadius.input, 12);
      expect(TGRadius.card, 16);
      expect(TGRadius.modal, 16);
      final r = DarkModeTheme().designToken.radius;
      expect(r.input, 12);
      expect(r.card, 16);
      expect(r.modal, 16);
    });

    test('FlutterFlow dark theme resolves to the tokens', () {
      final t = DarkModeTheme();
      expect(t.primaryBackground, TGColors.background);
      expect(t.secondaryBackground, TGColors.surface);
      expect(t.alternate, TGColors.surfaceHover);
      expect(t.tertiary, TGColors.border);
      expect(t.primary, TGColors.cta);
      expect(t.primaryBtnText, TGColors.onCta);
      expect(t.secondary, TGColors.accent);
      expect(t.success, TGColors.verified);
      expect(t.warning, TGColors.rating);
    });

    test('stock Material widgets follow the design system', () {
      final theme = buildTGDarkTheme();
      expect(theme.scaffoldBackgroundColor, TGColors.background);
      expect(theme.colorScheme.primary, TGColors.cta);
      final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(12));
      final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(dialog.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('pages paint on #252525; cards on #1F1F1F; CTA is turquoise with dark text', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, TGColors.background);

      final cardSurface = tester.widget<DecoratedBox>(find.descendant(of: find.byType(TGHoverCard).first, matching: find.byType(DecoratedBox)).first);
      expect((cardSurface.decoration as BoxDecoration).color, TGColors.surface);

      // Primary CTA ("+ Add Product").
      final cta = tester.widget<TGButton>(find.widgetWithText(TGButton, '+ Add Product').first);
      expect(cta.variant, TGButtonVariant.primary);
      final ac = tester.widget<AnimatedContainer>(find.descendant(of: find.widgetWithText(TGButton, '+ Add Product').first, matching: find.byType(AnimatedContainer)).first);
      expect((ac.decoration! as BoxDecoration).color, TGColors.cta);
      final label = tester.widget<Text>(find.descendant(of: find.widgetWithText(TGButton, '+ Add Product').first, matching: find.text('+ Add Product')));
      expect(label.style!.color, TGColors.onCta);
      _expectNoErrors(app);
    });

    testWidgets('badges: verified = green, promoted = pink, rating stars = gold', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      // Verified seller icon on a card.
      final verifiedIcon = tester.widgetList<Icon>(find.byIcon(Icons.verified_user)).first;
      expect(verifiedIcon.color, TGColors.verified);
      // Promoted pill.
      final promoted = tester.widget<Container>(find.ancestor(of: find.text('FEATURED').first, matching: find.byType(Container)).first);
      expect((promoted.decoration! as BoxDecoration).color, TGColors.accent);
      expect(find.text('PROMO'), findsNothing);
      _expectNoErrors(app);

      // Rating stars (home "Best Sellers").
      final app2 = await pumpTgApp(tester, location: '/');
      await tester.scrollUntilVisible(find.byType(TGRatingStars).first, 600, scrollable: _verticalScrollable, maxScrolls: 80);
      final star = tester.widgetList<Icon>(find.descendant(of: find.byType(TGRatingStars).first, matching: find.byType(Icon))).first;
      expect(star.color, TGColors.rating);
      _expectNoErrors(app2);
    });
  });

  // =========================================================================
  group('6. Business model surfaces', () {
    testWidgets('account pill opens the quota sheet: "Free listings: 2 of 3 left"', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      app.auth.setScenario(TGEntitlementScenario.freeActive);
      await tester.pump();
      await tester.tap(find.text('2 free left'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('Free listings: 2 of 3 left'), findsOneWidget);
      expect(find.textContaining("They don't expire"), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('"+ Add Product" opens the listing wizard', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      await _tapText(tester, '+ Add Product');
      expect(app.location, '/add-product');
      expect(find.text('Basic info'), findsWidgets);
      expect(find.text('Review & publish'), findsWidgets);
      _expectNoErrors(app);
    });
  });
}
