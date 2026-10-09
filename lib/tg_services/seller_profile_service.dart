import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class TGSellerProfileService extends ChangeNotifier {
  TGSellerProfileService._();
  static final TGSellerProfileService instance = TGSellerProfileService._();

  static const String featuredTechnicaPath = '/seller/2931-technica';

  final List<TGStoreProfile> _profiles = List.of(_seedProfiles());
  late final List<TGProduct> extraListings = _seedExtraListings();

  void reset() {
    _profiles
      ..clear()
      ..addAll(_seedProfiles());
    notifyListeners();
  }

  List<TGStoreProfile> get all => List.unmodifiable(_profiles);

  List<TGStoreProfile> get bestSellers => _profiles
      .where((p) => p.isStore && p.isLive && const {'2931', '1847', '4102', '5518', '1048'}.contains('${p.publicId}'))
      .toList();

  TGStoreProfile? resolve(String raw) {
    var token = raw.trim();
    if (token.startsWith('/seller/')) token = token.substring(8);
    if (token.isEmpty) return null;
    final digits = RegExp(r'^(\d+)').firstMatch(token)?.group(1);
    if (digits != null) {
      final id = int.tryParse(digits);
      final byId = _profiles.where((p) => p.publicId == id).firstOrNull;
      if (byId != null) return byId;
    }
    final lower = token.toLowerCase();
    return _profiles.where((p) => p.sellerKey == token || p.slug == lower || p.path.substring(8) == lower).firstOrNull;
  }

  TGStoreProfile? bySellerKey(String sellerKey) => _profiles.where((p) => p.sellerKey == sellerKey).firstOrNull;

  String pathForSellerId(String sellerId) => bySellerKey(sellerId)?.path ?? '/seller/$sellerId';

  TGProduct? listingById(String id) {
    final no = id.replaceAll(RegExp(r'\D'), '');
    for (final p in extraListings) {
      if (p.id == id || p.listingNo == id || (no.length == 8 && p.listingNo == no)) return p;
    }
    return null;
  }

  Future<List<TGProduct>> publicListings(TGStoreProfile profile) async {
    if (!profile.isLive) return const [];
    final catalogue = await TGProductService.instance.getAll();
    final fromCat = catalogue.where((p) => p.seller.id == profile.sellerKey && p.status == TGListingStatus.active && !p.isHidden);
    final extras = extraListings.where((p) => p.seller.id == profile.sellerKey && p.status == TGListingStatus.active && !p.isHidden);
    final seen = <String>{};
    final out = <TGProduct>[];
    for (final p in [...fromCat, ...extras]) {
      if (seen.add(p.id)) out.add(p);
    }
    return out;
  }

  void patch(int publicId, TGStoreProfile Function(TGStoreProfile) fn) {
    final i = _profiles.indexWhere((p) => p.publicId == publicId);
    if (i < 0) return;
    _profiles[i] = fn(_profiles[i]);
    notifyListeners();
  }
}

const _kWeek = TGStoreHours({
  'mon': '08:00-16:00',
  'tue': '08:00-16:00',
  'wed': '08:00-16:00',
  'thu': '08:00-16:00',
  'fri': '08:00-16:00',
  'sat': 'closed',
  'sun': 'closed',
});

List<TGStoreProfile> _seedProfiles() {
  final member = DateTime(2024, 3, 12);
  const phone = '+48 (532) 784-074';
  return [
    TGStoreProfile(
      publicId: 2931,
      slug: 'technica',
      sellerKey: 'seller_technica',
      type: TGSellerType.store,
      name: 'Technica',
      legalName: 'Technica Pro Sp. z o.o.',
      nip: '6345678901',
      nipVerifiedAt: DateTime(2026, 3, 12),
      verified: true,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/blog-26.jpg',
      logoUrl: 'assets/images/TECHNICA.png',
      description: 'Used and refurbished warewashing and cooking lines for Silesian kitchens. We keep a workshop in Gliwice and can arrange pickup the same week.',
      categories: [TGCategory.warewashing, TGCategory.cookingEquipment, TGCategory.foodPreparation],
      brands: ['Hobart', 'Winterhalter', 'Rational'],
      services: [TGStoreService.delivery, TGStoreService.fakturaVat, TGStoreService.warrantyService],
      hours: _kWeek,
      address: 'ul. Pszczyńska 44, Gliwice',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://technica.example',
      social: const TGStoreSocial(facebook: 'https://facebook.com', instagram: 'https://instagram.com'),
      memberSince: member,
      rating: 4.0,
      reviewsCount: 28,
    ),
    TGStoreProfile(
      publicId: 1847,
      slug: 'gastrosilesia',
      sellerKey: 'seller_gastropl',
      type: TGSellerType.store,
      name: 'Gastrosilesia.pl',
      legalName: 'Gastro Silesia Sp. z o.o.',
      nip: '6271112233',
      nipVerifiedAt: DateTime(2026, 2, 2),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
      logoUrl: 'assets/images/Gastrosilesia-pl.png',
      description: 'Turn-key kitchen fit-outs across Śląskie. We source, install and service cooking, refrigeration and stainless furniture for hotels and canteens.',
      categories: [TGCategory.cookingEquipment, TGCategory.refrigerationEquipment, TGCategory.stainlessSteelFurniture, TGCategory.warewashing, TGCategory.barAndBeverageEquipment],
      brands: ['Bartscher', 'Metos', 'Fagor'],
      services: TGStoreService.values,
      hours: _kWeek,
      address: 'ul. Katowicka 12, Chorzów',
      city: 'Chorzów',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://gastrosilesia.example',
      social: const TGStoreSocial(facebook: 'https://facebook.com', linkedin: 'https://linkedin.com', youtube: 'https://youtube.com'),
      memberSince: DateTime(2022, 6, 1),
      rating: 4.5,
      reviewsCount: 24,
      acceptsSpecialOrder: true,
      projects: _projects(8, 'Hotel kitchen', 'Chorzów'),
      managedByAdmin: true,
    ),
    TGStoreProfile(
      publicId: 4102,
      slug: 'ek',
      sellerKey: 'seller_ek',
      type: TGSellerType.store,
      name: 'EK',
      legalName: 'EK Gastro s.c.',
      nip: '6342221100',
      nipVerifiedAt: DateTime(2026, 1, 20),
      verified: true,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/Food_Prepering_table.jpg',
      logoUrl: 'assets/images/Untitled-2_Topaz_Gigapixel_2x_scale.png',
      description: '',
      categories: [TGCategory.warewashing, TGCategory.foodPreparation],
      brands: ['Öztiryakiler', 'Komat'],
      services: [TGStoreService.delivery, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Gliwicka 8, Rybnik',
      city: 'Rybnik',
      voivodeship: 'Śląskie',
      phone: phone,
      memberSince: DateTime(2025, 1, 8),
      rating: 3.5,
      reviewsCount: 10,
    ),
    TGStoreProfile(
      publicId: 5518,
      slug: 'rm',
      sellerKey: 'seller_rm',
      type: TGSellerType.store,
      name: 'RM',
      legalName: 'RM Kitchen Systems Sp. z o.o.',
      nip: '5252341136',
      nipVerifiedAt: DateTime(2026, 3, 1),
      verified: true,
      plan: TGStorePlanKind.enterprise,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/10befb6d92142e17d926d07d605d82d8.jpg',
      logoUrl: 'assets/images/RM.png',
      description: 'Enterprise kitchen systems for chains and institutions. Project desks in Katowice handle layout, installation and a dedicated service SLA.',
      categories: [TGCategory.cookingEquipment, TGCategory.refrigerationEquipment, TGCategory.barAndBeverageEquipment, TGCategory.stainlessSteelFurniture],
      brands: ['Rational', 'Electrolux', 'Hoshizaki'],
      services: TGStoreService.values,
      hours: _kWeek,
      address: 'ul. Warszawska 90, Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://rm.example',
      social: const TGStoreSocial(linkedin: 'https://linkedin.com', instagram: 'https://instagram.com'),
      memberSince: DateTime(2021, 9, 15),
      rating: 4.5,
      reviewsCount: 30,
      acceptsSpecialOrder: true,
      projects: _projects(12, 'Canteen line', 'Katowice'),
    ),
    TGStoreProfile(
      publicId: 1048,
      slug: 'primegastro',
      sellerKey: 'seller_primegastro',
      type: TGSellerType.store,
      name: 'PrimeGastro',
      legalName: 'PrimeGastro Sp. z o.o.',
      nip: '5252341136',
      nipVerifiedAt: DateTime(2026, 3, 12),
      verified: true,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/bartscher_2002170.webp',
      logoUrl: 'assets/images/PRIMEGASTRO.png',
      description: 'Selected combi ovens and refrigeration from our Katowice showroom. Units are tested before collection.',
      categories: [TGCategory.cookingEquipment, TGCategory.refrigerationEquipment],
      brands: ['Bartscher', 'Prime'],
      services: [TGStoreService.delivery, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Korfantego 2, Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://primegastro.example',
      memberSince: DateTime(2023, 11, 4),
      rating: 3.5,
      reviewsCount: 10,
    ),
    TGStoreProfile(
      publicId: 6620,
      slug: 'mateusz-k',
      sellerKey: 'seller_mateusz',
      type: TGSellerType.private,
      name: 'Mateusz K.',
      verified: false,
      status: TGStoreStatus.active,
      phone: phone,
      city: 'Katowice',
      voivodeship: 'Śląskie',
      memberSince: DateTime(2025, 2, 11),
      rating: 4.5,
      reviewsCount: 2,
    ),
    TGStoreProfile(
      publicId: 6621,
      slug: 'anna-p',
      sellerKey: 'seller_anna',
      type: TGSellerType.private,
      name: 'Anna P.',
      verified: true,
      status: TGStoreStatus.active,
      phone: phone,
      city: 'Tychy',
      voivodeship: 'Śląskie',
      memberSince: DateTime(2025, 4, 19),
      rating: 4.5,
      reviewsCount: 4,
      description: '',
    ),
    TGStoreProfile(
      publicId: 7703,
      slug: 'oldkitchen',
      sellerKey: 'seller_oldkitchen',
      type: TGSellerType.store,
      name: 'OldKitchen',
      legalName: 'OldKitchen Sp. z o.o.',
      verified: false,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.inactive,
      coverUrl: 'assets/images/images.jpeg',
      logoUrl: 'assets/images/GASTROPL.png',
      description: 'Temporarily closed for relocation.',
      categories: [TGCategory.cookingEquipment],
      hours: _kWeek,
      address: 'ul. Stawowa 1, Bytom',
      city: 'Bytom',
      voivodeship: 'Śląskie',
      phone: phone,
      memberSince: DateTime(2020, 2, 2),
      rating: 3.0,
      reviewsCount: 7,
    ),
    TGStoreProfile(
      publicId: 8804,
      slug: 'nordgastro',
      sellerKey: 'seller_nordgastro',
      type: TGSellerType.store,
      name: 'NordGastro',
      verified: false,
      status: TGStoreStatus.suspended,
      phone: phone,
      city: 'Gdańsk',
      voivodeship: 'Pomorskie',
      memberSince: DateTime(2024, 8, 8),
      rating: 2.0,
      reviewsCount: 2,
    ),
    TGStoreProfile(
      publicId: 9901,
      slug: 'gastrolab',
      sellerKey: 'seller_gastrolab',
      type: TGSellerType.store,
      name: 'GastroLab',
      legalName: 'GastroLab Sp. z o.o.',
      nip: '6349988776',
      verified: false,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/Food_Prepering_table.jpg',
      logoUrl: 'assets/images/GASTROPL.png',
      description: 'New Gliwice workshop for small-batch refurbishment of warewashers and prep tables.',
      categories: [TGCategory.warewashing, TGCategory.foodPreparation],
      services: [TGStoreService.delivery],
      hours: _kWeek,
      address: 'ul. Portowa 3, Gliwice',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      phone: phone,
      memberSince: DateTime(2026, 8, 20),
      rating: 4.5,
      reviewsCount: 2,
    ),
  ];
}

List<TGStoreProject> _projects(int count, String title, String city) {
  const photos = [
    'assets/images/blog-26.jpg',
    'assets/images/bartscher_2002170.webp',
    'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg',
    'assets/images/IMG_3696-scaled.webp',
    'assets/images/Food_Prepering_table.jpg',
    'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
    'assets/images/image.png',
    'assets/images/10befb6d92142e17d926d07d605d82d8.jpg',
  ];
  return [
    for (var i = 0; i < count; i++)
      TGStoreProject(
        title: '$title ${i + 1}',
        city: city,
        year: 2024 - (i % 4),
        photos: photos.take(3 + (i % 5)).toList(),
        description: 'Reference install $title ${i + 1} in $city. Layout, delivery and commissioning handled by our project desk.',
      ),
  ];
}

List<TGProduct> _seedExtraListings() {
  const phone = '+48 (532) 784-074';
  const gs = TGSeller(id: 'seller_gastropl', name: 'Gastrosilesia.pl', type: TGSellerType.store, verified: true, rating: 4.5);
  const ek = TGSeller(id: 'seller_ek', name: 'EK', type: TGSellerType.store, verified: true, rating: 3.5);
  const rm = TGSeller(id: 'seller_rm', name: 'RM', type: TGSellerType.store, verified: true, rating: 4.5);
  final now = DateTime(2026, 9, 1);
  TGProduct item({
    required String id,
    required String no,
    required String title,
    required TGSeller seller,
    required String image,
    required TGCategory cat,
    int? price,
    bool promoted = false,
    TGCondition condition = TGCondition.used,
  }) =>
      TGProduct(
        id: id,
        title: title,
        price: price,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.netto,
        negotiable: false,
        oldPrice: null,
        condition: condition,
        listingType: TGListingType.buy,
        category: cat,
        powerType: TGPowerType.electric,
        warrantyMonths: 6,
        delivery: true,
        pickup: true,
        seller: seller,
        city: seller.id == 'seller_ek' ? 'Rybnik' : seller.id == 'seller_rm' ? 'Katowice' : 'Chorzów',
        voivodeship: 'Śląskie',
        phone: phone,
        imageUrl: image,
        photoCount: 4,
        isPromoted: promoted,
        createdAt: now.subtract(Duration(days: int.tryParse(no.substring(6)) ?? 3)),
        description: title,
        status: TGListingStatus.active,
        listingNo: no,
        ownerId: seller.id,
      );

  return [
    item(id: 'gs1', no: '30110001', title: 'Piec konwekcyjny 10 GN – Gastrosilesia', seller: gs, image: 'assets/images/bartscher_2002170.webp', cat: TGCategory.cookingEquipment, price: 18900, promoted: true),
    item(id: 'gs2', no: '30110002', title: 'Szafa chłodnicza 1400L', seller: gs, image: 'assets/images/IMG_3696-scaled.webp', cat: TGCategory.refrigerationEquipment, price: 6400, promoted: true),
    item(id: 'gs3', no: '30110003', title: 'Stół centralny 2000 mm', seller: gs, image: 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg', cat: TGCategory.stainlessSteelFurniture, price: 2100, condition: TGCondition.newItem),
    item(id: 'gs4', no: '30110004', title: 'Zmywarka kapturowa Hobart', seller: gs, image: 'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp', cat: TGCategory.warewashing, price: 9800, promoted: true),
    item(id: 'ek1', no: '30220001', title: 'Zmywarka podszafkowa EK', seller: ek, image: 'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp', cat: TGCategory.warewashing, price: 4100, promoted: true),
    item(id: 'ek2', no: '30220002', title: 'Stół roboczy 1500 mm', seller: ek, image: 'assets/images/Food_Prepering_table.jpg', cat: TGCategory.foodPreparation, price: 980, condition: TGCondition.newItem),
    item(id: 'ek3', no: '30220003', title: 'Krajalnica 300 mm', seller: ek, image: 'assets/images/IMG_3696-scaled.webp', cat: TGCategory.foodPreparation, price: 1450),
    item(id: 'ek4', no: '30220004', title: 'Wanna bemarowa 2x GN', seller: ek, image: 'assets/images/pol_pm_Wanna-bemarowa-3X-GN-1-1-Komat-KCB-001-031-2808_2.png', cat: TGCategory.foodPreparation, price: 890),
    item(id: 'ek5', no: '30220005', title: 'Zmywarka tunelowa – outlet', seller: ek, image: 'assets/images/blog-26.jpg', cat: TGCategory.warewashing, price: 11200),
    item(id: 'rm1', no: '30330001', title: 'Linia Rational iCombi – RM', seller: rm, image: 'assets/images/bartscher_2002170.webp', cat: TGCategory.cookingEquipment, price: 42000, promoted: true, condition: TGCondition.newItem),
    item(id: 'rm2', no: '30330002', title: 'Komora chłodnicza 12 m²', seller: rm, image: 'assets/images/IMG_3696-scaled.webp', cat: TGCategory.refrigerationEquipment, price: 28500, promoted: true),
  ];
}
