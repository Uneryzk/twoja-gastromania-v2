import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    ModerationService.instance.reset();
  });

  test('seed has 8 public reports, 2 under-review seller listings (one hidden) and 1 removed', () {
    final mod = ModerationService.instance..ensureSeeded();
    expect(mod.reports.where((r) => r.reportNo.startsWith('R-2026-')), hasLength(15));
    expect(mod.sellerListings.where((p) => p.status.toString().contains('underReview')), hasLength(2));
    expect(mod.sellerListings.where((p) => p.isHidden && p.status.toString().contains('underReview')), hasLength(1));
    expect(mod.sellerListings.where((p) => p.status.toString().contains('removed')), hasLength(1));
  });

  testWidgets('Polish locale localizes the report listing modal', (tester) async {
    final app = await pumpTgApp(
      tester,
      location: '/product-detail/p001',
      size: TGSizes.desktop,
      locale: const Locale('pl'),
    );
    await tester.tap(find.byKey(const Key('pdp-report-listing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Zgłoś ogłoszenie'), findsWidgets);
    expect(find.text('Krok 1 z 2'), findsOneWidget);
    expect(find.text('Dlaczego zgłaszasz?'), findsOneWidget);
    expect(find.text('Podejrzenie oszustwa'), findsOneWidget);
    expect(find.text('Duplikat'), findsOneWidget);
    expect(find.text('Why are you reporting?'), findsNothing);
    expect(find.text('Suspected fraud or scam'), findsNothing);
    _ok(app);
  });

  testWidgets('desktop report link has a flag and opens a 2-step modal', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    final report = find.byKey(const Key('pdp-report-listing'));
    expect(report, findsOneWidget);
    expect(find.descendant(of: report, matching: find.byIcon(Icons.flag_outlined)), findsOneWidget);
    await tester.tap(report);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Why are you reporting?'), findsOneWidget);
    expect(find.textContaining('Listing No. 10482137'), findsWidgets);
    expect(find.text('Suspected fraud or scam'), findsOneWidget);
    _ok(app);
  });

  testWidgets('phone shows overflow menu and a report link above the footer', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.phone);
    expect(find.byKey(const Key('pdp-report-overflow')), findsOneWidget);
    expect(find.byKey(const Key('pdp-report-footer')), findsOneWidget);
    _ok(app);
  });

  testWidgets('owner does not see report; expired listing does not either', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/own_f1', size: TGSizes.desktop);
    expect(find.byKey(const Key('pdp-report-listing')), findsNothing);
    app.router.go('/product-detail/p012');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const Key('pdp-report-listing')), findsNothing);
    _ok(app);
  });

  testWidgets('submitting Other produces R-2026-000417 and a success screen', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    await tester.tap(find.byKey(const Key('pdp-report-listing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('report-reason-other')));
    await tester.tap(find.byKey(const Key('report-reason-other')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('report-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Step 2 of 2'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('report-details')), 'This listing looks wrong in several ways and needs a review.');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('report-confirm')));
    await tester.tap(find.byKey(const Key('report-confirm')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('report-submit')));
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pump();
    expect(find.byKey(const Key('report-success')), findsOneWidget);
    expect(find.text('R-2026-000417'), findsOneWidget);
    expect(find.text("We'll email you when we've reviewed it."), findsOneWidget);
    expect(ModerationService.instance.reports.last.reason, TGReportReason.other);
    expect(TGAnalytics.has('report_open'), isTrue);
    expect(TGAnalytics.has('report_reason_selected'), isTrue);
    expect(TGAnalytics.has('report_submit'), isTrue);
    _ok(app);
  });

  testWidgets('dashboard shows UNDER REVIEW, REMOVED, Respond and Appeal', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/listings', size: TGSizes.desktop);
    expect(find.text('UNDER REVIEW'), findsWidgets);
    expect(find.textContaining('Reply by 10 Oct'), findsWidgets);
    expect(find.text('REMOVED'), findsOneWidget);
    expect(find.text('Respond'), findsWidgets);
    expect(find.text('Appeal'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    _ok(app);
  });

  testWidgets('under-review PDP shows temporarily unavailable; removed shows removed', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/48019273', size: TGSizes.desktop, signedIn: false);
    expect(find.text('This listing is temporarily unavailable'), findsOneWidget);
    app.router.go('/product-detail/50231495');
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(find.text('This listing has been removed'), findsOneWidget);
    _ok(app);
  });

  testWidgets('guest must verify email with magic link or OTP 123456', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop, signedIn: false);
    await tester.tap(find.byKey(const Key('pdp-report-listing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('report-reason-other')));
    await tester.tap(find.byKey(const Key('report-reason-other')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('report-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('report-magic-link')));
    expect(find.byKey(const Key('report-magic-link')), findsOneWidget);
    expect(find.byKey(const Key('report-otp')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('report-email')), 'guest.one@example.com');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('report-otp')), '000000');
    await tester.tap(find.byKey(const Key('report-otp-verify')));
    await tester.pump();
    expect(find.textContaining('123456'), findsWidgets);
    await tester.enterText(find.byKey(const Key('report-otp')), '123456');
    await tester.tap(find.byKey(const Key('report-otp-verify')));
    await tester.pump();
    expect(find.text('E-mail verified'), findsOneWidget);
    _ok(app);
  });

  testWidgets('second report on the same listing is blocked with the original number', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    Future<void> fillOther() async {
      await tester.tap(find.byKey(const Key('pdp-report-listing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.byKey(const Key('report-reason-other')));
      await tester.tap(find.byKey(const Key('report-reason-other')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(find.byKey(const Key('report-details')), 'This listing looks wrong in several ways and needs a review.');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('report-confirm')));
      await tester.tap(find.byKey(const Key('report-confirm')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('report-submit')));
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pump();
    }

    await fillOther();
    expect(find.byKey(const Key('report-success')), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await fillOther();
    expect(find.byKey(const Key('report-blocked')), findsOneWidget);
    expect(find.text('R-2026-000417'), findsWidgets);
    expect(TGAnalytics.has('report_duplicate_attempt'), isTrue);
    _ok(app);
  });

  testWidgets('oversized evidence is rejected', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    await tester.tap(find.byKey(const Key('pdp-report-listing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('report-reason-other')));
    await tester.tap(find.byKey(const Key('report-reason-other')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('report-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('report-add-oversized')));
    await tester.tap(find.byKey(const Key('report-add-oversized')));
    await tester.pump();
    expect(find.text('Each file must be 5 MB or less.'), findsOneWidget);
    expect(find.byKey(const Key('report-add-video')), findsOneWidget);
    _ok(app);
  });

  test('duplicate and hourly cap block public reports', () {
    final mod = ModerationService.instance..ensureSeeded();
    final listing = _listing('30001001');
    final first = mod.submitListingReport(product: listing, reason: TGReportReason.other, email: 'once@example.com', reporterId: 'u_once', text: 'Needs a closer look from the team.');
    expect(first.ok, isTrue);
    final dup = mod.submitListingReport(product: listing, reason: TGReportReason.sold, email: 'once@example.com', reporterId: 'u_once');
    expect(dup.duplicateOf?.reportNo, first.report!.reportNo);
    expect(TGAnalytics.has('report_duplicate_attempt'), isTrue);
    for (var i = 0; i < 5; i++) {
      final r = mod.submitListingReport(product: _listing('30002${i.toString().padLeft(3, '0')}'), reason: TGReportReason.other, email: 'rate@example.com', reporterId: 'u_rate');
      expect(r.ok, isTrue);
    }
    final blocked = mod.submitListingReport(product: _listing('30002999'), reason: TGReportReason.other, email: 'rate@example.com', reporterId: 'u_rate');
    expect(blocked.rateLimited, isTrue);
  });

  test('sold reports stay with the seller until 2 reporters or 5 days', () {
    final mod = ModerationService.instance..ensureSeeded();
    final listing = _listing('30003001');
    mod.submitListingReport(product: listing, reason: TGReportReason.sold, email: 'sold1@example.com', reporterId: 'u_sold1');
    expect(mod.queueRows.any((c) => c.listingNo == '30003001'), isFalse);
    expect(mod.sellerCases['30003001']?.soldNudge, isTrue);
    mod.submitListingReport(product: listing, reason: TGReportReason.sold, email: 'sold2@example.com', reporterId: 'u_sold2');
    expect(mod.queueRows.any((c) => c.listingNo == '30003001'), isTrue);
    expect(mod.caseFor('30003001')!.priority, TGModerationPriority.medium);

    final aged = _listing('30003002');
    mod.debugNow = DateTime(2026, 1, 1);
    mod.submitListingReport(product: aged, reason: TGReportReason.sold, email: 'sold3@example.com', reporterId: 'u_sold3');
    expect(mod.queueRows.any((c) => c.listingNo == '30003002'), isFalse);
    mod.debugNow = DateTime(2026, 1, 7);
    expect(mod.queueRows.any((c) => c.listingNo == '30003002'), isTrue);
    expect(mod.queueRows.firstWhere((c) => c.listingNo == '30003002').priority, TGModerationPriority.medium);
  });

  test('guest reports start Low unless fraud or prohibited', () {
    final mod = ModerationService.instance..ensureSeeded();
    mod.submitListingReport(product: _listing('30004001'), reason: TGReportReason.duplicate, email: 'g1@example.com', reporterId: 'guest');
    expect(mod.caseFor('30004001')!.priority, TGModerationPriority.low);
    expect(mod.reports.last.reporterId, 'guest:g1@example.com');
    mod.submitListingReport(product: _listing('30004002'), reason: TGReportReason.fraud, email: 'g2@example.com', reporterId: 'guest');
    expect(mod.caseFor('30004002')!.priority, TGModerationPriority.high);
    mod.submitListingReport(product: _listing('30004003'), reason: TGReportReason.prohibited, email: 'g3@example.com', reporterId: 'guest');
    expect(mod.caseFor('30004003')!.priority, TGModerationPriority.high);
  });

  test('rejected appeal is final; restore refunds a store slot not a free slot', () async {
    final mod = ModerationService.instance..ensureSeeded();
    final removed = mod.sellerCases['50231495']!;
    mod.appealAsSeller(listingNo: '50231495', statement: 'Please take another look at this removal decision.', actorId: 'seller_tg', evidence: ['assets/images/image.png']);
    expect(removed.appealed, isTrue);
    expect(TGAnalytics.has('appeal_submit'), isTrue);
    final appeal = mod.appeals.last;
    mod.decideAppeal(appealId: appeal.id, uphold: false, actorId: 'staff_admin', actorRole: 'admin');
    expect(removed.finalRemoval, isTrue);

    final auth = FakeAuthState(isLoggedIn: true)..storeActiveUsed = 6;
    await TGProductService.instance.upsert(_listing('30005001', source: TGListingSource.store));
    await mod.restore(listingNo: '30005001', actorId: 'staff_admin', actorRole: 'admin', auth: auth);
    expect(mod.storeCreditsRefunded, 1);
    expect(auth.storeActiveUsed, 5);

    final freeUsed = auth.freeSlotsUsed;
    await TGProductService.instance.upsert(_listing('30005002', source: TGListingSource.free));
    await mod.restore(listingNo: '30005002', actorId: 'staff_admin', actorRole: 'admin', auth: auth);
    expect(mod.storeCreditsRefunded, 1);
    expect(auth.freeSlotsUsed, freeUsed);
  });
}

void _ok(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}

TGProduct _listing(String no, {TGListingSource source = TGListingSource.free}) => TGProduct(
      id: no,
      title: 'Unit $no',
      price: 100,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: TGPriceBasis.brutto,
      negotiable: false,
      oldPrice: null,
      condition: TGCondition.used,
      listingType: TGListingType.buy,
      category: TGCategory.cookingEquipment,
      powerType: TGPowerType.electric,
      warrantyMonths: 0,
      delivery: true,
      pickup: true,
      seller: FakeAuthState.mockOwnerSeller,
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '',
      imageUrl: '',
      photoCount: 1,
      isPromoted: false,
      createdAt: DateTime(2026, 1, 1),
      source: source,
      listingNo: no,
    );
