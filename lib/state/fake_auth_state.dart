import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum TGStorePlanKind { basic, pro, enterprise }

enum TGHeaderPillKind {
  needsAttention,
  expiredListings,
  expiringListings,
  store,
  noListings,
  freeQuota,
  noQuota,
}

enum TGListingPlan { free, paid, store, storeFull }

enum TGEntitlementScenario {
  noListings,
  freeActive,
  freeNoListingsLeft,
  needsAttention,
  listingExpiringSoon,
  hasExpired,
  storeSubscriber,
}

enum TGUserRole { visitor, seller, storeSeller, moderator, admin }

extension TGUserRoleLabel on TGUserRole {
  String get label => switch (this) {
        TGUserRole.visitor => 'Visitor',
        TGUserRole.seller => 'Seller',
        TGUserRole.storeSeller => 'Store seller',
        TGUserRole.moderator => 'Moderator',
        TGUserRole.admin => 'Admin',
      };

  bool get isStaff => this == TGUserRole.moderator || this == TGUserRole.admin;
}

/// Mock-only auth/session state.
///
/// Business rules (see [TGPricing]):
///  * every account has 3 free listing slots that never expire;
///  * a slot is spent when a listing is published (not on draft);
///  * expiry, deletion or moderator removal does not refund a slot;
///  * every listing (free or paid) has its own 30-day clock from publish.
class FakeAuthState extends ChangeNotifier {
  FakeAuthState({bool isLoggedIn = false}) : _isLoggedIn = isLoggedIn {
    setScenario(TGEntitlementScenario.hasExpired, notify: false);
  }

  bool _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn;

  String userId = mockOwnerId;
  String userInitials = 'TG';
  TGUserRole role = TGUserRole.seller;
  TGSellerType sellerType = TGSellerType.private;
  int freeSlotsUsed = 0;
  TGStorePlanKind? storePlan;

  String storePlanLabel = 'Basic Store';
  int storeActiveUsed = 11;
  int storeActiveLimit = 15;

  List<TGProduct> ownedListings = const [];
  TGCheckoutCart? checkoutCart;

  int get freeListingsTotal => TGPricing.freeListingQuota;
  int get freeListingsLeft => (freeListingsTotal - freeSlotsUsed).clamp(0, freeListingsTotal);

  static const String mockOwnerId = 'seller_tg';
  static const String mockStoreSellerId = 'seller_gastropl';

  static const TGSeller mockOwnerSeller = TGSeller(
    id: mockOwnerId,
    name: 'TG Demo',
    type: TGSellerType.private,
    verified: false,
    rating: 4.5,
  );

  TGEntitlementScenario _scenario = TGEntitlementScenario.hasExpired;
  TGEntitlementScenario get scenario => _scenario;

  List<TGProduct> get publishedListings =>
      ownedListings.where((p) => p.status != TGListingStatus.draft && p.status != TGListingStatus.paymentPending).toList();

  List<TGProduct> get ownedActive => ownedListings.where((p) => p.isActive).toList();
  List<TGProduct> get ownedExpired => ownedListings.where((p) => p.status == TGListingStatus.expired).toList();
  List<TGProduct> get ownedExpiringSoon => ownedActive.where((p) => p.isExpiringSoon).toList();
  List<TGProduct> get ownedNeedsAttention => ownedListings.where((p) => p.status == TGListingStatus.underReview).toList();

  TGHeaderPillKind get pillKind {
    if (ownedNeedsAttention.isNotEmpty) return TGHeaderPillKind.needsAttention;
    if (ownedExpired.isNotEmpty) return TGHeaderPillKind.expiredListings;
    if (ownedExpiringSoon.isNotEmpty) return TGHeaderPillKind.expiringListings;
    if (storePlan != null) return TGHeaderPillKind.store;
    if (publishedListings.isEmpty) return TGHeaderPillKind.noListings;
    if (freeListingsLeft <= 0) return TGHeaderPillKind.noQuota;
    return TGHeaderPillKind.freeQuota;
  }

  bool get pillIsProblem =>
      pillKind == TGHeaderPillKind.needsAttention ||
      pillKind == TGHeaderPillKind.expiredListings ||
      pillKind == TGHeaderPillKind.expiringListings;

  int get mobileBadgeCount {
    if (pillKind == TGHeaderPillKind.needsAttention) return ownedNeedsAttention.length;
    if (pillKind == TGHeaderPillKind.expiredListings) return ownedExpired.length;
    if (pillKind == TGHeaderPillKind.expiringListings) return ownedExpiringSoon.length;
    if (storePlan != null) return 0;
    return freeListingsLeft;
  }

  TGListingPlan get listingPlan {
    if (storePlan != null) {
      final used = ownedActive.length > storeActiveUsed ? ownedActive.length : storeActiveUsed;
      return used >= storeActiveLimit ? TGListingPlan.storeFull : TGListingPlan.store;
    }
    if (freeListingsLeft > 0) return TGListingPlan.free;
    return TGListingPlan.paid;
  }

  String get mockEmail => role == TGUserRole.storeSeller ? 'hello@gastropl.pl' : 'tg.demo@twojagastromania.pl';

  bool get canModerate => isLoggedIn && role.isStaff;
  bool get isAdmin => isLoggedIn && role == TGUserRole.admin;
  String get staffLabel => role.label;

  void setRole(TGUserRole next, {bool notify = true}) {
    role = next;
    switch (next) {
      case TGUserRole.visitor:
        _isLoggedIn = false;
        userId = 'visitor';
        userInitials = 'V';
        break;
      case TGUserRole.seller:
        _isLoggedIn = true;
        userId = mockOwnerId;
        userInitials = 'TG';
        if (sellerType == TGSellerType.store && storePlan == null) {
          sellerType = TGSellerType.private;
        }
        break;
      case TGUserRole.storeSeller:
        _isLoggedIn = true;
        setScenario(TGEntitlementScenario.storeSubscriber, notify: false);
        role = TGUserRole.storeSeller;
        break;
      case TGUserRole.moderator:
        _isLoggedIn = true;
        userId = 'staff_moderator';
        userInitials = 'MD';
        break;
      case TGUserRole.admin:
        _isLoggedIn = true;
        userId = 'staff_admin';
        userInitials = 'AD';
        break;
    }
    if (notify) notifyListeners();
  }

  bool ownsListing(TGProduct product) {
    if (!isLoggedIn) return false;
    if (product.ownerKey == userId) return true;
    if (ownedListings.any((p) => p.id == product.id)) return true;
    if (storePlan != null && product.seller.id == mockStoreSellerId) return true;
    return false;
  }

  void setScenario(TGEntitlementScenario next, {bool notify = true}) {
    _scenario = next;
    storePlan = null;
    sellerType = TGSellerType.private;
    if (!role.isStaff && role != TGUserRole.visitor) {
      role = next == TGEntitlementScenario.storeSubscriber ? TGUserRole.storeSeller : TGUserRole.seller;
      userId = next == TGEntitlementScenario.storeSubscriber ? mockStoreSellerId : mockOwnerId;
      userInitials = 'TG';
    } else if (!role.isStaff) {
      userId = mockOwnerId;
      userInitials = 'TG';
    }
    storePlanLabel = 'Basic Store';
    storeActiveUsed = 11;
    storeActiveLimit = 15;

    switch (next) {
      case TGEntitlementScenario.noListings:
        freeSlotsUsed = 0;
        ownedListings = const [];
        break;
      case TGEntitlementScenario.freeActive:
        freeSlotsUsed = 1;
        ownedListings = [
          _own(
            id: 'own_b1',
            title: 'Kuchenka indukcyjna 4-palnikowa – linia demo',
            listingNo: '31038475',
            publishedAgo: const Duration(days: 12),
            expiresIn: const Duration(days: 18),
            slot: 1,
          ),
        ];
        break;
      case TGEntitlementScenario.freeNoListingsLeft:
        freeSlotsUsed = 3;
        ownedListings = [
          _own(id: 'own_c1', title: 'Piec konwekcyjny – slot 1', listingNo: '32149586', publishedAgo: const Duration(days: 10), expiresIn: const Duration(days: 20), slot: 1),
          _own(id: 'own_c2', title: 'Zmywarka kapturowa – slot 2', listingNo: '33250697', publishedAgo: const Duration(days: 8), expiresIn: const Duration(days: 22), slot: 2),
          _own(id: 'own_c3', title: 'Stół inox 180 – slot 3', listingNo: '34361708', publishedAgo: const Duration(days: 6), expiresIn: const Duration(days: 24), slot: 3),
        ];
        break;
      case TGEntitlementScenario.needsAttention:
        freeSlotsUsed = 1;
        ownedListings = [
          _own(
            id: 'own_review1',
            title: 'Kocioł warzelny 150L – uzupełnij informacje',
            listingNo: '43250697',
            publishedAgo: const Duration(days: 4),
            expiresIn: const Duration(days: 26),
            slot: 1,
            status: TGListingStatus.underReview,
          ),
        ];
        break;
      case TGEntitlementScenario.listingExpiringSoon:
        freeSlotsUsed = 3;
        ownedListings = [
          _own(id: 'own_e1', title: 'Grill lawowy – kończy się za 3 dni', listingNo: '35472819', publishedAgo: const Duration(days: 27), expiresIn: const Duration(days: 3), slot: 1),
          _own(id: 'own_e2', title: 'Krajalnica do wędlin', listingNo: '36583920', publishedAgo: const Duration(days: 8), expiresIn: const Duration(days: 22), slot: 2),
          _own(id: 'own_e3', title: 'Frytkownica 8L', listingNo: '37694031', publishedAgo: const Duration(days: 5), expiresIn: const Duration(days: 25), slot: 3),
          _own(id: 'own_e_draft', title: 'Szkic: blender barmański', draft: true),
        ];
        break;
      case TGEntitlementScenario.hasExpired:
        freeSlotsUsed = 3;
        ownedListings = [
          _own(id: 'own_f1', title: 'Piec pizza 4 pizze – 3 dni do końca', listingNo: '38705142', publishedAgo: const Duration(days: 27), expiresIn: const Duration(days: 3), slot: 1),
          _own(id: 'own_f2', title: 'Stół chłodniczy 2-drzwiowy', listingNo: '39816253', publishedAgo: const Duration(days: 8), expiresIn: const Duration(days: 22), slot: 2),
          _own(id: 'own_f3', title: 'Zmywarka podszafkowa', listingNo: '40927364', publishedAgo: const Duration(days: 4), expiresIn: const Duration(days: 26), slot: 3),
          _own(id: 'own_f_exp1', title: 'Krajalnica chleba – wygasła', listingNo: '41038475', publishedAgo: const Duration(days: 33), expiredAgo: const Duration(days: 3), slot: 1),
          _own(id: 'own_f_exp2', title: 'Mikser planetarny 20L – wygasł', listingNo: '42149586', publishedAgo: const Duration(days: 38), expiredAgo: const Duration(days: 8), slot: 2),
          _own(id: 'own_f_draft', title: 'Szkic: ekspres 2-grupowy', draft: true),
        ];
        break;
      case TGEntitlementScenario.storeSubscriber:
        sellerType = TGSellerType.store;
        if (!role.isStaff) userId = mockStoreSellerId;
        storePlan = TGStorePlanKind.basic;
        freeSlotsUsed = 0;
        ownedListings = const [];
        break;
    }
    TGListingNo.reserveAll(ownedListings.map((p) => p.listingNo));
    if (notify) notifyListeners();
  }

  void logIn() {
    if (_isLoggedIn) return;
    _isLoggedIn = true;
    if (role == TGUserRole.visitor) role = TGUserRole.seller;
    notifyListeners();
  }

  void logOut() {
    if (!_isLoggedIn) return;
    _isLoggedIn = false;
    role = TGUserRole.visitor;
    notifyListeners();
  }

  void toggle() => _isLoggedIn ? logOut() : logIn();

  /// White-glove support: staff browse the store as that seller.
  void actAsSeller(String sellerKey, {String initials = 'AS'}) {
    _isLoggedIn = true;
    userId = sellerKey;
    userInitials = initials;
    role = TGUserRole.storeSeller;
    sellerType = TGSellerType.store;
    notifyListeners();
  }

  /// Inserts or replaces an owned listing. Drafts do not consume a free slot.
  void upsertOwned(TGProduct listing) {
    final next = [...ownedListings];
    final i = next.indexWhere((p) => p.id == listing.id);
    if (i >= 0) {
      next[i] = listing;
    } else {
      next.insert(0, listing);
    }
    ownedListings = next;
    notifyListeners();
  }

  /// Store-plan listings refund one active slot after a mistaken removal.
  void refundStoreSlot() {
    storeActiveUsed = (storeActiveUsed - 1).clamp(0, storeActiveLimit);
    notifyListeners();
  }

  /// Each free publish consumes one slot. Slots are never refunded.
  TGProduct publishOwned(TGProduct listing, {int promoteDays = 0}) {
    final now = DateTime.now();
    final plan = listingPlan;
    var source = listing.source;
    int? slot = listing.freeSlotIndex;
    if (plan == TGListingPlan.free) {
      source = TGListingSource.free;
      freeSlotsUsed = (freeSlotsUsed + 1).clamp(0, freeListingsTotal);
      slot = freeSlotsUsed;
    } else if (plan == TGListingPlan.store) {
      source = TGListingSource.store;
      storeActiveUsed += 1;
    } else {
      source = TGListingSource.paid;
    }
    final published = listing.copyWith(
      status: TGListingStatus.active,
      publishedAt: now,
      expiresAt: now.add(const Duration(days: TGPricing.listingPeriodDays)),
      source: source,
      freeSlotIndex: slot,
      isPromoted: promoteDays > 0,
      promotedUntil: promoteDays > 0 ? now.add(Duration(days: promoteDays)) : null,
      ownerId: userId,
      listingNo: listing.listingNo ?? TGListingNo.allocate(),
    );
    upsertOwned(published);
    return published;
  }

  void beginCheckout(TGCheckoutCart cart) {
    checkoutCart = cart;
    notifyListeners();
  }

  void clearCheckout() {
    checkoutCart = null;
    notifyListeners();
  }

  TGProduct renewOwned(String id, {int promoteDays = 0, bool early = false}) {
    final listing = ownedListings.firstWhere((p) => p.id == id);
    final now = DateTime.now();
    final base = early && listing.expiresAt != null && listing.expiresAt!.isAfter(now)
        ? listing.expiresAt!
        : now;
    final published = listing.copyWith(
      status: TGListingStatus.active,
      publishedAt: listing.publishedAt ?? now,
      expiresAt: base.add(const Duration(days: TGPricing.listingPeriodDays)),
      source: TGListingSource.paid,
      isPromoted: promoteDays > 0,
      promotedUntil: promoteDays > 0 ? now.add(Duration(days: promoteDays)) : null,
      ownerId: userId,
    );
    upsertOwned(published);
    return published;
  }

  List<TGProduct> renewAllExpired() {
    return [for (final p in [...ownedExpired]) renewOwned(p.id)];
  }

  void subscribeStore(String planId) {
    storePlan = switch (planId) {
      'pro' => TGStorePlanKind.pro,
      'enterprise' => TGStorePlanKind.enterprise,
      _ => TGStorePlanKind.basic,
    };
    storePlanLabel = switch (storePlan!) {
      TGStorePlanKind.pro => 'Pro Store',
      TGStorePlanKind.enterprise => 'Enterprise Store',
      TGStorePlanKind.basic => 'Basic Store',
    };
    storeActiveLimit = switch (storePlan!) {
      TGStorePlanKind.basic => 15,
      TGStorePlanKind.pro => 50,
      TGStorePlanKind.enterprise => 9999,
    };
    sellerType = TGSellerType.store;
    notifyListeners();
  }

  String listingTooltipLines([DateTime? now]) {
    final at = now ?? DateTime.now();
    final rows = <String>[];
    for (final p in publishedListings) {
      if (p.status == TGListingStatus.expired) {
        rows.add('${p.title} · expired ${p.daysSinceExpiry(at)}d ago');
      } else if (p.status == TGListingStatus.underReview) {
        rows.add('${p.title} · needs attention');
      } else if (p.isActive) {
        rows.add('${p.title} · ${p.daysUntilExpiry(at)}d left');
      } else {
        rows.add('${p.title} · ${p.status.name}');
      }
    }
    return rows.join('\n');
  }
}

TGProduct _own({
  required String id,
  required String title,
  String? listingNo,
  Duration? publishedAgo,
  Duration? expiresIn,
  Duration? expiredAgo,
  int? slot,
  bool draft = false,
  TGListingStatus? status,
}) {
  final now = DateTime.now();
  final created = now.subtract(publishedAgo ?? Duration.zero);
  final published = draft ? null : created;
  DateTime? expires;
  var resolved = TGListingStatus.draft;
  if (!draft) {
    if (expiredAgo != null) {
      resolved = TGListingStatus.expired;
      expires = now.subtract(expiredAgo);
    } else {
      resolved = status ?? TGListingStatus.active;
      expires = now.add(expiresIn ?? const Duration(days: TGPricing.listingPeriodDays));
    }
  }
  if (listingNo != null) TGListingNo.reserve(listingNo);
  return TGProduct(
    id: id,
    title: title,
    price: 2500,
    priceUnit: TGPriceUnit.oneTime,
    priceBasis: TGPriceBasis.netto,
    negotiable: false,
    oldPrice: null,
    condition: TGCondition.used,
    listingType: TGListingType.buy,
    category: TGCategory.cookingEquipment,
    powerType: TGPowerType.electric,
    warrantyMonths: 3,
    delivery: true,
    pickup: true,
    seller: FakeAuthState.mockOwnerSeller,
    city: 'Katowice',
    voivodeship: 'Śląskie',
    phone: '+48 (532) 784-074',
    imageUrl: 'assets/images/bartscher_2002170.webp',
    photoCount: 4,
    isPromoted: false,
    createdAt: created,
    description: title,
    status: resolved,
    publishedAt: published,
    expiresAt: expires,
    source: TGListingSource.free,
    freeSlotIndex: slot,
    ownerId: FakeAuthState.mockOwnerId,
    listingNo: draft ? null : listingNo,
  );
}
