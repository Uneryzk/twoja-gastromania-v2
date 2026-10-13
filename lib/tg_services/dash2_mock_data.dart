import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_favorite.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/favorites_service.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// DASH-2 Dev Switcher data. Every row is flagged as mock, so Production Mode
/// hides it, and nothing is seeded while Production Mode is on.
abstract final class Dash2Mocks {
  static bool get _off => TGRevenueConfigService.instance.productionMode;

  static const _buyers = [
    ('buyer_kasia', 'Kasia N.', '+48 601 234 567'),
    ('buyer_piotr', 'Piotr Z.', '+48 512 908 331'),
    ('buyer_ola', 'Ola M.', '+48 698 410 225'),
    ('buyer_tomek', 'Tomek R.', '+48 733 120 884'),
    ('buyer_ewa', 'Ewa S.', '+48 504 772 019'),
    ('buyer_bistro', 'Bistro Pod Lipą', '+48 32 255 14 90'),
    ('buyer_jan', 'Jan K.', '+48 667 301 552'),
    ('buyer_magda', 'Magda P.', '+48 789 445 118'),
    ('buyer_hotel', 'Hotel Silesia', '+48 32 781 22 40'),
    ('buyer_lukasz', 'Łukasz W.', '+48 535 016 774'),
    ('buyer_zofia', 'Zofia B.', '+48 600 912 387'),
    ('buyer_kawiarnia', 'Kawiarnia Ziarno', '+48 32 600 70 11'),
  ];

  static const _openers = [
    'Dzień dobry, czy urządzenie jest nadal dostępne?',
    'Czy możliwy jest odbiór osobisty w tym tygodniu?',
    'Jaka jest najniższa cena przy odbiorze od razu?',
    'Czy urządzenie ma fakturę VAT?',
    'Czy mogę zobaczyć je w działaniu przed zakupem?',
    'Ile lat było używane i czy było serwisowane?',
  ];

  static const _replies = [
    'Tak, jest dostępne. Zapraszam do obejrzenia.',
    'Odbiór możliwy od wtorku po 15:00.',
    'Mogę wystawić fakturę VAT 23%.',
  ];

  /// Seller with many buyer conversations (TG Demo, expired-listings scenario).
  static Future<void> seedBusySeller(FakeAuthState auth) async {
    if (_off) return;
    final msg = MessagingService.instance;
    await msg.ensureLoaded();
    final listings = auth.ownedListings.where((p) => p.status != TGListingStatus.draft).toList();
    if (listings.isEmpty) return;
    final now = TGClock.now();
    for (var i = 0; i < _buyers.length; i++) {
      final b = _buyers[i];
      final p = listings[i % listings.length];
      final opened = now.subtract(Duration(hours: 3 + i * 7));
      final answered = i % 3 != 0;
      msg.addMockThread(TGChatThread(
        id: 't_${p.id}_${b.$1}',
        listingId: p.id,
        listingTitle: p.title,
        listingImageUrl: p.imageUrl,
        listingPath: p.detailPath,
        listingPrice: p.price,
        listingNo: p.listingNo,
        buyerId: b.$1,
        sellerId: auth.userId,
        buyerName: b.$2,
        sellerName: auth.displayName,
        updatedAt: answered ? opened.add(const Duration(minutes: 40)) : opened,
        unreadSeller: answered ? 0 : 1 + i % 2,
        isMock: true,
        buyerPhone: b.$3,
        sellerPhone: p.phone,
        listingCity: p.city,
        buyerSince: DateTime(now.year - 1 - i % 3, 1 + i % 12, 10),
        sellerSince: DateTime(now.year - 2, 4, 2),
        messages: [
          TGChatMessage(
            id: 'm_mock_${b.$1}_1',
            senderId: b.$1,
            receiverId: auth.userId,
            timestamp: opened,
            ipAddress: MessagingService.mockIp,
            body: _openers[i % _openers.length],
          ),
          if (answered)
            TGChatMessage(
              id: 'm_mock_${b.$1}_2',
              senderId: auth.userId,
              receiverId: b.$1,
              timestamp: opened.add(const Duration(minutes: 40)),
              ipAddress: MessagingService.mockIp,
              body: _replies[i % _replies.length],
            ),
        ],
      ));
    }
    if (msg.templatesFor(auth.userId).isEmpty) {
      msg.addTemplate(auth.userId, title: 'Dostępne', body: 'Dzień dobry, tak — urządzenie jest dostępne. Zapraszam do obejrzenia w Katowicach.');
      msg.addTemplate(auth.userId, title: 'Odbiór', body: 'Odbiór osobisty możliwy od poniedziałku do piątku, 9:00–17:00.');
      msg.addTemplate(auth.userId, title: 'Faktura', body: 'Wystawiam fakturę VAT 23%. Proszę o dane firmy.');
    }
    seedListingStats(auth.ownedListings);
  }

  /// Daily stats from each listing's publish date to its end (or today).
  static void seedListingStats(List<TGProduct> listings) {
    if (_off) return;
    final stats = TGListingStatsService.instance;
    var seed = 3;
    for (final p in listings) {
      final from = p.publishedAt;
      if (from == null) continue;
      final ended = p.status == TGListingStatus.expired || p.status == TGListingStatus.sold;
      stats.seedHistory(
        TGListingStatsService.keyOfProduct(p),
        from: from,
        to: ended ? p.expiresAt : null,
        seed: seed++,
        baseViews: 8 + (p.price ?? 0) % 11,
        boostFrom: PromotionService.instance.activeFor(kind: PromotionTargetKind.listing, targetRef: p.id)?.startsAt,
      );
    }
  }

  /// Store seller with six months of history, a running promotion and a few chats.
  static Future<void> seedHistorySeller(FakeAuthState auth) async {
    if (_off) return;
    final now = TGClock.now();
    final paid = auth.ownedListings.where((p) => p.id == 'hs_paid1').firstOrNull;
    if (paid != null) {
      final start = now.subtract(const Duration(days: 9));
      final days = PromotionService.instance.config.durations.first;
      PromotionService.instance.addMock(Promotion(
        id: 'promo-dash2-${paid.id}',
        ownerId: auth.userId,
        targetKind: PromotionTargetKind.listing,
        targetRef: paid.id,
        tier: PromotionTier.glow,
        durationDays: days,
        startsAt: start,
        endsAt: DurationService.addDays(start, days),
        status: PromotionStatus.active,
        pricePln: PromotionService.instance.config.pricePln(PromotionTier.glow, days),
        source: PromotionSource.paid,
      ));
    }
    seedListingStats(auth.ownedListings);
    final msg = MessagingService.instance;
    await msg.ensureLoaded();
    final live = auth.ownedListings.where((p) => p.isActive).toList();
    for (var i = 0; i < 4 && live.isNotEmpty; i++) {
      final b = _buyers[i + 4];
      final p = live[i % live.length];
      final at = now.subtract(Duration(days: i * 3, hours: 2));
      msg.addMockThread(TGChatThread(
        id: 't_${p.id}_${b.$1}',
        listingId: p.id,
        listingTitle: p.title,
        listingImageUrl: p.imageUrl,
        listingPath: p.detailPath,
        listingPrice: p.price,
        listingNo: p.listingNo,
        buyerId: b.$1,
        sellerId: auth.userId,
        buyerName: b.$2,
        sellerName: auth.displayName,
        updatedAt: at,
        unreadSeller: i == 0 ? 1 : 0,
        isMock: true,
        buyerPhone: b.$3,
        sellerPhone: p.phone,
        listingCity: p.city,
        messages: [
          TGChatMessage(
            id: 'm_mock_hs_${b.$1}',
            senderId: b.$1,
            receiverId: auth.userId,
            timestamp: at,
            ipAddress: MessagingService.mockIp,
            body: _openers[(i + 2) % _openers.length],
          ),
        ],
      ));
    }
  }

  /// Buyer with many saved listings, some repriced, some no longer live.
  static Future<void> seedFavoritesBuyer(String userId) async {
    if (_off) return;
    final favs = TGFavoritesService.instance;
    final prices = TGPriceHistoryService.instance;
    final now = TGClock.now();
    final catalogue = (await TGProductService.instance.getAll()).where((p) => p.isActive && p.price != null).take(8).toList();
    for (var i = 0; i < catalogue.length; i++) {
      final p = catalogue[i];
      final saved = now.subtract(Duration(days: 3 + i * 4));
      final repriced = i % 3 == 0;
      final old = repriced ? (p.price! * 1.12).round() : p.price!;
      favs.add(TGFavorite(
        userId: userId,
        kind: FavoriteKind.equipment,
        listingId: p.id,
        savedAt: saved,
        title: p.title,
        imageUrl: p.imageUrl,
        path: p.detailPath,
        listingNo: p.listingNo,
        city: p.city,
        priceAtSave: old,
        isMock: true,
      ));
      if (repriced) {
        prices.record(listingId: p.id, oldPln: old, newPln: p.price!, at: saved.add(const Duration(days: 2)), isMock: true);
      }
    }
    for (final gone in const [
      ('fav_gone_sold', 'Zmywarka kapturowa Hobart – sprzedana', '47120934', 'Gliwice', 7400),
      ('fav_gone_exp', 'Piec do pizzy 6x33 cm – wygasło', '48231045', 'Kraków', 5200),
    ]) {
      favs.add(TGFavorite(
        userId: userId,
        kind: FavoriteKind.equipment,
        listingId: gone.$1,
        savedAt: now.subtract(const Duration(days: 41)),
        title: gone.$2,
        imageUrl: '',
        path: '/product-detail/${gone.$3}',
        listingNo: gone.$3,
        city: gone.$4,
        priceAtSave: gone.$5,
        isMock: true,
      ));
    }
    final restos = RestaurantService.instance.all.where((r) => r.status != RestaurantListingStatus.draft).take(4).toList();
    for (var i = 0; i < restos.length; i++) {
      final r = restos[i];
      final saved = now.subtract(Duration(days: 5 + i * 6));
      final repriced = i == 0;
      final old = repriced ? r.rentMonthly + 1000 : r.rentMonthly;
      favs.add(TGFavorite(
        userId: userId,
        kind: FavoriteKind.restaurant,
        listingId: r.id,
        savedAt: saved,
        title: r.title,
        imageUrl: r.imageUrl,
        path: r.detailPath,
        listingNo: r.listingNo,
        city: r.city,
        priceAtSave: old,
        isMock: true,
      ));
      if (repriced) {
        prices.record(listingId: r.id, oldPln: old, newPln: r.rentMonthly, at: saved.add(const Duration(days: 1)), isMock: true);
      }
    }
  }
}
