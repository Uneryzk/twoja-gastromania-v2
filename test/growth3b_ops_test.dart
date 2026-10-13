import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/growth_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGAnalytics.reset();
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    PricingConfigService.instance.resetForTests();
    ReferralRepository.instance.reset();
    GrowthService.instance.reset();
    TGBillingService.instance.reset();
    TGAdminConsoleService.instance.reset();
  });

  tearDown(() {
    TGRevenueConfigService.instance.reset();
    GrowthService.instance.reset();
    ReferralRepository.instance.reset();
    TGBillingService.instance.reset();
    TGClock.reset();
  });

  FakeAuthState admin() => FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.admin);

  test('dynamic listing images stay disabled', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  group('grosz', () {
    test('net from gross is integer-only and matches PDF / current prices', () {
      expect(GrowthMoney.netFromGross(616500), GrowthScenario.pdfNetGrosz);
      expect(GrowthScenario.pdfExample.grossGrosz, GrowthScenario.pdfGrossGrosz);
      expect(GrowthScenario.pdfExample.netGrosz, 501220);
      expect(GrowthMoney.format(501220), '5 012,20 PLN');

      final current = GrowthScenario.pdfExample.copyWith(priceProGrosz: 49900);
      expect(current.grossGrosz, GrowthScenario.currentGrossGrosz);
      expect(current.netGrosz, GrowthScenario.currentNetGrosz);
      expect(GrowthMoney.netFromGross(666500), 541870);
      expect(GrowthMoney.format(541870), '5 418,70 PLN');
    });

    test('Payment.netGr is used; refunds deducted; failed is ignored', () {
      final billing = TGBillingService.instance;
      final now = TGClock.now();
      final paid = billing.recordPayment(
        userId: 'u1',
        kind: TGPaymentKind.listing,
        description: 'listing',
        grossPln: 123,
        at: now,
      );
      billing.recordPayment(
        userId: 'u2',
        kind: TGPaymentKind.listing,
        description: 'fail',
        grossPln: 200,
        status: TGPaymentStatus.failed,
        at: now,
      );
      final pair = GrowthService.collectedGrosz(paid, 0);
      expect(pair.$1, paid.amount.grossGr);
      expect(pair.$2, paid.amount.netGr);
      expect(pair.$2, 10000);

      billing.markRefunded(paid.id, 23);
      final after = GrowthService.collectedGrosz(paid, billing.refundedGrosz(paid.id));
      expect(after.$1, 10000);
      expect(after.$2, lessThan(pair.$2));

      final svc = GrowthService.instance..ensureSeeded();
      final snap = svc.actualStreams(GrowthRevWindow.thisMonth);
      expect(snap.hasSource, isTrue);
      expect(snap.byStream[GrowthRevStreamId.extraListings]!.grossGrosz, 10000);
      expect(snap.netGrosz, after.$2);
    });

    test('scenario never mixes into Actual or Tab 1', () {
      final actor = admin();
      final svc = GrowthService.instance..ensureSeeded();
      final before = svc.actuals().byMetric[GrowthMetricId.monthlyRevenue];
      final actualBefore = svc.actualStreams(GrowthRevWindow.thisMonth);
      svc.saveScenario(GrowthScenario.pdfExample, actor: actor);
      expect(svc.scenarios, isNotEmpty);
      expect(svc.actualStreams(GrowthRevWindow.thisMonth).netGrosz, actualBefore.netGrosz);
      expect(svc.actuals().byMetric[GrowthMetricId.monthlyRevenue]?.value, before?.value);
      expect(svc.actuals().byMetric[GrowthMetricId.monthlyRevenue]?.hasSource, before?.hasSource);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'scenario_save'), isTrue);
      expect(TGAnalytics.has('scenario_save'), isFalse);
    });
  });

  group('budget', () {
    test('phase is assigned from expense date and program start', () {
      final actor = admin();
      final svc = GrowthService.instance..ensureSeeded();
      final start = DateTime(2026, 1, 1);
      svc.setProgramStart(start, actor: actor);
      expect(svc.phaseIdForDate(DateTime(2026, 2, 1)), 'bp-0-3');
      expect(svc.phaseIdForDate(DateTime(2026, 5, 1)), 'bp-3-6');
      expect(svc.phaseIdForDate(DateTime(2026, 10, 1)), 'bp-6-12');
    });

    test('80% and 100% warnings; void keeps the row and requires a reason', () {
      final actor = admin();
      final svc = GrowthService.instance..ensureSeeded();
      expect(
        svc.addExpense(
          GrowthExpense(
            id: '',
            date: TGClock.now(),
            amountGrosz: 768000,
            basis: GrowthRevenueBasis.net,
            category: GrowthExpenseCategory.legal,
            phaseId: 'bp-0-3',
            description: 'legal',
            createdBy: actor.userId,
          ),
          actor: actor,
        ),
        isNull,
      );
      expect(svc.phaseView(svc.phases.first).warn80, isTrue);
      expect(svc.phaseView(svc.phases.first).warn100, isFalse);
      expect(TGAnalytics.has('budget_expense_add'), isTrue);

      expect(
        svc.addExpense(
          GrowthExpense(
            id: '',
            date: TGClock.now(),
            amountGrosz: 200000,
            basis: GrowthRevenueBasis.net,
            category: GrowthExpenseCategory.legal,
            phaseId: 'bp-0-3',
            description: 'more',
            createdBy: actor.userId,
          ),
          actor: actor,
        ),
        'overrun_note_required',
      );
      expect(
        svc.addExpense(
          GrowthExpense(
            id: '',
            date: TGClock.now(),
            amountGrosz: 200000,
            basis: GrowthRevenueBasis.net,
            category: GrowthExpenseCategory.legal,
            phaseId: 'bp-0-3',
            description: 'more',
            createdBy: actor.userId,
            overrunNote: 'accepted overrun',
          ),
          actor: actor,
        ),
        isNull,
      );
      expect(svc.phaseView(svc.phases.first).warn100, isTrue);

      final id = svc.expenses.where((e) => !e.isMock).first.id;
      expect(svc.voidExpense(id, reason: '', actor: actor), 'reason_required');
      expect(svc.voidExpense(id, reason: 'duplicate', actor: actor), isNull);
      expect(svc.expenses.any((e) => e.id == id && e.voided), isTrue);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'budget_expense_void'), isTrue);
    });

    test('6-12 commit without a note is rejected', () {
      final actor = admin();
      final svc = GrowthService.instance..ensureSeeded();
      expect(svc.commitPhase('bp-6-12', note: '', actor: actor), 'reason_required');
      expect(svc.phases.last.commitment, BudgetCommitment.notCommitted);
      expect(svc.commitPhase('bp-6-12', note: 'channels verified', actor: actor), isNull);
      expect(svc.phases.last.commitment, BudgetCommitment.committed);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'budget_commit'), isTrue);
    });
  });

  group('weekly', () {
    test('auto numbers match Tab 2 queries; lock after 7 days', () {
      final actor = admin();
      final repo = ReferralRepository.instance..ensureSeeded();
      final svc = GrowthService.instance..ensureSeeded();
      final week = ReferralRepository.warsawWeekStart(TGClock.now());
      repo.debugAddAccount(TGReferredAccount(
        userId: 'w1',
        displayName: 'Ada',
        segment: TGReferralSegment.individual,
        referredByCode: 'Marek-IND2026',
        referredByRepId: 'rep_marek',
        referredAt: week.add(const Duration(hours: 2)),
        referralConsentAt: week.add(const Duration(hours: 2)),
        phoneVerified: true,
        listings: const [TGRefListingMeta(id: 'l1', title: 'X', listingNo: '1', photos: 3, completionPct: 80)],
      ));
      final rows = svc.teamRows(week);
      final marek = rows.firstWhere((r) => r.rep.id == 'rep_marek');
      final auto = svc.weekAuto(week);
      expect(auto.signups, rows.fold<int>(0, (a, r) => a + r.signups));
      expect(auto.won, rows.fold<int>(0, (a, r) => a + r.won));
      expect(auto.signups, greaterThanOrEqualTo(marek.signups));

      expect(
        svc.saveMeeting(
          GrowthWeeklyMeeting(
            id: '',
            weekStart: week,
            heldAt: TGClock.now(),
            attendees: const ['admin'],
            q1Note: '',
            q2Note: '',
            q3Note: '',
            q4Note: '',
            q5Problem: 'focus referrals',
            q5Channel: GrowthMeetChannel.referrals,
            q5Owner: 'Marek',
            decisions: 'keep',
            actionItems: const [],
            createdBy: actor.userId,
            lockedAt: TGClock.now().add(const Duration(days: 7)),
            snapshot: auto,
          ),
          actor: actor,
        ),
        isNull,
      );
      final saved = svc.meetingForWeek(week)!;
      expect(saved.isLocked(TGClock.now()), isFalse);
      TGClock.advance(const Duration(days: 7));
      expect(saved.isLocked(TGClock.now()), isTrue);
      expect(svc.saveMeeting(saved, actor: actor), 'locked');
      expect(svc.amendMeeting(saved.id, 'late note', actor: actor), isNull);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'meeting_save'), isTrue);
      expect(TGAnalytics.has('meeting_save'), isTrue);
    });
  });

  group('production & access', () {
    test('Production Mode hides sample expenses and meetings', () {
      GrowthService.instance.ensureSeeded();
      expect(GrowthService.instance.expenses.any((e) => e.isMock), isTrue);

      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      GrowthService.instance.reset();
      GrowthService.instance.ensureSeeded();
      expect(GrowthService.instance.expenses, isEmpty);
      expect(GrowthService.instance.meetings, isEmpty);
      expect(GrowthService.instance.phases, hasLength(3));
      expect(GrowthService.instance.phases.fold<int>(0, (a, p) => a + p.plannedGrosz), 9120000);
    });

    testWidgets('Moderator and Seller get 403 on revenue tab', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/growth?tab=revenue', size: TGSizes.desktop);
      expect(find.byKey(const Key('admin-403')), findsOneWidget);
      app.auth.setRole(TGUserRole.moderator);
      await tester.pump();
      expect(find.byKey(const Key('admin-403')), findsOneWidget);
      app.auth.setRole(TGUserRole.admin);
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(find.byKey(const Key('admin-growth')), findsOneWidget);
      expect(find.byKey(const Key('gr-revenue')), findsOneWidget);
      expect(find.byKey(const Key('gr-scenario')), findsOneWidget);
      expect(TGAdminConsoleService.instance.audit.any((e) => e.action == 'growth_view' && e.targetId == 'revenue'), isTrue);
      expect(TGAnalytics.has('growth_view'), isFalse);
      app.errors.stop();
      expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
    });
  });
}
