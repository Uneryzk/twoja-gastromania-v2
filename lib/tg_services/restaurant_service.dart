import 'package:flutter/foundation.dart';
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

  List<RestaurantListing> get all => List.unmodifiable(_all);

  /// Public hub catalogue (respects Production Mode).
  List<RestaurantListing> get publicListings {
    if (TGRevenueConfigService.instance.productionMode) return const [];
    return _all.where((r) => r.isPubliclyVisible).toList(growable: false);
  }

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

  void reset() {
    _all
      ..clear()
      ..addAll(_buildSeed());
    notifyListeners();
  }

  void _seed() {
    _all
      ..clear()
      ..addAll(_buildSeed());
  }
}

// ---------------------------------------------------------------------------
// Mock seed (14 listings)
// ---------------------------------------------------------------------------

List<RestaurantListing> _buildSeed() {
  final cfg = RestaurantConfigService.instance.config;
  final now = TGClock.now();

  const storeGastro = TGSeller(id: 'seller_gastropl', name: 'GastroPL Outlet', type: TGSellerType.store, verified: true, rating: 4.7);
  const storePrime = TGSeller(id: 'seller_primegastro', name: 'PrimeGastro', type: TGSellerType.store, verified: true, rating: 4.9);
  const ownerMateusz = TGSeller(id: 'seller_mateusz', name: 'Mateusz K.', type: TGSellerType.private, verified: false, rating: 4.4);
  const ownerAnna = TGSeller(id: 'seller_anna', name: 'Anna P.', type: TGSellerType.private, verified: false, rating: 4.6);
  const agentTechnica = TGSeller(id: 'seller_technica', name: 'Technica Pro', type: TGSellerType.store, verified: false, rating: 4.2);

  List<String> imgs(String id, RestaurantBusinessType type, String title, int n) =>
      TGListingImages.galleryForTheme(
        id: 'resto-$id',
        theme: RestaurantListing.businessTypeSlug(type),
        title: title,
        count: n,
      );

  List<RestaurantInventoryItem> inv(String prefix, int count, {int maySell = 2}) {
    final cats = RestaurantInventoryCategory.values;
    return [
      for (var i = 0; i < count; i++)
        RestaurantInventoryItem(
          id: '$prefix-inv-$i',
          category: cats[i % cats.length],
          name: 'Item ${i + 1}',
          qty: 1 + (i % 3),
          brand: i.isEven ? 'Bartscher' : 'Hobart',
          model: 'M-${100 + i}',
          condition: i % 5 == 0 ? RestaurantInventoryCondition.newItem : RestaurantInventoryCondition.used,
          availability: i < maySell ? RestaurantInventoryAvailability.maySellSeparately : RestaurantInventoryAvailability.included,
        ),
    ];
  }

  RestaurantListing L({
    required String id,
    required String no,
    required RestaurantBusinessType type,
    required String title,
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
      equipmentIncluded: inventory.isEmpty ? RestaurantEquipmentIncluded.partial : RestaurantEquipmentIncluded.all,
      alcoholPermit: alcohol
          ? const RestaurantAlcoholPermit(
              status: RestaurantAlcoholPermitStatus.hasPermit,
              classes: [RestaurantAlcoholClass.upTo45AndBeer, RestaurantAlcoholClass.from45To18],
              scope: [RestaurantAlcoholScope.onPremises],
            )
          : const RestaurantAlcoholPermit(status: RestaurantAlcoholPermitStatus.none),
      sanitaryApproval: true,
      staffTakeover: RestaurantStaffTakeover.negotiable,
      declaredMonthlyRevenue: revenue,
      declaredAsOf: revenue == null ? null : DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)),
      images: imgs(id, type, title, 6 + (id.hashCode % 5)),
      details: RestaurantDetails(
        garden: garden
            ? const RestaurantGarden(kind: RestaurantGardenKind.own, areaM2: 40)
            : const RestaurantGarden(),
        playArea: play
            ? const RestaurantPlayArea(kind: RestaurantPlayAreaKind.indoor, areaM2: 18)
            : const RestaurantPlayArea(),
        deliveryOnline: delivery,
        otherInfo: 'No ask-for-price: rent and transfer fee always visible.',
      ),
      inventory: inventory,
      engagement: engagement,
      seller: seller,
      foundViaPlatform: true,
    );
  }

  final reviewDue = PLBusinessDays.addBusinessDays(now, cfg.soldItemReviewBusinessDays);

  final rows = <RestaurantListing>[
    // 1 — day 5 free, promoted, restaurant Katowice
    L(
      id: 'r001',
      no: '51010001',
      type: RestaurantBusinessType.restaurant,
      title: 'Restaurant with terrace – Mariacka, Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      district: 'Śródmieście',
      street: 'ul. Mariacka',
      buildingNo: '12',
      area: 180,
      rent: 14500,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 120000, basis: RestaurantVatBasis.netto),
      seller: storeGastro,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 5,
      promoted: true,
      seats: 70,
      terrace: 35,
      garden: true,
      alcohol: true,
      inventory: inv('r001', 18),
      engagement: const RestaurantEngagement(views: 210, uniqueContacts: 8, uniqueFavorites: 12),
    ),
    // 2 — day 28 free with interest, cafe Rybnik
    L(
      id: 'r002',
      no: '51010002',
      type: RestaurantBusinessType.cafe,
      title: 'Corner café with pastry counter – Rybnik',
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
      inventory: inv('r002', 12),
      engagement: const RestaurantEngagement(views: 180, uniqueContacts: 5, uniqueFavorites: 9),
      revenue: 38000,
    ),
    // 3 — day 30 extended (no interest), bar Gliwice
    L(
      id: 'r003',
      no: '51010003',
      type: RestaurantBusinessType.bar,
      title: 'Cocktail bar – Gliwice centre',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      street: 'ul. Zwycięstwa',
      buildingNo: '41',
      area: 110,
      rent: 8900,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 70000),
      seller: ownerMateusz,
      role: RestaurantPosterRole.owner,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 30,
      freeExtension: true,
      expiresInDays: 30,
      seats: 50,
      alcohol: true,
      engagement: const RestaurantEngagement(views: 22, uniqueContacts: 0, uniqueFavorites: 1),
    ),
    // 4 — expired (had interest), pizzeria Kraków
    L(
      id: 'r004',
      no: '51010004',
      type: RestaurantBusinessType.pizzeria,
      title: 'Pizzeria with delivery fleet – Kraków Kazimierz',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      district: 'Kazimierz',
      street: 'ul. Miodowa',
      buildingNo: '22',
      area: 130,
      rent: 11000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 95000),
      seller: storePrime,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.expired,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 45,
      expiresInDays: -10,
      seats: 40,
      delivery: true,
      inventory: inv('r004', 15),
      engagement: const RestaurantEngagement(views: 340, uniqueContacts: 14, uniqueFavorites: 20),
    ),
    // 5 — paid active, promoted, fast food Warszawa
    L(
      id: 'r005',
      no: '51010005',
      type: RestaurantBusinessType.fastFood,
      title: 'Fast-food corner – Warszawa Mokotów',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      district: 'Mokotów',
      street: 'ul. Puławska',
      buildingNo: '88',
      area: 75,
      rent: 16000,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 150000),
      seller: storePrime,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 12,
      promoted: true,
      seats: 28,
      parking: false,
      delivery: true,
      inventory: inv('r005', 22, maySell: 4),
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
    // 7 — sold, catering Katowice
    L(
      id: 'r007',
      no: '51010007',
      type: RestaurantBusinessType.cateringDarkKitchen,
      title: 'Dark kitchen + catering hub – Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      street: 'ul. Gliwicka',
      buildingNo: '210',
      area: 220,
      rent: 9800,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 80000),
      seller: agentTechnica,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.sold,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 40,
      extraction: true,
      alcohol: false,
      inventory: inv('r007', 28, maySell: 6),
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
      inventory: inv('r009', 14),
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
      seller: storeGastro,
      role: RestaurantPosterRole.agent,
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
      city: 'Rybnik',
      voivodeship: 'Śląskie',
      street: 'ul. Hallera',
      buildingNo: '19',
      area: 150,
      rent: 7200,
      rentBasis: RestaurantVatBasis.netto,
      fee: const RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: 55000),
      seller: agentTechnica,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.freeIntro,
      publishedDaysAgo: 6,
      seats: 55,
      terrace: 45,
      garden: true,
      play: true,
      delivery: true,
      inventory: inv('r012', 20, maySell: 3),
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
      seller: storeGastro,
      role: RestaurantPosterRole.agent,
      status: RestaurantListingStatus.active,
      source: RestaurantListingSource.paid,
      publishedDaysAgo: 20,
      alcohol: false,
      extraction: true,
      inventory: inv('r014', 26, maySell: 5).map((e) {
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
            availability: e.availability,
            status: RestaurantInventoryStatus.soldSeparatelyPending,
            statusChangedAt: now.subtract(const Duration(days: 2)),
            reviewDueAt: reviewDue,
          );
        }
        return e;
      }).toList(),
      engagement: const RestaurantEngagement(views: 200, uniqueContacts: 7, uniqueFavorites: 11),
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
