import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

const kNeutralMatchCopy = 'Request sent if an account matches';

class TGSoldUndo {
  TGSoldUndo({required this.listing, required this.dealId});
  final TGProduct listing;
  final String? dealId;
}

class DealService extends ChangeNotifier {
  DealService._();
  static final DealService instance = DealService._();

  final List<TGDeal> deals = [];
  final List<TGDealConversation> conversations = [];
  final List<TGDealAccount> directory = [];
  final Map<String, int> _lookupsToday = {};
  final List<TGPurchaseReview> reviews = [];
  final List<TGObjection> objections = [];
  final List<TGEvidence> evidence = [];
  final Map<String, int> unjustObjections90d = {};
  final Map<String, int> _reviewsToday = {};
  final Set<String> _calendarKeys = {};
  final Set<String> _helpfulKeys = {};
  final Map<String, TGPurchaseReviewState> _reviewUndo = {};
  int _seq = 123;
  int _reviewSeq = 1;
  int _objSeq = 1;
  int _evSeq = 1;
  TGSoldUndo? lastUndo;
  bool _seeded = false;

  static const buyerMarek = TGDealAccount(
    userId: 'buyer_marek',
    displayName: 'Marek K.',
    phone: '+48532784074',
    email: 'marek.k@mail.com',
    phoneVerified: true,
  );
  static const buyerAnna = TGDealAccount(
    userId: 'buyer_anna',
    displayName: 'Anna W.',
    phone: '+48600111222',
    email: 'anna.w@mail.com',
    phoneVerified: false,
  );
  static const buyerPiotr = TGDealAccount(
    userId: 'buyer_piotr',
    displayName: 'Piotr B.',
    phone: '+48700999888',
    email: 'piotr.b@mail.com',
    phoneVerified: true,
  );

  void reset() {
    deals.clear();
    conversations.clear();
    directory.clear();
    reviews.clear();
    objections.clear();
    evidence.clear();
    unjustObjections90d.clear();
    _reviewsToday.clear();
    _calendarKeys.clear();
    _helpfulKeys.clear();
    _reviewUndo.clear();
    _lookupsToday.clear();
    _seq = 123;
    _reviewSeq = 1;
    _objSeq = 1;
    _evSeq = 1;
    lastUndo = null;
    _seeded = false;
    TGClock.reset();
    NotificationService.instance.reset();
    ensureSeeded();
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    directory.addAll([buyerMarek, buyerAnna, buyerPiotr]);
    final now = TGClock.now();
    conversations.addAll([
      TGDealConversation(id: 'c1', listingNo: '38705142', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerMarek.userId, buyerName: buyerMarek.displayName, lastMessageAt: DateTime(now.year, 10, 12)),
      TGDealConversation(id: 'c2', listingNo: '38705142', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerAnna.userId, buyerName: buyerAnna.displayName, lastMessageAt: DateTime(now.year, 10, 10)),
      TGDealConversation(id: 'c3', listingNo: '38705142', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerPiotr.userId, buyerName: buyerPiotr.displayName, lastMessageAt: DateTime(now.year, 10, 8)),
      TGDealConversation(id: 'c4', listingNo: '39816253', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerMarek.userId, buyerName: buyerMarek.displayName, lastMessageAt: DateTime(now.year, 10, 7)),
      TGDealConversation(id: 'c5', listingNo: '39816253', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerAnna.userId, buyerName: buyerAnna.displayName, lastMessageAt: DateTime(now.year, 10, 6)),
      TGDealConversation(id: 'c6', listingNo: '40927364', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerPiotr.userId, buyerName: buyerPiotr.displayName, lastMessageAt: DateTime(now.year, 10, 5)),
      TGDealConversation(id: 'c7', listingNo: '40927364', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerMarek.userId, buyerName: buyerMarek.displayName, lastMessageAt: DateTime(now.year, 10, 4)),
      TGDealConversation(id: 'c8', listingNo: '35472819', sellerId: FakeAuthState.mockOwnerId, buyerId: buyerMarek.userId, buyerName: buyerMarek.displayName, lastMessageAt: DateTime(now.year, 10, 3)),
    ]);
    const seller = 'Technica';
    const img = 'assets/images/bartscher_2002170.webp';
    final snap1 = const TGDealSnapshot(title: 'Piec pizza 4 pizze – 3 dni do końca', imageUrl: img, price: 2500, city: 'Katowice', sellerName: seller, sellerVerified: true);
    final snap2 = const TGDealSnapshot(title: 'Stół chłodniczy 2-drzwiowy', imageUrl: img, price: 2500, city: 'Katowice', sellerName: seller, sellerVerified: true);
    final snap3 = const TGDealSnapshot(title: 'Zmywarka podszafkowa', imageUrl: img, price: 2500, city: 'Katowice', sellerName: seller, sellerVerified: true);
    deals.addAll([
      TGDeal(
        id: 'D-2026-000123',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.pendingBuyer,
        listingNo: '38705142',
        listingSnapshot: snap1,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerMarek.userId,
        identifierType: TGDealIdentifierType.conversation,
        identifierMasked: maskPhone(buyerMarek.phone),
        createdAt: now.subtract(const Duration(days: 1)),
        sellerConfirmedAt: now.subtract(const Duration(days: 1)),
      ),
      TGDeal(
        id: 'D-2026-000124',
        type: TGDealType.sale,
        source: TGDealSource.buyerClaim,
        status: TGDealStatus.pendingSeller,
        listingNo: '39816253',
        listingSnapshot: snap2,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerAnna.userId,
        identifierType: TGDealIdentifierType.account,
        identifierMasked: maskEmail(buyerAnna.email),
        createdAt: now.subtract(const Duration(days: 2)),
        buyerConfirmedAt: now.subtract(const Duration(days: 2)),
      ),
      TGDeal(
        id: 'D-2026-000125',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.confirmed,
        verification: TGDealVerification.bothParties,
        listingNo: '40927364',
        listingSnapshot: snap3,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerMarek.userId,
        identifierType: TGDealIdentifierType.conversation,
        identifierMasked: buyerMarek.displayName,
        createdAt: now.subtract(const Duration(days: 8)),
        sellerConfirmedAt: now.subtract(const Duration(days: 8)),
        buyerConfirmedAt: now.subtract(const Duration(days: 7)),
        reviewWindowEndsAt: now.add(const Duration(days: 53)),
      ),
      TGDeal(
        id: 'D-2026-000126',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.declinedByBuyer,
        listingNo: '38705142',
        listingSnapshot: snap1,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerPiotr.userId,
        identifierMasked: maskPhone(buyerPiotr.phone),
        createdAt: now.subtract(const Duration(days: 6)),
        sellerConfirmedAt: now.subtract(const Duration(days: 6)),
      ),
      TGDeal(
        id: 'D-2026-000127',
        type: TGDealType.rental,
        source: TGDealSource.buyerClaim,
        status: TGDealStatus.declinedBySeller,
        listingNo: '39816253',
        listingSnapshot: snap2,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerAnna.userId,
        identifierMasked: maskEmail(buyerAnna.email),
        createdAt: now.subtract(const Duration(days: 5)),
        buyerConfirmedAt: now.subtract(const Duration(days: 5)),
      ),
      TGDeal(
        id: 'D-2026-000128',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.expired,
        listingNo: '38705142',
        listingSnapshot: snap1,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerAnna.userId,
        createdAt: now.subtract(const Duration(days: 16)),
        expiresAt: now.subtract(const Duration(days: 2)),
        sellerConfirmedAt: now.subtract(const Duration(days: 16)),
      ),
      TGDeal(
        id: 'D-2026-000129',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.inModeration,
        listingNo: '39816253',
        listingSnapshot: snap2,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerMarek.userId,
        createdAt: now.subtract(const Duration(days: 4)),
        riskFlags: const ['claim_mismatch'],
      ),
      TGDeal(
        id: 'D-2026-000130',
        type: TGDealType.sale,
        source: TGDealSource.sellerMarked,
        status: TGDealStatus.approvedByModerator,
        verification: TGDealVerification.moderator,
        listingNo: '40927364',
        listingSnapshot: snap3,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerPiotr.userId,
        createdAt: now.subtract(const Duration(days: 12)),
        sellerConfirmedAt: now.subtract(const Duration(days: 12)),
        buyerConfirmedAt: now.subtract(const Duration(days: 10)),
        reviewWindowEndsAt: now.add(const Duration(days: 50)),
      ),
    ]);
    _seq = 131;
    NotificationService.instance.add(
      userId: buyerMarek.userId,
      type: 'deal_request',
      dealId: 'D-2026-000123',
      title: 'Confirm this purchase',
      body: 'Technica says this item was sold to you.',
      params: {'name': seller, 'title': snap1.title},
    );
    _seedReviewFirst(now, snap1, snap2, snap3, seller);
    _seedCatalogReviews(now);
    syncStoreRatings();
  }

  String _nextId() {
    final n = _seq++;
    return 'D-2026-${n.toString().padLeft(6, '0')}';
  }

  List<TGDealConversation> conversationsFor(String listingNo) =>
      conversations.where((c) => c.listingNo == listingNo).toList()..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  List<TGDeal> forSeller(String sellerId) => deals.where((d) => d.sellerId == sellerId).toList();
  List<TGDeal> forBuyer(String buyerId) => deals.where((d) => d.buyerId == buyerId).toList();
  TGDeal? byId(String id) => deals.where((d) => d.id == id).firstOrNull;

  TGDealAccount? accountById(String id) => directory.where((a) => a.userId == id).firstOrNull;

  int lookupsUsed(String sellerId) {
    final key = '$sellerId-${_dayKey(TGClock.now())}';
    return _lookupsToday[key] ?? 0;
  }

  bool get canLookup => true;

  String lookupNeutral(String sellerId, {required TGDealIdentifierType type, required String query}) {
    final key = '$sellerId-${_dayKey(TGClock.now())}';
    final used = _lookupsToday[key] ?? 0;
    if (used >= 5) return kNeutralMatchCopy;
    _lookupsToday[key] = used + 1;
    notifyListeners();
    return kNeutralMatchCopy;
  }

  TGDealAccount? matchDirectory({required TGDealIdentifierType type, required String query}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    for (final a in directory) {
      switch (type) {
        case TGDealIdentifierType.account:
        case TGDealIdentifierType.conversation:
          if (a.displayName.toLowerCase().contains(q) || a.userId.toLowerCase() == q) return a;
        case TGDealIdentifierType.phone:
          if (a.phone.replaceAll(RegExp(r'\D'), '').contains(digits) && digits.length >= 6) return a;
        case TGDealIdentifierType.email:
          if (a.email.toLowerCase() == q) return a;
      }
    }
    return null;
  }

  String maskedFor(TGDealAccount a, TGDealIdentifierType type) => switch (type) {
        TGDealIdentifierType.phone => maskPhone(a.phone),
        TGDealIdentifierType.email => maskEmail(a.email),
        _ => a.displayName,
      };

  TGDealSnapshot snapshotOf(TGProduct listing) => TGDealSnapshot(
        title: listing.title,
        imageUrl: listing.imageUrl,
        price: listing.price,
        city: listing.city,
        listingType: listing.listingType.key,
        sellerName: listing.seller.name,
        sellerVerified: listing.seller.verified,
      );

  Future<TGDeal?> finalizeSold({
    required FakeAuthState auth,
    required TGProduct listing,
    required TGSoldReason reason,
    TGDealAccount? buyer,
    TGDealIdentifierType identifierType = TGDealIdentifierType.conversation,
    String? identifierMasked,
  }) async {
    TGDeal? deal;
    if (buyer != null) {
      final listingNo = listing.listingNo ?? listing.id;
      final pending = deals.any((d) => d.listingNo == listingNo && d.buyerId == buyer.userId && d.isPending);
      if (!pending) {
        final type = listing.listingType == TGListingType.rent || reason == TGSoldReason.rented ? TGDealType.rental : TGDealType.sale;
        deal = TGDeal(
          id: _nextId(),
          type: type,
          source: TGDealSource.sellerMarked,
          status: TGDealStatus.pendingBuyer,
          listingNo: listingNo,
          listingSnapshot: snapshotOf(listing),
          sellerId: auth.userId,
          buyerId: buyer.userId,
          identifierType: identifierType,
          identifierMasked: identifierMasked ?? maskedFor(buyer, identifierType),
          sellerConfirmedAt: TGClock.now(),
        );
        deal.events = [TGDealEvent(at: TGClock.now(), actor: TGDealActor.seller, type: TGDealEventType.created)];
        deals.insert(0, deal);
        NotificationService.instance.add(
          userId: buyer.userId,
          type: 'deal_request',
          dealId: deal.id,
          title: 'Confirm this purchase',
          body: '${listing.title} — please confirm whether you bought this item.',
          params: {'name': listing.seller.name, 'title': listing.title},
        );
        TGAnalytics.track('deal_request_sent', {'dealId': deal.id, 'listingNo': listing.listingNo});
      }
    }
    applySoldToAuth(auth, listing, reason: reason, dealId: deal?.id);
    notifyListeners();
    return deal;
  }

  Future<void> undoLastSold(FakeAuthState auth) async {
    final u = lastUndo;
    if (u == null) return;
    auth.upsertOwned(u.listing);
    TGProductService.instance.upsert(u.listing);
    if (u.dealId != null) {
      deals.removeWhere((d) => d.id == u.dealId);
    }
    lastUndo = null;
    notifyListeners();
  }

  void applySoldToAuth(FakeAuthState auth, TGProduct listing, {required TGSoldReason reason, String? dealId}) {
    lastUndo = TGSoldUndo(listing: listing, dealId: dealId);
    final nextStatus = reason == TGSoldReason.noLongerSelling || reason == TGSoldReason.other ? TGListingStatus.removed : TGListingStatus.sold;
    final patched = listing.copyWith(status: nextStatus, isHidden: true, soldReason: reason.name, soldDealId: dealId);
    auth.upsertOwned(patched);
    TGProductService.instance.upsert(patched);
    notifyListeners();
  }

  void confirmByBuyer(TGDeal deal, {required String buyerId}) {
    if (deal.buyerId != buyerId) return;
    deal.status = TGDealStatus.confirmed;
    deal.verification = TGDealVerification.bothParties;
    deal.buyerConfirmedAt = TGClock.now();
    deal.reviewWindowEndsAt = TGClock.now().add(const Duration(days: 60));
    deal.events = [...deal.events, TGDealEvent(at: TGClock.now(), actor: TGDealActor.buyer, type: TGDealEventType.confirmed)];
    NotificationService.instance.add(
      userId: deal.sellerId,
      type: 'deal_buyer_confirmed',
      dealId: deal.id,
      title: 'Buyer confirmed',
      body: 'The buyer confirmed this deal.',
      deepLink: '/dashboard/deals',
      params: {'title': deal.listingSnapshot.title},
    );
    TGAnalytics.track('deal_buyer_confirmed', {'dealId': deal.id});
    notifyListeners();
  }

  void declineByBuyer(TGDeal deal, {required String buyerId, bool reportSeller = false}) {
    if (deal.buyerId != buyerId) return;
    deal.status = TGDealStatus.declinedByBuyer;
    deal.declineReason = reportSeller ? 'not_me_reported' : 'not_me';
    deal.events = [...deal.events, TGDealEvent(at: TGClock.now(), actor: TGDealActor.buyer, type: TGDealEventType.declined)];
    NotificationService.instance.add(
      userId: deal.sellerId,
      type: 'deal_buyer_declined',
      dealId: deal.id,
      title: 'Deal update',
      body: "The buyer couldn't confirm this deal.",
      deepLink: '/dashboard/deals',
      params: {'title': deal.listingSnapshot.title},
    );
    TGAnalytics.track('deal_buyer_declined', {'dealId': deal.id, 'report': reportSeller});
    notifyListeners();
  }

  void cancel(TGDeal deal, {required String actorId}) {
    if (deal.sellerId != actorId) return;
    deal.status = TGDealStatus.cancelled;
    deal.events = [...deal.events, TGDealEvent(at: TGClock.now(), actor: TGDealActor.seller, type: TGDealEventType.cancelled)];
    notifyListeners();
  }

  bool resendReminder(TGDeal deal) {
    final now = TGClock.now();
    if (deal.lastReminderAt != null && now.difference(deal.lastReminderAt!).inDays < 3) return false;
    deal.lastReminderAt = now;
    deal.events = [...deal.events, TGDealEvent(at: now, actor: TGDealActor.seller, type: TGDealEventType.reminderResent)];
    if (deal.buyerId != null) {
      NotificationService.instance.add(
        userId: deal.buyerId!,
        type: 'deal_reminder',
        dealId: deal.id,
        title: 'Reminder: confirm this purchase',
        body: deal.listingSnapshot.title,
        params: {'title': deal.listingSnapshot.title},
      );
    }
    notifyListeners();
    return true;
  }

  void requestReview(TGDeal deal) {
    if (deal.reviewRequestedAt != null || !deal.isConfirmed) return;
    deal.reviewRequestedAt = TGClock.now();
    deal.events = [...deal.events, TGDealEvent(at: TGClock.now(), actor: TGDealActor.seller, type: TGDealEventType.reviewRequested)];
    if (deal.buyerId != null) {
      NotificationService.instance.add(
        userId: deal.buyerId!,
        type: 'deal_review_requested',
        dealId: deal.id,
        title: 'Please review this seller',
        body: deal.listingSnapshot.title,
        deepLink: '/account/reviews?compose=1&listingNo=${deal.listingNo}',
        params: {'title': deal.listingSnapshot.title},
      );
    }
    TGAnalytics.track('deal_review_requested', {'dealId': deal.id});
    notifyListeners();
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    for (final d in deals.where((e) => e.isPending)) {
      final age = now.difference(d.createdAt);
      if (age >= const Duration(days: 14) && d.status != TGDealStatus.expired) {
        d.status = TGDealStatus.expired;
        d.events = [...d.events, TGDealEvent(at: now, actor: TGDealActor.system, type: TGDealEventType.expired)];
        if (d.buyerId != null) {
          NotificationService.instance.add(userId: d.buyerId!, type: 'deal_expired', dealId: d.id, title: 'Request expired', body: d.listingSnapshot.title, params: {'title': d.listingSnapshot.title});
        }
        NotificationService.instance.add(userId: d.sellerId, type: 'deal_expired', dealId: d.id, title: 'Request expired', body: d.listingSnapshot.title, deepLink: '/dashboard/deals', params: {'title': d.listingSnapshot.title});
        TGAnalytics.track('deal_expired', {'dealId': d.id});
      } else if (age >= const Duration(days: 10) && (d.lastReminderAt == null || now.difference(d.lastReminderAt!).inDays >= 3)) {
        d.lastReminderAt = now;
        if (d.buyerId != null) {
          NotificationService.instance.add(userId: d.buyerId!, type: 'deal_reminder_d10', dealId: d.id, title: '4 days left to confirm', body: d.listingSnapshot.title, params: {'title': d.listingSnapshot.title});
        }
      } else if (age >= const Duration(days: 3) && d.lastReminderAt == null) {
        d.lastReminderAt = now;
        if (d.buyerId != null) {
          NotificationService.instance.add(userId: d.buyerId!, type: 'deal_reminder_d3', dealId: d.id, title: 'Reminder: confirm this purchase', body: d.listingSnapshot.title, params: {'title': d.listingSnapshot.title});
        }
      }
    }
    _advanceReviewCalendar(now);
    notifyListeners();
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  TGPurchaseReview? reviewById(String id) => reviews.where((r) => r.id == id).firstOrNull;
  TGPurchaseReview? reviewForDeal(String dealId) => reviews.where((r) => r.dealId == dealId).firstOrNull;
  TGObjection? objectionForReview(String reviewId) => objections.where((o) => o.reviewId == reviewId).firstOrNull;
  List<TGEvidence> evidenceForDeal(String dealId) => evidence.where((e) => e.dealId == dealId).toList();
  List<TGPurchaseReview> reviewsForBuyer(String buyerId) => reviews.where((r) => r.authorId == buyerId).toList();
  List<TGPurchaseReview> reviewsForSeller(String sellerId) => reviews.where((r) => sellerAliases(sellerId).contains(r.sellerId)).toList();

  static Set<String> sellerAliases(String sellerId) {
    if (sellerId == FakeAuthState.mockOwnerId || sellerId == 'seller_technica') {
      return {FakeAuthState.mockOwnerId, 'seller_technica'};
    }
    return {sellerId};
  }

  bool sameSeller(String a, String b) => sellerAliases(a).contains(b);

  List<TGPurchaseReview> publicReviewsFor(String sellerKey) =>
      reviewsForSeller(sellerKey).where((r) => r.isPublicVisible).toList();

  List<TGPurchaseReview> countedReviewsFor(String sellerKey) =>
      reviewsForSeller(sellerKey).where((r) => r.countsTowardRating && !r.hidden).toList();

  double averageFor(String sellerKey) {
    final list = countedReviewsFor(sellerKey);
    if (list.isEmpty) return 0;
    return list.fold<int>(0, (a, r) => a + r.rating) / list.length;
  }

  Map<int, int> countedDistribution(String sellerKey) {
    final m = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in countedReviewsFor(sellerKey)) {
      m[r.rating] = (m[r.rating] ?? 0) + 1;
    }
    return m;
  }

  int notInRatingCount(String sellerKey) => publicReviewsFor(sellerKey).where((r) => !r.countsTowardRating).length;

  void syncStoreRatings() {
    for (final p in TGSellerProfileService.instance.all) {
      final counted = countedReviewsFor(p.sellerKey);
      final avg = counted.isEmpty ? 0.0 : counted.fold<int>(0, (a, r) => a + r.rating) / counted.length;
      TGSellerProfileService.instance.patch(p.publicId, (x) => x.copyWith(rating: (avg * 10).round() / 10, reviewsCount: counted.length));
    }
  }

  bool markHelpful(String reviewId, String actor) {
    final key = '$reviewId|$actor';
    if (!_helpfulKeys.add(key)) return false;
    final r = reviewById(reviewId);
    if (r == null) return false;
    r.helpfulCount++;
    TGAnalytics.track('review_helpful', {'reviewId': reviewId});
    notifyListeners();
    return true;
  }

  bool replyToReview({required String reviewId, required String text, required String actorId}) {
    final r = reviewById(reviewId);
    if (r == null || r.reply != null || text.trim().isEmpty || text.trim().length > 500) return false;
    r.reply = TGPurchaseReply(text: text.trim(), createdAt: TGClock.now());
    TGAnalytics.track('review_reply_submit', {'reviewId': reviewId, 'actorId': actorId});
    notifyListeners();
    return true;
  }

  void setReviewState(String reviewId, TGPurchaseReviewState next, {bool recordUndo = false}) {
    final r = reviewById(reviewId);
    if (r == null) return;
    if (recordUndo) _reviewUndo[reviewId] = r.state;
    r.state = next;
    if (next != TGPurchaseReviewState.pendingCheck) r.hidden = false;
    syncStoreRatings();
    notifyListeners();
  }

  void hideReviewTemporarily(String reviewId) {
    final r = reviewById(reviewId);
    if (r == null) return;
    r.hidden = true;
    syncStoreRatings();
    notifyListeners();
  }

  bool undoReviewState(String reviewId) {
    final prev = _reviewUndo.remove(reviewId);
    final r = reviewById(reviewId);
    if (prev == null || r == null) return false;
    r.state = prev;
    r.hidden = false;
    syncStoreRatings();
    notifyListeners();
    return true;
  }

  TGDeal? confirmedDealWith({required String buyerId, required String sellerId}) {
    return deals.where((d) => d.buyerId == buyerId && sameSeller(d.sellerId, sellerId) && d.isConfirmed).firstOrNull;
  }

  TGPurchaseReview? existingReview({required String authorId, required String listingNo}) =>
      reviews.where((r) => r.authorId == authorId && r.listingNo == listingNo && r.state != TGPurchaseReviewState.removed).firstOrNull;

  void updateReview(TGPurchaseReview review, {required int rating, required String text}) {
    review.rating = rating;
    review.text = text;
    syncStoreRatings();
    notifyListeners();
  }

  bool evidenceRequiredFor(String sellerId) => (unjustObjections90d[sellerId] ?? 0) >= 3;

  int reviewsPostedToday(String authorId) => _reviewsToday['$authorId-${_dayKey(TGClock.now())}'] ?? 0;

  ListingNoCheck checkListingNo({required String listingNo, required String sellerId, required String authorId}) {
    final listing = resolveListing(listingNo);
    if (listing == null) return ListingNoCheck.notFound;
    if (listing.ownerId == authorId || listing.sellerId == authorId) return ListingNoCheck.ownListing;
    if (listing.status == TGListingStatus.removed) return ListingNoCheck.removed;
    final sellerOk = sameSeller(listing.sellerId, sellerId) || (listing.ownerId != null && sameSeller(listing.ownerId!, sellerId));
    if (!sellerOk) return ListingNoCheck.wrongSeller;
    if (reviews.any((r) => r.authorId == authorId && r.listingNo == listingNo && r.state != TGPurchaseReviewState.removed)) {
      return ListingNoCheck.alreadyReviewed;
    }
    return ListingNoCheck.ok;
  }

  TGListingHit? resolveListing(String listingNo) {
    final cached = TGProductService.instance.cachedByNo(listingNo);
    if (cached != null) {
      return TGListingHit(
        listingNo: listingNo,
        title: cached.title,
        imageUrl: cached.imageUrl,
        sellerId: cached.seller.id,
        price: cached.price,
        city: cached.city,
        sellerName: cached.seller.name,
        sellerVerified: cached.seller.verified,
        status: cached.status,
        ownerId: cached.ownerId,
      );
    }
    for (final d in deals) {
      if (d.listingNo == listingNo) {
        return TGListingHit(
          listingNo: listingNo,
          title: d.listingSnapshot.title,
          imageUrl: d.listingSnapshot.imageUrl,
          sellerId: d.sellerId,
          price: d.listingSnapshot.price,
          city: d.listingSnapshot.city,
          sellerName: d.listingSnapshot.sellerName ?? 'Seller',
          sellerVerified: d.listingSnapshot.sellerVerified,
          ownerId: d.sellerId,
        );
      }
    }
    for (final c in conversations) {
      if (c.listingNo == listingNo) {
        return TGListingHit(
          listingNo: listingNo,
          title: 'Listing $listingNo',
          imageUrl: '',
          sellerId: c.sellerId,
          sellerName: 'Technica',
          sellerVerified: true,
          ownerId: c.sellerId,
        );
      }
    }
    return null;
  }

  TGPurchaseReview? submitReviewFirst({
    required FakeAuthState auth,
    required String sellerId,
    required String listingNo,
    required TGDealType dealType,
    required DateTime dealMonth,
    required int rating,
    required String text,
    List<String> riskFlags = const [],
  }) {
    if (reviewsPostedToday(auth.userId) >= 3) return null;
    final check = checkListingNo(listingNo: listingNo, sellerId: sellerId, authorId: auth.userId);
    if (check != ListingNoCheck.ok) return null;
    final listing = resolveListing(listingNo);
    final confirmed = deals.any((d) => d.listingNo == listingNo && d.buyerId == auth.userId && sameSeller(d.sellerId, sellerId) && d.isConfirmed);
    final hold = riskFlags.where((f) => f == 'hold' || f.startsWith('hold')).length >= 2;
    var state = confirmed
        ? TGPurchaseReviewState.confirmed
        : (hold ? TGPurchaseReviewState.pendingCheck : TGPurchaseReviewState.awaitingSeller);
    final snap = listing == null
        ? TGDealSnapshot(title: listingNo, imageUrl: '', price: null, city: '', sellerName: 'Technica', sellerVerified: true)
        : TGDealSnapshot(title: listing.title, imageUrl: listing.imageUrl, price: listing.price, city: listing.city, sellerName: listing.sellerName, sellerVerified: listing.sellerVerified);
    final deal = TGDeal(
      id: _nextId(),
      type: dealType,
      source: TGDealSource.reviewFirst,
      status: confirmed ? TGDealStatus.confirmed : TGDealStatus.pendingSeller,
      verification: confirmed ? TGDealVerification.bothParties : TGDealVerification.none,
      listingNo: listingNo,
      listingSnapshot: snap,
      sellerId: sellerId,
      buyerId: auth.userId,
      identifierType: TGDealIdentifierType.account,
      identifierMasked: auth.displayName,
      sellerConfirmedAt: confirmed ? TGClock.now() : null,
      buyerConfirmedAt: TGClock.now(),
      riskFlags: riskFlags,
    );
    final review = TGPurchaseReview(
      id: 'R-2026-${(_reviewSeq++).toString().padLeft(4, '0')}',
      sellerId: sellerId,
      authorId: auth.userId,
      authorName: auth.displayName,
      dealId: deal.id,
      listingNo: listingNo,
      listingTitleSnapshot: deal.listingSnapshot.title,
      dealType: dealType,
      dealMonth: dealMonth,
      rating: rating,
      text: text,
      state: state,
      riskFlags: riskFlags,
      imageUrl: deal.listingSnapshot.imageUrl,
      price: deal.listingSnapshot.price,
    );
    deal.reviewId = review.id;
    deals.insert(0, deal);
    reviews.insert(0, review);
    _reviewsToday['${auth.userId}-${_dayKey(TGClock.now())}'] = reviewsPostedToday(auth.userId) + 1;
    if (!confirmed) {
      _notify(sellerId, 'review_received', deal.id, deal.listingSnapshot.title, name: auth.displayName, deepLink: '/dashboard/deals?tab=requests');
    }
    _notify(auth.userId, 'review_live', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}');
    TGAnalytics.track('review_submit', {'reviewId': review.id, 'dealId': deal.id, 'state': state.name});
    TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': state.name});
    syncStoreRatings();
    notifyListeners();
    return review;
  }

  void sellerConfirmReview(TGDeal deal, {required bool keepListingActive}) {
    final review = reviewForDeal(deal.id);
    if (review == null) return;
    if (review.state != TGPurchaseReviewState.awaitingSeller && review.state != TGPurchaseReviewState.pendingCheck) return;
    deal.status = TGDealStatus.confirmed;
    deal.verification = TGDealVerification.bothParties;
    deal.sellerConfirmedAt = TGClock.now();
    review.state = TGPurchaseReviewState.confirmed;
    review.keepListingActive = keepListingActive;
    if (!keepListingActive) {
      _markListingSold(deal);
    }
    _notify(deal.buyerId ?? '', 'review_seller_confirmed', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}');
    TGAnalytics.track('seller_answer', {'dealId': deal.id, 'answer': 'yes'});
    TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': 'confirmed'});
    syncStoreRatings();
    notifyListeners();
  }

  void sellerDispute({
    required TGDeal deal,
    required TGObjectionKind kind,
    required String reason,
    String? note,
    List<TGEvidence> sellerFiles = const [],
    TGDealAccount? realBuyer,
  }) {
    final review = reviewForDeal(deal.id);
    if (review == null) return;
    if (review.state != TGPurchaseReviewState.awaitingSeller && review.state != TGPurchaseReviewState.pendingCheck) return;
    if (evidenceRequiredFor(deal.sellerId) && sellerFiles.isEmpty) return;
    final due = deal.sellerAnswerDueAt;
    if (due != null && TGClock.now().isAfter(due)) return;
    final obj = TGObjection(
      id: 'O-2026-${(_objSeq++).toString().padLeft(4, '0')}',
      dealId: deal.id,
      reviewId: review.id,
      kind: kind,
      reason: reason,
      note: note,
    );
    objections.insert(0, obj);
    review.state = TGPurchaseReviewState.suspendedObjection;
    deal.status = TGDealStatus.inModeration;
    if (kind == TGObjectionKind.soldToOther) _markListingSold(deal);
    for (final f in sellerFiles) {
      evidence.add(TGEvidence(id: f.id, dealId: deal.id, uploaderRole: TGEvidenceRole.seller, type: f.type, fileUrl: f.fileUrl, captureCode: f.captureCode, durationSec: f.durationSec));
    }
    if (deal.buyerId != null) {
      _notify(deal.buyerId!, 'review_disputed', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}?evidence=1');
    }
    TGAnalytics.track('objection_submit', {'dealId': deal.id, 'kind': kind.name});
    TGAnalytics.track('seller_answer', {'dealId': deal.id, 'answer': kind.name});
    TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': 'suspended_objection'});
    notifyListeners();
  }

  String addEvidence({
    required String dealId,
    required TGEvidenceRole role,
    required TGEvidenceType type,
    required String fileUrl,
    String? captureCode,
    int? durationSec,
  }) {
    final e = TGEvidence(
      id: 'E-${(_evSeq++).toString().padLeft(4, '0')}',
      dealId: dealId,
      uploaderRole: role,
      type: type,
      fileUrl: fileUrl,
      captureCode: captureCode,
      durationSec: durationSec,
    );
    evidence.add(e);
    TGAnalytics.track('evidence_upload', {'dealId': dealId, 'type': type.name});
    notifyListeners();
    return e.id;
  }

  bool submitBuyerEvidence(String dealId, {required String note}) {
    final obj = objections.where((o) => o.dealId == dealId && o.status == TGObjectionStatus.awaitingEvidence).firstOrNull;
    if (obj == null) return false;
    final files = evidenceForDeal(dealId).where((e) => e.uploaderRole == TGEvidenceRole.buyer);
    final hasStrong = files.any((e) => e.type == TGEvidenceType.liveVideo || e.type == TGEvidenceType.paymentTrace || e.type == TGEvidenceType.document);
    if (!hasStrong) return false;
    obj.status = TGObjectionStatus.evidenceReceived;
    obj.note = note;
    TGAnalytics.track('evidence_submit', {'dealId': dealId});
    notifyListeners();
    return true;
  }

  void extendEvidenceOnce(TGObjection obj) {
    if (obj.evidenceExtendedOnce) return;
    obj.evidenceExtendedOnce = true;
    obj.evidenceDueAt = obj.evidenceDueAt.add(const Duration(hours: 48));
    notifyListeners();
  }

  void moderatorDecide(TGObjection obj, TGObjectionDecision decision, {bool markListingSold = true}) {
    final review = reviewById(obj.reviewId);
    final deal = byId(obj.dealId);
    if (review == null || deal == null) return;
    obj.status = TGObjectionStatus.decided;
    obj.decision = decision;
    obj.decidedAt = TGClock.now();
    for (final e in evidenceForDeal(deal.id)) {
      e.deleteAt = TGClock.now().add(const Duration(days: 30));
    }
    switch (decision) {
      case TGObjectionDecision.confirmed:
        review.state = TGPurchaseReviewState.confirmedModerator;
        deal.status = TGDealStatus.confirmed;
        deal.verification = TGDealVerification.moderator;
        unjustObjections90d[deal.sellerId] = (unjustObjections90d[deal.sellerId] ?? 0) + 1;
        if (markListingSold) {
          _markListingSold(deal);
          deal.unitRestoreUntil = TGClock.now().add(const Duration(hours: 24));
        }
      case TGObjectionDecision.removed:
        review.state = TGPurchaseReviewState.removed;
        deal.status = TGDealStatus.rejectedByModerator;
      case TGObjectionDecision.notVerified:
        review.state = TGPurchaseReviewState.notVerified;
        deal.status = TGDealStatus.notVerified;
        deal.verification = TGDealVerification.none;
    }
    _notify(deal.sellerId, 'review_moderator_decision', deal.id, deal.listingSnapshot.title, deepLink: '/dashboard/deals');
    if (deal.buyerId != null) {
      _notify(deal.buyerId!, 'review_moderator_decision', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}');
    }
    TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': review.state.name});
    notifyListeners();
  }

  void restoreUnit(TGDeal deal) {
    if (deal.unitRestoreUntil == null || TGClock.now().isAfter(deal.unitRestoreUntil!)) return;
    deal.unitRestoreUntil = null;
    final listing = TGProductService.instance.cachedByNo(deal.listingNo);
    if (listing != null) {
      TGProductService.instance.upsert(listing.copyWith(status: TGListingStatus.active, isHidden: false));
    }
    TGAnalytics.track('unit_restore_click', {'dealId': deal.id});
    notifyListeners();
  }

  void appealRemoved(TGPurchaseReview review, {required String note}) {
    if (review.appealed || review.state != TGPurchaseReviewState.removed) return;
    review.appealed = true;
    TGAnalytics.track('appeal_submit', {'reviewId': review.id});
    notifyListeners();
  }

  void _markListingSold(TGDeal deal) {
    final listing = TGProductService.instance.cachedByNo(deal.listingNo);
    if (listing == null) return;
    TGProductService.instance.upsert(listing.copyWith(status: TGListingStatus.sold, isHidden: true, soldDealId: deal.id));
  }

  void _notifyOnce(String key, String userId, String type, String dealId, String title, {String? name, String? deepLink}) {
    if (_calendarKeys.contains(key)) return;
    _calendarKeys.add(key);
    _notify(userId, type, dealId, title, name: name, deepLink: deepLink);
  }

  void _notify(String userId, String type, String dealId, String title, {String? name, String? deepLink}) {
    if (userId.isEmpty) return;
    NotificationService.instance.add(
      userId: userId,
      type: type,
      dealId: dealId,
      title: type,
      body: title,
      deepLink: deepLink,
      params: {'title': title, if (name != null) 'name': name},
    );
  }

  void _advanceReviewCalendar(DateTime now) {
    for (final review in reviews) {
      final deal = byId(review.dealId);
      if (deal == null) continue;
      if (review.state == TGPurchaseReviewState.awaitingSeller && deal.sellerAnswerDueAt != null && now.isAfter(deal.sellerAnswerDueAt!)) {
        review.state = TGPurchaseReviewState.notDisputed;
        deal.status = TGDealStatus.notDisputed;
        deal.verification = TGDealVerification.notDisputed;
        _notify(deal.sellerId, 'review_not_disputed', deal.id, deal.listingSnapshot.title, deepLink: '/dashboard/deals');
        if (deal.buyerId != null) _notify(deal.buyerId!, 'review_not_disputed', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}');
        TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': 'not_disputed'});
      } else if (review.state == TGPurchaseReviewState.awaitingSeller && deal.sellerAnswerDueAt != null) {
        final left = deal.sellerAnswerDueAt!.difference(now);
        if (left <= const Duration(days: 3) && left > const Duration(days: 1) && (deal.lastReminderAt == null || now.difference(deal.lastReminderAt!).inHours >= 20)) {
          deal.lastReminderAt = now;
          _notify(deal.sellerId, 'review_seller_d2', deal.id, deal.listingSnapshot.title, deepLink: '/dashboard/deals?tab=requests');
        } else if (left <= const Duration(days: 1) && left > Duration.zero && (deal.lastReminderAt == null || now.difference(deal.lastReminderAt!).inHours >= 12)) {
          deal.lastReminderAt = now;
          _notify(deal.sellerId, 'review_seller_d4', deal.id, deal.listingSnapshot.title, deepLink: '/dashboard/deals?tab=requests');
        }
      }
    }
    for (final obj in objections.where((o) => o.status != TGObjectionStatus.decided)) {
      final files = evidenceForDeal(obj.dealId).where((e) => e.uploaderRole == TGEvidenceRole.buyer);
      final hasStrong = files.any((e) => e.type == TGEvidenceType.liveVideo || e.type == TGEvidenceType.paymentTrace || e.type == TGEvidenceType.document);
      if (obj.status == TGObjectionStatus.awaitingEvidence && now.isAfter(obj.evidenceDueAt) && !hasStrong) {
        obj.status = TGObjectionStatus.noEvidence;
        final deal = byId(obj.dealId);
        if (deal?.buyerId != null) {
          _notifyOnce('ev-exp-${obj.id}', deal!.buyerId!, 'evidence_expired', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${obj.reviewId}');
        }
      } else if (hasStrong && now.isAfter(obj.hardCapAt)) {
        obj.status = TGObjectionStatus.decided;
        obj.decision = TGObjectionDecision.notVerified;
        final review = reviewById(obj.reviewId);
        final deal = byId(obj.dealId);
        if (review != null && deal != null) {
          review.state = TGPurchaseReviewState.notVerified;
          deal.status = TGDealStatus.notVerified;
          deal.verification = TGDealVerification.none;
          _notify(deal.sellerId, 'review_not_verified', deal.id, deal.listingSnapshot.title);
          if (deal.buyerId != null) _notify(deal.buyerId!, 'review_not_verified', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${review.id}');
          TGAnalytics.track('review_state_change', {'reviewId': review.id, 'state': 'not_verified'});
        }
      } else if (obj.status == TGObjectionStatus.awaitingEvidence) {
        final left = obj.evidenceDueAt.difference(now);
        final deal = byId(obj.dealId);
        if (deal?.buyerId == null) continue;
        if (left <= const Duration(hours: 24) && left > const Duration(hours: 6)) {
          _notifyOnce('ev-24-${obj.id}', deal!.buyerId!, 'evidence_due_24h', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${obj.reviewId}?evidence=1');
        } else if (left <= const Duration(hours: 6) && left > Duration.zero) {
          _notifyOnce('ev-6-${obj.id}', deal!.buyerId!, 'evidence_due_6h', deal.id, deal.listingSnapshot.title, deepLink: '/account/reviews/${obj.reviewId}?evidence=1');
        }
      }
    }
  }

  void _seedReviewFirst(DateTime now, TGDealSnapshot snap1, TGDealSnapshot snap2, TGDealSnapshot snap3, String seller) {
    void pair({
      required String dealId,
      required String reviewId,
      required TGPurchaseReviewState state,
      required TGDealStatus dealStatus,
      TGDealVerification? ver,
      required TGDealSnapshot snap,
      required String listingNo,
      String? buyerId,
      String author = 'Marek K.',
      List<String> flags = const [],
      Duration createdAgo = const Duration(days: 1),
    }) {
      final created = now.subtract(createdAgo);
      final deal = TGDeal(
        id: dealId,
        type: TGDealType.sale,
        source: TGDealSource.reviewFirst,
        status: dealStatus,
        verification: ver,
        listingNo: listingNo,
        listingSnapshot: snap,
        sellerId: FakeAuthState.mockOwnerId,
        buyerId: buyerId ?? buyerMarek.userId,
        identifierMasked: author,
        createdAt: created,
        reviewId: reviewId,
        sellerAnswerDueAt: created.add(const Duration(days: 5)),
      );
      deals.add(deal);
      reviews.add(TGPurchaseReview(
        id: reviewId,
        sellerId: FakeAuthState.mockOwnerId,
        authorId: buyerId ?? buyerMarek.userId,
        authorName: author,
        dealId: dealId,
        listingNo: listingNo,
        listingTitleSnapshot: snap.title,
        dealType: TGDealType.sale,
        dealMonth: DateTime(created.year, created.month),
        rating: 5,
        text: 'Bought this unit after viewing it in person. Setup was straightforward and the seller answered quickly.',
        state: state,
        createdAt: created,
        riskFlags: flags,
        imageUrl: snap.imageUrl,
        price: snap.price,
      ));
    }

    pair(dealId: 'D-2026-000201', reviewId: 'R-2026-0001', state: TGPurchaseReviewState.awaitingSeller, dealStatus: TGDealStatus.pendingSeller, ver: TGDealVerification.none, snap: snap1, listingNo: '38705142', createdAgo: const Duration(days: 1));
    pair(dealId: 'D-2026-000202', reviewId: 'R-2026-0002', state: TGPurchaseReviewState.confirmed, dealStatus: TGDealStatus.confirmed, ver: TGDealVerification.bothParties, snap: snap2, listingNo: '39816253', createdAgo: const Duration(days: 8));
    pair(dealId: 'D-2026-000203', reviewId: 'R-2026-0003', state: TGPurchaseReviewState.confirmedModerator, dealStatus: TGDealStatus.confirmed, ver: TGDealVerification.moderator, snap: snap3, listingNo: '40927364', createdAgo: const Duration(days: 10));
    pair(dealId: 'D-2026-000204', reviewId: 'R-2026-0004', state: TGPurchaseReviewState.notDisputed, dealStatus: TGDealStatus.notDisputed, ver: TGDealVerification.notDisputed, snap: snap1, listingNo: '38705142', buyerId: buyerAnna.userId, author: 'Anna W.', createdAgo: const Duration(days: 6));
    pair(dealId: 'D-2026-000205', reviewId: 'R-2026-0005', state: TGPurchaseReviewState.notVerified, dealStatus: TGDealStatus.notVerified, ver: TGDealVerification.none, snap: snap2, listingNo: '39816253', buyerId: buyerPiotr.userId, author: 'Piotr B.', createdAgo: const Duration(days: 9));
    pair(dealId: 'D-2026-000206', reviewId: 'R-2026-0006', state: TGPurchaseReviewState.suspendedObjection, dealStatus: TGDealStatus.inModeration, snap: snap3, listingNo: '40927364', createdAgo: const Duration(hours: 20));
    pair(dealId: 'D-2026-000207', reviewId: 'R-2026-0007', state: TGPurchaseReviewState.pendingCheck, dealStatus: TGDealStatus.pendingSeller, ver: TGDealVerification.none, snap: snap1, listingNo: '38705142', buyerId: buyerAnna.userId, author: 'Anna W.', flags: const ['hold', 'hold_repeat'], createdAgo: const Duration(days: 2));
    pair(dealId: 'D-2026-000208', reviewId: 'R-2026-0008', state: TGPurchaseReviewState.removed, dealStatus: TGDealStatus.rejectedByModerator, snap: snap2, listingNo: '39816253', createdAgo: const Duration(days: 12));
    pair(dealId: 'D-2026-000209', reviewId: 'R-2026-0009', state: TGPurchaseReviewState.awaitingSeller, dealStatus: TGDealStatus.pendingSeller, ver: TGDealVerification.none, snap: snap3, listingNo: '40927364', buyerId: buyerPiotr.userId, author: 'Piotr B.', createdAgo: const Duration(days: 3));
    pair(dealId: 'D-2026-000210', reviewId: 'R-2026-0010', state: TGPurchaseReviewState.suspendedObjection, dealStatus: TGDealStatus.inModeration, snap: snap1, listingNo: '38705142', createdAgo: const Duration(days: 2));
    reviewById('R-2026-0002')!
      ..helpfulCount = 3
      ..reply = TGPurchaseReply(text: 'Thanks for collecting in Gliwice — glad the unit matched the listing.', createdAt: now.subtract(const Duration(days: 2)));

    objections.add(TGObjection(
      id: 'O-2026-0001',
      dealId: 'D-2026-000206',
      reviewId: 'R-2026-0006',
      kind: TGObjectionKind.soldToOther,
      reason: 'Sold to someone else',
      createdAt: now.subtract(const Duration(hours: 20)),
    ));
    objections.add(TGObjection(
      id: 'O-2026-0002',
      dealId: 'D-2026-000210',
      reviewId: 'R-2026-0010',
      kind: TGObjectionKind.notSold,
      reason: 'Still for sale',
      status: TGObjectionStatus.evidenceReceived,
      createdAt: now.subtract(const Duration(days: 2)),
    ));
    evidence.add(TGEvidence(
      id: 'E-0001',
      dealId: 'D-2026-000210',
      uploaderRole: TGEvidenceRole.buyer,
      type: TGEvidenceType.liveVideo,
      fileUrl: 'mock://live/4827',
      durationSec: 12,
      captureCode: '4827',
    ));
    _reviewSeq = 11;
    _objSeq = 3;
    _evSeq = 2;
    _notify(buyerMarek.userId, 'review_disputed', 'D-2026-000206', snap3.title, deepLink: '/account/reviews/R-2026-0006?evidence=1');
  }

  void _seedCatalogReviews(DateTime now) {
    const img = 'assets/images/bartscher_2002170.webp';
    const names = ['Marek K.', 'Anna W.', 'Piotr B.', 'Kasia M.', 'Jan Z.'];
    const ids = ['buyer_marek', 'buyer_anna', 'buyer_piotr', 'buyer_kasia', 'buyer_jan'];
    var seq = 1100;
    void add({
      required String sellerId,
      required String listingNo,
      required String title,
      required int rating,
      required TGPurchaseReviewState state,
      required Duration ago,
      String? text,
    }) {
      final i = seq % names.length;
      final created = now.subtract(ago);
      reviews.add(TGPurchaseReview(
        id: 'R-2026-${seq.toString().padLeft(4, '0')}',
        sellerId: sellerId,
        authorId: ids[i],
        authorName: names[i],
        dealId: 'D-CAT-$seq',
        listingNo: listingNo,
        listingTitleSnapshot: title,
        dealType: TGDealType.sale,
        dealMonth: DateTime(created.year, created.month),
        rating: rating,
        text: text ?? 'Collected this unit as listed. Packaging was intact and the seller was reachable the same day.',
        state: state,
        createdAt: created,
        imageUrl: img,
      ));
      seq++;
    }

    void spread(String sellerId, String listingNo, String title, List<int> stars, {Duration start = const Duration(days: 12)}) {
      for (var i = 0; i < stars.length; i++) {
        add(sellerId: sellerId, listingNo: listingNo, title: title, rating: stars[i], state: TGPurchaseReviewState.confirmed, ago: start + Duration(days: i));
      }
    }

    // Technica already has 3 counted 5★ DEAL-2 rows → add 9×5, 6×4, 8×3, 2×2.
    spread(FakeAuthState.mockOwnerId, '38705142', 'Piec pizza 4 pizze – 3 dni do końca', [
      ...List.filled(9, 5),
      ...List.filled(6, 4),
      ...List.filled(8, 3),
      ...List.filled(2, 2),
    ]);
    spread('seller_gastropl', '30110001', 'Piec konwekcyjny 10 GN – Gastrosilesia', [
      ...List.filled(16, 5),
      ...List.filled(4, 4),
      ...List.filled(4, 3),
    ]);
    add(sellerId: 'seller_gastropl', listingNo: '30110002', title: 'Szafa chłodnicza 1400L', rating: 5, state: TGPurchaseReviewState.awaitingSeller, ago: const Duration(days: 1));
    add(sellerId: 'seller_gastropl', listingNo: '30110003', title: 'Stół centralny 2000 mm', rating: 4, state: TGPurchaseReviewState.notVerified, ago: const Duration(days: 11));
    spread('seller_ek', '30220001', 'Zmywarka podszafkowa EK', [5, 5, 4, 4, 4, 3, 3, 3, 2, 2]);
    add(sellerId: 'seller_ek', listingNo: '30220002', title: 'Stół roboczy 1500 mm', rating: 5, state: TGPurchaseReviewState.awaitingSeller, ago: const Duration(days: 2));
    spread('seller_rm', '30330001', 'Linia Rational iCombi – RM', [
      ...List.filled(20, 5),
      ...List.filled(6, 4),
      ...List.filled(3, 3),
      2,
    ]);
    add(sellerId: 'seller_rm', listingNo: '30330002', title: 'Komora chłodnicza 12 m²', rating: 3, state: TGPurchaseReviewState.notVerified, ago: const Duration(days: 8));
    spread('seller_primegastro', '10482137', 'PrimeGastro warewasher line', [5, 5, 4, 4, 4, 3, 3, 3, 2, 2]);
    spread('seller_gastrolab', '99010001', 'GastroLab prep table', [5, 4]);
    spread('seller_mateusz', '16038472', 'Used slicer – Mateusz K.', [5, 4]);
    spread('seller_oldkitchen', '77030001', 'OldKitchen range', [4, 4, 4, 3, 2, 2, 2]);
    spread('seller_nordgastro', '88040001', 'NordGastro mixer', [2, 2]);
    _reviewSeq = 2000;
  }
}
