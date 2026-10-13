import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';
import 'package:twoja_gastromania/tg_services/account_settings_service.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

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

FakeAuthState _staff(TGUserRole role) => FakeAuthState(isLoggedIn: true)..setRole(role, notify: false);

void _resetAll() {
  TGClock.reset();
  TGAnalytics.reset();
  TGRevenueConfigService.instance.reset();
  TGBillingService.instance.reset();
  TGVerificationService.instance.reset();
  TGAccountSettingsService.instance.reset();
  TGAdminConsoleService.instance.reset();
  MessagingService.instance.reset();
  AccountIdentityService.instance.reset();
}

/// All auto checks green (used to test the switch itself; the real list is
/// still blocked by the draft photo licence clause).
final _greenChecks = [
  (id: 'phase', labelKey: 'ui_golive_phase', ok: true, blocking: true),
  (id: 'photo_license_clause', labelKey: 'ui_golive_photo_license', ok: true, blocking: true),
];

void main() {
  setUp(_resetAll);
  tearDown(_resetAll);

  group('DASH-4 helpers', () {
    test('public name is "Marek K." and contact data is masked', () {
      expect(tgPublicName('Marek', 'Kowalski'), 'Marek K.');
      expect(tgPublicName(' Ewa ', ''), 'Ewa');
      expect(tgMaskEmail('hello@gastropl.pl'), 'h••••@g•••••••.pl');
      expect(tgMaskPhone('+48 601 222 111'), '+48 ••• ••• 111');
      expect(tgMaskPhone('601222111'), '••• ••• 111');
    });
  });

  group('Verification centre', () {
    test('NIP: checksum, register lookup and representation are all enforced', () {
      final v = TGVerificationService.instance;
      expect(v.submitCompany(userId: 'u1', nip: '1234567890', representativeName: 'Jan', confirmedRepresentation: true).error, 'ver_err_nip');
      expect(v.submitCompany(userId: 'u1', nip: '1133009087', representativeName: 'Jan Nowak', confirmedRepresentation: true).error,
          'ver_err_registry_not_found');
      expect(v.submitCompany(userId: 'u1', nip: '872-555-21-04', representativeName: 'Jan Nowak', confirmedRepresentation: true).error,
          'ver_err_registry_inactive');
      expect(v.submitCompany(userId: 'u1', nip: '6761005675', representativeName: 'Marek Kowalski', confirmedRepresentation: false).error,
          'ver_err_rep_confirm');
      final ok = v.submitCompany(userId: 'u1', nip: '676-100-56-75', representativeName: 'Marek Kowalski', confirmedRepresentation: true);
      expect(ok.error, isNull);
      expect(ok.app!.status, TGVerifyStatus.pending);
      expect(ok.app!.registry.register, 'CEIDG');
      expect(ok.app!.representativeListed, isTrue);
      expect(_ev('verification_submit').single['kind'], 'company');
      expect(v.submitCompany(userId: 'u1', nip: '6761005675', representativeName: 'Marek Kowalski', confirmedRepresentation: true).error,
          'ver_err_pending');
    });

    test('green shield needs NIP verification AND an active store plan', () {
      final v = TGVerificationService.instance;
      final user = FakeAuthState(isLoggedIn: true);
      v.submitCompany(userId: user.userId, nip: '7771234567', representativeName: 'Ewa Nowak', confirmedRepresentation: true);
      final app = v.companyFor(user.userId)!;

      expect(v.decide(app.id, actor: user, approve: true), 'adm_err_staff');
      final mod = _staff(TGUserRole.moderator);
      expect(v.decide(app.id, actor: mod, approve: false, note: 'short'), 'adm_err_reason');
      expect(v.decide(app.id, actor: mod, approve: true), isNull);
      expect(v.isNipVerified(user.userId), isTrue);
      expect(_ev('verification_decision').single['approved'], isTrue);
      expect(TGAdminConsoleService.instance.audit.first.action, 'verification_decision');

      user.storePlan = null;
      expect(v.isVerifiedSeller(user), isFalse, reason: 'NIP alone is not enough');
      user.storePlan = TGStorePlanKind.pro;
      expect(v.isVerifiedSeller(user), isTrue);
    });

    test('phone change: format, conflict-free SMS code, then phone_change event', () {
      final v = TGVerificationService.instance;
      final auth = FakeAuthState(isLoggedIn: true)..phoneVerified = false;
      expect(v.startPhoneChange(auth.userId, '12345'), 'ver_err_phone_format');
      expect(v.startPhoneChange(auth.userId, '+48 731 905 448'), isNull);
      expect(v.confirmPhone(auth.userId, '000000', auth: auth), 'ver_err_code');
      expect(v.confirmPhone(auth.userId, TGVerificationService.mockCode, auth: auth), isNull);
      expect(v.phoneOf(auth.userId).value, '+48 731 905 448');
      expect(auth.phoneVerified, isTrue);
      expect(_ev('phone_change'), hasLength(1));
    });
  });

  group('Settings & privacy', () {
    test('password rules and 2FA mock', () {
      final s = TGAccountSettingsService.instance;
      expect(s.changePassword('u', current: 'nope', next: 'Abcdefgh12', confirm: 'Abcdefgh12'), 'set_err_pw_current');
      expect(s.changePassword('u', current: TGAccountSettingsService.mockPassword, next: 'short1', confirm: 'short1'), 'set_err_pw_weak');
      expect(s.changePassword('u', current: TGAccountSettingsService.mockPassword, next: 'Abcdefgh12', confirm: 'Abcdefgh13'), 'set_err_pw_match');
      expect(s.changePassword('u', current: TGAccountSettingsService.mockPassword, next: 'Abcdefgh12', confirm: 'Abcdefgh12'), isNull);
      s.startTwoFa('u');
      expect(s.confirmTwoFa('u', '111111'), 'ver_err_code');
      expect(s.confirmTwoFa('u', '123456'), isNull);
      expect(s.twoFaEnabled('u'), isTrue);
      expect(s.backupCodes('u'), hasLength(8));
    });

    test('data export is JSON, one per 24 h, and emits data_export_request', () {
      final s = TGAccountSettingsService.instance;
      final auth = FakeAuthState(isLoggedIn: true);
      final r = s.requestExport(auth);
      expect(r.error, isNull);
      expect(r.export!.json, contains('"userId": "${auth.userId}"'));
      expect(s.requestExport(auth).error, 'set_err_export_cooldown');
      TGClock.advance(const Duration(hours: 25));
      expect(s.requestExport(auth).error, isNull);
      expect(_ev('data_export_request'), hasLength(2));
    });

    test('delete account: prerequisites, 7-day wait, cancellable', () {
      final s = TGAccountSettingsService.instance;
      final store = FakeAuthState(isLoggedIn: true)..actAsStoreOwner(StoreOwnerDevPick.gastroPro);
      TGBillingService.instance.seedMocks(store);
      expect(s.deleteChecks(store).firstWhere((c) => c.id == 'subscriptions').ok, isFalse);
      expect(s.requestDeletion(store, confirmText: 'DELETE'), 'set_err_del_blocked');

      final user = FakeAuthState(isLoggedIn: true)..actAsBuyer(BuyerDevPick.marek);
      expect(s.deleteChecks(user).every((c) => c.ok), isTrue);
      expect(s.requestDeletion(user, confirmText: 'nope'), 'set_err_del_confirm');
      expect(s.requestDeletion(user, confirmText: 'USUŃ'), isNull);
      final d = s.deletionOf(user.userId)!;
      expect(d.effectiveAt.difference(d.requestedAt), const Duration(days: 7));
      expect(_ev('account_delete_request').single['graceDays'], 7);
      s.cancelDeletion(user.userId);
      expect(s.deletionOf(user.userId), isNull);
    });
  });

  group('Admin console service', () {
    test('mock set: 3 applications, 2 conversation reports, 6 users, 5 refunds; hidden in production', () {
      final c = TGAdminConsoleService.instance..ensureSeeded();
      expect(TGVerificationService.instance.queue(), hasLength(3));
      expect(c.conversationReports(), hasLength(2));
      expect(c.users(), hasLength(6));
      expect(c.refunds(), hasLength(5));
      expect(c.refunds().where((r) => r.status == TGRefundStatus.pending), hasLength(3));

      TGRevenueConfigService.instance.setProductionMode(true, actorId: 'test', reason: 'unit');
      expect(TGVerificationService.instance.queue(), isEmpty);
      expect(c.conversationReports(), isEmpty);
      expect(c.users(), isEmpty);
      expect(c.refunds(), isEmpty);
    });

    test('reveal needs staff + reason, is logged, audit is append-only and CSV is admin-only', () {
      final c = TGAdminConsoleService.instance..ensureSeeded();
      final mod = _staff(TGUserRole.moderator);
      final seller = FakeAuthState(isLoggedIn: true);
      expect(c.reveal(actor: seller, userId: 'usr_anna', field: TGPiiField.email, reason: 'Needed for a complaint'), 'adm_err_staff');
      expect(c.reveal(actor: mod, userId: 'usr_anna', field: TGPiiField.email, reason: 'why'), 'adm_err_reason');
      expect(c.display(mod, 'usr_anna', TGPiiField.email, 'anna.w@example.pl'), isNot(contains('anna.w')));
      expect(c.reveal(actor: mod, userId: 'usr_anna', field: TGPiiField.email, reason: 'Buyer asked to correct the address'), isNull);
      expect(c.display(mod, 'usr_anna', TGPiiField.email, 'anna.w@example.pl'), 'anna.w@example.pl');
      expect(c.display(_staff(TGUserRole.admin), 'usr_anna', TGPiiField.email, 'anna.w@example.pl'), isNot(contains('anna.w')),
          reason: 'a reveal is per staff member');
      expect(_ev('admin_reveal').single['field'], 'email');

      final audit = c.audit;
      expect(audit.first.action, 'reveal');
      expect(() => audit.add(audit.first), throwsUnsupportedError);
      expect(() => audit.removeAt(0), throwsUnsupportedError);

      expect(c.exportAuditCsv(mod), isNull);
      final csv = c.exportAuditCsv(_staff(TGUserRole.admin))!;
      expect(csv.split('\n').first, 'at,actor,role,action,target,reason,details');
      expect(csv, contains('reveal'));
      expect(c.audit.first.action, 'audit_export');
    });

    test('refunds: admin only, partial amounts up to the gross fee, admin_refund event', () {
      final c = TGAdminConsoleService.instance..ensureSeeded();
      final req = c.refunds().firstWhere((r) => r.id == 'RF-mock-3');
      final pay = TGBillingService.instance.paymentById(req.paymentId)!;
      final admin = _staff(TGUserRole.admin);
      expect(c.refund(actor: _staff(TGUserRole.moderator), paymentId: pay.id, amountPln: 10, reason: 'Partial goodwill refund'), 'adm_err_admin_only');
      expect(c.refund(actor: admin, paymentId: pay.id, amountPln: pay.grossPln + 1, reason: 'Partial goodwill refund'), 'adm_err_amount');
      expect(c.refund(actor: admin, paymentId: pay.id, amountPln: req.amountPln, reason: 'Restaurant closed, half refund', requestId: req.id), isNull);
      expect(req.status, TGRefundStatus.approved);
      expect(TGBillingService.instance.refundedPln(pay.id), 74.5);
      expect(TGBillingService.instance.paymentById(pay.id)!.status, TGPaymentStatus.succeeded);
      expect(c.refund(actor: admin, paymentId: pay.id, amountPln: 74.5, reason: 'Rest of the fee returned'), isNull);
      expect(TGBillingService.instance.paymentById(pay.id)!.status, TGPaymentStatus.refunded);
      expect(_ev('admin_refund'), hasLength(2));
      expect(_ev('admin_refund').first['partial'], isTrue);
    });

    test('full conversation opens only with a logged reason', () {
      final c = TGAdminConsoleService.instance..ensureSeeded();
      final mod = _staff(TGUserRole.moderator);
      expect(c.openedThread(mod, 'CR-mock-1'), isNull);
      expect(c.openFullConversation(actor: mod, reportId: 'CR-mock-1', reason: 'x'), 'adm_err_reason');
      expect(c.openFullConversation(actor: mod, reportId: 'CR-mock-1', reason: 'Need context for the scam claim'), isNull);
      expect(c.openedThread(mod, 'CR-mock-1'), hasLength(3));
      expect(c.openedThread(_staff(TGUserRole.admin), 'CR-mock-1'), isNull);
      expect(c.audit.first.action, 'conversation_open');
    });

    test('go-live: blocked by the draft photo licence clause; switch works when every check passes', () {
      final c = TGAdminConsoleService.instance;
      final admin = _staff(TGUserRole.admin);
      expect(c.goLiveBlockers(), contains('photo_license_clause'));
      expect(c.switchToProduction(actor: admin, reason: 'Launch approved by board'), 'adm_err_blockers');
      expect(c.switchToProduction(actor: _staff(TGUserRole.moderator), reason: 'Launch approved by board', checks: _greenChecks), 'adm_err_admin_only');
      for (final id in TGAdminConsoleService.manualCheckIds) {
        c.setManual(actor: admin, id: id, done: true);
      }
      expect(c.goLiveBlockers(_greenChecks), isEmpty);
      expect(c.switchToProduction(actor: admin, reason: 'Launch approved by board', checks: _greenChecks), isNull);
      expect(TGRevenueConfigService.instance.productionMode, isTrue);
      expect(_ev('golive_switch'), hasLength(1));
      expect(c.audit.first.action, 'golive_switch');
    });
  });

  group('DASH-4 UI', () {
    testWidgets('non-staff get 403 on /admin/today; moderators cannot open payments or go-live', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/today', size: TGSizes.desktop);
      expect(find.byKey(const Key('admin-403')), findsOneWidget);

      app.auth.setRole(TGUserRole.moderator);
      await _settle(tester);
      expect(find.byKey(const Key('adm-today')), findsOneWidget);
      expect(find.byKey(const Key('adm-today-card-nip')), findsOneWidget);
      expect(find.byKey(const Key('adm-today-card-refunds')), findsNothing);

      for (final path in ['/admin/payments', '/admin/go-live']) {
        app.router.go(path);
        await _settle(tester);
        expect(find.byKey(const Key('admin-403')), findsOneWidget, reason: path);
      }
      app.auth.setRole(TGUserRole.admin);
      await _settle(tester);
      expect(find.byKey(const Key('adm-golive')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('user 360°: data masked, Reveal asks for a reason and lands in the access log', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/users/usr_marek', size: const Size(1280, 1100));
      app.auth.setRole(TGUserRole.moderator);
      await _settle(tester);
      final email = find.byKey(const Key('adm-pii-usr_marek-email'));
      expect(tester.widget<Text>(email).data, isNot(contains('marek.kowalski')));
      expect(find.byKey(const Key('adm-no-impersonation')), findsOneWidget);

      await tester.tap(find.byKey(const Key('adm-pii-usr_marek-email-reveal')));
      await _settle(tester);
      final confirm = find.byKey(const Key('adm-reveal-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('adm-reveal-input')), 'User asked to update invoice e-mail');
      await tester.pump();
      await tester.tap(confirm);
      await _settle(tester);
      expect(tester.widget<Text>(email).data, 'marek.kowalski@example.pl');
      expect(find.descendant(of: find.byKey(const Key('adm-reveal-log')), matching: find.textContaining('User asked to update invoice')), findsOneWidget);
      expect(_ev('admin_reveal'), hasLength(1));
      _expectNoErrors(app);
    });

    testWidgets('conversation reports show only the excerpt until a logged open', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/conversations', size: TGSizes.desktop);
      app.auth.setRole(TGUserRole.moderator);
      await _settle(tester);
      expect(find.byKey(const Key('adm-conv-excerpt-CR-mock-1')), findsOneWidget);
      expect(find.byKey(const Key('adm-conv-thread-CR-mock-1')), findsNothing);
      expect(find.textContaining('Wolę obejrzeć sprzęt'), findsNothing);

      await tester.tap(find.byKey(const Key('adm-conv-open-CR-mock-1')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('adm-conv-open-input')), 'Need context for the scam claim');
      await tester.pump();
      await tester.tap(find.byKey(const Key('adm-conv-open-confirm')));
      await _settle(tester);
      expect(find.byKey(const Key('adm-conv-thread-CR-mock-1')), findsOneWidget);
      expect(find.textContaining('Wolę obejrzeć sprzęt'), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('go-live modal lists blockers and keeps the switch disabled', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/go-live', size: TGSizes.desktop);
      app.auth.setRole(TGUserRole.admin);
      await _settle(tester);
      expect(find.byKey(const Key('adm-golive-auto-photo_license_clause')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('adm-golive-switch')));
      await tester.tap(find.byKey(const Key('adm-golive-switch')));
      await _settle(tester);
      expect(find.byKey(const Key('adm-golive-blocker-photo_license_clause')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('adm-golive-confirm'))).onPressed, isNull);
      expect(TGRevenueConfigService.instance.productionMode, isFalse);
      _expectNoErrors(app);
    });

    testWidgets('audit page: append-only note and CSV export for admins', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/audit', size: TGSizes.desktop);
      app.auth.setRole(TGUserRole.moderator);
      await _settle(tester);
      expect(find.byKey(const Key('adm-audit-append-only')), findsOneWidget);
      expect(find.byKey(const Key('adm-audit-csv')), findsNothing);
      app.auth.setRole(TGUserRole.admin);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('adm-audit-csv')));
      await _settle(tester);
      expect(find.byKey(const Key('dash-export-content')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('390 px: compact Today cards and full-screen section menu', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/today', size: TGSizes.phone);
      app.auth.setRole(TGUserRole.admin);
      await _settle(tester);
      final card = tester.getRect(find.byKey(const Key('adm-today-card-reports')));
      expect(card.width, lessThan(190));
      await tester.tap(find.byKey(const Key('admin-menu')));
      await _settle(tester);
      expect(tester.getSize(find.byKey(const Key('admin-menu-sheet'))), const Size(390, 844));
      await tester.tap(find.byKey(const Key('admin-menu-nip')));
      await _settle(tester);
      expect(app.location, '/admin/nip');
      expect(find.byKey(const Key('adm-nip-VER-mock-usr_bistro')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('settings: five tabs, "Marek K." public name, tab in the URL', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/settings', size: TGSizes.desktop);
      await _settle(tester);
      for (final t in ['profile', 'security', 'language', 'blocked', 'privacy']) {
        expect(find.byKey(Key('settings-tab-$t')), findsOneWidget);
      }
      await tester.enterText(find.byKey(const Key('set-first')), 'Marek');
      await tester.enterText(find.byKey(const Key('set-last')), 'Kowalski');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('set-public-name'))).data, 'Marek K.');
      await tester.tap(find.byKey(const Key('set-profile-save')));
      await _settle(tester);
      expect(app.auth.displayName, 'Marek K.');

      tester.widget<ChoiceChip>(find.byKey(const Key('settings-tab-blocked'))).onSelected!(true);
      await _settle(tester);
      expect(app.location, '/dashboard/settings?tab=blocked');
      expect(find.byKey(const Key('set-blocked-usr_spam_42')), findsOneWidget);
      await tester.tap(find.byKey(const Key('set-unblock-usr_spam_42')));
      await _settle(tester);
      expect(find.byKey(const Key('set-blocked-empty')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('390 px: delete-account flow is a full-screen sheet with checks and legal notes', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/settings?tab=privacy', size: TGSizes.phone);
      app.auth.actAsNewUser();
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('set-del-start')));
      await tester.tap(find.byKey(const Key('set-del-start')));
      await _settle(tester);
      expect(tester.getSize(find.byKey(const Key('set-del-sheet'))), const Size(390, 844));
      expect(find.byKey(const Key('set-del-legal')), findsOneWidget);
      expect(find.byKey(const Key('set-del-check-subscriptions')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('set-del-confirm')));
      await tester.enterText(find.byKey(const Key('set-del-confirm')), 'DELETE');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('set-del-submit')));
      await tester.tap(find.byKey(const Key('set-del-submit')));
      await _settle(tester);
      expect(find.byKey(const Key('set-del-pending')), findsOneWidget);
      expect(_ev('account_delete_request'), hasLength(1));

      await tester.ensureVisible(find.byKey(const Key('set-export')));
      await tester.tap(find.byKey(const Key('set-export')));
      await _settle(tester);
      expect(find.byKey(const Key('dash-export-content')), findsOneWidget);
      expect(_ev('data_export_request'), hasLength(1));
      _expectNoErrors(app);
    });

    testWidgets('390 px: NIP verification sheet — checksum, register lookup, representation, submit', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/verification', size: TGSizes.phone);
      await _settle(tester);
      expect(find.bySemanticsLabel(RegExp(r'^Not met: Company NIP verified')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('vc-nip-start')));
      await tester.tap(find.byKey(const Key('vc-nip-start')));
      await _settle(tester);
      expect(tester.getSize(find.byKey(const Key('vc-nip-sheet'))), const Size(390, 844));

      await tester.enterText(find.byKey(const Key('vc-nip-input')), '6761005670');
      await tester.pump();
      expect(find.byKey(const Key('vc-nip-checksum-bad')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('vc-nip-input')), '6761005675');
      await tester.pump();
      expect(find.byKey(const Key('vc-nip-checksum-ok')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vc-nip-lookup')));
      await _settle(tester);
      expect(find.byKey(const Key('vc-registry-result')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('vc-rep-name')), 'Marek Kowalski');
      await tester.ensureVisible(find.byKey(const Key('vc-rep-confirm')));
      await tester.tap(find.byKey(const Key('vc-rep-confirm')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('vc-nip-submit')));
      await tester.tap(find.byKey(const Key('vc-nip-submit')));
      await _settle(tester);
      expect(find.byKey(const Key('vc-nip-company')), findsOneWidget);
      expect(_ev('verification_submit'), hasLength(1));
      expect(find.bySemanticsLabel(RegExp(r'^Not met: Company NIP verified')), findsOneWidget, reason: 'pending review is not verification');
      _expectNoErrors(app);
    });

    testWidgets('phone change sheet sends a code and confirms the number', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/verification', size: TGSizes.desktop);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('vc-phone-change')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('vc-phone-input')), '731 905 448');
      await tester.tap(find.byKey(const Key('vc-phone-send')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('vc-phone-code')), '123456');
      await tester.tap(find.byKey(const Key('vc-phone-confirm')));
      await _settle(tester);
      expect(tester.widget<Text>(find.byKey(const Key('vc-phone-value'))).data, '+48 731 905 448');
      expect(_ev('phone_change'), hasLength(1));
      _expectNoErrors(app);
    });
  });
}
