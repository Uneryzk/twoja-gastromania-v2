import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/favorites_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

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

enum TGUserRole { visitor, seller, storeSeller, moderator, admin, buyer }

class StoreOwnerDevPick {
  const StoreOwnerDevPick({
    required this.sellerKey,
    required this.labelKey,
    required this.plan,
    required this.planLabel,
    this.promotedUsed = 0,
  });

  final String sellerKey;
  /// l10n key — brand names stay in the translated string.
  final String labelKey;
  final TGStorePlanKind plan;
  final String planLabel;
  final int promotedUsed;

  /// Approved store — Technica Pro (also used by older tests as [technica]).
  static const technica = StoreOwnerDevPick(
    sellerKey: 'seller_technica',
    labelKey: 'ui_dev_store_technica',
    plan: TGStorePlanKind.basic,
    planLabel: 'Basic Store',
  );

  /// Approved store — Gastrosilesia.pl
  static const gastroPro = StoreOwnerDevPick(
    sellerKey: 'seller_gastropl',
    labelKey: 'ui_dev_store_gastro',
    plan: TGStorePlanKind.pro,
    planLabel: 'Pro Store',
    promotedUsed: 2,
  );

  /// Kept for tests / manufacturer-adjacent store chrome (RM).
  static const rmEnterprise = StoreOwnerDevPick(
    sellerKey: 'seller_rm',
    labelKey: 'ui_dev_maker_rm',
    plan: TGStorePlanKind.enterprise,
    planLabel: 'Enterprise Store',
    promotedUsed: 1,
  );

  static const pendingApproval = StoreOwnerDevPick(
    sellerKey: 'seller_gastrolab',
    labelKey: 'ui_dev_store_pending',
    plan: TGStorePlanKind.basic,
    planLabel: 'Basic Store',
  );

  static const suspended = StoreOwnerDevPick(
    sellerKey: 'seller_nordgastro',
    labelKey: 'ui_dev_store_suspended',
    plan: TGStorePlanKind.basic,
    planLabel: 'Basic Store',
  );

  /// Corporate store rows shown in the Dev Switcher.
  static const all = [technica, gastroPro, pendingApproval, suspended];
}

/// Special-order manufacturer personas for the Dev Switcher (names unchanged).
class ManufacturerDevPick {
  const ManufacturerDevPick({
    required this.sellerKey,
    required this.labelKey,
    required this.plan,
    required this.planLabel,
    this.promotedUsed = 0,
    this.forceInactive = false,
  });

  final String sellerKey;
  final String labelKey;
  final TGStorePlanKind plan;
  final String planLabel;
  final int promotedUsed;
  final bool forceInactive;

  static const rm = ManufacturerDevPick(
    sellerKey: 'seller_rm',
    labelKey: 'ui_dev_maker_rm',
    plan: TGStorePlanKind.enterprise,
    planLabel: 'Enterprise Store',
    promotedUsed: 1,
  );

  static const stalbar = ManufacturerDevPick(
    sellerKey: 'seller_stalbar',
    labelKey: 'ui_dev_maker_stalbar',
    plan: TGStorePlanKind.enterprise,
    planLabel: 'Enterprise Store',
  );

  static const inoxline = ManufacturerDevPick(
    sellerKey: 'seller_inoxline',
    labelKey: 'ui_dev_maker_inoxline',
    plan: TGStorePlanKind.pro,
    planLabel: 'Pro Store',
    promotedUsed: 1,
  );

  static const metalgast = ManufacturerDevPick(
    sellerKey: 'seller_metalgast',
    labelKey: 'ui_dev_maker_metalgast',
    plan: TGStorePlanKind.pro,
    planLabel: 'Pro Store',
  );

  static const capacityFull = ManufacturerDevPick(
    sellerKey: 'seller_nordinox',
    labelKey: 'ui_dev_maker_passive',
    plan: TGStorePlanKind.pro,
    planLabel: 'Pro Store',
    forceInactive: true,
  );

  static const all = [rm, stalbar, inoxline, metalgast, capacityFull];

  StoreOwnerDevPick get asStoreOwner => StoreOwnerDevPick(
        sellerKey: sellerKey,
        labelKey: labelKey,
        plan: plan,
        planLabel: planLabel,
        promotedUsed: promotedUsed,
      );
}

/// Dev Switcher personas for GROWTH-2 representatives (mock only).
class RepresentativeDevPick {
  const RepresentativeDevPick({
    required this.userId,
    required this.labelKey,
    required this.displayName,
    required this.initials,
  });

  final String userId;
  final String labelKey;
  final String displayName;
  final String initials;

  static const marek = RepresentativeDevPick(
    userId: 'rep_marek',
    labelKey: 'ui_dev_rep_marek',
    displayName: 'Marek Kowalski',
    initials: 'MK',
  );
  static const piotr = RepresentativeDevPick(
    userId: 'rep_piotr',
    labelKey: 'ui_dev_rep_piotr',
    displayName: 'Piotr Nowak',
    initials: 'PN',
  );
  static const anna = RepresentativeDevPick(
    userId: 'rep_anna',
    labelKey: 'ui_dev_rep_anna',
    displayName: 'Anna Wiśniewska',
    initials: 'AW',
  );

  static const all = [marek, piotr, anna];
}

class BuyerDevPick {
  const BuyerDevPick({
    required this.userId,
    required this.labelKey,
    required this.displayName,
    required this.phoneVerified,
    required this.initials,
  });

  final String userId;
  final String labelKey;
  final String displayName;
  final bool phoneVerified;
  final String initials;

  static const corporate = BuyerDevPick(
    userId: 'buyer_corporate',
    labelKey: 'ui_dev_buyer_corporate',
    displayName: 'GastroHotel Sp. z o.o.',
    phoneVerified: true,
    initials: 'GH',
  );

  static const marek = BuyerDevPick(
    userId: 'buyer_marek',
    labelKey: 'ui_dev_buyer_marek',
    displayName: 'Marek K.',
    phoneVerified: true,
    initials: 'MK',
  );

  static const anna = BuyerDevPick(
    userId: 'buyer_anna',
    labelKey: 'ui_dev_buyer_anna',
    displayName: 'Anna W.',
    phoneVerified: false,
    initials: 'AW',
  );

  static const all = [corporate, marek, anna];
}

/// Special-order request owners for the Dev Switcher (names unchanged).
class SpecialOrderBuyerDevPick {
  const SpecialOrderBuyerDevPick({
    required this.userId,
    required this.labelKey,
    required this.displayName,
    required this.initials,
  });

  final String userId;
  final String labelKey;
  final String displayName;
  final String initials;

  static const jan = SpecialOrderBuyerDevPick(
    userId: 'buyer_jan',
    labelKey: 'ui_dev_so_jan',
    displayName: 'Jan Kowalski',
    initials: 'JK',
  );

  static const piotr = SpecialOrderBuyerDevPick(
    userId: 'buyer_piotr',
    labelKey: 'ui_dev_so_piotr',
    displayName: 'Piotr Nowak',
    initials: 'PN',
  );

  static const tomasz = SpecialOrderBuyerDevPick(
    userId: 'buyer_tomasz',
    labelKey: 'ui_dev_so_tomasz',
    displayName: 'Tomasz Wiśniewski',
    initials: 'TW',
  );

  static const all = [jan, piotr, tomasz];

  BuyerDevPick get asBuyer => BuyerDevPick(
        userId: userId,
        labelKey: labelKey,
        displayName: displayName,
        phoneVerified: true,
        initials: initials,
      );
}

/// Sentinel for Dev Switcher → Devren İlan Sahibi.
enum DevrenSellerDevPick { listingOwner }

/// DASH-1 Dev Switcher personas: an account with no data at all, and a buyer
/// (Marek, real deals/reviews/evidence) who also publishes his own listings.
/// DASH-2 adds a seller with many conversations, a buyer with many favorites
/// and a store seller with six months of listing history.
enum DashboardDevPick { newUser, sellerBuyer, busySeller, favoritesBuyer, historySeller, billingStore }

/// Dev Switcher: restaurant (dükkan) seller personas.
enum RestoSellerDevPick {
  ownerFreeAvailable,
  ownerFreeUsed,
  agentBasicStore,
  withExpired,
  underReview,
}

extension TGUserRoleLabel on TGUserRole {
  String get label => switch (this) {
        TGUserRole.visitor => 'Visitor',
        TGUserRole.seller => 'Seller',
        TGUserRole.storeSeller => 'Store seller',
        TGUserRole.moderator => 'Moderator',
        TGUserRole.admin => 'Admin',
        TGUserRole.buyer => 'Buyer',
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
    if (isLoggedIn) {
      setScenario(TGEntitlementScenario.hasExpired, notify: false);
    } else {
      setRole(TGUserRole.visitor, notify: false);
    }
  }

  bool _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn;

  String userId = mockOwnerId;
  String userInitials = 'TG';
  String displayName = 'TG Demo';
  bool phoneVerified = false;
  TGUserRole role = TGUserRole.seller;
  TGSellerType sellerType = TGSellerType.private;
  int freeSlotsUsed = 0;
  TGStorePlanKind? storePlan;

  String storePlanLabel = 'Basic Store';
  int storeActiveUsed = 11;
  int storeActiveLimit = 15;
  int storePromotedUsed = 0;
  int storePromotedLimit = 3;
  DateTime storeRenewsOn = DateTime(2026, 10, 24);

  List<TGProduct> ownedListings = const [];
  TGCheckoutCart? checkoutCart;

  String? referredByCode;
  String? referredByRepId;
  DateTime? referredAt;
  DateTime? referralConsentAt;
  TGReferralVisibility referralVisibility = TGReferralVisibility.on;

  int get freeListingsTotal => PricingConfigService.instance.config.freeListingQuota;
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

  /// Restaurant rows belong on the mock seller's default (hasExpired) inventory.
  /// Product-only entitlement scenarios must not be hijacked by seed restaurants.
  bool get _headerCountsRestaurants => _scenario == TGEntitlementScenario.hasExpired;

  int get _restoExpiredCount =>
      _headerCountsRestaurants ? RestaurantService.instance.ownedExpired(userId).length : 0;

  int get _restoExpiringCount =>
      _headerCountsRestaurants ? RestaurantService.instance.ownedExpiringSoon(userId).length : 0;

  /// Product + (default mock) restaurant expired count for header pill.
  int get expiredListingCount => ownedExpired.length + _restoExpiredCount;

  /// Product + restaurant expiring ≤7d count for header pill ("ends in Nd").
  int get expiringListingCount => ownedExpiringSoon.length + _restoExpiringCount;

  int get nearestExpiringDays {
    final productDays = ownedExpiringSoon.map((p) => p.daysUntilExpiry());
    final restoDays = _headerCountsRestaurants
        ? RestaurantService.instance.ownedExpiringSoon(userId).map((r) => r.daysUntilExpiry())
        : const <int>[];
    final all = [...productDays, ...restoDays];
    if (all.isEmpty) return 0;
    return all.reduce((a, b) => a < b ? a : b);
  }

  TGHeaderPillKind get pillKind {
    if (ownedNeedsAttention.isNotEmpty) return TGHeaderPillKind.needsAttention;
    if (ownedExpired.isNotEmpty || _restoExpiredCount > 0) return TGHeaderPillKind.expiredListings;
    if (ownedExpiringSoon.isNotEmpty || _restoExpiringCount > 0) return TGHeaderPillKind.expiringListings;
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
    if (pillKind == TGHeaderPillKind.expiredListings) {
      return expiredListingCount;
    }
    if (pillKind == TGHeaderPillKind.expiringListings) {
      return expiringListingCount;
    }
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
        displayName = 'Visitor';
        phoneVerified = false;
        _clearReferralMirror();
        break;
      case TGUserRole.seller:
        _isLoggedIn = true;
        userId = mockOwnerId;
        userInitials = 'TG';
        displayName = 'TG Demo';
        phoneVerified = false;
        if (sellerType == TGSellerType.store && storePlan == null) {
          sellerType = TGSellerType.private;
        }
        break;
      case TGUserRole.storeSeller:
        _isLoggedIn = true;
        setScenario(TGEntitlementScenario.storeSubscriber, notify: false);
        role = TGUserRole.storeSeller;
        displayName = 'Gastrosilesia';
        phoneVerified = true;
        break;
      case TGUserRole.moderator:
        _isLoggedIn = true;
        userId = 'staff_moderator';
        userInitials = 'MD';
        displayName = 'Moderator';
        phoneVerified = true;
        break;
      case TGUserRole.admin:
        _isLoggedIn = true;
        userId = 'staff_admin';
        userInitials = 'AD';
        displayName = 'Admin';
        phoneVerified = true;
        break;
      case TGUserRole.buyer:
        _isLoggedIn = true;
        userId = BuyerDevPick.marek.userId;
        userInitials = BuyerDevPick.marek.initials;
        displayName = BuyerDevPick.marek.displayName;
        phoneVerified = BuyerDevPick.marek.phoneVerified;
        ownedListings = const [];
        storePlan = null;
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
    if (role == TGUserRole.visitor) {
      role = TGUserRole.seller;
      if (ownedListings.isEmpty) {
        setScenario(TGEntitlementScenario.hasExpired, notify: false);
      }
    }
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

  /// Mock auth: browse as a buyer with (or without) a verified phone.
  void actAsBuyer(BuyerDevPick pick) {
    _isLoggedIn = true;
    role = TGUserRole.buyer;
    userId = pick.userId;
    userInitials = pick.initials;
    displayName = pick.displayName;
    phoneVerified = pick.phoneVerified;
    ownedListings = const [];
    storePlan = null;
    notifyListeners();
  }

  /// Settings → Profile: public name ("Marek K.") and avatar initials.
  void updatePublicName(String name, String initials) {
    displayName = name;
    userInitials = initials;
    notifyListeners();
  }

  void markPhoneVerified() {
    phoneVerified = true;
    notifyListeners();
  }

  /// Mock auth: open `/seller/:id` as the store owner with plan chrome.
  void actAsStoreOwner(StoreOwnerDevPick pick) {
    actAsSeller(pick.sellerKey, initials: 'SO');
    storePlan = pick.plan;
    storePlanLabel = pick.planLabel;
    storeActiveUsed = 11;
    storeActiveLimit = switch (pick.plan) {
      TGStorePlanKind.basic => 15,
      TGStorePlanKind.pro => 50,
      TGStorePlanKind.enterprise => 9999,
    };
    storePromotedUsed = pick.promotedUsed;
    storePromotedLimit = 3;
    storeRenewsOn = DateTime(2026, 10, 24);
    ownedListings = const [];
    displayName = switch (pick.sellerKey) {
      'seller_technica' => 'Technica Pro',
      'seller_gastropl' => 'Gastrosilesia.pl',
      'seller_rm' => 'RM',
      'seller_stalbar' => 'Stalbar Projekt',
      'seller_inoxline' => 'Inoxline Silesia',
      'seller_metalgast' => 'Metalgast Katowice',
      'seller_nordinox' => 'Nordinox Warszawa',
      'seller_gastrolab' => 'GastroLab',
      'seller_nordgastro' => 'NordGastro',
      _ => pick.sellerKey,
    };
    phoneVerified = true;
    notifyListeners();
  }

  /// Mock auth: Special Order manufacturer persona (same store chrome + seller key).
  void actAsManufacturer(ManufacturerDevPick pick) => actAsStoreOwner(pick.asStoreOwner);

  /// Mock auth: GROWTH-2 representative. Does not change existing seller personas.
  void actAsRepresentative(RepresentativeDevPick pick) {
    ReferralRepository.instance.ensureSeeded();
    _isLoggedIn = true;
    role = TGUserRole.seller;
    sellerType = TGSellerType.private;
    userId = pick.userId;
    userInitials = pick.initials;
    displayName = pick.displayName;
    phoneVerified = true;
    storePlan = null;
    ownedListings = const [];
    checkoutCart = null;
    _clearReferralMirror();
    notifyListeners();
  }

  void applyReferralMirror(TGReferredAccount? acc) {
    if (acc == null) return;
    if ((referredByRepId != null && referredByRepId!.isNotEmpty) || referredAt != null) return;
    referredByCode = acc.referredByCode;
    referredByRepId = acc.referredByRepId;
    referredAt = acc.referredAt;
    referralConsentAt = acc.referralConsentAt;
    referralVisibility = acc.referralVisibility;
    notifyListeners();
  }

  void _clearReferralMirror() {
    referredByCode = null;
    referredByRepId = null;
    referredAt = null;
    referralConsentAt = null;
    referralVisibility = TGReferralVisibility.on;
  }

  /// Mock auth: Special Order request owner (Jan / Piotr / Tomasz).
  void actAsSpecialOrderBuyer(SpecialOrderBuyerDevPick pick) => actAsBuyer(pick.asBuyer);

  static const String newUserId = 'user_new';

  /// Mock auth: freshly registered account — no listings, deals, requests or threads.
  void actAsNewUser() {
    setScenario(TGEntitlementScenario.noListings, notify: false);
    _isLoggedIn = true;
    role = TGUserRole.seller;
    sellerType = TGSellerType.private;
    userId = newUserId;
    userInitials = 'NU';
    displayName = 'New user';
    phoneVerified = false;
    storePlan = null;
    checkoutCart = null;
    notifyListeners();
  }

  /// Mock auth: Marek keeps his buyer history (deals, reviews, evidence request)
  /// and also sells two items of his own.
  void actAsSellerBuyer() {
    const pick = BuyerDevPick.marek;
    const seller = TGSeller(id: 'buyer_marek', name: 'Marek K.', type: TGSellerType.private, verified: false, rating: 0);
    setScenario(TGEntitlementScenario.noListings, notify: false);
    _isLoggedIn = true;
    role = TGUserRole.seller;
    sellerType = TGSellerType.private;
    userId = pick.userId;
    userInitials = pick.initials;
    displayName = pick.displayName;
    phoneVerified = pick.phoneVerified;
    storePlan = null;
    freeSlotsUsed = 2;
    ownedListings = [
      _own(
        id: 'own_sb1',
        title: 'Ekspres kolbowy 2-grupowy',
        listingNo: '45381920',
        publishedAgo: const Duration(days: 9),
        expiresIn: const Duration(days: 21),
        slot: 1,
        seller: seller,
        ownerId: pick.userId,
      ),
      _own(
        id: 'own_sb2',
        title: 'Szafa chłodnicza 600L',
        listingNo: '46492031',
        publishedAgo: const Duration(days: 28),
        expiresIn: const Duration(days: 2),
        slot: 2,
        seller: seller,
        ownerId: pick.userId,
      ),
    ];
    TGListingNo.reserveAll(ownedListings.map((p) => p.listingNo));
    notifyListeners();
  }

  /// Mock auth: restaurant / cafe business-transfer seller (Devren).
  void actAsDevrenSeller() {
    setScenario(TGEntitlementScenario.noListings, notify: false);
    _isLoggedIn = true;
    role = TGUserRole.seller;
    sellerType = TGSellerType.private;
    userId = 'seller_devren';
    userInitials = 'DR';
    displayName = 'Devren İlan Sahibi';
    phoneVerified = true;
    storePlan = null;
    notifyListeners();
  }

  void actAsRestoSeller(RestoSellerDevPick pick) {
    RestaurantLifecycleService.instance.ensureSeeded();
    _isLoggedIn = true;
    role = TGUserRole.seller;
    phoneVerified = true;
    storePlan = null;
    switch (pick) {
      case RestoSellerDevPick.ownerFreeAvailable:
        userId = 'seller_resto_new';
        userInitials = 'RN';
        displayName = 'Resto Owner (free available)';
        sellerType = TGSellerType.private;
      case RestoSellerDevPick.ownerFreeUsed:
        userId = mockOwnerId;
        userInitials = 'TG';
        displayName = 'TG Demo (free used)';
        sellerType = TGSellerType.private;
        final r = RestaurantService.instance.byId('r001');
        if (r != null) {
          RestaurantLifecycleService.instance.markFreeStartUsed(
            ownerId: userId,
            premisesKey: r.premisesKey,
            phone: r.phone,
          );
        }
      case RestoSellerDevPick.agentBasicStore:
        userId = mockStoreSellerId;
        userInitials = 'GP';
        displayName = 'GastroPL Agent';
        sellerType = TGSellerType.store;
        storePlan = TGStorePlanKind.basic;
        storePlanLabel = 'Basic Store';
      case RestoSellerDevPick.withExpired:
        userId = mockOwnerId;
        userInitials = 'TG';
        displayName = 'TG Demo (expired resto)';
        sellerType = TGSellerType.private;
      case RestoSellerDevPick.underReview:
        userId = 'seller_mateusz';
        userInitials = 'MK';
        displayName = 'Mateusz K. (under review)';
        sellerType = TGSellerType.private;
    }
    notifyListeners();
  }

  /// Mock auth: TG Demo with the expired-listings scenario; the DASH-2 mock
  /// data adds many buyer conversations on top.
  void actAsBusySeller() {
    _isLoggedIn = true;
    role = TGUserRole.seller;
    setScenario(TGEntitlementScenario.hasExpired, notify: false);
    displayName = 'TG Demo';
    phoneVerified = true;
    notifyListeners();
  }

  /// Mock auth: Anna (buyer); the DASH-2 mock data adds her favorites.
  void actAsFavoritesBuyer() => actAsBuyer(BuyerDevPick.anna);

  static const historySellerId = 'seller_technica';

  /// Mock auth: Technica Pro (Basic Store) with six months of mixed listings:
  /// FREE, PAID, STORE, sold, expired and a fresh one with too little data.
  void actAsHistorySeller() {
    actAsStoreOwner(StoreOwnerDevPick.technica);
    final now = DateTime.now();
    storeRenewsOn = DateTime(now.year, now.month, now.day + 18);
    storeActiveUsed = 1;
    storeActiveLimit = 15;
    freeSlotsUsed = 3;
    const seller = TGSeller(id: historySellerId, name: 'Technica Pro', type: TGSellerType.store, verified: true, rating: 4.7);
    TGProduct own(
      String id,
      String title,
      String no, {
      Duration? ago,
      Duration? left,
      Duration? expiredAgo,
      TGListingStatus? status,
      TGListingSource source = TGListingSource.paid,
      int? slot,
      int price = 2500,
      DateTime? expiresAt,
    }) =>
        _own(
          id: id,
          title: title,
          listingNo: no,
          publishedAgo: ago,
          expiresIn: left,
          expiredAgo: expiredAgo,
          status: status,
          slot: slot,
          seller: seller,
          ownerId: historySellerId,
          source: source,
          price: price,
          expiresAt: expiresAt,
        );
    ownedListings = [
      own('hs_store1', 'Zmywarka kapturowa Winterhalter PT-M', '51200481', ago: const Duration(days: 172), source: TGListingSource.store, price: 18900, expiresAt: storeRenewsOn),
      own('hs_paid1', 'Piec konwekcyjny Rational iCombi 6-1/1', '51200492', ago: const Duration(days: 50), left: const Duration(days: 40), price: 32500),
      own('hs_free1', 'Frytownica elektryczna 2x8L', '51200503', ago: const Duration(days: 20), left: const Duration(days: 40), source: TGListingSource.free, slot: 1, price: 1450),
      own('hs_new1', 'Stół chłodniczy 3-drzwiowy', '51200514', ago: const Duration(days: 3), left: const Duration(days: 27), price: 4200),
      own('hs_exp1', 'Szatkownica Robot Coupe CL50', '51200525', ago: const Duration(days: 102), expiredAgo: const Duration(days: 12), price: 6900),
      own('hs_exp2', 'Kuchnia gazowa 6-palnikowa', '51200536', ago: const Duration(days: 65), expiredAgo: const Duration(days: 5), source: TGListingSource.free, slot: 2, price: 3800),
      own('hs_sold1', 'Ekspres Nuova Simonelli Appia II', '51200547', ago: const Duration(days: 120), left: const Duration(days: 1), status: TGListingStatus.sold, price: 9800),
      _own(id: 'hs_draft1', title: 'Szkic: szafa mroźnicza 700L', draft: true, seller: seller, ownerId: historySellerId),
    ];
    TGListingNo.reserveAll(ownedListings.map((p) => p.listingNo));
    notifyListeners();
  }

  int get storeSlotsUsed {
    final store = ownedActive.where((p) => p.source == TGListingSource.store).length;
    return store > storeActiveUsed ? store : storeActiveUsed;
  }

  bool get storeHasFreeSlot => storePlan != null && storeSlotsUsed < storeActiveLimit;

  /// Moves an owned FREE / PAID listing onto the store plan: spends one store
  /// slot and aligns expiry with the subscription end ([storeRenewsOn]). The
  /// FREE slot already spent is not refunded. Returns an i18n error key.
  String? moveToStorePlan(String id) {
    if (storePlan == null) return 'dash_move_err_no_store';
    final i = ownedListings.indexWhere((p) => p.id == id);
    if (i < 0) return 'dash_move_err_missing';
    final p = ownedListings[i];
    if (p.source == TGListingSource.store) return 'dash_move_err_already';
    if (!p.isActive && p.status != TGListingStatus.expired) return 'dash_move_err_status';
    if (!storeHasFreeSlot) return 'dash_move_err_quota';
    if (!storeRenewsOn.isAfter(DateTime.now())) return 'dash_move_err_renewal';
    storeActiveUsed = storeSlotsUsed + 1;
    final next = [...ownedListings];
    next[i] = p.copyWith(source: TGListingSource.store, status: TGListingStatus.active, expiresAt: storeRenewsOn);
    ownedListings = next;
    notifyListeners();
    return null;
  }

  /// Inserts or replaces an owned listing. Drafts do not consume a free slot.
  /// A price edit on a live listing is recorded in [TGPriceHistoryService].
  void upsertOwned(TGProduct listing) {
    final next = [...ownedListings];
    final i = next.indexWhere((p) => p.id == listing.id);
    if (i >= 0) {
      final old = next[i].price;
      final now = listing.price;
      if (old != null && now != null && old != now && listing.status == TGListingStatus.active) {
        TGPriceHistoryService.instance.record(listingId: listing.id, oldPln: old, newPln: now);
      }
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
  /// [periodDays] comes from PricingConfig (free = freeListingDays; paid = 30/60/90).
  TGProduct publishOwned(TGProduct listing, {int promoteDays = 0, int? periodDays}) {
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
    final days = periodDays ?? PricingConfigService.instance.config.defaultListingDays;
    final published = listing.copyWith(
      status: TGListingStatus.active,
      publishedAt: now,
      expiresAt: DurationService.addDays(now, days),
      source: source,
      freeSlotIndex: slot,
      isPromoted: promoteDays > 0,
      promotedUntil: promoteDays > 0 ? DurationService.addDays(now, promoteDays) : null,
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

  TGProduct renewOwned(String id, {int promoteDays = 0, bool early = false, int? periodDays}) {
    final listing = ownedListings.firstWhere((p) => p.id == id);
    final now = DateTime.now();
    final base = early && listing.expiresAt != null && listing.expiresAt!.isAfter(now)
        ? listing.expiresAt!
        : now;
    final days = periodDays ?? PricingConfigService.instance.config.defaultListingDays;
    final published = listing.copyWith(
      status: TGListingStatus.active,
      publishedAt: listing.publishedAt ?? now,
      expiresAt: DurationService.addDays(base, days),
      source: TGListingSource.paid,
      isPromoted: promoteDays > 0,
      promotedUntil: promoteDays > 0 ? DurationService.addDays(now, promoteDays) : null,
      ownerId: userId,
    );
    upsertOwned(published);
    return published;
  }

  List<TGProduct> renewAllExpired({int? periodDays}) {
    return [for (final p in [...ownedExpired]) renewOwned(p.id, periodDays: periodDays)];
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
    // VITRIN-2: Pro grants 3 Glow/1m credits per period; Enterprise has none.
    if (storePlan == TGStorePlanKind.pro) {
      PromotionService.instance.grantProCredits(userId);
    }
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
  TGSeller seller = FakeAuthState.mockOwnerSeller,
  String ownerId = FakeAuthState.mockOwnerId,
  TGListingSource source = TGListingSource.free,
  int price = 2500,
  DateTime? expiresAt,
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
      expires = expiresAt ?? now.add(expiresIn ?? Duration(days: TGPricing.listingPeriodDays));
    }
  }
  if (listingNo != null) TGListingNo.reserve(listingNo);
  return TGProduct(
    id: id,
    title: title,
    price: price,
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
    seller: seller,
    city: 'Katowice',
    voivodeship: 'Śląskie',
    phone: '+48 (532) 784-074',
    imageUrl: TGListingImages.seedCover(id: id, category: TGCategory.cookingEquipment, title: title),
    imageUrls: TGListingImages.seedGallery(id: id, category: TGCategory.cookingEquipment, title: title, count: 4),
    photoCount: 4,
    isPromoted: false,
    createdAt: created,
    description: title,
    status: resolved,
    publishedAt: published,
    expiresAt: expires,
    source: source,
    freeSlotIndex: source == TGListingSource.free ? slot : null,
    ownerId: ownerId,
    listingNo: draft ? null : listingNo,
  );
}
