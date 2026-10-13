import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

import 'helpers/tg_test_app.dart';

const _markAsset = 'assets/images/tg_watermark_mark.png';

TGSpecialRequest _draft(String buyerId) {
  final now = TGClock.now();
  return TGSpecialRequest(
    id: 'draft',
    requestNo: 'DRAFT',
    buyerId: buyerId,
    buyerName: 'Test Buyer',
    companyName: 'Bistro',
    phone: '+48 600 100 200',
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
  group('consent red box (TR)', () {
    setUp(() {
      TGClock.reset();
      NotificationService.instance.reset();
      TGSpecialOrderService.instance
        ..reset()
        ..ensureSeeded();
    });

    test('new warning keeps Turkish İ / Ğ as precomposed capitals', () {
      final tr = kUiTranslations['so_consent_warning_body']!['tr']!;
      expect(tr, contains('SİPARİŞİN'));
      expect(tr, contains('DEĞİLDİR'));
      expect(tr.contains('\u0307'), isFalse, reason: 'no combining dot (I + ̇) from a runtime toUpperCase');
      expect(RegExp(r'[a-zçğıöşü]').hasMatch(tr), isFalse, reason: 'no lower-case letters left');
      expect(kUiTranslations['so_consent_warning_title']!['tr'], 'ÖNEMLİ YASAL UYARI');
    });

    testWidgets('confirm page shows the new body inside the red box', (tester) async {
      final app = await pumpTgApp(tester, size: const Size(390, 844), locale: const Locale('tr'), location: '/');
      final r = TGSpecialOrderService.instance.createAwaitingConsent(_draft(app.auth.userId));
      app.router.go('/special-order/new/confirm?draft=${r.id}');
      await pumpFor(tester, const Duration(milliseconds: 600));
      final box = find.byKey(const Key('so-consent-warning'));
      await tester.scrollUntilVisible(box, 300, scrollable: find.byType(Scrollable).first);
      final body = kUiTranslations['so_consent_warning_body']!['tr']!;
      expect(find.descendant(of: box, matching: find.text(body)), findsOneWidget);
      expect(find.descendant(of: box, matching: find.text('ÖNEMLİ YASAL UYARI')), findsOneWidget);
    });
  });

  group('watermark visibility', () {
    testWidgets('on white the mark shifts pixels by ≥ 25 levels at the default opacity', (tester) async {
      final opacity = const WatermarkConfig().opacity;
      final data = await tester.runAsync(() async {
        final bytes = await rootBundle.load(_markAsset);
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      });
      final px = data!.buffer.asUint8List();
      var maxDelta = 0.0;
      for (var i = 0; i < px.length; i += 4) {
        final a = px[i + 3] / 255 * opacity;
        if (a == 0) continue;
        final lum = 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
        final onWhite = 255 * (1 - a) + lum * a;
        if (255 - onWhite > maxDelta) maxDelta = 255 - onWhite;
      }
      expect(maxDelta, greaterThanOrEqualTo(25), reason: 'dark outline must stay visible on white photos');
    });

    test('no mark below 200 px is the default floor', () {
      expect(const WatermarkConfig().minImageWidthPx, 200);
    });
  });

  group('surfaces without a watermark', () {
    test('evidence, drawings, attachments and avatars never use WatermarkedImage', () {
      const files = [
        'lib/deals',
        'lib/special_order',
        'lib/admin/admin_case_page.dart',
        'lib/admin/admin_deal_case_page.dart',
        'lib/admin/admin_modals.dart',
      ];
      for (final path in files) {
        final entities = FileSystemEntity.isDirectorySync(path)
            ? Directory(path).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
            : [File(path)];
        for (final f in entities) {
          expect(f.readAsStringSync().contains('WatermarkedImage('), isFalse, reason: f.path);
        }
      }
    });

    test('every WatermarkedImage in lib/ targets a listing surface', () {
      final allowed = {for (final s in TGImageSurface.values) if (watermarkAppliesTo(s)) s.name};
      final call = RegExp(r'WatermarkedImage\(([^;]*?)surface:\s*TGImageSurface\.(\w+)', dotAll: true);
      var n = 0;
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('tg_watermarked_image.dart')) continue;
        for (final m in call.allMatches(f.readAsStringSync())) {
          n++;
          expect(allowed, contains(m.group(2)), reason: '${f.path}: ${m.group(2)}');
        }
      }
      expect(n, greaterThan(5));
    });
  });

  group('compare modal vs public page', () {
    testWidgets('admin compare shows the originals; the public PDP shows the watermarked copy', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/l/11820463', size: TGSizes.desktop);
      app.auth.setRole(TGUserRole.moderator);
      await pumpFor(tester, const Duration(milliseconds: 500));
      final mod = ModerationService.instance..ensureSeeded();
      final all = await TGProductService.instance.getAll();
      final m = mod.photoMatches.first;
      final a = all.firstWhere((p) => p.listingNo == m.listingNoA);
      final b = all.where((p) => p.listingNo == m.listingNoB).firstOrNull;
      showPhotoCompare(tester.element(find.byType(Navigator).first), m, a, b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('wm-original-match')), findsOneWidget);
      final dialog = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CompareDialog');
      expect(dialog, findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.byType(WatermarkedImage)), findsNothing);
      expect(find.descendant(of: dialog, matching: find.byKey(WatermarkedImage.markKey)), findsNothing);
      final shown = tester
          .widgetList<Image>(find.descendant(of: dialog, matching: find.byType(Image)))
          .map((i) => i.image)
          .whereType<AssetImage>()
          .map((i) => i.assetName)
          .toSet();
      expect(shown, containsAll({m.imageA, m.imageB}));
      Navigator.of(tester.element(dialog)).pop();
      await tester.pump(const Duration(milliseconds: 300));

      app.auth.setRole(TGUserRole.visitor);
      app.router.go('/product-detail/${a.id}');
      await pumpFor(tester, const Duration(milliseconds: 800));
      final pdp = tester.widgetList<WatermarkedImage>(find.byType(WatermarkedImage)).toList();
      expect(pdp.any((w) => w.surface == TGImageSurface.listingDetail), isTrue);
      expect(find.byKey(WatermarkedImage.markKey), findsWidgets);
    });
  });
}
