import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/dashboard/listings_dashboard_widget.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('seeded catalogue keeps sold/expired rows but public filters drop them', () async {
    final all = await TGProductService.instance.getAll();
    expect(all, hasLength(18));
    expect(all.where((p) => p.id == 'p007').single.status, TGListingStatus.sold);
    expect(all.where((p) => p.id == 'p012').single.status, TGListingStatus.expired);
    final public = applyFilters(all, const TGProductsQueryState());
    expect(public.every((p) => p.isActive), isTrue);
    expect(public.map((p) => p.id), isNot(containsAll(['p007', 'p012'])));
    expect(public, hasLength(16));
  });

  test('hasExpired scenario is 3 active, 2 expired, 1 draft', () {
    final auth = FakeAuthState(isLoggedIn: true);
    expect(auth.ownedActive, hasLength(3));
    expect(auth.ownedExpired, hasLength(2));
    expect(auth.ownedListings.where((p) => p.status == TGListingStatus.draft), hasLength(1));
    expect(auth.ownedActive.where((p) => p.isExpiringSoon), hasLength(1));
    expect(auth.pillKind, TGHeaderPillKind.expiredListings);
  });

  testWidgets('expired pill opens the dashboard filter', (tester) async {
    final app = await pumpTgApp(tester, location: '/');
    await tester.tap(find.text('2 expired · Renew'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(app.location, '/dashboard/listings?filter=expired');
    expect(find.text('Expired'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('owner expired PDP shows renew CTA', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/own_f_exp1', size: TGSizes.desktop);
    expect(find.text('This is your listing'), findsOneWidget);
    expect(find.textContaining('Expired'), findsOneWidget);
    expect(find.text('Renew · 49 PLN'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('owner expired mobile puts renew directly under the inactive banner', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/own_f_exp2', size: TGSizes.phone);
    expect(find.text('This listing is no longer active'), findsOneWidget);
    expect(find.byKey(const Key('pdp-renew-inline')), findsOneWidget);
    final banner = tester.getRect(find.text('This listing is no longer active'));
    final renew = tester.getRect(find.byKey(const Key('pdp-renew-inline')));
    expect(renew.top, greaterThan(banner.bottom - 4));
    expect(renew.top - banner.bottom, lessThan(24));
    expect(find.text('This is your listing'), findsOneWidget);
    expect(find.text('Renew · 49 PLN'), findsWidgets);
    _expectNoErrors(app);
  });

  test('dashboard sort puts expired first, then fewest days left', () {
    final auth = FakeAuthState(isLoggedIn: true);
    final sorted = [...auth.ownedListings]..sort(compareDashboardListings);
    expect(sorted.map((p) => p.id).toList(), [
      'own_f_exp2',
      'own_f_exp1',
      'own_f1',
      'own_f2',
      'own_f3',
      'own_f_draft',
    ]);
  });

  testWidgets('my listings shows renew on expired rows and expired listings first', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings', size: TGSizes.desktop);
    expect(find.text('Renew · 49 PLN'), findsNWidgets(2));
    expect(find.byKey(const Key('dashboard-renew-own_f_exp1')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-renew-own_f_exp2')), findsOneWidget);
    final mixer = tester.getTopLeft(find.text('Mikser planetarny 20L – wygasł').first);
    final slicer = tester.getTopLeft(find.text('Krajalnica chleba – wygasła').first);
    final pizza = tester.getTopLeft(find.textContaining('Piec pizza 4 pizze').first);
    expect(mixer.dy, lessThan(slicer.dy));
    expect(slicer.dy, lessThan(pizza.dy));
    _expectNoErrors(app);
  });

  testWidgets('my listings has an add-product CTA that opens the wizard', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings', size: TGSizes.desktop);
    expect(find.byKey(const Key('dashboard-add-product')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-add-product')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/add-product');
    expect(find.text('Basic info'), findsWidgets);
    _expectNoErrors(app);
  });

  test('seeded listings have unique 8-digit listing numbers used in URLs', () async {
    final all = await TGProductService.instance.getAll();
    final numbers = all.map((p) => p.listingNo).whereType<String>().toList();
    expect(numbers, hasLength(18));
    expect(numbers.toSet(), hasLength(18));
    expect(numbers.every(TGListingNo.isListingNo), isTrue);
    expect(all.where((p) => p.id == 'p001').single.listingNo, '10482137');
    expect(all.first.detailPath, contains(all.first.listingNo));
  });

  test('unused free slots never expire; drafts still do not spend them', () {
    final auth = FakeAuthState(isLoggedIn: true)..setScenario(TGEntitlementScenario.freeActive);
    expect(auth.freeListingsLeft, 2);
    expect(auth.listingPlan, TGListingPlan.free);
    expect(auth.pillKind, TGHeaderPillKind.freeQuota);
    auth.upsertOwned(auth.ownedListings.first.copyWith(status: TGListingStatus.draft, listingNo: null));
    expect(auth.freeSlotsUsed, 1);
  });

  test('under_review is public unless hidden; removed is not', () {
    final auth = FakeAuthState(isLoggedIn: true)..setScenario(TGEntitlementScenario.needsAttention);
    final review = auth.ownedNeedsAttention.single;
    expect(review.isPubliclyVisible, isTrue);
    expect(review.copyWith(isHidden: true).isPubliclyVisible, isFalse);
    expect(review.copyWith(status: TGListingStatus.removed).isPubliclyVisible, isFalse);
    expect(auth.pillKind, TGHeaderPillKind.needsAttention);
  });
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
