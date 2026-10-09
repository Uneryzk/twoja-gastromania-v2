import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    TGSellerProfileService.instance.reset();
  });

  test('resolves numeric id and keeps slug decorative', () {
    final s = TGSellerProfileService.instance;
    expect(s.resolve('2931-technica')?.name, 'Technica');
    expect(s.resolve('2931-anything')?.publicId, 2931);
    expect(s.resolve('seller_primegastro')?.slug, 'primegastro');
    expect(s.resolve('1048-primegastro')?.path, '/seller/1048-primegastro');
    expect(s.resolve('6621-anna-p')?.isPrivate, isTrue);
    expect(s.resolve('7703-oldkitchen')?.status, TGStoreStatus.inactive);
    expect(s.resolve('8804-nordgastro')?.status, TGStoreStatus.suspended);
    expect(s.resolve('missing'), isNull);
  });

  testWidgets('Technica store shows identity, full phone and products', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica');
    expect(find.text('Technica'), findsWidgets);
    expect(find.text('+48 (532) 784-074'), findsWidgets);
    expect(find.text('Call now'), findsWidgets);
    expect(find.textContaining('Active Products'), findsOneWidget);
    expect(TGAnalytics.has('store_view'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('Gastrosilesia has quote CTA, custom orders and about tab', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/1847-gastrosilesia');
    expect(find.text('Gastrosilesia.pl'), findsWidgets);
    expect(find.text('Request a quote'), findsOneWidget);
    expect(find.text('Custom orders'), findsOneWidget);
    expect(find.text('About Business'), findsOneWidget);
    await tester.tap(find.text('About Business'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('What we offer'), findsOneWidget);
    expect(find.textContaining('References'), findsOneWidget);
    expect(app.location, contains('tab=about'));
    expect(TGAnalytics.has('store_tab_change'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('EK hides empty About tab', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/4102-ek');
    expect(find.text('EK'), findsWidgets);
    expect(find.text('About Business'), findsNothing);
    expect(find.textContaining('Reviews'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('private seller has listings and reviews tabs without About', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/6621-anna-p');
    expect(find.text('Anna P.'), findsWidgets);
    expect(find.text('Private seller'), findsOneWidget);
    expect(find.text('+48 (532) 784-074'), findsWidgets);
    expect(find.text('Active listings'), findsWidgets);
    expect(find.textContaining('Reviews'), findsWidgets);
    expect(find.text('About Business'), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('inactive store hides phone and listings', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/7703-oldkitchen');
    expect(find.text('This store is currently inactive'), findsOneWidget);
    expect(find.text('+48 (532) 784-074'), findsNothing);
    expect(find.text('Similar stores'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('suspended seller is unavailable', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/8804-nordgastro');
    expect(find.text("This seller isn't available"), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('unknown seller shows 404', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/9999-nope');
    expect(find.text('We could not find this seller'), findsOneWidget);
    expect(find.text('Back to search'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('admin bar can act as seller', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/4102-ek');
    app.auth.setRole(TGUserRole.admin);
    await tester.pump();
    expect(find.text('Edit Seller Profile (Admin)'), findsOneWidget);
    await tester.tap(find.text('Act as Seller'));
    await tester.pump();
    expect(app.auth.userId, 'seller_ek');
    expect(find.textContaining('Complete your store setup'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('legacy seller key still opens PrimeGastro', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/seller_primegastro');
    expect(find.text('PrimeGastro'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });
}
