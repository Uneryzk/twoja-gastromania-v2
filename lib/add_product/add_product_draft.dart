import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum AddProductFulfillment { pickupOnly, shipping, buyerChoice }

enum AddProductPromote { none, days14, days30 }

class AddProductPhoto {
  const AddProductPhoto({required this.id, required this.assetPath, this.error});
  final String id;
  final String assetPath;
  final String? error;
}

/// In-memory listing wizard. Maps onto [TGProduct] plus [TGProduct.extra].
class AddProductDraft extends ChangeNotifier {
  AddProductDraft({required this.auth, String? id}) : id = id ?? 'draft_${DateTime.now().millisecondsSinceEpoch}' {
    priceBasis = auth.sellerType == TGSellerType.store ? TGPriceBasis.netto : TGPriceBasis.brutto;
    sellerType = auth.sellerType;
    companyName = auth.sellerType == TGSellerType.store ? auth.mockDisplayName : '';
  }

  final FakeAuthState auth;
  final String id;

  int step = 0;
  bool dirty = false;
  DateTime? lastSavedAt;
  final Map<String, String> fieldErrors = {};

  // 1 Basic
  TGListingType listingType = TGListingType.buy;
  TGCategory? category;
  String subcategory = '';
  String title = '';
  String description = '';
  String priceText = '';
  TGPriceBasis priceBasis = TGPriceBasis.brutto;
  bool negotiable = false;
  bool askPrice = false;
  String depositText = '';
  String minPeriodText = '';

  // 2 Specs
  TGCondition condition = TGCondition.used;
  String yearText = '';
  String hoursText = '';
  String serviceHistory = '';
  bool originalPackaging = false;
  bool onSiteInspection = false;
  String brand = '';
  String model = '';
  TGPowerType powerType = TGPowerType.electric;
  String powerKwText = '';
  String voltage = '400';
  String phasesText = '3';
  String widthText = '';
  String depthText = '';
  String heightText = '';
  String weightText = '';
  String material = 'AISI 304';
  int warrantyMonths = 0;
  String customWarrantyText = '';
  bool fakturaVat = true;
  AddProductFulfillment fulfillment = AddProductFulfillment.pickupOnly;
  String tempText = '';
  String volumeText = '';
  String programText = '';
  String basketSize = '';

  // 3 Photos
  final List<AddProductPhoto> photos = [];

  // 4 Contact
  TGSellerType sellerType = TGSellerType.private;
  String companyName = '';
  String nip = '';
  String companyAddress = '';
  String contactName = '';
  String phoneDigits = '';
  bool phoneVerified = false;
  String smsCode = '';
  String city = '';
  String voivodeship = '';
  String hoursToCall = '';
  String notifyEmail = '';

  // 5
  AddProductPromote promote = AddProductPromote.none;
  int reviewTab = 0;

  static const brands = ['Bartscher', 'Rational', 'Hobart', 'Winterhalter', 'Convotherm', 'Electrolux', 'Zanussi', 'Metos', 'Other'];

  static const sampleAssets = [
    'assets/images/bartscher_2002170.webp',
    'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
    'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg',
    'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp',
    'assets/images/IMG_20200120_131650.jpg',
  ];

  static const Map<TGCategory, List<String>> subcategories = {
    TGCategory.cookingEquipment: ['Ovens', 'Ranges', 'Fryers', 'Grills'],
    TGCategory.refrigerationEquipment: ['Cabinets', 'Counters', 'Blast chillers'],
    TGCategory.warewashing: ['Undercounter', 'Hood type', 'Flight'],
    TGCategory.foodPreparation: ['Mixers', 'Slicers', 'Vacuum packers'],
    TGCategory.stainlessSteelFurniture: ['Tables', 'Sinks', 'Shelving'],
    TGCategory.barAndBeverageEquipment: ['Espresso', 'Ice machines', 'Draft beer'],
  };

  static const Map<String, String> subcategoryKeys = {
    'Ovens': 'ui_sub_ovens',
    'Ranges': 'ui_sub_ranges',
    'Fryers': 'ui_sub_fryers',
    'Grills': 'ui_sub_grills',
    'Cabinets': 'ui_sub_cabinets',
    'Counters': 'ui_sub_counters',
    'Blast chillers': 'ui_sub_blast',
    'Undercounter': 'ui_sub_undercounter',
    'Hood type': 'ui_sub_hood',
    'Flight': 'ui_sub_flight',
    'Mixers': 'ui_sub_mixers',
    'Slicers': 'ui_sub_slicers',
    'Vacuum packers': 'ui_sub_vacuum',
    'Tables': 'ui_sub_tables',
    'Sinks': 'ui_sub_sinks',
    'Shelving': 'ui_sub_shelving',
    'Espresso': 'ui_sub_espresso',
    'Ice machines': 'ui_sub_ice',
    'Draft beer': 'ui_sub_draft',
  };

  void markDirty() {
    dirty = true;
    notifyListeners();
  }

  void setStep(int value) {
    step = value.clamp(0, 4);
    notifyListeners();
  }

  void markSaved() {
    dirty = false;
    lastSavedAt = DateTime.now();
    notifyListeners();
  }

  void setFieldError(String key, String message) {
    fieldErrors[key] = message;
    notifyListeners();
  }

  int? get pricePln {
    if (askPrice) return null;
    final n = int.tryParse(priceText.replaceAll(RegExp(r'[^0-9]'), ''));
    return n;
  }

  int get counterpartPln {
    final p = pricePln;
    if (p == null) return 0;
    if (priceBasis == TGPriceBasis.netto) {
      return (p * (1 + TGPricing.vatRate)).round();
    }
    return TGPricing.netFromGross(p).round();
  }

  int get promoteFeePln => switch (promote) {
        AddProductPromote.none => 0,
        AddProductPromote.days14 => TGPricing.promote14Pln,
        AddProductPromote.days30 => TGPricing.promote30Pln,
      };

  int get promoteDays => switch (promote) {
        AddProductPromote.none => 0,
        AddProductPromote.days14 => 14,
        AddProductPromote.days30 => 30,
      };

  int get listingFeePln => auth.listingPlan == TGListingPlan.paid ? TGPricing.listingFeePln : 0;

  int get totalPln => listingFeePln + promoteFeePln;

  bool get goesToCheckout => totalPln > 0;

  String get phoneDisplay {
    final d = phoneDigits;
    if (d.length < 9) return d.isEmpty ? '' : '+48 $d';
    return '+48 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
  }

  double get completeness {
    var n = 0;
    var d = 0;
    void bit(bool ok) {
      d++;
      if (ok) n++;
    }

    bit(category != null);
    bit(title.trim().length >= 15);
    bit(description.trim().length >= 50);
    bit(askPrice || (pricePln != null && pricePln! > 0));
    bit(brand.trim().isNotEmpty);
    bit(photos.where((p) => p.error == null).isNotEmpty);
    bit(photos.where((p) => p.error == null).length >= 5);
    bit(contactName.trim().isNotEmpty);
    bit(phoneVerified);
    bit(city.trim().isNotEmpty);
    return d == 0 ? 0 : n / d;
  }

  List<String> get hints {
    final out = <String>[];
    if (title.trim().length < 15) out.add('hint_wizard_title');
    if (photos.isEmpty) out.add('hint_wizard_photos');
    if (category == TGCategory.refrigerationEquipment && tempText.isEmpty) {
      out.add('hint_wizard_temp');
    }
    if (out.isEmpty) out.add('hint_wizard_nameplate');
    return out.take(3).toList();
  }

  bool validateStep(int s) {
    fieldErrors.clear();
    if (s == 4) {
      for (var i = 0; i <= 3; i++) {
        _collectErrors(i);
      }
    } else {
      _collectErrors(s);
    }
    notifyListeners();
    return fieldErrors.isEmpty;
  }

  void _collectErrors(int s) {
    switch (s) {
      case 0:
        if (category == null) fieldErrors['category'] = 'err_wizard_category';
        if (title.trim().length < 15 || title.trim().length > 80) {
          fieldErrors['title'] = 'err_wizard_title_len';
        }
        if (description.trim().length < 50 || description.trim().length > 4000) {
          fieldErrors['description'] = 'err_wizard_description_len';
        }
        if (!askPrice && (pricePln == null || pricePln! <= 0)) {
          fieldErrors['price'] = 'err_wizard_price';
        }
        if (listingType == TGListingType.rent) {
          if (depositText.trim().isEmpty) fieldErrors['deposit'] = 'err_wizard_deposit';
          if (minPeriodText.trim().isEmpty) fieldErrors['minPeriod'] = 'err_wizard_min_period';
        }
      case 1:
        if (brand.trim().isEmpty) fieldErrors['brand'] = 'err_wizard_brand';
        if (condition == TGCondition.used && yearText.trim().isEmpty) {
          fieldErrors['year'] = 'err_wizard_year';
        }
      case 2:
        if (photos.where((p) => p.error == null).isEmpty) {
          fieldErrors['photos'] = 'err_wizard_photos';
        }
      case 3:
        if (sellerType == TGSellerType.store) {
          if (companyName.trim().isEmpty) fieldErrors['company'] = 'err_wizard_company';
          if (!isValidNip(nip)) fieldErrors['nip'] = 'err_wizard_nip';
        }
        if (contactName.trim().isEmpty) fieldErrors['contact'] = 'err_wizard_contact';
        if (phoneDigits.length != 9) fieldErrors['phone'] = 'err_wizard_phone';
        if (!phoneVerified) fieldErrors['sms'] = 'err_wizard_sms';
        if (city.trim().isEmpty || TGGeo.lookup(city) == null) {
          fieldErrors['city'] = 'err_wizard_city';
        }
    }
  }

  String? get firstErrorField => fieldErrors.isEmpty ? null : fieldErrors.keys.first;

  void addSamplePhoto() {
    if (photos.length >= 12) return;
    final asset = sampleAssets[photos.length % sampleAssets.length];
    photos.add(AddProductPhoto(id: 'ph_${DateTime.now().microsecondsSinceEpoch}', assetPath: asset));
    markDirty();
  }

  void addPhotoError(String message) {
    photos.add(AddProductPhoto(id: 'err_${DateTime.now().microsecondsSinceEpoch}', assetPath: '', error: message));
    markDirty();
  }

  AddProductPhoto? removePhoto(String id) {
    final i = photos.indexWhere((p) => p.id == id);
    if (i < 0) return null;
    final removed = photos.removeAt(i);
    markDirty();
    return removed;
  }

  void insertPhoto(int index, AddProductPhoto photo) {
    photos.insert(index.clamp(0, photos.length), photo);
    markDirty();
  }

  void movePhoto(int from, int to) {
    if (from < 0 || from >= photos.length || to < 0 || to >= photos.length) return;
    final item = photos.removeAt(from);
    photos.insert(to, item);
    markDirty();
  }

  TGProduct toProduct({TGListingStatus status = TGListingStatus.draft}) {
    final validPhotos = photos.where((p) => p.error == null && p.assetPath.isNotEmpty).toList();
    final cityHit = TGGeo.lookup(city);
    final warr = warrantyMonths < 0 ? (int.tryParse(customWarrantyText) ?? 0) : warrantyMonths;
    final extra = <String, String>{
      if (subcategory.isNotEmpty) 'Subcategory': subcategory,
      if (brand.isNotEmpty) 'Brand': brand,
      if (model.isNotEmpty) 'Model': model,
      if (yearText.isNotEmpty) 'Year': yearText,
      if (hoursText.isNotEmpty) 'Hours': hoursText,
      if (serviceHistory.isNotEmpty) 'Service history': serviceHistory,
      if (condition == TGCondition.used) 'Original packaging': originalPackaging ? 'Yes' : 'No',
      if (condition == TGCondition.used) 'On-site inspection': onSiteInspection ? 'Yes' : 'No',
      if (powerKwText.isNotEmpty) 'Power': '$powerKwText kW',
      if (voltage.isNotEmpty) 'Voltage': voltage == 'other' ? 'Other' : '$voltage V',
      if (phasesText.isNotEmpty) 'Phases': phasesText,
      if (widthText.isNotEmpty || depthText.isNotEmpty || heightText.isNotEmpty)
        'Dimensions': '${widthText.isEmpty ? '—' : widthText} × ${depthText.isEmpty ? '—' : depthText} × ${heightText.isEmpty ? '—' : heightText} mm',
      if (weightText.isNotEmpty) 'Weight': '$weightText kg',
      if (material.isNotEmpty) 'Material': material,
      'Faktura VAT': fakturaVat ? 'Yes' : 'No',
      if (tempText.isNotEmpty) 'Temperature': '$tempText °C',
      if (volumeText.isNotEmpty) 'Volume': '$volumeText L',
      if (programText.isNotEmpty) 'Program time': '$programText min',
      if (basketSize.isNotEmpty) 'Basket size': basketSize,
      if (depositText.isNotEmpty) 'Deposit': '$depositText PLN',
      if (minPeriodText.isNotEmpty) 'Min. period': '$minPeriodText mies.',
    };

    final sellerName = sellerType == TGSellerType.store
        ? (companyName.trim().isEmpty ? 'Store' : companyName.trim())
        : (contactName.trim().isEmpty ? auth.mockDisplayName : contactName.trim());

    return TGProduct(
      id: id,
      title: title.trim().isEmpty ? 'Untitled listing' : title.trim(),
      price: pricePln,
      priceUnit: listingType == TGListingType.rent ? TGPriceUnit.month : TGPriceUnit.oneTime,
      priceBasis: priceBasis,
      negotiable: negotiable,
      oldPrice: null,
      condition: condition,
      listingType: listingType,
      category: category ?? TGCategory.cookingEquipment,
      powerType: powerType,
      warrantyMonths: warr,
      delivery: fulfillment != AddProductFulfillment.pickupOnly,
      pickup: fulfillment != AddProductFulfillment.shipping,
      seller: TGSeller(
        id: auth.userId,
        name: sellerName,
        type: sellerType,
        verified: auth.storePlan != null,
        rating: 0,
      ),
      city: cityHit?.name ?? city,
      voivodeship: cityHit?.voivodeship ?? voivodeship,
      phone: phoneDisplay.isEmpty ? '+48' : phoneDisplay,
      imageUrl: validPhotos.isNotEmpty ? validPhotos.first.assetPath : '',
      photoCount: validPhotos.length,
      isPromoted: promote != AddProductPromote.none,
      createdAt: DateTime.now(),
      description: description.trim().isEmpty ? null : description.trim(),
      imageUrls: [for (final p in validPhotos) p.assetPath],
      status: status,
      source: TGListingSource.free,
      ownerId: auth.userId,
      extra: extra,
    );
  }
}

bool isValidNip(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return false;
  const w = [6, 5, 7, 2, 3, 4, 5, 6, 7];
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(d[i]) * w[i];
  }
  final check = sum % 11;
  if (check == 10) return false;
  return check == int.parse(d[9]);
}

extension FakeAuthDisplay on FakeAuthState {
  String get mockDisplayName => sellerType == TGSellerType.store ? storePlanLabel : userInitials;
}
