import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await TGProductService.instance.resetToSeed();
  });

  test('BLIK mock codes and Luhn', () {
    expect(resolveBlik('777123'), TGBlikOutcome.success);
    expect(resolveBlik('000000'), TGBlikOutcome.incorrect);
    expect(resolveBlik('111111'), TGBlikOutcome.declined);
    expect(resolveBlik('222222'), TGBlikOutcome.noConfirmation);
    expect(luhnValid('4111111111111111'), isTrue);
    expect(luhnValid('4111111111111112'), isFalse);
  });

  test('store prepaid math', () {
    expect(TGPricing.storeSixMonths(199), closeTo(1074.6, 0.01));
    expect(TGPricing.storeYearly(199), 1990);
    expect(TGPricing.storeYearlyMonthlyEq(499), closeTo(415.83, 0.01));
  });

  test('renewOwned sets paid + 30 days; early adds to current end', () {
    final auth = FakeAuthState(isLoggedIn: true);
    final now = DateTime.now();
    final expired = auth.renewOwned('own_f_exp1');
    expect(expired.status, TGListingStatus.active);
    expect(expired.source, TGListingSource.paid);
    expect(expired.expiresAt!.difference(now).inDays, 30);

    auth.setScenario(TGEntitlementScenario.hasExpired);
    final early = auth.ownedListings.where((p) => p.id == 'own_f1').single;
    final left = early.daysUntilExpiry();
    final renewed = auth.renewOwned('own_f1', early: true);
    expect(renewed.expiresAt!.difference(now).inDays, greaterThanOrEqualTo(left + 29));
  });

  testWidgets('paid checkout with BLIK 777 publishes the listing', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product/checkout');
    final pending = app.auth.ownedListings.first.copyWith(status: TGListingStatus.paymentPending, id: 'pay_me');
    app.auth.upsertOwned(pending);
    app.auth.beginCheckout(TGCheckoutCart.listing(listingId: 'pay_me', listingFee: 49, promoteFee: 39, promoteDays: 14));
    await tester.pump();
    expect(find.text('Order summary'), findsOneWidget);
    expect(find.textContaining('88'), findsWidgets);
    await tester.enterText(find.byKey(const Key('payment-blik-0')), '777123');
    await tester.pump();
    tester.widget<InkWell>(find.byKey(const Key('payment-terms'))).onTap?.call();
    await tester.pump();
    tester.widget<TGButton>(find.byKey(const Key('payment-pay'))).onPressed?.call();
    await pumpFor(tester, const Duration(milliseconds: 1600));
    expect(app.location, contains('/add-product/success'));
    expect(app.auth.ownedListings.where((p) => p.id == 'pay_me').single.status, TGListingStatus.active);
    _expectNoErrors(app);
  });

  testWidgets('plans page Choose Basic opens checkout', (tester) async {
    final app = await pumpTgApp(tester, location: '/plans');
    expect(find.text('Basic Store'), findsOneWidget);
    expect(find.text('Pro Store'), findsOneWidget);
    await tester.tap(find.text('Choose Basic'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(app.location, '/add-product/checkout');
    expect(app.auth.checkoutCart?.kind, TGCheckoutKind.store);
    _expectNoErrors(app);
  });

  testWidgets('dashboard renew sheet opens from the expired row', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings?filter=expired', size: TGSizes.desktop);
    await tester.tap(find.byKey(const Key('dashboard-renew-own_f_exp1')));
    await tester.pump();
    expect(find.textContaining('Renew · 49 PLN'), findsWidgets);
    expect(find.text('BLIK'), findsWidgets);
    expect(find.text('Przelewy24'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Other payment methods'), findsNothing);
    _expectNoErrors(app);
  });
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
