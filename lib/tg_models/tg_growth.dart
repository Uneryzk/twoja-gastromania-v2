import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';

/// Planning windows (not listing-duration labels). DurationFormatter does not apply.
enum GrowthPeriod { p0to3, p3to6, p6to12 }

enum GrowthRevenueBasis { net, gross }

enum GrowthTempo { ahead, onTrack, behind, noTarget }

enum GrowthMetricId {
  individualSellers,
  individualListings,
  activeStores,
  restaurantListings,
  activeManufacturers,
  paidStores,
  adSponsorCustomers,
  monthlyRevenue,
}

@immutable
class GrowthCell {
  const GrowthCell({this.min, this.goal, this.text});

  final int? min;
  final int? goal;
  final String? text;

  bool get hasNumber => min != null || goal != null;

  GrowthCell copyWith({int? min, int? goal, String? text, bool clearText = false}) => GrowthCell(
        min: min ?? this.min,
        goal: goal ?? this.goal,
        text: clearText ? null : (text ?? this.text),
      );
}

@immutable
class GrowthTargets {
  const GrowthTargets(this.cells);
  final Map<GrowthMetricId, Map<GrowthPeriod, GrowthCell>> cells;

  GrowthCell cell(GrowthMetricId id, GrowthPeriod p) => cells[id]?[p] ?? const GrowthCell();

  GrowthTargets withCell(GrowthMetricId id, GrowthPeriod p, GrowthCell cell) {
    final next = {for (final e in cells.entries) e.key: Map<GrowthPeriod, GrowthCell>.of(e.value)};
    next.putIfAbsent(id, () => {});
    next[id]![p] = cell;
    return GrowthTargets(next);
  }

  static GrowthTargets defaults() => GrowthTargets({
        GrowthMetricId.individualSellers: {
          GrowthPeriod.p0to3: const GrowthCell(min: 100),
          GrowthPeriod.p3to6: const GrowthCell(min: 300),
          GrowthPeriod.p6to12: const GrowthCell(min: 800, goal: 1000),
        },
        GrowthMetricId.individualListings: {
          GrowthPeriod.p0to3: const GrowthCell(min: 500),
          GrowthPeriod.p3to6: const GrowthCell(min: 1500),
          GrowthPeriod.p6to12: const GrowthCell(min: 4000, goal: 5000),
        },
        GrowthMetricId.activeStores: {
          GrowthPeriod.p0to3: const GrowthCell(min: 2),
          GrowthPeriod.p3to6: const GrowthCell(min: 10),
          GrowthPeriod.p6to12: const GrowthCell(min: 25, goal: 40),
        },
        GrowthMetricId.restaurantListings: {
          GrowthPeriod.p0to3: const GrowthCell(min: 2, goal: 5),
          GrowthPeriod.p3to6: const GrowthCell(min: 20, goal: 30),
          GrowthPeriod.p6to12: const GrowthCell(min: 60, goal: 100),
        },
        GrowthMetricId.activeManufacturers: {
          GrowthPeriod.p0to3: const GrowthCell(min: 2),
          GrowthPeriod.p3to6: const GrowthCell(min: 8, goal: 10),
          GrowthPeriod.p6to12: const GrowthCell(min: 20, goal: 30),
        },
        GrowthMetricId.paidStores: {
          GrowthPeriod.p0to3: const GrowthCell(text: 'Test paid conversion'),
          GrowthPeriod.p3to6: const GrowthCell(min: 3, goal: 8),
          GrowthPeriod.p6to12: const GrowthCell(min: 15, goal: 25),
        },
        GrowthMetricId.adSponsorCustomers: {
          GrowthPeriod.p0to3: const GrowthCell(text: 'First conversations'),
          GrowthPeriod.p3to6: const GrowthCell(min: 1, goal: 3),
          GrowthPeriod.p6to12: const GrowthCell(min: 5, goal: 10),
        },
        GrowthMetricId.monthlyRevenue: {
          GrowthPeriod.p0to3: const GrowthCell(min: 0, goal: 500),
          GrowthPeriod.p3to6: const GrowthCell(min: 2000, goal: 5000),
          GrowthPeriod.p6to12: const GrowthCell(min: 8000, goal: 20000),
        },
      });
}

@immutable
class GrowthConfig {
  const GrowthConfig({
    this.programStartDate,
    this.revenueBasis = GrowthRevenueBasis.net,
    required this.targets,
  });

  final DateTime? programStartDate;
  final GrowthRevenueBasis revenueBasis;
  final GrowthTargets targets;

  GrowthConfig copyWith({
    DateTime? programStartDate,
    bool clearStart = false,
    GrowthRevenueBasis? revenueBasis,
    GrowthTargets? targets,
  }) =>
      GrowthConfig(
        programStartDate: clearStart ? null : (programStartDate ?? this.programStartDate),
        revenueBasis: revenueBasis ?? this.revenueBasis,
        targets: targets ?? this.targets,
      );
}

@immutable
class GrowthMetricActual {
  const GrowthMetricActual({this.value, this.hasSource = false, this.founderGrant = 0});

  /// Null when the source set is empty ("No data yet").
  final int? value;
  final bool hasSource;
  final int founderGrant;

  bool get noData => !hasSource || value == null;
}

@immutable
class GrowthActuals {
  const GrowthActuals({
    required this.byMetric,
    required this.uniqueSellerIds,
    this.monthlyUniqueSellers = const [],
  });

  final Map<GrowthMetricId, GrowthMetricActual> byMetric;
  final Set<String> uniqueSellerIds;
  final List<int> monthlyUniqueSellers;

  int get uniqueSellers => uniqueSellerIds.length;
  bool get hasSparkline => monthlyUniqueSellers.length >= 3;
}

@immutable
class GrowthRowView {
  const GrowthRowView({
    required this.metric,
    required this.cell,
    required this.actual,
    this.pctMin,
    this.pctGoal,
    required this.tempo,
  });

  final GrowthMetricId metric;
  final GrowthCell cell;
  final GrowthMetricActual actual;
  final double? pctMin;
  final double? pctGoal;
  final GrowthTempo tempo;
}

@immutable
class GrowthRepTarget {
  const GrowthRepTarget({required this.repId, required this.category, this.min = 0, this.goal = 0});

  final String repId;
  final TGRepContactCategory category;
  final int min;
  final int goal;
}

@immutable
class GrowthRoadmapTask {
  const GrowthRoadmapTask({required this.id, required this.text, this.done = false});
  final String id;
  final String text;
  final bool done;
}

@immutable
class GrowthMonthEndCheck {
  const GrowthMonthEndCheck({required this.done, required this.doneBy, required this.doneAt, this.note = ''});
  final bool done;
  final String doneBy;
  final DateTime doneAt;
  final String note;
}

@immutable
class GrowthRoadmapItem {
  const GrowthRoadmapItem({
    required this.id,
    required this.monthStart,
    required this.monthEnd,
    required this.goalKey,
    required this.tasks,
    required this.checkpointKey,
    this.checkpointMetricRef,
    this.monthEndCheck,
  });

  final String id;
  final int monthStart;
  final int monthEnd;
  final String goalKey;
  final List<GrowthRoadmapTask> tasks;
  final String checkpointKey;
  final GrowthMetricId? checkpointMetricRef;
  final GrowthMonthEndCheck? monthEndCheck;

  GrowthRoadmapItem copyWith({
    List<GrowthRoadmapTask>? tasks,
    GrowthMonthEndCheck? monthEndCheck,
    bool clearCheck = false,
  }) =>
      GrowthRoadmapItem(
        id: id,
        monthStart: monthStart,
        monthEnd: monthEnd,
        goalKey: goalKey,
        tasks: tasks ?? this.tasks,
        checkpointKey: checkpointKey,
        checkpointMetricRef: checkpointMetricRef,
        monthEndCheck: clearCheck ? null : (monthEndCheck ?? this.monthEndCheck),
      );
}

enum GrowthAttrFlagKind { sameCluster, noListingAfter14d, selfReferral, burstSignups }

@immutable
class GrowthAttrFlag {
  const GrowthAttrFlag({required this.kind, required this.detail});
  final GrowthAttrFlagKind kind;
  final String detail;
}

@immutable
class GrowthRepWeekRow {
  const GrowthRepWeekRow({
    required this.rep,
    required this.contactsEntered,
    required this.contactMin,
    required this.contactGoal,
    required this.signups,
    required this.phoneVerified,
    required this.won,
    required this.qualifiedActive,
    required this.paid,
    this.attributedNetGrosz,
  });

  final TGRepresentative rep;
  final int contactsEntered;
  final int contactMin;
  final int contactGoal;
  final int signups;
  final int phoneVerified;
  final int won;
  final int qualifiedActive;
  final int paid;
  /// Attributed net, VAT excluded, integer grosz. Never float.
  final int? attributedNetGrosz;
}

/// Integer grosz. Never store money as float.
abstract final class GrowthMoney {
  static const vatBps = 123; // 1.23 × 100

  static int plnToGrosz(int pln) => pln * 100;

  /// `round(gross / 1.23)` at grosz precision, integer-only.
  static int netFromGross(int grossGrosz) {
    if (grossGrosz == 0) return 0;
    final n = grossGrosz * 100;
    return (n * 2 + vatBps) ~/ (vatBps * 2);
  }

  static int vatFromGross(int grossGrosz) => grossGrosz - netFromGross(grossGrosz);

  /// Scale [netGrosz] by remain/gross after a refund, integer-only.
  static int remainNet(int netGrosz, int remainGross, int grossGrosz) {
    if (grossGrosz <= 0) return 0;
    return (netGrosz * remainGross * 2 + grossGrosz) ~/ (grossGrosz * 2);
  }

  static int roundDiv(int value, int denom) {
    if (denom <= 0) return 0;
    return (value * 2 + denom) ~/ (denom * 2);
  }

  /// pl-PL: `6 165,00 PLN` / `5 012,20 PLN`.
  static String format(int grosz) {
    final sign = grosz < 0 ? '-' : '';
    final a = grosz.abs();
    final zl = a ~/ 100;
    final gr = (a % 100).toString().padLeft(2, '0');
    return '$sign${_group(zl)},$gr PLN';
  }

  static String formatZl(int grosz) {
    final sign = grosz < 0 ? '-' : '';
    final a = grosz.abs();
    return '$sign${_group(a ~/ 100)} PLN';
  }

  static String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final left = s.length - i;
      if (i > 0 && left % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

enum GrowthRevWindow { thisMonth, lastMonth, last3, last6, last12 }

enum GrowthRevStreamId {
  storeBasic,
  storePro,
  storeEnterprise,
  extraListings,
  promotions,
  banner,
  sponsorSlot,
  priority,
  restaurant,
}

@immutable
class GrowthStreamActual {
  const GrowthStreamActual({required this.id, required this.grossGrosz, required this.netGrosz, this.hasSource = false, this.count = 0});

  final GrowthRevStreamId id;
  final int grossGrosz;
  final int netGrosz;
  final bool hasSource;
  final int count;

  bool get noData => !hasSource;
}

@immutable
class GrowthPaidPlanCount {
  const GrowthPaidPlanCount({this.basic = 0, this.pro = 0, this.enterprise = 0});
  final int basic;
  final int pro;
  final int enterprise;
  int get total => basic + pro + enterprise;
}

@immutable
class GrowthActualStreams {
  const GrowthActualStreams({
    required this.byStream,
    required this.grossGrosz,
    required this.netGrosz,
    required this.hasSource,
    required this.monthlyNetEqGrosz,
    required this.planCounts,
  });

  final Map<GrowthRevStreamId, GrowthStreamActual> byStream;
  final int grossGrosz;
  final int netGrosz;
  final bool hasSource;
  final int monthlyNetEqGrosz;
  final GrowthPaidPlanCount planCounts;
}

@immutable
class GrowthScenario {
  const GrowthScenario({
    this.id = '',
    this.name = '',
    this.qtyBasic = 0,
    this.priceBasicGrosz = 19900,
    this.qtyPro = 0,
    this.priceProGrosz = 49900,
    this.qtyEnterprise = 0,
    this.priceEnterpriseGrosz = 89900,
    this.qtyListing = 0,
    this.priceListingGrosz = 4900,
    this.qtyPromo = 0,
    this.pricePromoGrosz = 6000,
    this.qtyRestaurant = 0,
    this.priceRestaurantGrosz = 14900,
    this.qtyBanner = 0,
    this.priceBannerGrosz = 12900,
    this.qtySponsor = 0,
    this.priceSponsorGrosz = 8900,
  });

  final String id;
  final String name;
  final int qtyBasic;
  final int priceBasicGrosz;
  final int qtyPro;
  final int priceProGrosz;
  final int qtyEnterprise;
  final int priceEnterpriseGrosz;
  final int qtyListing;
  final int priceListingGrosz;
  final int qtyPromo;
  final int pricePromoGrosz;
  final int qtyRestaurant;
  final int priceRestaurantGrosz;
  final int qtyBanner;
  final int priceBannerGrosz;
  final int qtySponsor;
  final int priceSponsorGrosz;

  int get grossGrosz =>
      qtyBasic * priceBasicGrosz +
      qtyPro * priceProGrosz +
      qtyEnterprise * priceEnterpriseGrosz +
      qtyListing * priceListingGrosz +
      qtyPromo * pricePromoGrosz +
      qtyRestaurant * priceRestaurantGrosz +
      qtyBanner * priceBannerGrosz +
      qtySponsor * priceSponsorGrosz;

  int get netGrosz => GrowthMoney.netFromGross(grossGrosz);

  GrowthScenario copyWith({
    String? id,
    String? name,
    int? qtyBasic,
    int? priceBasicGrosz,
    int? qtyPro,
    int? priceProGrosz,
    int? qtyEnterprise,
    int? priceEnterpriseGrosz,
    int? qtyListing,
    int? priceListingGrosz,
    int? qtyPromo,
    int? pricePromoGrosz,
    int? qtyRestaurant,
    int? priceRestaurantGrosz,
    int? qtyBanner,
    int? priceBannerGrosz,
    int? qtySponsor,
    int? priceSponsorGrosz,
  }) =>
      GrowthScenario(
        id: id ?? this.id,
        name: name ?? this.name,
        qtyBasic: qtyBasic ?? this.qtyBasic,
        priceBasicGrosz: priceBasicGrosz ?? this.priceBasicGrosz,
        qtyPro: qtyPro ?? this.qtyPro,
        priceProGrosz: priceProGrosz ?? this.priceProGrosz,
        qtyEnterprise: qtyEnterprise ?? this.qtyEnterprise,
        priceEnterpriseGrosz: priceEnterpriseGrosz ?? this.priceEnterpriseGrosz,
        qtyListing: qtyListing ?? this.qtyListing,
        priceListingGrosz: priceListingGrosz ?? this.priceListingGrosz,
        qtyPromo: qtyPromo ?? this.qtyPromo,
        pricePromoGrosz: pricePromoGrosz ?? this.pricePromoGrosz,
        qtyRestaurant: qtyRestaurant ?? this.qtyRestaurant,
        priceRestaurantGrosz: priceRestaurantGrosz ?? this.priceRestaurantGrosz,
        qtyBanner: qtyBanner ?? this.qtyBanner,
        priceBannerGrosz: priceBannerGrosz ?? this.priceBannerGrosz,
        qtySponsor: qtySponsor ?? this.qtySponsor,
        priceSponsorGrosz: priceSponsorGrosz ?? this.priceSponsorGrosz,
      );

  static const pdfExample = GrowthScenario(
    name: 'PDF example',
    qtyBasic: 10,
    priceBasicGrosz: 19900,
    qtyPro: 5,
    priceProGrosz: 39900,
    qtyListing: 20,
    priceListingGrosz: 4900,
    qtyPromo: 20,
    pricePromoGrosz: 6000,
  );

  static const pdfGrossGrosz = 616500;
  static const pdfNetGrosz = 501220;
  static const currentGrossGrosz = 666500;
  static const currentNetGrosz = 541870;
}

enum BudgetCommitment { committed, notCommitted }

@immutable
class BudgetPhase {
  const BudgetPhase({
    required this.id,
    required this.labelKey,
    required this.monthStart,
    required this.monthEnd,
    required this.plannedGrosz,
    required this.commitment,
    this.commitNote = '',
    this.committedAt,
  });

  final String id;
  final String labelKey;
  final int monthStart;
  final int monthEnd;
  final int plannedGrosz;
  final BudgetCommitment commitment;
  final String commitNote;
  final DateTime? committedAt;

  BudgetPhase copyWith({
    BudgetCommitment? commitment,
    String? commitNote,
    DateTime? committedAt,
  }) =>
      BudgetPhase(
        id: id,
        labelKey: labelKey,
        monthStart: monthStart,
        monthEnd: monthEnd,
        plannedGrosz: plannedGrosz,
        commitment: commitment ?? this.commitment,
        commitNote: commitNote ?? this.commitNote,
        committedAt: committedAt ?? this.committedAt,
      );
}

enum GrowthExpenseCategory { infrastructure, legal, marketing, b2bMarketing, tools, other, custom }

@immutable
class GrowthExpense {
  const GrowthExpense({
    required this.id,
    required this.date,
    required this.amountGrosz,
    required this.basis,
    this.vatGrosz,
    required this.category,
    this.customCategory = '',
    required this.phaseId,
    required this.description,
    this.vendor = '',
    this.invoiceRef = '',
    required this.createdBy,
    this.voided = false,
    this.voidReason = '',
    this.overrunNote = '',
    this.isMock = false,
  });

  final String id;
  final DateTime date;
  final int amountGrosz;
  final GrowthRevenueBasis basis;
  final int? vatGrosz;
  final GrowthExpenseCategory category;
  final String customCategory;
  final String phaseId;
  final String description;
  final String vendor;
  final String invoiceRef;
  final String createdBy;
  final bool voided;
  final String voidReason;
  final String overrunNote;
  final bool isMock;

  int get netGrosz {
    if (basis == GrowthRevenueBasis.net) return amountGrosz;
    if (vatGrosz != null) return amountGrosz - vatGrosz!;
    return GrowthMoney.netFromGross(amountGrosz);
  }

  GrowthExpense copyWith({
    DateTime? date,
    int? amountGrosz,
    GrowthRevenueBasis? basis,
    int? vatGrosz,
    GrowthExpenseCategory? category,
    String? customCategory,
    String? phaseId,
    String? description,
    String? vendor,
    String? invoiceRef,
    bool? voided,
    String? voidReason,
    String? overrunNote,
  }) =>
      GrowthExpense(
        id: id,
        date: date ?? this.date,
        amountGrosz: amountGrosz ?? this.amountGrosz,
        basis: basis ?? this.basis,
        vatGrosz: vatGrosz ?? this.vatGrosz,
        category: category ?? this.category,
        customCategory: customCategory ?? this.customCategory,
        phaseId: phaseId ?? this.phaseId,
        description: description ?? this.description,
        vendor: vendor ?? this.vendor,
        invoiceRef: invoiceRef ?? this.invoiceRef,
        createdBy: createdBy,
        voided: voided ?? this.voided,
        voidReason: voidReason ?? this.voidReason,
        overrunNote: overrunNote ?? this.overrunNote,
        isMock: isMock,
      );
}

@immutable
class BudgetPhaseView {
  const BudgetPhaseView({
    required this.phase,
    required this.spentGrosz,
    required this.remainingGrosz,
    required this.usageBps,
    required this.warn80,
    required this.warn100,
  });

  final BudgetPhase phase;
  final int spentGrosz;
  final int remainingGrosz;

  /// Spent / planned in basis points (10000 = 100%).
  final int usageBps;
  final bool warn80;
  final bool warn100;
}

@immutable
class GrowthCashMonth {
  const GrowthCashMonth({required this.monthStart, required this.collectedNetGrosz, required this.expenseNetGrosz, required this.hasSource});
  final DateTime monthStart;
  final int collectedNetGrosz;
  final int expenseNetGrosz;
  final bool hasSource;
  int get positionGrosz => collectedNetGrosz - expenseNetGrosz;
}

enum GrowthMeetChannel { marketplaceGroups, directVisits, referrals, seo, social, ads, other }

@immutable
class GrowthActionItem {
  const GrowthActionItem({required this.id, required this.text, this.owner = '', this.due, this.done = false});
  final String id;
  final String text;
  final String owner;
  final DateTime? due;
  final bool done;

  GrowthActionItem copyWith({String? text, String? owner, DateTime? due, bool? done}) => GrowthActionItem(
        id: id,
        text: text ?? this.text,
        owner: owner ?? this.owner,
        due: due ?? this.due,
        done: done ?? this.done,
      );
}

@immutable
class GrowthMeetAmendment {
  const GrowthMeetAmendment({required this.at, required this.by, required this.text});
  final DateTime at;
  final String by;
  final String text;
}

@immutable
class GrowthWeekAuto {
  const GrowthWeekAuto({
    required this.signups,
    required this.won,
    required this.signupsBySegment,
    required this.wonBySegment,
    required this.newActiveListings,
    required this.repMeetings,
    required this.paidCustomers,
    required this.weekNetGrosz,
    required this.weekGrossGrosz,
    required this.mtdNetGrosz,
    required this.mtdGrossGrosz,
  });

  final int signups;
  final int won;
  final Map<TGReferralSegment, int> signupsBySegment;
  final Map<TGReferralSegment, int> wonBySegment;
  final int newActiveListings;
  final int repMeetings;
  final int paidCustomers;
  final int weekNetGrosz;
  final int weekGrossGrosz;
  final int mtdNetGrosz;
  final int mtdGrossGrosz;
}

@immutable
class GrowthWeeklyMeeting {
  const GrowthWeeklyMeeting({
    required this.id,
    required this.weekStart,
    required this.heldAt,
    required this.attendees,
    required this.q1Note,
    required this.q2Note,
    required this.q3Note,
    this.q3Override,
    required this.q4Note,
    required this.q5Problem,
    required this.q5Channel,
    required this.q5Owner,
    required this.decisions,
    required this.actionItems,
    required this.createdBy,
    required this.lockedAt,
    required this.snapshot,
    this.amendments = const [],
    this.isMock = false,
  });

  final String id;
  final DateTime weekStart;
  final DateTime heldAt;
  final List<String> attendees;
  final String q1Note;
  final String q2Note;
  final String q3Note;
  final int? q3Override;
  final String q4Note;
  final String q5Problem;
  final GrowthMeetChannel q5Channel;
  final String q5Owner;
  final String decisions;
  final List<GrowthActionItem> actionItems;
  final String createdBy;
  final DateTime lockedAt;
  final GrowthWeekAuto snapshot;
  final List<GrowthMeetAmendment> amendments;
  final bool isMock;

  bool isLocked([DateTime? now]) => !(now ?? DateTime.now()).isBefore(lockedAt);

  GrowthWeeklyMeeting copyWith({
    List<String>? attendees,
    String? q1Note,
    String? q2Note,
    String? q3Note,
    int? q3Override,
    String? q4Note,
    String? q5Problem,
    GrowthMeetChannel? q5Channel,
    String? q5Owner,
    String? decisions,
    List<GrowthActionItem>? actionItems,
    List<GrowthMeetAmendment>? amendments,
    GrowthWeekAuto? snapshot,
  }) =>
      GrowthWeeklyMeeting(
        id: id,
        weekStart: weekStart,
        heldAt: heldAt,
        attendees: attendees ?? this.attendees,
        q1Note: q1Note ?? this.q1Note,
        q2Note: q2Note ?? this.q2Note,
        q3Note: q3Note ?? this.q3Note,
        q3Override: q3Override ?? this.q3Override,
        q4Note: q4Note ?? this.q4Note,
        q5Problem: q5Problem ?? this.q5Problem,
        q5Channel: q5Channel ?? this.q5Channel,
        q5Owner: q5Owner ?? this.q5Owner,
        decisions: decisions ?? this.decisions,
        actionItems: actionItems ?? this.actionItems,
        createdBy: createdBy,
        lockedAt: lockedAt,
        snapshot: snapshot ?? this.snapshot,
        amendments: amendments ?? this.amendments,
        isMock: isMock,
      );
}
