import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/growth_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGAnalytics.reset();
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    ReferralRepository.instance.reset();
    GrowthService.instance.reset();
    TGBillingService.instance.reset();
    TGAdminConsoleService.instance.reset();
  });

  tearDown(() {
    TGRevenueConfigService.instance.reset();
    ReferralRepository.instance.reset();
    GrowthService.instance.reset();
    TGBillingService.instance.reset();
    TGClock.reset();
  });

  test('dynamic listing images stay disabled', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  group('targets math', () {
    test('percent, tempo and unique seller union', () {
      expect(GrowthService.pct(50, 100), 0.5);
      expect(GrowthService.pct(null, 100), isNull);
      expect(GrowthService.pct(10, 0), isNull);

      const cell = GrowthCell(min: 100, goal: 200);
      expect(GrowthService.tempo(cell: cell, actual: 100, elapsed: 0.5), GrowthTempo.ahead);
      expect(GrowthService.tempo(cell: cell, actual: 50, elapsed: 0.5), GrowthTempo.onTrack);
      expect(GrowthService.tempo(cell: cell, actual: 40, elapsed: 0.5), GrowthTempo.behind);
      expect(GrowthService.tempo(cell: const GrowthCell(text: 'Test paid conversion'), actual: 3, elapsed: 1), GrowthTempo.noTarget);
      expect(GrowthService.tempo(cell: cell, actual: 80, elapsed: null), GrowthTempo.noTarget);

      expect(GrowthService.revenueTempo(cell: const GrowthCell(min: 2000, goal: 5000), actual: 5000), GrowthTempo.ahead);
      expect(GrowthService.revenueTempo(cell: const GrowthCell(min: 2000, goal: 5000), actual: 2000), GrowthTempo.onTrack);
      expect(GrowthService.revenueTempo(cell: const GrowthCell(min: 2000, goal: 5000), actual: 100), GrowthTempo.behind);

      expect(GrowthService.uniqueSellerCount([['a', 'b'], ['b', 'c'], ['a']]), 3);
    });

    test('missing programStartDate freezes period math', () {
      final svc = GrowthService.instance..ensureSeeded();
      expect(svc.config.programStartDate, isNull);
      expect(svc.activePeriod(), isNull);
      expect(svc.elapsedRatio(GrowthPeriod.p0to3), isNull);
      expect(svc.rowsFor(GrowthPeriod.p0to3).every((r) => r.tempo == GrowthTempo.noTarget || r.metric == GrowthMetricId.monthlyRevenue), isTrue);
    });

    test('revenueBasis net vs gross from last complete month minus refunds', () {
      final actor = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.admin);
      final svc = GrowthService.instance..ensureSeeded();
      final now = TGClock.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      TGBillingService.instance.recordPayment(
        userId: 'store_1',
        kind: TGPaymentKind.store,
        description: 'store',
        grossPln: 123,
        at: lastMonth,
      );
      svc.setRevenueBasis(GrowthRevenueBasis.gross, actor: actor);
      expect(svc.lastCompleteMonthRevenue(), 123);
      svc.setRevenueBasis(GrowthRevenueBasis.net, actor: actor);
      expect(svc.lastCompleteMonthRevenue(), 100);
      final pay = TGBillingService.instance.allPayments().first;
      TGBillingService.instance.markRefunded(pay.id, 23);
      expect(svc.lastCompleteMonthRevenue(), lessThan(100));
    });

    test('Production Mode hides mock actuals and team rows', () {
      ReferralRepository.instance.ensureSeeded();
      GrowthService.instance.ensureSeeded();
      expect(ReferralRepository.instance.allRepresentatives(), isNotEmpty);

      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      ReferralRepository.instance.reset();
      GrowthService.instance.reset();
      GrowthService.instance.ensureSeeded();

      expect(ReferralRepository.instance.allRepresentatives(), isEmpty);
      expect(GrowthService.instance.teamRows(ReferralRepository.warsawWeekStart(TGClock.now())), isEmpty);
      final snap = GrowthService.instance.actuals();
      expect(snap.byMetric.values.every((m) => m.noData), isTrue);
      expect(snap.uniqueSellers, 0);
      expect(snap.hasSparkline, isFalse);
    });
  });

  group('team & roadmap', () {
    test('rep week metrics only count referredByRepId', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      final svc = GrowthService.instance..ensureSeeded();
      final week = ReferralRepository.warsawWeekStart(TGClock.now());
      final before = svc.teamRows(week).firstWhere((r) => r.rep.id == 'rep_marek').signups;
      repo.debugAddAccount(TGReferredAccount(
        userId: 'only_piotr',
        displayName: 'Only Piotr',
        segment: TGReferralSegment.individual,
        referredByCode: 'Piotr-CORP2026',
        referredByRepId: 'rep_piotr',
        referredAt: week.add(const Duration(hours: 3)),
        referralConsentAt: week.add(const Duration(hours: 3)),
        phoneVerified: true,
      ));
      expect(svc.teamRows(week).firstWhere((r) => r.rep.id == 'rep_marek').signups, before);
      expect(svc.teamRows(week).firstWhere((r) => r.rep.id == 'rep_piotr').signups, 1);
    });

    test('deactivating a code keeps the old assignment', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.debugAddAccount(TGReferredAccount(
        userId: 'kept',
        displayName: 'Kept',
        segment: TGReferralSegment.individual,
        referredByCode: 'Marek-IND2026',
        referredByRepId: 'rep_marek',
        referredAt: DateTime(2026, 1, 2),
        referralConsentAt: DateTime(2026, 1, 2),
      ));
      expect(repo.setRepStatus('rep_marek', TGRepStatus.inactive), isTrue);
      expect(repo.checkCode('Marek-IND2026').result, TGReferralCodeResult.unrecognized);
      expect(repo.accountOf('kept')?.referredByRepId, 'rep_marek');
      expect(repo.rawAccountsFor('rep_marek').any((a) => a.userId == 'kept'), isTrue);
    });

    test('assignment correction without a reason is rejected', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      expect(
        repo.adminCorrectReferral(userId: 'x', actorId: 'staff_admin', reason: '', newCode: 'Piotr-CORP2026'),
        'reason_required',
      );
    });

    test('roadmap month-end check persists and writes audit', () {
      final actor = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.admin);
      final svc = GrowthService.instance..ensureSeeded();
      expect(svc.roadmap, hasLength(8));
      svc.setMonthEndCheck('m1', done: true, note: 'first sellers live', actor: actor);
      expect(svc.roadmap.firstWhere((e) => e.id == 'm1').monthEndCheck?.done, isTrue);
      expect(svc.roadmap.firstWhere((e) => e.id == 'm1').monthEndCheck?.note, 'first sellers live');
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'growth_roadmap_check' && e.targetId == 'm1'), isTrue);

      final start = DateTime(TGClock.now().year, TGClock.now().month - 4, TGClock.now().day);
      svc.setProgramStart(start, actor: actor);
      expect(svc.isOverdue(svc.roadmap.firstWhere((e) => e.id == 'm2')), isTrue);
      expect(svc.isOverdue(svc.roadmap.firstWhere((e) => e.id == 'm1')), isFalse);
    });

    test('default weekly contact ranges match the PDF', () {
      final svc = GrowthService.instance..ensureSeeded();
      ReferralRepository.instance.ensureSeeded();
      final t = {for (final x in svc.targetsFor('rep_marek')) x.category: x};
      expect(t[TGRepContactCategory.individual]?.min, 30);
      expect(t[TGRepContactCategory.individual]?.goal, 50);
      expect(t[TGRepContactCategory.corporate]?.min, 10);
      expect(t[TGRepContactCategory.corporate]?.goal, 15);
      expect(t[TGRepContactCategory.restaurant]?.min, 5);
      expect(t[TGRepContactCategory.restaurant]?.goal, 10);
      expect(t[TGRepContactCategory.manufacturer]?.min, 5);
      expect(t[TGRepContactCategory.manufacturer]?.goal, 10);
    });
  });

  group('admin page', () {
    testWidgets('Moderator, Seller and Representative get 403; Admin sees the page', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/growth', size: TGSizes.desktop);
      expect(find.byKey(const Key('admin-403')), findsOneWidget);

      app.auth.setRole(TGUserRole.moderator);
      await tester.pump();
      expect(find.byKey(const Key('admin-403')), findsOneWidget);

      app.auth.actAsRepresentative(RepresentativeDevPick.marek);
      await tester.pump();
      expect(find.byKey(const Key('admin-403')), findsOneWidget);

      app.auth.setRole(TGUserRole.admin);
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(find.byKey(const Key('admin-403')), findsNothing);
      expect(find.byKey(const Key('admin-growth')), findsOneWidget);
      expect(find.byKey(const Key('admin-nav-growth')), findsOneWidget);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'growth_view'), isTrue);
      expect(TGAnalytics.has('growth_view'), isFalse);
      _ok(app);
    });

    testWidgets('frozen start date, no data copy, placeholders and 390 cards', (tester) async {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      final app = await pumpTgApp(tester, location: '/admin/growth', size: TGSizes.phone);
      app.auth.setRole(TGUserRole.admin);
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const Key('admin-growth')), findsOneWidget);
      expect(find.byKey(const Key('gr-no-start')), findsOneWidget);
      expect(find.byKey(const Key('gr-cards')), findsOneWidget);
      expect(find.byKey(const Key('gr-table')), findsNothing);
      expect(find.textContaining('No data yet'), findsWidgets);

      app.router.go('/admin/growth?tab=weekly');
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(find.byKey(const Key('gr-weekly')), findsOneWidget);
      expect(TGAdminConsoleService.instance.audit.where((e) => e.action == 'growth_view').length, greaterThanOrEqualTo(2));
      _ok(app);
    });
  });
}

void _ok(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
