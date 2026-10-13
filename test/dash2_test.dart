import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_exif.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_favorite.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/dash2_mock_data.dart';
import 'package:twoja_gastromania/tg_services/favorites_service.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

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

Future<void> _go(WidgetTester tester, TGApp app, String location) async {
  app.router.go(location);
  await _settle(tester);
}

/// JPEG: SOI, APP0 (JFIF), APP1 (Exif with "GPS"), SOS + data, EOI.
Uint8List _jpegWithExif() => Uint8List.fromList([
      0xFF, 0xD8, //
      0xFF, 0xE0, 0x00, 0x07, 0x4A, 0x46, 0x49, 0x46, 0x00,
      0xFF, 0xE1, 0x00, 0x0A, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x47, 0x50,
      0xFF, 0xDA, 0x00, 0x04, 0x01, 0x02, 0x11, 0x22, 0x33,
      0xFF, 0xD9,
    ]);

TGProduct _sellerProduct() => FakeAuthState(isLoggedIn: true).ownedListings.firstWhere((p) => p.isActive);

void main() {
  setUp(() {
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    TGListingStatsService.instance.reset();
    TGFavoritesService.instance.reset();
    TGPriceHistoryService.instance.reset();
    MessagingService.instance.reset();
    ModerationService.instance.reset();
    TGAnalytics.reset();
  });

  group('ListingStatsDaily counting rules', () {
    test('a visitor counts once per kind per day; owner/staff traffic is not counted', () {
      final s = TGListingStatsService.instance;
      final key = TGListingStatsService.productKey('x1');
      expect(s.record(listingKey: key, kind: ListingStatKind.view, visitorKey: 'v1', count: true), isTrue);
      expect(s.record(listingKey: key, kind: ListingStatKind.view, visitorKey: 'v1', count: true), isFalse);
      expect(s.record(listingKey: key, kind: ListingStatKind.callTap, visitorKey: 'v1', count: true), isTrue);
      expect(s.record(listingKey: key, kind: ListingStatKind.view, visitorKey: 'v2', count: true), isTrue);
      expect(s.record(listingKey: key, kind: ListingStatKind.view, visitorKey: 'owner', count: false), isFalse);
      final tomorrow = TGClock.now().add(const Duration(days: 1));
      expect(s.record(listingKey: key, kind: ListingStatKind.view, visitorKey: 'v1', count: true, at: tomorrow), isTrue);
      final t = s.totals(key, now: tomorrow);
      expect(t.views, 3);
      expect(t.callTaps, 1);
    });

    test('fewer than 7 tracked days is "not enough data"; series is zero-filled', () {
      final s = TGListingStatsService.instance;
      final key = TGListingStatsService.productKey('x2');
      final now = TGClock.now();
      s.seedHistory(key, from: now.subtract(const Duration(days: 5)));
      expect(s.coverageDays(key), 6);
      expect(s.hasEnoughData(key), isFalse);
      s.seedHistory(key, from: now.subtract(const Duration(days: 20)));
      expect(s.hasEnoughData(key), isTrue);
      expect(s.hasEnoughData(key, liveSince: now.subtract(const Duration(days: 3))), isFalse);
      expect(s.daily(key, days: 30).length, 30);
      expect(s.daily(key, days: 90).length, 90);
    });

    test('promotion comparison needs 7+ days on both sides and uses the 14 days before', () {
      final s = TGListingStatsService.instance;
      final key = TGListingStatsService.productKey('x3');
      final now = TGClock.now();
      final promo = Promotion(
        id: 'promo-t1',
        ownerId: 's',
        targetKind: PromotionTargetKind.listing,
        targetRef: 'x3',
        tier: PromotionTier.glow,
        durationDays: 14,
        startsAt: now.subtract(const Duration(days: 9)),
        endsAt: now.add(const Duration(days: 5)),
        status: PromotionStatus.active,
        pricePln: 49,
        source: PromotionSource.paid,
      );
      s.seedHistory(key, from: now.subtract(const Duration(days: 40)), boostFrom: promo.startsAt);
      final c = s.compareWithPromotion(key, promo);
      expect(c.enoughData, isTrue);
      expect(c.beforeDays, TGListingStatsService.comparisonBeforeDays);
      expect(c.duringDays, 10);
      final short = s.compareWithPromotion(TGListingStatsService.productKey('none'), promo);
      expect(short.enoughData, isFalse);
    });

    test('mock rows are hidden in Production Mode', () {
      final s = TGListingStatsService.instance;
      final key = TGListingStatsService.productKey('x4');
      s.seedHistory(key, from: TGClock.now().subtract(const Duration(days: 10)));
      expect(s.hasAny(key), isTrue);
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 't');
      expect(s.hasAny(key), isFalse);
      expect(s.totals(key).views, 0);
    });
  });

  group('EXIF and attachments', () {
    test('JPEG APP1 (EXIF) is stripped, image data kept', () {
      final raw = _jpegWithExif();
      expect(TGExif.isJpeg(raw), isTrue);
      expect(TGExif.hasExif(raw), isTrue);
      final clean = TGExif.strip(raw);
      expect(TGExif.hasExif(clean), isFalse);
      expect(clean.length, raw.length - 12);
      expect(clean.sublist(clean.length - 2), [0xFF, 0xD9]);
    });

    test('max 3 photos, ≤ 5 MB each, images only', () {
      final m = MessagingService.instance;
      TGMessageAttachment a(String id, {int size = 0, Uint8List? bytes, String mime = 'image/jpeg'}) =>
          TGMessageAttachment(id: id, fileName: '$id.jpg', mimeType: mime, sizeBytes: size, bytes: bytes);
      final ok = m.prepareAttachments([a('1', bytes: _jpegWithExif())]);
      expect(ok.error, isNull);
      expect(ok.files.single.exifStripped, isTrue);
      expect(TGExif.hasExif(ok.files.single.bytes!), isFalse);
      expect(m.prepareAttachments([a('1'), a('2'), a('3'), a('4')]).error, 'msg_err_attach_count');
      expect(m.prepareAttachments([a('1', size: MessagingLimits.maxAttachmentBytes + 1)]).error, 'msg_err_attach_size');
      expect(m.prepareAttachments([a('1', mime: 'application/pdf')]).error, 'msg_err_attach_type');
    });
  });

  group('Messaging limits', () {
    test('5th identical message within an hour is blocked as spam and flagged', () {
      final m = MessagingService.instance;
      final p = _sellerProduct();
      for (var i = 0; i < 4; i++) {
        expect(m.send(product: p, senderId: 'b1', senderName: 'B', body: 'Hello, still available?').ok, isTrue);
      }
      final r = m.send(product: p, senderId: 'b1', senderName: 'B', body: 'hello,  still available?');
      expect(r.ok, isFalse);
      expect(r.reason, 'msg_err_spam');
      expect(m.moderationFlags.any((f) => f.reason == 'spam_duplicate'), isTrue);
      TGClock.advance(const Duration(hours: 2));
      expect(m.send(product: p, senderId: 'b1', senderName: 'B', body: 'Hello, still available?').ok, isTrue);
    });

    test('at most 20 new conversations per day', () {
      final m = MessagingService.instance;
      final base = _sellerProduct();
      for (var i = 0; i < MessagingLimits.maxNewConversationsPerDay; i++) {
        final p = base.copyWith(id: 'lim_$i');
        expect(m.send(product: p, senderId: 'b2', senderName: 'B', body: 'Question $i').ok, isTrue, reason: '$i');
      }
      final r = m.send(product: base.copyWith(id: 'lim_x'), senderId: 'b2', senderName: 'B', body: 'One more');
      expect(r.reason, 'msg_err_daily_limit');
      expect(m.send(product: base.copyWith(id: 'lim_0'), senderId: 'b2', senderName: 'B', body: 'Follow-up').ok, isTrue);
    });

    test('templates are capped at 10; archive and block work per user', () {
      final m = MessagingService.instance;
      for (var i = 0; i < MessagingLimits.maxTemplates; i++) {
        expect(m.addTemplate('s1', title: 'T$i', body: 'Body $i'), isNull);
      }
      expect(m.addTemplate('s1', title: 'T', body: 'B'), 'msg_err_template_limit');
      expect(m.addTemplate('s2', title: '', body: 'B'), 'msg_err_template_empty');

      final p = _sellerProduct();
      final sent = m.send(product: p, senderId: 'b3', senderName: 'B', body: 'Hi');
      final sellerId = p.seller.id;
      m.setArchived(sent.threadId!, sellerId, true);
      expect(m.inboxFor(sellerId).any((t) => t.id == sent.threadId), isFalse);
      expect(m.inboxFor(sellerId, archived: true).any((t) => t.id == sent.threadId), isTrue);
      m.send(product: p, senderId: 'b3', senderName: 'B', body: 'Anyone?');
      expect(m.inboxFor(sellerId).any((t) => t.id == sent.threadId), isTrue, reason: 'a new message un-archives');

      m.setBlocked(sellerId, 'b3', true);
      expect(m.send(product: p, senderId: 'b3', senderName: 'B', body: 'Hello?').reason, 'msg_err_blocked');
      m.setBlocked(sellerId, 'b3', false);
      expect(m.send(product: p, senderId: 'b3', senderName: 'B', body: 'Hello again').ok, isTrue);
      expect(_ev('msg_send'), isNotEmpty);
    });

    test('buyer opening message counts as a "message" stat once', () {
      final m = MessagingService.instance;
      final p = _sellerProduct();
      m.send(product: p, senderId: 'b4', senderName: 'B', body: 'Hi');
      m.send(product: p, senderId: 'b4', senderName: 'B', body: 'Hi again');
      expect(TGListingStatsService.instance.totals(TGListingStatsService.productKey(p.id)).messages, 1);
    });
  });

  group('Move to store plan', () {
    test('spends a store slot and aligns expiry with the subscription end', () {
      final auth = FakeAuthState(isLoggedIn: true)..actAsHistorySeller();
      final used = auth.storeSlotsUsed;
      expect(auth.moveToStorePlan('hs_paid1'), isNull);
      final p = auth.ownedListings.firstWhere((e) => e.id == 'hs_paid1');
      expect(p.source, TGListingSource.store);
      expect(p.expiresAt, auth.storeRenewsOn);
      expect(auth.storeSlotsUsed, used + 1);
      expect(auth.moveToStorePlan('hs_paid1'), 'dash_move_err_already');
      expect(auth.moveToStorePlan('hs_draft1'), 'dash_move_err_status');
      expect(auth.moveToStorePlan('hs_exp1'), isNull, reason: 'expired listings can be reactivated on the plan');
      auth.storeActiveLimit = auth.storeSlotsUsed;
      expect(auth.moveToStorePlan('hs_free1'), 'dash_move_err_quota');
    });

    test('without a store plan it is refused', () {
      final auth = FakeAuthState(isLoggedIn: true)..actAsBusySeller();
      final id = auth.ownedListings.first.id;
      expect(auth.moveToStorePlan(id), 'dash_move_err_no_store');
    });
  });

  group('Favorites and price history', () {
    test('toggle adds/removes; dashboard removal is tracked', () {
      final favs = TGFavoritesService.instance;
      final p = _sellerProduct();
      expect(favs.toggleProduct('u1', p, countStat: true), isTrue);
      expect(favs.isFavorite('u1', FavoriteKind.equipment, p.id), isTrue);
      expect(TGListingStatsService.instance.totals(TGListingStatsService.productKey(p.id)).favorites, 1);
      expect(favs.remove('u1', FavoriteKind.equipment, p.id), isTrue);
      expect(_ev('fav_remove'), hasLength(1));
    });

    test('price edits on live listings are recorded', () {
      final auth = FakeAuthState(isLoggedIn: true);
      final p = auth.ownedListings.firstWhere((e) => e.isActive && e.price != null);
      auth.upsertOwned(p.copyWith(price: p.price! - 100));
      final h = TGPriceHistoryService.instance.forListing(p.id);
      expect(h.single.oldPln, p.price);
      expect(h.single.newPln, p.price! - 100);
      expect(h.single.dropped, isTrue);
    });
  });

  group('Mock personas', () {
    test('nothing is seeded in Production Mode', () async {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 't');
      final auth = FakeAuthState(isLoggedIn: true)..actAsHistorySeller();
      await Dash2Mocks.seedHistorySeller(auth);
      expect(TGListingStatsService.instance.hasAny(TGListingStatsService.productKey('hs_paid1')), isFalse);
      expect(PromotionService.instance.byId('promo-dash2-hs_paid1'), isNull);
    });

    test('mock threads are hidden from the inbox in Production Mode', () {
      final m = MessagingService.instance;
      final p = _sellerProduct();
      m.addMockThread(TGChatThread(
        id: 'mock_t',
        listingId: p.id,
        listingTitle: p.title,
        listingImageUrl: p.imageUrl,
        listingPath: p.detailPath,
        listingPrice: p.price,
        listingNo: p.listingNo,
        buyerId: 'bx',
        sellerId: p.seller.id,
        buyerName: 'X',
        sellerName: p.seller.name,
        updatedAt: TGClock.now(),
        isMock: true,
      ));
      expect(m.inboxFor(p.seller.id).any((t) => t.id == 'mock_t'), isTrue);
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 't');
      expect(m.inboxFor(p.seller.id).any((t) => t.isMock), isFalse);
    });
  });

  group('Pages', () {
    testWidgets('listings: tabs, type and search live in the URL', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsHistorySeller();
      await _go(tester, app, '/dashboard/listings?tab=sold');
      for (final id in ['all', 'active', 'expiring', 'expired', 'drafts', 'review', 'sold']) {
        expect(find.byKey(ValueKey('listings-tab-$id')), findsOneWidget, reason: id);
      }
      expect(find.text('Ekspres Nuova Simonelli Appia II'), findsWidgets);
      expect(find.text('Piec konwekcyjny Rational iCombi 6-1/1'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('listings-tab-active')));
      await _settle(tester);
      expect(app.location, contains('filter=active'));
      expect(_ev('listings_filter'), isNotEmpty);

      await tester.enterText(find.byKey(const ValueKey('listings-search')), 'Rational');
      await _settle(tester, 900);
      expect(app.location, contains('q=Rational'));
      expect(find.text('Piec konwekcyjny Rational iCombi 6-1/1'), findsWidgets);
      expect(find.text('Frytownica elektryczna 2x8L'), findsNothing);

      await _go(tester, app, '/dashboard/listings?filter=all&type=restaurant');
      expect(find.text('Frytownica elektryczna 2x8L'), findsNothing);
      _expectNoErrors(app);
    });

    testWidgets('expired tab shows renew offers; move to store asks for confirmation', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsHistorySeller();
      await _go(tester, app, '/dashboard/listings?filter=expired');
      expect(find.byKey(const ValueKey('renew-offers-hs_exp1')), findsOneWidget);
      expect(find.byKey(const ValueKey('renew-offer-hs_exp1-0')), findsOneWidget);

      await _go(tester, app, '/dashboard/listings?filter=active');
      await tester.tap(find.byKey(const ValueKey('listing-more-hs_paid1')).first);
      await _settle(tester, 400);
      await tester.tap(find.byKey(const ValueKey('listing-move-store-hs_paid1')).last);
      await _settle(tester, 400);
      expect(find.byKey(const ValueKey('move-store-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('move-store-confirm')));
      await _settle(tester, 400);
      expect(app.auth.ownedListings.firstWhere((p) => p.id == 'hs_paid1').source, TGListingSource.store);
      expect(_ev('move_to_store'), hasLength(1));
      _expectNoErrors(app);
    });

    testWidgets('insights: totals, not-enough state and per-listing drawer', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsHistorySeller();
      await tester.runAsync(() => Dash2Mocks.seedHistorySeller(app.auth));
      await _go(tester, app, '/dashboard/insights');
      expect(find.byKey(const ValueKey('insights-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('insights-totals')), findsOneWidget);
      expect(_ev('insights_view').any((e) => e['source'] == 'page'), isTrue);

      await _go(tester, app, '/dashboard/insights?listing=hs_new1');
      expect(find.byKey(const ValueKey('insights-drawer')), findsOneWidget);
      expect(find.text('Not enough data yet'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('insights-close')));
      await _settle(tester, 400);

      await _go(tester, app, '/dashboard/insights?listing=hs_paid1');
      final drawer = find.byKey(const ValueKey('insights-drawer'));
      expect(drawer, findsOneWidget);
      expect(find.descendant(of: drawer, matching: find.byKey(const ValueKey('insights-promo-compare'))), findsOneWidget);
      expect(find.descendant(of: drawer, matching: find.text('During promotion vs the 14 days before')), findsOneWidget);
      expect(find.descendant(of: drawer, matching: find.text('Comparison only, not a guarantee')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('favorites: inactive label and price change line', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsFavoritesBuyer();
      await tester.runAsync(() => Dash2Mocks.seedFavoritesBuyer(app.auth.userId));
      await _go(tester, app, '/dashboard/favorites');
      expect(find.byKey(const ValueKey('favorites-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('fav-inactive-fav_gone_sold')), findsOneWidget);
      expect(find.text('Inactive'), findsWidgets);
      expect(find.textContaining(RegExp(r'^Price changed .+: .+ → .+ PLN$')), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('fav-remove-fav_gone_sold')));
      await _settle(tester, 400);
      expect(find.byKey(const ValueKey('fav-card-fav_gone_sold')), findsNothing);
      expect(_ev('fav_remove'), hasLength(1));

      await _go(tester, app, '/dashboard/favorites?tab=restaurants');
      expect(find.byKey(const ValueKey('fav-tab-restaurants')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('messages: 3 panels, safety band, context panel with full phone', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsBusySeller();
      await tester.runAsync(() => Dash2Mocks.seedBusySeller(app.auth));
      final thread = MessagingService.instance.inboxFor(app.auth.userId).firstWhere((t) => t.isMock && t.buyerPhone != null);
      await _go(tester, app, '/dashboard/messages?thread=${thread.id}');
      expect(find.text('Never pay a deposit or advance before seeing the item or the lease. Twoja Gastromania never holds funds.'), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-context')), findsOneWidget);
      final phone = tester.widget<SelectableText>(find.byKey(const ValueKey('messages-ctx-phone')));
      expect(phone.data, thread.buyerPhone);
      expect(find.byKey(const ValueKey('messages-mark-sold')), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-archive')), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-report-ctx')), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-block')), findsOneWidget);
      expect(_ev('msg_open'), isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('messages-report-ctx')));
      await _settle(tester, 400);
      expect(_ev('msg_report'), isEmpty, reason: 'reporting asks for confirmation first');
      await tester.tap(find.byKey(const ValueKey('messages-report-confirm')));
      await _settle(tester, 400);
      expect(_ev('msg_report'), hasLength(1));
      _expectNoErrors(app);
    });

    testWidgets('messages: phone hides the context panel behind a details button', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard', size: TGSizes.phone);
      app.auth.actAsBusySeller();
      await tester.runAsync(() => Dash2Mocks.seedBusySeller(app.auth));
      final thread = MessagingService.instance.inboxFor(app.auth.userId).first;
      await _go(tester, app, '/dashboard/messages?thread=${thread.id}');
      expect(find.byKey(const ValueKey('messages-safety-band')), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-context')), findsNothing);
      expect(find.byKey(const ValueKey('messages-details')), findsOneWidget);
      _expectNoErrors(app);
    });
  });
}
