import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_core/pl_business_days.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGSeller, TGSellerType;
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// In-memory restaurant listings. Production Mode hides all mock rows.
class RestaurantService extends ChangeNotifier {
  RestaurantService._() {
    _seed();
  }
  static final RestaurantService instance = RestaurantService._();

  final List<RestaurantListing> _all = [];
  final Set<String> _viewKeys = {};
  final Set<String> _contactKeys = {};
  final Set<String> _favoriteKeys = {};
  final Map<String, _RestoTransferUndo> _transferUndos = {};

  List<RestaurantListing> get all => List.unmodifiable(_all);

  /// Public hub catalogue (respects Production Mode).
  List<RestaurantListing> get publicListings {
    if (TGRevenueConfigService.instance.productionMode) return const [];
    return _all.where((r) => r.isPubliclyVisible).toList(growable: false);
  }

  List<RestaurantListing> ownedBy(String ownerId) =>
      _all.where((r) => r.ownerId == ownerId).toList(growable: false);

  List<RestaurantListing> ownedExpired(String ownerId) =>
      ownedBy(ownerId).where((r) => r.status == RestaurantListingStatus.expired).toList(growable: false);

  List<RestaurantListing> ownedExpiringSoon(String ownerId) =>
      ownedBy(ownerId).where((r) => r.isExpiringSoon() && r.daysUntilExpiry() <= 7).toList(growable: false);

  RestaurantListing? byId(String id) {
    for (final r in _all) {
      if (r.id == id) return r;
    }
    return null;
  }

  RestaurantListing? byListingNo(String no) {
    final n = no.trim();
    for (final r in _all) {
      if (r.listingNo == n) return r;
    }
    return null;
  }

  /// Header 8-digit search: active + visible only.
  RestaurantListing? findPublicByNo(String no) {
    if (TGRevenueConfigService.instance.productionMode) return null;
    final hit = byListingNo(no);
    if (hit == null || !hit.isPubliclyVisible) return null;
    return hit;
  }

  RestaurantListing? fromPathSegment(String segment) {
    final no = TGListingNo.parseFromPath(segment) ?? (TGListingNo.isListingNo(segment) ? segment : null);
    if (no == null) return null;
    return byListingNo(no);
  }

  List<RestaurantListing> similarTo(RestaurantListing listing, {int limit = 4}) {
    final rows = publicListings
        .where((r) => r.id != listing.id && r.businessType == listing.businessType && r.city == listing.city)
        .toList();
    if (rows.length < limit) {
      final extra = publicListings
          .where((r) => r.id != listing.id && r.city == listing.city && !rows.any((x) => x.id == r.id))
          .toList();
      rows.addAll(extra);
    }
    if (rows.length < limit) {
      final extra = publicListings
          .where((r) => r.id != listing.id && r.businessType == listing.businessType && !rows.any((x) => x.id == r.id))
          .toList();
      rows.addAll(extra);
    }
    return rows.take(limit).toList(growable: false);
  }

  List<RestaurantListing> moreFromSeller(RestaurantListing listing, {int limit = 4}) {
    return publicListings.where((r) => r.id != listing.id && r.ownerId == listing.ownerId).take(limit).toList(growable: false);
  }

  List<RestaurantListing> samePremises(RestaurantListing listing) {
    return _all.where((r) => r.id != listing.id && r.premisesKey == listing.premisesKey).toList(growable: false);
  }

  void replace(RestaurantListing next) {
    final i = _all.indexWhere((r) => r.id == next.id);
    var toStore = next;
    if (i >= 0) {
      final prev = _all[i];
      // Days spent under_review pause the timer (added back on restore).
      final wasPaused = prev.status == RestaurantListingStatus.underReview || prev.isHidden;
      final nowPaused = next.status == RestaurantListingStatus.underReview || next.isHidden;
      if (!wasPaused && nowPaused) {
        _hiddenSince[next.id] = TGClock.now();
      } else if (wasPaused && !nowPaused) {
        final since = _hiddenSince.remove(next.id);
        final days = since == null ? 0 : TGClock.now().difference(since).inDays;
        if (days > 0 && next.expiresAt != null) {
          toStore = next.copyWith(expiresAt: next.expiresAt!.add(Duration(days: days)));
        }
      }
      _all[i] = toStore;
    } else {
      _all.add(toStore);
    }
    notifyListeners();
  }

  /// Alias used by the wizard for draft upserts.
  void upsertDraft(RestaurantListing draft) => replace(draft);

  /// View engagement: unique per session+day. Owner / staff / bot excluded by caller.
  bool recordView({required String listingId, required String sessionKey, required bool count}) {
    if (!count) return false;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'v:$listingId:$sessionKey:$day';
    if (!_viewKeys.add(key)) return false;
    final cur = byId(listingId);
    if (cur == null) return false;
    replace(cur.copyWith(engagement: cur.engagement.copyWith(views: cur.engagement.views + 1)));
    return true;
  }

  bool recordContact({required String listingId, required String sessionKey, required bool count}) {
    if (!count) return false;
    final key = 'c:$listingId:$sessionKey';
    if (!_contactKeys.add(key)) return false;
    final cur = byId(listingId);
    if (cur == null) return false;
    replace(cur.copyWith(engagement: cur.engagement.copyWith(uniqueContacts: cur.engagement.uniqueContacts + 1)));
    return true;
  }

  bool recordFavorite({required String listingId, required String userId, required bool on, required bool count}) {
    if (!count || !on) return false;
    final key = 'f:$listingId:$userId';
    if (!_favoriteKeys.add(key)) return false;
    final cur = byId(listingId);
    if (cur == null) return false;
    replace(cur.copyWith(engagement: cur.engagement.copyWith(uniqueFavorites: cur.engagement.uniqueFavorites + 1)));
    return true;
  }

  final Map<String, DateTime> _hiddenSince = {};

  void setHidden(String listingId, bool hidden) {
    final cur = byId(listingId);
    if (cur == null) return;
    replace(cur.copyWith(isHidden: hidden));
  }

  void attachAuthorizationProof(String listingId, String docLabel) {
    final cur = byId(listingId);
    if (cur == null) return;
    replace(cur.copyWith(documents: [...cur.documents, docLabel]));
  }

  /// Mark transferred (sold). Optional linked equipment keep/remove. 10s undo.
  RestaurantListing? markTransferred({
    required String listingId,
    required bool foundViaPlatform,
    Set<String> removeLinkedListingNos = const {},
  }) {
    final cur = byId(listingId);
    if (cur == null) return null;
    final snapshot = cur;
    var inv = cur.inventory;
    if (removeLinkedListingNos.isNotEmpty) {
      inv = [
        for (final item in inv)
          if (item.linkedListingNo != null && removeLinkedListingNos.contains(item.linkedListingNo))
            item.copyWith(status: RestaurantInventoryStatus.archived, statusChangedAt: DateTime.now())
          else
            item,
      ];
    }
    final next = cur.copyWith(
      status: RestaurantListingStatus.sold,
      foundViaPlatform: foundViaPlatform,
      inventory: inv,
    );
    replace(next);
    _transferUndos[listingId] = _RestoTransferUndo(snapshot: snapshot, until: DateTime.now().add(const Duration(seconds: 10)));
    notifyListeners();
    return next;
  }

  /// Direct remove (no longer selling / other) — status removed.
  RestaurantListing? markRemoved(String listingId) {
    final cur = byId(listingId);
    if (cur == null) return null;
    final next = cur.copyWith(status: RestaurantListingStatus.removed);
    replace(next);
    return next;
  }

  bool undoTransfer(String listingId) {
    final u = _transferUndos[listingId];
    if (u == null || DateTime.now().isAfter(u.until)) {
      _transferUndos.remove(listingId);
      return false;
    }
    replace(u.snapshot);
    _transferUndos.remove(listingId);
    return true;
  }

  bool canUndoTransfer(String listingId) {
    final u = _transferUndos[listingId];
    return u != null && !DateTime.now().isAfter(u.until);
  }

  void reset() {
    _all
      ..clear()
      ..addAll(_buildSeed());
    _viewKeys.clear();
    _contactKeys.clear();
    _favoriteKeys.clear();
    _transferUndos.clear();
    notifyListeners();
  }

  void _seed() {
    _all
      ..clear()
      ..addAll(_buildSeed());
  }
}

class _RestoTransferUndo {
  _RestoTransferUndo({required this.snapshot, required this.until});
  final RestaurantListing snapshot;
  final DateTime until;
}

// ---------------------------------------------------------------------------
// Mock seed (14 listings)
// ---------------------------------------------------------------------------

List<RestaurantListing> _buildSeed() {
  final cfg = RestaurantConfigService.instance.config;
  final now = TGClock.now();

  // Restaurant transfers are individual (owner/agent persons) — never store brands.
  const ownerMateusz = TGSeller(id: 'seller_mateusz', name: 'Mateusz K.', type: TGSellerType.private, verified: false, rating: 4.4);
  const ownerAnna = TGSeller(id: 'seller_anna', name: 'Anna P.', type: TGSellerType.private, verified: false, rating: 4.6);
  const ownerKarol = TGSeller(id: 'seller_karol', name: 'Karol W.', type: TGSellerType.private, verified: false, rating: 4.5);
  const ownerEwa = TGSeller(id: 'seller_ewa', name: 'Ewa N.', type: TGSellerType.private, verified: false, rating: 4.3);
  const agentAgnieszka = TGSeller(id: 'seller_agnieszka', name: 'Agnieszka T.', type: TGSellerType.private, verified: false, rating: 4.6);
  const ownerTg = TGSeller(id: 'seller_tg', name: 'Piotr M.', type: TGSellerType.private, verified: false, rating: 4.5);

  List<String> imgs(String id, RestaurantBusinessType type, String title, int n) =>
      TGListingImages.galleryForTheme(
        id: 'resto-$id',
        theme: RestaurantListing.businessTypeSlug(type),
        title: title,
        count: n,
      );

  /// 10–20 themed equipment rows; first [maySell] are “sold separately”.
  List<RestaurantInventoryItem> inv(
    String prefix,
    RestaurantBusinessType type, {
    int? count,
    int maySell = 3,
    int excluded = 1,
    List<String> linkedNos = const [],
  }) {
    final keys = restoEquipmentNameKeys(type);
    final n = (count ?? keys.length).clamp(10, 20).clamp(1, keys.length);
    final theme = RestaurantListing.businessTypeSlug(type);
    final photoPool = TGListingImages.galleryForTheme(
      id: 'resto-$prefix-inv',
      theme: theme,
      title: keys.first,
      count: n.clamp(4, 12),
    );
    return [
      for (var i = 0; i < n; i++)
        RestaurantInventoryItem(
          id: '$prefix-inv-$i',
          category: restoEquipmentCategory(keys[i]),
          name: keys[i],
          qty: 1 + (i % 2),
          brand: i.isEven ? 'Bartscher' : 'Hobart',
          model: 'M-${100 + i}',
          condition: i % 5 == 0 ? RestaurantInventoryCondition.newItem : RestaurantInventoryCondition.used,
          photos: [photoPool[i % photoPool.length]],
          availability: i < maySell
              ? RestaurantInventoryAvailability.maySellSeparately
              : (i >= n - excluded ? RestaurantInventoryAvailability.excluded : RestaurantInventoryAvailability.included),
          linkedListingNo: i < maySell && i < linkedNos.length ? linkedNos[i] : null,
        ),
    ];
  }

  const demoCosts = [
    RestaurantCostLine(key: RestaurantCostKey.electricity, label: 'Electricity', amountPln: 2800, basis: RestaurantCostBasis.netto, period: RestaurantCostPeriod.avg12m),
    RestaurantCostLine(key: RestaurantCostKey.gas, label: 'Gas', amountPln: 1200, basis: RestaurantCostBasis.brutto, period: RestaurantCostPeriod.lastBill),
    RestaurantCostLine(key: RestaurantCostKey.waterSewage, label: 'Water & sewage', amountPln: 450, basis: RestaurantCostBasis.unspecified, period: RestaurantCostPeriod.estimate),
    RestaurantCostLine(key: RestaurantCostKey.waste, label: 'Waste', amountPln: 320, basis: RestaurantCostBasis.netto, period: RestaurantCostPeriod.avg12m, includedInRent: true),
    RestaurantCostLine(key: RestaurantCostKey.internetPhone, label: 'Internet', amountPln: 180, basis: RestaurantCostBasis.brutto, period: RestaurantCostPeriod.lastBill),
  ];

  RestaurantListing L({
    required String id,
    required String no,
    required RestaurantBusinessType type,
    required String title,
    String? venueName,
    required String city,
    required String voivodeship,
    required String street,
    required String buildingNo,
    String? district,
    String? unitNo,
    required double area,
    required int rent,
    required RestaurantVatBasis rentBasis,
    required RestaurantTransferFee fee,
    required TGSeller seller,
    required RestaurantPosterRole role,
    required RestaurantListingStatus status,
    required RestaurantListingSource source,
    required int publishedDaysAgo,
    int? expiresInDays,
    bool freeExtension = false,
    bool promoted = false,
    bool negotiable = false,
    int? seats,
    double? terrace,
    bool garden = false,
    bool play = false,
    bool parking = true,
    bool extraction = true,
    bool alcohol = true,
    bool delivery = false,
    RestaurantLeaseType lease = RestaurantLeaseType.fixed,
    int? leaseEndsYear,
    List<RestaurantInventoryItem> inventory = const [],
    int? revenue,
    RestaurantEngagement engagement = const RestaurantEngagement(),
    bool isHidden = false,
    bool authConfirmed = true,
    DateTime? availableFrom,
    String? description,
    List<RestaurantCostLine> costLines = const [],
    List<String> documents = const [],
    String? floorPlanUrl,
    RestaurantEquipmentIncluded? equipmentIncluded,
    RestaurantDetails? detailsOverride,
  }) {
    final published = now.subtract(Duration(days: publishedDaysAgo));
    final expires = expiresInDays == null
        ? published.add(Duration(days: source == RestaurantListingSource.paid ? cfg.paidDays : cfg.freeDays))
        : now.add(Duration(days: expiresInDays));
    final geo = _coords(city);
    return RestaurantListing.create(
      id: id,
      listingNo: no,
      status: status,
      isHidden: isHidden,
      publishedAt: published,
      expiresAt: expires,
      source: source,
      freeExtensionGranted: freeExtension,
      promotedUntil: promoted ? now.add(const Duration(days: 14)) : null,
      ownerId: seller.id,
      posterRole: role,
      authorizationConfirmed: authConfirmed,
      businessType: type,
      title: title,
      venueName: venueName,
      description: description ??
          '$title in $city. Full address, rent and transfer fee shown upfront. Ready for takeover — inspect the lease and permits yourself.',
      reasonForSale: 'Relocation / new project',
      availableFrom: availableFrom ?? now.add(const Duration(days: 14)),
      city: city,
      voivodeship: voivodeship,
      district: district,
      street: street,
      buildingNo: buildingNo,
      unitNo: unitNo,
      lat: geo.$1,
      lng: geo.$2,
      totalAreaM2: area,
      salesAreaM2: area * 0.55,
      kitchenAreaM2: area * 0.25,
      seats: seats,
      terraceM2: terrace,
      floorLevel: 0,
      parking: parking,
      powerKw: 40,
      gasConnection: true,
      extractionSystem: extraction,
      rentMonthly: rent,
      rentBasis: rentBasis,
      depositPln: rent * 3,
      leaseType: lease,
      leaseEndsAt: lease == RestaurantLeaseType.indefinite
          ? null
          : DateTime(leaseEndsYear ?? 2029, 6, 30),
      landlordConsent: RestaurantLandlordConsent.toBeArranged,
      transferFee: fee,
      negotiable: negotiable,
      equipmentIncluded: equipmentIncluded ??
          (inventory.isEmpty ? RestaurantEquipmentIncluded.none : RestaurantEquipmentIncluded.all),
      alcoholPermit: alcohol
          ? RestaurantAlcoholPermit(
              status: RestaurantAlcoholPermitStatus.hasPermit,
              classes: const [RestaurantAlcoholClass.upTo45AndBeer, RestaurantAlcoholClass.from45To18],
              scope: const [RestaurantAlcoholScope.onPremises],
              validUntil: DateTime(now.year + 1, 12, 31),
            )
          : const RestaurantAlcoholPermit(status: RestaurantAlcoholPermitStatus.none),
      sanitaryApproval: true,
      staffTakeover: RestaurantStaffTakeover.negotiable,
      declaredMonthlyRevenue: revenue,
      declaredAsOf: revenue == null ? null : DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)),
      documents: documents.isEmpty
          ? const ['Lease agreement', 'Sanitary approval', 'Floor plan']
          : documents,
      images: imgs(id, type, title, 6 + (id.hashCode % 5)),
      floorPlanUrl: floorPlanUrl ?? imgs(id, type, title, 1).first,
      details: detailsOverride ??
          RestaurantDetails(
            garden: garden
                ? const RestaurantGarden(kind: RestaurantGardenKind.own, areaM2: 40)
                : const RestaurantGarden(),
            playArea: play
                ? const RestaurantPlayArea(kind: RestaurantPlayAreaKind.indoor, areaM2: 18)
                : const RestaurantPlayArea(),
            deliveryOnline: delivery,
            conceptMenu: 'Seasonal Polish & European menu; lunch set on weekdays.',
            customersLocation: 'Office & tourist footfall; evening dining peak Fri–Sat.',
            hoursSeasonality: 'Mon–Thu 12–22, Fri–Sat 12–24, Sun 12–21.',
            staffContracts: '2 FT kitchen, 3 waitstaff — negotiable takeover.',
            systems: 'POS + online reservations.',
            brandAssets: const ['Trade name', 'Social media handles'],
            otherInfo: 'No ask-for-price: rent and transfer fee always visible.',
          ),
      costLines: costLines,
      inventory: inventory,
      engagement: engagement,
      seller: seller,
      foundViaPlatform: true,
    );
  }

  final reviewDue = PLBusinessDays.addBusinessDays(now, cfg.soldItemReviewBusinessDays);

  final rows = <RestaurantListing>[
    // 1 — day 5 free, promoted, restaurant Katowice (owned by mock seller_tg)
    L(
      id: 'r001',
      no: '51010001',
      type: RestaurantBusinessType.restaurant,
      title: 'Restaurant with terrace – Mariacka, Katowice',
      venueName: 'Katowice Big Pizza',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      district: 'Śródmieście',
      street: 'ul. Mariacka',
      buildingNo: '12',
      unitNo: '1',
      area: 180,
      rent: 14500,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 120000, basis: RestaurantVatBasis.netto),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 5,
      promoted: true,
      seats: 70,
      terrace: 35,
      garden: true,
      alcohol: true,
      inventory: inv('r001', RestaurantBusinessType.restaurant, maySell: 3, linkedNos: const ['10482137', '14120395', '11820463']),
      costLines: demoCosts,
      engagement: const RestaurantEngagement(views: 210, uniqueContacts: 8, uniqueFavorites: 12),
      revenue: 78000,
    ),
    // 2 — day 28 free with interest, cafe Rybnik
    L(
      id: 'r002',
      no: '51010002',
      type: RestaurantBusinessType.cafe,
      title: 'Corner café with pastry counter – Rybnik',
      venueName: 'Silesia Coffee',
      city: 'Rybnik',
      voivodeship: 'Śląskie',
      street: 'ul. Kościuszki',
      buildingNo: '8',
      area: 95,
      rent: 6200,
      rentBasis: RestaurantVatBasis.brutto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 45000, basis: RestaurantVatBasis.brutto),
      seller: ownerAnna,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 28,
      seats: 36,
      alcohol: false,
      inventory: inv('r002', RestaurantBusinessType.cafe, maySell: 3),
      engagement: const RestaurantEngagement(views: 180, uniqueContacts: 5, uniqueFavorites: 9),
      revenue: 38000,
    ),
    // 3 — day 30 extended (no interest), bar Gliwice
    L(
      id: 'r003',
      no: '51010003',
      type: RestaurantBusinessType.bar,
      title: 'Cocktail bar – Gliwice centre',
      venueName: 'Zwycięstwa Bar',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      street: 'ul. Zwycięstwa',
      buildingNo: '41',
      area: 110,
      rent: 8900,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 70000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 30,
      freeExtension: true,
      expiresInDays: 5,
      promoted: true,
      seats: 50,
      alcohol: true,
      inventory: inv('r003', RestaurantBusinessType.bar, maySell: 2),
      engagement: const RestaurantEngagement(views: 22, uniqueContacts: 0, uniqueFavorites: 1),
    ),
    // 4 — expired (had interest), pizzeria Kraków — owned by seller_tg for renew UI
    L(
      id: 'r004',
      no: '51010004',
      type: RestaurantBusinessType.pizzeria,
      title: 'Pizzeria with delivery fleet – Kraków Kazimierz',
      venueName: 'Kazimierz Big Pizza',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      district: 'Kazimierz',
      street: 'ul. Miodowa',
      buildingNo: '22',
      area: 130,
      rent: 11000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 95000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.expired,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 45,
      expiresInDays: -3,
      seats: 40,
      delivery: true,
      inventory: inv('r004', RestaurantBusinessType.pizzeria, maySell: 3),
      engagement: const RestaurantEngagement(views: 340, uniqueContacts: 14, uniqueFavorites: 20),
    ),
    // 5 — paid active, promoted, fast food Warszawa
    L(
      id: 'r005',
      no: '51010005',
      type: RestaurantBusinessType.fastFood,
      title: 'Fast-food corner – Warszawa Mokotów',
      venueName: 'Mokotów Burger',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      district: 'Mokotów',
      street: 'ul. Puławska',
      buildingNo: '88',
      area: 75,
      rent: 16000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 150000),
      seller: ownerKarol,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 12,
      promoted: true,
      seats: 28,
      parking: false,
      delivery: true,
      inventory: inv('r005', RestaurantBusinessType.fastFood, maySell: 3),
      engagement: const RestaurantEngagement(views: 410, uniqueContacts: 18, uniqueFavorites: 25),
      revenue: 92000,
    ),
    // 6 — pending authorization, bakery Częstochowa
    L(
      id: 'r006',
      no: '51010006',
      type: RestaurantBusinessType.bakeryPatisserie,
      title: 'Bakery & café – Częstochowa',
      city: 'Częstochowa',
      voivodeship: 'Śląskie',
      street: 'al. NMP',
      buildingNo: '15',
      area: 140,
      rent: 7800,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 60000),
      seller: ownerAnna,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.pendingAuthorization,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 2,
      authConfirmed: false,
      seats: 24,
      play: true,
    ),
    // 7 — sold, same premises as r001 (duplicate flag demo)
    L(
      id: 'r007',
      no: '51010007',
      type: RestaurantBusinessType.cateringDarkKitchen,
      title: 'Dark kitchen + catering hub – Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      street: 'ul. Mariacka',
      buildingNo: '12',
      unitNo: '1',
      area: 220,
      rent: 9800,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 80000),
      seller: agentAgnieszka,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.sold,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 40,
      extraction: true,
      alcohol: false,
      inventory: inv('r007', RestaurantBusinessType.cateringDarkKitchen, maySell: 3),
    ),
    // 8 — under review, club Bielsko-Biała
    L(
      id: 'r008',
      no: '51010008',
      type: RestaurantBusinessType.club,
      title: 'Night club premises – Bielsko-Biała',
      city: 'Bielsko-Biała',
      voivodeship: 'Śląskie',
      street: 'ul. 11 Listopada',
      buildingNo: '5',
      area: 350,
      rent: 22000,
      rentBasis: RestaurantVatBasis.brutto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 200000, basis: RestaurantVatBasis.brutto),
      seller: ownerMateusz,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.underReview,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 9,
      seats: 200,
      alcohol: true,
      isHidden: false,
    ),
    // 9 — No transfer fee, restaurant Kraków
    L(
      id: 'r009',
      no: '51010009',
      type: RestaurantBusinessType.restaurant,
      title: 'Family restaurant – no transfer fee, Kraków',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      district: 'Podgórze',
      street: 'ul. Kalwaryjska',
      buildingNo: '60',
      area: 160,
      rent: 12500,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.none),
      seller: ownerAnna,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 8,
      seats: 60,
      terrace: 20,
      garden: true,
      negotiable: true,
      lease: RestaurantLeaseType.indefinite,
      inventory: inv('r009', RestaurantBusinessType.restaurant, maySell: 3),
      engagement: const RestaurantEngagement(views: 95, uniqueContacts: 3, uniqueFavorites: 6),
    ),
    // 10 — vat_unspecified rent + fee, bar Warszawa
    L(
      id: 'r010',
      no: '51010010',
      type: RestaurantBusinessType.bar,
      title: 'Wine bar – Warszawa Śródmieście',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      district: 'Śródmieście',
      street: 'ul. Nowy Świat',
      buildingNo: '33',
      area: 85,
      rent: 18000,
      rentBasis: RestaurantVatBasis.vatUnspecified,
      fee: const RestaurantTransferFee(
        kind: RestaurantTransferFeeKind.amount,
        amountPln: 110000,
        basis: RestaurantVatBasis.vatUnspecified,
      ),
      seller: ownerEwa,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 15,
      seats: 42,
      alcohol: true,
      engagement: const RestaurantEngagement(views: 160, uniqueContacts: 6, uniqueFavorites: 8),
    ),
    // 11 — cafe Gliwice active
    L(
      id: 'r011',
      no: '51010011',
      type: RestaurantBusinessType.cafe,
      title: 'Specialty coffee shop – Gliwice',
      venueName: 'Silesia Coffee Gliwice',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      street: 'ul. Wieczorka',
      buildingNo: '3',
      area: 70,
      rent: 5400,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 35000),
      seller: ownerMateusz,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 18,
      seats: 30,
      alcohol: false,
      availableFrom: now, // immediately
      engagement: const RestaurantEngagement(views: 70, uniqueContacts: 2, uniqueFavorites: 4),
    ),
    // 12 — pizzeria Rybnik
    L(
      id: 'r012',
      no: '51010012',
      type: RestaurantBusinessType.pizzeria,
      title: 'Pizzeria with garden – Rybnik',
      venueName: 'Rybnik Garden Pizza',
      city: 'Rybnik',
      voivodeship: 'Śląskie',
      street: 'ul. Hallera',
      buildingNo: '19',
      area: 150,
      rent: 7200,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 55000),
      seller: ownerMateusz,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 6,
      seats: 55,
      terrace: 45,
      garden: true,
      play: true,
      delivery: true,
      inventory: inv('r012', RestaurantBusinessType.pizzeria, maySell: 3),
      engagement: const RestaurantEngagement(views: 120, uniqueContacts: 4, uniqueFavorites: 7),
    ),
    // 13 — other / food hall booth Częstochowa
    L(
      id: 'r013',
      no: '51010013',
      type: RestaurantBusinessType.other,
      title: 'Food-hall booth – Częstochowa',
      city: 'Częstochowa',
      voivodeship: 'Śląskie',
      street: 'ul. Wilsona',
      buildingNo: '7',
      unitNo: 'B12',
      area: 40,
      rent: 3900,
      rentBasis: RestaurantVatBasis.brutto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 18000, basis: RestaurantVatBasis.brutto),
      seller: ownerAnna,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 11,
      seats: 12,
      parking: false,
      extraction: false,
      alcohol: false,
      engagement: const RestaurantEngagement(views: 55, uniqueContacts: 1, uniqueFavorites: 2),
    ),
    // 14 — catering Bielsko paid active
    L(
      id: 'r014',
      no: '51010014',
      type: RestaurantBusinessType.cateringDarkKitchen,
      title: 'Production kitchen for catering – Bielsko-Biała',
      city: 'Bielsko-Biała',
      voivodeship: 'Śląskie',
      street: 'ul. Cieszyńska',
      buildingNo: '112',
      area: 260,
      rent: 10500,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 90000),
      seller: ownerEwa,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 20,
      alcohol: false,
      extraction: true,
      // RESTO-4 mock: 3 linked separate listings; first is sold → sync pending.
      inventory: inv('r014', RestaurantBusinessType.cateringDarkKitchen, maySell: 3, linkedNos: const ['10482137', '14120395', '11820463']).map((e) {
        if (e.id.endsWith('-0')) {
          return RestaurantInventoryItem(
            id: e.id,
            category: e.category,
            name: e.name,
            qty: e.qty,
            brand: e.brand,
            model: e.model,
            condition: e.condition,
            photos: e.photos,
            availability: RestaurantInventoryAvailability.maySellSeparately,
            linkedListingNo: '10482137',
            status: RestaurantInventoryStatus.soldSeparatelyPending,
            statusChangedAt: now.subtract(const Duration(days: 2)),
            reviewDueAt: reviewDue,
          );
        }
        return e;
      }).toList(),
      engagement: const RestaurantEngagement(views: 200, uniqueContacts: 7, uniqueFavorites: 11),
    ),
    // RESTO-3 mocks: 3 drafts, 2 payment_pending (r006 already pending_authorization)
    L(
      id: 'r_draft_1',
      no: 'D00000001',
      type: RestaurantBusinessType.cafe,
      title: 'Draft café concept – Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      street: 'ul. 3 Maja',
      buildingNo: '1',
      area: 80,
      rent: 5000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.none),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.draft,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 1,
    ),
    L(
      id: 'r_draft_2',
      no: 'D00000002',
      type: RestaurantBusinessType.bar,
      title: 'Draft wine bar – Kraków',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      street: 'ul. Floriańska',
      buildingNo: '9',
      area: 60,
      rent: 9000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 40000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.draft,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 2,
    ),
    L(
      id: 'r_draft_3',
      no: 'D00000003',
      type: RestaurantBusinessType.restaurant,
      title: 'Draft bistro – Gliwice',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      street: 'ul. Dolnych Wałów',
      buildingNo: '4',
      area: 100,
      rent: 7000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 50000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.draft,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 0,
    ),
    L(
      id: 'r_pay_1',
      no: '51010015',
      type: RestaurantBusinessType.fastFood,
      title: 'Payment pending – burger corner Warszawa',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      street: 'ul. Marszałkowska',
      buildingNo: '50',
      area: 55,
      rent: 14000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 80000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.paymentPending,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 0,
    ),
    L(
      id: 'r_pay_2',
      no: '51010016',
      type: RestaurantBusinessType.bakeryPatisserie,
      title: 'Payment pending – bakery Rybnik',
      city: 'Rybnik',
      voivodeship: 'Śląskie',
      street: 'ul. Dworek',
      buildingNo: '2',
      area: 90,
      rent: 4800,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 30000),
      seller: ownerTg,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.paymentPending,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 1,
    ),
  ];

  TGListingNo.reserveAll(rows.map((r) => r.listingNo));
  return rows;
}

(double, double) _coords(String city) => switch (city) {
      'Katowice' => (50.2649, 19.0238),
      'Rybnik' => (50.0971, 18.5463),
      'Gliwice' => (50.2945, 18.6714),
      'Kraków' => (50.0647, 19.9450),
      'Warszawa' => (52.2297, 21.0122),
      'Częstochowa' => (50.7965, 19.1200),
      'Bielsko-Biała' => (49.8224, 19.0584),
      _ => (50.2649, 19.0238),
    };
