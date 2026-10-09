import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    DealService.instance.reset();
  });

  test('seeds eight deals and conversations on the owner listings', () {
    final d = DealService.instance;
    expect(d.deals.map((e) => e.id), containsAll(['D-2026-000123', 'D-2026-000130']));
    expect(d.deals, hasLength(18));
    expect(d.reviews, hasLength(10));
    expect(d.reviews.map((r) => r.state).toSet(), containsAll(TGPurchaseReviewState.values));
    expect(d.objections, hasLength(2));
    expect(d.evidence.any((e) => e.type == TGEvidenceType.liveVideo), isTrue);
    expect(d.conversationsFor('38705142'), hasLength(3));
    expect(d.deals.map((e) => e.status).toSet(), containsAll([
      TGDealStatus.pendingBuyer,
      TGDealStatus.pendingSeller,
      TGDealStatus.confirmed,
      TGDealStatus.declinedByBuyer,
      TGDealStatus.declinedBySeller,
      TGDealStatus.expired,
      TGDealStatus.inModeration,
      TGDealStatus.approvedByModerator,
    ]));
  });

  test('lookup always returns the same copy and never leaks a miss', () {
    final d = DealService.instance;
    expect(d.lookupNeutral('seller_tg', type: TGDealIdentifierType.phone, query: '+48532784074'), kNeutralMatchCopy);
    expect(d.lookupNeutral('seller_tg', type: TGDealIdentifierType.email, query: 'nobody@mail.com'), kNeutralMatchCopy);
    expect(d.matchDirectory(type: TGDealIdentifierType.phone, query: '+48532784074')?.userId, 'buyer_marek');
    expect(d.matchDirectory(type: TGDealIdentifierType.email, query: 'nobody@mail.com'), isNull);
  });

  test('advance +14 days expires a pending request', () {
    TGClock.advance(const Duration(days: 14));
    DealService.instance.onClockAdvanced();
    final deal = DealService.instance.byId('D-2026-000123')!;
    expect(deal.status, TGDealStatus.expired);
    expect(TGAnalytics.has('deal_expired'), isTrue);
  });

  testWidgets('mark as sold removes the listing from public pages', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings?sold=own_f1', signedIn: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(TGAnalytics.has('sold_flow_open'), isTrue);
    await tester.tap(find.byKey(const Key('sold-no')));
    await tester.pump();
    await tester.tap(find.text('Mark as sold').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Listing marked as sold'), findsWidgets);
    final listing = app.auth.ownedListings.firstWhere((p) => p.id == 'own_f1');
    expect(listing.status, TGListingStatus.sold);
    expect(listing.isPubliclyVisible, isFalse);
    expect(visibleProducts(app.auth.ownedListings).where((p) => p.id == 'own_f1'), isEmpty);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('buyer Marek confirms a pending deal', (tester) async {
    final app = await pumpTgApp(tester, location: '/', signedIn: true);
    app.auth.actAsBuyer(BuyerDevPick.marek);
    app.router.go('/account/deals/D-2026-000123?confirm=1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('says this item was sold to you'), findsOneWidget);
    await tester.tap(find.text('Yes, I bought it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Deal confirmed'), findsOneWidget);
    expect(DealService.instance.byId('D-2026-000123')!.status, TGDealStatus.confirmed);
    expect(TGAnalytics.has('deal_buyer_confirmed'), isTrue);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('Anna must enter the mock SMS code before confirming', (tester) async {
    final app = await pumpTgApp(tester, location: '/', signedIn: true);
    DealService.instance.byId('D-2026-000123')!.buyerId = BuyerDevPick.anna.userId;
    app.auth.actAsBuyer(BuyerDevPick.anna);
    app.router.go('/account/deals/D-2026-000123?confirm=1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Verify your phone'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sms-phone')), '600111222');
    await tester.tap(find.byKey(const Key('confirm-yes')));
    await tester.pump();
    expect(find.textContaining('Code sent'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sms-code')), '123456');
    await tester.tap(find.byKey(const Key('confirm-yes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-yes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Deal confirmed'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('confirm deep link is blocked for the wrong account', (tester) async {
    final app = await pumpTgApp(tester, location: '/account/deals/D-2026-000123?confirm=1', signedIn: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('This request is for another account'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('seller deal filters collapse to a hamburger on a phone', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/deals', signedIn: true, size: TGSizes.phone);
    expect(find.byKey(const Key('deals-filter-menu')), findsOneWidget);
    expect(find.byKey(const Key('filter-chip-waiting')), findsNothing);
    await tester.tap(find.byKey(const Key('deals-filter-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Waiting for buyer'), findsWidgets);
    await tester.tap(find.text('Waiting for buyer').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.location, contains('tab=waiting'));
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('seller deals page lists status chips', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/deals', signedIn: true);
    expect(find.text('WAITING FOR BUYER'), findsWidgets);
    expect(find.text('CONFIRMED'), findsWidgets);
    expect(find.text('Deals'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('account lookup always shows the same copy', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings?sold=own_f1', signedIn: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('sold-yes')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sold-continue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sold-tab-lookup')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sold-lookup')), 'nobody@mail.com');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sold-continue')));
    await tester.pump();
    expect(find.text(kNeutralMatchCopy), findsOneWidget);
    expect(DealService.instance.byId('D-2026-000131'), isNull);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('notification copy follows the Polish locale', (tester) async {
    final app = await pumpTgApp(tester, location: '/', signedIn: true, locale: const Locale('pl'));
    app.auth.actAsBuyer(BuyerDevPick.marek);
    NotificationService.instance.add(
      userId: BuyerDevPick.marek.userId,
      type: 'deal_reminder',
      dealId: 'D-2026-000123',
      title: 'Reminder: confirm this purchase',
      body: 'Piec pizza 4 pizze – 3 dni do końca',
      params: {'title': 'Piec pizza 4 pizze – 3 dni do końca'},
    );
    NotificationService.instance.add(
      userId: BuyerDevPick.marek.userId,
      type: 'deal_review_requested',
      dealId: 'D-2026-000125',
      title: 'Please review this seller',
      body: 'Zmywarka podszafkowa',
      params: {'title': 'Zmywarka podszafkowa'},
    );
    app.router.go('/account/notifications');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Confirm this purchase'), findsNothing);
    expect(find.text('Reminder: confirm this purchase'), findsNothing);
    expect(find.text('Please review this seller'), findsNothing);
    expect(find.text('Potwierdź ten zakup'), findsOneWidget);
    expect(find.text('Przypomnienie: potwierdź ten zakup'), findsOneWidget);
    expect(find.text('Oceń tego sprzedającego'), findsOneWidget);
    expect(find.textContaining('Technica twierdzi'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  test('review-first submit asks the seller and stays off the rating', () {
    final auth = FakeAuthState()..actAsBuyer(BuyerDevPick.marek);
    final review = DealService.instance.submitReviewFirst(
      auth: auth,
      sellerId: FakeAuthState.mockOwnerId,
      listingNo: '35472819',
      dealType: TGDealType.sale,
      dealMonth: DateTime(2026, 9),
      rating: 5,
      text: 'Bought this unit after viewing it in person. Setup was straightforward.',
    );
    expect(review, isNotNull);
    expect(review!.state, TGPurchaseReviewState.awaitingSeller);
    expect(review.countsTowardRating, isFalse);
    expect(DealService.instance.byId(review.dealId)!.source, TGDealSource.reviewFirst);
    expect(DealService.instance.byId(review.dealId)!.status, TGDealStatus.pendingSeller);
    expect(TGAnalytics.has('review_submit'), isTrue);
  });

  test('seller confirm and five-day silence move the review onto the rating', () {
    final d = DealService.instance;
    d.sellerConfirmReview(d.byId('D-2026-000201')!, keepListingActive: true);
    expect(d.reviewById('R-2026-0001')!.state, TGPurchaseReviewState.confirmed);
    expect(d.reviewById('R-2026-0001')!.countsTowardRating, isTrue);
    expect(d.byId('D-2026-000201')!.verification, TGDealVerification.bothParties);
    TGClock.advance(const Duration(days: 5));
    d.onClockAdvanced();
    expect(d.reviewById('R-2026-0009')!.state, TGPurchaseReviewState.notDisputed);
    expect(d.reviewById('R-2026-0009')!.countsTowardRating, isTrue);
    expect(d.byId('D-2026-000209')!.status, TGDealStatus.notDisputed);
  });

  test('photos-only evidence is rejected; 48h silence marks no evidence', () {
    final d = DealService.instance;
    d.addEvidence(dealId: 'D-2026-000206', role: TGEvidenceRole.buyer, type: TGEvidenceType.photo, fileUrl: 'mock://p');
    expect(d.submitBuyerEvidence('D-2026-000206', note: 'photos only here'), isFalse);
    TGClock.advance(const Duration(days: 2));
    d.onClockAdvanced();
    expect(d.objectionForReview('R-2026-0006')!.status, TGObjectionStatus.noEvidence);
  });

  test('hard cap with evidence marks the review not verified', () {
    TGClock.advance(const Duration(days: 5));
    DealService.instance.onClockAdvanced();
    expect(DealService.instance.reviewById('R-2026-0010')!.state, TGPurchaseReviewState.notVerified);
    expect(DealService.instance.reviewById('R-2026-0010')!.countsTowardRating, isFalse);
  });

  testWidgets('review checks lists buyer reviews for the seller', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/deals?tab=requests', signedIn: true);
    expect(find.textContaining('reviewed you'), findsWidgets);
    expect(find.text('Yes, sold to this buyer'), findsWidgets);
    expect(find.text('Review checks'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('buyer reviews page shows status chips', (tester) async {
    final app = await pumpTgApp(tester, location: '/', signedIn: true);
    app.auth.actAsBuyer(BuyerDevPick.marek);
    app.router.go('/account/reviews');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('AWAITING SELLER'), findsWidgets);
    expect(find.text('REMOVED'), findsWidgets);
    expect(find.text('Appeal'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('review a purchase opens the composer', (tester) async {
    final app = await pumpTgApp(tester, location: '/', signedIn: true);
    app.auth.actAsBuyer(BuyerDevPick.marek);
    app.router.go('/account/deals');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('review-a-purchase')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Review a purchase'), findsWidgets);
    await tester.enterText(find.byKey(const Key('review-listing-no')), '35472819');
    await tester.pump();
    expect(find.textContaining('Listing 35472819'), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  test('neutral seller copy when the buyer declines', () {
    final deal = DealService.instance.byId('D-2026-000123')!;
    DealService.instance.declineByBuyer(deal, buyerId: deal.buyerId!);
    final n = NotificationService.instance.forUser(FakeAuthState.mockOwnerId).first;
    expect(n.body, "The buyer couldn't confirm this deal.");
    expect(TGAnalytics.has('deal_buyer_declined'), isTrue);
  });
}

List<TGProduct> visibleProducts(List<TGProduct> all) => all.where((p) => p.isPubliclyVisible).toList();
