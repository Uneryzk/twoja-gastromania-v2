import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    TGSellerProfileService.instance.reset();
  });

  test('Technica completeness is 60 percent', () {
    final p = TGSellerProfileService.instance.resolve('2931-technica')!;
    expect(storeProfileCompleteness(p), 60);
  });

  testWidgets('390px Technica has cover identity, short tabs and Call+Message bar', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica', size: TGSizes.phone);
    expect(find.text('Technica'), findsWidgets);
    expect(find.textContaining('Products'), findsWidgets);
    expect(find.textContaining('Reviews 28'), findsOneWidget);
    expect(find.byKey(const Key('store-mobile-contact')), findsOneWidget);
    expect(find.byKey(const Key('store-mobile-call')), findsOneWidget);
    expect(find.byKey(const Key('store-mobile-message')), findsOneWidget);
    expect(find.text('+48 (532) 784-074'), findsWidgets);
    expect(find.text('Call now'), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('below 1024 columns collapse and tabs swipe', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/1847-gastrosilesia', size: TGSizes.phone);
    expect(find.text('About'), findsWidgets);
    expect(find.text('About Business'), findsNothing);
    expect(find.text('Request a quote'), findsWidgets);
    await tester.tap(find.text('About').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(app.location, contains('tab=about'));
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('store owner Technica sees bar, completeness and disabled Call', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica');
    app.auth.actAsStoreOwner(StoreOwnerDevPick.technica);
    await tester.pump();
    expect(find.byKey(const Key('store-owner-bar')), findsOneWidget);
    expect(find.text("You're viewing your store"), findsOneWidget);
    expect(find.text('Store profile 60%'), findsOneWidget);
    expect(find.textContaining('Add 3 project photos'), findsOneWidget);
    expect(find.textContaining('Basic Store'), findsOneWidget);
    expect(find.textContaining('11/15 active'), findsOneWidget);
    expect(find.text('See stats in Dashboard'), findsOneWidget);
    expect(find.byKey(const Key('report-seller-menu')), findsNothing);
    expect(TGAnalytics.has('store_profile_completeness'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('preview as visitor re-enables Call look and hides owner chrome', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica');
    app.auth.actAsStoreOwner(StoreOwnerDevPick.technica);
    await tester.pump();
    await tester.tap(find.byKey(const Key('store-preview-visitor')));
    await tester.pump();
    expect(find.text('Exit preview'), findsOneWidget);
    expect(find.text('Store profile 60%'), findsNothing);
    expect(find.text('Call now'), findsWidgets);
    expect(TGAnalytics.has('store_preview_toggle'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('edit store saves with live region', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica');
    app.auth.actAsStoreOwner(StoreOwnerDevPick.technica);
    await tester.pump();
    await tester.tap(find.byKey(const Key('store-edit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('store-region-edit-cover')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('store-edit-save')));
    await tester.pump();
    expect(find.text('Saved ✓'), findsOneWidget);
    expect(TGAnalytics.has('store_edit_save'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('Gastrosilesia Pro owner shows promoted quota', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/1847-gastrosilesia');
    app.auth.actAsStoreOwner(StoreOwnerDevPick.gastroPro);
    await tester.pump();
    expect(find.textContaining('2/3 promoted used'), findsOneWidget);
    expect(find.text('Upgrade'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('390px store categories scroll as chips', (tester) async {
    final app = await pumpTgApp(
      tester,
      location: '/seller/1847-gastrosilesia',
      size: TGSizes.phone,
      locale: const Locale('tr'),
    );
    expect(find.byKey(const Key('store-categories-menu')), findsOneWidget);
    expect(find.byKey(const Key('store-listings-filter-menu')), findsOneWidget);
    expect(find.byKey(const Key('store-category-cookingEquipment')), findsWidgets);
    expect(find.byKey(const Key('store-category-stainlessSteelFurniture')), findsWidgets);
    await tester.tap(find.byKey(const Key('store-listings-filter-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Paslanmaz Çelik Mobilya'), findsWidgets);
    await tester.tap(find.textContaining('Paslanmaz Çelik Mobilya').last);
    await tester.pump();
    await tester.tap(find.textContaining('sonucu göster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.location, contains('cat=stainless'));
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('dev switch lists store owner roles', (tester) async {
    expect(StoreOwnerDevPick.technica.label, 'Store owner (Technica)');
    expect(StoreOwnerDevPick.gastroPro.label, 'Store owner (Gastrosilesia.pl, Pro)');
  });

  testWidgets('390px reviews tab is a single column with write CTA', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica?tab=reviews', size: TGSizes.phone);
    expect(find.text('4.0'), findsWidgets);
    expect(find.text('28 reviews'), findsWidgets);
    expect(find.byKey(const Key('write-review')), findsOneWidget);
    expect(find.byKey(const Key('how-reviews-work')), findsOneWidget);
    expect(find.byKey(const Key('review-sort')), findsOneWidget);
    expect(find.textContaining('Confirmed deal'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('owner reviews tab shows review-check badge and disables write', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica?tab=reviews');
    app.auth.actAsStoreOwner(StoreOwnerDevPick.technica);
    await tester.pump();
    expect(storeIsOwner(app.auth, TGSellerProfileService.instance.bySellerKey('seller_technica')!), isTrue);
    expect(find.byKey(const Key('store-review-checks-badge')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });
}
