import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

class TGProductService {
  TGProductService._();
  static final TGProductService instance = TGProductService._();

  /// Bumped when seed image strategy changes (remote Unsplash → local assets).
  static const _storageKey = '__tg_products_v13__';

  List<TGProduct>? _cache;

  /// Sync snapshot when catalogue already loaded (homepage / promo seed).
  static const _kSeedProductIds = {
    'p001', 'p002', 'p003', 'p004', 'p005', 'p006', 'p007', 'p008', 'p009',
    'p010', 'p011', 'p012', 'p013', 'p014', 'p015', 'p016', 'p017', 'p018',
    'p020', 'p021', 'p022', 'p023', 'p024',
  };

  List<TGProduct> _visible(List<TGProduct> all) {
    if (!TGRevenueConfigService.instance.productionMode) return all;
    return [for (final p in all) if (!_kSeedProductIds.contains(p.id)) p];
  }

  List<TGProduct> get cachedAll => List.unmodifiable(_visible(_cache ?? const []));

  TGProduct? cachedByNo(String no) => cachedAll.where((p) => p.listingNo == no).firstOrNull;

  static const Duration _prefsTimeout = Duration(seconds: 2);

  Future<List<TGProduct>> getAll() async {
    if (_cache != null && !(_cache!.isEmpty && !TGRevenueConfigService.instance.productionMode)) {
      return _visible(_cache!);
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        if (TGRevenueConfigService.instance.productionMode) {
          _cache = const [];
          return _cache!;
        }
        final seeded = _seedProducts();
        await _persist(prefs, seeded);
        _cache = seeded;
        return seeded;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Products payload is not a list');

      final products = <TGProduct>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final p = TGProduct.fromJson(item);
            if (p.id.isNotEmpty && p.title.isNotEmpty) products.add(p);
          } catch (e) {
            debugPrint('Skip corrupted product entry: $e');
          }
        }
      }

      if (products.isEmpty) {
        if (TGRevenueConfigService.instance.productionMode) {
          _cache = const [];
          return _cache!;
        }
        final seeded = _seedProducts();
        await _persist(prefs, seeded);
        _cache = seeded;
        return seeded;
      }

      // Sanitize storage if we skipped corrupted entries.
      if (products.length != decoded.length) {
        await _persist(prefs, products);
      }

      _cache = products;
      return _visible(products);
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (TGRevenueConfigService.instance.productionMode) {
        _cache = const [];
        return _cache!;
      }
      final seeded = _seedProducts();
      _cache = seeded;
      return seeded;
    }
  }

  Future<TGProduct?> getById(String id) async {
    final all = await getAll();
    final no = TGListingNo.parseFromPath(id) ?? (TGListingNo.isListingNo(id) ? id : null);
    if (no != null) {
      final byNo = all.where((p) => p.listingNo == no).cast<TGProduct?>().firstOrNull;
      if (byNo != null) return byNo;
    }
    return all.where((p) => p.id == id).cast<TGProduct?>().firstOrNull;
  }

  Future<void> upsert(TGProduct product) async {
    await getAll();
    final all = [...(_cache ?? const <TGProduct>[])];
    final i = all.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      all[i] = product;
    } else {
      all.insert(0, product);
    }
    _cache = all;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await _persist(prefs, all);
    } catch (e) {
      debugPrint('Failed to persist product: $e');
    }
  }

  Future<void> resetToSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final seeded = _seedProducts();
      await _persist(prefs, seeded);
      _cache = seeded;
    } catch (e) {
      debugPrint('Failed to reset products: $e');
    }
  }

  Future<void> _persist(SharedPreferences prefs, List<TGProduct> products) async {
    final encoded = jsonEncode(products.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded).timeout(_prefsTimeout);
  }

  List<TGProduct> _seedProducts() {
    const phone = '+48 (532) 784-074';
    final now = DateTime.now();

    const s1 = TGSeller(id: 'seller_gastropl', name: 'GastroPL Outlet', type: TGSellerType.store, verified: true, rating: 4.7);
    const s2 = TGSeller(id: 'seller_primegastro', name: 'PrimeGastro', type: TGSellerType.store, verified: true, rating: 4.9);
    const s3 = TGSeller(id: 'seller_mateusz', name: 'Mateusz K.', type: TGSellerType.private, verified: false, rating: 4.4);
    const s4 = TGSeller(id: 'seller_technica', name: 'Technica Pro', type: TGSellerType.store, verified: false, rating: 4.2);
    const s5 = TGSeller(id: 'seller_anna', name: 'Anna P.', type: TGSellerType.private, verified: true, rating: 4.6);
    const sFontPrivate = TGSeller(id: 'seller_font_piotr', name: 'Piotr W.', type: TGSellerType.private, verified: false, rating: 4.3);
    const sFontCorp = TGSeller(id: 'seller_font_inoxcorp', name: 'InoxCorp', type: TGSellerType.store, verified: true, rating: 4.8);
    const sFontSo = TGSeller(id: 'seller_font_customkit', name: 'CustomKit Atelier', type: TGSellerType.store, verified: true, rating: 4.7);
    const sFontRent = TGSeller(id: 'seller_font_rentline', name: 'RentLine Gastro', type: TGSellerType.store, verified: true, rating: 4.5);
    const sFontPro = TGSeller(id: 'seller_font_proheat', name: 'ProHeat Kitchen', type: TGSellerType.store, verified: true, rating: 4.9);

    // Requirements mix:
    // - 3 promoted (pickup, shipping, buyer-choice)
    // - most listings pickup-only; 2 shipping; 3 buyer-choice
    // - 4 without price
    // - 3 rent listings
    // - a few discounted (oldPrice)
    // - private + verified sellers
    // - most listings active; p007 sold, p012 expired (PDP states)
    final seeded = [
      TGProduct(
        id: 'p001',
        title: 'Piec konwekcyjno-parowy 10x GN 1/1 – Bartscher',
        price: 12500,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: 14900,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 6,
        delivery: false,
        pickup: true,
        seller: s2,
        city: 'Katowice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.combiOven,
        photoCount: 12,
        isPromoted: true,
        createdAt: now.subtract(const Duration(days: 2)),
        description: 'Serwisowany, gotowy do pracy. W zestawie prowadnice i wąż odpływowy.',
      ),
      TGProduct(
        id: 'p002',
        title: 'Stół ze stali nierdzewnej 180x70 – półka dolna',
        price: 1100,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 24,
        delivery: false,
        pickup: true,
        seller: s1,
        city: 'Rybnik',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.stainless,
        photoCount: 6,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 5)),
        description: 'Nowy stół roboczy – idealny do zaplecza kuchennego. Faktura VAT.',
      ),
      TGProduct(
        id: 'p003',
        title: 'Zmywarka podblatowa z pompą – Öztiryakiler OBY-50T',
        price: 7600,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: 8900,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.warewashing,
        powerType: TGPowerType.electric,
        warrantyMonths: 12,
        delivery: true,
        pickup: false,
        seller: s4,
        city: 'Gliwice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.warewashing,
        photoCount: 9,
        isPromoted: true,
        createdAt: now.subtract(const Duration(days: 1)),
        description: 'Nowa, w kartonie. Programy eco, szybki cykl i automatyczne dozowanie.',
      ),
      TGProduct(
        id: 'p004',
        title: 'Szafa chłodnicza 700L – inox, 3 półki',
        price: 6900,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.refrigerationEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 3,
        delivery: false,
        pickup: true,
        seller: s3,
        city: 'Warszawa',
        voivodeship: 'Mazowieckie',
        phone: phone,
        imageUrl: TGListingImages.fridge700,
        photoCount: 8,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 8)),
        description: 'Sprawna, normalne ślady używania. Odbiór osobisty lub wysyłka.',
      ),
      TGProduct(
        id: 'p005',
        title: 'Bemar 3x GN 1/1 Komat – wanna bemarowa',
        price: 3200,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.foodPreparation,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: true,
        pickup: true,
        seller: s5,
        city: 'Kraków',
        voivodeship: 'Małopolskie',
        phone: phone,
        imageUrl: TGListingImages.bainMarie,
        photoCount: 10,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 14)),
        description: 'Idealny do bufetów. Grzałki OK, stan wizualny dobry.',
      ),
      TGProduct(
        id: 'p006',
        title: 'Ekspres kolbowy 2-grupowy + młynek – zestaw do kawiarni',
        price: 9800,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: true,
        oldPrice: 11500,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.barAndBeverageEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 6,
        delivery: false,
        pickup: true,
        seller: s2,
        city: 'Częstochowa',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.coffeeEspresso,
        photoCount: 16,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 3)),
        description: 'Po przeglądzie. Idealny do startu kawiarni lub food trucka.',
      ),
      TGProduct(
        id: 'p007',
        title: 'Witryna chłodnicza cukiernicza – 120cm, LED',
        price: 4500,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.refrigerationEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s3,
        city: 'Katowice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.beverageFridge,
        photoCount: 7,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 9)),
        description: 'Do lekkiego odświeżenia. Chłodzi poprawnie. Odbiór osobisty.',
      ),
      TGProduct(
        id: 'p008',
        title: 'Kuchnia gazowa 6-palnikowa + piekarnik – stal nierdzewna',
        price: 5400,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.gas,
        warrantyMonths: 3,
        delivery: false,
        pickup: true,
        seller: s1,
        city: 'Gliwice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.mutfakEquip,
        photoCount: 11,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 4)),
        description: 'Sprawdzona, szczelna. W zestawie dysze. Możliwa dostawa.',
      ),
      TGProduct(
        id: 'p009',
        title: 'Wynajem: piec konwekcyjny 6x GN 1/1 – na event',
        price: 1200,
        priceUnit: TGPriceUnit.month,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.rent,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s4,
        city: 'Warszawa',
        voivodeship: 'Mazowieckie',
        phone: phone,
        imageUrl: TGListingImages.combiOven,
        photoCount: 5,
        isPromoted: false,
        createdAt: now.subtract(const Duration(hours: 26)),
        description: 'Wynajem krótkoterminowy możliwy. Transport i montaż w cenie.',
      ),
      TGProduct(
        id: 'p010',
        title: 'Wynajem: agregat chłodniczy + komora – sezon letni',
        price: 1800,
        priceUnit: TGPriceUnit.month,
        priceBasis: TGPriceBasis.netto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.rent,
        category: TGCategory.refrigerationEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s2,
        city: 'Kraków',
        voivodeship: 'Małopolskie',
        phone: phone,
        imageUrl: TGListingImages.freezerVertical,
        photoCount: 9,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 6)),
        description: 'Elastyczne warunki. Idealne dla gastronomii sezonowej.',
      ),
      TGProduct(
        id: 'p011',
        title: 'Wynajem: zmywarka kapturowa – catering / kuchnia tymczasowa',
        price: 1600,
        priceUnit: TGPriceUnit.month,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.rent,
        category: TGCategory.warewashing,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s1,
        city: 'Katowice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.warewashing,
        photoCount: 4,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 11)),
        description: 'Idealna na eventy i kuchnie tymczasowe. Umowa miesięczna.',
      ),
      TGProduct(
        id: 'p012',
        title: 'Blat roboczy 120cm + zlew 1-komorowy – inox',
        price: 900,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s3,
        city: 'Rybnik',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.foodPrep,
        photoCount: 3,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 12)),
        description: 'Zlew + blat. Stan dobry. Odbiór osobisty w Rybniku.',
      ),
      TGProduct(
        id: 'p013',
        title: 'Pakowarka próżniowa komorowa – gastronomia',
        price: 3600,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.foodPreparation,
        powerType: TGPowerType.electric,
        warrantyMonths: 6,
        delivery: true,
        pickup: true,
        seller: s5,
        city: 'Gliwice',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.vacuum,
        photoCount: 9,
        isPromoted: true,
        createdAt: now.subtract(const Duration(hours: 7)),
        description: 'Komora duża, pompa po serwisie. Świetna do produkcji.',
      ),
      TGProduct(
        id: 'p014',
        title: 'Nadstawka chłodnicza na pizzę – 8x pojemnik GN',
        price: 2400,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: 2900,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.refrigerationEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 3,
        delivery: false,
        pickup: true,
        seller: s4,
        city: 'Częstochowa',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.pizzaColdTop,
        photoCount: 6,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 17)),
        description: 'Chłodzi szybko. Idealna do pizzerii i barów.',
      ),
      TGProduct(
        id: 'p015',
        title: 'Stół chłodniczy 3-drzwiowy – gastronomiczny',
        price: 5200,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.refrigerationEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: s2,
        city: 'Warszawa',
        voivodeship: 'Mazowieckie',
        phone: phone,
        imageUrl: TGListingImages.fridge700,
        photoCount: 10,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 13)),
        description: 'Możliwość transportu. Cena do ustalenia po oględzinach.',
      ),
      TGProduct(
        id: 'p016',
        title: 'Okap gastronomiczny z filtrami – 200cm',
        price: 1900,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 12,
        delivery: true,
        pickup: false,
        seller: s1,
        city: 'Rybnik',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.restoKitchen,
        photoCount: 4,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 20)),
        description: 'Nowy, nierdzewny. W zestawie filtry labiryntowe.',
      ),
      TGProduct(
        id: 'p017',
        title: 'Mikser planetarny 20L – 3 końcówki, stal',
        price: 2750,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.foodPreparation,
        powerType: TGPowerType.electric,
        warrantyMonths: 3,
        delivery: false,
        pickup: true,
        seller: s5,
        city: 'Kraków',
        voivodeship: 'Małopolskie',
        phone: phone,
        imageUrl: TGListingImages.mixer,
        photoCount: 8,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 7)),
        description: 'Działa cicho, wymienione łożyska. Idealny do cukierni.',
      ),
      TGProduct(
        id: 'p018',
        title: 'Regał magazynowy inox – 5 półek, 120x50',
        price: 1890,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 24,
        delivery: true,
        pickup: true,
        seller: s4,
        city: 'Częstochowa',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: TGListingImages.shelves,
        photoCount: 5,
        isPromoted: false,
        createdAt: now.subtract(const Duration(days: 10)),
        description: 'Nowy regał w systemie skręcanym. Idealny do magazynu.',
      ),
      // Font-preview pack (Regular titles): 1 private, 1 corporate, 1 special-order, 1 rental, 1 Pro.
      TGProduct(
        id: 'p020',
        title: 'Patelnia uchylna 80 L – elektryczna, stal 304',
        price: 8900,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 3,
        delivery: false,
        pickup: true,
        seller: sFontPrivate,
        city: 'Łódź',
        voivodeship: 'Łódzkie',
        phone: phone,
        imageUrl: TGListingImages.cooking,
        photoCount: 5,
        isPromoted: false,
        createdAt: now.subtract(const Duration(hours: 8)),
        description: 'Prywatna oferta. Sprawna patelnia uchylna do gastronomii, regularny tytuł do testów fontu.',
      ),
      TGProduct(
        id: 'p021',
        title: 'Zestaw stołów nierdzewnych 3×180 cm – faktura VAT',
        price: 6400,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: 7200,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 24,
        delivery: true,
        pickup: true,
        seller: sFontCorp,
        city: 'Poznań',
        voivodeship: 'Wielkopolskie',
        phone: phone,
        imageUrl: TGListingImages.stainless,
        photoCount: 7,
        isPromoted: false,
        createdAt: now.subtract(const Duration(hours: 10)),
        description: 'Korporacyjny zestaw stołów roboczych. Nowe, z atestem stali. Faktura VAT 23%.',
      ),
      TGProduct(
        id: 'p022',
        title: 'Blat roboczy na wymiar – stal 304, spaw TIG',
        price: 4100,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: true,
        oldPrice: null,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 12,
        delivery: true,
        pickup: true,
        seller: sFontSo,
        city: 'Kraków',
        voivodeship: 'Małopolskie',
        phone: phone,
        imageUrl: TGListingImages.paslanmazEquip,
        photoCount: 6,
        isPromoted: true,
        createdAt: now.subtract(const Duration(hours: 6)),
        description: 'Producent zamówień specjalnych. Blat cięty i spawany pod wymiar zaplecza.',
      ),
      TGProduct(
        id: 'p023',
        title: 'Piec konwekcyjny 6× GN 1/1 – wynajem miesięczny',
        price: 890,
        priceUnit: TGPriceUnit.month,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.rent,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: true,
        pickup: true,
        seller: sFontRent,
        city: 'Wrocław',
        voivodeship: 'Dolnośląskie',
        phone: phone,
        imageUrl: TGListingImages.combiOven,
        photoCount: 8,
        isPromoted: true,
        createdAt: now.subtract(const Duration(hours: 4)),
        description: 'Firma wynajmu. Piec serwisowany, kaucja zwrotna, umowa miesięczna.',
      ),
      TGProduct(
        id: 'p024',
        title: 'Szafa przelotowa inox 1400 mm – linia ProHeat',
        price: 9800,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.newItem,
        listingType: TGListingType.buy,
        category: TGCategory.stainlessSteelFurniture,
        powerType: TGPowerType.other,
        warrantyMonths: 24,
        delivery: true,
        pickup: true,
        seller: sFontPro,
        city: 'Warszawa',
        voivodeship: 'Mazowieckie',
        phone: phone,
        imageUrl: TGListingImages.shelves,
        photoCount: 9,
        isPromoted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        description: 'Sklep Pro. Szafa przelotowa do linii wydawczej, montaż na miejscu.',
      ),
    ];
    final numbered = [
      for (final p in seeded)
        p.copyWith(
          // Keep seed cover asset; fill gallery from local gastronomy pool only.
          imageUrls: TGListingImages.galleryWithPrimary(
            primary: p.imageUrl,
            id: p.id,
            category: p.category,
            title: p.title,
            count: p.photoCount.clamp(1, 8),
          ),
          status: switch (p.id) {
            'p007' => TGListingStatus.sold,
            'p012' => TGListingStatus.expired,
            _ => TGListingStatus.active,
          },
          ownerId: p.seller.id,
          publishedAt: switch (p.id) {
            'p012' => now.subtract(const Duration(days: 40)),
            'p007' => now.subtract(const Duration(days: 20)),
            _ => p.createdAt,
          },
          expiresAt: switch (p.id) {
            'p012' => now.subtract(const Duration(days: 10)),
            'p007' => now.add(const Duration(days: 10)),
            _ => p.seller.type == TGSellerType.store
                ? now.add(const Duration(days: 22))
                : p.createdAt.add(Duration(days: TGPricing.listingPeriodDays)),
          },
          source: p.seller.type == TGSellerType.store ? TGListingSource.store : TGListingSource.free,
          promotedUntil: p.isPromoted ? now.add(const Duration(days: 7)) : null,
          listingNo: _seedListingNo(p.id),
        ),
    ];
    TGListingNo.reserveAll(numbered.map((p) => p.listingNo));
    return numbered;
  }
}

String _seedListingNo(String id) => switch (id) {
      'p001' => '10482137',
      'p002' => '11820463',
      'p003' => '12938570',
      'p004' => '13049281',
      'p005' => '14120395',
      'p006' => '15293840',
      'p007' => '16038472',
      'p008' => '17102958',
      'p009' => '18293046',
      'p010' => '19384720',
      'p011' => '20491837',
      'p012' => '21503948',
      'p013' => '22614059',
      'p014' => '23725160',
      'p015' => '24836271',
      'p016' => '25947382',
      'p017' => '26058493',
      'p018' => '27169504',
      'p020' => '28270615',
      'p021' => '29381726',
      'p022' => '30492837',
      'p023' => '31503948',
      'p024' => '32614059',
      _ => TGListingNo.allocate(),
    };

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
