import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGSeller;
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';

/// In-memory wizard draft (no Listing No. until publish).
class RestaurantWizardDraft extends ChangeNotifier {
  RestaurantWizardDraft({required this.ownerId, this.draftId});

  final String ownerId;
  String? draftId;
  int step = 0;
  DateTime? lastSavedAt;
  bool dirty = false;

  // Step 1
  RestaurantPosterRole role = RestaurantPosterRole.owner;
  bool authorized = false;
  String? authDocName;
  RestaurantBusinessType? businessType;
  String title = '';
  String description = '';

  // Step 2
  String city = '';
  String voivodeship = 'Śląskie';
  String district = '';
  String street = '';
  String buildingNo = '';
  String unitNo = '';
  bool noUnit = false;
  double? totalAreaM2;

  // Step 3
  int? rentMonthly;
  RestaurantVatBasis rentBasis = RestaurantVatBasis.netto;
  RestaurantLeaseType leaseType = RestaurantLeaseType.fixed;
  DateTime? leaseEndsAt;
  RestaurantLandlordConsent landlordConsent = RestaurantLandlordConsent.toBeArranged;
  RestaurantTransferFeeKind? feeKind;
  int? feeAmount;
  RestaurantVatBasis feeBasis = RestaurantVatBasis.netto;
  bool negotiable = false;

  // Step 4
  RestaurantEquipmentIncluded equipmentIncluded = RestaurantEquipmentIncluded.partial;
  List<RestaurantInventoryItem> inventory = [];
  List<String> photos = [];
  String? floorPlanUrl;
  List<String> suggestedEquipment = [];

  // Step 5
  String phone = '+48 ';
  bool phoneVerified = false;
  String contactName = '';
  String email = '';
  int promoteDays = 0;

  final Map<String, String> errors = {};

  double get completion {
    var n = 0;
    var d = 12;
    if (authorized) n++;
    if (businessType != null) n++;
    if (title.length >= 15) n++;
    if (description.length >= 50) n++;
    if (city.isNotEmpty) n++;
    if (street.isNotEmpty) n++;
    if (buildingNo.isNotEmpty) n++;
    if (noUnit || unitNo.isNotEmpty) n++;
    if (totalAreaM2 != null && totalAreaM2! > 0) n++;
    if (rentMonthly != null && rentMonthly! > 0) n++;
    if (feeKind != null) n++;
    if (photos.length >= 3) n++;
    return (n / d).clamp(0, 1);
  }

  bool get canUseFree {
    final key = premisesKey;
    return RestaurantLifecycleService.instance.canUseFreeStart(
      ownerId: ownerId,
      premisesKey: key,
      phone: phone,
    );
  }

  String get premisesKey => RestaurantPremisesKey.normalize(
        city: city,
        street: street,
        buildingNo: buildingNo,
        unitNo: noUnit ? null : unitNo,
      );

  RestaurantConfig get cfg => RestaurantConfigService.instance.config;

  int get listingFeePln => canUseFree ? 0 : cfg.paidPricePln;
  int get promoteFeePln => promoteDays == 14
      ? cfg.promote.pln14
      : promoteDays == 30
          ? cfg.promote.pln30
          : 0;
  int get totalPln => listingFeePln + promoteFeePln;
  bool get goesToCheckout => totalPln > 0;

  void touch() {
    dirty = true;
    notifyListeners();
  }

  void markSaved() {
    lastSavedAt = TGClock.now();
    dirty = false;
    notifyListeners();
  }

  bool validateStep(int s) {
    errors.clear();
    switch (s) {
      case 0:
        if (!authorized) errors['auth'] = 'Confirm you are authorized.';
        if (businessType == null) errors['type'] = 'Choose a business type.';
        if (title.trim().length < 15 || title.trim().length > 80) errors['title'] = 'Title must be 15–80 characters.';
        if (description.trim().length < 50 || description.trim().length > 4000) {
          errors['description'] = 'Description must be 50–4000 characters.';
        }
      case 1:
        if (city.trim().isEmpty) errors['city'] = 'City is required.';
        if (street.trim().isEmpty) errors['street'] = 'Street is required.';
        if (buildingNo.trim().isEmpty) errors['building'] = 'Building number is required.';
        if (!noUnit && unitNo.trim().isEmpty) errors['unit'] = 'Unit number or “No unit number”.';
        if (totalAreaM2 == null || totalAreaM2! <= 0) errors['area'] = 'Total area (m²) is required.';
      case 2:
        if (rentMonthly == null || rentMonthly! <= 0) errors['rent'] = 'Monthly rent is required.';
        if (feeKind == null) errors['fee'] = 'Choose Amount or No transfer fee.';
        if (feeKind == RestaurantTransferFeeKind.amount && (feeAmount == null || feeAmount! <= 0)) {
          errors['feeAmount'] = 'Enter the transfer fee amount.';
        }
        if (leaseType == RestaurantLeaseType.fixed && leaseEndsAt == null) {
          errors['leaseEnds'] = 'Lease end date is required for fixed leases.';
        }
      case 3:
        if (photos.length < 3) errors['photos'] = 'At least 3 photos are required (5 recommended).';
      case 4:
        if (!phoneVerified) errors['phone'] = 'Verify your phone number.';
        if (contactName.trim().isEmpty) errors['name'] = 'Name is required.';
        if (email.trim().isEmpty || !email.contains('@')) errors['email'] = 'Valid email is required.';
    }
    notifyListeners();
    return errors.isEmpty;
  }

  /// Scan description for equipment terms → suggestions (never auto-add).
  void scanDescriptionSuggestions() {
    const dict = {
      'fryer': 'Fryer',
      'frytkownica': 'Fryer',
      'combi': 'Combi oven',
      'konwekcyjno': 'Combi oven',
      'dishwasher': 'Dishwasher',
      'zmywarka': 'Dishwasher',
      'espresso': 'Espresso machine',
      'walk-in': 'Walk-in cold room',
      'mixer': 'Mixer',
      'mikser': 'Mixer',
    };
    final lower = description.toLowerCase();
    final found = <String>[];
    for (final e in dict.entries) {
      if (lower.contains(e.key) && !inventory.any((i) => i.name.toLowerCase() == e.value.toLowerCase())) {
        found.add(e.value);
      }
    }
    suggestedEquipment = found;
    notifyListeners();
  }

  void addSuggested(String name) {
    inventory = [
      ...inventory,
      RestaurantInventoryItem(
        id: 'inv_${TGClock.now().microsecondsSinceEpoch}',
        category: RestaurantInventoryCategory.cooking,
        name: name,
        qty: 1,
      ),
    ];
    suggestedEquipment = suggestedEquipment.where((s) => s != name).toList();
    touch();
  }

  void addQuickItem(RestaurantInventoryCategory cat, String name) {
    inventory = [
      ...inventory,
      RestaurantInventoryItem(
        id: 'inv_${TGClock.now().microsecondsSinceEpoch}',
        category: cat,
        name: name,
        qty: 1,
      ),
    ];
    touch();
  }

  void updateInventoryItem(
    String id, {
    int? qty,
    String? brand,
    String? model,
    RestaurantInventoryCondition? condition,
    RestaurantInventoryAvailability? availability,
    List<String>? photos,
    RestaurantInventoryStatus? status,
  }) {
    inventory = [
      for (final i in inventory)
        if (i.id == id)
          i.copyWith(
            qty: qty,
            brand: brand,
            model: model,
            condition: condition,
            availability: availability,
            photos: photos,
            status: status,
            statusChangedAt: status != null ? TGClock.now() : null,
          )
        else
          i,
    ];
    touch();
  }

  void addMockPhotos(int count) {
    final urls = TGListingImages.galleryForTheme(
      id: 'resto-draft-${draftId ?? ownerId}',
      theme: businessType != null ? RestaurantListing.businessTypeSlug(businessType!) : 'restaurant',
      title: title.isEmpty ? 'draft' : title,
      count: count,
    );
    photos = [...photos, ...urls].take(20).toList();
    touch();
  }

  RestaurantListing toListing({
    required TGSeller seller,
    required RestaurantListingStatus status,
  }) {
    final id = draftId ?? 'resto_draft_${TGClock.now().millisecondsSinceEpoch}';
    final fee = feeKind == RestaurantTransferFeeKind.none
        ? const RestaurantTransferFee(kind: RestaurantTransferFeeKind.none)
        : RestaurantTransferFee(kind: RestaurantTransferFeeKind.amount, amountPln: feeAmount, basis: feeBasis);
    return RestaurantListing.create(
      id: id,
      // Listing No. is assigned only when leaving draft (publish / payment).
      listingNo: status == RestaurantListingStatus.draft || status == RestaurantListingStatus.paymentPending
          ? 'D${id.hashCode.abs() % 100000000}'
          : TGListingNo.allocate(),
      status: status,
      isHidden: false,
      publishedAt: null,
      expiresAt: null,
      source: canUseFree ? RestaurantListingSource.freeIntro : RestaurantListingSource.paid,
      ownerId: ownerId,
      posterRole: role,
      authorizationConfirmed: authorized,
      businessType: businessType ?? RestaurantBusinessType.other,
      title: title.trim(),
      description: description.trim(),
      reasonForSale: 'Listed via wizard',
      availableFrom: TGClock.now(),
      city: city.trim(),
      voivodeship: voivodeship.trim(),
      district: district.trim().isEmpty ? null : district.trim(),
      street: street.trim(),
      buildingNo: buildingNo.trim(),
      unitNo: noUnit ? null : unitNo.trim(),
      totalAreaM2: totalAreaM2 ?? 0,
      rentMonthly: rentMonthly ?? 0,
      rentBasis: rentBasis,
      leaseType: leaseType,
      leaseEndsAt: leaseEndsAt,
      landlordConsent: landlordConsent,
      transferFee: fee,
      negotiable: negotiable,
      equipmentIncluded: equipmentIncluded,
      images: photos,
      floorPlanUrl: floorPlanUrl,
      inventory: inventory,
      documents: [
        if (authDocName != null) authDocName!,
      ],
      seller: seller,
      phone: phone.trim(),
    );
  }

  static RestaurantWizardDraft fromListing(RestaurantListing r) {
    final d = RestaurantWizardDraft(ownerId: r.ownerId, draftId: r.id);
    d.role = r.posterRole;
    d.authorized = r.authorizationConfirmed;
    d.businessType = r.businessType;
    d.title = r.title;
    d.description = r.description;
    d.city = r.city;
    d.voivodeship = r.voivodeship;
    d.district = r.district ?? '';
    d.street = r.street;
    d.buildingNo = r.buildingNo;
    d.unitNo = r.unitNo ?? '';
    d.noUnit = r.unitNo == null || r.unitNo!.isEmpty;
    d.totalAreaM2 = r.totalAreaM2;
    d.rentMonthly = r.rentMonthly;
    d.rentBasis = r.rentBasis;
    d.leaseType = r.leaseType;
    d.leaseEndsAt = r.leaseEndsAt;
    d.landlordConsent = r.landlordConsent;
    d.feeKind = r.transferFee.kind;
    d.feeAmount = r.transferFee.amountPln;
    d.feeBasis = r.transferFee.basis;
    d.negotiable = r.negotiable;
    d.equipmentIncluded = r.equipmentIncluded;
    d.inventory = List.of(r.inventory);
    d.photos = List.of(r.images);
    d.floorPlanUrl = r.floorPlanUrl;
    d.phone = r.phone;
    d.phoneVerified = true;
    d.contactName = r.seller.name;
    return d;
  }
}

const kQuickInventory = <RestaurantInventoryCategory, List<String>>{
  RestaurantInventoryCategory.cooking: ['Combi oven', 'Fryer', 'Range'],
  RestaurantInventoryCategory.refrigeration: ['Walk-in cold room', 'Fridge', 'Freezer'],
  RestaurantInventoryCategory.warewashing: ['Dishwasher'],
  RestaurantInventoryCategory.foodPrep: ['Mixer', 'Slicer'],
  RestaurantInventoryCategory.stainlessFurniture: ['Prep tables', 'Shelving'],
  RestaurantInventoryCategory.barBeverage: ['Espresso machine', 'Ice machine'],
  RestaurantInventoryCategory.other: ['Other'],
};
