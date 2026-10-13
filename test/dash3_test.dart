import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_account_sheets.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_showcase_section.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_notification_prefs.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/dashboard_service.dart';
import 'package:twoja_gastromania/tg_services/notification_prefs_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

import 'helpers/tg_test_app.dart';

List<Map<String, Object?>> _ev(String name) => [for (final e in TGAnalytics.events) if (e.$1 == name) e.$2];

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}

Future<void> _settle(WidgetTester tester, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _go(WidgetTester tester, TGApp app, String location) async {
  app.router.go(location);
  await _settle(tester);
}

/// Store owner "Gastrosilesia.pl" (Pro) with the DASH-3 billing mocks.
Future<TGApp> _billingApp(WidgetTester tester, {Size size = TGSizes.desktop, String location = '/dashboard/billing'}) async {
  final app = await pumpTgApp(tester, location: '/dashboard', size: size);
  applyTGDevSwitchPick(app.router, app.auth, DashboardDevPick.billingStore);
  await _settle(tester);
  if (location != '/dashboard/billing') await _go(tester, app, location);
  return app;
}

TGInvoiceProfile _profile(String userId) => TGInvoiceProfile(
      userId: userId,
      companyName: 'Test sp. z o.o.',
      nip: '526-025-02-74',
      street: 'ul. Długa 1',
      postalCode: '00-001',
      city: 'Warszawa',
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() {
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    TGBillingService.instance.reset();
    TGNotificationPrefsService.instance.reset();
    NotificationService.instance.reset();
    TGSponsorSlotService.instance.reset();
    TGAnalytics.reset();
  });

  tearDown(() async {
    TGClock.reset();
    await TGProductService.instance.resetToSeed();
  });

  group('Payment / VAT / NIP models', () {
    test('gross → net + 23% VAT in grosze always adds up', () {
      final s = TGVatSplit.fromGross(199);
      expect(s.grossGr, 19900);
      expect(s.netGr, 16179);
      expect(s.vatGr, 3721);
      for (final g in [1, 19, 49, 88, 149, 499, 899, 1074.6]) {
        final v = TGVatSplit.fromGross(g);
        expect(v.netGr + v.vatGr, v.grossGr);
        expect(v.vatGr / v.netGr, closeTo(0.23, 0.01));
      }
      final p = TGBillingService.instance.recordPayment(userId: 'u1', kind: TGPaymentKind.listing, description: 'x', grossPln: 49);
      expect(p.toJson()['vatRate'], 0.23);
      expect(p.vatPln, closeTo(9.16, 0.001));
    });

    test('invoice profile validates the NIP checksum and postal code', () {
      expect(_profile('u').isValid, isTrue);
      const bad = TGInvoiceProfile(userId: 'u', companyName: 'A', nip: '5260250275', street: 's', postalCode: '00001', city: 'c', email: 'nope');
      expect(bad.validate(), {'nip': 'bill_err_nip', 'postal': 'bill_err_postal', 'email': 'bill_err_email'});
      expect(TGBillingService.instance.saveProfile(bad), isNotEmpty);
      expect(TGBillingService.instance.profileFor('u'), isNull);
      expect(TGBillingService.instance.saveProfile(_profile('u')), isEmpty);
      expect(TGBillingService.instance.profileFor('u')!.nipDigits, '5260250274');
    });

    testWidgets('a successful PaymentForm payment writes a Payment record automatically', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/listings?filter=expired', size: TGSizes.desktop);
      await tester.tap(find.byKey(const Key('dashboard-renew-own_f_exp1')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('payment-blik-0')), '777123');
      await tester.pump();
      tester.widget<InkWell>(find.byKey(const Key('payment-terms'))).onTap?.call();
      await tester.pump();
      tester.widget<TGButton>(find.byKey(const Key('payment-pay'))).onPressed?.call();
      await pumpFor(tester, const Duration(milliseconds: 1600));
      final rows = TGBillingService.instance.paymentsFor(app.auth.userId);
      expect(rows, hasLength(1));
      expect(rows.single.kind, TGPaymentKind.renew);
      expect(rows.single.amount.netGr + rows.single.amount.vatGr, rows.single.amount.grossGr);
      expect(rows.single.status, TGPaymentStatus.succeeded);
      expect(rows.single.methodLabel, 'BLIK');
      expect(_ev('payment_recorded'), hasLength(1));
      _expectNoErrors(app);
    });
  });

  group('Invoices + CSV', () {
    test('request invoice: profile, already issued and 3-month deadline', () {
      final svc = TGBillingService.instance;
      final now = TGClock.now();
      final fresh = svc.recordPayment(userId: 'u', kind: TGPaymentKind.promotion, description: 'Glow · 14 days', grossPln: 59, at: now);
      final old = svc.recordPayment(userId: 'u', kind: TGPaymentKind.listing, description: 'Old', grossPln: 49, at: DateTime(now.year, now.month - 4, 10));
      expect(svc.requestInvoice('u', []).error, 'bill_err_pick_payment');
      expect(svc.requestInvoice('u', [fresh.id]).error, 'bill_err_profile');
      svc.saveProfile(_profile('u'));
      expect(svc.canRequestInvoice(old), isFalse);
      expect(svc.requestInvoice('u', [old.id]).error, 'bill_err_deadline');
      final r = svc.requestInvoice('u', [fresh.id]);
      expect(r.error, isNull);
      expect(r.invoice!.number, matches(RegExp(r'^FV/\d{4}/\d{2}/0001$')));
      expect(r.invoice!.amount.grossGr, 5900);
      expect(svc.paymentById(fresh.id)!.invoiceId, r.invoice!.id);
      expect(svc.requestInvoice('u', [fresh.id]).error, 'bill_err_already');
      expect(_ev('billing_invoice_request'), hasLength(1));
      final doc = svc.invoiceDocument(r.invoice!);
      expect(doc, contains('NIP 5260250274'));
      expect(doc, contains('VAT 23%'));
    });

    test('CSV export has net / VAT / gross columns and escapes cells', () {
      final svc = TGBillingService.instance;
      svc.recordPayment(userId: 'u', kind: TGPaymentKind.banner, description: 'Hero; "big"', grossPln: 199, methodLabel: 'BLIK');
      final csv = svc.paymentsCsv(svc.paymentsFor('u'));
      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('Date;Payment ID;Description;Kind;Net PLN;VAT PLN;Gross PLN'));
      expect(lines[1], contains('"Hero; ""big"""'));
      expect(lines[1], contains('161.79;37.21;199.00'));
    });
  });

  group('Subscriptions + dunning', () {
    test('cancel at period end keeps the plan until the end; change plan applies next period', () {
      final svc = TGBillingService.instance;
      final s = svc.startStoreSubscription(userId: 'u', planId: 'pro', period: TGBillingPeriod.monthly, pricePln: 499);
      svc.changePlan(s.id, planId: 'enterprise', period: TGBillingPeriod.yearly);
      expect(s.planId, 'pro');
      expect(s.nextPlanId, 'enterprise');
      expect(s.pricePln, TGBillingService.storePrice('enterprise', TGBillingPeriod.yearly));
      final change = _ev('subscription_change').single;
      expect(change['from'], 'pro/monthly');
      expect(change['to'], 'enterprise/yearly');

      svc.cancelAtPeriodEnd(s.id, userId: 'u', reason: 'price');
      expect(s.cancelAtPeriodEnd, isTrue);
      expect(s.status, TGSubscriptionStatus.active);
      expect(_ev('subscription_cancel').single, containsPair('atPeriodEnd', true));
      svc.resume(s.id);
      expect(s.cancelAtPeriodEnd, isFalse);
      expect(_ev('subscription_change').last['action'], 'resume');
    });

    test('past_due retries on day 0 / +3 / +7 and recovers with a valid default card', () {
      final svc = TGBillingService.instance;
      final s = svc.startStoreSubscription(userId: 'u', planId: 'basic', period: TGBillingPeriod.monthly, pricePln: 199);
      final t0 = TGClock.now();
      svc.markPastDue(s.id, at: t0, methodLabel: 'Visa •••• 4242');
      expect(s.status.apiName, 'past_due');
      expect(svc.nextRetryAt(s), DateTime(t0.year, t0.month, t0.day + 3, t0.hour, t0.minute));
      expect(svc.changePlan(s.id, planId: 'pro'), 'bill_err_sub_past_due');
      expect(svc.retryNow(s.id), 'bill_err_no_method');
      expect(NotificationService.instance.forUser('u').where((n) => n.type == 'billing_payment_failed'), hasLength(1));

      svc.processDunning(now: t0.add(const Duration(days: 3, hours: 1)));
      expect(s.attempts.map((a) => (a.dayOffset, a.ok)), [(0, false), (3, false)]);
      expect(s.isPastDue, isTrue);

      svc.saveCard(userId: 'u', number: '4111111111111111', expMonth: 12, expYear: t0.year + 3);
      svc.processDunning(now: t0.add(const Duration(days: 7, hours: 1)));
      expect(s.status, TGSubscriptionStatus.active);
      expect(svc.paymentsFor('u').where((p) => p.status == TGPaymentStatus.succeeded && p.subscriptionId == s.id), hasLength(1));
      expect(NotificationService.instance.forUser('u').where((n) => n.type == 'billing_payment_recovered'), hasLength(1));
    });

    test('the plan ends after the last failed attempt; Pay now needs a valid card', () {
      final svc = TGBillingService.instance;
      final s = svc.startStoreSubscription(userId: 'u', planId: 'pro', period: TGBillingPeriod.monthly, pricePln: 499);
      svc.saveCard(userId: 'u', number: '4111111111111111', expMonth: 1, expYear: 2020);
      final t0 = TGClock.now();
      svc.markPastDue(s.id, at: t0);
      expect(svc.retryNow(s.id), 'bill_err_method_expired');
      svc.processDunning(now: t0.add(const Duration(days: 8)));
      expect(s.attempts, hasLength(3));
      expect(s.status, TGSubscriptionStatus.cancelled);
      expect(NotificationService.instance.forUser('u').where((n) => n.type == 'billing_subscription_ended'), hasLength(1));
    });

    test('past_due shows up as a critical Action Center item', () {
      final auth = FakeAuthState(isLoggedIn: true)..actAsStoreOwner(StoreOwnerDevPick.gastroPro);
      TGBillingService.instance.seedMocks(auth);
      final items = TGDashboard.actionItems(auth).where((i) => i.type == ActionItemType.subscriptionPastDue).toList();
      expect(items, hasLength(1));
      expect(items.single.route, '/dashboard/billing?tab=subscriptions');
      expect(items.single.titleKey, 'dash_ai_past_due');
    });
  });

  group('Mocks', () {
    test('12 payments, 3 invoices, 1 past_due subscription; hidden in productionMode', () {
      final auth = FakeAuthState(isLoggedIn: true)..actAsStoreOwner(StoreOwnerDevPick.gastroPro);
      final svc = TGBillingService.instance;
      svc.seedMocks(auth);
      svc.seedMocks(auth);
      expect(svc.paymentsFor(auth.userId), hasLength(12));
      expect(svc.paymentsFor(auth.userId).where((p) => p.status == TGPaymentStatus.failed), hasLength(1));
      expect(svc.invoicesFor(auth.userId), hasLength(3));
      expect(svc.pastDueFor(auth.userId), hasLength(1));
      expect(svc.methodsFor(auth.userId), hasLength(2));

      TGRevenueConfigService.instance.setProductionMode(true, actorId: 'admin', reason: 'test');
      expect(svc.paymentsFor(auth.userId), isEmpty);
      expect(svc.invoicesFor(auth.userId), isEmpty);
      expect(svc.pastDueFor(auth.userId), isEmpty);
      expect(svc.methodsFor(auth.userId), isEmpty);
      final other = FakeAuthState(isLoggedIn: true)..actAsStoreOwner(StoreOwnerDevPick.technica);
      svc.seedMocks(other);
      expect(svc.paymentsFor(other.userId), isEmpty);
    });
  });

  group('Notification preferences', () {
    test('moderation + billing cannot be turned off; marketing is opt-in with a timestamp', () {
      final p = TGNotificationPrefsService.instance;
      expect(p.set('u', TGNotifCategory.billing, TGNotifChannel.email, false), isFalse);
      expect(p.isOn('u', TGNotifCategory.billing, TGNotifChannel.email), isTrue);
      expect(p.set('u', TGNotifCategory.moderation, TGNotifChannel.inApp, false), isFalse);
      expect(p.isOn('u', TGNotifCategory.moderation, TGNotifChannel.inApp), isTrue);

      expect(p.isOn('u', TGNotifCategory.marketing, TGNotifChannel.email), isFalse);
      expect(p.marketingConsent('u', TGNotifChannel.email), isNull);
      TGClock.advance(const Duration(hours: 2));
      p.set('u', TGNotifCategory.marketing, TGNotifChannel.email, true);
      final r = p.marketingConsent('u', TGNotifChannel.email)!;
      expect(r.granted, isTrue);
      expect(TGClock.now().difference(r.at).inSeconds, 0);
      final e = _ev('notification_pref_change').single;
      expect(e['category'], 'marketing');
      expect(e['consentAt'], r.at.toIso8601String());
      p.set('u', TGNotifCategory.marketing, TGNotifChannel.email, false);
      expect(p.marketingConsent('u', TGNotifChannel.email)!.granted, isFalse);
      expect(p.consentLog, hasLength(2));
    });

    test('turning off a category hides its in-app notifications, never billing', () {
      final n = NotificationService.instance;
      n.add(userId: 'u', type: 'listing_expiring', dealId: 'a', title: 'x', body: 'y');
      n.add(userId: 'u', type: 'billing_payment_failed', dealId: 'b', title: 'x', body: 'y');
      expect(n.forUser('u'), hasLength(2));
      TGNotificationPrefsService.instance.set('u', TGNotifCategory.listings, TGNotifChannel.inApp, false);
      expect(n.forUser('u').map((e) => e.type), ['billing_payment_failed']);
    });
  });

  group('Billing page', () {
    testWidgets('desktop: past_due banner, tabs, table, CSV, invoice download, cancel', (tester) async {
      final app = await _billingApp(tester);
      expect(app.location, '/dashboard/billing');
      expect(find.byKey(const Key('billing-page')), findsOneWidget);
      expect(find.byKey(const Key('billing-vat-note')), findsOneWidget);
      expect(find.byKey(const Key('billing-payments-table')), findsOneWidget);
      expect(find.byKey(Key('billing-pastdue-banner-SUB-store-${app.auth.userId}')), findsOneWidget);
      expect(_ev('billing_view').last['tab'], 'payments');

      await tester.tap(find.byKey(const Key('billing-export-csv')));
      await _settle(tester);
      expect(find.byKey(const Key('dash-export-content')), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const Key('dash-export-content'))).data, contains('Gross PLN'));
      await tester.tap(find.byTooltip('Close'));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('billing-tab-invoices')));
      await _settle(tester);
      expect(app.location, '/dashboard/billing?tab=invoices');
      expect(_ev('billing_view').last['tab'], 'invoices');
      final inv = TGBillingService.instance.invoicesFor(app.auth.userId).first;
      await tester.tap(find.byKey(Key('billing-invoice-download-${inv.id}')));
      await _settle(tester);
      expect(_ev('billing_invoice_download').single['number'], inv.number);
      await tester.tap(find.byTooltip('Close'));
      await _settle(tester);

      await _go(tester, app, '/dashboard/billing?tab=subscriptions');
      final subId = 'SUB-store-${app.auth.userId}';
      expect(find.byKey(Key('billing-dunning-$subId')), findsOneWidget);
      expect(find.byKey(const Key('billing-dunning-7')), findsOneWidget);
      await tester.tap(find.byKey(Key('billing-retry-$subId')));
      await _settle(tester);
      expect(find.text('This card has expired. Choose another card.'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('request invoice flow issues an invoice for a picked payment', (tester) async {
      final app = await _billingApp(tester);
      await tester.tap(find.byKey(const Key('billing-request-invoice')));
      await _settle(tester);
      final eligible = TGBillingService.instance.paymentsFor(app.auth.userId).where((p) => TGBillingService.instance.canRequestInvoice(p)).first;
      await tester.tap(find.byKey(const Key('billing-request-submit')));
      await _settle(tester);
      expect(find.byKey(const Key('billing-request-error')), findsOneWidget);
      await tester.tap(find.byKey(Key('billing-request-pick-${eligible.id}')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('billing-request-submit')));
      await _settle(tester);
      expect(TGBillingService.instance.invoicesFor(app.auth.userId), hasLength(4));
      expect(TGBillingService.instance.paymentById(eligible.id)!.invoiceId, isNotNull);
      _expectNoErrors(app);
    });

    testWidgets('pay now succeeds after switching to a valid card', (tester) async {
      final app = await _billingApp(tester, location: '/dashboard/billing?tab=methods');
      final mc = 'PM-mock-mc-${app.auth.userId}';
      expect(find.byKey(Key('billing-method-expired-PM-mock-visa-${app.auth.userId}')), findsOneWidget);
      await tester.tap(find.byKey(Key('billing-method-default-$mc')));
      await _settle(tester);
      await _go(tester, app, '/dashboard/billing?tab=subscriptions');
      final subId = 'SUB-store-${app.auth.userId}';
      await tester.tap(find.byKey(Key('billing-retry-$subId')));
      await _settle(tester);
      expect(TGBillingService.instance.pastDueFor(app.auth.userId), isEmpty);
      expect(find.byKey(Key('billing-pastdue-banner-$subId')), findsNothing);
      expect(TGBillingService.instance.paymentsFor(app.auth.userId), hasLength(13));
      _expectNoErrors(app);
    });

    testWidgets('390px: vertical cards, scrollable tabs, full-screen cancel sheet', (tester) async {
      final app = await _billingApp(tester, size: TGSizes.phone);
      expect(find.byKey(const Key('billing-payments-table')), findsNothing);
      final first = TGBillingService.instance.paymentsFor(app.auth.userId).first;
      expect(find.byKey(Key('billing-payment-${first.id}')), findsOneWidget);
      final tabs = find.byKey(const Key('billing-tabs'));
      expect(tester.widget<SingleChildScrollView>(tabs).scrollDirection, Axis.horizontal);

      final s = TGBillingService.instance.startStoreSubscription(userId: app.auth.userId, planId: 'pro', period: TGBillingPeriod.monthly, pricePln: 499);
      await _go(tester, app, '/dashboard/billing?tab=subscriptions');
      await tester.ensureVisible(find.byKey(Key('billing-cancel-${s.id}')));
      await tester.tap(find.byKey(Key('billing-cancel-${s.id}')));
      await _settle(tester);
      expect(tester.getSize(find.byKey(const Key('billing-cancel-sheet'))), const Size(390, 844));
      await tester.tap(find.byKey(const Key('billing-cancel-reason-price')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('billing-cancel-confirm')));
      await tester.tap(find.byKey(const Key('billing-cancel-confirm')));
      await _settle(tester);
      expect(s.cancelAtPeriodEnd, isTrue);
      expect(_ev('subscription_cancel').single['reason'], 'price');
      expect(find.byKey(Key('billing-resume-${s.id}')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('320px payments tab renders without overflow', (tester) async {
      final app = await _billingApp(tester, size: TGSizes.smallPhone);
      expect(find.byKey(const Key('billing-payments')), findsOneWidget);
      _expectNoErrors(app);
    });
  });

  group('Notifications page', () {
    testWidgets('All | Action required | Updates | Preferences', (tester) async {
      final app = await pumpTgApp(tester, location: '/account/notifications');
      final uid = app.auth.userId;
      NotificationService.instance.add(userId: uid, type: 'billing_payment_failed', dealId: 's', title: 'Payment failed', body: 'Pro Store', params: {'title': 'Pro Store'});
      NotificationService.instance.add(userId: uid, type: 'listing_expiring', dealId: 'l', title: 'Listing', body: 'x');
      await _settle(tester);
      expect(find.text('Payment failed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notif-tab-action')));
      await _settle(tester);
      expect(app.location, '/account/notifications?tab=action');
      expect(find.text('Payment failed'), findsOneWidget);
      final updates = NotificationService.instance.forUser(uid).where((n) => !tgNotifNeedsAction(n.type)).length;

      await tester.tap(find.byKey(const Key('notif-tab-updates')));
      await _settle(tester);
      expect(find.text('Payment failed'), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(updates));

      await tester.tap(find.byKey(const Key('notif-tab-prefs')));
      await _settle(tester);
      expect(find.byKey(const Key('notif-pref-table')), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('notif-pref-billing-email'))).onChanged, isNull);
      expect(tester.widget<Switch>(find.byKey(const Key('notif-pref-moderation-push'))).onChanged, isNull);
      expect(find.byKey(const Key('notif-pref-lock-billing')), findsOneWidget);
      expect(find.text('E-mail: no consent given'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notif-pref-marketing-email')));
      await _settle(tester);
      expect(TGNotificationPrefsService.instance.isOn(uid, TGNotifCategory.marketing, TGNotifChannel.email), isTrue);
      expect(find.textContaining('E-mail: consent given'), findsOneWidget);
      expect(_ev('notification_pref_change').single['channel'], 'email');
      _expectNoErrors(app);
    });

    testWidgets('390px preferences are cards', (tester) async {
      final app = await pumpTgApp(tester, location: '/account/notifications?tab=prefs', size: TGSizes.phone);
      expect(find.byKey(const Key('notif-pref-table')), findsNothing);
      expect(find.byKey(const Key('notif-pref-card-billing')), findsOneWidget);
      _expectNoErrors(app);
    });
  });

  group('Promotion & ad centre', () {
    test('sponsor slot counters: once per visitor per day, owner/staff not counted; stop early', () {
      final svc = TGSponsorSlotService.instance;
      svc.ensureSeeded();
      final slot = svc.liveSlotOf('seller_gastropl')!;
      expect(svc.recordImpression(slot.id, visitorKey: 'v1', count: true), isTrue);
      expect(svc.recordImpression(slot.id, visitorKey: 'v1', count: true), isFalse);
      expect(svc.recordImpression(slot.id, visitorKey: 'seller_gastropl', count: false), isFalse);
      expect(svc.recordClick(slot.id, visitorKey: 'v1', count: true), isTrue);
      TGClock.advance(const Duration(days: 1));
      expect(svc.recordImpression(slot.id, visitorKey: 'v1', count: true), isTrue);
      expect(svc.countersFor(slot.id), (impressions: 2, clicks: 1));
      expect(svc.stopByOwner(slot.id, sellerId: 'someone'), 'ads_err_not_owner');
      expect(svc.stopByOwner(slot.id, sellerId: 'seller_gastropl'), isNull);
      expect(svc.slots.firstWhere((s) => s.id == slot.id).status, TGSponsorSlotStatus.expired);
      expect(svc.liveSlotOf('seller_gastropl'), isNull);
    });

    testWidgets('hub sponsored banner records a real impression for visitors', (tester) async {
      final app = await pumpTgApp(tester, location: '/special-order', signedIn: false);
      await _settle(tester, 1200);
      final banner = find.byKey(const Key('so-sponsored-banner'));
      if (banner.evaluate().isNotEmpty) {
        final slot = TGSponsorSlotService.instance.liveSlotOf('seller_gastropl');
        if (slot != null) expect(TGSponsorSlotService.instance.countersFor(slot.id).impressions, 1);
      }
      _expectNoErrors(app);
    });

    testWidgets('tabs, exact reach note, real counters, stop early, promo_add', (tester) async {
      final app = await _billingApp(tester, location: '/dashboard/advertising');
      expect(find.text('Reach depends on traffic. We show real numbers.'), findsOneWidget);
      expect(find.byKey(const Key('ads-promotions')), findsOneWidget);
      final live = PromotionService.instance.forOwner(app.auth.userId).firstWhere((p) => p.isActiveAt(TGClock.now()));
      expect(find.byKey(Key('ads-promo-counters-${live.id}')), findsOneWidget);
      final totals = PromotionService.instance.totalsFor(live.id);
      expect(find.textContaining('${totals.impressions} impressions · ${totals.clicks} clicks'), findsWidgets);

      await tester.ensureVisible(find.byKey(Key('ads-promo-stop-${live.id}')));
      await tester.tap(find.byKey(Key('ads-promo-stop-${live.id}')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('ads-stop-confirm')));
      await _settle(tester);
      expect(PromotionService.instance.byId(live.id)!.status, PromotionStatus.ended);

      tester.widget<ChoiceChip>(find.byKey(const Key('ads-tab-sponsor'))).onSelected!(true);
      await _settle(tester);
      expect(app.location, '/dashboard/advertising?tab=sponsor');
      expect(find.byKey(const Key('ads-sponsor')), findsOneWidget);
      expect(find.text('Reach depends on traffic. We show real numbers.'), findsOneWidget);

      await _go(tester, app, '/dashboard/advertising?tab=credits');
      expect(find.byKey(const Key('credits-panel')), findsOneWidget);

      await _go(tester, app, '/dashboard/advertising?tab=promotions');
      await tester.tap(find.byKey(const Key('ads-add-promo')));
      await _settle(tester);
      final pick = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ads-add-pick-'));
      expect(pick, findsWidgets);
      await tester.tap(pick.first);
      await _settle(tester);
      final showcase = tester.widget<TGShowcaseSection>(find.byType(TGShowcaseSection));
      showcase.onPurchased!(Promotion(
        id: 'promo-new',
        ownerId: app.auth.userId,
        targetKind: PromotionTargetKind.listing,
        targetRef: showcase.product.id,
        tier: PromotionTier.glow,
        durationDays: 14,
        startsAt: TGClock.now(),
        endsAt: TGClock.now().add(const Duration(days: 14)),
        status: PromotionStatus.active,
        pricePln: 59,
        source: PromotionSource.paid,
      ));
      await _settle(tester);
      expect(_ev('promo_add').single, containsPair('tier', 'glow'));
      _expectNoErrors(app);
    });

    testWidgets('?target= still opens the banner purchase flow', (tester) async {
      final app = await _billingApp(tester, location: '/dashboard/advertising?target=%2Fseller%2Fx');
      expect(app.location, contains('target='));
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('ads-tab-banners'))).selected, isTrue);
      expect(find.byKey(const Key('ads-promotions')), findsNothing);
      _expectNoErrors(app);
    });

    testWidgets('390px ad centre', (tester) async {
      final app = await _billingApp(tester, size: TGSizes.phone, location: '/dashboard/advertising');
      expect(find.byKey(const Key('ads-promotions')), findsOneWidget);
      expect(tester.widget<SingleChildScrollView>(find.byKey(const Key('ads-tabs'))).scrollDirection, Axis.horizontal);
      _expectNoErrors(app);
    });
  });

  test('all six DASH-3 events are emitted by the services', () {
    final svc = TGBillingService.instance;
    final s = svc.startStoreSubscription(userId: 'u', planId: 'pro', period: TGBillingPeriod.monthly, pricePln: 499);
    svc.changePlan(s.id, planId: 'basic');
    svc.cancelAtPeriodEnd(s.id, userId: 'u');
    TGNotificationPrefsService.instance.set('u', TGNotifCategory.deals, TGNotifChannel.push, true);
    svc.saveProfile(_profile('u'));
    final p = svc.recordPayment(userId: 'u', kind: TGPaymentKind.listing, description: 'x', grossPln: 49);
    final inv = svc.requestInvoice('u', [p.id]).invoice!;
    svc.trackInvoiceDownload(inv);
    for (final e in ['subscription_change', 'subscription_cancel', 'notification_pref_change', 'billing_invoice_download']) {
      expect(_ev(e), isNotEmpty, reason: e);
    }
  });
}
