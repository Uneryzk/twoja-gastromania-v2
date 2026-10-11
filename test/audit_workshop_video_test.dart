import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_audits_page.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/audited_badge.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/audit_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGClock.reset();
    NotificationService.instance.reset();
    TGSellerProfileService.instance.reset();
    TGRevenueConfigService.instance.reset();
    TGAuditService.instance.reset();
  });

  group('1) Video required + challenge code', () {
    test('submit without video is blocked with exact error', () {
      final svc = TGAuditService.instance..ensureSeeded();
      final app = svc.apply(sellerId: 'seller_gastropl');
      svc.markPaid(app.id);
      final incomplete = TGAuditWorkshopVideo(
        kind: TGAuditVideoKind.file,
        challengeCode: app.workshopVideo!.challengeCode,
        challengeIssuedAt: TGClock.now(),
      );
      expect(incomplete.isComplete, isFalse);
      expect(
        () => svc.submitDocumentsAndVideo(
          app.id,
          workshopAddress: 'Katowice',
          docs: const ['mock://krs.pdf'],
          video: incomplete,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'msg', 'Please add your workshop video.')),
      );
      expect(
        () => svc.submitForReview(app.id),
        throwsA(isA<StateError>().having((e) => e.message, 'msg', 'Please add your workshop video.')),
      );
    });

    test('challenge code is shown and New code regenerates', () {
      final svc = TGAuditService.instance..ensureSeeded();
      final app = svc.apply(sellerId: 'seller_gastropl');
      svc.markPaid(app.id);
      final before = app.workshopVideo!.challengeCode;
      expect(before.length, 4);
      expect(int.tryParse(before), isNotNull);
      svc.regenerateCode(app.id);
      final after = svc.latestFor('seller_gastropl')!.workshopVideo!.challengeCode;
      expect(after.length, 4);
      expect(after, isNot(equals(before)));
      expect(svc.latestFor('seller_gastropl')!.workshopVideo!.challengeValid, isTrue);
    });
  });

  group('2) Admin Approve gates', () {
    test('Approve blocked when checklist empty / video Not provided', () {
      final svc = TGAuditService.instance..ensureSeeded();
      final app = svc.applications.firstWhere((a) => a.id == 'AUD-seed-link');
      // Fresh checklist defaults to notProvided
      app.checklist = TGAuditApplication.defaultChecklist();
      app.linkAckChecked = true;
      expect(app.allChecklistMarked, isFalse);
      expect(app.videoChecklistOk, isFalse);
      expect(app.canApprove, isFalse);
      expect(
        () => svc.decide(
          applicationId: app.id,
          status: TGAuditApplicationStatus.approved,
          actorId: 'admin',
          note: 'nope',
        ),
        throwsStateError,
      );

      // Mark all Pass except video Not provided
      app.checklist = [
        for (final c in TGAuditApplication.defaultChecklist())
          c.id == 'video' ? c : c.copyWith(result: TGAuditCheckResult.pass),
      ];
      expect(app.videoChecklistOk, isFalse);
      expect(app.canApprove, isFalse);
    });
  });

  group('3) Link submission UI', () {
    testWidgets('External link chip + ack checkbox on link case', (tester) async {
      TGAuditService.instance.ensureSeeded();
      final auth = FakeAuthState()..setRole(TGUserRole.admin);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: Scaffold(body: AdminAuditsPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audits'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Stalbar Projekt'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Stalbar Projekt'), matching: find.byType(Column)).first,
        matching: find.text('Open case'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('External link: can change after approval'), findsOneWidget);
      expect(find.text('I watched the video and the code matches.'), findsOneWidget);
      expect(find.textContaining('Expected code: 7193'), findsOneWidget);
      final approveBtn = tester.widget<TGButton>(find.widgetWithText(TGButton, 'Approve'));
      expect(approveBtn.onPressed, isNull);
    });
  });

  group('4) Live visit request + 7-day close', () {
    test('Request Live Video Visit notifies seller; 7d without schedule → rejected', () {
      final svc = TGAuditService.instance..ensureSeeded();
      NotificationService.instance.reset();
      final app = svc.applications.firstWhere((a) => a.id == 'AUD-seed-link');
      svc.requestLiveVisit(
        applicationId: app.id,
        actorId: 'admin',
        reason: 'Link-only submission',
      );
      expect(app.status, TGAuditApplicationStatus.liveVisitRequested);
      expect(app.liveVisit, isNotNull);
      final notes = NotificationService.instance.forUser(app.sellerId);
      expect(notes.any((n) => n.body.contains('short video call')), isTrue);
      expect(notes.any((n) => n.title == 'Verification call'), isTrue);

      TGClock.advance(const Duration(days: 7));
      svc.onClockAdvanced();
      expect(svc.applications.firstWhere((a) => a.id == app.id).status, TGAuditApplicationStatus.rejected);
      expect(svc.applications.firstWhere((a) => a.id == app.id).decisionNote, 'Verification incomplete');
      // Free re-apply preserved
      expect(svc.applications.firstWhere((a) => a.id == app.id).reapplyUsed, isFalse);
    });
  });

  group('5) Badge popover copy', () {
    testWidgets('no live video visit line; Live visit completed only after visit', (tester) async {
      final svc = TGAuditService.instance..ensureSeeded();
      // Direct approve — no live visit line
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditedManufacturerBadge(sellerId: 'seller_gastropl'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Audited Manufacturer'), findsOneWidget);
      await tester.tap(find.text('Audited Manufacturer'));
      await tester.pumpAndSettle();
      expect(find.text('What we checked'), findsOneWidget);
      expect(find.textContaining('live video visit'), findsNothing);
      expect(find.textContaining('Live video visit'), findsNothing);
      expect(find.text('Workshop and equipment video reviewed by our team'), findsOneWidget);
      expect(find.text('Live visit completed'), findsNothing);

      // Approve path after live visit → line appears
      final afterVisit = svc.applications.firstWhere((a) => a.id == 'AUD-seed-direct');
      afterVisit.decisionPath = 'after_live_visit';
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audited Manufacturer'));
      await tester.pumpAndSettle();
      expect(find.text('Live visit completed'), findsOneWidget);
      expect(find.textContaining('live video visit'), findsNothing);
    });
  });
}
