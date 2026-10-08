import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum TGProductsSort { recommended, newest, priceLowHigh, priceHighLow, nearest, longestWarranty }

enum TGPriceFilterBasis { netto, brutto }

/// Every user-controllable aspect of the products page.
///
/// The URL is the single source of truth: this class round-trips losslessly
/// through [toQuery] / [fromQuery], so deep links, the browser back button and
/// "Buy / Rent / category" links from the home page all land in exactly the
/// state they describe.
@immutable
class TGProductsQueryState {
  const TGProductsQueryState({
    this.listingType,
    this.verifiedOnly = false,
    this.conditions = const {},
    this.categories = const {},
    this.minPrice,
    this.maxPrice,
    this.includeNoPrice = true,
    this.priceFilterBasis = TGPriceFilterBasis.netto,
    this.city,
    this.radiusKm = 0,
    this.voivodeships = const {},
    this.powerTypes = const {},
    this.delivery,
    this.pickup,
    this.warrantyMinMonths,
    this.sellerTypes = const {},
    this.brand,
    this.search,
    this.sort = TGProductsSort.recommended,
    this.page = 1,
    this.view = TGProductCardLayout.grid,
  });

  /// `null` means "all" (buy and rent).
  final TGListingType? listingType;
  final bool verifiedOnly;
  final Set<TGCondition> conditions;
  final Set<TGCategory> categories;
  final int? minPrice;
  final int? maxPrice;
  final bool includeNoPrice;
  final TGPriceFilterBasis priceFilterBasis;
  final String? city;

  /// 0 = exact city only, otherwise "within N km of [city]".
  final int radiusKm;
  final Set<String> voivodeships;
  final Set<TGPowerType> powerTypes;
  final bool? delivery;
  final bool? pickup;
  final int? warrantyMinMonths;
  final Set<TGSellerType> sellerTypes;
  final String? brand;
  final String? search;
  final TGProductsSort sort;
  final int page;
  final TGProductCardLayout view;

  bool get hasCity => city != null && city!.trim().isNotEmpty;
  bool get hasBrand => brand != null && brand!.trim().isNotEmpty;
  bool get hasSearch => search != null && search!.trim().isNotEmpty;

  TGProductsQueryState copyWith({
    TGListingType? listingType,
    bool listingTypeToNull = false,
    bool? verifiedOnly,
    Set<TGCondition>? conditions,
    Set<TGCategory>? categories,
    int? minPrice,
    bool minPriceToNull = false,
    int? maxPrice,
    bool maxPriceToNull = false,
    bool? includeNoPrice,
    TGPriceFilterBasis? priceFilterBasis,
    String? city,
    bool cityToNull = false,
    int? radiusKm,
    Set<String>? voivodeships,
    Set<TGPowerType>? powerTypes,
    bool? delivery,
    bool deliveryToNull = false,
    bool? pickup,
    bool pickupToNull = false,
    int? warrantyMinMonths,
    bool warrantyToNull = false,
    Set<TGSellerType>? sellerTypes,
    String? brand,
    bool brandToNull = false,
    String? search,
    bool searchToNull = false,
    TGProductsSort? sort,
    int? page,
    TGProductCardLayout? view,
  }) {
    return TGProductsQueryState(
      listingType: listingTypeToNull ? null : (listingType ?? this.listingType),
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      conditions: conditions ?? this.conditions,
      categories: categories ?? this.categories,
      minPrice: minPriceToNull ? null : (minPrice ?? this.minPrice),
      maxPrice: maxPriceToNull ? null : (maxPrice ?? this.maxPrice),
      includeNoPrice: includeNoPrice ?? this.includeNoPrice,
      priceFilterBasis: priceFilterBasis ?? this.priceFilterBasis,
      city: cityToNull ? null : (city ?? this.city),
      radiusKm: radiusKm ?? this.radiusKm,
      voivodeships: voivodeships ?? this.voivodeships,
      powerTypes: powerTypes ?? this.powerTypes,
      delivery: deliveryToNull ? null : (delivery ?? this.delivery),
      pickup: pickupToNull ? null : (pickup ?? this.pickup),
      warrantyMinMonths: warrantyToNull ? null : (warrantyMinMonths ?? this.warrantyMinMonths),
      sellerTypes: sellerTypes ?? this.sellerTypes,
      brand: brandToNull ? null : (brand ?? this.brand),
      search: searchToNull ? null : (search ?? this.search),
      sort: sort ?? this.sort,
      page: page ?? this.page,
      view: view ?? this.view,
    );
  }

  /// Number of active *filters* (sort, page and view are presentation, not
  /// filters, so they never count).
  int get activeFilterCount {
    var n = 0;
    if (listingType != null) n++;
    if (verifiedOnly) n++;
    n += conditions.length;
    n += categories.length;
    if (minPrice != null) n++;
    if (maxPrice != null) n++;
    if (!includeNoPrice) n++;
    if (hasCity) n++;
    if (hasCity && radiusKm > 0) n++;
    n += voivodeships.length;
    n += powerTypes.length;
    if (delivery != null) n++;
    if (pickup != null) n++;
    if (warrantyMinMonths != null) n++;
    n += sellerTypes.length;
    if (hasBrand) n++;
    if (hasSearch) n++;
    return n;
  }

  /// All filters reset; sort order and layout are kept.
  TGProductsQueryState clearedFilters() => TGProductsQueryState(sort: sort, view: view);

  /// Serialises to URL query parameters. Defaults are omitted so the canonical
  /// "everything" URL is just `/products`.
  Map<String, String> toQuery() {
    final qp = <String, String>{};
    if (listingType != null) qp['type'] = listingType == TGListingType.rent ? 'rent' : 'buy';
    if (verifiedOnly) qp['verified'] = '1';
    if (conditions.isNotEmpty) qp['condition'] = _sorted(conditions.map(_encodeCondition)).join(',');
    if (categories.isNotEmpty) qp['cat'] = _sorted(categories.map(_encodeCategory)).join(',');
    if (minPrice != null) qp['min'] = minPrice.toString();
    if (maxPrice != null) qp['max'] = maxPrice.toString();
    if (!includeNoPrice) qp['noprice'] = '0';
    if (priceFilterBasis != TGPriceFilterBasis.netto) qp['pb'] = priceFilterBasis.name;
    if (hasCity) qp['city'] = city!.trim();
    if (radiusKm > 0) qp['r'] = radiusKm.toString();
    if (voivodeships.isNotEmpty) qp['v'] = _sorted(voivodeships).join(',');
    if (powerTypes.isNotEmpty) qp['power'] = _sorted(powerTypes.map(_encodePower)).join(',');
    if (delivery != null) qp['delivery'] = delivery! ? '1' : '0';
    if (pickup != null) qp['pickup'] = pickup! ? '1' : '0';
    if (warrantyMinMonths != null) qp['w'] = warrantyMinMonths.toString();
    if (sellerTypes.isNotEmpty) qp['seller'] = _sorted(sellerTypes.map(_encodeSellerType)).join(',');
    if (hasBrand) qp['brand'] = brand!.trim();
    if (hasSearch) qp['q'] = search!.trim();
    if (sort != TGProductsSort.recommended) qp['sort'] = encodeSort(sort);
    if (page != 1) qp['page'] = page.toString();
    if (view != TGProductCardLayout.grid) qp['view'] = 'list';
    return qp;
  }

  /// The `/products?...` location for this state.
  String toLocation({String path = '/products'}) {
    final qp = toQuery();
    return Uri(path: path, queryParameters: qp.isEmpty ? null : qp).toString();
  }

  static TGProductsQueryState fromQuery(Map<String, String> qp) {
    TGListingType? listingType;
    switch (qp['type']) {
      case 'buy':
        listingType = TGListingType.buy;
      case 'rent':
        listingType = TGListingType.rent;
    }

    final pbRaw = (qp['pb'] ?? '').toLowerCase();
    final delivery = qp['delivery'];
    final pickup = qp['pickup'];
    final page = int.tryParse(qp['page'] ?? '') ?? 1;
    final radius = int.tryParse(qp['r'] ?? '') ?? 0;
    final warranty = int.tryParse(qp['w'] ?? '');

    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return TGProductsQueryState(
      listingType: listingType,
      verifiedOnly: qp['verified'] == '1' || qp['verified'] == 'true',
      conditions: _decodeList(qp['condition']).map(_decodeCondition).whereType<TGCondition>().toSet(),
      categories: _decodeList(qp['cat']).map(_decodeCategory).whereType<TGCategory>().toSet(),
      minPrice: int.tryParse(qp['min'] ?? ''),
      maxPrice: int.tryParse(qp['max'] ?? ''),
      includeNoPrice: qp['noprice'] != '0',
      priceFilterBasis: pbRaw == 'brutto' ? TGPriceFilterBasis.brutto : TGPriceFilterBasis.netto,
      city: clean(qp['city']),
      radiusKm: radius < 0 ? 0 : radius,
      voivodeships: _decodeList(qp['v']).toSet(),
      powerTypes: _decodeList(qp['power']).map(_decodePower).whereType<TGPowerType>().toSet(),
      delivery: delivery == null ? null : (delivery == '1' || delivery == 'true'),
      pickup: pickup == null ? null : (pickup == '1' || pickup == 'true'),
      warrantyMinMonths: warranty,
      sellerTypes: _decodeList(qp['seller']).map(_decodeSellerType).whereType<TGSellerType>().toSet(),
      brand: clean(qp['brand']),
      search: clean(qp['q']),
      sort: decodeSort(qp['sort']),
      page: page < 1 ? 1 : page,
      view: (qp['view'] ?? '').toLowerCase() == 'list' ? TGProductCardLayout.list : TGProductCardLayout.grid,
    );
  }

  /// True when two states serialise to the same URL.
  bool sameAs(TGProductsQueryState other) => mapEquals(toQuery(), other.toQuery());
}

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

List<String> _decodeList(String? raw) => (raw ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList(growable: false);

String _encodeCondition(TGCondition c) => c == TGCondition.newItem ? 'new' : 'used';

TGCondition? _decodeCondition(String raw) {
  switch (raw.toLowerCase()) {
    case 'new':
    case 'nowy':
      return TGCondition.newItem;
    case 'used':
    case 'uzywany':
      return TGCondition.used;
  }
  return null;
}

/// Stable URL slug for a category (also used by home page / footer links).
String encodeCategory(TGCategory c) => _encodeCategory(c);

String _encodeCategory(TGCategory c) => switch (c) {
      TGCategory.cookingEquipment => 'cooking',
      TGCategory.refrigerationEquipment => 'refrigeration',
      TGCategory.warewashing => 'warewashing',
      TGCategory.foodPreparation => 'prep',
      TGCategory.stainlessSteelFurniture => 'stainless',
      TGCategory.barAndBeverageEquipment => 'bar',
    };

TGCategory? _decodeCategory(String raw) => switch (raw.toLowerCase()) {
      'cooking' => TGCategory.cookingEquipment,
      'refrigeration' => TGCategory.refrigerationEquipment,
      'warewashing' => TGCategory.warewashing,
      'prep' => TGCategory.foodPreparation,
      'stainless' => TGCategory.stainlessSteelFurniture,
      'bar' => TGCategory.barAndBeverageEquipment,
      _ => null,
    };

String _encodePower(TGPowerType p) => switch (p) {
      TGPowerType.electric => 'electric',
      TGPowerType.gas => 'gas',
      TGPowerType.other => 'other',
    };

TGPowerType? _decodePower(String raw) => switch (raw.toLowerCase()) {
      'electric' => TGPowerType.electric,
      'gas' => TGPowerType.gas,
      'other' => TGPowerType.other,
      _ => null,
    };

String _encodeSellerType(TGSellerType t) => t == TGSellerType.store ? 'store' : 'private';

TGSellerType? _decodeSellerType(String raw) => switch (raw.toLowerCase()) {
      'store' => TGSellerType.store,
      'private' => TGSellerType.private,
      _ => null,
    };

String encodeSort(TGProductsSort s) => switch (s) {
      TGProductsSort.recommended => 'recommended',
      TGProductsSort.newest => 'newest',
      TGProductsSort.priceLowHigh => 'price_asc',
      TGProductsSort.priceHighLow => 'price_desc',
      TGProductsSort.nearest => 'nearest',
      TGProductsSort.longestWarranty => 'warranty',
    };

TGProductsSort decodeSort(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'newest' => TGProductsSort.newest,
      'price_asc' => TGProductsSort.priceLowHigh,
      'price_desc' => TGProductsSort.priceHighLow,
      'nearest' => TGProductsSort.nearest,
      'warranty' => TGProductsSort.longestWarranty,
      _ => TGProductsSort.recommended,
    };

String sortLabel(TGProductsSort s, {String Function(String key)? t}) => switch (s) {
      TGProductsSort.recommended => t?.call('ui_sort_recommended') ?? 'Recommended',
      TGProductsSort.newest => t?.call('ui_sort_newest') ?? 'Newest',
      TGProductsSort.priceLowHigh => t?.call('ui_sort_price_low') ?? 'Price: low to high',
      TGProductsSort.priceHighLow => t?.call('ui_sort_price_high') ?? 'Price: high to low',
      TGProductsSort.nearest => t?.call('ui_sort_nearest') ?? 'Nearest',
      TGProductsSort.longestWarranty => t?.call('ui_sort_warranty') ?? 'Longest warranty',
    };

String conditionLabel(TGCondition c, {String Function(String key)? t}) => c == TGCondition.newItem
    ? (t?.call('ui_condition_new') ?? 'New')
    : (t?.call('ui_condition_used') ?? 'Used');

String categoryLabel(TGCategory c, {String Function(String key)? t}) => switch (c) {
      TGCategory.cookingEquipment => t?.call('ui_cat_cooking') ?? 'Cooking Equipment',
      TGCategory.refrigerationEquipment => t?.call('ui_cat_refrigeration') ?? 'Refrigeration Equipment',
      TGCategory.warewashing => t?.call('ui_cat_warewashing') ?? 'Warewashing',
      TGCategory.foodPreparation => t?.call('ui_cat_food_prep') ?? 'Food Preparation',
      TGCategory.stainlessSteelFurniture => t?.call('ui_cat_stainless') ?? 'Stainless Steel Furniture',
      TGCategory.barAndBeverageEquipment => t?.call('ui_cat_bar') ?? 'Bar & Beverage Equipment',
    };
