import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/special_order/so_consent_widgets.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_consent.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/special_consent_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

import 'helpers/tg_test_app.dart';

const _locales = ['en', 'pl', 'tr', 'de', 'cs', 'sk', 'uk', 'be', 'lt', 'ru'];

TGSpecialRequest _draft(String buyerId, {String phone = '+48 600 100 200'}) {
  final now = TGClock.now();
  return TGSpecialRequest(
    id: 'draft',
    requestNo: 'DRAFT',
    buyerId: buyerId,
    buyerName: 'Test Buyer',
    companyName: 'Bistro',
    phone: phone,
    email: 'test.buyer@example.com',
    projectTypes: const [TGStoreSpecialty.worktopsTables],
    title: 'Stainless prep table 1800 mm',
    description: 'Prep table with undershelf and splash guard for a small bistro kitchen.',
    quantity: 2,
    dimensionsText: '1800 × 700 × 850 mm',
    material: 'AISI 304',
    finish: 'Brushed',
    budgetMin: 4000,
    budgetMax: 6000,
    deadline: TGSpecialDeadline.flex,
    city: 'Katowice',
    voivodeship: 'Śląskie',
    installationNeeded: false,
    deliveryNeeded: true,
    files: const [],
    routingMode: TGSpecialRoutingMode.selected,
    selectedSellerIds: const ['seller_inoxline'],
    contactPref: TGSpecialContactPref.share,
    consentAt: now,
    status: TGSpecialRequestStatus.draft,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
}

void main() {
  final svc = TGSpecialOrderService.instance;
  final consent = TGSpecialConsentService.instance;
  const buyer = 'buyer_consent_test';

  setUp(() {
    TGClock.reset();
    NotificationService.instance.reset();
    svc.reset();
    svc.ensureSeeded();
  });

  group('awaiting_consent flow', () {
    test('Send request only stores awaiting_consent: no LeadAccess, no seller alerts', () {
      final before = NotificationService.instance.items.length;
      final r = svc.createAwaitingConsent(_draft(buyer));
      expect(r.status, TGSpecialRequestStatus.awaitingConsent);
      expect(r.status.wire, 'awaiting_consent');
      expect(TGSpecialRequestStatusWire.fromWire('awaiting_consent'), TGSpecialRequestStatus.awaitingConsent);
      expect(r.consentDeadline!.difference(r.createdAt), const Duration(hours: 24));
      expect(svc.accessFor(r.id), isEmpty);
      expect(svc.leadsForSeller('seller_inoxline').any((e) => e.id == r.id), isFalse);
      expect(NotificationService.instance.items.length, before);
      expect(svc.adminQueue(TGSoAdminQueue.all).any((e) => e.id == r.id), isFalse);
      expect(consent.forRequest(r.id), isNull);
    });

    test('confirm stores the consent record, distributes and sends e-mail + SMS proof', () {
      final transport = TGMockConsentTransport();
      final r = svc.createAwaitingConsent(_draft(buyer));
      consent.transport = transport;
      final saved = svc.confirmConsent(r.id, userId: buyer, locale: 'tr');

      expect(saved.status, TGSpecialRequestStatus.open);
      expect(svc.viaFor(saved.id, 'seller_inoxline'), TGLeadAccessVia.selected);

      final c = consent.forRequest(saved.id)!;
      expect(c.requestId, saved.id);
      expect(c.userId, buyer);
      expect(c.version, kSoConsentTextVersion);
      expect(c.locale, 'tr');
      expect(c.text, TGSpecialConsentService.consentText('tr'));
      expect(c.textHash, sha256.convert(utf8.encode(c.text)).toString());
      expect(TGClock.now().difference(c.approvedAt).inSeconds, lessThan(5));
      expect(c.text, contains('ÖNEMLİ YASAL UYARI'));
      expect(c.text, contains('Okudum, anladım ve onaylıyorum'));

      final email = transport.sent.singleWhere((m) => m.channel == TGConsentChannel.email);
      expect(email.to, 'test.buyer@example.com');
      expect(email.subject, '${saved.requestNo} · Talep onayınız');
      expect(email.body, contains(c.text));
      expect(email.body, contains('Başlık: Stainless prep table 1800 mm'));
      expect(email.body, contains(c.textHash));

      final sms = transport.sent.singleWhere((m) => m.channel == TGConsentChannel.sms);
      expect(sms.to, '+48 600 100 200');
      expect(sms.body, 'Talebiniz ${saved.requestNo} alındı. Onay metni: https://twojagastromania.pl/account/requests/${saved.requestNo}/consent');
      expect(consent.hasFailedDelivery(saved.id), isFalse);
    });

    test('only the owner can confirm, and only once', () {
      final r = svc.createAwaitingConsent(_draft(buyer));
      expect(() => svc.confirmConsent(r.id, userId: 'someone_else', locale: 'en'), throwsStateError);
      svc.confirmConsent(r.id, userId: buyer, locale: 'en');
      expect(() => svc.confirmConsent(r.id, userId: buyer, locale: 'en'), throwsStateError);
      expect(consent.consents.where((c) => c.requestId == r.id), hasLength(1));
    });

    test('not confirmed within 24 h → back to draft (kept 7 days), then deleted', () {
      final r = svc.createAwaitingConsent(_draft(buyer));
      TGClock.advance(const Duration(hours: 23, minutes: 59));
      expect(svc.pendingConsent(r.id, userId: buyer), isNotNull);
      TGClock.advance(const Duration(minutes: 1));
      svc.onClockAdvanced();
      final d = svc.byId(r.id)!;
      expect(d.status, TGSpecialRequestStatus.draft);
      expect(d.consentDeadline, isNull);
      expect(d.draftKeepUntil, isNotNull);
      expect(() => svc.confirmConsent(r.id, userId: buyer, locale: 'en'), throwsStateError);
      expect(svc.accessFor(r.id), isEmpty);
      TGClock.advance(const Duration(days: 7));
      svc.onClockAdvanced();
      expect(svc.byId(r.id), isNull);
    });

    test('"Cancel request" keeps the draft for 7 days and resuming reuses it', () {
      final r = svc.createAwaitingConsent(_draft(buyer));
      final d = svc.cancelConsent(r.id, userId: buyer)!;
      expect(d.status, TGSpecialRequestStatus.draft);
      expect(d.draftKeepUntil!.difference(TGClock.now()).inHours, inInclusiveRange(7 * 24 - 1, 7 * 24 + 1));
      final again = svc.createAwaitingConsent(_draft(buyer), replaceId: r.id);
      expect(again.id, r.id);
      expect(again.requestNo, r.requestNo);
      expect(again.status, TGSpecialRequestStatus.awaitingConsent);
      expect(svc.requests.where((e) => e.id == r.id), hasLength(1));
    });
  });

  group('proof delivery retries', () {
    test('3 automatic attempts, then failed; manual Resend recovers', () {
      final r = svc.createAwaitingConsent(_draft(buyer, phone: '+48 000 000 000'));
      consent.transport = TGMockConsentTransport(unreachable: {'+48 000 000 000'});
      final saved = svc.confirmConsent(r.id, userId: buyer, locale: 'pl');
      final sms = consent.deliveriesFor(saved.id).singleWhere((d) => d.channel == TGConsentChannel.sms);
      expect(sms.status, TGConsentDeliveryStatus.failed);
      expect(sms.attempts, TGSpecialConsentService.maxAttempts);
      expect(sms.lastError, 'sms_gateway_unreachable');
      final email = consent.deliveriesFor(saved.id).singleWhere((d) => d.channel == TGConsentChannel.email);
      expect(email.status, TGConsentDeliveryStatus.sent);
      expect(email.attempts, 1);

      expect(consent.resend(saved.id), isFalse);
      expect(sms.attempts, TGSpecialConsentService.maxAttempts);

      consent.transport = TGMockConsentTransport();
      expect(consent.resend(saved.id), isTrue);
      expect(sms.status, TGConsentDeliveryStatus.sent);
      expect(consent.hasFailedDelivery(saved.id), isFalse);
    });
  });

  group('mock data', () {
    test('one awaiting_consent request and one failed proof delivery are seeded', () {
      final awaiting = svc.requests.where((r) => r.status == TGSpecialRequestStatus.awaitingConsent).toList();
      expect(awaiting, hasLength(1));
      expect(awaiting.single.requestNo, 'SO-2026-000143');
      expect(svc.accessFor(awaiting.single.id), isEmpty);

      final failed = svc.requests.where((r) => consent.hasFailedDelivery(r.id)).toList();
      expect(failed.map((r) => r.id), ['so-req-2']);
      expect(consent.forRequest('so-req-2')!.locale, 'pl');
    });
  });

  group('consent text', () {
    test('every key exists in all 10 locales', () {
      for (final key in TGSpecialConsentService.textKeys) {
        for (final l in _locales) {
          expect(kUiTranslations[key]?[l]?.trim(), isNotEmpty, reason: '$key/$l');
        }
      }
    });

    test('red warning is authored in capitals in every locale (no runtime toUpperCase)', () {
      for (final key in ['so_consent_warning_title', 'so_consent_warning_body']) {
        for (final l in _locales) {
          final v = kUiTranslations[key]![l]!;
          expect(v, v.toUpperCase(), reason: '$key/$l');
        }
      }
      expect(kUiTranslations['so_consent_warning_title']!['tr'], 'ÖNEMLİ YASAL UYARI');
    });

    test('text and hash follow the locale; unsupported locale falls back to English', () {
      final hashes = {for (final l in _locales) l: TGSpecialConsentService.hashOf(TGSpecialConsentService.consentText(l))};
      expect(hashes.values.toSet(), hasLength(_locales.length));
      expect(TGSpecialConsentService.resolveLocale('pl_PL'), 'pl');
      expect(TGSpecialConsentService.resolveLocale('fr'), 'en');
      expect(TGSpecialConsentService.consentText('fr'), TGSpecialConsentService.consentText('en'));
    });
  });

  group('confirm page', () {
    testWidgets('confirm stays disabled until the box is ticked; warning box is accessible', (tester) async {
      final app = await pumpTgApp(tester, size: const Size(390, 844), textScale: 1.3, locale: const Locale('tr'), location: '/');
      final r = svc.createAwaitingConsent(_draft(app.auth.userId));
      app.router.go('/special-order/new/confirm?draft=${r.id}');
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(find.text('Talebinizi göndermeden önce'), findsWidgets);
      for (final k in ['so_consent_a', 'so_consent_b', 'so_consent_c', 'so_consent_d']) {
        expect(find.byKey(Key(k)), findsOneWidget);
      }

      final box = find.byKey(const Key('so-consent-warning'));
      await tester.scrollUntilVisible(box, 300, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: box, matching: find.text('ÖNEMLİ YASAL UYARI')), findsOneWidget);
      expect(find.descendant(of: box, matching: find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
      final deco = tester.widget<Container>(find.descendant(of: box, matching: find.byType(Container)).first).decoration! as BoxDecoration;
      final border = deco.border! as Border;
      expect(border.top.color, kSoConsentRed);
      expect(border.top.width, 2);
      expect(tester.getSemantics(box).label, startsWith('ÖNEMLİ YASAL UYARI. TWOJA GASTROMANIA'));

      final confirm = find.byKey(const Key('so-consent-confirm'));
      await tester.ensureVisible(confirm);
      await tester.pump();
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pump();
      expect(svc.byId(r.id)!.status, TGSpecialRequestStatus.awaitingConsent);

      await tester.ensureVisible(find.byKey(const Key('so-consent-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('so-consent-checkbox')));
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.pump();
      await tester.tap(confirm);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(svc.byId(r.id)!.status, TGSpecialRequestStatus.open);
      expect(consent.forRequest(r.id)!.locale, 'tr');
      expect(app.location, startsWith('/special-order/success'));
      expect(app.errors.distinct.where((e) => e.contains('overflowed') && (e.contains('special_order_confirm_page') || e.contains('so_consent_widgets'))), isEmpty);
    });

    testWidgets('cancel returns to /account/requests and keeps a draft', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      final r = svc.createAwaitingConsent(_draft(app.auth.userId));
      app.router.go('/special-order/new/confirm?draft=${r.id}');
      await pumpFor(tester, const Duration(milliseconds: 600));
      final cancel = find.byKey(const Key('so-consent-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pump();
      await tester.tap(cancel);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(svc.byId(r.id)!.status, TGSpecialRequestStatus.draft);
      expect(app.location, '/account/requests');
    });

    testWidgets('stored copy page renders the saved text and the Resend banner', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      final r = svc.createAwaitingConsent(_draft(app.auth.userId, phone: '+48 000 000 000'));
      consent.transport = TGMockConsentTransport(unreachable: {'+48 000 000 000'});
      final saved = svc.confirmConsent(r.id, userId: app.auth.userId, locale: 'en');
      consent.transport = TGMockConsentTransport();
      app.router.go(TGSpecialConsentService.consentPath(saved.requestNo));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('so-consent-meta')), findsOneWidget);
      expect(find.byKey(const Key('so-consent-warning')), findsOneWidget);
      final resend = find.byKey(Key('so-consent-resend-${saved.id}'));
      expect(resend, findsOneWidget);
      await tester.ensureVisible(resend);
      await tester.pump();
      await tester.tap(resend);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(consent.hasFailedDelivery(saved.id), isFalse);
      expect(find.byKey(Key('so-consent-delivery-failed-${saved.id}')), findsNothing);
    });
  });
}
