import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Admin Growth & Operations numbers. Actuals come from live services;
/// mocks stay hidden in Production Mode.
class GrowthService extends ChangeNotifier {
  GrowthService._();
  static final GrowthService instance = GrowthService._();

  GrowthConfig _config = GrowthConfig(targets: GrowthTargets.defaults());
  final List<GrowthRoadmapItem> _roadmap = [];
  final List<GrowthRepTarget> _repTargets = [];
  final List<BudgetPhase> _phases = [];
  final List<GrowthExpense> _expenses = [];
  final List<GrowthScenario> _scenarios = [];
  final List<GrowthWeeklyMeeting> _meetings = [];
  final Set<String> _phoneVerified = {};
  bool _seeded = false;
  int _taskSeq = 1;
  int _expSeq = 1;
  int _scenSeq = 1;
  int _meetSeq = 1;
  int _actSeq = 1;

  GrowthConfig get config => _config;
  List<GrowthRoadmapItem> get roadmap => List.unmodifiable(_roadmap);
  List<BudgetPhase> get phases => List.unmodifiable(_phases);
  List<GrowthExpense> get expenses => [for (final e in _expenses) if (!(_hideMock && e.isMock)) e];
  List<GrowthScenario> get scenarios => List.unmodifiable(_scenarios);
  List<GrowthWeeklyMeeting> get meetings => [for (final m in _meetings) if (!(_hideMock && m.isMock)) m];

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _config = GrowthConfig(targets: GrowthTargets.defaults());
    _roadmap.clear();
    _repTargets.clear();
    _phases.clear();
    _expenses.clear();
    _scenarios.clear();
    _meetings.clear();
    _phoneVerified.clear();
    _seeded = false;
    _taskSeq = 1;
    _expSeq = 1;
    _scenSeq = 1;
    _meetSeq = 1;
    _actSeq = 1;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _roadmap.addAll(_seedRoadmap());
    _phases.addAll(_seedPhases());
    for (final r in ReferralRepository.instance.allRepresentatives()) {
      _ensureDefaultTargets(r.id);
    }
    if (!_hideMock) _seedDevOps();
  }

  void logView(FakeAuthState actor, String tab) {
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_view', targetId: tab);
  }

  void setProgramStart(DateTime? date, {required FakeAuthState actor}) {
    _config = _config.copyWith(programStartDate: date, clearStart: date == null);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_start_date', targetId: date?.toIso8601String() ?? 'cleared');
    notifyListeners();
  }

  void setRevenueBasis(GrowthRevenueBasis basis, {required FakeAuthState actor}) {
    _config = _config.copyWith(revenueBasis: basis);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_revenue_basis', targetId: basis.name);
    notifyListeners();
  }

  void setTargetCell(GrowthMetricId id, GrowthPeriod p, GrowthCell cell, {required FakeAuthState actor}) {
    _config = _config.copyWith(targets: _config.targets.withCell(id, p, cell));
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_target_edit', targetId: '${id.name}.${p.name}');
    notifyListeners();
  }

  static const periodMonths = {
    GrowthPeriod.p0to3: (0, 3),
    GrowthPeriod.p3to6: (3, 6),
    GrowthPeriod.p6to12: (6, 12),
  };

  GrowthPeriod? activePeriod([DateTime? now]) {
    final start = _config.programStartDate;
    if (start == null) return null;
    final months = _monthsBetween(start, now ?? TGClock.now());
    if (months < 3) return GrowthPeriod.p0to3;
    if (months < 6) return GrowthPeriod.p3to6;
    return GrowthPeriod.p6to12;
  }

  /// Elapsed ratio inside [period] (0–1). Null when start date is missing.
  double? elapsedRatio(GrowthPeriod period, [DateTime? now]) {
    final start = _config.programStartDate;
    if (start == null) return null;
    final band = periodMonths[period]!;
    final t = now ?? TGClock.now();
    final periodStart = DateTime(start.year, start.month + band.$1, start.day);
    final periodEnd = DateTime(start.year, start.month + band.$2, start.day);
    if (t.isBefore(periodStart)) return 0;
    final total = periodEnd.difference(periodStart).inDays;
    if (total <= 0) return 1;
    final gone = t.difference(periodStart).inDays.clamp(0, total);
    return gone / total;
  }

  static double? pct(int? actual, int? target) {
    if (actual == null || target == null || target <= 0) return null;
    return actual / target;
  }

  static GrowthTempo tempo({required GrowthCell cell, required int? actual, required double? elapsed}) {
    if (!cell.hasNumber) return GrowthTempo.noTarget;
    if (actual == null) return GrowthTempo.noTarget;
    if (elapsed == null) return GrowthTempo.noTarget;
    final floor = (cell.min ?? cell.goal)! * elapsed;
    final goalLine = cell.goal == null ? null : cell.goal! * elapsed;
    if (goalLine != null && actual >= goalLine) return GrowthTempo.ahead;
    if (actual >= floor) return GrowthTempo.onTrack;
    return GrowthTempo.behind;
  }

  /// Monthly revenue compares the last complete month to the period band
  /// (no elapsed-ratio scaling).
  static GrowthTempo revenueTempo({required GrowthCell cell, required int? actual}) {
    if (!cell.hasNumber || actual == null) return GrowthTempo.noTarget;
    if (cell.goal != null && actual >= cell.goal!) return GrowthTempo.ahead;
    if ((cell.min ?? 0) <= actual) return GrowthTempo.onTrack;
    return GrowthTempo.behind;
  }

  static int uniqueSellerCount(Iterable<Iterable<String>> groups) {
    final out = <String>{};
    for (final g in groups) {
      out.addAll(g);
    }
    return out.length;
  }

  GrowthActuals actuals() {
    ReferralRepository.instance.ensureSeeded();
    final products = TGProductService.instance.cachedAll;
    final restos = _hideMock ? const <RestaurantListing>[] : RestaurantService.instance.all.where((r) => r.status == RestaurantListingStatus.active).toList();
    final profiles = _hideMock ? const <TGStoreProfile>[] : TGSellerProfileService.instance.all;

    final privateNonDraft = [
      for (final p in products)
        if (p.seller.type == TGSellerType.private && p.status != TGListingStatus.draft) p,
    ];
    final privateSellers = <String>{};
    for (final p in privateNonDraft) {
      if (_phoneOk(p.ownerKey)) privateSellers.add(p.ownerKey);
    }
    final repo = ReferralRepository.instance;
    for (final r in repo.allRepresentatives()) {
      for (final a in repo.rawAccountsFor(r.id)) {
        if (a.segment == TGReferralSegment.individual && a.phoneVerified && a.listings.isNotEmpty) {
          privateSellers.add(a.userId);
        }
      }
    }

    final individualListings = [
      for (final p in products)
        if (p.seller.type == TGSellerType.private && p.isActive) p,
    ];

    final founderIds = <String>{};
    final storeIds = <String>{};
    for (final p in profiles.where((p) => p.isStore && p.isLive && p.plan != null)) {
      storeIds.add(p.sellerKey);
      if (TGFounderService.instance.founderFor(p.sellerKey).enrolled) founderIds.add(p.sellerKey);
    }
    for (final s in TGBillingService.instance.allStoreSubscriptions()) {
      if (s.status == TGSubscriptionStatus.active) storeIds.add(s.userId);
    }

    final paidStoreIds = <String>{
      for (final id in storeIds)
        if (!TGFounderService.instance.founderFor(id).enrolled) id,
    };
    for (final p in TGBillingService.instance.allPayments()) {
      if (p.kind == TGPaymentKind.store && p.status == TGPaymentStatus.succeeded) {
        if (!TGFounderService.instance.founderFor(p.userId).enrolled) paidStoreIds.add(p.userId);
      }
    }

    final makers = [
      for (final p in profiles)
        if (p.isSpecialOrderManufacturer && p.isLive) p.sellerKey,
    ];

    final now = TGClock.now();
    final since = now.subtract(const Duration(days: 90));
    final adIds = <String>{};
    for (final p in TGBillingService.instance.allPayments()) {
      if ((p.kind == TGPaymentKind.banner || p.kind == TGPaymentKind.sponsorSlot) &&
          p.status == TGPaymentStatus.succeeded &&
          !p.createdAt.isBefore(since)) {
        adIds.add(p.userId);
      }
    }

    final monthRev = lastCompleteMonthRevenue();

    GrowthMetricActual metric(int count, {required bool hasSource, int founder = 0}) =>
        GrowthMetricActual(value: hasSource ? count : null, hasSource: hasSource, founderGrant: founder);

    final unique = <String>{
      ...privateSellers,
      ...storeIds,
      for (final r in restos) r.ownerId,
      ...makers,
    };

    return GrowthActuals(
      byMetric: {
        GrowthMetricId.individualSellers: metric(privateSellers.length, hasSource: privateNonDraft.isNotEmpty || privateSellers.isNotEmpty),
        GrowthMetricId.individualListings: metric(individualListings.length, hasSource: products.isNotEmpty),
        GrowthMetricId.activeStores: metric(storeIds.length, hasSource: storeIds.isNotEmpty || profiles.any((p) => p.isStore), founder: founderIds.length),
        GrowthMetricId.restaurantListings: metric(restos.length, hasSource: !_hideMock && RestaurantService.instance.all.isNotEmpty),
        GrowthMetricId.activeManufacturers: metric(makers.length, hasSource: profiles.any((p) => p.acceptsSpecialOrder)),
        GrowthMetricId.paidStores: metric(paidStoreIds.length, hasSource: paidStoreIds.isNotEmpty || TGBillingService.instance.allStoreSubscriptions().isNotEmpty),
        GrowthMetricId.adSponsorCustomers: metric(adIds.length, hasSource: TGBillingService.instance.allPayments().isNotEmpty),
        GrowthMetricId.monthlyRevenue: metric(monthRev, hasSource: TGBillingService.instance.allPayments().isNotEmpty),
      },
      uniqueSellerIds: unique,
      monthlyUniqueSellers: _monthlyUniques(products, restos),
    );
  }

  int lastCompleteMonthRevenue() {
    final now = TGClock.now();
    final end = DateTime(now.year, now.month, 1);
    final start = DateTime(end.year, end.month - 1, 1);
    var net = 0.0;
    var any = false;
    final billing = TGBillingService.instance;
    final gross = _config.revenueBasis == GrowthRevenueBasis.gross;
    for (final p in billing.allPayments()) {
      if (p.status != TGPaymentStatus.succeeded && p.status != TGPaymentStatus.refunded) continue;
      if (p.createdAt.isBefore(start) || !p.createdAt.isBefore(end)) continue;
      any = true;
      final refunded = billing.refundedPln(p.id);
      final remainGross = (p.grossPln - refunded).clamp(0, p.grossPln);
      net += gross ? remainGross : (p.grossPln == 0 ? 0.0 : remainGross * (p.netPln / p.grossPln));
    }
    return any ? net.round() : 0;
  }

  List<GrowthRowView> rowsFor(GrowthPeriod period) {
    final snap = actuals();
    final elapsed = elapsedRatio(period);
    return [
      for (final id in GrowthMetricId.values)
        () {
          final cell = _config.targets.cell(id, period);
          final a = snap.byMetric[id] ?? const GrowthMetricActual();
          final value = a.value;
          return GrowthRowView(
            metric: id,
            cell: cell,
            actual: a,
            pctMin: pct(value, cell.min),
            pctGoal: pct(value, cell.goal),
            tempo: id == GrowthMetricId.monthlyRevenue
                ? revenueTempo(cell: cell, actual: value)
                : tempo(cell: cell, actual: value, elapsed: elapsed),
          );
        }(),
    ];
  }

  List<int> _monthlyUniques(List<TGProduct> products, List<RestaurantListing> restos) {
    final byMonth = <String, Set<String>>{};
    void add(DateTime? at, String id) {
      if (at == null) return;
      final key = '${at.year}-${at.month}';
      byMonth.putIfAbsent(key, () => {}).add(id);
    }

    for (final p in products) {
      add(p.publishedAt, p.ownerKey);
    }
    for (final r in restos) {
      add(r.publishedAt, r.ownerId);
    }
    final keys = byMonth.keys.toList()..sort();
    return [for (final k in keys) byMonth[k]!.length];
  }

  bool _phoneOk(String userId) {
    if (_phoneVerified.contains(userId)) return true;
    final acc = ReferralRepository.instance.accountOf(userId);
    return acc?.phoneVerified ?? false;
  }

  @visibleForTesting
  void debugMarkPhoneVerified(String userId) => _phoneVerified.add(userId);

  int _monthsBetween(DateTime start, DateTime now) =>
      (now.year - start.year) * 12 + now.month - start.month + (now.day >= start.day ? 0 : -1);

  bool isOverdue(GrowthRoadmapItem item, [DateTime? now]) {
    final start = _config.programStartDate;
    if (start == null) return false;
    if (item.monthEndCheck?.done == true) return false;
    final end = DateTime(start.year, start.month + item.monthEnd, start.day);
    return (now ?? TGClock.now()).isAfter(end);
  }

  void addTask(String itemId, String text, {required FakeAuthState actor}) {
    final i = _roadmap.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    final tasks = [..._roadmap[i].tasks, GrowthRoadmapTask(id: 't-${_taskSeq++}', text: text)];
    _roadmap[i] = _roadmap[i].copyWith(tasks: tasks);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_roadmap_task', targetId: itemId);
    notifyListeners();
  }

  void removeTask(String itemId, String taskId, {required FakeAuthState actor}) {
    final i = _roadmap.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    _roadmap[i] = _roadmap[i].copyWith(tasks: [for (final t in _roadmap[i].tasks) if (t.id != taskId) t]);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_roadmap_task_del', targetId: taskId);
    notifyListeners();
  }

  void toggleTask(String itemId, String taskId) {
    final i = _roadmap.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    _roadmap[i] = _roadmap[i].copyWith(
      tasks: [
        for (final t in _roadmap[i].tasks)
          if (t.id == taskId) GrowthRoadmapTask(id: t.id, text: t.text, done: !t.done) else t,
      ],
    );
    notifyListeners();
  }

  void setMonthEndCheck(String itemId, {required bool done, required String note, required FakeAuthState actor}) {
    final i = _roadmap.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    _roadmap[i] = _roadmap[i].copyWith(
      monthEndCheck: done
          ? GrowthMonthEndCheck(done: true, doneBy: actor.userId, doneAt: TGClock.now(), note: note)
          : null,
      clearCheck: !done,
    );
    TGAdminConsoleService.instance.log(
      actor: actor,
      action: 'growth_roadmap_check',
      targetId: itemId,
      reason: note.trim().isEmpty ? 'month-end' : note,
    );
    notifyListeners();
  }

  List<GrowthRepTarget> targetsFor(String repId) {
    _ensureDefaultTargets(repId);
    return [for (final t in _repTargets) if (t.repId == repId) t];
  }

  void setRepTarget(GrowthRepTarget t, {required FakeAuthState actor}) {
    _repTargets.removeWhere((e) => e.repId == t.repId && e.category == t.category);
    _repTargets.add(t);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_rep_target', targetId: '${t.repId}.${t.category.name}');
    notifyListeners();
  }

  void _ensureDefaultTargets(String repId) {
    if (_repTargets.any((t) => t.repId == repId)) return;
    _repTargets.addAll(const [
      GrowthRepTarget(repId: '', category: TGRepContactCategory.individual, min: 30, goal: 50),
      GrowthRepTarget(repId: '', category: TGRepContactCategory.corporate, min: 10, goal: 15),
      GrowthRepTarget(repId: '', category: TGRepContactCategory.restaurant, min: 5, goal: 10),
      GrowthRepTarget(repId: '', category: TGRepContactCategory.manufacturer, min: 5, goal: 10),
    ].map((t) => GrowthRepTarget(repId: repId, category: t.category, min: t.min, goal: t.goal)));
  }

  void addRep({required String displayName, required TGRepRole role, required FakeAuthState actor}) {
    final r = ReferralRepository.instance.addRepresentative(displayName: displayName, role: role);
    if (r == null) return;
    _ensureDefaultTargets(r.id);
    TGAdminConsoleService.instance.log(actor: actor, action: 'growth_rep_add', targetId: r.id);
    notifyListeners();
  }

  void setRepActive(String repId, bool active, {required FakeAuthState actor}) {
    ReferralRepository.instance.setRepStatus(repId, active ? TGRepStatus.active : TGRepStatus.inactive);
    TGAdminConsoleService.instance.log(
      actor: actor,
      action: active ? 'growth_rep_activate' : 'growth_rep_deactivate',
      targetId: repId,
    );
    notifyListeners();
  }

  List<GrowthRepWeekRow> teamRows(DateTime weekStart) {
    ReferralRepository.instance.ensureSeeded();
    final repo = ReferralRepository.instance;
    return [
      for (final r in repo.allRepresentatives()) _weekRow(r, weekStart),
    ];
  }

  GrowthRepWeekRow _weekRow(TGRepresentative r, DateTime weekStart) {
    final repo = ReferralRepository.instance;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final acc = repo.rawAccountsFor(r.id);
    final weekAcc = [for (final a in acc) if (!a.referredAt.isBefore(weekStart) && a.referredAt.isBefore(weekEnd)) a];
    final targets = targetsFor(r.id);
    var cMin = 0, cGoal = 0;
    for (final t in targets) {
      cMin += t.min;
      cGoal += t.goal;
    }
    var won = 0, paid = 0, qual = 0, phone = 0;
    for (final a in acc) {
      if (a.phoneVerified) phone++;
      if (a.phoneVerified && (a.listings.any((l) => l.qualifiedActive) || a.hasPaidPlan)) won++;
      if (a.hasPaidPlan) paid++;
      qual += a.listings.where((l) => l.qualifiedActive).length;
    }
    var net = 0;
    var anyNet = false;
    for (final a in acc) {
      final v = repo.attributedNetGrosz(a.userId);
      if (v != null) {
        net += v;
        anyNet = true;
      }
    }
    return GrowthRepWeekRow(
      rep: r,
      contactsEntered: repo.contactsInWeek(r.id, weekStart),
      contactMin: cMin,
      contactGoal: cGoal,
      signups: weekAcc.length,
      phoneVerified: phone,
      won: won,
      qualifiedActive: qual,
      paid: paid,
      attributedNetGrosz: anyNet ? net : null,
    );
  }

  static List<GrowthRoadmapItem> _seedRoadmap() => const [
        GrowthRoadmapItem(id: 'm1', monthStart: 1, monthEnd: 1, goalKey: 'gr_m1_goal', tasks: [GrowthRoadmapTask(id: 'm1t1', text: 'gr_m1_task')], checkpointKey: 'gr_m1_check'),
        GrowthRoadmapItem(id: 'm2', monthStart: 2, monthEnd: 2, goalKey: 'gr_m2_goal', tasks: [GrowthRoadmapTask(id: 'm2t1', text: 'gr_m2_task')], checkpointKey: 'gr_m2_check'),
        GrowthRoadmapItem(id: 'm3', monthStart: 3, monthEnd: 3, goalKey: 'gr_m3_goal', tasks: [GrowthRoadmapTask(id: 'm3t1', text: 'gr_m3_task')], checkpointKey: 'gr_m3_check', checkpointMetricRef: GrowthMetricId.individualSellers),
        GrowthRoadmapItem(id: 'm4', monthStart: 4, monthEnd: 4, goalKey: 'gr_m4_goal', tasks: [GrowthRoadmapTask(id: 'm4t1', text: 'gr_m4_task')], checkpointKey: 'gr_m4_check'),
        GrowthRoadmapItem(id: 'm5', monthStart: 5, monthEnd: 5, goalKey: 'gr_m5_goal', tasks: [GrowthRoadmapTask(id: 'm5t1', text: 'gr_m5_task')], checkpointKey: 'gr_m5_check'),
        GrowthRoadmapItem(id: 'm6', monthStart: 6, monthEnd: 6, goalKey: 'gr_m6_goal', tasks: [GrowthRoadmapTask(id: 'm6t1', text: 'gr_m6_task')], checkpointKey: 'gr_m6_check'),
        GrowthRoadmapItem(id: 'm79', monthStart: 7, monthEnd: 9, goalKey: 'gr_m79_goal', tasks: [GrowthRoadmapTask(id: 'm79t1', text: 'gr_m79_task')], checkpointKey: 'gr_m79_check'),
        GrowthRoadmapItem(id: 'm1012', monthStart: 10, monthEnd: 12, goalKey: 'gr_m1012_goal', tasks: [GrowthRoadmapTask(id: 'm1012t1', text: 'gr_m1012_task')], checkpointKey: 'gr_m1012_check'),
      ];

  static List<BudgetPhase> _seedPhases() => [
        const BudgetPhase(
          id: 'bp-0-3',
          labelKey: 'gr_bp_03',
          monthStart: 0,
          monthEnd: 3,
          plannedGrosz: 960000,
          commitment: BudgetCommitment.committed,
        ),
        const BudgetPhase(
          id: 'bp-3-6',
          labelKey: 'gr_bp_36',
          monthStart: 3,
          monthEnd: 6,
          plannedGrosz: 1560000,
          commitment: BudgetCommitment.committed,
        ),
        const BudgetPhase(
          id: 'bp-6-12',
          labelKey: 'gr_bp_612',
          monthStart: 6,
          monthEnd: 12,
          plannedGrosz: 6600000,
          commitment: BudgetCommitment.notCommitted,
        ),
      ];

  void _seedDevOps() {
    _expenses.add(GrowthExpense(
      id: 'exp-mock-1',
      date: TGClock.now().subtract(const Duration(days: 10)),
      amountGrosz: 123000,
      basis: GrowthRevenueBasis.net,
      category: GrowthExpenseCategory.legal,
      phaseId: 'bp-0-3',
      description: 'Mock legal retainer',
      createdBy: 'seed',
      isMock: true,
    ));
  }

  // ---------------------------------------------------------------------------
  // Tab 4 — actual streams (never mix with scenario)
  // ---------------------------------------------------------------------------

  static (DateTime, DateTime) windowBounds(GrowthRevWindow w, [DateTime? now]) {
    final t = now ?? TGClock.now();
    final today = DateTime(t.year, t.month, t.day);
    final monthStart = DateTime(t.year, t.month, 1);
    switch (w) {
      case GrowthRevWindow.thisMonth:
        return (monthStart, today.add(const Duration(days: 1)));
      case GrowthRevWindow.lastMonth:
        final start = DateTime(t.year, t.month - 1, 1);
        return (start, monthStart);
      case GrowthRevWindow.last3:
        return (DateTime(t.year, t.month - 2, 1), today.add(const Duration(days: 1)));
      case GrowthRevWindow.last6:
        return (DateTime(t.year, t.month - 5, 1), today.add(const Duration(days: 1)));
      case GrowthRevWindow.last12:
        return (DateTime(t.year, t.month - 11, 1), today.add(const Duration(days: 1)));
    }
  }

  /// Collected amount of a paid payment after refunds, in grosz.
  static (int gross, int net) collectedGrosz(TGPayment p, int refundedGrosz) {
    if (p.status == TGPaymentStatus.failed) return (0, 0);
    if (p.status != TGPaymentStatus.succeeded && p.status != TGPaymentStatus.refunded) return (0, 0);
    final remainGross = (p.amount.grossGr - refundedGrosz).clamp(0, p.amount.grossGr);
    final remainNet = GrowthMoney.remainNet(p.amount.netGr, remainGross, p.amount.grossGr);
    return (remainGross, remainNet);
  }

  GrowthRevStreamId? _streamOf(TGPayment p) {
    switch (p.kind) {
      case TGPaymentKind.store:
        final plan = _storePlanOf(p);
        return switch (plan) {
          'pro' => GrowthRevStreamId.storePro,
          'enterprise' => GrowthRevStreamId.storeEnterprise,
          _ => GrowthRevStreamId.storeBasic,
        };
      case TGPaymentKind.listing:
      case TGPaymentKind.renew:
        return GrowthRevStreamId.extraListings;
      case TGPaymentKind.promotion:
        return GrowthRevStreamId.promotions;
      case TGPaymentKind.banner:
        return GrowthRevStreamId.banner;
      case TGPaymentKind.sponsorSlot:
        return GrowthRevStreamId.sponsorSlot;
      case TGPaymentKind.priority:
        return GrowthRevStreamId.priority;
      case TGPaymentKind.restaurant:
        return GrowthRevStreamId.restaurant;
      case TGPaymentKind.audit:
        return null;
    }
  }

  String _storePlanOf(TGPayment p) {
    if (p.subscriptionId != null) {
      for (final s in TGBillingService.instance.allStoreSubscriptions()) {
        if (s.id == p.subscriptionId) return s.planId;
      }
    }
    final d = p.description.toLowerCase();
    if (d.contains('enterprise')) return 'enterprise';
    if (d.contains('pro')) return 'pro';
    return 'basic';
  }

  GrowthActualStreams actualStreams(GrowthRevWindow window) {
    final billing = TGBillingService.instance;
    final bounds = windowBounds(window);
    final acc = {for (final id in GrowthRevStreamId.values) id: (g: 0, n: 0, c: 0, src: false)};
    var any = false;
    var gross = 0;
    var net = 0;
    for (final p in billing.allPayments()) {
      if (p.createdAt.isBefore(bounds.$1) || !p.createdAt.isBefore(bounds.$2)) continue;
      final sid = _streamOf(p);
      if (sid == null) continue;
      final pair = collectedGrosz(p, billing.refundedGrosz(p.id));
      if (p.status == TGPaymentStatus.failed) continue;
      any = true;
      final cur = acc[sid]!;
      acc[sid] = (g: cur.g + pair.$1, n: cur.n + pair.$2, c: cur.c + 1, src: true);
      gross += pair.$1;
      net += pair.$2;
    }
    return GrowthActualStreams(
      byStream: {
        for (final id in GrowthRevStreamId.values)
          id: GrowthStreamActual(id: id, grossGrosz: acc[id]!.g, netGrosz: acc[id]!.n, hasSource: acc[id]!.src, count: acc[id]!.c),
      },
      grossGrosz: gross,
      netGrosz: net,
      hasSource: any,
      monthlyNetEqGrosz: monthlyPaidNetEquivalent(),
      planCounts: paidPlanCounts(),
    );
  }

  int monthlyPaidNetEquivalent() {
    var monthlyGross = 0;
    for (final s in TGBillingService.instance.allStoreSubscriptions()) {
      if (s.status != TGSubscriptionStatus.active) continue;
      if (TGFounderService.instance.founderFor(s.userId).enrolled) continue;
      final periodGrosz = s.pricePln * 100;
      monthlyGross += switch (s.period) {
        TGBillingPeriod.monthly => periodGrosz,
        TGBillingPeriod.sixMonths => GrowthMoney.roundDiv(periodGrosz, 6),
        TGBillingPeriod.yearly => GrowthMoney.roundDiv(periodGrosz, 12),
      };
    }
    return GrowthMoney.netFromGross(monthlyGross);
  }

  GrowthPaidPlanCount paidPlanCounts() {
    var b = 0, p = 0, e = 0;
    for (final s in TGBillingService.instance.allStoreSubscriptions()) {
      if (s.status != TGSubscriptionStatus.active) continue;
      if (TGFounderService.instance.founderFor(s.userId).enrolled) continue;
      switch (s.planId) {
        case 'pro':
          p++;
        case 'enterprise':
          e++;
        default:
          b++;
      }
    }
    return GrowthPaidPlanCount(basic: b, pro: p, enterprise: e);
  }

  GrowthScenario scenarioFromConfig() {
    final cfg = PricingConfigService.instance.config;
    return GrowthScenario(
      priceBasicGrosz: cfg.basicStoreMonthlyPln * 100,
      priceProGrosz: cfg.proStoreMonthlyPln * 100,
      priceEnterpriseGrosz: cfg.enterpriseStoreMonthlyPln * 100,
      priceListingGrosz: cfg.defaultListingFeePln * 100,
      pricePromoGrosz: 6000,
      priceRestaurantGrosz: cfg.restaurantFeePln(cfg.defaultRestaurantDays) * 100,
      priceBannerGrosz: cfg.banner.pricePln(cfg.banner.durations.first) * 100,
      priceSponsorGrosz: cfg.sponsorSlot.pricePln(cfg.sponsorSlot.durations.first) * 100,
    );
  }

  GrowthScenario applyCurrentPrices(GrowthScenario s) {
    final base = scenarioFromConfig();
    return s.copyWith(
      priceBasicGrosz: base.priceBasicGrosz,
      priceProGrosz: base.priceProGrosz,
      priceEnterpriseGrosz: base.priceEnterpriseGrosz,
      priceListingGrosz: base.priceListingGrosz,
      priceRestaurantGrosz: base.priceRestaurantGrosz,
      priceBannerGrosz: base.priceBannerGrosz,
      priceSponsorGrosz: base.priceSponsorGrosz,
    );
  }

  void saveScenario(GrowthScenario s, {required FakeAuthState actor}) {
    final id = s.id.isEmpty ? 'sc-${_scenSeq++}' : s.id;
    final next = s.copyWith(id: id);
    final i = _scenarios.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _scenarios[i] = next;
    } else {
      _scenarios.add(next);
    }
    TGAdminConsoleService.instance.log(actor: actor, action: 'scenario_save', targetId: id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Tab 5 — budget
  // ---------------------------------------------------------------------------

  String? phaseIdForDate(DateTime date) {
    final start = _config.programStartDate;
    if (start == null) return _phases.isEmpty ? null : _phases.first.id;
    final months = _monthsBetween(start, date);
    for (final p in _phases) {
      if (months >= p.monthStart && months < p.monthEnd) return p.id;
    }
    return _phases.isNotEmpty ? _phases.last.id : null;
  }

  int spentInPhase(String phaseId) {
    var n = 0;
    for (final e in expenses) {
      if (!e.voided && e.phaseId == phaseId) n += e.netGrosz;
    }
    return n;
  }

  BudgetPhaseView phaseView(BudgetPhase p) {
    final spent = spentInPhase(p.id);
    final bps = p.plannedGrosz <= 0 ? 0 : (spent * 10000) ~/ p.plannedGrosz;
    return BudgetPhaseView(
      phase: p,
      spentGrosz: spent,
      remainingGrosz: p.plannedGrosz - spent,
      usageBps: bps,
      warn80: bps >= 8000,
      warn100: bps >= 10000,
    );
  }

  String? addExpense(GrowthExpense draft, {required FakeAuthState actor}) {
    final phaseId = draft.phaseId.isEmpty ? (phaseIdForDate(draft.date) ?? '') : draft.phaseId;
    final next = GrowthExpense(
      id: 'exp-${_expSeq++}',
      date: draft.date,
      amountGrosz: draft.amountGrosz,
      basis: draft.basis,
      vatGrosz: draft.vatGrosz,
      category: draft.category,
      customCategory: draft.customCategory,
      phaseId: phaseId,
      description: draft.description,
      vendor: draft.vendor,
      invoiceRef: draft.invoiceRef,
      createdBy: actor.userId,
      overrunNote: draft.overrunNote,
    );
    final view = _phases.where((p) => p.id == phaseId).firstOrNull;
    if (view != null) {
      final after = spentInPhase(phaseId) + next.netGrosz;
      if (after > view.plannedGrosz && next.overrunNote.trim().isEmpty) return 'overrun_note_required';
    }
    _expenses.add(next);
    TGAdminConsoleService.instance.log(actor: actor, action: 'budget_expense_add', targetId: next.id);
    TGAnalytics.track('budget_expense_add', {'id': next.id, 'grosz': next.amountGrosz});
    notifyListeners();
    return null;
  }

  String? editExpense(GrowthExpense next, {required FakeAuthState actor}) {
    final i = _expenses.indexWhere((e) => e.id == next.id);
    if (i < 0 || _expenses[i].voided) return 'not_found';
    _expenses[i] = next;
    TGAdminConsoleService.instance.log(actor: actor, action: 'budget_expense_add', targetId: next.id, reason: 'edit');
    notifyListeners();
    return null;
  }

  String? voidExpense(String id, {required String reason, required FakeAuthState actor}) {
    if (reason.trim().isEmpty) return 'reason_required';
    final i = _expenses.indexWhere((e) => e.id == id);
    if (i < 0) return 'not_found';
    _expenses[i] = _expenses[i].copyWith(voided: true, voidReason: reason.trim());
    TGAdminConsoleService.instance.log(actor: actor, action: 'budget_expense_void', targetId: id, reason: reason);
    notifyListeners();
    return null;
  }

  String? commitPhase(String phaseId, {required String note, required FakeAuthState actor}) {
    if (note.trim().isEmpty) return 'reason_required';
    final i = _phases.indexWhere((p) => p.id == phaseId);
    if (i < 0) return 'not_found';
    _phases[i] = _phases[i].copyWith(
      commitment: BudgetCommitment.committed,
      commitNote: note.trim(),
      committedAt: TGClock.now(),
    );
    TGAdminConsoleService.instance.log(actor: actor, action: 'budget_commit', targetId: phaseId, reason: note);
    notifyListeners();
    return null;
  }

  List<GrowthExpense> filteredExpenses({String? phaseId, GrowthExpenseCategory? category, DateTime? from, DateTime? to}) {
    return [
      for (final e in expenses)
        if ((phaseId == null || e.phaseId == phaseId) &&
            (category == null || e.category == category) &&
            (from == null || !e.date.isBefore(from)) &&
            (to == null || e.date.isBefore(to)))
          e,
    ];
  }

  String expensesCsv(List<GrowthExpense> rows) {
    final b = StringBuffer('id,date,amount_grosz,basis,vat_grosz,category,phase,description,vendor,invoice,voided,void_reason\n');
    for (final e in rows) {
      b.writeln(
        [
          e.id,
          e.date.toIso8601String(),
          '${e.amountGrosz}',
          e.basis.name,
          '${e.vatGrosz ?? ''}',
          e.category.name,
          e.phaseId,
          e.description.replaceAll(',', ' '),
          e.vendor.replaceAll(',', ' '),
          e.invoiceRef,
          '${e.voided}',
          e.voidReason.replaceAll(',', ' '),
        ].join(','),
      );
    }
    return b.toString();
  }

  void exportExpensesCsv(FakeAuthState actor, List<GrowthExpense> rows) {
    TGAdminConsoleService.instance.log(actor: actor, action: 'budget_expense_export', targetId: 'csv', details: {'rows': '${rows.length}'});
  }

  List<GrowthCashMonth> cashMonths({int count = 6}) {
    final now = TGClock.now();
    return [
      for (var i = count - 1; i >= 0; i--) _cashMonth(DateTime(now.year, now.month - i, 1)),
    ];
  }

  GrowthCashMonth _cashMonth(DateTime start) {
    final end = DateTime(start.year, start.month + 1, 1);
    final billing = TGBillingService.instance;
    var collected = 0;
    var anyPay = false;
    for (final p in billing.allPayments()) {
      if (p.createdAt.isBefore(start) || !p.createdAt.isBefore(end)) continue;
      if (p.status == TGPaymentStatus.failed) continue;
      anyPay = true;
      collected += collectedGrosz(p, billing.refundedGrosz(p.id)).$2;
    }
    var exp = 0;
    var anyExp = false;
    for (final e in expenses) {
      if (e.voided) continue;
      if (e.date.isBefore(start) || !e.date.isBefore(end)) continue;
      anyExp = true;
      exp += e.netGrosz;
    }
    return GrowthCashMonth(monthStart: start, collectedNetGrosz: collected, expenseNetGrosz: exp, hasSource: anyPay || anyExp);
  }

  int behindCount(GrowthPeriod period) => rowsFor(period).where((r) => r.tempo == GrowthTempo.behind).length;

  // ---------------------------------------------------------------------------
  // Tab 6 — weekly meeting
  // ---------------------------------------------------------------------------

  GrowthWeekAuto weekAuto(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    ReferralRepository.instance.ensureSeeded();
    final signups = <TGReferralSegment, int>{};
    final won = <TGReferralSegment, int>{};
    var signupN = 0;
    var wonN = 0;
    for (final r in ReferralRepository.instance.allRepresentatives()) {
      final row = _weekRow(r, weekStart);
      signupN += row.signups;
      wonN += row.won;
      for (final a in ReferralRepository.instance.rawAccountsFor(r.id)) {
        if (!a.referredAt.isBefore(weekStart) && a.referredAt.isBefore(weekEnd)) {
          signups[a.segment] = (signups[a.segment] ?? 0) + 1;
        }
        final isWon = a.phoneVerified && (a.listings.any((l) => l.qualifiedActive) || a.hasPaidPlan);
        if (isWon) won[a.segment] = (won[a.segment] ?? 0) + 1;
      }
    }

    var listings = 0;
    for (final p in TGProductService.instance.cachedAll) {
      final at = p.publishedAt;
      if (p.isActive && at != null && !at.isBefore(weekStart) && at.isBefore(weekEnd)) listings++;
    }
    if (!_hideMock) {
      for (final r in RestaurantService.instance.all) {
        final at = r.publishedAt;
        if (r.status == RestaurantListingStatus.active && at != null && !at.isBefore(weekStart) && at.isBefore(weekEnd)) listings++;
      }
    }

    const cats = {TGRepContactCategory.corporate, TGRepContactCategory.restaurant, TGRepContactCategory.manufacturer};
    var meets = 0;
    for (final r in ReferralRepository.instance.allRepresentatives()) {
      meets += ReferralRepository.instance.contactsInWeekCats(r.id, weekStart, cats);
    }

    final billing = TGBillingService.instance;
    final monthStart = DateTime(weekStart.year, weekStart.month, 1);
    final paid = <String>{};
    var weekNet = 0, weekGross = 0, mtdNet = 0, mtdGross = 0;
    for (final p in billing.allPayments()) {
      if (p.status == TGPaymentStatus.failed) continue;
      final pair = collectedGrosz(p, billing.refundedGrosz(p.id));
      if (!p.createdAt.isBefore(weekStart) && p.createdAt.isBefore(weekEnd)) {
        weekGross += pair.$1;
        weekNet += pair.$2;
        if (pair.$1 > 0) paid.add(p.userId);
      }
      if (!p.createdAt.isBefore(monthStart) && p.createdAt.isBefore(weekEnd)) {
        mtdGross += pair.$1;
        mtdNet += pair.$2;
      }
    }

    return GrowthWeekAuto(
      signups: signupN,
      won: wonN,
      signupsBySegment: signups,
      wonBySegment: won,
      newActiveListings: listings,
      repMeetings: meets,
      paidCustomers: paid.length,
      weekNetGrosz: weekNet,
      weekGrossGrosz: weekGross,
      mtdNetGrosz: mtdNet,
      mtdGrossGrosz: mtdGross,
    );
  }

  List<GrowthActionItem> openActionsCarried() {
    if (_meetings.isEmpty) return const [];
    final prev = List<GrowthWeeklyMeeting>.from(meetings)..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    if (prev.isEmpty) return const [];
    return [
      for (final a in prev.first.actionItems)
        if (!a.done) GrowthActionItem(id: 'act-${_actSeq++}', text: a.text, owner: a.owner, due: a.due),
    ];
  }

  String? saveMeeting(GrowthWeeklyMeeting draft, {required FakeAuthState actor}) {
    final snap = weekAuto(draft.weekStart);
    final existing = _meetings.indexWhere((m) => m.id == draft.id);
    if (existing >= 0 && _meetings[existing].isLocked(TGClock.now())) return 'locked';
    final held = draft.heldAt;
    final locked = held.add(const Duration(days: 7));
    final id = draft.id.isEmpty ? 'meet-${_meetSeq++}' : draft.id;
    final next = GrowthWeeklyMeeting(
      id: id,
      weekStart: draft.weekStart,
      heldAt: held,
      attendees: draft.attendees,
      q1Note: draft.q1Note,
      q2Note: draft.q2Note,
      q3Note: draft.q3Note,
      q3Override: draft.q3Override,
      q4Note: draft.q4Note,
      q5Problem: draft.q5Problem,
      q5Channel: draft.q5Channel,
      q5Owner: draft.q5Owner,
      decisions: draft.decisions,
      actionItems: draft.actionItems,
      createdBy: actor.userId,
      lockedAt: locked,
      snapshot: snap,
    );
    if (existing >= 0) {
      _meetings[existing] = next;
    } else {
      _meetings.add(next);
    }
    TGAdminConsoleService.instance.log(actor: actor, action: 'meeting_save', targetId: id);
    TGAnalytics.track('meeting_save', {'id': id, 'week': draft.weekStart.toIso8601String()});
    notifyListeners();
    return null;
  }

  String? amendMeeting(String id, String text, {required FakeAuthState actor}) {
    if (text.trim().isEmpty) return 'reason_required';
    final i = _meetings.indexWhere((m) => m.id == id);
    if (i < 0) return 'not_found';
    final m = _meetings[i];
    _meetings[i] = m.copyWith(amendments: [...m.amendments, GrowthMeetAmendment(at: TGClock.now(), by: actor.userId, text: text.trim())]);
    TGAdminConsoleService.instance.log(actor: actor, action: 'meeting_save', targetId: id, reason: 'amendment');
    notifyListeners();
    return null;
  }

  GrowthWeeklyMeeting? meetingForWeek(DateTime weekStart) {
    for (final m in meetings) {
      if (m.weekStart == weekStart) return m;
    }
    return null;
  }

  GrowthWeeklyMeeting? previousMeeting(DateTime weekStart) {
    final prev = weekStart.subtract(const Duration(days: 7));
    return meetingForWeek(prev);
  }
}
