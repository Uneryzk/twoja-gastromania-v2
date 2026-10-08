import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/add_product/add_product_draft.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await TGProductService.instance.resetToSeed();
  });

  test('Polish NIP checksum accepts 1111111111 and rejects a bad digit', () {
    expect(isValidNip('1111111111'), isTrue);
    expect(isValidNip('1111111112'), isFalse);
    expect(isValidNip('123'), isFalse);
  });

  test('review validation collects errors from every step', () {
    final auth = FakeAuthState(isLoggedIn: true)..setScenario(TGEntitlementScenario.noListings);
    final draft = AddProductDraft(auth: auth);
    expect(draft.validateStep(4), isFalse);
    expect(
      draft.fieldErrors.keys,
      containsAll(['category', 'title', 'description', 'price', 'brand', 'year', 'photos', 'contact', 'phone', 'sms', 'city']),
    );
  });

  test('drafts do not consume a free slot; first publish does', () {
    final auth = FakeAuthState(isLoggedIn: true)..setScenario(TGEntitlementScenario.noListings);
    final draft = AddProductDraft(auth: auth);
    draft.category = TGCategory.cookingEquipment;
    draft.title = 'Rational SCC 101 combi oven';
    draft.description = 'Fully working combi oven with a recent service and stainless interior ready.';
    draft.priceText = '12500';
    draft.brand = 'Rational';
    draft.yearText = '2019';
    draft.addSamplePhoto();
    draft.contactName = 'Jan Kowalski';
    draft.phoneDigits = '501234567';
    draft.phoneVerified = true;
    draft.city = 'Warszawa';

    auth.upsertOwned(draft.toProduct());
    expect(auth.freeSlotsUsed, 0);
    expect(auth.ownedListings.first.status, TGListingStatus.draft);
    expect(auth.ownedListings.first.listingNo, isNull);

    final published = auth.publishOwned(draft.toProduct());
    expect(auth.freeSlotsUsed, 1);
    expect(published.status, TGListingStatus.active);
    expect(published.listingNo, isNotNull);
    expect(published.listingNo, hasLength(8));
    expect(published.expiresAt!.difference(published.publishedAt!).inDays, 30);
    expect(published.extra['Brand'], 'Rational');
    expect(auth.listingPlan, TGListingPlan.free);
  });

  testWidgets('logged-out visit shows login then returns to the wizard', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', signedIn: false);
    expect(find.text('LOG IN'), findsWidgets);
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).first, 'demo@gastromania.pl');
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).at(1), 'password');
    await tester.tap(find.text('LOG IN').last);
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(app.auth.isLoggedIn, isTrue);
    expect(find.text('Basic info'), findsWidgets);
    expect(find.text('Listing type'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('header CTA opens /add-product with stepper and live preview', (tester) async {
    final app = await pumpTgApp(tester, location: '/');
    await tester.tap(find.text('+ Add Product').first);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/add-product');
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Add Product'), findsWidgets);
    expect(find.text('Basic info'), findsWidgets);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('save draft keeps quota; unsaved leave asks first', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product');
    app.auth.setScenario(TGEntitlementScenario.noListings);
    await tester.pump();
    await _enter(tester, const Key('wizard-title'), 'Rational SCC 101 combi oven');
    final used = app.auth.freeSlotsUsed;
    await tester.tap(find.byKey(const Key('wizard-save-draft')));
    await tester.pump();
    expect(find.text('Saved · just now'), findsOneWidget);
    expect(app.auth.freeSlotsUsed, used);
    expect(app.auth.ownedListings.first.status, TGListingStatus.draft);

    await _enter(tester, const Key('wizard-title'), 'Rational SCC 101 combi oven x');
    await tester.tap(find.text('Home').first);
    await tester.pump();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pump();
    expect(app.location, '/add-product');
    _expectNoErrors(app);
  });

  testWidgets('free publish lands on success and writes extra specs', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product');
    app.auth.setScenario(TGEntitlementScenario.noListings);
    await tester.pump();
    await _fillWizard(tester);
    expect(find.text('Publish for free'), findsOneWidget);
    expect(find.textContaining('Free listing 1/3'), findsOneWidget);
    expect(find.textContaining('Live for 30 days from publication'), findsOneWidget);
    await _tapKey(tester, const Key('wizard-next'));
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(app.location, contains('/add-product/success'));
    expect(find.text('Your listing is live'), findsOneWidget);
    expect(app.auth.freeSlotsUsed, 1);
    expect(find.text('You have 2 free listings left.'), findsOneWidget);
    final live = app.auth.ownedActive.single;
    expect(live.status, TGListingStatus.active);
    expect(live.listingNo, isNotNull);
    expect(live.extra['Brand'], 'Rational');
    expect(live.city, 'Warszawa');

    expect((await TGProductService.instance.getById(live.id))!.extra['Brand'], 'Rational');
    app.router.go(live.detailPath);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(app.location, live.detailPath);
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Show all specs')).onPressed?.call();
    await tester.pump();
    expect(find.text('Brand'), findsWidgets);
    expect(find.text('Rational'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('paid plan continues to checkout instead of publishing', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product');
    expect(app.auth.listingPlan, TGListingPlan.paid);
    await _fillWizard(tester);
    expect(find.textContaining('Continue to payment'), findsOneWidget);
    await _tapKey(tester, const Key('wizard-next'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/add-product/checkout');
    expect(find.text('Checkout'), findsWidgets);
    expect(find.text('Order summary'), findsOneWidget);
    expect(app.auth.ownedListings.first.status, TGListingStatus.paymentPending);
    expect(app.auth.ownedListings.first.listingNo, hasLength(8));
    _expectNoErrors(app);
  });

  testWidgets('full store quota sends the seller to plans', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product');
    app.auth.setScenario(TGEntitlementScenario.storeSubscriber);
    app.auth.storeActiveUsed = 15;
    await tester.pump();
    await _fillWizard(tester);
    expect(find.text('Upgrade plan'), findsOneWidget);
    await _tapKey(tester, const Key('wizard-next'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/plans');
    expect(find.text('Store plans'), findsWidgets);
    _expectNoErrors(app);
  });
}

Future<void> _fillWizard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('wizard-cat-cookingEquipment')));
  await tester.pump();
  await _enter(tester, const Key('wizard-title'), 'Rational SCC 101 combi oven');
  await _enter(
    tester,
    const Key('wizard-description'),
    'Fully working combi oven with a recent service and stainless interior ready.',
  );
  await _enter(tester, const Key('wizard-price'), '12500');
  await _tapKey(tester, const Key('wizard-next'));

  await _enter(tester, const Key('wizard-year'), '2019');
  await _enter(tester, const Key('wizard-brand'), 'Rational');
  await _tapKey(tester, const Key('wizard-next'));

  await _tapKey(tester, const Key('wizard-add-photo'));
  await _tapKey(tester, const Key('wizard-next'));

  await _enter(tester, const Key('wizard-contact'), 'Jan Kowalski');
  await _enter(tester, const Key('wizard-phone'), '501234567');
  await _enter(tester, const Key('wizard-sms'), '123456');
  await _tapKey(tester, const Key('wizard-verify'));
  await _enter(tester, const Key('wizard-city'), 'Warszawa');
  await _tapKey(tester, const Key('wizard-next'));
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final finder = find.byKey(key);
  final widget = tester.widget(finder);
  if (widget is TGButton) {
    widget.onPressed?.call();
  } else {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }
  await tester.pump();
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
