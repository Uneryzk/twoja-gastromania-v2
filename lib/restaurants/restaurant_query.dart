import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGProductCardLayout;
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';

enum RestaurantSort {
  recommended,
  newest,
  rentLowHigh,
  rentHighLow,
  feeLowHigh,
  feeHighLow,
  area,
  nearest,
}

enum RestaurantAvailFilter { any, immediately, within1m, within3m }

enum RestaurantSellerFilter { owner, agent }

enum RestaurantFeature {
  terrace,
  garden,
  playArea,
  extraction,
  parking,
  equipmentList,
  alcoholPermit,
  takeawayDelivery,
}

enum RestaurantLeaseMin { any, m12, m24, m36, indefinite }

/// URL-backed query state for `/restaurants`.
@immutable
class RestaurantQueryState {
  const RestaurantQueryState({
    this.businessTypes = const {},
    this.verifiedOnly = false,
    this.city,
    this.radiusKm = 0,
    this.voivodeships = const {},
    this.areaMin,
    this.areaMax,
    this.rentMax,
    this.rentBasis = RestaurantVatBasis.netto,
    this.includeVatUnspecified = true,
    this.feeMax,
    this.feeBasis = RestaurantVatBasis.netto,
    this.includeNoTransferFee = true,
    this.leaseMin = RestaurantLeaseMin.any,
    this.features = const {},
    this.avail = RestaurantAvailFilter.any,
    this.sellerFilters = const {},
    this.sort = RestaurantSort.recommended,
    this.page = 1,
    this.view = TGProductCardLayout.grid,
    this.mobileShown = 12,
  });

  final Set<RestaurantBusinessType> businessTypes;
  final bool verifiedOnly;
  final String? city;
  final int radiusKm;
  final Set<String> voivodeships;
  final int? areaMin;
  final int? areaMax;
  final int? rentMax;
  final RestaurantVatBasis rentBasis;
  final bool includeVatUnspecified;
  final int? feeMax;
  final RestaurantVatBasis feeBasis;
  final bool includeNoTransferFee;
  final RestaurantLeaseMin leaseMin;
  final Set<RestaurantFeature> features;
  final RestaurantAvailFilter avail;
  final Set<RestaurantSellerFilter> sellerFilters;
  final RestaurantSort sort;
  final int page;
  final TGProductCardLayout view;

  /// Mobile "Show more" cursor (12 at a time). Desktop uses [page].
  final int mobileShown;

  bool get hasCity => city != null && city!.trim().isNotEmpty;

  int get activeFilterCount {
    var n = 0;
    n += businessTypes.length;
    if (verifiedOnly) n++;
    if (hasCity) n++;
    if (hasCity && radiusKm > 0) n++;
    n += voivodeships.length;
    if (areaMin != null) n++;
    if (areaMax != null) n++;
    if (rentMax != null) n++;
    if (!includeVatUnspecified) n++;
    if (feeMax != null) n++;
    if (!includeNoTransferFee) n++;
    if (leaseMin != RestaurantLeaseMin.any) n++;
    n += features.length;
    if (avail != RestaurantAvailFilter.any) n++;
    n += sellerFilters.length;
    return n;
  }

  RestaurantQueryState copyWith({
    Set<RestaurantBusinessType>? businessTypes,
    bool? verifiedOnly,
    String? city,
    bool cityToNull = false,
    int? radiusKm,
    Set<String>? voivodeships,
    int? areaMin,
    bool areaMinToNull = false,
    int? areaMax,
    bool areaMaxToNull = false,
    int? rentMax,
    bool rentMaxToNull = false,
    RestaurantVatBasis? rentBasis,
    bool? includeVatUnspecified,
    int? feeMax,
    bool feeMaxToNull = false,
    RestaurantVatBasis? feeBasis,
    bool? includeNoTransferFee,
    RestaurantLeaseMin? leaseMin,
    Set<RestaurantFeature>? features,
    RestaurantAvailFilter? avail,
    Set<RestaurantSellerFilter>? sellerFilters,
    RestaurantSort? sort,
    int? page,
    TGProductCardLayout? view,
    int? mobileShown,
  }) =>
      RestaurantQueryState(
        businessTypes: businessTypes ?? this.businessTypes,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        city: cityToNull ? null : (city ?? this.city),
        radiusKm: radiusKm ?? this.radiusKm,
        voivodeships: voivodeships ?? this.voivodeships,
        areaMin: areaMinToNull ? null : (areaMin ?? this.areaMin),
        areaMax: areaMaxToNull ? null : (areaMax ?? this.areaMax),
        rentMax: rentMaxToNull ? null : (rentMax ?? this.rentMax),
        rentBasis: rentBasis ?? this.rentBasis,
        includeVatUnspecified: includeVatUnspecified ?? this.includeVatUnspecified,
        feeMax: feeMaxToNull ? null : (feeMax ?? this.feeMax),
        feeBasis: feeBasis ?? this.feeBasis,
        includeNoTransferFee: includeNoTransferFee ?? this.includeNoTransferFee,
        leaseMin: leaseMin ?? this.leaseMin,
        features: features ?? this.features,
        avail: avail ?? this.avail,
        sellerFilters: sellerFilters ?? this.sellerFilters,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        view: view ?? this.view,
        mobileShown: mobileShown ?? this.mobileShown,
      );

  RestaurantQueryState clearedFilters() => RestaurantQueryState(sort: sort, view: view, mobileShown: mobileShown);

  Map<String, String> toQuery() {
    final qp = <String, String>{};
    if (businessTypes.isNotEmpty) {
      qp['type'] = (businessTypes.map(RestaurantListing.businessTypeSlug).toList()..sort()).join(',');
    }
    if (verifiedOnly) qp['verified'] = '1';
    if (hasCity) qp['city'] = city!.trim();
    if (radiusKm > 0) qp['r'] = radiusKm.toString();
    if (voivodeships.isNotEmpty) qp['v'] = (voivodeships.toList()..sort()).join(',');
    if (areaMin != null) qp['area_min'] = areaMin.toString();
    if (areaMax != null) qp['area_max'] = areaMax.toString();
    if (rentMax != null) qp['rent_max'] = rentMax.toString();
    if (rentBasis != RestaurantVatBasis.netto) qp['rent_pb'] = rentBasis == RestaurantVatBasis.brutto ? 'brutto' : 'vat_na';
    if (!includeVatUnspecified) qp['vat_na'] = '0';
    if (feeMax != null) qp['fee_max'] = feeMax.toString();
    if (feeBasis != RestaurantVatBasis.netto) qp['fee_pb'] = feeBasis == RestaurantVatBasis.brutto ? 'brutto' : 'vat_na';
    if (!includeNoTransferFee) qp['no_fee'] = '0';
    if (leaseMin != RestaurantLeaseMin.any) qp['lease_min'] = encodeLeaseMin(leaseMin);
    if (features.isNotEmpty) qp['feat'] = (features.map(encodeFeature).toList()..sort()).join(',');
    if (avail != RestaurantAvailFilter.any) qp['avail'] = encodeAvail(avail);
    if (sellerFilters.isNotEmpty) {
      qp['seller'] = (sellerFilters.map((e) => e == RestaurantSellerFilter.owner ? 'owner' : 'agent').toList()..sort()).join(',');
    }
    if (sort != RestaurantSort.recommended) qp['sort'] = encodeSort(sort);
    if (page != 1) qp['page'] = page.toString();
    if (view != TGProductCardLayout.grid) qp['view'] = 'list';
    return qp;
  }

  String toLocation({String path = '/restaurants'}) {
    final qp = toQuery();
    return Uri(path: path, queryParameters: qp.isEmpty ? null : qp).toString();
  }

  static RestaurantQueryState fromQuery(Map<String, String> qp) {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final types = (qp['type'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(RestaurantListing.parseBusinessType)
        .whereType<RestaurantBusinessType>()
        .toSet();

    final feats = (qp['feat'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(decodeFeature)
        .whereType<RestaurantFeature>()
        .toSet();

    final sellers = (qp['seller'] ?? '')
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e == 'owner' || e == 'agent')
        .map((e) => e == 'owner' ? RestaurantSellerFilter.owner : RestaurantSellerFilter.agent)
        .toSet();

    final page = int.tryParse(qp['page'] ?? '') ?? 1;
    final radius = int.tryParse(qp['r'] ?? '') ?? 0;

    return RestaurantQueryState(
      businessTypes: types,
      verifiedOnly: qp['verified'] == '1' || qp['verified'] == 'true',
      city: clean(qp['city']),
      radiusKm: radius < 0 ? 0 : radius,
      voivodeships: (qp['v'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet(),
      areaMin: int.tryParse(qp['area_min'] ?? ''),
      areaMax: int.tryParse(qp['area_max'] ?? ''),
      rentMax: int.tryParse(qp['rent_max'] ?? ''),
      rentBasis: (qp['rent_pb'] ?? '') == 'brutto' ? RestaurantVatBasis.brutto : RestaurantVatBasis.netto,
      includeVatUnspecified: qp['vat_na'] != '0',
      feeMax: int.tryParse(qp['fee_max'] ?? ''),
      feeBasis: (qp['fee_pb'] ?? '') == 'brutto' ? RestaurantVatBasis.brutto : RestaurantVatBasis.netto,
      includeNoTransferFee: qp['no_fee'] != '0',
      leaseMin: decodeLeaseMin(qp['lease_min']),
      features: feats,
      avail: decodeAvail(qp['avail']),
      sellerFilters: sellers,
      sort: decodeSort(qp['sort']),
      page: page < 1 ? 1 : page,
      view: (qp['view'] ?? '').toLowerCase() == 'list' ? TGProductCardLayout.list : TGProductCardLayout.grid,
    );
  }

  bool sameAs(RestaurantQueryState other) => mapEquals(toQuery(), other.toQuery());
}

String encodeSort(RestaurantSort s) => switch (s) {
      RestaurantSort.recommended => 'recommended',
      RestaurantSort.newest => 'newest',
      RestaurantSort.rentLowHigh => 'rent_asc',
      RestaurantSort.rentHighLow => 'rent_desc',
      RestaurantSort.feeLowHigh => 'fee_asc',
      RestaurantSort.feeHighLow => 'fee_desc',
      RestaurantSort.area => 'area',
      RestaurantSort.nearest => 'nearest',
    };

RestaurantSort decodeSort(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'newest' => RestaurantSort.newest,
      'rent_asc' => RestaurantSort.rentLowHigh,
      'rent_desc' => RestaurantSort.rentHighLow,
      'fee_asc' => RestaurantSort.feeLowHigh,
      'fee_desc' => RestaurantSort.feeHighLow,
      'area' => RestaurantSort.area,
      'nearest' => RestaurantSort.nearest,
      _ => RestaurantSort.recommended,
    };

String sortLabel(RestaurantSort s) => switch (s) {
      RestaurantSort.recommended => 'Recommended',
      RestaurantSort.newest => 'Newest',
      RestaurantSort.rentLowHigh => 'Rent low→high',
      RestaurantSort.rentHighLow => 'Rent high→low',
      RestaurantSort.feeLowHigh => 'Transfer fee low→high',
      RestaurantSort.feeHighLow => 'Transfer fee high→low',
      RestaurantSort.area => 'Area',
      RestaurantSort.nearest => 'Nearest',
    };

String encodeFeature(RestaurantFeature f) => switch (f) {
      RestaurantFeature.terrace => 'terrace',
      RestaurantFeature.garden => 'garden',
      RestaurantFeature.playArea => 'play',
      RestaurantFeature.extraction => 'extraction',
      RestaurantFeature.parking => 'parking',
      RestaurantFeature.equipmentList => 'equipment',
      RestaurantFeature.alcoholPermit => 'alcohol',
      RestaurantFeature.takeawayDelivery => 'delivery',
    };

RestaurantFeature? decodeFeature(String raw) => switch (raw.toLowerCase()) {
      'terrace' => RestaurantFeature.terrace,
      'garden' => RestaurantFeature.garden,
      'play' => RestaurantFeature.playArea,
      'extraction' => RestaurantFeature.extraction,
      'parking' => RestaurantFeature.parking,
      'equipment' => RestaurantFeature.equipmentList,
      'alcohol' => RestaurantFeature.alcoholPermit,
      'delivery' => RestaurantFeature.takeawayDelivery,
      _ => null,
    };

String featureLabel(RestaurantFeature f) => switch (f) {
      RestaurantFeature.terrace => 'Terrace',
      RestaurantFeature.garden => 'Garden',
      RestaurantFeature.playArea => 'Play area',
      RestaurantFeature.extraction => 'Extraction system',
      RestaurantFeature.parking => 'Parking',
      RestaurantFeature.equipmentList => 'Equipment list available',
      RestaurantFeature.alcoholPermit => 'Alcohol permit in place',
      RestaurantFeature.takeawayDelivery => 'Takeaway/delivery ready',
    };

String encodeLeaseMin(RestaurantLeaseMin m) => switch (m) {
      RestaurantLeaseMin.any => 'any',
      RestaurantLeaseMin.m12 => '12',
      RestaurantLeaseMin.m24 => '24',
      RestaurantLeaseMin.m36 => '36',
      RestaurantLeaseMin.indefinite => 'indefinite',
    };

RestaurantLeaseMin decodeLeaseMin(String? raw) => switch ((raw ?? '').toLowerCase()) {
      '12' => RestaurantLeaseMin.m12,
      '24' => RestaurantLeaseMin.m24,
      '36' => RestaurantLeaseMin.m36,
      'indefinite' => RestaurantLeaseMin.indefinite,
      _ => RestaurantLeaseMin.any,
    };

String encodeAvail(RestaurantAvailFilter a) => switch (a) {
      RestaurantAvailFilter.any => 'any',
      RestaurantAvailFilter.immediately => 'now',
      RestaurantAvailFilter.within1m => '1m',
      RestaurantAvailFilter.within3m => '3m',
    };

RestaurantAvailFilter decodeAvail(String? raw) => switch ((raw ?? '').toLowerCase()) {
      'now' => RestaurantAvailFilter.immediately,
      '1m' => RestaurantAvailFilter.within1m,
      '3m' => RestaurantAvailFilter.within3m,
      _ => RestaurantAvailFilter.any,
    };
