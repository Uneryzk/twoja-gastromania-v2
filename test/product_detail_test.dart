import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/product_detail/product_detail_widget.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(TGAnalytics.clear);

  testWidgets('390px shows gallery counter, always-visible phone and Call/Message bar', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.phone);
    expect(find.byType(ProductDetailPageWidget), findsOneWidget);
    expect(find.textContaining('/'), findsWidgets); // 1 / N counter
    expect(find.text('+48 (532) 784-074'), findsWidgets);
    expect(find.textContaining('Call'), findsWidgets);
    expect(find.text('Message'), findsWidgets);
    expect(find.text('Show number'), findsNothing);
    _expectNoErrors(app);
  });

  testWidgets('<1024px is a single column (no desktop contact panel width)', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: const Size(1023, 900));
    expect(find.text('Location & delivery'), findsOneWidget);
    expect(find.text('Safety tips'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('desktop shows NETTO tooltip, counterpart price and thumbnails', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    expect(find.byTooltip('Net amount, excluding 23% VAT'), findsOneWidget);
    expect(find.textContaining('brutto'), findsWidgets);
    expect(find.text('Similar listings'), findsOneWidget);
    expect(find.text('More from this seller'), findsOneWidget);
    expect(find.text("Can't find it? Send a Special Order"), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('report listing sits under the contact panel', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    expect(find.byKey(const Key('pdp-report-listing')), findsOneWidget);
    expect(find.text('Report listing'), findsOneWidget);
    final report = tester.getRect(find.byKey(const Key('pdp-report-listing')));
    final message = tester.getRect(find.text('Message').first);
    expect(report.top, greaterThan(message.bottom - 8));
    expect(report.left, greaterThan(700));
    _expectNoErrors(app);
  });

  testWidgets('phone report listing sits under the seller block', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.phone);
    expect(find.text('Report listing'), findsWidgets);
    final report = tester.getRect(find.byKey(const Key('pdp-report-listing')));
    final phone = tester.getRect(find.text('+48 (532) 784-074').first);
    expect(report.top, greaterThan(phone.bottom - 8));
    _expectNoErrors(app);
  });

  testWidgets('similar and more-from-seller cards show city, fulfillment and seller name', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    expect(find.textContaining('GastroPL Outlet'), findsWidgets);
    expect(find.textContaining('PrimeGastro'), findsWidgets);
    expect(find.text('Gliwice'), findsWidgets);
    expect(find.text('Pickup'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    _expectNoErrors(app);
  });

  testWidgets('inactive listing shows banner and disables Call', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p007', size: TGSizes.phone);
    expect(find.text('This listing is no longer active'), findsOneWidget);
    expect(find.byKey(const Key('pdp-noindex')), findsOneWidget);
    expect(find.textContaining('Call  +48'), findsNothing);
    expect(find.text('Similar listings'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('404 uses search recovery', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/does-not-exist', size: TGSizes.phone);
    expect(find.text('Product not found'), findsOneWidget);
    expect(find.text('Back to search'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('store subscriber sees owner chrome on GastroPL listings', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p002', size: TGSizes.desktop);
    app.auth.setScenario(TGEntitlementScenario.storeSubscriber);
    await tester.pumpAndSettle();
    expect(find.text('This is your listing'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Promote'), findsOneWidget);
    expect(find.text('Renew'), findsNothing);
    expect(find.text('Report listing'), findsNothing);
    _expectNoErrors(app);
  });

  testWidgets('Call tracks call_click and launches tel:', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.phone);
    await tester.ensureVisible(find.textContaining('Call').first);
    await tester.tap(find.textContaining('Call').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(TGAnalytics.events.any((e) => e.$1 == 'call_click'), isTrue);
    expect(app.log.launchedUrls.any((u) => u.startsWith('tel:')), isTrue);
    _expectNoErrors(app);
  });

  testWidgets('Message sheet opens with quick replies and Send', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.phone);
    await tester.tap(find.text('Message').first);
    await tester.pumpAndSettle();
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Is this still available?'), findsOneWidget);
    _expectNoErrors(app);
  });

  testWidgets('specifications accordion reveals remaining rows', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    for (var i = 0; i < 16; i++) {
      final rect = tester.getRect(find.text('Show all specs'));
      if (rect.top >= 80 && rect.bottom <= 860) break;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
      await tester.pump();
    }
    await tester.tap(find.text('Show all specs'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsWidgets);
    _expectNoErrors(app);
  });
}

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
