import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

enum TGRevenuePhase { phase0, phase1, phase2 }

enum TGPriorityStatus { none, active, waitlist, cancelled }

enum TGPrioritySource { addon, enterprise, founderFree }

enum TGPriorityBillingPeriod { monthly, sixMonths, yearly }

@immutable
class TGRevenueFlags {
  const TGRevenueFlags({
    this.priorityForSale = false,
    this.marketInsight = false,
    this.bulkBilling = false,
    this.sponsorSlots = false,
    this.auditProgram = false,
    this.founderProgram = false,
    this.bannerAds = false,
  });

  final bool priorityForSale;
  final bool marketInsight;
  final bool bulkBilling;
  final bool sponsorSlots;
  final bool auditProgram;
  final bool founderProgram;
  /// Homepage hero AdSlot purchase (RESTO-5). Phase 2 only.
  final bool bannerAds;

  TGRevenueFlags copyWith({
    bool? priorityForSale,
    bool? marketInsight,
    bool? bulkBilling,
    bool? sponsorSlots,
    bool? auditProgram,
    bool? founderProgram,
    bool? bannerAds,
  }) =>
      TGRevenueFlags(
        priorityForSale: priorityForSale ?? this.priorityForSale,
        marketInsight: marketInsight ?? this.marketInsight,
        bulkBilling: bulkBilling ?? this.bulkBilling,
        sponsorSlots: sponsorSlots ?? this.sponsorSlots,
        auditProgram: auditProgram ?? this.auditProgram,
        founderProgram: founderProgram ?? this.founderProgram,
        bannerAds: bannerAds ?? this.bannerAds,
      );

  static TGRevenueFlags forPhase(int phase) => switch (phase) {
        0 => const TGRevenueFlags(),
        1 => const TGRevenueFlags(priorityForSale: true, marketInsight: true, founderProgram: true),
        _ => const TGRevenueFlags(
            priorityForSale: true,
            marketInsight: true,
            founderProgram: true,
            bulkBilling: true,
            sponsorSlots: true,
            auditProgram: true,
            bannerAds: true,
          ),
      };
}

@immutable
class TGBannerAdsConfig {
  const TGBannerAdsConfig({
    this.adSlotPln14 = 299,
    this.enterpriseIncludedSlidesPerMonth = 1,
    this.maxLiveHeroSlides = 3,
  });
  final int adSlotPln14;
  final int enterpriseIncludedSlidesPerMonth;
  final int maxLiveHeroSlides;

  TGBannerAdsConfig copyWith({
    int? adSlotPln14,
    int? enterpriseIncludedSlidesPerMonth,
    int? maxLiveHeroSlides,
  }) =>
      TGBannerAdsConfig(
        adSlotPln14: adSlotPln14 ?? this.adSlotPln14,
        enterpriseIncludedSlidesPerMonth: enterpriseIncludedSlidesPerMonth ?? this.enterpriseIncludedSlidesPerMonth,
        maxLiveHeroSlides: maxLiveHeroSlides ?? this.maxLiveHeroSlides,
      );
}

@immutable
class TGPriorityGate {
  const TGPriorityGate({
    this.minRequests30d = 5,
    this.openRegions = const ['Śląskie'],
  });
  final int minRequests30d;
  final List<String> openRegions;

  TGPriorityGate copyWith({int? minRequests30d, List<String>? openRegions}) => TGPriorityGate(
        minRequests30d: minRequests30d ?? this.minRequests30d,
        openRegions: openRegions ?? this.openRegions,
      );
}

@immutable
class TGPriorityBulk {
  const TGPriorityBulk({this.sixMonthDiscount = 0.10, this.yearlyFreeMonths = 2});
  final double sixMonthDiscount;
  final int yearlyFreeMonths;
}

@immutable
class TGPriorityConfig {
  const TGPriorityConfig({
    this.priceMonthly = 349,
    this.capPerSegment = 8,
    this.waitlist = true,
    this.gate = const TGPriorityGate(),
    this.bulk = const TGPriorityBulk(),
  });
  final int priceMonthly;
  final int capPerSegment;
  final bool waitlist;
  final TGPriorityGate gate;
  final TGPriorityBulk bulk;

  TGPriorityConfig copyWith({
    int? priceMonthly,
    int? capPerSegment,
    bool? waitlist,
    TGPriorityGate? gate,
    TGPriorityBulk? bulk,
  }) =>
      TGPriorityConfig(
        priceMonthly: priceMonthly ?? this.priceMonthly,
        capPerSegment: capPerSegment ?? this.capPerSegment,
        waitlist: waitlist ?? this.waitlist,
        gate: gate ?? this.gate,
        bulk: bulk ?? this.bulk,
      );
}

@immutable
class TGWaveConfig {
  const TGWaveConfig({
    this.delayHours = 24,
    this.delayHoursAsap = 4,
    this.poolQuoteCap = 3,
    this.priorityWindowPoolCap = 2,
  });
  final int delayHours;
  final int delayHoursAsap;
  final int poolQuoteCap;
  final int priorityWindowPoolCap;

  TGWaveConfig copyWith({
    int? delayHours,
    int? delayHoursAsap,
    int? poolQuoteCap,
    int? priorityWindowPoolCap,
  }) =>
      TGWaveConfig(
        delayHours: delayHours ?? this.delayHours,
        delayHoursAsap: delayHoursAsap ?? this.delayHoursAsap,
        poolQuoteCap: poolQuoteCap ?? this.poolQuoteCap,
        priorityWindowPoolCap: priorityWindowPoolCap ?? this.priorityWindowPoolCap,
      );
}

@immutable
class TGFounderTierRule {
  const TGFounderTierRule({required this.qualified, required this.discount});
  final int qualified;
  final double discount;
}

@immutable
class TGFounderConfig {
  const TGFounderConfig({
    this.quota = 20,
    this.counterMinReal = 5,
    this.programMonths = 6,
    this.freeMonths = 2,
    this.tiers = const [
      TGFounderTierRule(qualified: 5, discount: 0.20),
      TGFounderTierRule(qualified: 10, discount: 0.40),
    ],
    this.freeBoostCreditAt5 = false,
    this.planOffer,
  });

  final int quota;
  final int counterMinReal;
  final int programMonths;
  final int freeMonths;
  final List<TGFounderTierRule> tiers;
  final bool freeBoostCreditAt5;
  /// Optional time-limited plan offer id; null = none.
  final String? planOffer;

  TGFounderConfig copyWith({
    int? quota,
    int? counterMinReal,
    int? programMonths,
    int? freeMonths,
    List<TGFounderTierRule>? tiers,
    bool? freeBoostCreditAt5,
    String? planOffer,
    bool clearPlanOffer = false,
  }) =>
      TGFounderConfig(
        quota: quota ?? this.quota,
        counterMinReal: counterMinReal ?? this.counterMinReal,
        programMonths: programMonths ?? this.programMonths,
        freeMonths: freeMonths ?? this.freeMonths,
        tiers: tiers ?? this.tiers,
        freeBoostCreditAt5: freeBoostCreditAt5 ?? this.freeBoostCreditAt5,
        planOffer: clearPlanOffer ? null : (planOffer ?? this.planOffer),
      );

  double discountForQualified(int count) {
    var best = 0.0;
    for (final t in tiers) {
      if (count >= t.qualified && t.discount > best) best = t.discount;
    }
    return best;
  }

  int tierForQualified(int count) {
    var tier = 0;
    for (var i = 0; i < tiers.length; i++) {
      if (count >= tiers[i].qualified) tier = i + 1;
    }
    return tier;
  }
}

enum TGFounderApplicationStatus { applied, approved, rejected, waitlisted }

enum TGFounderDiscountItem { promote14, promote30, priority, sponsorSlot }

@immutable
class TGSellerFounder {
  const TGSellerFounder({
    this.enrolled = false,
    this.enrolledAt,
    this.programEndsAt,
    this.nip,
    this.freeUntil,
    this.qualifiedCount = 0,
    this.tier = 0,
    this.tierComputedAt,
    this.freeBoostCreditGranted = false,
  });

  final bool enrolled;
  final DateTime? enrolledAt;
  final DateTime? programEndsAt;
  final String? nip;
  final DateTime? freeUntil;
  final int qualifiedCount;
  final int tier;
  final DateTime? tierComputedAt;
  final bool freeBoostCreditGranted;

  bool isInProgram(DateTime now) => enrolled && programEndsAt != null && now.isBefore(programEndsAt!);
  bool isInFreeMonths(DateTime now) => isInProgram(now) && freeUntil != null && now.isBefore(freeUntil!);
  /// Tier discount only after free months end (consecutive, not overlapping).
  bool discountActive(DateTime now) => isInProgram(now) && !isInFreeMonths(now);

  TGSellerFounder copyWith({
    bool? enrolled,
    DateTime? enrolledAt,
    DateTime? programEndsAt,
    String? nip,
    DateTime? freeUntil,
    int? qualifiedCount,
    int? tier,
    DateTime? tierComputedAt,
    bool? freeBoostCreditGranted,
  }) =>
      TGSellerFounder(
        enrolled: enrolled ?? this.enrolled,
        enrolledAt: enrolledAt ?? this.enrolledAt,
        programEndsAt: programEndsAt ?? this.programEndsAt,
        nip: nip ?? this.nip,
        freeUntil: freeUntil ?? this.freeUntil,
        qualifiedCount: qualifiedCount ?? this.qualifiedCount,
        tier: tier ?? this.tier,
        tierComputedAt: tierComputedAt ?? this.tierComputedAt,
        freeBoostCreditGranted: freeBoostCreditGranted ?? this.freeBoostCreditGranted,
      );
}

@immutable
class TGFounderApplication {
  const TGFounderApplication({
    required this.id,
    required this.sellerId,
    required this.nip,
    required this.status,
    required this.profileCompletePct,
    required this.referenceProjectsCount,
    required this.feedbackCallDone,
    required this.createdAt,
    this.companyName,
    this.decidedAt,
    this.decisionNote,
    this.feedbackCallAt,
  });

  final String id;
  final String sellerId;
  final String nip;
  final String? companyName;
  final TGFounderApplicationStatus status;
  final int profileCompletePct;
  final int referenceProjectsCount;
  final bool feedbackCallDone;
  final DateTime? feedbackCallAt;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decisionNote;

  TGFounderApplication copyWith({
    TGFounderApplicationStatus? status,
    DateTime? decidedAt,
    String? decisionNote,
    bool? feedbackCallDone,
    DateTime? feedbackCallAt,
    int? profileCompletePct,
    int? referenceProjectsCount,
  }) =>
      TGFounderApplication(
        id: id,
        sellerId: sellerId,
        nip: nip,
        companyName: companyName,
        status: status ?? this.status,
        profileCompletePct: profileCompletePct ?? this.profileCompletePct,
        referenceProjectsCount: referenceProjectsCount ?? this.referenceProjectsCount,
        feedbackCallDone: feedbackCallDone ?? this.feedbackCallDone,
        feedbackCallAt: feedbackCallAt ?? this.feedbackCallAt,
        createdAt: createdAt,
        decidedAt: decidedAt ?? this.decidedAt,
        decisionNote: decisionNote ?? this.decisionNote,
      );
}

@immutable
class TGFounderSavingsEntry {
  const TGFounderSavingsEntry({
    required this.id,
    required this.sellerId,
    required this.at,
    required this.item,
    required this.listPrice,
    required this.paidPrice,
    required this.discountPct,
  });
  final String id;
  final String sellerId;
  final DateTime at;
  final TGFounderDiscountItem item;
  final int listPrice;
  final int paidPrice;
  final double discountPct;
  int get saved => listPrice - paidPrice;
}

@immutable
class TGQualifiedListingInfo {
  const TGQualifiedListingInfo({
    required this.listingId,
    required this.title,
    required this.qualified,
    required this.reasons,
  });
  final String listingId;
  final String title;
  final bool qualified;
  final List<String> reasons;
}

@immutable
class TGAuditConfig {
  const TGAuditConfig({this.liveVisitSampleRate = 0.0});
  /// Fraction of in-review apps randomly suggested for live visit (admin still decides).
  final double liveVisitSampleRate;

  TGAuditConfig copyWith({double? liveVisitSampleRate}) =>
      TGAuditConfig(liveVisitSampleRate: liveVisitSampleRate ?? this.liveVisitSampleRate);
}

@immutable
class TGRevenueConfig {
  const TGRevenueConfig({
    this.phase = 2,
    this.productionMode = false,
    this.flags = const TGRevenueFlags(
      priorityForSale: true,
      marketInsight: true,
      founderProgram: true,
      bulkBilling: true,
      sponsorSlots: true,
      auditProgram: true,
      bannerAds: true,
    ),
    this.priority = const TGPriorityConfig(),
    this.waves = const TGWaveConfig(),
    this.quietMonthThreshold = 3,
    this.founder = const TGFounderConfig(),
    this.audit = const TGAuditConfig(),
    this.bannerAds = const TGBannerAdsConfig(),
  });

  final int phase;
  final bool productionMode;
  final TGRevenueFlags flags;
  final TGPriorityConfig priority;
  final TGWaveConfig waves;
  final int quietMonthThreshold;
  final TGFounderConfig founder;
  final TGAuditConfig audit;
  final TGBannerAdsConfig bannerAds;

  TGRevenueConfig copyWith({
    int? phase,
    bool? productionMode,
    TGRevenueFlags? flags,
    TGPriorityConfig? priority,
    TGWaveConfig? waves,
    int? quietMonthThreshold,
    TGFounderConfig? founder,
    TGAuditConfig? audit,
    TGBannerAdsConfig? bannerAds,
  }) =>
      TGRevenueConfig(
        phase: phase ?? this.phase,
        productionMode: productionMode ?? this.productionMode,
        flags: flags ?? this.flags,
        priority: priority ?? this.priority,
        waves: waves ?? this.waves,
        quietMonthThreshold: quietMonthThreshold ?? this.quietMonthThreshold,
        founder: founder ?? this.founder,
        audit: audit ?? this.audit,
        bannerAds: bannerAds ?? this.bannerAds,
      );

  static TGRevenueConfig mockDefault() => const TGRevenueConfig();

  static TGRevenueConfig forPhase(int phase, {bool productionMode = false}) => TGRevenueConfig(
        phase: phase.clamp(0, 2),
        productionMode: productionMode,
        flags: TGRevenueFlags.forPhase(phase.clamp(0, 2)),
      );
}

@immutable
class TGPrioritySegment {
  const TGPrioritySegment({
    required this.specialty,
    required this.region,
    this.seat = false,
    this.waitlisted = false,
  });
  final TGStoreSpecialty specialty;
  /// Manufacturer's own voivodeship (segment = specialty × own region).
  final String region;
  final bool seat;
  final bool waitlisted;

  String get key => '${specialty.name}|$region';

  TGPrioritySegment copyWith({bool? seat, bool? waitlisted}) => TGPrioritySegment(
        specialty: specialty,
        region: region,
        seat: seat ?? this.seat,
        waitlisted: waitlisted ?? this.waitlisted,
      );
}

@immutable
class TGQuietMonthCredit {
  const TGQuietMonthCredit({
    required this.periodStart,
    required this.matchingRequests,
    required this.extendedUntil,
  });
  final DateTime periodStart;
  final int matchingRequests;
  final DateTime extendedUntil;
}

@immutable
class TGSellerPriority {
  const TGSellerPriority({
    this.status = TGPriorityStatus.none,
    this.source,
    this.activeSince,
    this.nextBillingAt,
    this.cancelAtPeriodEnd = false,
    this.segments = const [],
    this.quietMonthCredits = const [],
  });

  final TGPriorityStatus status;
  final TGPrioritySource? source;
  final DateTime? activeSince;
  final DateTime? nextBillingAt;
  final bool cancelAtPeriodEnd;
  final List<TGPrioritySegment> segments;
  final List<TGQuietMonthCredit> quietMonthCredits;

  bool get isActive => status == TGPriorityStatus.active;
  bool get hasEarlyAccess => isActive || source == TGPrioritySource.enterprise || source == TGPrioritySource.founderFree;

  bool coversSpecialty(TGStoreSpecialty s) => segments.any((seg) => seg.seat && seg.specialty == s);

  TGSellerPriority copyWith({
    TGPriorityStatus? status,
    TGPrioritySource? source,
    bool clearSource = false,
    DateTime? activeSince,
    bool clearActive = false,
    DateTime? nextBillingAt,
    bool clearBilling = false,
    bool? cancelAtPeriodEnd,
    List<TGPrioritySegment>? segments,
    List<TGQuietMonthCredit>? quietMonthCredits,
  }) =>
      TGSellerPriority(
        status: status ?? this.status,
        source: clearSource ? null : (source ?? this.source),
        activeSince: clearActive ? null : (activeSince ?? this.activeSince),
        nextBillingAt: clearBilling ? null : (nextBillingAt ?? this.nextBillingAt),
        cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
        segments: segments ?? this.segments,
        quietMonthCredits: quietMonthCredits ?? this.quietMonthCredits,
      );
}

@immutable
class TGPriorityWaitlistEntry {
  const TGPriorityWaitlistEntry({
    required this.sellerId,
    required this.specialty,
    required this.region,
    required this.joinedAt,
  });
  final String sellerId;
  final TGStoreSpecialty specialty;
  final String region;
  final DateTime joinedAt;
}

@immutable
class TGSegmentGateOverride {
  const TGSegmentGateOverride({
    required this.specialty,
    required this.region,
    required this.open,
    required this.reason,
    required this.at,
    required this.actorId,
  });
  final TGStoreSpecialty specialty;
  final String region;
  final bool open;
  final String reason;
  final DateTime at;
  final String actorId;

  String get key => '${specialty.name}|$region';
}

@immutable
class TGRequestQualitySignals {
  const TGRequestQualitySignals({
    required this.budgetGiven,
    required this.drawingAttached,
    required this.phoneVerified,
    required this.companyNip,
  });
  final bool budgetGiven;
  final bool drawingAttached;
  final bool phoneVerified;
  final bool companyNip;
}

@immutable
class TGMarketInsight {
  const TGMarketInsight({
    required this.otherQuotes,
    required this.minPriceNet,
    required this.maxPriceNet,
    required this.medianLeadWeeks,
  });
  final int otherQuotes;
  final int minPriceNet;
  final int maxPriceNet;
  final int medianLeadWeeks;
}

@immutable
class TGRevenueAuditEntry {
  const TGRevenueAuditEntry({
    required this.id,
    required this.at,
    required this.actorId,
    required this.action,
    this.detail,
    this.reason,
  });
  final String id;
  final DateTime at;
  final String actorId;
  final String action;
  final String? detail;
  final String? reason;
}
