import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class TGReviewService extends ChangeNotifier {
  TGReviewService._();
  static final TGReviewService instance = TGReviewService._();

  final List<TGStoreReview> _reviews = [];
  final Set<String> _helpfulKeys = {};
  int _seq = 0;
  bool _loaded = false;

  void reset() {
    _reviews.clear();
    _helpfulKeys.clear();
    _seq = 0;
    _loaded = false;
    ensureSeeded();
  }

  void ensureSeeded() {
    if (_loaded) return;
    _loaded = true;
    _reviews.addAll(_seedReviews());
    _seq = _reviews.length;
    _syncAllStores();
  }

  List<TGStoreReview> get all => List.unmodifiable(_reviews);

  List<TGStoreReview> publishedFor(String sellerId) {
    ensureSeeded();
    return _reviews.where((r) => r.sellerId == sellerId && r.isPublic).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<TGStoreReview> forSeller(String sellerId, {bool includeHidden = false}) {
    ensureSeeded();
    return _reviews.where((r) => r.sellerId == sellerId && (includeHidden || r.isPublic)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  TGStoreReview? byId(String id) {
    ensureSeeded();
    return _reviews.where((r) => r.id == id).firstOrNull;
  }

  List<TGStoreReview> byAuthor(String authorId, {String? exceptId}) {
    ensureSeeded();
    return _reviews.where((r) => r.authorId == authorId && r.id != exceptId).toList();
  }

  List<TGStoreReview> sameSignal({required String ip, required String phone, String? exceptId}) {
    ensureSeeded();
    return _reviews.where((r) => r.id != exceptId && (r.authorIp == ip || r.authorPhone == phone)).toList();
  }

  TGStoreReview? byAuthorAndSeller(String authorId, String sellerId) {
    ensureSeeded();
    return _reviews.where((r) => r.authorId == authorId && r.sellerId == sellerId && r.status != TGReviewStatus.removed).firstOrNull;
  }

  Map<int, int> distribution(String sellerId) {
    final counts = {for (var i = 1; i <= 5; i++) i: 0};
    for (final r in publishedFor(sellerId)) {
      counts[r.rating] = (counts[r.rating] ?? 0) + 1;
    }
    return counts;
  }

  double average(String sellerId) {
    final list = publishedFor(sellerId);
    if (list.isEmpty) return 0;
    return list.fold<int>(0, (s, r) => s + r.rating) / list.length;
  }

  TGReviewBlock gate({required TGStoreProfile store, required FakeAuthState auth, bool ignoreExisting = false}) {
    if (!auth.isLoggedIn) return TGReviewBlock.none;
    if (auth.userId == store.sellerKey) return TGReviewBlock.ownStore;
    if (_sameIdentity(store, auth)) return TGReviewBlock.sameIdentity;
    if (!ignoreExisting && byAuthorAndSeller(auth.userId, store.sellerKey) != null) return TGReviewBlock.alreadyReviewed;
    return TGReviewBlock.none;
  }

  static const _sellerEmails = {
    'seller_technica': 'office@technica.pro',
    'seller_gastropl': 'hello@gastropl.pl',
    'seller_primegastro': 'biuro@primegastro.pl',
    'seller_mateusz': 'mateusz.k@example.com',
    'seller_anna': 'anna.p@example.com',
  };

  bool _sameIdentity(TGStoreProfile store, FakeAuthState auth) {
    final email = _sellerEmails[store.sellerKey];
    if (email != null && email.toLowerCase() == auth.mockEmail.toLowerCase()) return true;
    final mine = TGSellerProfileService.instance.bySellerKey(auth.userId);
    if (mine?.nip != null && mine!.nip!.isNotEmpty && store.nip != null && mine.nip == store.nip) return true;
    const demoDigits = '48532784074';
    String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');
    final storePhone = digits(store.phone);
    final userPhone = digits(AccountIdentityDigits.phoneOf(auth));
    if (storePhone.isNotEmpty && storePhone == userPhone && storePhone != demoDigits && !storePhone.endsWith(demoDigits)) {
      return true;
    }
    return false;
  }

  TGReviewSubmitResult submit({
    required TGStoreProfile store,
    required FakeAuthState auth,
    required int rating,
    required String text,
    required TGReviewDeclaration declaration,
    String? listingNo,
    String? listingTitle,
    bool editing = false,
  }) {
    ensureSeeded();
    final block = gate(store: store, auth: auth, ignoreExisting: editing);
    if (block == TGReviewBlock.ownStore || block == TGReviewBlock.sameIdentity) {
      return TGReviewSubmitResult(block: block);
    }
    final existing = byAuthorAndSeller(auth.userId, store.sellerKey);
    if (existing != null && !editing) {
      return TGReviewSubmitResult(block: TGReviewBlock.alreadyReviewed, existing: existing);
    }
    if (editing && existing != null) {
      if (!existing.canEditAt(DateTime.now())) {
        return TGReviewSubmitResult(block: TGReviewBlock.alreadyReviewed, existing: existing);
      }
      final i = _reviews.indexWhere((r) => r.id == existing.id);
      final next = existing.copyWith(
        rating: rating,
        text: text,
        declaration: declaration,
        listingNo: listingNo,
        listingTitle: listingTitle,
        updatedAt: DateTime.now(),
      );
      _reviews[i] = next;
      _syncStore(store.sellerKey);
      TGAnalytics.track('review_submit', {'sellerId': store.sellerKey, 'rating': rating, 'edit': true});
      notifyListeners();
      return TGReviewSubmitResult(review: next);
    }
    final review = TGStoreReview(
      id: 'rv_${++_seq}',
      sellerId: store.sellerKey,
      authorName: _displayName(auth),
      authorId: auth.userId,
      rating: rating,
      text: text,
      declaration: declaration,
      listingNo: listingNo,
      listingTitle: listingTitle,
      createdAt: DateTime.now(),
      authorEmail: auth.mockEmail,
      authorPhone: AccountIdentityDigits.phoneOf(auth),
    );
    _reviews.add(review);
    _syncStore(store.sellerKey);
    TGAnalytics.track('review_submit', {'sellerId': store.sellerKey, 'rating': rating, 'reviewId': review.id});
    notifyListeners();
    return TGReviewSubmitResult(review: review);
  }

  bool markHelpful(String reviewId, String userKey) {
    ensureSeeded();
    final key = '$userKey|$reviewId';
    if (_helpfulKeys.contains(key)) return false;
    final i = _reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) return false;
    _helpfulKeys.add(key);
    _reviews[i] = _reviews[i].copyWith(helpfulCount: _reviews[i].helpfulCount + 1);
    TGAnalytics.track('review_helpful', {'reviewId': reviewId});
    notifyListeners();
    return true;
  }

  bool hasMarkedHelpful(String reviewId, String userKey) => _helpfulKeys.contains('$userKey|$reviewId');

  TGStoreReview? reply({required String reviewId, required String text, required String actorId}) {
    ensureSeeded();
    final i = _reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) return null;
    final current = _reviews[i];
    if (current.reply != null) return current;
    if (actorId != current.sellerId) return current;
    final next = current.copyWith(reply: TGReviewReply(text: text, createdAt: DateTime.now()));
    _reviews[i] = next;
    TGAnalytics.track('review_reply_submit', {'reviewId': reviewId, 'sellerId': current.sellerId});
    notifyListeners();
    return next;
  }

  TGReviewStatus? _undoStatus;
  String? _undoId;

  void setStatus(String reviewId, TGReviewStatus status, {bool recordUndo = false}) {
    ensureSeeded();
    final i = _reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) return;
    if (recordUndo) {
      _undoId = reviewId;
      _undoStatus = _reviews[i].status;
    }
    _reviews[i] = _reviews[i].copyWith(status: status);
    _syncStore(_reviews[i].sellerId);
    notifyListeners();
  }

  bool undoStatus(String reviewId) {
    if (_undoId != reviewId || _undoStatus == null) return false;
    final i = _reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) return false;
    _reviews[i] = _reviews[i].copyWith(status: _undoStatus);
    _undoId = null;
    _undoStatus = null;
    _syncStore(_reviews[i].sellerId);
    notifyListeners();
    return true;
  }

  void _syncAllStores() {
    final ids = _reviews.map((r) => r.sellerId).toSet();
    for (final id in ids) {
      _syncStore(id, notify: false);
    }
  }

  void _syncStore(String sellerId, {bool notify = true}) {
    final store = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (store == null) return;
    final list = publishedFor(sellerId);
    final avg = list.isEmpty ? 0.0 : (list.fold<int>(0, (s, r) => s + r.rating) / list.length);
    final rounded = list.isEmpty ? 0.0 : (avg * 10).round() / 10;
    TGSellerProfileService.instance.patch(store.publicId, (p) => p.copyWith(rating: rounded, reviewsCount: list.length));
  }

  static String _displayName(FakeAuthState auth) {
    final raw = auth.userId == FakeAuthState.mockOwnerId ? FakeAuthState.mockOwnerSeller.name : auth.userInitials;
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.length <= 2 ? '${parts.first}.' : '${parts.first[0].toUpperCase()}.';
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }
}

abstract final class AccountIdentityDigits {
  static String phoneOf(FakeAuthState auth) {
    final mine = TGSellerProfileService.instance.bySellerKey(auth.userId);
    return mine?.phone ?? '+48 532 784 074';
  }
}

List<TGStoreReview> _seedReviews() {
  final now = DateTime(2026, 10, 8, 12);
  const names = [
    'Marek K.',
    'Ola W.',
    'Piotr B.',
    'Kasia M.',
    'Jan N.',
    'Anna L.',
    'Tomasz R.',
    'Ewa S.',
    'Paweł G.',
    'Magda H.',
    'Krzysztof D.',
    'Natalia P.',
    'Adam C.',
    'Joanna F.',
    'Michał Z.',
  ];
  const decls = [TGReviewDeclaration.bought, TGReviewDeclaration.contacted, TGReviewDeclaration.visited];
  const shorts = [
    'Pickup was organised the same week and the unit matched the photos.',
    'Clear answers on the phone and a fair price for a used combi.',
    'Visited the workshop in Gliwice — tidy stock and honest condition notes.',
    'Invoice arrived the next day. Would buy again from this seller.',
    'Delivery took a bit longer than promised but the machine runs well.',
    'Staff walked me through the controls. Helpful and straightforward.',
    'Good communication, no surprises on collection.',
    'The serial plate was intact and the hours looked right.',
  ];
  const longText =
      'We compared three quotes before choosing this seller. The listing photos matched the unit we collected, including the wear on the left door gasket which they had already described. Payment was made by transfer after we inspected the machine in the yard, and they packed the accessories so nothing was missing. Commissioning at our site took an afternoon and the only extra work was a new water filter which they flagged in advance. I would use them again for a warewasher.';

  TGStoreReview make({
    required String id,
    required String sellerId,
    required int index,
    required int rating,
    required Duration ago,
    String? listingNo,
    String? listingTitle,
    bool reply = false,
    bool long = false,
    TGReviewDeclaration? declaration,
    String? authorId,
    String? authorName,
    String ip = '83.11.10.4',
    String phone = '+48 600 100 200',
    int helpful = 0,
  }) {
    final name = authorName ?? names[index % names.length];
    return TGStoreReview(
      id: id,
      sellerId: sellerId,
      authorName: name,
      authorId: authorId ?? 'u_${name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}_$index',
      rating: rating,
      text: long ? longText : shorts[index % shorts.length],
      declaration: declaration ?? decls[index % decls.length],
      listingNo: listingNo,
      listingTitle: listingTitle,
      createdAt: now.subtract(ago),
      helpfulCount: helpful,
      reply: reply
          ? TGReviewReply(
              text: 'Thank you for the visit — we are glad the unit is running in your kitchen.',
              createdAt: now.subtract(ago).add(const Duration(days: 1)),
            )
          : null,
      authorIp: ip,
      authorPhone: phone,
      authorEmail: '${name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}@example.com',
    );
  }

  List<TGStoreReview> spread({
    required String prefix,
    required String sellerId,
    required List<int> stars,
    String? listingNo,
    String? listingTitle,
    Set<int> replies = const {},
    Set<int> longs = const {},
  }) {
    return [
      for (var i = 0; i < stars.length; i++)
        make(
          id: '$prefix${(i + 1).toString().padLeft(2, '0')}',
          sellerId: sellerId,
          index: i,
          rating: stars[i],
          ago: Duration(days: i + 1, hours: i * 2),
          listingNo: i % 4 == 0 ? listingNo : null,
          listingTitle: i % 4 == 0 ? listingTitle : null,
          reply: replies.contains(i),
          long: longs.contains(i),
          helpful: i % 5 == 0 ? 3 + (i % 4) : (i % 3),
          ip: i == 1 ? '83.11.22.9' : '83.11.10.4',
          phone: i == 1 ? '+48 600 888 111' : '+48 600 100 200',
        ),
    ];
  }

  return [
    ...spread(
      prefix: 'rv_tech_',
      sellerId: 'seller_technica',
      stars: const [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2],
      listingNo: '18293046',
      listingTitle: 'Zmywarka kapturowa — Technica',
      replies: const {0, 3, 8},
      longs: const {0, 5, 12},
    ),
    ...spread(
      prefix: 'rv_gs_',
      sellerId: 'seller_gastropl',
      stars: const [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
      listingNo: '30110001',
      listingTitle: 'Piec konwekcyjny 10 GN – Gastrosilesia',
      replies: const {1, 4},
      longs: const {2},
    ),
    ...spread(
      prefix: 'rv_ek_',
      sellerId: 'seller_ek',
      stars: const [5, 5, 5, 4, 4, 3, 3, 2, 2, 2],
      listingNo: '30220001',
      listingTitle: 'Zmywarka podszafkowa EK',
      replies: const {0},
    ),
    ...spread(
      prefix: 'rv_rm_',
      sellerId: 'seller_rm',
      stars: const [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
      listingNo: '30330001',
      listingTitle: 'Linia Rational iCombi – RM',
      replies: const {2, 9},
    ),
    ...spread(
      prefix: 'rv_pg_',
      sellerId: 'seller_primegastro',
      stars: const [5, 5, 5, 4, 4, 3, 3, 2, 2, 2],
      listingNo: '10482137',
      listingTitle: 'Piec konwekcyjno-parowy 10x GN 1/1 – Bartscher',
      replies: const {1},
      longs: const {0},
    ),
    make(
      id: 'rv_lab_01',
      sellerId: 'seller_gastrolab',
      index: 0,
      rating: 5,
      ago: const Duration(days: 6),
      declaration: TGReviewDeclaration.visited,
      helpful: 1,
    ),
    make(
      id: 'rv_lab_02',
      sellerId: 'seller_gastrolab',
      index: 1,
      rating: 4,
      ago: const Duration(days: 3),
      declaration: TGReviewDeclaration.contacted,
    ),
    make(id: 'rv_mk_01', sellerId: 'seller_mateusz', index: 0, rating: 5, ago: const Duration(days: 20)),
    make(id: 'rv_mk_02', sellerId: 'seller_mateusz', index: 1, rating: 4, ago: const Duration(days: 11)),
    make(id: 'rv_an_01', sellerId: 'seller_anna', index: 0, rating: 5, ago: const Duration(days: 40)),
    make(id: 'rv_an_02', sellerId: 'seller_anna', index: 1, rating: 5, ago: const Duration(days: 22)),
    make(id: 'rv_an_03', sellerId: 'seller_anna', index: 2, rating: 4, ago: const Duration(days: 14)),
    make(id: 'rv_an_04', sellerId: 'seller_anna', index: 3, rating: 4, ago: const Duration(days: 4)),
    make(id: 'rv_ok_01', sellerId: 'seller_oldkitchen', index: 0, rating: 5, ago: const Duration(days: 80)),
    make(id: 'rv_ok_02', sellerId: 'seller_oldkitchen', index: 1, rating: 4, ago: const Duration(days: 70)),
    make(id: 'rv_ok_03', sellerId: 'seller_oldkitchen', index: 2, rating: 3, ago: const Duration(days: 55)),
    make(id: 'rv_ok_04', sellerId: 'seller_oldkitchen', index: 3, rating: 3, ago: const Duration(days: 40)),
    make(id: 'rv_ok_05', sellerId: 'seller_oldkitchen', index: 4, rating: 2, ago: const Duration(days: 30)),
    make(id: 'rv_ok_06', sellerId: 'seller_oldkitchen', index: 5, rating: 2, ago: const Duration(days: 18)),
    make(id: 'rv_ok_07', sellerId: 'seller_oldkitchen', index: 6, rating: 2, ago: const Duration(days: 9)),
    make(id: 'rv_ng_01', sellerId: 'seller_nordgastro', index: 0, rating: 2, ago: const Duration(days: 50)),
    make(id: 'rv_ng_02', sellerId: 'seller_nordgastro', index: 1, rating: 2, ago: const Duration(days: 12)),
  ];
}
