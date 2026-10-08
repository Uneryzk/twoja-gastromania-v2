import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

const _seller = TGSeller(id: 's1', name: 'Seller', type: TGSellerType.store, verified: false, rating: 4.0);
const _verifiedSeller = TGSeller(id: 's2', name: 'Verified', type: TGSellerType.store, verified: true, rating: 4.9);

TGProduct _p(
  String id, {
  int? price,
  TGPriceBasis basis = TGPriceBasis.netto,
  bool promoted = false,
  String city = 'Katowice',
  String voivodeship = 'Śląskie',
  TGListingType type = TGListingType.buy,
  TGCategory category = TGCategory.cookingEquipment,
  TGCondition condition = TGCondition.used,
  TGSeller seller = _seller,
  int ageDays = 1,
  int warranty = 0,
  bool delivery = false,
  bool pickup = true,
  String title = 'Item',
}) =>
    TGProduct(
      id: id,
      title: '$title $id',
      price: price,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: basis,
      negotiable: false,
      oldPrice: null,
      condition: condition,
      listingType: type,
      category: category,
      powerType: TGPowerType.electric,
      warrantyMonths: warranty,
      delivery: delivery,
      pickup: pickup,
      seller: seller,
      city: city,
      voivodeship: voivodeship,
      phone: '+48 000 000 000',
      imageUrl: '',
      photoCount: 1,
      isPromoted: promoted,
      createdAt: DateTime(2026, 10, 1).subtract(Duration(days: ageDays)),
    );

void main() {
  group('TGProductsQueryState URL round-trip', () {
    test('default state serialises to an empty query', () {
      expect(const TGProductsQueryState().toQuery(), isEmpty);
      expect(const TGProductsQueryState().toLocation(), '/products');
    });

    test('every field survives toQuery -> fromQuery', () {
      const original = TGProductsQueryState(
        listingType: TGListingType.rent,
        verifiedOnly: true,
        conditions: {TGCondition.newItem, TGCondition.used},
        categories: {TGCategory.refrigerationEquipment, TGCategory.barAndBeverageEquipment},
        minPrice: 500,
        maxPrice: 9000,
        includeNoPrice: false,
        priceFilterBasis: TGPriceFilterBasis.brutto,
        city: 'Kraków',
        radiusKm: 50,
        voivodeships: {'Śląskie', 'Małopolskie'},
        powerTypes: {TGPowerType.gas},
        delivery: true,
        pickup: true,
        warrantyMinMonths: 12,
        sellerTypes: {TGSellerType.private},
        brand: 'Bartscher',
        search: 'piec konwekcyjny',
        sort: TGProductsSort.priceHighLow,
        page: 3,
        view: TGProductCardLayout.list,
      );
      final parsed = TGProductsQueryState.fromQuery(original.toQuery());
      expect(parsed.sameAs(original), isTrue);
      // Casing must be preserved (used to be lower-cased, which broke chip selection).
      expect(parsed.voivodeships, {'Śląskie', 'Małopolskie'});
      expect(parsed.city, 'Kraków');
      expect(parsed.view, TGProductCardLayout.list);
    });

    test('sort, page and view are not counted as filters', () {
      const s = TGProductsQueryState(sort: TGProductsSort.newest, page: 4, view: TGProductCardLayout.list);
      expect(s.activeFilterCount, 0);
    });

    test('home page deep links parse as expected', () {
      final buy = TGProductsQueryState.fromQuery({'type': 'buy'});
      expect(buy.listingType, TGListingType.buy);
      final cat = TGProductsQueryState.fromQuery({'cat': encodeCategory(TGCategory.warewashing)});
      expect(cat.categories, {TGCategory.warewashing});
    });

    test('garbage query values degrade to defaults instead of throwing', () {
      final s = TGProductsQueryState.fromQuery({'type': 'x', 'min': 'abc', 'page': '-5', 'sort': '??', 'cat': 'nope,cooking'});
      expect(s.listingType, isNull);
      expect(s.minPrice, isNull);
      expect(s.page, 1);
      expect(s.sort, TGProductsSort.recommended);
      expect(s.categories, {TGCategory.cookingEquipment});
    });

    test('clearedFilters keeps sort and view', () {
      const s = TGProductsQueryState(verifiedOnly: true, sort: TGProductsSort.newest, view: TGProductCardLayout.list);
      final c = s.clearedFilters();
      expect(c.verifiedOnly, isFalse);
      expect(c.sort, TGProductsSort.newest);
      expect(c.view, TGProductCardLayout.list);
    });
  });

  group('filters', () {
    final products = [
      _p('a', price: 1000, type: TGListingType.buy, condition: TGCondition.newItem),
      _p('b', price: 2000, type: TGListingType.rent, seller: _verifiedSeller),
      _p('c', price: 1230, basis: TGPriceBasis.brutto), // net 1000
      _p('d', price: null),
      _p('e', price: 9000, category: TGCategory.warewashing, city: 'Warszawa', voivodeship: 'Mazowieckie'),
    ];

    List<String> ids(TGProductsQueryState q) => applyFilters(products, q).map((p) => p.id).toList()..sort();

    test('listing type', () {
      expect(ids(const TGProductsQueryState(listingType: TGListingType.rent)), ['b']);
      expect(ids(const TGProductsQueryState(listingType: TGListingType.buy)), ['a', 'c', 'd', 'e']);
      expect(ids(const TGProductsQueryState()), ['a', 'b', 'c', 'd', 'e']);
    });

    test('verified sellers only', () {
      expect(ids(const TGProductsQueryState(verifiedOnly: true)), ['b']);
    });

    test('condition and category', () {
      expect(ids(const TGProductsQueryState(conditions: {TGCondition.newItem})), ['a']);
      expect(ids(const TGProductsQueryState(categories: {TGCategory.warewashing})), ['e']);
    });

    test('price compares on a net basis (brutto 1230 == netto 1000)', () {
      final net = ids(const TGProductsQueryState(minPrice: 900, maxPrice: 1100, includeNoPrice: false));
      expect(net, ['a', 'c']);
      // Same range expressed as brutto: 1107..1353 gross == 900..1100 net.
      final gross = ids(const TGProductsQueryState(
        minPrice: 1107,
        maxPrice: 1353,
        includeNoPrice: false,
        priceFilterBasis: TGPriceFilterBasis.brutto,
      ));
      expect(gross, ['a', 'c']);
    });

    test('listings without price follow includeNoPrice', () {
      expect(ids(const TGProductsQueryState(maxPrice: 5000)).contains('d'), isTrue);
      expect(ids(const TGProductsQueryState(maxPrice: 5000, includeNoPrice: false)).contains('d'), isFalse);
    });

    test('voivodeship matches regardless of case/diacritics', () {
      expect(ids(const TGProductsQueryState(voivodeships: {'mazowieckie'})), ['e']);
      expect(ids(const TGProductsQueryState(voivodeships: {'SLASKIE'})), ['a', 'b', 'c', 'd']);
    });
  });

  group('pickup vs delivery', () {
    final products = [
      _p('both', delivery: true, pickup: true),
      _p('pickupOnly', delivery: false, pickup: true),
      _p('shipOnly', delivery: true, pickup: false),
    ];

    List<String> ids(TGProductsQueryState q) => applyFilters(products, q).map((p) => p.id).toList()..sort();

    test('pickup filter is independent of delivery', () {
      expect(ids(const TGProductsQueryState(pickup: true)), ['both', 'pickupOnly']);
      expect(ids(const TGProductsQueryState(pickup: false)), ['shipOnly']);
      expect(ids(const TGProductsQueryState(delivery: true)), ['both', 'shipOnly']);
      expect(ids(const TGProductsQueryState(delivery: true, pickup: true)), ['both']);
    });
  });

  group('location autocomplete + radius', () {
    // Straight-line distances from Katowice: Gliwice ~25.3 km, Rybnik ~38.8 km,
    // Częstochowa ~59.5 km, Kraków ~69.3 km, Warszawa ~253 km.
    final products = [
      _p('katowice', city: 'Katowice'),
      _p('gliwice', city: 'Gliwice'),
      _p('rybnik', city: 'Rybnik'),
      _p('czestochowa', city: 'Częstochowa'),
      _p('krakow', city: 'Kraków', voivodeship: 'Małopolskie'),
      _p('warszawa', city: 'Warszawa', voivodeship: 'Mazowieckie'),
    ];

    Set<String> ids(TGProductsQueryState q) => applyFilters(products, q).map((p) => p.id).toSet();

    test('radius 0 is an exact city match (diacritics/case insensitive)', () {
      expect(ids(const TGProductsQueryState(city: 'katowice')), {'katowice'});
      expect(ids(const TGProductsQueryState(city: 'KRAKOW')), {'krakow'});
    });

    test('radius widens the search using real distances', () {
      expect(ids(const TGProductsQueryState(city: 'Katowice', radiusKm: 10)), {'katowice'});
      // 25 km is just short of Gliwice (25.3 km straight-line).
      expect(ids(const TGProductsQueryState(city: 'Katowice', radiusKm: 25)), {'katowice'});
      expect(ids(const TGProductsQueryState(city: 'Katowice', radiusKm: 30)), {'katowice', 'gliwice'});
      expect(ids(const TGProductsQueryState(city: 'Katowice', radiusKm: 50)), {'katowice', 'gliwice', 'rybnik'});
      expect(ids(const TGProductsQueryState(city: 'Katowice', radiusKm: 100)),
          {'katowice', 'gliwice', 'rybnik', 'czestochowa', 'krakow'});
    });

    test('a city without listings still works as a search centre', () {
      // Zabrze has no listings but Gliwice is ~12 km away.
      expect(ids(const TGProductsQueryState(city: 'Zabrze', radiusKm: 25)), contains('gliwice'));
    });

    test('unknown city falls back to exact match', () {
      expect(ids(const TGProductsQueryState(city: 'Nowhereville', radiusKm: 100)), isEmpty);
    });

    test('haversine sanity: Warszawa-Kraków ~252 km', () {
      final d = TGGeo.distanceBetween('Warszawa', 'Kraków')!;
      expect(d, inInclusiveRange(245, 260));
    });

    test('"nearest" sort orders by distance to the selected city', () {
      final sorted = sortProducts(products, const TGProductsQueryState(city: 'Katowice', radiusKm: 300, sort: TGProductsSort.nearest));
      expect(sorted.map((p) => p.id).take(3).toList(), ['katowice', 'gliwice', 'rybnik']);
      expect(sorted.last.id, 'warszawa');
    });
  });

  group('promoted listings are sticky regardless of sorting', () {
    final products = [
      _p('promo1', price: 99999, promoted: true, ageDays: 40),
      _p('promo2', price: 1, promoted: true, ageDays: 30),
      _p('promo3', price: 50000, promoted: true, ageDays: 20),
      _p('promo4', price: 5, promoted: true, ageDays: 10), // 4th promoted: not pinned
      for (var i = 0; i < 12; i++) _p('org$i', price: 100 + i * 37, ageDays: i, warranty: i),
    ];

    for (final sort in TGProductsSort.values) {
      test('sort=${sort.name}: same promoted block, nothing else leaks in', () {
        final base = computeResults(products, const TGProductsQueryState(), promotedSeed: 7);
        final r = computeResults(products, TGProductsQueryState(sort: sort), promotedSeed: 7);

        expect(r.promoted, hasLength(kPromotedSlots));
        expect(r.promoted.every((p) => p.isPromoted), isTrue);
        // Identical block and identical order for every sort option.
        expect(r.promoted.map((p) => p.id).toList(), base.promoted.map((p) => p.id).toList());
        // Pinned items never also appear in the organic list.
        final pinned = r.promoted.map((p) => p.id).toSet();
        expect(r.organic.any((p) => pinned.contains(p.id)), isFalse);
        // Nothing is lost.
        expect(r.total, products.length);
      });
    }

    test('price low->high really sorts the organic list ascending', () {
      final r = computeResults(products, const TGProductsQueryState(sort: TGProductsSort.priceLowHigh), promotedSeed: 1);
      final prices = r.organic.map((p) => productPriceNet(p)!).toList();
      expect(prices, [...prices]..sort());
    });

    test('a promoted listing that violates the filters is excluded', () {
      final r = computeResults(
        [_p('promoRent', promoted: true, type: TGListingType.rent), _p('plain', type: TGListingType.buy)],
        const TGProductsQueryState(listingType: TGListingType.buy),
        promotedSeed: 1,
      );
      expect(r.promoted, isEmpty);
      expect(r.organic.map((p) => p.id), ['plain']);
    });

    test('listings without price are always last for price sorts', () {
      final list = [_p('x', price: null), _p('y', price: 10), _p('z', price: 5)];
      expect(sortProducts(list, const TGProductsQueryState(sort: TGProductsSort.priceLowHigh)).map((p) => p.id), ['z', 'y', 'x']);
      expect(sortProducts(list, const TGProductsQueryState(sort: TGProductsSort.priceHighLow)).map((p) => p.id), ['y', 'z', 'x']);
    });

    test('total count equals what the mobile sheet counter reports', () {
      const q = TGProductsQueryState(verifiedOnly: false, maxPrice: 400);
      expect(computeResults(products, q, promotedSeed: 3).total, countResults(products, q));
    });
  });

  group('seeded catalogue', () {
    setUpAll(() => SharedPreferences.setMockInitialValues({}));

    test('has promoted listings and every sort keeps the same top block', () async {
      final all = await TGProductService.instance.getAll();
      final blocks = <String>{};
      for (final sort in TGProductsSort.values) {
        final r = computeResults(all, TGProductsQueryState(sort: sort), promotedSeed: 11);
        expect(r.promoted, isNotEmpty);
        blocks.add(r.promoted.map((p) => p.id).join(','));
      }
      expect(blocks, hasLength(1));
    });

    test('most seeded listings offer in-person pickup', () async {
      final all = await TGProductService.instance.getAll();
      expect(all, hasLength(18));
      expect(all.where((p) => p.pickup).length, greaterThanOrEqualTo(16));
      expect(all.any((p) => p.delivery && !p.pickup), isTrue);
      expect(all.any((p) => p.pickup && !p.delivery), isTrue);
    });
  });

  group('pricing constants (business rules)', () {
    test('freemium + listing fee + store plans', () {
      expect(TGPricing.freeListingQuota, 3);
      expect(TGPricing.freePeriodDays, 30);
      expect(TGPricing.listingFeePln, 49);
      expect(TGPricing.listingPeriodDays, 30);
      expect(TGPricing.storePlans.map((p) => '${p.name}:${p.monthlyPricePln}').toList(), ['Basic:199', 'Pro:499', 'Enterprise:899']);
    });

    test('VAT: 23% is included in gross prices', () {
      expect(TGPricing.netFromGross(123), closeTo(100, 1e-9));
      expect(TGPricing.vatFromGross(123), closeTo(23, 1e-9));
    });
  });

  test('pagination', () {
    final items = List.generate(10, (i) => i);
    expect(paginate(items, 1, perPage: 4), [0, 1, 2, 3]);
    expect(paginate(items, 3, perPage: 4), [8, 9]);
    expect(paginate(items, 9, perPage: 4), isEmpty);
    expect(pageCount(10, 4), 3);
    expect(pageCount(0, 4), 1);
  });
}
