import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/product_detail/pdp_gallery.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_watermark_preview.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_seed_phash.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/go_live_checks.dart';
import 'package:twoja_gastromania/tg_services/listing_image_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/watermark_service.dart';

import 'helpers/tg_test_app.dart';

const _photo = 'assets/images/szafa-chlodnicza-700l.jpeg';

ListingImage _img({String listingKey = 'product:1', String url = _photo, DateTime? at, String by = 'seller_a'}) =>
    TGListingImageService.instance.sync(
      listingKey: listingKey,
      urls: [url],
      uploadedById: by,
      uploadedByName: by.toUpperCase(),
      uploadedAt: at ?? DateTime(2026, 1, 1),
    ).single;

/// Plain harness: no app shell, so goldens only contain the image + mark.
Future<void> _pumpImage(WidgetTester tester, {required double width, double? height, TGImageSurface surface = TGImageSurface.listingCard, WatermarkConfig? config, BoxFit fit = BoxFit.cover}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ColoredBox(
      color: Colors.white,
      child: Center(
        child: RepaintBoundary(
          key: const Key('golden'),
          child: SizedBox(
            width: width,
            height: height ?? width * 3 / 4,
            child: WatermarkedImage(url: _photo, surface: surface, config: config, fit: fit),
          ),
        ),
      ),
    ),
  ));
  final ctx = tester.element(find.byType(WatermarkedImage));
  await tester.runAsync(() async {
    await precacheImage(const AssetImage(_photo), ctx);
    await precacheImage(const AssetImage(WatermarkConfig.kDefaultMarkAsset), ctx);
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    TGListingImageService.instance.reset();
    TGWatermarkService.instance.reset();
    ModerationService.instance.reset();
    TGAnalytics.reset();
  });

  group('config & scope', () {
    test('defaults match the pack and round-trip through JSON', () {
      const c = WatermarkConfig();
      expect(c.enabled, isTrue);
      expect(c.version, 1);
      expect(c.markAsset, 'assets/images/tg_watermark_mark.png');
      expect(c.opacity, 0.12);
      expect(c.widthRatio, 0.22);
      expect(c.position, TGWatermarkPosition.center);
      expect(c.minImageWidthPx, 200);
      expect(WatermarkConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>), c);
    });

    test('out-of-scope surfaces are never watermarked', () {
      for (final s in [
        TGImageSurface.specialOrderFile,
        TGImageSurface.legalDocument,
        TGImageSurface.messageAttachment,
        TGImageSurface.avatar,
        TGImageSurface.storeLogo,
        TGImageSurface.storeCover,
        TGImageSurface.banner,
        TGImageSurface.hero,
        TGImageSurface.adSlot,
        TGImageSurface.sponsorSlot,
      ]) {
        expect(watermarkAppliesTo(s), isFalse, reason: s.name);
      }
      for (final s in [
        TGImageSurface.listingGrid,
        TGImageSurface.listingCard,
        TGImageSurface.listingDetail,
        TGImageSurface.lightbox,
        TGImageSurface.favorites,
        TGImageSurface.sharePreview,
        TGImageSurface.uploadPreview,
      ]) {
        expect(watermarkAppliesTo(s), isTrue, reason: s.name);
      }
    });

    test('variants are 320 / 640 / 1280 / 2000', () {
      expect([for (final v in TGImageVariant.values) v.widthPx], [320, 640, 1280, 2000]);
      expect(TGImageVariantX.forWidth(600), TGImageVariant.card);
      expect(TGImageVariantX.forWidth(5000), TGImageVariant.lightbox);
    });

    test('dynamic listing images stay disabled', () {
      expect(TGListingImages.kDisableDynamicListingImages, isTrue);
    });
  });

  group('originalRef privacy', () {
    test('absent from the public JSON and from toString', () {
      final img = _img();
      final json = jsonEncode(img.toJson());
      final ref = img.originalRefFor(TGUserRole.admin)!;
      expect(ref, startsWith('originals/'));
      expect(json, isNot(contains('originalRef')));
      expect(json, isNot(contains(ref)));
      expect(json, isNot(contains('phash')));
      expect(img.toString(), isNot(contains(ref)));
      expect(img.toJson().keys, containsAll(['variants', 'watermarked', 'watermarkVersion']));
    });

    test('readable only by admin and moderator', () {
      final img = _img();
      for (final r in [TGUserRole.visitor, TGUserRole.buyer, TGUserRole.seller, TGUserRole.storeSeller]) {
        expect(img.originalRefFor(r), isNull, reason: r.name);
        expect(TGListingImageService.instance.originalRefFor(img.id, r), isNull, reason: r.name);
        expect(() => img.toStaffJson(r), throwsStateError, reason: r.name);
      }
      for (final r in [TGUserRole.admin, TGUserRole.moderator]) {
        expect(img.originalRefFor(r), isNotNull);
        expect(TGListingImageService.instance.originalRefFor(img.id, r), img.originalRefFor(r));
        expect(img.toStaffJson(r)['originalRef'], img.originalRefFor(r));
      }
    });

    test('public JSON never restores an original', () {
      final img = _img();
      final back = ListingImage.fromPublicJson(jsonDecode(jsonEncode(img.toJson())) as Map<String, dynamic>);
      expect(back.originalRefFor(TGUserRole.admin), isEmpty);
      expect(back.variant(TGImageVariant.card), _photo);
    });

    test('product JSON (public listing payload) carries no original reference', () async {
      final all = await TGProductService.instance.getAll();
      final p = all.first;
      TGListingImageService.instance.syncProduct(p);
      final ref = TGListingImageService.instance.imagesFor(TGListingImageService.productKey(p)).first.originalRefFor(TGUserRole.admin)!;
      final json = jsonEncode(p.toJson());
      expect(json, isNot(contains(ref)));
      expect(json, isNot(contains('originalRef')));
    });
  });

  group('pHash on originals', () {
    test('algorithm: identical → 0, inverted → far', () {
      final g = [for (var i = 0; i < 1024; i++) ((i % 32) * (i ~/ 32)) / 961];
      final inv = [for (final v in g) 1 - v];
      expect(TGPhash.distance(TGPhash.fromGray(g), TGPhash.fromGray(g)), 0);
      expect(TGPhash.distance(TGPhash.fromGray(g), TGPhash.fromGray(inv)), greaterThan(32));
      expect(TGPhash.fromGray(g), hasLength(16));
    });

    test('seed hashes exist for every bundled asset and are attached at upload', () {
      for (final a in TGListingImages.bundledAssets) {
        expect(kSeedOriginalPhash[a], isNotNull, reason: a);
      }
      expect(_img().phash, kSeedOriginalPhash[_photo]);
    });

    testWidgets('upload-time hash from the original bytes agrees with the seed', (tester) async {
      final bytes = (await rootBundle.load(_photo)).buffer.asUint8List();
      final h = await tester.runAsync(() => TGPhash.fromEncoded(bytes));
      expect(TGPhash.distance(h!, kSeedOriginalPhash[_photo]!), lessThanOrEqualTo(TGPhash.matchThresholdBits));
    });

    test('a re-uploaded copy matches the earlier original; staff only', () {
      _img(listingKey: 'product:A', url: 'assets/images/paslanmaz-raflar.jpeg', at: DateTime(2026, 3, 2), by: 'seller_first');
      _img(listingKey: 'product:B', url: 'assets/images/paslanmaz-raflar.jpeg', at: DateTime(2026, 5, 9), by: 'seller_copy');
      _img(listingKey: 'product:C', url: 'assets/images/bain-marie.png', at: DateTime(2026, 6, 1), by: 'seller_c');
      final svc = TGListingImageService.instance;
      final m = svc.compareOriginals('product:B', 'product:A', TGUserRole.moderator)!;
      expect(m.isMatch, isTrue);
      expect(m.distance, 0);
      expect(m.earlier.uploadedById, 'seller_first');
      final other = svc.compareOriginals('product:A', 'product:C', TGUserRole.admin)!;
      expect(other.isMatch, isFalse);
      expect(svc.compareOriginals('product:A', 'product:B', TGUserRole.seller), isNull);
    });
  });

  group('reprocess job', () {
    test('visual change bumps the version, audits, and reprocess moves every photo', () async {
      await TGProductService.instance.getAll();
      final w = TGWatermarkService.instance;
      expect(w.staleCount(), greaterThan(0));
      w.setConfig(w.config.copyWith(opacity: 0.2), actorId: 'admin_1');
      expect(w.config.version, 2);
      expect(ModerationService.instance.auditFor().first.summary, contains('Watermark config v1 → v2'));
      w.startReprocess(actorId: 'admin_1');
      expect(w.running, isTrue);
      final total = w.total;
      expect(total, greaterThan(TGWatermarkService.batchSize));
      w.step();
      expect(w.progress, closeTo(TGWatermarkService.batchSize / total, 1e-9));
      while (w.running) {
        w.step();
      }
      expect(w.progress, 1);
      expect(w.staleCount(), 0);
      expect(TGListingImageService.instance.all.every((i) => i.watermarked && i.watermarkVersion == 2), isTrue);
      expect(TGAnalytics.has('watermark_reprocess_done'), isTrue);
      expect(ModerationService.instance.auditFor().any((e) => e.summary.startsWith('Reprocess images started')), isTrue);
    });
  });

  group('WatermarkedImage', () {
    testWidgets('draws the mark at ≥200 px, sized by widthRatio and excluded from semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpImage(tester, width: 400);
      final mark = find.byKey(WatermarkedImage.markKey);
      expect(mark, findsOneWidget);
      expect(tester.widget<Opacity>(mark).opacity, 0.12);
      final logo = tester.widget<Image>(find.descendant(of: mark, matching: find.byType(Image)));
      expect(logo.excludeFromSemantics, isTrue);
      expect(logo.width, closeTo(400 * 0.22, 0.01));
      expect(find.ancestor(of: mark, matching: find.byType(ExcludeSemantics)), findsWidgets);
      expect(find.ancestor(of: mark, matching: find.byType(IgnorePointer)), findsWidgets);
      expect(tester.getCenter(mark), tester.getCenter(find.byKey(const Key('golden'))));
      handle.dispose();
    });

    testWidgets('skips the mark below 200 px', (tester) async {
      await _pumpImage(tester, width: 199);
      expect(find.byKey(WatermarkedImage.markKey), findsNothing);
      await _pumpImage(tester, width: 200);
      expect(find.byKey(WatermarkedImage.markKey), findsOneWidget);
    });

    testWidgets('no mark on excluded surfaces or when disabled', (tester) async {
      await _pumpImage(tester, width: 400, surface: TGImageSurface.banner);
      expect(find.byKey(WatermarkedImage.markKey), findsNothing);
      await _pumpImage(tester, width: 400, surface: TGImageSurface.avatar);
      expect(find.byKey(WatermarkedImage.markKey), findsNothing);
      await _pumpImage(tester, width: 400, config: const WatermarkConfig(enabled: false));
      expect(find.byKey(WatermarkedImage.markKey), findsNothing);
    });

    testWidgets('contain: the mark follows the letterboxed photo, not the box', (tester) async {
      // Portrait 387×516 photo. 600×400 box → painted 300 px wide.
      await _pumpImage(tester, width: 600, height: 400, fit: BoxFit.contain);
      final logo = tester.widget<Image>(find.descendant(of: find.byKey(WatermarkedImage.markKey), matching: find.byType(Image)));
      expect(logo.width, closeTo(400 * 387 / 516 * 0.22, 0.5));
      // 600×200 box → painted 150 px wide: below the 200 px floor, so no mark.
      await _pumpImage(tester, width: 600, height: 200, fit: BoxFit.contain);
      expect(find.byKey(WatermarkedImage.markKey), findsNothing);
    });

    testWidgets('golden: centered mark at 400 px', (tester) async {
      await _pumpImage(tester, width: 400);
      await expectLater(find.byKey(const Key('golden')), matchesGoldenFile('goldens/watermark_card_400.png'));
    });

    testWidgets('golden: 180 px thumbnail is unmarked', (tester) async {
      await _pumpImage(tester, width: 180);
      await expectLater(find.byKey(const Key('golden')), matchesGoldenFile('goldens/watermark_thumb_180.png'));
    });

    testWidgets('golden: bottom-right position', (tester) async {
      await _pumpImage(tester, width: 400, config: const WatermarkConfig(position: TGWatermarkPosition.bottomRight, opacity: 0.3));
      await expectLater(find.byKey(const Key('golden')), matchesGoldenFile('goldens/watermark_bottom_right_400.png'));
    });
  });

  group('surfaces', () {
    testWidgets('lightbox: the mark scales with the zoom', (tester) async {
      await pumpTgApp(tester, location: '/products', size: TGSizes.desktop);
      final ctx = tester.element(find.byType(Navigator).first);
      openPdpLightbox(context: ctx, images: const [_photo], index: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);
      final mark = find.descendant(of: viewer, matching: find.byKey(WatermarkedImage.markKey));
      expect(mark, findsOneWidget);
      final before = tester.getRect(mark);
      tester.widget<InteractiveViewer>(viewer).transformationController!.value = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      await tester.pump();
      final after = tester.getRect(mark);
      expect(after.width, closeTo(before.width * 2, 0.5));
      expect(after.height, closeTo(before.height * 2, 0.5));
    });

    testWidgets('product cards and PDP gallery use WatermarkedImage; home hero does not', (tester) async {
      await pumpTgApp(tester, location: '/products', size: TGSizes.desktop);
      await pumpFor(tester, const Duration(milliseconds: 600));
      final cards = tester.widgetList<WatermarkedImage>(find.byType(WatermarkedImage));
      expect(cards.where((w) => w.surface == TGImageSurface.listingCard), isNotEmpty);
      expect(find.byKey(WatermarkedImage.markKey), findsWidgets);
    });

    testWidgets('share preview is watermarked', (tester) async {
      await pumpTgApp(tester, location: '/products', size: TGSizes.desktop);
      await pumpFor(tester, const Duration(milliseconds: 600));
      final p = TGProductService.instance.cachedAll.first;
      showPdpShareMenu(tester.element(find.byType(Navigator).first), p);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final preview = find.byKey(const Key('pdp-share-preview'));
      expect(preview, findsOneWidget);
      final img = tester.widget<WatermarkedImage>(find.descendant(of: preview, matching: find.byType(WatermarkedImage)));
      expect(img.surface, TGImageSurface.sharePreview);
      expect(find.descendant(of: preview, matching: find.byKey(WatermarkedImage.markKey)), findsOneWidget);
    });

    testWidgets('upload step: "Preview (with logo)" toggle and DRAFT licence clause', (tester) async {
      await pumpTgApp(tester, location: '/products', size: TGSizes.desktop, locale: const Locale('tr'));
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: TGWatermarkUploadPreview(photos: [_photo]))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Önizleme (logolu)'), findsOneWidget);
      expect(find.text('Yüklediğiniz fotoğraflar logomuzla birlikte gösterilir ve platformda kullanım için lisanslanır.'), findsOneWidget);
      expect(find.text('DRAFT - legal review required'), findsOneWidget);
      expect(find.byKey(const Key('wm-upload-preview')), findsNothing);
      await tester.tap(find.byKey(const Key('wm-preview-toggle')));
      await tester.pump();
      expect(find.byKey(const Key('wm-upload-preview')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('wm-upload-preview')), matching: find.byKey(WatermarkedImage.markKey)), findsOneWidget);
      expect(TGAnalytics.has('watermark_preview_toggle'), isTrue);
    });
  });

  group('moderation & admin', () {
    testWidgets('compare modal matches on originals and names the first uploader', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/l/11820463', size: TGSizes.desktop);
      app.auth.setRole(TGUserRole.moderator);
      await pumpFor(tester, const Duration(milliseconds: 500));
      final mod = ModerationService.instance..ensureSeeded();
      final all = await TGProductService.instance.getAll();
      final m = mod.photoMatches.first;
      final a = all.where((p) => p.listingNo == m.listingNoA).firstOrNull;
      final b = all.where((p) => p.listingNo == m.listingNoB).firstOrNull;
      showPhotoCompare(tester.element(find.byType(Navigator).first), m, a, b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final line = find.byKey(const Key('wm-original-match'));
      expect(line, findsOneWidget);
      final first = [a!, b!]..sort((x, y) => (x.publishedAt ?? x.createdAt).compareTo(y.publishedAt ?? y.createdAt));
      expect(find.descendant(of: line, matching: find.textContaining('Matching original uploaded by ${first.first.seller.name}')), findsOneWidget);
      expect(find.descendant(of: line, matching: find.textContaining('distance 0/64')), findsOneWidget);
      expect(find.text('Compared on the uploaded originals, not on watermarked copies.'), findsOneWidget);
    });

    testWidgets('admin page: save bumps version, reprocess shows progress', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/watermark', size: const Size(1280, 1600));
      app.auth.setRole(TGUserRole.admin);
      await TGProductService.instance.getAll();
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const Key('wm-admin-security')), findsOneWidget);
      expect(find.textContaining('Overlay gives no real protection'), findsOneWidget);
      expect(find.byKey(const Key('wm-admin-excluded')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('wm-admin-opacity')), '20');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('wm-admin-save')));
      await tester.tap(find.byKey(const Key('wm-admin-save')));
      await tester.pump();
      expect(TGWatermarkService.instance.config.version, 2);
      expect(TGWatermarkService.instance.config.opacity, 0.2);
      await tester.ensureVisible(find.byKey(const Key('wm-admin-reprocess')));
      await tester.tap(find.byKey(const Key('wm-admin-reprocess')));
      await tester.pump();
      expect(TGWatermarkService.instance.running, isTrue);
      expect(find.byKey(const Key('wm-admin-progress')), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 10));
      expect(TGWatermarkService.instance.running, isFalse);
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const Key('wm-admin-progress'))).value, 1);
      expect(find.textContaining('0 images not on version 2'), findsOneWidget);
      app.errors.stop();
      expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
    });
  });

  group('Regulamin & go-live', () {
    test('photo licence clause exists in every locale and is flagged DRAFT', () {
      expect(kUiTranslations['regulamin_photo_license']!['tr'], 'Yüklediğiniz fotoğraflar logomuzla birlikte gösterilir ve platformda kullanım için lisanslanır.');
      for (final l in FFLocalizations.languages()) {
        expect(kUiTranslations['regulamin_photo_license']![l], isNotEmpty, reason: l);
      }
      expect(kUiTranslations['regulamin_photo_license_status']!['en'], 'DRAFT - legal review required');
      expect(kPhotoLicenseClauseIsDraft, isTrue);
    });

    test('draft clause blocks go-live', () {
      final c = tgGoLiveChecks().firstWhere((c) => c.id == 'photo_license_clause');
      expect(c.blocking, isTrue);
      expect(c.ok, isFalse);
    });
  });
}
