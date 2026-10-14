import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/standard_member_seeds.dart';

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

  /// Demo / investor presentation cards (Technica, Gastrosilesia, …).
  static const Set<String> demoBestSellerPublicIds = {'2931', '1847', '4102', '5518', '1048'};

  static const Set<int> seedPublicIds = {
    2931, 1847, 4102, 5518, 6120, 6121, 6122, 6123, 1048, 6620, 6621, 7703, 8804, 9901, 8810, 8811, 8812, 8813, 8814,
    8901, 8902, 8903, 8904, 8905, 8906, 8907, 8908, 8909, 8910, 8911, 8912, 8913, 8914, 8915,
    8916, 8917, 8918, 8919, 8920, 8921, 8922, 8923, 8924, 8925, 8926, 8927, 8928, 8929, 8930,
  };

  static const int minBestSellers = 3;

  List<TGStoreProfile> get bestSellers {
    final live = _profiles.where((p) => p.isStore && p.isLive).toList();
    if (TGRevenueConfigService.instance.productionMode) {
      final real = live.where((p) => !seedPublicIds.contains(p.publicId)).toList();
      if (real.length < minBestSellers) return const [];
      return real;
    }
    return live.where((p) => demoBestSellerPublicIds.contains('${p.publicId}')).toList();
  }

  List<TGStoreProfile> get specialOrderManufacturers =>
      _profiles.where((p) => p.isSpecialOrderManufacturer).toList();

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
      coverUrl: 'assets/images/banner-mutfak-ekipmanlari.jpg',
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
      specialties: const [TGStoreSpecialty.fullFitout, TGStoreSpecialty.worktopsTables, TGStoreSpecialty.extractionHoods, TGStoreSpecialty.coldRooms, TGStoreSpecialty.sinksWashing],
      serviceRegions: const ['Śląskie', 'Małopolskie', 'nationwide'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 3, max: 6),
      responseHours: 4,
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
      coverUrl: 'assets/images/food-prep-table.jpg',
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
      coverUrl: 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
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
      specialties: const [TGStoreSpecialty.fullFitout, TGStoreSpecialty.coldRooms, TGStoreSpecialty.barCounters, TGStoreSpecialty.shelvingStorage, TGStoreSpecialty.laserBending],
      serviceRegions: const ['nationwide'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 4, max: 10),
      responseHours: 6,
    ),
    TGStoreProfile(
      publicId: 6120,
      slug: 'inoxline-silesia',
      sellerKey: 'seller_inoxline',
      type: TGSellerType.store,
      name: 'Inoxline Silesia',
      legalName: 'Inoxline Silesia Sp. z o.o.',
      nip: '6348877665',
      nipVerifiedAt: DateTime(2026, 4, 2),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/paslanmaz-raflar.jpeg',
      logoUrl: 'assets/images/GASTROPL.png',
      description: 'Custom stainless worktops, sinks and washing lines fabricated in Gliwice for hotels and ghost kitchens.',
      categories: [TGCategory.stainlessSteelFurniture, TGCategory.warewashing],
      brands: ['Inoxline'],
      services: [TGStoreService.delivery, TGStoreService.installation, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Hutnicza 18, Gliwice',
      city: 'Gliwice',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://inoxline.example',
      memberSince: DateTime(2023, 5, 14),
      rating: 4.2,
      reviewsCount: 14,
      acceptsSpecialOrder: true,
      projects: _projects(5, 'Prep line', 'Gliwice'),
      specialties: const [TGStoreSpecialty.worktopsTables, TGStoreSpecialty.sinksWashing, TGStoreSpecialty.shelvingStorage],
      serviceRegions: const ['Śląskie', 'Opolskie'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 2, max: 5),
      responseHours: 3,
    ),
    TGStoreProfile(
      publicId: 6121,
      slug: 'stalbar-projekt',
      sellerKey: 'seller_stalbar',
      type: TGSellerType.store,
      name: 'Stalbar Projekt',
      legalName: 'Stalbar Projekt Sp. z o.o.',
      nip: '5259988776',
      nipVerifiedAt: DateTime(2026, 3, 22),
      verified: true,
      plan: TGStorePlanKind.enterprise,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
      logoUrl: 'assets/images/PRIMEGASTRO.png',
      description: 'Bar counters, hoods and full stainless fit-outs for multi-unit chains across Poland.',
      categories: [TGCategory.barAndBeverageEquipment, TGCategory.stainlessSteelFurniture, TGCategory.cookingEquipment],
      brands: ['Stalbar'],
      services: TGStoreService.values,
      hours: _kWeek,
      address: 'ul. Barska 7, Kraków',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      phone: phone,
      website: 'https://stalbar.example',
      memberSince: DateTime(2020, 11, 3),
      rating: 4.7,
      reviewsCount: 41,
      acceptsSpecialOrder: true,
      projects: _projects(10, 'Bar counter', 'Kraków'),
      specialties: const [TGStoreSpecialty.barCounters, TGStoreSpecialty.extractionHoods, TGStoreSpecialty.fullFitout, TGStoreSpecialty.laserBending],
      serviceRegions: const ['nationwide'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 5, max: 12),
      responseHours: 8,
    ),
    TGStoreProfile(
      publicId: 6122,
      slug: 'metalgast-katowice',
      sellerKey: 'seller_metalgast',
      type: TGSellerType.store,
      name: 'Metalgast Katowice',
      legalName: 'Metalgast Katowice Sp. z o.o.',
      nip: '6341122334',
      nipVerifiedAt: DateTime(2026, 5, 1),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/food-prep-table.jpg',
      logoUrl: 'assets/images/TECHNICA.png',
      description: 'Laser cutting, bending and cold-room shells for Silesian industrial kitchens.',
      categories: [TGCategory.stainlessSteelFurniture, TGCategory.refrigerationEquipment],
      brands: ['Metalgast'],
      services: [TGStoreService.delivery, TGStoreService.installation, TGStoreService.fakturaVat, TGStoreService.service],
      hours: _kWeek,
      address: 'ul. Stalowa 3, Katowice',
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: phone,
      website: 'https://metalgast.example',
      memberSince: DateTime(2024, 2, 20),
      rating: 4.1,
      reviewsCount: 9,
      acceptsSpecialOrder: true,
      projects: _projects(3, 'Cold room shell', 'Katowice'),
      specialties: const [TGStoreSpecialty.laserBending, TGStoreSpecialty.coldRooms, TGStoreSpecialty.shelvingStorage],
      serviceRegions: const ['Śląskie', 'Dolnośląskie'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 3, max: 7),
      responseHours: 5,
    ),
    TGStoreProfile(
      publicId: 6123,
      slug: 'nordinox-warszawa',
      sellerKey: 'seller_nordinox',
      type: TGSellerType.store,
      name: 'Nordinox Warszawa',
      legalName: 'Nordinox Warszawa Sp. z o.o.',
      nip: '5214455667',
      nipVerifiedAt: DateTime(2026, 4, 18),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/banner-mutfak-ekipmanlari.jpg',
      logoUrl: 'assets/images/RM.png',
      description: 'Warsaw workshop for custom sinks and washing stations. New to Special Order — project gallery coming soon.',
      categories: [TGCategory.warewashing, TGCategory.stainlessSteelFurniture],
      brands: ['Nordinox'],
      services: [TGStoreService.delivery, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Przemysłowa 22, Warszawa',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      phone: phone,
      website: 'https://nordinox.example',
      memberSince: DateTime(2025, 9, 1),
      rating: 4.0,
      reviewsCount: 5,
      acceptsSpecialOrder: true,
      projects: const [],
      specialties: const [TGStoreSpecialty.sinksWashing, TGStoreSpecialty.worktopsTables],
      serviceRegions: const ['Mazowieckie', 'Łódzkie'],
      installation: false,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 2, max: 4),
      responseHours: 12,
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
      coverUrl: 'assets/images/mutfak-ekipmanlari.jpg',
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
      coverUrl: 'assets/images/restaurant-kitchen.jpg',
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
      coverUrl: 'assets/images/food-prep-table.jpg',
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
    TGStoreProfile(
      publicId: 8810,
      slug: 'piotr-w',
      sellerKey: 'seller_font_piotr',
      type: TGSellerType.private,
      name: 'Piotr W.',
      verified: false,
      status: TGStoreStatus.active,
      phone: phone,
      city: 'Łódź',
      voivodeship: 'Łódzkie',
      memberSince: DateTime(2026, 6, 2),
      rating: 4.3,
      reviewsCount: 1,
      description: 'Prywatna sprzedaż używanego sprzętu kuchennego.',
    ),
    TGStoreProfile(
      publicId: 8811,
      slug: 'inoxcorp',
      sellerKey: 'seller_font_inoxcorp',
      type: TGSellerType.store,
      name: 'InoxCorp',
      legalName: 'InoxCorp Sp. z o.o.',
      nip: '7799988776',
      nipVerifiedAt: DateTime(2026, 4, 8),
      verified: true,
      plan: TGStorePlanKind.enterprise,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/paslanmaz-raflar.jpeg',
      logoUrl: 'assets/images/TECHNICA.png',
      description: 'Korporacyjny hurtownik mebli nierdzewnych i stołów roboczych. Faktura VAT, dostawa krajowa.',
      categories: [TGCategory.stainlessSteelFurniture, TGCategory.foodPreparation],
      brands: ['InoxCorp', 'Bartscher'],
      services: [TGStoreService.delivery, TGStoreService.fakturaVat, TGStoreService.installation],
      hours: _kWeek,
      address: 'ul. Głogowska 88, Poznań',
      city: 'Poznań',
      voivodeship: 'Wielkopolskie',
      phone: phone,
      memberSince: DateTime(2023, 1, 15),
      rating: 4.8,
      reviewsCount: 31,
    ),
    TGStoreProfile(
      publicId: 8812,
      slug: 'customkit-atelier',
      sellerKey: 'seller_font_customkit',
      type: TGSellerType.store,
      name: 'CustomKit Atelier',
      legalName: 'CustomKit Atelier Sp. z o.o.',
      nip: '6775544332',
      nipVerifiedAt: DateTime(2026, 5, 1),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/paslanmaz-ekipmanlar.jpg',
      logoUrl: 'assets/images/GASTROPL.png',
      description: 'Zamówienia specjalne: blaty, obudowy i meble ze stali 304 cięte i spawane pod wymiar.',
      categories: [TGCategory.stainlessSteelFurniture, TGCategory.cookingEquipment],
      brands: ['CustomKit'],
      services: [TGStoreService.delivery, TGStoreService.installation, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Zabłocie 20, Kraków',
      city: 'Kraków',
      voivodeship: 'Małopolskie',
      phone: phone,
      memberSince: DateTime(2024, 9, 10),
      rating: 4.7,
      reviewsCount: 18,
      acceptsSpecialOrder: true,
      projects: _projects(3, 'Custom stainless', 'Kraków'),
      specialties: const [TGStoreSpecialty.worktopsTables, TGStoreSpecialty.laserBending, TGStoreSpecialty.fullFitout],
      serviceRegions: const ['Małopolskie', 'Śląskie', 'nationwide'],
      installation: true,
      leadTimeWeeks: const TGLeadTimeWeeks(min: 2, max: 5),
      responseHours: 6,
    ),
    TGStoreProfile(
      publicId: 8813,
      slug: 'rentline-gastro',
      sellerKey: 'seller_font_rentline',
      type: TGSellerType.store,
      name: 'RentLine Gastro',
      legalName: 'RentLine Gastro Sp. z o.o.',
      nip: '8987766554',
      nipVerifiedAt: DateTime(2026, 2, 18),
      verified: true,
      plan: TGStorePlanKind.basic,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/piec-konwekcyjno-parowy.jpeg',
      logoUrl: 'assets/images/PRIMEGASTRO.png',
      description: 'Wynajem pieców, zmywarek i stołów inox na tygodnie i miesiące. Serwis w cenie.',
      categories: [TGCategory.cookingEquipment, TGCategory.warewashing, TGCategory.stainlessSteelFurniture],
      brands: ['Rational', 'Bartscher'],
      services: [TGStoreService.leasing, TGStoreService.delivery, TGStoreService.service, TGStoreService.fakturaVat],
      hours: _kWeek,
      address: 'ul. Grabiszyńska 51, Wrocław',
      city: 'Wrocław',
      voivodeship: 'Dolnośląskie',
      phone: phone,
      memberSince: DateTime(2024, 3, 22),
      rating: 4.5,
      reviewsCount: 14,
    ),
    TGStoreProfile(
      publicId: 8814,
      slug: 'proheat-kitchen',
      sellerKey: 'seller_font_proheat',
      type: TGSellerType.store,
      name: 'ProHeat Kitchen',
      legalName: 'ProHeat Kitchen Sp. z o.o.',
      nip: '5256677889',
      nipVerifiedAt: DateTime(2026, 1, 9),
      verified: true,
      plan: TGStorePlanKind.pro,
      status: TGStoreStatus.active,
      coverUrl: 'assets/images/paslanmaz-raflar.jpeg',
      logoUrl: 'assets/images/Gastrosilesia-pl.png',
      description: 'Sklep Pro: linie wydawcze, szafy przelotowe i meble nierdzewne z montażem.',
      categories: [TGCategory.stainlessSteelFurniture, TGCategory.cookingEquipment, TGCategory.foodPreparation],
      brands: ['ProHeat', 'Metos'],
      services: [TGStoreService.delivery, TGStoreService.installation, TGStoreService.fakturaVat, TGStoreService.warrantyService],
      hours: _kWeek,
      address: 'ul. Grochowska 210, Warszawa',
      city: 'Warszawa',
      voivodeship: 'Mazowieckie',
      phone: phone,
      memberSince: DateTime(2023, 8, 1),
      rating: 4.9,
      reviewsCount: 42,
    ),
    ...buildStandardMemberProfiles(),
  ];
}

List<TGStoreProject> _projects(int count, String title, String city) {
  return [
    for (var i = 0; i < count; i++)
      TGStoreProject(
        title: '$title ${i + 1}',
        city: city,
        year: 2024 - (i % 4),
        photos: TGListingImages.seedGalleryForTheme(
          id: 'project-$city-$i',
          theme: 'restaurant',
          title: title,
          count: 3 + (i % 5),
        ),
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
        imageUrl: TGListingImages.seedCover(id: id, category: cat, title: title),
        imageUrls: TGListingImages.seedGallery(id: id, category: cat, title: title, count: 4),
        photoCount: 4,
        isPromoted: promoted,
        createdAt: now.subtract(Duration(days: int.tryParse(no.substring(6)) ?? 3)),
        description: title,
        status: TGListingStatus.active,
        listingNo: no,
        ownerId: seller.id,
      );

  return [
    item(id: 'gs1', no: '30110001', title: 'Piec konwekcyjny 10 GN – Gastrosilesia', seller: gs, cat: TGCategory.cookingEquipment, price: 18900, promoted: true),
    item(id: 'gs2', no: '30110002', title: 'Szafa chłodnicza 1400L', seller: gs, cat: TGCategory.refrigerationEquipment, price: 6400, promoted: true),
    item(id: 'gs3', no: '30110003', title: 'Stół centralny 2000 mm', seller: gs, cat: TGCategory.stainlessSteelFurniture, price: 2100, condition: TGCondition.newItem),
    item(id: 'gs4', no: '30110004', title: 'Zmywarka kapturowa Hobart', seller: gs, cat: TGCategory.warewashing, price: 9800, promoted: true),
    item(id: 'ek1', no: '30220001', title: 'Zmywarka podszafkowa EK', seller: ek, cat: TGCategory.warewashing, price: 4100, promoted: true),
    item(id: 'ek2', no: '30220002', title: 'Stół roboczy 1500 mm', seller: ek, cat: TGCategory.foodPreparation, price: 980, condition: TGCondition.newItem),
    item(id: 'ek3', no: '30220003', title: 'Krajalnica 300 mm', seller: ek, cat: TGCategory.foodPreparation, price: 1450),
    item(id: 'ek4', no: '30220004', title: 'Wanna bemarowa 2x GN', seller: ek, cat: TGCategory.foodPreparation, price: 890),
    item(id: 'ek5', no: '30220005', title: 'Zmywarka tunelowa – outlet', seller: ek, cat: TGCategory.warewashing, price: 11200),
    item(id: 'rm1', no: '30330001', title: 'Linia Rational iCombi – RM', seller: rm, cat: TGCategory.cookingEquipment, price: 42000, promoted: true, condition: TGCondition.newItem),
    item(id: 'rm2', no: '30330002', title: 'Komora chłodnicza 12 m²', seller: rm, cat: TGCategory.refrigerationEquipment, price: 28500, promoted: true),
  ];
}
