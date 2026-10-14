import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Founding manufacturers program — applications, enrollment, tier discounts.
class TGFounderService extends ChangeNotifier {
  TGFounderService._();
  static final TGFounderService instance = TGFounderService._();

  final Map<String, TGSellerFounder> bySeller = {};
  final List<TGFounderApplication> applications = [];
  final List<TGFounderSavingsEntry> savings = [];
  final Set<String> _notifiedEnds = {};
  bool _seeded = false;
  int _appSeq = 1;
  int _saveSeq = 1;

  /// Optional listing resolver (wired from UI with FakeAuthState.ownedListings).
  List<TGProduct> Function(String sellerId)? listingResolver;

  void reset() {
    bySeller.clear();
    applications.clear();
    savings.clear();
    _notifiedEnds.clear();
    listingResolver = null;
    _seeded = false;
    _appSeq = 1;
    _saveSeq = 1;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedAll();
  }

  TGFounderConfig get cfg => TGRevenueConfigService.instance.config.founder;
  bool get programEnabled => TGRevenueConfigService.instance.flags.founderProgram;

  int get enrolledCount => bySeller.values.where((f) => f.enrolled && f.isInProgram(TGClock.now())).length;
  int get spotsTaken => enrolledCount;
  bool get quotaFull => spotsTaken >= cfg.quota;

  String spotsLabel() {
    final n = spotsTaken;
    if (quotaFull) return 'Applications are on a waitlist';
    if (n >= cfg.counterMinReal) return '$n of ${cfg.quota} spots taken';
    return '${cfg.quota} founding manufacturer spots';
  }

  TGSellerFounder founderFor(String sellerId) {
    ensureSeeded();
    return bySeller[sellerId] ?? const TGSellerFounder();
  }

  TGFounderApplication? applicationFor(String sellerId) {
    ensureSeeded();
    return applications.where((a) => a.sellerId == sellerId).firstOrNull;
  }

  bool nipAlreadyUsed(String nip, {String? exceptSellerId}) {
    ensureSeeded();
    final n = nip.trim();
    for (final f in bySeller.entries) {
      if (exceptSellerId != null && f.key == exceptSellerId) continue;
      if (f.value.nip == n && f.value.enrolled) return true;
    }
    for (final a in applications) {
      if (exceptSellerId != null && a.sellerId == exceptSellerId) continue;
      if (a.nip == n &&
          (a.status == TGFounderApplicationStatus.applied ||
              a.status == TGFounderApplicationStatus.approved ||
              a.status == TGFounderApplicationStatus.waitlisted)) {
        return true;
      }
    }
    return false;
  }

  int listingCompletionPct(TGProduct p) {
    final checks = [
      p.title.trim().length >= 12,
      (p.description ?? '').trim().length >= 40,
      (p.price ?? 0) > 0,
      p.gallery.length >= 3,
      p.city.trim().isNotEmpty,
    ];
    return ((checks.where((e) => e).length / checks.length) * 100).round();
  }

  bool _looksLikeCopy(TGProduct p) => p.title.toUpperCase().contains('COPY');

  TGQualifiedListingInfo evaluateListing(TGProduct p) {
    final reasons = <String>[];
    final pct = listingCompletionPct(p);
    if (pct < 80) reasons.add('founder_reason_completion');
    if (p.gallery.length < 3) reasons.add('founder_reason_photos');
    if (_looksLikeCopy(p)) reasons.add('founder_reason_copy');
    if (p.status == TGListingStatus.removed) reasons.add('founder_reason_removed');
    if (p.status != TGListingStatus.active) reasons.add('founder_reason_inactive');
    return TGQualifiedListingInfo(
      listingId: p.id,
      title: p.title,
      qualified: reasons.isEmpty,
      reasons: reasons,
    );
  }

  List<TGProduct> _listingsFor(String sellerId) {
    final resolved = listingResolver?.call(sellerId);
    if (resolved != null) return resolved;
    return const [];
  }

  List<TGQualifiedListingInfo> evaluateSellerListings(String sellerId, {List<TGProduct>? listings}) {
    final list = listings ?? _listingsFor(sellerId);
    return list.map(evaluateListing).toList();
  }

  int countQualified(String sellerId, {List<TGProduct>? listings}) =>
      evaluateSellerListings(sellerId, listings: listings).where((e) => e.qualified).length;

  void recomputeTier(String sellerId, {List<TGProduct>? listings}) {
    ensureSeeded();
    final f = founderFor(sellerId);
    if (!f.isInProgram(TGClock.now())) return;
    final count = countQualified(sellerId, listings: listings);
    final tier = cfg.tierForQualified(count);
    final prev = f.tier;
    bySeller[sellerId] = f.copyWith(qualifiedCount: count, tier: tier, tierComputedAt: TGClock.now());
    if (tier != prev) {
      TGAnalytics.track('founder_tier_change', {'sellerId': sellerId, 'from': prev, 'to': tier, 'qualified': count});
      if (tier > prev) {
        NotificationService.instance.add(
          userId: sellerId,
          type: 'founder_tier_up',
          dealId: 'founder',
          params: {'pct': '${(cfg.discountForQualified(count) * 100).round()}'},
          deepLink: '/dashboard/manufacturer?tab=programs',
        );
      } else if (tier < prev) {
        NotificationService.instance.add(
          userId: sellerId,
          type: 'founder_tier_down',
          dealId: 'founder',
          params: {'pct': '${tier == 0 ? 0 : (cfg.discountForQualified(count) * 100).round()}'},
          deepLink: '/dashboard/manufacturer?tab=programs',
        );
      }
      if (cfg.freeBoostCreditAt5 && count >= 5 && !f.freeBoostCreditGranted) {
        bySeller[sellerId] = bySeller[sellerId]!.copyWith(freeBoostCreditGranted: true);
      }
      notifyListeners();
    }
  }

  double activeDiscountRate(String sellerId, {List<TGProduct>? listings}) {
    ensureSeeded();
    if (!programEnabled) return 0;
    final f = founderFor(sellerId);
    final now = TGClock.now();
    if (!f.discountActive(now)) return 0;
    if (listings != null) recomputeTier(sellerId, listings: listings);
    final live = founderFor(sellerId);
    return cfg.discountForQualified(live.qualifiedCount);
  }

  int discountedPrice(String sellerId, int listPrice, {List<TGProduct>? listings}) {
    final rate = activeDiscountRate(sellerId, listings: listings);
    if (rate <= 0) return listPrice;
    return (listPrice * (1 - rate)).round();
  }

  ({int list, int paid, double rate}) priceBreakdown(String sellerId, int listPrice, {List<TGProduct>? listings}) {
    final rate = activeDiscountRate(sellerId, listings: listings);
    final paid = rate <= 0 ? listPrice : (listPrice * (1 - rate)).round();
    return (list: listPrice, paid: paid, rate: rate);
  }

  void recordSavings({
    required String sellerId,
    required TGFounderDiscountItem item,
    required int listPrice,
    required int paidPrice,
    required double discountPct,
  }) {
    savings.insert(
      0,
      TGFounderSavingsEntry(
        id: 'fs-${_saveSeq++}',
        sellerId: sellerId,
        at: TGClock.now(),
        item: item,
        listPrice: listPrice,
        paidPrice: paidPrice,
        discountPct: discountPct,
      ),
    );
    TGAnalytics.track('founder_discount_applied', {'sellerId': sellerId, 'item': item.name, 'list': listPrice, 'paid': paidPrice});
    notifyListeners();
  }

  List<TGFounderSavingsEntry> savingsFor(String sellerId) =>
      List.unmodifiable(savings.where((s) => s.sellerId == sellerId));

  String? canApply({
    required String sellerId,
    required String nip,
    required int profilePct,
    required int projects,
    required bool feedbackCallDone,
  }) {
    if (!programEnabled) return 'Program is not open';
    if (nipAlreadyUsed(nip, exceptSellerId: sellerId)) return 'This company already joined the program';
    if (profilePct < 80) return 'Profile completion must be at least 80%';
    if (projects < 3) return 'At least 3 reference projects required';
    if (!feedbackCallDone) return 'Feedback call required';
    final existing = applicationFor(sellerId);
    if (existing != null &&
        (existing.status == TGFounderApplicationStatus.applied || existing.status == TGFounderApplicationStatus.approved)) {
      return 'Application already submitted';
    }
    return null;
  }

  TGFounderApplication apply({
    required String sellerId,
    required String nip,
    required String companyName,
    required int profilePct,
    required int projects,
    required DateTime feedbackCallAt,
    required bool understood,
  }) {
    ensureSeeded();
    if (!understood) throw StateError('Consent required');
    final err = canApply(
      sellerId: sellerId,
      nip: nip,
      profilePct: profilePct,
      projects: projects,
      feedbackCallDone: true,
    );
    if (err != null) throw StateError(err);
    final status = quotaFull ? TGFounderApplicationStatus.waitlisted : TGFounderApplicationStatus.applied;
    final app = TGFounderApplication(
      id: 'FA-${_appSeq++}',
      sellerId: sellerId,
      nip: nip.trim(),
      companyName: companyName,
      status: status,
      profileCompletePct: profilePct,
      referenceProjectsCount: projects,
      feedbackCallDone: true,
      feedbackCallAt: feedbackCallAt,
      createdAt: TGClock.now(),
    );
    applications.insert(0, app);
    NotificationService.instance.add(
      userId: sellerId,
      type: 'founder_applied',
      dealId: app.id,
      bodyKey: status == TGFounderApplicationStatus.waitlisted
          ? 'notif_founder_applied_waitlist_body'
          : 'notif_founder_applied_body',
      deepLink: '/dashboard/manufacturer?tab=programs',
    );
    TGAnalytics.track('founder_apply', {'sellerId': sellerId, 'status': status.name});
    notifyListeners();
    return app;
  }

  void decide({
    required String applicationId,
    required TGFounderApplicationStatus status,
    required String actorId,
    required String note,
    FakeAuthState? auth,
  }) {
    ensureSeeded();
    final i = applications.indexWhere((a) => a.id == applicationId);
    if (i < 0) return;
    final app = applications[i];
    if (status == TGFounderApplicationStatus.approved && quotaFull && !founderFor(app.sellerId).enrolled) {
      applications[i] = app.copyWith(
        status: TGFounderApplicationStatus.waitlisted,
        decidedAt: TGClock.now(),
        decisionNote: 'Quota full — waitlisted',
      );
      notifyListeners();
      return;
    }
    applications[i] = app.copyWith(status: status, decidedAt: TGClock.now(), decisionNote: note);
    if (status == TGFounderApplicationStatus.approved) {
      enrollApproved(app.sellerId, nip: app.nip, auth: auth);
      NotificationService.instance.add(
        userId: app.sellerId,
        type: 'founder_approved',
        dealId: app.id,
        deepLink: '/dashboard/manufacturer?tab=programs',
      );
    } else if (app.status == TGFounderApplicationStatus.approved && status != TGFounderApplicationStatus.approved) {
      // Undo / reverse approval — clear enrollment.
      bySeller[app.sellerId] = const TGSellerFounder();
    }
    if (status == TGFounderApplicationStatus.rejected) {
      NotificationService.instance.add(
        userId: app.sellerId,
        type: 'founder_rejected',
        dealId: app.id,
        deepLink: '/founders',
      );
    } else if (status == TGFounderApplicationStatus.waitlisted) {
      NotificationService.instance.add(
        userId: app.sellerId,
        type: 'founder_waitlisted',
        dealId: app.id,
        deepLink: '/dashboard/manufacturer?tab=programs',
      );
    }
    TGAnalytics.track('founder_decision', {'id': applicationId, 'status': status.name, 'actor': actorId});
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config,
      actorId: actorId,
      action: 'founder_decision',
      reason: note,
      detail: '$applicationId → ${status.name}',
    );
    notifyListeners();
  }

  void enrollApproved(String sellerId, {required String nip, FakeAuthState? auth}) {
    final now = TGClock.now();
    final ends = DateTime(now.year, now.month + cfg.programMonths, now.day);
    final free = DateTime(now.year, now.month + cfg.freeMonths, now.day);
    bySeller[sellerId] = TGSellerFounder(
      enrolled: true,
      enrolledAt: now,
      programEndsAt: ends,
      nip: nip,
      freeUntil: free,
      qualifiedCount: 0,
      tier: 0,
      tierComputedAt: now,
    );
    if (auth != null && auth.userId == sellerId) {
      auth.subscribeStore('pro');
    }
    final profile = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (profile != null) {
      TGSellerProfileService.instance.patch(
        profile.publicId,
        (p) => p.copyWith(
          plan: TGStorePlanKind.pro,
          verified: true,
          nip: p.nip ?? nip,
          nipVerifiedAt: p.nipVerifiedAt ?? now,
        ),
      );
      if (TGRevenueConfigService.instance.flags.priorityForSale) {
        final specialty = profile.specialties.firstOrNull ?? TGStoreSpecialty.worktopsTables;
        TGPriorityService.instance.grantFounderFree(
          sellerId: sellerId,
          freeUntil: free,
          segments: [TGPrioritySegment(specialty: specialty, region: profile.voivodeship, seat: true)],
        );
      }
    }
    notifyListeners();
  }

  void setTierManual({required String sellerId, required int tier, required String actorId, required String reason}) {
    ensureSeeded();
    final f = founderFor(sellerId);
    if (!f.enrolled) return;
    bySeller[sellerId] = f.copyWith(tier: tier.clamp(0, cfg.tiers.length), tierComputedAt: TGClock.now());
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config,
      actorId: actorId,
      action: 'founder_tier_override',
      reason: reason,
      detail: '$sellerId tier=$tier',
    );
    notifyListeners();
  }

  void endProgram({required String sellerId, required String actorId, required String reason}) {
    ensureSeeded();
    final f = founderFor(sellerId);
    bySeller[sellerId] = f.copyWith(programEndsAt: TGClock.now());
    NotificationService.instance.add(
      userId: sellerId,
      type: 'founder_ended',
      dealId: 'founder',
      deepLink: '/dashboard/manufacturer?tab=programs',
    );
    TGAnalytics.track('founder_program_end', {'sellerId': sellerId, 'actor': actorId});
    notifyListeners();
  }

  void extendProgram({required String sellerId, required int days, required String actorId, required String reason}) {
    ensureSeeded();
    final f = founderFor(sellerId);
    if (f.programEndsAt == null) return;
    bySeller[sellerId] = f.copyWith(programEndsAt: f.programEndsAt!.add(Duration(days: days)));
    notifyListeners();
  }

  void onClockAdvanced() {
    ensureSeeded();
    final now = TGClock.now();
    for (final e in bySeller.entries.toList()) {
      final f = e.value;
      if (!f.enrolled || f.programEndsAt == null) continue;
      final ends = f.programEndsAt!;
      final daysLeft = ends.difference(now).inDays;
      if (daysLeft == 30 && _notifiedEnds.add('${e.key}-30')) {
        NotificationService.instance.add(
          userId: e.key,
          type: 'founder_ending',
          dealId: 'founder',
          params: {'n': '30', 'date': fmtDate(ends)},
          deepLink: '/dashboard/manufacturer?tab=programs',
        );
      }
      if (daysLeft == 7 && _notifiedEnds.add('${e.key}-7')) {
        NotificationService.instance.add(
          userId: e.key,
          type: 'founder_ending',
          dealId: 'founder',
          params: {'n': '7', 'date': fmtDate(ends)},
          deepLink: '/dashboard/manufacturer?tab=programs',
        );
      }
      if (f.freeUntil != null) {
        final freeLeft = f.freeUntil!.difference(now).inDays;
        if (freeLeft == 7 && _notifiedEnds.add('${e.key}-free7')) {
          NotificationService.instance.add(
            userId: e.key,
            type: 'founder_free_ending',
            dealId: 'founder',
            deepLink: '/dashboard/manufacturer?tab=programs',
          );
        }
      }
      if (!now.isBefore(ends) && _notifiedEnds.add('${e.key}-end')) {
        NotificationService.instance.add(
          userId: e.key,
          type: 'founder_ended',
          dealId: 'founder',
          deepLink: '/dashboard/manufacturer?tab=programs',
        );
        TGAnalytics.track('founder_program_end', {'sellerId': e.key});
      }
    }
  }

  static String fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  ({int founders, int qualifiedListings, int discountSales, int listTotal, int paidTotal}) report() {
    ensureSeeded();
    var qualified = 0;
    for (final e in bySeller.entries) {
      if (e.value.isInProgram(TGClock.now())) qualified += e.value.qualifiedCount;
    }
    return (
      founders: enrolledCount,
      qualifiedListings: qualified,
      discountSales: savings.length,
      listTotal: savings.fold<int>(0, (a, s) => a + s.listPrice),
      paidTotal: savings.fold<int>(0, (a, s) => a + s.paidPrice),
    );
  }

  void _seedAll() {
    final now = TGClock.now();
    void enrollSeed(String id, String nip, int monthsAgo, int qualified, int tier, {bool ended = false}) {
      final enrolledAt = DateTime(now.year, now.month - monthsAgo, now.day.clamp(1, 28));
      final ends = DateTime(enrolledAt.year, enrolledAt.month + cfg.programMonths, enrolledAt.day);
      final free = DateTime(enrolledAt.year, enrolledAt.month + cfg.freeMonths, enrolledAt.day);
      bySeller[id] = TGSellerFounder(
        enrolled: true,
        enrolledAt: enrolledAt,
        programEndsAt: ended ? now.subtract(const Duration(days: 5)) : ends,
        nip: nip,
        freeUntil: free,
        qualifiedCount: qualified,
        tier: tier,
        tierComputedAt: now,
      );
      applications.add(TGFounderApplication(
        id: 'FA-seed-$id',
        sellerId: id,
        nip: nip,
        companyName: TGSellerProfileService.instance.bySellerKey(id)?.name,
        status: TGFounderApplicationStatus.approved,
        profileCompletePct: 90,
        referenceProjectsCount: 4,
        feedbackCallDone: true,
        createdAt: enrolledAt.subtract(const Duration(days: 3)),
        decidedAt: enrolledAt,
        decisionNote: 'Seed approve',
      ));
    }

    // monthsAgo >= freeMonths → past free window → tier discount can apply.
    enrollSeed('seller_inoxline', '5252341134', 3, 6, 1);
    enrollSeed('seller_gastropl', '5261040828', 4, 11, 2);
    enrollSeed('seller_metalgast', '9451975812', 1, 3, 0);
    enrollSeed('seller_stalbar', '6793087624', 0, 8, 1);
    enrollSeed('seller_nordinox', '1130000458', 7, 5, 1, ended: true);

    applications.add(TGFounderApplication(
      id: 'FA-app-1',
      sellerId: 'seller_primegastro',
      nip: '7010000001',
      companyName: 'PrimeGastro',
      status: TGFounderApplicationStatus.applied,
      profileCompletePct: 82,
      referenceProjectsCount: 3,
      feedbackCallDone: true,
      createdAt: now.subtract(const Duration(days: 1)),
    ));
    applications.add(TGFounderApplication(
      id: 'FA-app-2',
      sellerId: 'seller_ek',
      nip: '7010000002',
      companyName: 'EK',
      status: TGFounderApplicationStatus.applied,
      profileCompletePct: 88,
      referenceProjectsCount: 5,
      feedbackCallDone: true,
      createdAt: now.subtract(const Duration(hours: 10)),
    ));
    applications.add(TGFounderApplication(
      id: 'FA-rej-1',
      sellerId: 'seller_technica',
      nip: '5252341134',
      companyName: 'Technica',
      status: TGFounderApplicationStatus.rejected,
      profileCompletePct: 70,
      referenceProjectsCount: 1,
      feedbackCallDone: false,
      createdAt: now.subtract(const Duration(days: 4)),
      decidedAt: now.subtract(const Duration(days: 3)),
      decisionNote: 'Duplicate NIP',
    ));
    applications.add(TGFounderApplication(
      id: 'FA-wait-1',
      sellerId: 'seller_oldkitchen',
      nip: '7010000099',
      companyName: 'OldKitchen',
      status: TGFounderApplicationStatus.waitlisted,
      profileCompletePct: 85,
      referenceProjectsCount: 3,
      feedbackCallDone: true,
      createdAt: now.subtract(const Duration(days: 2)),
      decidedAt: now.subtract(const Duration(days: 1)),
      decisionNote: 'Quota full',
    ));
  }
}
