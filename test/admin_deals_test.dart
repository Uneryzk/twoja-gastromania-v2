import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    DealService.instance.reset();
    DealModerationService.instance.reset();
    ModerationService.instance.reset();
  });

  test('seeds 12 deal cases without growing DealService.deals', () {
    final svc = DealModerationService.instance..ensureSeeded();
    expect(svc.cases, hasLength(12));
    expect(svc.count(TGDealQueueKind.objection), 5);
    expect(svc.count(TGDealQueueKind.flagged), 4);
    expect(svc.count(TGDealQueueKind.dispute), 1);
    expect(svc.count(TGDealQueueKind.appeal), 2);
    expect(DealService.instance.deals, hasLength(18));
    expect(svc.byDealNo('D-2026-000210')!.evidence.any((e) => e.type == TGEvidenceType.liveVideo), isTrue);
    expect(svc.byDealNo('D-2026-000206')!.noEvidence, isTrue);
    expect(svc.byDealNo('D-2026-000301')!.priority, TGModerationPriority.high);
    expect(svc.byDealNo('D-2026-000302')!.evidence.any((e) => e.type == TGEvidenceType.paymentTrace), isTrue);
    expect(svc.byDealNo('D-2026-000303')!.photoOnlyRejected, isTrue);
    expect(svc.byDealNo('D-2026-000307')!.flags, contains(TGDealRiskFlag.reciprocal));
    final dispute = svc.byDealNo('D-2026-000123')!;
    expect(dispute.priority, TGModerationPriority.high);
    expect(dispute.decisionDueAt.difference(dispute.createdAt), const Duration(hours: 24));
  });

  test('Deal No. search resolves; 8-digit listing search stays listing', () {
    final svc = DealModerationService.instance..ensureSeeded();
    expect(svc.resolveSearch('D-2026-000123'), 'D-2026-000123');
    expect(ModerationService.instance.resolveSearch('10482137'), '10482137');
    expect(svc.resolveSearch('10482137'), isNull);
  });

  test('appeals cannot be assigned to the moderator who removed the review', () {
    final svc = DealModerationService.instance..ensureSeeded();
    final appeal = svc.byDealNo('D-2026-000208')!;
    expect(svc.canAssign(appeal, DealModerationService.moderatorId), isFalse);
    expect(svc.canAssign(appeal, DealModerationService.adminId), isTrue);
  });

  test('hard cap with evidence marks review not_verified and keeps the case High', () {
    final svc = DealModerationService.instance..ensureSeeded();
    final c = svc.byDealNo('D-2026-000301')!;
    TGClock.advance(const Duration(days: 2));
    svc.onClockAdvanced();
    expect(c.hardCapBreached, isTrue);
    expect(c.reviewState, TGPurchaseReviewState.notVerified);
    expect(c.priority, TGModerationPriority.high);
    expect(c.statusLabel, 'Hard cap breached');
  });

  test('human decision writes audit; no automatic suggestion field', () {
    final svc = DealModerationService.instance..ensureSeeded();
    final c = svc.byDealNo('D-2026-000210')!;
    svc.decide(c, decision: TGObjectionDecision.confirmed, rationale: 'Video matches 4827', markSold: true, actorId: 'staff_moderator', actorRole: 'moderator');
    expect(c.statusLabel, 'Confirmed');
    expect(ModerationService.instance.audit.first.summary, contains('Decision'));
    expect(TGAnalytics.has('admin_deal_decision'), isTrue);
    svc.undo(actorId: 'staff_moderator', actorRole: 'moderator');
    expect(TGAnalytics.has('admin_undo'), isTrue);
  });

  testWidgets('moderator opens Deals queue at 1280 with Objections', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/deals', size: const Size(1280, 900));
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('Deals'), findsWidgets);
    expect(find.textContaining('Objections'), findsWidgets);
    expect(find.text('D-2026-000210'), findsWidgets);
    expect(find.text('Deal No.'), findsOneWidget);
    _ok(app);
  });

  testWidgets('Deal No. enter on admin search opens the case', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('admin-search')), 'D-2026-000123');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/admin/d/D-2026-000123');
    expect(TGAnalytics.has('admin_deal_open'), isTrue);
    expect(find.text('D-2026-000123'), findsWidgets);
    _ok(app);
  });

  testWidgets('8-digit search is unchanged', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('admin-search')), '10482137');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/admin/l/10482137');
    _ok(app);
  });

  testWidgets('390px deals queue is cards; case has sticky actions', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/deals', size: TGSizes.phone);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('admin-deal-card-D-2026-000210')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-deal-card-D-2026-000210')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/admin/d/D-2026-000210');
    expect(find.byKey(const Key('admin-deal-decide')), findsWidgets);
    _ok(app);
  });

  testWidgets('decide requires rationale and writes the decision', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/d/D-2026-000210', size: const Size(1280, 900));
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('admin-deal-decide')));
    await tester.tap(find.byKey(const Key('admin-deal-decide')));
    await tester.pump();
    expect(find.byKey(const Key('admin-deal-decide-confirm')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('admin-deal-rationale')), 'Live video matches the expected code.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-deal-decide-confirm')));
    await tester.pump();
    expect(DealModerationService.instance.byDealNo('D-2026-000210')!.statusLabel, 'Confirmed');
    expect(find.textContaining('Undo'), findsWidgets);
    _ok(app);
  });
}

void _ok(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
