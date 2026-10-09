import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/admin/admin_target_pages.dart';
import 'package:twoja_gastromania/seller/seller_profile_widget.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/seller/write_review_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    TGSellerProfileService.instance.reset();
    DealService.instance.reset();
    ModerationService.instance.reset();
  });

  test('seeded averages match store records from counted reviews', () {
    final d = DealService.instance..ensureSeeded();
    expect(d.countedReviewsFor('seller_technica'), hasLength(28));
    expect(d.averageFor('seller_technica'), closeTo(4.0, 0.05));
    expect(d.countedReviewsFor('seller_gastropl'), hasLength(24));
    expect(d.averageFor('seller_gastropl'), closeTo(4.5, 0.05));
    expect(d.countedReviewsFor('seller_ek'), hasLength(10));
    expect(d.averageFor('seller_ek'), closeTo(3.5, 0.05));
    expect(d.countedReviewsFor('seller_rm'), hasLength(30));
    expect(d.averageFor('seller_rm'), closeTo(4.5, 0.05));
    expect(d.countedReviewsFor('seller_primegastro'), hasLength(10));
    expect(d.averageFor('seller_primegastro'), closeTo(3.5, 0.05));
    expect(d.countedReviewsFor('seller_gastrolab'), hasLength(2));
    expect(d.countedReviewsFor('seller_mateusz'), hasLength(2));
    expect(DealService.instance.deals, hasLength(18));
    final tech = TGSellerProfileService.instance.bySellerKey('seller_technica')!;
    expect(tech.reviewsCount, 28);
    expect(tech.rating, closeTo(4.0, 0.05));
  });

  test('mock includes 3 seller reports and 4 review reports', () {
    final mod = ModerationService.instance..ensureSeeded();
    expect(mod.reports.where((r) => r.target == TGReportTarget.seller), hasLength(3));
    expect(mod.reports.where((r) => r.target == TGReportTarget.review), hasLength(4));
  });

  testWidgets('Technica reviews tab shows score, 28 reviews and write CTA', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica?tab=reviews', size: TGSizes.desktop);
    expect(find.text('4.0'), findsWidgets);
    expect(find.text('28 reviews'), findsWidgets);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text('How reviews work'), findsOneWidget);
    expect(find.text('Marek K.'), findsWidgets);
    expect(find.textContaining('Reply from Technica'), findsWidgets);
    expect(find.textContaining('Confirmed deal'), findsWidgets);
    expect(TGAnalytics.has('store_view'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('new store shows not enough reviews and New', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/9901-gastrolab?tab=reviews', size: TGSizes.desktop);
    expect(find.text('Not enough reviews yet'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('write review requires login then publishes as awaiting', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica?tab=reviews', size: TGSizes.desktop, signedIn: false);
    final ctx = tester.element(find.byType(SellerProfilePageWidget));
    final store = TGSellerProfileService.instance.bySellerKey('seller_technica')!;
    showWriteReviewFlow(ctx, store);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(TGAnalytics.has('review_write_open'), isTrue);
    expect(find.text('Log in to write a review.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(app.auth.isLoggedIn, isTrue);
    app.auth.actAsBuyer(
      const BuyerDevPick(
        userId: 'buyer_kasia',
        label: 'Buyer (Kasia)',
        displayName: 'Kasia M.',
        phoneVerified: true,
        initials: 'KM',
      ),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('review-listing-no')), '40927364');
    await tester.pump();
    await tester.tap(find.byKey(const Key('review-star-5')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('review-text')), 'Collected the warewasher in Gliwice and it matches the listing photos exactly.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('review-honest')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('review-submit')));
    await tester.pump();
    expect(find.textContaining('Awaiting seller'), findsWidgets);
    expect(TGAnalytics.has('review_submit'), isTrue);
    expect(DealService.instance.countedReviewsFor('seller_technica'), hasLength(28));
    expect(DealService.instance.publicReviewsFor('seller_technica').where((r) => r.state == TGPurchaseReviewState.awaitingSeller), isNotEmpty);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  test('cannot review own store', () {
    final auth = FakeAuthState(isLoggedIn: true)..actAsSeller('seller_technica');
    final store = TGSellerProfileService.instance.bySellerKey('seller_technica')!;
    expect(storeIsOwner(auth, store), isTrue);
  });

  testWidgets('report seller opens existing modal with seller reasons', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica', size: TGSizes.desktop);
    await tester.tap(find.byKey(const Key('report-seller-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Report seller').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Fake store or impersonation'), findsOneWidget);
    expect(find.text('Fraud or scam'), findsOneWidget);
    expect(find.text('Suspected fraud or scam'), findsNothing);
    expect(find.text('Prohibited or illegal activity'), findsOneWidget);
    expect(TGAnalytics.has('seller_report_open'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('owner does not see report seller', (tester) async {
    final app = await pumpTgApp(tester, location: '/seller/2931-technica', size: TGSizes.desktop);
    app.auth.actAsSeller('seller_technica');
    await tester.pump();
    expect(find.byKey(const Key('report-seller-menu')), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('admin queue shows Target column', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: const Size(1280, 900));
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Seller'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Fake store'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty);
  });

  testWidgets('admin review case shows remove action', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/r/R-2026-0002', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(app.location, '/admin/r/R-2026-0002');
    expect(find.byKey(const Key('admin-403')), findsNothing);
    expect(find.byType(AdminReviewCasePage), findsOneWidget);
    expect(find.byKey(const Key('admin-remove-review')), findsOneWidget);
    expect(find.textContaining('Marek K.'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  test('removing a review recalculates the store average', () {
    final svc = DealService.instance..ensureSeeded();
    expect(svc.countedReviewsFor('seller_technica'), hasLength(28));
    svc.setReviewState('R-2026-0002', TGPurchaseReviewState.removed, recordUndo: true);
    expect(svc.countedReviewsFor('seller_technica'), hasLength(27));
    expect(TGSellerProfileService.instance.bySellerKey('seller_technica')!.reviewsCount, 27);
    svc.undoReviewState('R-2026-0002');
    expect(svc.countedReviewsFor('seller_technica'), hasLength(28));
  });
}
