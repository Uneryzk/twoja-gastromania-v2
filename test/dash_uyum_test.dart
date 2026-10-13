import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/dashboard/renew_sheet.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/dashboard_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
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

FakeAuthState _pro() => FakeAuthState(isLoggedIn: true)..actAsStoreOwner(StoreOwnerDevPick.gastroPro);

Future<TGApp> _proApp(WidgetTester tester, String location, {Size size = TGSizes.desktop}) async {
  final app = await pumpTgApp(tester, location: '/dashboard', size: size);
  app.auth.actAsStoreOwner(StoreOwnerDevPick.gastroPro);
  app.router.go(location);
  await _settle(tester);
  return app;
}

void main() {
  setUp(() {
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    PricingConfigService.instance.resetForTests();
    PromotionService.instance.resetForTests();
    TGBillingService.instance.reset();
    TGSponsorSlotService.instance.reset();
    ActionDismissals.instance.reset();
    TGAnalytics.reset();
  });

  group('dynamic PricingConfig / PromotionConfig', () {
    test('store plan prices come from PricingConfig', () {
      const cfg = PricingConfig();
      expect(cfg.storeMonthlyPln('basic'), cfg.basicStoreMonthlyPln);
      expect(cfg.storeMonthlyPln('Pro Store'), cfg.proStoreMonthlyPln);
      expect(cfg.storeMonthlyPln('ENTERPRISE'), cfg.enterpriseStoreMonthlyPln);
      expect(cfg.storeMonthlyPln('gold'), isNull);
      expect(cfg.defaultListingFeePln, cfg.listingFeePln(cfg.defaultListingDays));

      PricingConfigService.instance.setConfig(cfg.copyWith(proStoreMonthlyPln: 555));
      final charges = TGDashboard.upcomingCharges(_pro(), now: DateTime(2026, 10, 1));
      expect(charges.firstWhere((c) => c.labelKey == 'dash_charge_store').amountPln, 555);
      expect(TGBillingService.storePrice('pro', TGBillingPeriod.monthly), 555);
    });

    test('listing defaults and free quota follow the admin config', () {
      final base = PricingConfigService.instance.config;
      PricingConfigService.instance.setConfig(base.copyWith(listingPrices: {45: 59, 90: 99}, freeListingQuota: 5));
      final cfg = PricingConfigService.instance.config;
      expect(cfg.defaultListingDays, 45);
      expect(cfg.defaultListingFeePln, 59);
      expect(FakeAuthState(isLoggedIn: true).freeListingsTotal, 5);
    });

    test('promotion mocks and credits use PromotionConfig durations', () {
      final svc = PromotionService.instance..ensureSeeded();
      final durations = svc.config.durations;
      for (final p in svc.all) {
        expect(durations, contains(p.durationDays), reason: p.id);
      }
      for (final c in svc.credits) {
        expect(durations, contains(c.durationDays), reason: c.id);
      }
    });

    test('billing and admin mocks carry config prices', () {
      final cfg = PricingConfigService.instance.config;
      final auth = _pro();
      TGBillingService.instance.seedMocks(auth);
      final pays = TGBillingService.instance.paymentsFor(auth.userId);
      final listing = pays.firstWhere((p) => p.kind == TGPaymentKind.listing);
      expect(listing.amount.grossGr, cfg.defaultListingFeePln * 100);
      final glow = pays.firstWhere((p) => p.description.startsWith('Glow'));
      final days = cfg.promotions.durations.first;
      expect(glow.description, tgPromoBillingLabel(PromotionTier.glow, days));
      expect(glow.amount.grossGr, cfg.promoFeePln(PromotionTier.glow, days) * 100);
      expect(pays.any((p) => p.kind == TGPaymentKind.audit), isFalse);
    });
  });

  group('audit clean-up', () {
    test('no audited capability; legacy audit kind kept only for history', () {
      expect(AccountCapabilities.of(_pro()).toMap().containsKey('audited'), isFalse);
      expect(TGPaymentKind.fromName('audit'), TGPaymentKind.audit);
      expect(TGPaymentKind.audit.sellable, isFalse);
      for (final c in TGDashboard.upcomingCharges(_pro(), now: DateTime(2026, 10, 1))) {
        expect(c.labelKey.contains('audit'), isFalse);
      }
    });
  });

  group('Pro Glow credits', () {
    test('usage, left and redeem (free, proIncluded)', () {
      final auth = _pro();
      final svc = PromotionService.instance;
      final total = PricingConfigService.instance.config.proCreditsPerPeriod;
      expect(svc.proCreditUsage(auth.userId), (used: 1, total: total));
      expect(svc.unusedCreditsOf(auth.userId, PromotionTier.glow), total - 1);
      final promo = svc.redeemCredit(ownerId: auth.userId, kind: PromotionTargetKind.listing, targetRef: 'p020')!;
      expect(promo.pricePln, 0);
      expect(promo.source, PromotionSource.proIncluded);
      expect(promo.durationDays, svc.config.durations.last);
      expect(svc.proCreditUsage(auth.userId).used, 2);
      expect(svc.unusedCreditsOf(auth.userId, PromotionTier.glow), total - 2);
      expect(_ev('promo_credit_use'), hasLength(1));
    });

    test('no credits → redeem returns null', () {
      expect(
        PromotionService.instance.redeemCredit(ownerId: 'nobody', kind: PromotionTargetKind.listing, targetRef: 'x'),
        isNull,
      );
    });
  });

  group('Action Center: promotion ends soon', () {
    test('priority 2 (high), dismissible, per account', () {
      final auth = _pro();
      final item = TGDashboard.actionItems(auth).firstWhere((i) => i.type == ActionItemType.promotionEnding);
      expect(item.id, 'promo-ending-promo-dash-2');
      expect(item.priority, ActionPriority.high);
      expect(ActionPriority.values.indexOf(item.priority) + 1, 2);
      expect(item.dismissible, isTrue);
      expect(item.params['n'], '2');
      expect(item.params['tier'], 'Bold');
      expect(item.route, '/dashboard/advertising?tab=promotions');
      expect(TGDashboard.actionItems(auth).where((i) => i.type == ActionItemType.promotionEnding), hasLength(1));

      ActionDismissals.instance.dismiss(auth.userId, item);
      expect(TGDashboard.actionItems(auth).any((i) => i.id == item.id), isFalse);
      expect(ActionDismissals.instance.isDismissed('someone_else', item.id), isFalse);
    });

    test('obligations cannot be dismissed', () {
      final auth = FakeAuthState(isLoggedIn: true);
      final expired = TGDashboard.actionItems(auth).firstWhere((i) => i.type == ActionItemType.listingExpired);
      ActionDismissals.instance.dismiss(auth.userId, expired);
      expect(TGDashboard.actionItems(auth).any((i) => i.id == expired.id), isTrue);
    });

    test('promotions further than 2 days out do not surface', () {
      final auth = _pro();
      PromotionService.instance.ensureSeeded();
      TGClock.advance(const Duration(days: -3));
      expect(TGDashboard.actionItems(auth).any((i) => i.type == ActionItemType.promotionEnding), isFalse);
    });

    test('copy', () {
      expect(kUiTranslations['dash_ai_promo_ending']!['en'], contains('{tier} promotion ends in'));
      expect(kUiTranslations['uyum_glow_credits_left']!['en'], '{n} Glow credits left');
      expect(kUiTranslations['uyum_glow_used']!['en'], '{used}/{total} Glow credits used');
    });
  });

  group('widgets', () {
    testWidgets('overview: Pro quota shows Glow usage; dismiss the promotion card', (tester) async {
      final app = await _proApp(tester, '/dashboard');
      expect(find.text('1/3 Glow credits used'), findsOneWidget);
      expect(find.byKey(const Key('dash-quota-paid')), findsNothing);
      final row = find.byKey(const Key('dash-action-promo-ending-promo-dash-2'));
      expect(row, findsOneWidget);
      expect(find.textContaining('Bold promotion ends in 2 days'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^High\. Suggestion\. Bold promotion ends in 2 days')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dash-action-dismiss-promo-ending-promo-dash-2')));
      await _settle(tester, 300);
      expect(row, findsNothing);
      expect(_ev('action_item_dismiss').single['type'], 'promotionEnding');
      _expectNoErrors(app);
    });

    testWidgets('overview: individual seller sees config 30/60/90 paid options', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      await _settle(tester, 300);
      final cfg = PricingConfigService.instance.config;
      expect(find.byKey(const Key('dash-quota-paid')), findsOneWidget);
      for (final d in cfg.listingDurations) {
        expect(find.byKey(Key('dash-quota-paid-$d')), findsOneWidget);
        expect(find.text('$d days · ${cfg.listingFeePln(d)} PLN'), findsOneWidget);
      }
      expect(find.byKey(const Key('dash-quota-glow')), findsNothing);
      _expectNoErrors(app);
    });

    testWidgets('advertising › Promotions: tiers, time left, real counters, Glow credits', (tester) async {
      final app = await _proApp(tester, '/dashboard/advertising?tab=promotions');
      expect(find.byKey(const Key('ads-promotions')), findsOneWidget);
      expect(find.text('2 Glow credits left · 1/3 Glow credits used'), findsOneWidget);
      for (final t in PromotionTier.values) {
        expect(find.byKey(Key('ads-tier-${t.name}')), findsOneWidget);
      }
      final now = TGClock.now();
      final boldLive = PromotionService.instance
          .forOwner(app.auth.userId)
          .where((p) => p.tier == PromotionTier.bold && p.status == PromotionStatus.active && p.isActiveAt(now))
          .length;
      expect(boldLive, greaterThan(0));
      expect(find.text('Bold: $boldLive live · 0 scheduled'), findsOneWidget);
      expect(find.text('2 days left'), findsOneWidget);
      expect(find.textContaining('Paid with a credit'), findsOneWidget);
      final t = PromotionService.instance.totalsFor('promo-dash-3');
      expect(t, (impressions: 655, clicks: 47));
      expect(find.textContaining('655 impressions · 47 clicks'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('advertising › Sponsor slots list VITRIN-4 config prices', (tester) async {
      final app = await _proApp(tester, '/dashboard/advertising?tab=sponsor');
      final pricing = TGSponsorSlotService.instance.pricing;
      for (final d in pricing.durations) {
        expect(find.byKey(Key('ads-sponsor-price-$d')), findsOneWidget);
        expect(find.textContaining('$d days · ${pricing.pricePln(d)} PLN'), findsOneWidget);
      }
      _expectNoErrors(app);
    });

    testWidgets('listings › promotions tab reuses the advertising list', (tester) async {
      final app = await _proApp(tester, '/dashboard/listings?tab=promotions');
      expect(find.byKey(const Key('ads-promotions')), findsOneWidget);
      expect(find.byKey(const Key('ads-glow-credits')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('verification: two bases, individual path = reviews', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/verification', size: const Size(1280, 2400));
      await _settle(tester, 400);
      final reviews = find.byKey(const Key('vc-shield-opt-reviews'));
      final store = find.byKey(const Key('vc-shield-opt-store'));
      expect(reviews, findsOneWidget);
      expect(store, findsOneWidget);
      expect(find.descendant(of: reviews, matching: find.text('Your path')), findsOneWidget);
      expect(find.descendant(of: store, matching: find.text('Your path')), findsNothing);
      expect(find.descendant(of: store, matching: find.byKey(const Key('vc-shield-req-nip'))), findsOneWidget);
      expect(find.descendant(of: reviews, matching: find.byKey(const Key('vc-shield-req-negatives'))), findsOneWidget);
      expect(find.byKey(const Key('ver-reviews-card')), findsOneWidget);
      expect(find.text('Verified through reviews'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('verification: store path = NIP + plan', (tester) async {
      final app = await _proApp(tester, '/dashboard/verification', size: const Size(1280, 2400));
      final store = find.byKey(const Key('vc-shield-opt-store'));
      expect(find.descendant(of: store, matching: find.text('Your path')), findsOneWidget);
      expect(find.byKey(const Key('ver-company-card')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('renew sheet: config durations, tier copy, Glow credit makes the add-on free', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard', size: TGSizes.desktop);
      await _settle(tester, 300);
      final cfg = PricingConfigService.instance.config;
      final product = app.auth.ownedListings.firstWhere((p) => p.id == 'own_f_exp1');
      PromotionService.instance.grantFounderCredit(app.auth.userId);
      showRenewSheet(tester.element(find.byKey(const Key('dash-overview'))), product);
      await _settle(tester);
      for (final d in cfg.listingDurations) {
        expect(find.byKey(Key('renew-dur-$d')), findsOneWidget);
      }
      final fee = cfg.defaultListingFeePln;
      expect(find.text('Total (brutto, VAT 23% included): $fee PLN'), findsOneWidget);
      final promoDays = cfg.promotions.defaultDays;
      expect(find.text('Glow · ${cfg.promoFeePln(PromotionTier.glow, promoDays)} PLN'), findsOneWidget);
      expect(find.textContaining('Neon frame on the homepage'), findsOneWidget);
      expect(find.byKey(const Key('renew-use-credit')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('renew-tier-glow')));
      await tester.tap(find.byKey(const Key('renew-tier-glow')));
      await _settle(tester, 300);
      final promoPaid = TGFounderService.instance.discountedPrice(app.auth.userId, cfg.promoFeePln(PromotionTier.glow, promoDays));
      expect(find.text('Total (brutto, VAT 23% included): ${fee + promoPaid} PLN'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('renew-use-credit')));
      await tester.tap(find.byKey(const Key('renew-use-credit')));
      await _settle(tester, 300);
      expect(find.byKey(const Key('renew-credit-covers')), findsOneWidget);
      expect(find.text('Total (brutto, VAT 23% included): $fee PLN'), findsOneWidget);
      _expectNoErrors(app);
    });
  });
}
