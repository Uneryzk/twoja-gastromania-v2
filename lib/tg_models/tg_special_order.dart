import 'package:flutter/foundation.dart';

enum TGStoreSpecialty {
  worktopsTables,
  extractionHoods,
  barCounters,
  fullFitout,
  coldRooms,
  sinksWashing,
  shelvingStorage,
  laserBending,
  other,
}

enum TGSpecialRequestStatus { draft, held, open, quoted, awarded, closed, expired, rejected }

enum TGSpecialRoutingMode { selected, team, both }

enum TGSpecialContactPref { share, platformOnly }

enum TGSpecialDeadline { asap, oneMonth, threeMonths, flex }

enum TGQuotePriceType { fixed, from, estimate }

enum TGQuoteStatus { submitted, viewed, shortlisted, declined, awarded, lost, withdrawn }

enum TGLeadAccessVia { selected, matched, enterprisePool }

enum TGSoAdminQueue { needsMatching, held, noQuotes, reported, all }

enum TGSoSlaTone { ok, warning, overdue }

@immutable
class TGSoAdminAudit {
  const TGSoAdminAudit({
    required this.id,
    required this.requestId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.at,
    this.reason,
    this.detail,
  });
  final String id;
  final String requestId;
  final String actorId;
  final String actorRole;
  final String action;
  final DateTime at;
  final String? reason;
  final String? detail;
}

@immutable
class TGSoEmailPreview {
  const TGSoEmailPreview({required this.subject, required this.body, this.lang = 'en'});
  final String subject;
  final String body;
  final String lang;
}

@immutable
class TGLeadTimeWeeks {
  const TGLeadTimeWeeks({required this.min, required this.max});
  final int min;
  final int max;
}

@immutable
class TGSpecialFile {
  const TGSpecialFile({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.bytes,
    this.exifStripped = true,
  });
  final String id;
  final String name;
  final String assetPath;
  final int bytes;
  final bool exifStripped;
}

@immutable
class TGLeadAlertSettings {
  const TGLeadAlertSettings({
    this.categories = const {},
    this.regions = const {},
    this.instantEmail = true,
    this.dailyDigest = false,
  });
  final Set<TGStoreSpecialty> categories;
  final Set<String> regions;
  final bool instantEmail;
  final bool dailyDigest;

  TGLeadAlertSettings copyWith({
    Set<TGStoreSpecialty>? categories,
    Set<String>? regions,
    bool? instantEmail,
    bool? dailyDigest,
  }) =>
      TGLeadAlertSettings(
        categories: categories ?? this.categories,
        regions: regions ?? this.regions,
        instantEmail: instantEmail ?? this.instantEmail,
        dailyDigest: dailyDigest ?? this.dailyDigest,
      );
}

@immutable
class TGQuoteTemplate {
  const TGQuoteTemplate({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.priceType,
    required this.leadTimeWeeks,
    required this.warrantyMonths,
    required this.paymentTerms,
    required this.note,
    this.installationIncluded = false,
    this.deliveryIncluded = false,
  });
  final String id;
  final String sellerId;
  final String name;
  final TGQuotePriceType priceType;
  final int leadTimeWeeks;
  final int warrantyMonths;
  final String paymentTerms;
  final String note;
  final bool installationIncluded;
  final bool deliveryIncluded;
}

@immutable
class TGSpecialRequest {
  const TGSpecialRequest({
    required this.id,
    required this.requestNo,
    required this.buyerId,
    required this.buyerName,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.projectTypes,
    required this.title,
    required this.description,
    required this.quantity,
    required this.dimensionsText,
    required this.material,
    required this.finish,
    required this.deadline,
    required this.city,
    required this.voivodeship,
    required this.installationNeeded,
    required this.deliveryNeeded,
    required this.files,
    required this.routingMode,
    required this.selectedSellerIds,
    required this.contactPref,
    required this.consentAt,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.budgetMin,
    this.budgetMax,
    this.quoteLimit = 5,
    this.awardedSellerId,
    this.flags = const [],
    this.nip,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.rejectReason,
    this.closedAt,
    this.teamQueued = false,
    this.assignedTo,
    this.phoneVerified = true,
    this.buyerAccountCreatedAt,
    this.reportedAt,
    this.reporterSellerId,
    this.reportReason,
  });

  final String id;
  final String requestNo;
  final String buyerId;
  final String buyerName;
  final String companyName;
  final String phone;
  final String email;
  final String? nip;
  final List<TGStoreSpecialty> projectTypes;
  final String title;
  final String description;
  final int quantity;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final String dimensionsText;
  final String material;
  final String finish;
  final int? budgetMin;
  final int? budgetMax;
  final TGSpecialDeadline deadline;
  final String city;
  final String voivodeship;
  final bool installationNeeded;
  final bool deliveryNeeded;
  final List<TGSpecialFile> files;
  final TGSpecialRoutingMode routingMode;
  final List<String> selectedSellerIds;
  final TGSpecialContactPref contactPref;
  final DateTime consentAt;
  final TGSpecialRequestStatus status;
  final int quoteLimit;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? awardedSellerId;
  final List<String> flags;
  final String? rejectReason;
  final DateTime? closedAt;
  final bool teamQueued;
  final String? assignedTo;
  final bool phoneVerified;
  final DateTime? buyerAccountCreatedAt;
  final DateTime? reportedAt;
  final String? reporterSellerId;
  final String? reportReason;

  bool get shareContact => contactPref == TGSpecialContactPref.share;

  int daysUntilClose(DateTime now) {
    final d = expiresAt.difference(now).inDays;
    return d < 0 ? 0 : d;
  }

  TGSpecialRequest copyWith({
    String? buyerName,
    String? companyName,
    String? phone,
    String? email,
    String? nip,
    List<TGStoreSpecialty>? projectTypes,
    String? title,
    String? description,
    int? quantity,
    int? widthMm,
    int? depthMm,
    int? heightMm,
    String? dimensionsText,
    String? material,
    String? finish,
    int? budgetMin,
    int? budgetMax,
    bool clearBudget = false,
    TGSpecialDeadline? deadline,
    String? city,
    String? voivodeship,
    bool? installationNeeded,
    bool? deliveryNeeded,
    List<TGSpecialFile>? files,
    TGSpecialRoutingMode? routingMode,
    List<String>? selectedSellerIds,
    TGSpecialContactPref? contactPref,
    DateTime? consentAt,
    TGSpecialRequestStatus? status,
    int? quoteLimit,
    DateTime? expiresAt,
    String? awardedSellerId,
    bool clearAwarded = false,
    List<String>? flags,
    String? rejectReason,
    bool clearReject = false,
    DateTime? closedAt,
    bool clearClosed = false,
    bool? teamQueued,
    String? assignedTo,
    bool clearAssigned = false,
    bool? phoneVerified,
    DateTime? buyerAccountCreatedAt,
    DateTime? reportedAt,
    bool clearReported = false,
    String? reporterSellerId,
    String? reportReason,
  }) =>
      TGSpecialRequest(
        id: id,
        requestNo: requestNo,
        buyerId: buyerId,
        buyerName: buyerName ?? this.buyerName,
        companyName: companyName ?? this.companyName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        nip: nip ?? this.nip,
        projectTypes: projectTypes ?? this.projectTypes,
        title: title ?? this.title,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        widthMm: widthMm ?? this.widthMm,
        depthMm: depthMm ?? this.depthMm,
        heightMm: heightMm ?? this.heightMm,
        dimensionsText: dimensionsText ?? this.dimensionsText,
        material: material ?? this.material,
        finish: finish ?? this.finish,
        budgetMin: clearBudget ? null : (budgetMin ?? this.budgetMin),
        budgetMax: clearBudget ? null : (budgetMax ?? this.budgetMax),
        deadline: deadline ?? this.deadline,
        city: city ?? this.city,
        voivodeship: voivodeship ?? this.voivodeship,
        installationNeeded: installationNeeded ?? this.installationNeeded,
        deliveryNeeded: deliveryNeeded ?? this.deliveryNeeded,
        files: files ?? this.files,
        routingMode: routingMode ?? this.routingMode,
        selectedSellerIds: selectedSellerIds ?? this.selectedSellerIds,
        contactPref: contactPref ?? this.contactPref,
        consentAt: consentAt ?? this.consentAt,
        status: status ?? this.status,
        quoteLimit: quoteLimit ?? this.quoteLimit,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        awardedSellerId: clearAwarded ? null : (awardedSellerId ?? this.awardedSellerId),
        flags: flags ?? this.flags,
        rejectReason: clearReject ? null : (rejectReason ?? this.rejectReason),
        closedAt: clearClosed ? null : (closedAt ?? this.closedAt),
        teamQueued: teamQueued ?? this.teamQueued,
        assignedTo: clearAssigned ? null : (assignedTo ?? this.assignedTo),
        phoneVerified: phoneVerified ?? this.phoneVerified,
        buyerAccountCreatedAt: buyerAccountCreatedAt ?? this.buyerAccountCreatedAt,
        reportedAt: clearReported ? null : (reportedAt ?? this.reportedAt),
        reporterSellerId: clearReported ? null : (reporterSellerId ?? this.reporterSellerId),
        reportReason: clearReported ? null : (reportReason ?? this.reportReason),
      );

  int buyerAccountAgeDays(DateTime now) {
    final created = buyerAccountCreatedAt ?? createdAt.subtract(const Duration(days: 60));
    return now.difference(created).inDays;
  }

  List<String> autoSpamFlags(DateTime now, {bool duplicateText = false, bool duplicateFiles = false}) {
    final out = <String>[...flags];
    if (buyerAccountAgeDays(now) < 7 && !out.contains('new_account')) out.add('new_account');
    if (!phoneVerified && !out.contains('phone_unverified')) out.add('phone_unverified');
    if (duplicateText && !out.contains('duplicate_text')) out.add('duplicate_text');
    if (duplicateFiles && !out.contains('duplicate_files')) out.add('duplicate_files');
    return out;
  }
}

@immutable
class TGQuote {
  const TGQuote({
    required this.id,
    required this.requestId,
    required this.sellerId,
    required this.priceNet,
    required this.priceType,
    required this.leadTimeWeeks,
    required this.validUntil,
    required this.installationIncluded,
    required this.deliveryIncluded,
    required this.warrantyMonths,
    required this.paymentTerms,
    required this.note,
    required this.status,
    required this.createdAt,
    this.vatRate = 23,
    this.attachmentUrl,
    this.isNew = false,
  });

  final String id;
  final String requestId;
  final String sellerId;
  final int priceNet;
  final int vatRate;
  final TGQuotePriceType priceType;
  final int leadTimeWeeks;
  final DateTime validUntil;
  final bool installationIncluded;
  final bool deliveryIncluded;
  final int warrantyMonths;
  final String paymentTerms;
  final String note;
  final String? attachmentUrl;
  final TGQuoteStatus status;
  final DateTime createdAt;
  final bool isNew;

  int get priceGross => (priceNet * (100 + vatRate) / 100).round();

  TGQuote copyWith({
    TGQuoteStatus? status,
    bool? isNew,
    DateTime? validUntil,
  }) =>
      TGQuote(
        id: id,
        requestId: requestId,
        sellerId: sellerId,
        priceNet: priceNet,
        vatRate: vatRate,
        priceType: priceType,
        leadTimeWeeks: leadTimeWeeks,
        validUntil: validUntil ?? this.validUntil,
        installationIncluded: installationIncluded,
        deliveryIncluded: deliveryIncluded,
        warrantyMonths: warrantyMonths,
        paymentTerms: paymentTerms,
        note: note,
        attachmentUrl: attachmentUrl,
        status: status ?? this.status,
        createdAt: createdAt,
        isNew: isNew ?? this.isNew,
      );
}

@immutable
class TGLeadAccess {
  const TGLeadAccess({
    required this.requestId,
    required this.sellerId,
    required this.via,
    required this.viewedAt,
  });

  final String requestId;
  final String sellerId;
  final TGLeadAccessVia via;
  final DateTime? viewedAt;

  TGLeadAccess copyWith({DateTime? viewedAt}) => TGLeadAccess(
        requestId: requestId,
        sellerId: sellerId,
        via: via,
        viewedAt: viewedAt ?? this.viewedAt,
      );
}

String specialtyKey(TGStoreSpecialty s) => switch (s) {
      TGStoreSpecialty.worktopsTables => 'worktops_tables',
      TGStoreSpecialty.extractionHoods => 'extraction_hoods',
      TGStoreSpecialty.barCounters => 'bar_counters',
      TGStoreSpecialty.fullFitout => 'full_fitout',
      TGStoreSpecialty.coldRooms => 'cold_rooms',
      TGStoreSpecialty.sinksWashing => 'sinks_washing',
      TGStoreSpecialty.shelvingStorage => 'shelving_storage',
      TGStoreSpecialty.laserBending => 'laser_bending',
      TGStoreSpecialty.other => 'other',
    };

TGStoreSpecialty? specialtyFromKey(String raw) {
  final k = raw.trim().toLowerCase();
  for (final s in TGStoreSpecialty.values) {
    if (specialtyKey(s) == k || s.name.toLowerCase() == k) return s;
  }
  return null;
}

/// Polish NIP checksum (10 digits).
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
