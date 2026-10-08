import 'package:flutter/foundation.dart';

enum TGPriceUnit { oneTime, month }
enum TGPriceBasis { brutto, netto }
enum TGCondition { newItem, used }
enum TGListingType { buy, rent }
enum TGCategory {
  cookingEquipment,
  refrigerationEquipment,
  warewashing,
  foodPreparation,
  stainlessSteelFurniture,
  barAndBeverageEquipment,
}

enum TGPowerType { electric, gas, other }

/// Lifecycle of a classifieds listing.
enum TGListingStatus { draft, paymentPending, active, expired, sold, underReview, removed }

/// How a listing was paid for / slotted.
enum TGListingSource { free, paid, store }

/// How a result set is presented: 3-column grid or horizontal list rows.
enum TGProductCardLayout { grid, list }

extension TGEnumParsing on String {
  TGPriceUnit toPriceUnit() => switch (this) {
        'month' => TGPriceUnit.month,
        _ => TGPriceUnit.oneTime,
      };
  TGPriceBasis toPriceBasis() => switch (this) {
        'netto' => TGPriceBasis.netto,
        _ => TGPriceBasis.brutto,
      };
  TGCondition toCondition() => switch (this) {
        'used' => TGCondition.used,
        _ => TGCondition.newItem,
      };
  TGListingType toListingType() => switch (this) {
        'rent' => TGListingType.rent,
        _ => TGListingType.buy,
      };
  TGCategory toCategory() => switch (this) {
        'Refrigeration Equipment' => TGCategory.refrigerationEquipment,
        'Warewashing' => TGCategory.warewashing,
        'Food Preparation' => TGCategory.foodPreparation,
        'Stainless Steel Furniture' => TGCategory.stainlessSteelFurniture,
        'Bar & Beverage Equipment' => TGCategory.barAndBeverageEquipment,
        _ => TGCategory.cookingEquipment,
      };
  TGPowerType toPowerType() => switch (this) {
        'gas' => TGPowerType.gas,
        'other' => TGPowerType.other,
        _ => TGPowerType.electric,
      };
  TGSellerType toSellerType() => switch (this) {
        'private' => TGSellerType.private,
        _ => TGSellerType.store,
      };
  TGListingStatus toListingStatus() => switch (this) {
        'draft' => TGListingStatus.draft,
        'payment_pending' || 'paymentPending' => TGListingStatus.paymentPending,
        'sold' => TGListingStatus.sold,
        'expired' => TGListingStatus.expired,
        'under_review' || 'underReview' => TGListingStatus.underReview,
        'removed' => TGListingStatus.removed,
        _ => TGListingStatus.active,
      };
  TGListingSource toListingSource() => switch (this) {
        'paid' => TGListingSource.paid,
        'store' => TGListingSource.store,
        _ => TGListingSource.free,
      };
}

extension TGEnumStrings on Enum {
  String get key => name;
}

enum TGSellerType { store, private }

@immutable
class TGSeller {
  const TGSeller({
    required this.id,
    required this.name,
    required this.type,
    required this.verified,
    required this.rating,
  });

  final String id;
  final String name;
  final TGSellerType type;
  final bool verified;
  final double rating;

  TGSeller copyWith({
    String? id,
    String? name,
    TGSellerType? type,
    bool? verified,
    double? rating,
  }) =>
      TGSeller(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        verified: verified ?? this.verified,
        rating: rating ?? this.rating,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.key,
        'verified': verified,
        'rating': rating,
      };

  static TGSeller fromJson(Map<String, dynamic> json) => TGSeller(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? 'store').toString().toSellerType(),
        verified: json['verified'] == true,
        rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0,
      );
}

@immutable
class TGProduct {
  const TGProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.priceUnit,
    required this.priceBasis,
    required this.negotiable,
    required this.oldPrice,
    required this.condition,
    required this.listingType,
    required this.category,
    required this.powerType,
    required this.warrantyMonths,
    required this.delivery,
    required this.pickup,
    required this.seller,
    required this.city,
    required this.voivodeship,
    required this.phone,
    required this.imageUrl,
    required this.photoCount,
    required this.isPromoted,
    required this.createdAt,
    this.description,
    this.imageUrls = const [],
    this.status = TGListingStatus.active,
    this.publishedAt,
    this.expiresAt,
    this.source = TGListingSource.free,
    this.freeSlotIndex,
    this.promotedUntil,
    this.ownerId,
    this.listingNo,
    this.isHidden = false,
    this.extra = const {},
  });

  final String id;
  final String title;
  final int? price; // PLN
  final TGPriceUnit priceUnit;
  final TGPriceBasis priceBasis;
  final bool negotiable;
  final int? oldPrice;
  final TGCondition condition;
  final TGListingType listingType;
  final TGCategory category;
  final TGPowerType powerType;
  final int warrantyMonths;
  final bool delivery;
  /// In-person collection at the seller's location (odbiór osobisty / elden teslim).
  final bool pickup;
  final TGSeller seller;
  final String city;
  final String voivodeship;
  final String phone;
  final String imageUrl;
  final int photoCount;
  final bool isPromoted;
  final DateTime createdAt;
  final String? description;
  final List<String> imageUrls;
  final TGListingStatus status;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final TGListingSource source;
  final int? freeSlotIndex;
  final DateTime? promotedUntil;
  final String? ownerId;
  /// Immutable 8-digit public listing number. Null on drafts.
  final String? listingNo;
  /// Moderator hide-flag. Hidden [underReview] rows are not public.
  final bool isHidden;
  /// Extra specification rows shown on the PDP table (brand, kW, mm, …).
  final Map<String, String> extra;

  bool get isActive => status == TGListingStatus.active;

  bool get isPubliclyVisible =>
      status == TGListingStatus.active || (status == TGListingStatus.underReview && !isHidden);

  bool get allowsPublicContact => status == TGListingStatus.active && !isHidden;

  bool get canBeReported => status == TGListingStatus.active && !isHidden;

  String get ownerKey => ownerId ?? seller.id;

  int daysUntilExpiry([DateTime? now]) {
    final end = expiresAt;
    if (end == null) return 0;
    final d = end.difference(now ?? DateTime.now());
    if (d.isNegative) return d.inDays;
    // Ceil remaining time so "3 days left" does not drop to 2 after one millisecond.
    return (d.inHours + 23) ~/ 24;
  }

  int daysSinceExpiry([DateTime? now]) {
    final end = expiresAt;
    if (end == null) return 0;
    return (now ?? DateTime.now()).difference(end).inDays;
  }

  bool get isExpiringSoon {
    if (!isActive) return false;
    final d = daysUntilExpiry();
    return d >= 0 && d <= 5;
  }

  /// Photos shown in the PDP gallery (falls back to [imageUrl]).
  List<String> get gallery {
    if (imageUrls.isNotEmpty) return List<String>.unmodifiable(imageUrls);
    if (imageUrl.isEmpty) return const [];
    return [imageUrl];
  }

  TGProduct copyWith({
    String? id,
    String? title,
    int? price,
    TGPriceUnit? priceUnit,
    TGPriceBasis? priceBasis,
    bool? negotiable,
    int? oldPrice,
    TGCondition? condition,
    TGListingType? listingType,
    TGCategory? category,
    TGPowerType? powerType,
    int? warrantyMonths,
    bool? delivery,
    bool? pickup,
    TGSeller? seller,
    String? city,
    String? voivodeship,
    String? phone,
    String? imageUrl,
    int? photoCount,
    bool? isPromoted,
    DateTime? createdAt,
    String? description,
    List<String>? imageUrls,
    TGListingStatus? status,
    DateTime? publishedAt,
    DateTime? expiresAt,
    TGListingSource? source,
    int? freeSlotIndex,
    DateTime? promotedUntil,
    String? ownerId,
    String? listingNo,
    bool? isHidden,
    Map<String, String>? extra,
  }) =>
      TGProduct(
        id: id ?? this.id,
        title: title ?? this.title,
        price: price ?? this.price,
        priceUnit: priceUnit ?? this.priceUnit,
        priceBasis: priceBasis ?? this.priceBasis,
        negotiable: negotiable ?? this.negotiable,
        oldPrice: oldPrice ?? this.oldPrice,
        condition: condition ?? this.condition,
        listingType: listingType ?? this.listingType,
        category: category ?? this.category,
        powerType: powerType ?? this.powerType,
        warrantyMonths: warrantyMonths ?? this.warrantyMonths,
        delivery: delivery ?? this.delivery,
        pickup: pickup ?? this.pickup,
        seller: seller ?? this.seller,
        city: city ?? this.city,
        voivodeship: voivodeship ?? this.voivodeship,
        phone: phone ?? this.phone,
        imageUrl: imageUrl ?? this.imageUrl,
        photoCount: photoCount ?? this.photoCount,
        isPromoted: isPromoted ?? this.isPromoted,
        createdAt: createdAt ?? this.createdAt,
        description: description ?? this.description,
        imageUrls: imageUrls ?? this.imageUrls,
        status: status ?? this.status,
        publishedAt: publishedAt ?? this.publishedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        source: source ?? this.source,
        freeSlotIndex: freeSlotIndex ?? this.freeSlotIndex,
        promotedUntil: promotedUntil ?? this.promotedUntil,
        ownerId: ownerId ?? this.ownerId,
        listingNo: listingNo ?? this.listingNo,
        isHidden: isHidden ?? this.isHidden,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'priceUnit': priceUnit.key,
        'priceBasis': priceBasis.key,
        'negotiable': negotiable,
        'oldPrice': oldPrice,
        'condition': condition.key,
        'listingType': listingType.key,
        'category': categoryLabel,
        'powerType': powerType.key,
        'warrantyMonths': warrantyMonths,
        'delivery': delivery,
        'pickup': pickup,
        'seller': seller.toJson(),
        'city': city,
        'voivodeship': voivodeship,
        'phone': phone,
        'imageUrl': imageUrl,
        'photoCount': photoCount,
        'isPromoted': isPromoted,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'imageUrls': imageUrls,
        'status': _statusWire(status),
        'publishedAt': publishedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'source': source.key,
        'freeSlotIndex': freeSlotIndex,
        'promotedUntil': promotedUntil?.toIso8601String(),
        'ownerId': ownerId,
        'listingNo': listingNo,
        'isHidden': isHidden,
        'extra': extra,
      };

  static TGProduct fromJson(Map<String, dynamic> json) {
    final createdRaw = (json['createdAt'] ?? '').toString();
    DateTime created;
    try {
      created = DateTime.parse(createdRaw);
    } catch (_) {
      created = DateTime.now();
    }

    final sellerRaw = json['seller'];
    final basisRaw = (json['priceBasis'] ?? 'brutto').toString();
    // Backwards compatibility: older seed used `priceBasis: negotiable`.
    final basisWasNegotiable = basisRaw == 'negotiable';
    final negotiable = json['negotiable'] == true || basisWasNegotiable;
    return TGProduct(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      price: json['price'] is num ? (json['price'] as num).round() : null,
      priceUnit: (json['priceUnit'] ?? 'oneTime').toString().toPriceUnit(),
      priceBasis: basisWasNegotiable ? TGPriceBasis.brutto : basisRaw.toPriceBasis(),
      negotiable: negotiable,
      oldPrice: json['oldPrice'] is num ? (json['oldPrice'] as num).round() : null,
      condition: (json['condition'] ?? 'newItem').toString().toCondition(),
      listingType: (json['listingType'] ?? 'buy').toString().toListingType(),
      category: (json['category'] ?? 'Cooking Equipment').toString().toCategory(),
      powerType: (json['powerType'] ?? 'electric').toString().toPowerType(),
      warrantyMonths: json['warrantyMonths'] is num ? (json['warrantyMonths'] as num).round() : 0,
      delivery: json['delivery'] == true,
      // Missing key defaults to true: used equipment is typically collected in person.
      pickup: json.containsKey('pickup') ? json['pickup'] == true : true,
      seller: sellerRaw is Map<String, dynamic> ? TGSeller.fromJson(sellerRaw) : const TGSeller(id: 'unknown', name: 'Unknown', type: TGSellerType.store, verified: false, rating: 0),
      city: (json['city'] ?? '').toString(),
      voivodeship: (json['voivodeship'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      photoCount: json['photoCount'] is num ? (json['photoCount'] as num).round() : 0,
      isPromoted: json['isPromoted'] == true,
      createdAt: created,
      description: json['description']?.toString(),
      imageUrls: _stringList(json['imageUrls']),
      status: (json['status'] ?? 'active').toString().toListingStatus(),
      publishedAt: _tryDate(json['publishedAt']),
      expiresAt: _tryDate(json['expiresAt']),
      source: (json['source'] ?? 'free').toString().toListingSource(),
      freeSlotIndex: json['freeSlotIndex'] is num ? (json['freeSlotIndex'] as num).round() : null,
      promotedUntil: _tryDate(json['promotedUntil']),
      ownerId: json['ownerId']?.toString(),
      listingNo: json['listingNo']?.toString(),
      isHidden: json['isHidden'] == true,
      extra: _stringMap(json['extra']),
    );
  }

  String get categoryLabel => switch (category) {
        TGCategory.cookingEquipment => 'Cooking Equipment',
        TGCategory.refrigerationEquipment => 'Refrigeration Equipment',
        TGCategory.warewashing => 'Warewashing',
        TGCategory.foodPreparation => 'Food Preparation',
        TGCategory.stainlessSteelFurniture => 'Stainless Steel Furniture',
        TGCategory.barAndBeverageEquipment => 'Bar & Beverage Equipment',
      };
}

String _statusWire(TGListingStatus status) => switch (status) {
      TGListingStatus.paymentPending => 'payment_pending',
      TGListingStatus.underReview => 'under_review',
      _ => status.name,
    };

DateTime? _tryDate(Object? raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString());
  } catch (_) {
    return null;
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e != null && e.toString().trim().isNotEmpty) e.toString(),
  ];
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.key.toString().trim().isNotEmpty && e.value != null && e.value.toString().trim().isNotEmpty)
        e.key.toString(): e.value.toString(),
  };
}
