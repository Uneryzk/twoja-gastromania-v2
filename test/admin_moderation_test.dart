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

  test('seed has 14 reports, 3 copy matches, 1 fraud high case, 2 appeals', () {
    final mod = ModerationService.instance..ensureSeeded();
    expect(mod.reports.where((r) => r.reportNo.startsWith('RP-')), hasLength(14));
    expect(mod.reports.where((r) => r.reportNo.startsWith('R-2026-')), hasLength(15));
    expect(mod.photoMatches, hasLength(3));
    expect(mod.appeals.where((a) => !a.resolved), hasLength(2));
    final fraud = mod.caseFor('10482137')!;
    expect(fraud.priority, TGModerationPriority.high);
    expect(fraud.reportCount, 3);
    expect(fraud.reporterIds, hasLength(3));
  });

  test('priority: promoted or 3 reporters is High; duplicate is Medium; sold is Low', () {
    final mod = ModerationService.instance..ensureSeeded();
    expect(mod.caseFor('10482137')!.priority, TGModerationPriority.high);
    expect(mod.caseFor('11820463')!.priority, TGModerationPriority.medium);
    expect(mod.caseFor('22614059')!.priority, TGModerationPriority.low);
  });

  test('SLA is amber at 80% and overdue after High 24h', () {
    final mod = ModerationService.instance..ensureSeeded();
    final overdue = mod.caseFor('26058493')!;
    expect(overdue.priority, TGModerationPriority.high);
    expect(overdue.slaTone(), TGSlaTone.overdue);
    final amber = mod.caseFor('14120395')!;
    expect(amber.priority, TGModerationPriority.high);
    expect(amber.slaTone(), TGSlaTone.warning);
  });

  test('8-digit search resolves to a case listing number', () {
    final mod = ModerationService.instance..ensureSeeded();
    expect(mod.resolveSearch('10482137'), '10482137');
    expect(mod.resolveSearch('RP-24011'), '10482137');
    expect(mod.resolveSearch('biuro@primegastro.pl'), '10482137');
  });

  testWidgets('seller hitting /admin sees 403', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.desktop);
    expect(find.byKey(const Key('admin-403')), findsOneWidget);
    expect(find.textContaining('403'), findsWidgets);
    _ok(app);
  });

  testWidgets('moderator opens queue at 1280px with grouped fraud row', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: const Size(1280, 900));
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('admin-403')), findsNothing);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('10482137'), findsWidgets);
    expect(find.text('Report No.'), findsOneWidget);
    expect(find.textContaining('New'), findsWidgets);
    expect(find.text('Moderator'), findsWidgets);
    _ok(app);
  });

  testWidgets('8-digit enter on admin search opens /admin/l/10482137', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('admin-search')), '10482137');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/admin/l/10482137');
    expect(TGAnalytics.has('admin_case_open'), isTrue);
    expect(find.text('Open public page'), findsOneWidget);
    _ok(app);
  });

  testWidgets('moderator can dismiss; cannot restore; admin can restore', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/l/10482137', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('admin-action-restore')), findsNothing);
    expect(find.byKey(const Key('admin-action-suspend')), findsNothing);
    await tester.tap(find.byKey(const Key('admin-action-dismiss')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-dismiss-confirm')));
    await tester.pump();
    expect(ModerationService.instance.caseFor('10482137')!.status, TGReportStatus.resolvedNoViolation);
    expect(ModerationService.instance.audit, isNotEmpty);
    expect(TGAnalytics.has('admin_action'), isTrue);

    app.auth.setRole(TGUserRole.admin);
    await tester.pump();
    expect(find.byKey(const Key('admin-action-restore')), findsOneWidget);
    _ok(app);
  });

  testWidgets('remove shows undo toast and audit; undo restores', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/l/11820463', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('admin-action-remove')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-remove-confirm')));
    await tester.pump();
    expect(find.text('Listing removed · Undo'), findsOneWidget);
    final product = await TGProductService.instance.getById('11820463');
    expect(product!.status, TGListingStatus.removed);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(TGAnalytics.has('admin_undo'), isTrue);
    final restored = await TGProductService.instance.getById('11820463');
    expect(restored!.status, isNot(TGListingStatus.removed));
    _ok(app);
  });

  testWidgets('390px queue is cards and case has a bottom action bar', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.phone);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('Report No.'), findsNothing);
    expect(find.byKey(const Key('admin-queue-card-10482137')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-queue-card-10482137')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(app.location, '/admin/l/10482137');
    expect(find.byKey(const Key('admin-action-remove')), findsOneWidget);
    _ok(app);
  });

  testWidgets('staff PDP shows moderator bar', (tester) async {
    final app = await pumpTgApp(tester, location: '/product-detail/p001', size: TGSizes.desktop);
    expect(find.byKey(const Key('pdp-moderator-bar')), findsNothing);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    expect(find.byKey(const Key('pdp-moderator-bar')), findsOneWidget);
    expect(find.textContaining('Moderator view'), findsOneWidget);
    expect(find.text('Open case'), findsOneWidget);
    _ok(app);
  });

  testWidgets('admin language switcher changes chrome from EN to TR instantly', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('admin-lang-switcher')), findsOneWidget);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Report No.'), findsOneWidget);
    expect(find.text('Dismiss'), findsNothing);
    await tester.tap(find.byKey(const Key('admin-lang-tr')));
    await tester.pump();
    expect(find.text('Kuyruk'), findsWidgets);
    expect(find.text('Rapor No.'), findsOneWidget);
    expect(find.text('Öncelik'), findsWidgets);
    expect(find.text('Durum'), findsWidgets);
    expect(find.text('Geçen Süre'), findsWidgets);
    expect(find.text('Atanan'), findsWidgets);
    await tester.tap(find.byKey(const Key('admin-lang-en')));
    await tester.pump();
    expect(find.text('Queue'), findsWidgets);
    _ok(app);
  });

  testWidgets('report text stays Polish until Translate to English', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/l/10482137', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.textContaining('Sprzedający poprosił o przelew BLIK'), findsWidgets);
    expect(find.byKey(const Key('admin-report-translate-en-RP-24012')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-report-translate-en-RP-24012')));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('BLIK transfer to a private number'), findsWidgets);
    expect(find.text('Show original'), findsOneWidget);
    await tester.tap(find.text('Show original'));
    await tester.pump();
    expect(find.textContaining('Sprzedający poprosił o przelew BLIK'), findsWidgets);
    _ok(app);
  });

  testWidgets('templates route is 403 for moderator and open for admin', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/templates', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    expect(find.byKey(const Key('admin-403')), findsOneWidget);
    app.auth.setRole(TGUserRole.admin);
    await tester.pump();
    expect(find.byKey(const Key('admin-403')), findsNothing);
    expect(find.text('Templates'), findsWidgets);
    _ok(app);
  });
}

void _ok(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
