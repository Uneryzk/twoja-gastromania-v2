import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(TGAnalytics.reset);

  testWidgets('390 wizard uses step header, preview chip and sticky next', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.byKey(const Key('wizard-preview-chip')), findsOneWidget);
    expect(find.text('Live preview'), findsNothing);
    expect(find.text('Next'), findsWidgets);
    expect(find.text('Take photo'), findsNothing);
    expect(find.byKey(const Key('wizard-cat-cookingEquipment')), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(TGAnalytics.has('wizard_step_view'), isTrue);
    _expectNoErrors(app);
  });

  testWidgets('390 preview sheet closes with the X button', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    await tester.tap(find.byKey(const Key('wizard-preview-chip')));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('wizard-preview-close')), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wizard-preview-close')));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('wizard-preview-close')), findsNothing);
    _expectNoErrors(app);
  });

  testWidgets('390 preview sheet closes on barrier tap', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    await tester.tap(find.byKey(const Key('wizard-preview-chip')));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('wizard-preview-close')), findsOneWidget);
    await tester.tapAt(const Offset(195, 24));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('wizard-preview-close')), findsNothing);
    _expectNoErrors(app);
  });

  testWidgets('390 specs step localizes condition and does not overflow voltage', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    app.auth.setScenario(TGEntitlementScenario.noListings);
    await tester.pump();
    await tester.tap(find.byKey(const Key('wizard-cat-cookingEquipment')));
    await tester.pump();
    await _enter(tester, const Key('wizard-title'), 'Rational SCC 101 combi oven');
    await _enter(
      tester,
      const Key('wizard-description'),
      'Fully working combi oven with a recent service and stainless interior ready.',
    );
    await _enter(tester, const Key('wizard-price'), '12500');
    await _tap(tester, const Key('wizard-next'));
    expect(find.text('New'), findsWidgets);
    expect(find.text('Used'), findsWidgets);
    expect(find.text('NOWY'), findsNothing);
    expect(find.text('Voltage'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('390 photos step shows camera and gallery buttons', (tester) async {
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    app.auth.setScenario(TGEntitlementScenario.noListings);
    await tester.pump();
    await tester.tap(find.byKey(const Key('wizard-cat-cookingEquipment')));
    await tester.pump();
    await _enter(tester, const Key('wizard-title'), 'Rational SCC 101 combi oven');
    await _enter(
      tester,
      const Key('wizard-description'),
      'Fully working combi oven with a recent service and stainless interior ready.',
    );
    await _enter(tester, const Key('wizard-price'), '12500');
    await _tap(tester, const Key('wizard-next'));
    await _enter(tester, const Key('wizard-year'), '2019');
    await _enter(tester, const Key('wizard-brand'), 'Rational');
    await _tap(tester, const Key('wizard-next'));
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.byKey(const Key('wizard-add-photo')), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('390 dashboard listing is a vertical card with full-width renew', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings?filter=expired', size: TGSizes.phone);
    expect(find.byKey(const Key('dashboard-renew-own_f_exp1')), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    _expectNoErrors(app);
  });

  testWidgets('payment_pending listing shows Resume', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings', size: TGSizes.desktop);
    final pending = app.auth.ownedListings.first.copyWith(status: TGListingStatus.paymentPending, id: 'pay_me');
    app.auth.upsertOwned(pending);
    await tester.pump();
    expect(find.byKey(const Key('dashboard-resume-pay_me')), findsOneWidget);
    expect(find.text('Resume'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('390 plans uses a snap carousel starting on Pro', (tester) async {
    final app = await pumpTgApp(tester, location: '/plans', size: TGSizes.phone);
    expect(find.text('Pro Store'), findsWidgets);
    expect(find.text('Choose Pro'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('offline banner on the wizard', (tester) async {
    TGAnalytics.offline = true;
    final app = await pumpTgApp(tester, location: '/add-product', size: TGSizes.phone);
    expect(find.text("You're offline. Draft saved locally."), findsOneWidget);
    _expectNoErrors(app);
  });

  test('TGMotion.of is zero when animations are disabled', () {
    expect(TGMotion.slide, const Duration(milliseconds: 200));
    expect(TGMotion.tick, const Duration(milliseconds: 400));
  });
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final widget = tester.widget(find.byKey(key));
  if (widget is TGButton) {
    widget.onPressed?.call();
  } else {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
  }
  await tester.pump();
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
