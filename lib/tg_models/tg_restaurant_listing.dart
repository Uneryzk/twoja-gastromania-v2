import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGSeller;

// Re-export seller types used on restaurant cards.
export 'package:twoja_gastromania/tg_models/tg_product.dart' show TGSeller, TGSellerType;

enum RestaurantListingStatus {
  draft,
  paymentPending,
  pendingAuthorization,
  active,
  expired,
  sold,
  underReview,
  removed,
}

enum RestaurantListingSource { freeIntro, paid }

enum RestaurantPosterRole { owner, agent }

enum RestaurantBusinessType {
  restaurant,
  cafe,
  bar,
  pizzeria,
  fastFood,
  bakeryPatisserie,
  cateringDarkKitchen,
  club,
  other,
}

enum RestaurantLeaseType { fixed, indefinite }

enum RestaurantLandlordConsent { yes, no, toBeArranged }

enum RestaurantTransferFeeKind { amount, none }

enum RestaurantEquipmentIncluded { all, partial, none }

enum RestaurantAlcoholPermitStatus { hasPermit, newApplicationRequired, none, unknown }

enum RestaurantAlcoholClass { upTo45AndBeer, from45To18, over18 }

enum RestaurantAlcoholScope { onPremises, offPremises }

enum RestaurantStaffTakeover { yes, no, negotiable }

enum RestaurantGardenKind { none, own, municipalLease, landlord }

enum RestaurantPlayAreaKind { none, indoor, outdoor }

enum RestaurantCostKey {
  rent,
  serviceCharges,
  electricity,
  waterSewage,
  gas,
  heating,
  internetPhone,
  waste,
  propertyTax,
  insurance,
  musicLicence,
  alarmMonitoring,
  cleaningPest,
  greaseTrap,
  accounting,
  posSoftware,
  custom,
}

enum RestaurantCostPeriod { lastBill, avg12m, estimate }

enum RestaurantCostBasis { netto, brutto, unspecified }

enum RestaurantInventoryCategory {
  cooking,
  refrigeration,
  warewashing,
  foodPrep,
  stainlessFurniture,
  barBeverage,
  other,
}

enum RestaurantInventoryCondition { newItem, used, unknown }

enum RestaurantInventoryAvailability { included, maySellSeparately, excluded }

enum RestaurantInventoryStatus { active, soldSeparatelyPending, archived }

extension RestaurantListingStatusX on RestaurantListingStatus {
  String get key => switch (this) {
        RestaurantListingStatus.draft => 'draft',
        RestaurantListingStatus.paymentPending => 'payment_pending',
        RestaurantListingStatus.pendingAuthorization => 'pending_authorization',
        RestaurantListingStatus.active => 'active',
        RestaurantListingStatus.expired => 'expired',
        RestaurantListingStatus.sold => 'sold',
        RestaurantListingStatus.underReview => 'under_review',
        RestaurantListingStatus.removed => 'removed',
      };
}

/// VAT presentation for rent / fee: netto, brutto, or unspecified.
enum RestaurantVatBasis { netto, brutto, vatUnspecified }

@immutable
class RestaurantTransferFee {
  const RestaurantTransferFee({
    required this.kind,
    this.amountPln,
    this.basis = RestaurantVatBasis.netto,
  });

  final RestaurantTransferFeeKind kind;
  final int? amountPln;
  final RestaurantVatBasis basis;

  bool get isNone => kind == RestaurantTransferFeeKind.none;

  Map<String, dynamic> toJson() => {
        'kind': kind == RestaurantTransferFeeKind.none ? 'none' : 'amount',
        'amountPln': amountPln,
        'basis': switch (basis) {
          RestaurantVatBasis.brutto => 'brutto',
          RestaurantVatBasis.vatUnspecified => 'vat_unspecified',
          RestaurantVatBasis.netto => 'netto',
        },
      };

  static RestaurantTransferFee fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] ?? 'amount').toString() == 'none'
        ? RestaurantTransferFeeKind.none
        : RestaurantTransferFeeKind.amount;
    final b = (json['basis'] ?? 'netto').toString();
    return RestaurantTransferFee(
      kind: kind,
      amountPln: (json['amountPln'] as num?)?.toInt(),
      basis: switch (b) {
        'brutto' => RestaurantVatBasis.brutto,
        'vat_unspecified' => RestaurantVatBasis.vatUnspecified,
        _ => RestaurantVatBasis.netto,
      },
    );
  }
}

@immutable
class RestaurantAlcoholPermit {
  const RestaurantAlcoholPermit({
    required this.status,
    this.classes = const [],
    this.scope = const [],
    this.validUntil,
  });

  final RestaurantAlcoholPermitStatus status;
  final List<RestaurantAlcoholClass> classes;
  final List<RestaurantAlcoholScope> scope;
  final DateTime? validUntil;

  bool get inPlace => status == RestaurantAlcoholPermitStatus.hasPermit;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'classes': classes.map((e) => e.name).toList(),
        'scope': scope.map((e) => e.name).toList(),
        'validUntil': validUntil?.toIso8601String(),
      };

  static RestaurantAlcoholPermit fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RestaurantAlcoholPermit(status: RestaurantAlcoholPermitStatus.unknown);
    }
    return RestaurantAlcoholPermit(
      status: RestaurantAlcoholPermitStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RestaurantAlcoholPermitStatus.unknown,
      ),
      classes: ((json['classes'] as List?) ?? const [])
          .map((e) => RestaurantAlcoholClass.values.firstWhere((c) => c.name == e, orElse: () => RestaurantAlcoholClass.upTo45AndBeer))
          .toList(),
      scope: ((json['scope'] as List?) ?? const [])
          .map((e) => RestaurantAlcoholScope.values.firstWhere((c) => c.name == e, orElse: () => RestaurantAlcoholScope.onPremises))
          .toList(),
      validUntil: json['validUntil'] != null ? DateTime.tryParse(json['validUntil'].toString()) : null,
    );
  }
}

@immutable
class RestaurantGarden {
  const RestaurantGarden({
    this.kind = RestaurantGardenKind.none,
    this.areaM2,
    this.lastFeePln,
    this.feeBasis = RestaurantVatBasis.netto,
    this.feePeriod,
  });

  final RestaurantGardenKind kind;
  final double? areaM2;
  final int? lastFeePln;
  final RestaurantVatBasis feeBasis;
  final String? feePeriod;

  bool get hasGarden => kind != RestaurantGardenKind.none;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'areaM2': areaM2,
        'lastFeePln': lastFeePln,
        'feeBasis': feeBasis.name,
        'feePeriod': feePeriod,
      };

  static RestaurantGarden fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RestaurantGarden();
    return RestaurantGarden(
      kind: RestaurantGardenKind.values.firstWhere((e) => e.name == json['kind'], orElse: () => RestaurantGardenKind.none),
      areaM2: (json['areaM2'] as num?)?.toDouble(),
      lastFeePln: (json['lastFeePln'] as num?)?.toInt(),
      feeBasis: RestaurantVatBasis.values.firstWhere((e) => e.name == json['feeBasis'], orElse: () => RestaurantVatBasis.netto),
      feePeriod: json['feePeriod']?.toString(),
    );
  }
}

@immutable
class RestaurantPlayArea {
  const RestaurantPlayArea({this.kind = RestaurantPlayAreaKind.none, this.areaM2});

  final RestaurantPlayAreaKind kind;
  final double? areaM2;

  bool get hasPlayArea => kind != RestaurantPlayAreaKind.none;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'areaM2': areaM2};

  static RestaurantPlayArea fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RestaurantPlayArea();
    return RestaurantPlayArea(
      kind: RestaurantPlayAreaKind.values.firstWhere((e) => e.name == json['kind'], orElse: () => RestaurantPlayAreaKind.none),
      areaM2: (json['areaM2'] as num?)?.toDouble(),
    );
  }
}

@immutable
class RestaurantDetails {
  const RestaurantDetails({
    this.garden = const RestaurantGarden(),
    this.playArea = const RestaurantPlayArea(),
    this.otherInfo,
    this.conceptMenu,
    this.customersLocation,
    this.hoursSeasonality,
    this.deliveryOnline = false,
    this.staffContracts,
    this.systems,
    this.brandAssets = const [],
  });

  final RestaurantGarden garden;
  final RestaurantPlayArea playArea;
  final String? otherInfo;
  final String? conceptMenu;
  final String? customersLocation;
  final String? hoursSeasonality;
  final bool deliveryOnline;
  final String? staffContracts;
  final String? systems;
  final List<String> brandAssets;

  Map<String, dynamic> toJson() => {
        'garden': garden.toJson(),
        'playArea': playArea.toJson(),
        'otherInfo': otherInfo,
        'conceptMenu': conceptMenu,
        'customersLocation': customersLocation,
        'hoursSeasonality': hoursSeasonality,
        'deliveryOnline': deliveryOnline,
        'staffContracts': staffContracts,
        'systems': systems,
        'brandAssets': brandAssets,
      };

  static RestaurantDetails fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RestaurantDetails();
    return RestaurantDetails(
      garden: RestaurantGarden.fromJson(json['garden'] as Map<String, dynamic>?),
      playArea: RestaurantPlayArea.fromJson(json['playArea'] as Map<String, dynamic>?),
      otherInfo: json['otherInfo']?.toString(),
      conceptMenu: json['conceptMenu']?.toString(),
      customersLocation: json['customersLocation']?.toString(),
      hoursSeasonality: json['hoursSeasonality']?.toString(),
      deliveryOnline: json['deliveryOnline'] == true,
      staffContracts: json['staffContracts']?.toString(),
      systems: json['systems']?.toString(),
      brandAssets: ((json['brandAssets'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

@immutable
class RestaurantCostLine {
  const RestaurantCostLine({
    required this.key,
    required this.label,
    required this.amountPln,
    this.basis = RestaurantCostBasis.netto,
    this.period = RestaurantCostPeriod.estimate,
    this.includedInRent = false,
  });

  final RestaurantCostKey key;
  final String label;
  final int amountPln;
  final RestaurantCostBasis basis;
  final RestaurantCostPeriod period;
  final bool includedInRent;

  Map<String, dynamic> toJson() => {
        'key': key.name,
        'label': label,
        'amountPln': amountPln,
        'basis': basis.name,
        'period': period.name,
        'includedInRent': includedInRent,
      };

  static RestaurantCostLine fromJson(Map<String, dynamic> json) => RestaurantCostLine(
        key: RestaurantCostKey.values.firstWhere((e) => e.name == json['key'], orElse: () => RestaurantCostKey.custom),
        label: (json['label'] ?? '').toString(),
        amountPln: (json['amountPln'] as num?)?.toInt() ?? 0,
        basis: RestaurantCostBasis.values.firstWhere((e) => e.name == json['basis'], orElse: () => RestaurantCostBasis.unspecified),
        period: RestaurantCostPeriod.values.firstWhere((e) => e.name == json['period'], orElse: () => RestaurantCostPeriod.estimate),
        includedInRent: json['includedInRent'] == true,
      );
}

@immutable
class RestaurantInventoryItem {
  const RestaurantInventoryItem({
    required this.id,
    required this.category,
    required this.name,
    required this.qty,
    this.brand,
    this.model,
    this.condition = RestaurantInventoryCondition.used,
    this.photos = const [],
    this.availability = RestaurantInventoryAvailability.included,
    this.linkedListingNo,
    this.status = RestaurantInventoryStatus.active,
    this.statusChangedAt,
    this.reviewDueAt,
  });

  final String id;
  final RestaurantInventoryCategory category;
  final String name;
  final int qty;
  final String? brand;
  final String? model;
  final RestaurantInventoryCondition condition;
  final List<String> photos;
  final RestaurantInventoryAvailability availability;
  final String? linkedListingNo;
  final RestaurantInventoryStatus status;
  final DateTime? statusChangedAt;
  final DateTime? reviewDueAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'name': name,
        'qty': qty,
        'brand': brand,
        'model': model,
        'condition': condition.name,
        'photos': photos,
        'availability': availability.name,
        'linkedListingNo': linkedListingNo,
        'status': status.name,
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'reviewDueAt': reviewDueAt?.toIso8601String(),
      };

  static RestaurantInventoryItem fromJson(Map<String, dynamic> json) => RestaurantInventoryItem(
        id: (json['id'] ?? '').toString(),
        category: RestaurantInventoryCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => RestaurantInventoryCategory.other,
        ),
        name: (json['name'] ?? '').toString(),
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        brand: json['brand']?.toString(),
        model: json['model']?.toString(),
        condition: RestaurantInventoryCondition.values.firstWhere(
          (e) => e.name == json['condition'],
          orElse: () => RestaurantInventoryCondition.unknown,
        ),
        photos: ((json['photos'] as List?) ?? const []).map((e) => e.toString()).toList(),
        availability: RestaurantInventoryAvailability.values.firstWhere(
          (e) => e.name == json['availability'],
          orElse: () => RestaurantInventoryAvailability.included,
        ),
        linkedListingNo: json['linkedListingNo']?.toString(),
        status: RestaurantInventoryStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => RestaurantInventoryStatus.active,
        ),
        statusChangedAt: json['statusChangedAt'] != null ? DateTime.tryParse(json['statusChangedAt'].toString()) : null,
        reviewDueAt: json['reviewDueAt'] != null ? DateTime.tryParse(json['reviewDueAt'].toString()) : null,
      );
}

@immutable
class RestaurantEngagement {
  const RestaurantEngagement({this.views = 0, this.uniqueContacts = 0, this.uniqueFavorites = 0});

  final int views;
  final int uniqueContacts;
  final int uniqueFavorites;

  bool get hasInterest => uniqueContacts > 0 || uniqueFavorites > 0 || views > 20;

  Map<String, dynamic> toJson() => {
        'views': views,
        'uniqueContacts': uniqueContacts,
        'uniqueFavorites': uniqueFavorites,
      };

  static RestaurantEngagement fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RestaurantEngagement();
    return RestaurantEngagement(
      views: (json['views'] as num?)?.toInt() ?? 0,
      uniqueContacts: (json['uniqueContacts'] as num?)?.toInt() ?? 0,
      uniqueFavorites: (json['uniqueFavorites'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Premises identity key: city|street|buildingNo|unitNo (normalized).
abstract final class RestaurantPremisesKey {
  static String normalize({
    required String city,
    required String street,
    required String buildingNo,
    String? unitNo,
  }) {
    String scrub(String s) {
      var t = s.toLowerCase().trim();
      t = t
          .replaceAll(RegExp(r'\bul\.?\b'), '')
          .replaceAll(RegExp(r'\bal\.?\b'), '')
          .replaceAll(RegExp(r'[àáâãäåą]'), 'a')
          .replaceAll(RegExp(r'[ćç]'), 'c')
          .replaceAll(RegExp(r'[èéêëę]'), 'e')
          .replaceAll(RegExp(r'[ìíîï]'), 'i')
          .replaceAll(RegExp(r'[ł]'), 'l')
          .replaceAll(RegExp(r'[ńñ]'), 'n')
          .replaceAll(RegExp(r'[òóôõö]'), 'o')
          .replaceAll(RegExp(r'[ś]'), 's')
          .replaceAll(RegExp(r'[ùúûü]'), 'u')
          .replaceAll(RegExp(r'[źż]'), 'z')
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return t;
    }

    return [scrub(city), scrub(street), scrub(buildingNo), scrub(unitNo ?? '')].join('|');
  }
}

@immutable
class RestaurantListing {
  const RestaurantListing({
    required this.id,
    required this.listingNo,
    required this.slug,
    required this.status,
    required this.isHidden,
    required this.publishedAt,
    required this.expiresAt,
    required this.source,
    required this.freeExtensionGranted,
    required this.promotedUntil,
    required this.ownerId,
    required this.posterRole,
    required this.authorizationConfirmed,
    required this.premisesKey,
    required this.businessType,
    required this.title,
    required this.description,
    required this.reasonForSale,
    required this.availableFrom,
    required this.city,
    required this.voivodeship,
    this.district,
    required this.street,
    required this.buildingNo,
    this.unitNo,
    this.lat,
    this.lng,
    required this.totalAreaM2,
    this.salesAreaM2,
    this.kitchenAreaM2,
    this.seats,
    this.terraceM2,
    this.floorLevel,
    this.parking = false,
    this.powerKw,
    this.gasConnection = false,
    this.extractionSystem = false,
    required this.rentMonthly,
    required this.rentBasis,
    this.depositPln,
    required this.leaseType,
    this.leaseEndsAt,
    required this.landlordConsent,
    required this.transferFee,
    this.negotiable = false,
    required this.equipmentIncluded,
    required this.alcoholPermit,
    this.sanitaryApproval = false,
    this.staffTakeover = RestaurantStaffTakeover.negotiable,
    this.declaredMonthlyRevenue,
    this.declaredAsOf,
    this.documents = const [],
    this.images = const [],
    this.floorPlanUrl,
    this.photoCount = 1,
    this.details = const RestaurantDetails(),
    this.costLines = const [],
    this.inventory = const [],
    this.engagement = const RestaurantEngagement(),
    required this.seller,
    this.phone = '+48 (532) 784-074',
    this.foundViaPlatform,
  });

  final String id;
  final String listingNo;
  final String slug;
  final RestaurantListingStatus status;
  final bool isHidden;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final RestaurantListingSource source;
  final bool freeExtensionGranted;
  final DateTime? promotedUntil;
  final String ownerId;
  final RestaurantPosterRole posterRole;
  final bool authorizationConfirmed;
  final String premisesKey;
  final RestaurantBusinessType businessType;
  final String title;
  final String description;
  final String reasonForSale;
  final DateTime availableFrom;
  final String city;
  final String voivodeship;
  final String? district;
  final String street;
  final String buildingNo;
  final String? unitNo;
  final double? lat;
  final double? lng;
  final double totalAreaM2;
  final double? salesAreaM2;
  final double? kitchenAreaM2;
  final int? seats;
  final double? terraceM2;
  final int? floorLevel;
  final bool parking;
  final double? powerKw;
  final bool gasConnection;
  final bool extractionSystem;
  final int rentMonthly;
  final RestaurantVatBasis rentBasis;
  final int? depositPln;
  final RestaurantLeaseType leaseType;
  final DateTime? leaseEndsAt;
  final RestaurantLandlordConsent landlordConsent;
  final RestaurantTransferFee transferFee;
  final bool negotiable;
  final RestaurantEquipmentIncluded equipmentIncluded;
  final RestaurantAlcoholPermit alcoholPermit;
  final bool sanitaryApproval;
  final RestaurantStaffTakeover staffTakeover;
  final int? declaredMonthlyRevenue;
  final DateTime? declaredAsOf;
  final List<String> documents;
  final List<String> images;
  final String? floorPlanUrl;
  final int photoCount;
  final RestaurantDetails details;
  final List<RestaurantCostLine> costLines;
  final List<RestaurantInventoryItem> inventory;
  final RestaurantEngagement engagement;
  final TGSeller seller;
  final String phone;
  final bool? foundViaPlatform;

  bool get isPromoted => promotedUntil != null && promotedUntil!.isAfter(DateTime.now());

  /// Hub / SEO: only active + not hidden.
  bool get isPubliclyVisible => status == RestaurantListingStatus.active && !isHidden;

  bool get isIndexable => isPubliclyVisible;

  String get imageUrl => images.isNotEmpty ? images.first : '';

  int get inventoryIncludedCount =>
      inventory.where((i) => i.availability == RestaurantInventoryAvailability.included && i.status == RestaurantInventoryStatus.active).fold<int>(0, (a, b) => a + b.qty);

  String get detailPath => '/restaurants/$listingNo-$slug';

  String get fullAddress => [
        street,
        buildingNo,
        if (unitNo != null && unitNo!.isNotEmpty) 'loc. $unitNo',
        city,
      ].where((e) => e.trim().isNotEmpty).join(', ');

  RestaurantListing copyWith({
    RestaurantListingStatus? status,
    bool? isHidden,
    DateTime? publishedAt,
    DateTime? expiresAt,
    DateTime? promotedUntil,
    bool? freeExtensionGranted,
    RestaurantEngagement? engagement,
    List<String>? images,
  }) =>
      RestaurantListing(
        id: id,
        listingNo: listingNo,
        slug: slug,
        status: status ?? this.status,
        isHidden: isHidden ?? this.isHidden,
        publishedAt: publishedAt ?? this.publishedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        source: source,
        freeExtensionGranted: freeExtensionGranted ?? this.freeExtensionGranted,
        promotedUntil: promotedUntil ?? this.promotedUntil,
        ownerId: ownerId,
        posterRole: posterRole,
        authorizationConfirmed: authorizationConfirmed,
        premisesKey: premisesKey,
        businessType: businessType,
        title: title,
        description: description,
        reasonForSale: reasonForSale,
        availableFrom: availableFrom,
        city: city,
        voivodeship: voivodeship,
        district: district,
        street: street,
        buildingNo: buildingNo,
        unitNo: unitNo,
        lat: lat,
        lng: lng,
        totalAreaM2: totalAreaM2,
        salesAreaM2: salesAreaM2,
        kitchenAreaM2: kitchenAreaM2,
        seats: seats,
        terraceM2: terraceM2,
        floorLevel: floorLevel,
        parking: parking,
        powerKw: powerKw,
        gasConnection: gasConnection,
        extractionSystem: extractionSystem,
        rentMonthly: rentMonthly,
        rentBasis: rentBasis,
        depositPln: depositPln,
        leaseType: leaseType,
        leaseEndsAt: leaseEndsAt,
        landlordConsent: landlordConsent,
        transferFee: transferFee,
        negotiable: negotiable,
        equipmentIncluded: equipmentIncluded,
        alcoholPermit: alcoholPermit,
        sanitaryApproval: sanitaryApproval,
        staffTakeover: staffTakeover,
        declaredMonthlyRevenue: declaredMonthlyRevenue,
        declaredAsOf: declaredAsOf,
        documents: documents,
        images: images ?? this.images,
        floorPlanUrl: floorPlanUrl,
        photoCount: photoCount,
        details: details,
        costLines: costLines,
        inventory: inventory,
        engagement: engagement ?? this.engagement,
        seller: seller,
        phone: phone,
        foundViaPlatform: foundViaPlatform,
      );

  static String businessTypeLabel(RestaurantBusinessType t) => switch (t) {
        RestaurantBusinessType.restaurant => 'Restaurant',
        RestaurantBusinessType.cafe => 'Café',
        RestaurantBusinessType.bar => 'Bar',
        RestaurantBusinessType.pizzeria => 'Pizzeria',
        RestaurantBusinessType.fastFood => 'Fast food',
        RestaurantBusinessType.bakeryPatisserie => 'Bakery / pâtisserie',
        RestaurantBusinessType.cateringDarkKitchen => 'Catering / dark kitchen',
        RestaurantBusinessType.club => 'Club',
        RestaurantBusinessType.other => 'Other',
      };

  static String businessTypeSlug(RestaurantBusinessType t) => switch (t) {
        RestaurantBusinessType.restaurant => 'restaurant',
        RestaurantBusinessType.cafe => 'cafe',
        RestaurantBusinessType.bar => 'bar',
        RestaurantBusinessType.pizzeria => 'pizzeria',
        RestaurantBusinessType.fastFood => 'fast_food',
        RestaurantBusinessType.bakeryPatisserie => 'bakery_patisserie',
        RestaurantBusinessType.cateringDarkKitchen => 'catering_dark_kitchen',
        RestaurantBusinessType.club => 'club',
        RestaurantBusinessType.other => 'other',
      };

  static RestaurantBusinessType? parseBusinessType(String raw) => switch (raw.toLowerCase()) {
        'restaurant' => RestaurantBusinessType.restaurant,
        'cafe' || 'café' => RestaurantBusinessType.cafe,
        'bar' => RestaurantBusinessType.bar,
        'pizzeria' => RestaurantBusinessType.pizzeria,
        'fast_food' || 'fastfood' => RestaurantBusinessType.fastFood,
        'bakery_patisserie' || 'bakery' => RestaurantBusinessType.bakeryPatisserie,
        'catering_dark_kitchen' || 'catering' => RestaurantBusinessType.cateringDarkKitchen,
        'club' => RestaurantBusinessType.club,
        'other' => RestaurantBusinessType.other,
        _ => null,
      };

  /// Build a listing with slug derived from title and reserved listing no.
  factory RestaurantListing.create({
    required String id,
    required String listingNo,
    required RestaurantListingStatus status,
    required bool isHidden,
    required DateTime? publishedAt,
    required DateTime? expiresAt,
    required RestaurantListingSource source,
    bool freeExtensionGranted = false,
    DateTime? promotedUntil,
    required String ownerId,
    required RestaurantPosterRole posterRole,
    bool authorizationConfirmed = true,
    required RestaurantBusinessType businessType,
    required String title,
    required String description,
    required String reasonForSale,
    required DateTime availableFrom,
    required String city,
    required String voivodeship,
    String? district,
    required String street,
    required String buildingNo,
    String? unitNo,
    double? lat,
    double? lng,
    required double totalAreaM2,
    double? salesAreaM2,
    double? kitchenAreaM2,
    int? seats,
    double? terraceM2,
    int? floorLevel,
    bool parking = false,
    double? powerKw,
    bool gasConnection = false,
    bool extractionSystem = false,
    required int rentMonthly,
    RestaurantVatBasis rentBasis = RestaurantVatBasis.netto,
    int? depositPln,
    required RestaurantLeaseType leaseType,
    DateTime? leaseEndsAt,
    RestaurantLandlordConsent landlordConsent = RestaurantLandlordConsent.toBeArranged,
    required RestaurantTransferFee transferFee,
    bool negotiable = false,
    RestaurantEquipmentIncluded equipmentIncluded = RestaurantEquipmentIncluded.partial,
    RestaurantAlcoholPermit alcoholPermit = const RestaurantAlcoholPermit(status: RestaurantAlcoholPermitStatus.unknown),
    bool sanitaryApproval = false,
    RestaurantStaffTakeover staffTakeover = RestaurantStaffTakeover.negotiable,
    int? declaredMonthlyRevenue,
    DateTime? declaredAsOf,
    List<String> documents = const [],
    required List<String> images,
    String? floorPlanUrl,
    int? photoCount,
    RestaurantDetails details = const RestaurantDetails(),
    List<RestaurantCostLine> costLines = const [],
    List<RestaurantInventoryItem> inventory = const [],
    RestaurantEngagement engagement = const RestaurantEngagement(),
    required TGSeller seller,
    String phone = '+48 (532) 784-074',
    bool? foundViaPlatform,
  }) {
    TGListingNo.reserve(listingNo);
    final slug = TGListingNo.slug(title);
    return RestaurantListing(
      id: id,
      listingNo: listingNo,
      slug: slug,
      status: status,
      isHidden: isHidden,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      source: source,
      freeExtensionGranted: freeExtensionGranted,
      promotedUntil: promotedUntil,
      ownerId: ownerId,
      posterRole: posterRole,
      authorizationConfirmed: authorizationConfirmed,
      premisesKey: RestaurantPremisesKey.normalize(
        city: city,
        street: street,
        buildingNo: buildingNo,
        unitNo: unitNo,
      ),
      businessType: businessType,
      title: title,
      description: description,
      reasonForSale: reasonForSale,
      availableFrom: availableFrom,
      city: city,
      voivodeship: voivodeship,
      district: district,
      street: street,
      buildingNo: buildingNo,
      unitNo: unitNo,
      lat: lat,
      lng: lng,
      totalAreaM2: totalAreaM2,
      salesAreaM2: salesAreaM2,
      kitchenAreaM2: kitchenAreaM2,
      seats: seats,
      terraceM2: terraceM2,
      floorLevel: floorLevel,
      parking: parking,
      powerKw: powerKw,
      gasConnection: gasConnection,
      extractionSystem: extractionSystem,
      rentMonthly: rentMonthly,
      rentBasis: rentBasis,
      depositPln: depositPln,
      leaseType: leaseType,
      leaseEndsAt: leaseEndsAt,
      landlordConsent: landlordConsent,
      transferFee: transferFee,
      negotiable: negotiable,
      equipmentIncluded: equipmentIncluded,
      alcoholPermit: alcoholPermit,
      sanitaryApproval: sanitaryApproval,
      staffTakeover: staffTakeover,
      declaredMonthlyRevenue: declaredMonthlyRevenue,
      declaredAsOf: declaredAsOf,
      documents: documents,
      images: images,
      floorPlanUrl: floorPlanUrl,
      photoCount: photoCount ?? images.length.clamp(1, 30),
      details: details,
      costLines: costLines,
      inventory: inventory,
      engagement: engagement,
      seller: seller,
      phone: phone,
      foundViaPlatform: foundViaPlatform,
    );
  }
}
