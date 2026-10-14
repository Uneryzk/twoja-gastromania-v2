import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Single isolation layer for representative data.
///
/// **This is only a UI filter, not real security; production requires
/// server-side authorization.** Every seller/report/log query takes [repId]
/// and is filtered here. Phone, email, address, messages, payment method and
/// invoices never leave this class on representative DTOs.
class ReferralRepository extends ChangeNotifier {
  ReferralRepository._();
  static final ReferralRepository instance = ReferralRepository._();

  TGReferralConfig config = const TGReferralConfig();

  final List<TGRepresentative> _reps = [];
  final Map<String, TGReferredAccount> _accounts = {};
  final List<TGRepPerformanceReport> _reports = [];
  final List<TGRepShareLink> _links = [];
  final List<TGRepWeeklyLog> _logs = [];
  final List<TGReferralAudit> audit = [];
  final List<DateTime> _failedChecks = [];

  /// In-memory register-session only — no persistent cookie.
  String sessionCode = '';
  bool sessionConsent = false;

  int _seq = 1;
  bool _seeded = false;
  final Set<String> _signedUpUserIds = {};

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  /// Seed / debug writers: debug builds only, and never in Production Mode.
  bool get _allowDevReferralWrites => kDebugMode && !_hideMock;

  void reset() {
    _reps.clear();
    _accounts.clear();
    _reports.clear();
    _links.clear();
    _logs.clear();
    audit.clear();
    _failedChecks.clear();
    selfReferralAttempts.clear();
    _clusterByUser.clear();
    sessionCode = '';
    sessionConsent = false;
    _seq = 1;
    _seeded = false;
    _signedUpUserIds.clear();
    config = const TGReferralConfig();
    notifyListeners();
  }

  void ensureSeeded() {
    if (!_allowDevReferralWrites) return;
    if (_seeded) return;
    _seeded = true;
    _seedMocks();
  }

  @visibleForTesting
  void debugAddRep(TGRepresentative r) {
    if (!_allowDevReferralWrites) return;
    _reps.add(r);
  }

  @visibleForTesting
  void debugAddAccount(TGReferredAccount a) {
    if (!_allowDevReferralWrites) return;
    _accounts[a.userId] = a;
    _signedUpUserIds.add(a.userId);
  }

  /// Account already completed signup — referral cannot be attached later.
  bool isSignupLocked(String userId) {
    if (userId.isEmpty) return false;
    if (_accounts.containsKey(userId)) return true;
    return _signedUpUserIds.contains(userId);
  }

  // ---------------------------------------------------------------------------
  // Code normalisation
  // ---------------------------------------------------------------------------

  static const _fold = {
    'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
    'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N', 'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
    'ü': 'u', 'ö': 'o', 'ä': 'a', 'ß': 'ss', 'Ü': 'U', 'Ö': 'O', 'Ä': 'A',
    'ı': 'i', 'İ': 'I', 'ğ': 'g', 'Ğ': 'G', 'ş': 's', 'Ş': 'S', 'ç': 'c', 'Ç': 'C',
  };

  /// Polish (and similar) letters → ASCII; keep letters, digits, hyphen.
  static String foldCode(String raw) {
    final buf = StringBuffer();
    for (final r in raw.trim().runes) {
      final ch = String.fromCharCode(r);
      final mapped = _fold[ch] ?? ch;
      for (final u in mapped.runes) {
        final c = String.fromCharCode(u);
        if (RegExp(r'[A-Za-z0-9-]').hasMatch(c)) buf.write(c);
      }
    }
    return buf.toString();
  }

  static String codeKey(String raw) => foldCode(raw).toLowerCase();

  static bool isValidShape(String folded) => RegExp(r'^[A-Za-z0-9-]{4,24}$').hasMatch(folded);

  bool isCodeTaken(String raw, {String? exceptRepId}) {
    final key = codeKey(raw);
    return _reps.any((r) => codeKey(r.code) == key && r.id != exceptRepId);
  }

  // ---------------------------------------------------------------------------
  // Session + live check
  // ---------------------------------------------------------------------------

  void setSessionCode(String raw) {
    sessionCode = foldCode(raw);
    notifyListeners();
  }

  void setSessionConsent(bool value) {
    sessionConsent = value;
    notifyListeners();
  }

  void clearSession() {
    sessionCode = '';
    sessionConsent = false;
    notifyListeners();
  }

  TGReferralCodeCheck checkCode(String raw, {bool recordFailure = true, String? applicantUserId}) {
    if (applicantUserId != null && applicantUserId.isNotEmpty && isSignupLocked(applicantUserId)) {
      return const TGReferralCodeCheck(result: TGReferralCodeResult.signupOnly);
    }
    final now = TGClock.now();
    _failedChecks.removeWhere((t) => now.difference(t) > const Duration(hours: 1));
    if (_failedChecks.length >= config.maxFailedChecksPerHour) {
      return const TGReferralCodeCheck(result: TGReferralCodeResult.rateLimited);
    }
    final folded = foldCode(raw);
    if (!isValidShape(folded)) {
      if (recordFailure) _failedChecks.add(now);
      return const TGReferralCodeCheck(result: TGReferralCodeResult.unrecognized);
    }
    final key = folded.toLowerCase();
    TGRepresentative? hit;
    for (final r in _visibleReps) {
      if (codeKey(r.code) == key) {
        hit = r;
        break;
      }
    }
    if (hit == null || hit.status != TGRepStatus.active) {
      if (recordFailure) _failedChecks.add(now);
      return const TGReferralCodeCheck(result: TGReferralCodeResult.unrecognized);
    }
    TGAnalytics.track('referral_code_entered', {'repId': hit.id});
    return TGReferralCodeCheck(result: TGReferralCodeResult.valid, firstName: hit.firstName, rep: hit);
  }

  // ---------------------------------------------------------------------------
  // Signup / user fields
  // ---------------------------------------------------------------------------

  /// Applies the session code only when this call is the real new-account
  /// create of [userId]. Existing assignment / prior signup is a silent no-op.
  /// Consent is written in the same step as the assignment — never before.
  TGReferredAccount? applySessionOnSignup({
    required String userId,
    required String displayName,
    required TGReferralSegment segment,
    String email = '',
    String phone = '',
    bool phoneVerified = false,
    bool accountCreatedThisSession = false,
  }) {
    if (!accountCreatedThisSession) return null;
    ensureSeeded();
    if (isSignupLocked(userId) || _accounts.containsKey(userId)) return null;
    if (!sessionConsent || sessionCode.isEmpty) {
      _signedUpUserIds.add(userId);
      clearSession();
      return null;
    }
    final checked = checkCode(sessionCode, recordFailure: false);
    if (checked.result != TGReferralCodeResult.valid || checked.rep == null) {
      _signedUpUserIds.add(userId);
      clearSession();
      return null;
    }
    final rep = checked.rep!;
    if (_isSelfReferral(rep, userId: userId, email: email, phone: phone)) {
      noteSelfReferralAttempt();
      _signedUpUserIds.add(userId);
      clearSession();
      return null;
    }
    final now = TGClock.now();
    final acc = TGReferredAccount(
      userId: userId,
      displayName: displayName,
      segment: segment,
      referredByCode: rep.code,
      referredByRepId: rep.id,
      referredAt: now,
      referralConsentAt: now,
      email: email,
      phone: phone,
      phoneVerified: phoneVerified,
    );
    _accounts[userId] = acc;
    _signedUpUserIds.add(userId);
    TGAnalytics.track('referral_signup_success', {'repId': rep.id, 'userId': userId});
    clearSession();
    notifyListeners();
    return acc;
  }

  bool _isSelfReferral(TGRepresentative rep, {required String userId, required String email, required String phone}) {
    if (userId.isNotEmpty && userId == rep.userId) return true;
    final e = email.trim().toLowerCase();
    if (e.isNotEmpty && e == rep.email.trim().toLowerCase()) return true;
    final p = phone.replaceAll(RegExp(r'\D'), '');
    final rp = rep.phone.replaceAll(RegExp(r'\D'), '');
    if (p.length >= 9 && rp.length >= 9 && p == rp) return true;
    return false;
  }

  /// Admin-only correction. Existing assignment is rewritten; reason is required.
  String? adminCorrectReferral({
    required String userId,
    required String actorId,
    required String reason,
    String? newCode,
  }) {
    if (reason.trim().isEmpty) return 'reason_required';
    final prev = _accounts[userId];
    if (newCode == null || newCode.trim().isEmpty) {
      _accounts.remove(userId);
      _audit(actorId, 'referral_admin_clear', detail: userId, reason: reason);
      notifyListeners();
      return null;
    }
    final checked = checkCode(newCode, recordFailure: false);
    if (checked.result != TGReferralCodeResult.valid || checked.rep == null) return 'code_unrecognized';
    final now = TGClock.now();
    _accounts[userId] = (prev ??
            TGReferredAccount(
              userId: userId,
              displayName: userId,
              segment: TGReferralSegment.individual,
              referredByCode: checked.rep!.code,
              referredByRepId: checked.rep!.id,
              referredAt: now,
              referralConsentAt: now,
            ))
        .copyWith(
          referredByCode: checked.rep!.code,
          referredByRepId: checked.rep!.id,
          referredAt: prev?.referredAt ?? now,
        );
    _audit(actorId, 'referral_admin_correct', detail: '$userId→${checked.rep!.code}', reason: reason);
    notifyListeners();
    return null;
  }

  void setVisibility(String userId, TGReferralVisibility visibility) {
    final acc = _accounts[userId];
    if (acc == null) return;
    _accounts[userId] = acc.copyWith(referralVisibility: visibility);
    notifyListeners();
  }

  TGReferredAccount? accountOf(String userId) {
    final acc = _accounts[userId];
    if (acc == null) return null;
    if (_hideMock && acc.isMock) return null;
    return acc;
  }

  // ---------------------------------------------------------------------------
  // Representatives
  // ---------------------------------------------------------------------------

  Iterable<TGRepresentative> get _visibleReps sync* {
    for (final r in _reps) {
      if (_hideMock && r.isMock) continue;
      yield r;
    }
  }

  TGRepresentative? profileForUser(String userId) {
    ensureSeeded();
    for (final r in _visibleReps) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  TGRepresentative? byId(String id) {
    ensureSeeded();
    for (final r in _visibleReps) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<TGRepresentative> allRepresentatives() {
    ensureSeeded();
    return _visibleReps.toList();
  }

  final List<DateTime> selfReferralAttempts = [];
  final Map<String, String> _clusterByUser = {};

  TGRepresentative? addRepresentative({
    required String displayName,
    required TGRepRole role,
    String? code,
    String email = '',
    String phone = '',
  }) {
    ensureSeeded();
    final folded = foldCode(code ?? suggestCode(displayName, role));
    if (!isValidShape(folded) || isCodeTaken(folded)) return null;
    final id = 'rep-${_seq++}';
    final rep = TGRepresentative(
      id: id,
      userId: id,
      displayName: displayName,
      role: role,
      code: folded,
      status: TGRepStatus.active,
      createdAt: TGClock.now(),
      email: email,
      phone: phone,
    );
    _reps.add(rep);
    notifyListeners();
    return rep;
  }

  String suggestCode(String displayName, TGRepRole role) {
    final first = foldCode(displayName.trim().split(RegExp(r'\s+')).first);
    final tag = switch (role) {
      TGRepRole.individualPortfolio => 'IND',
      TGRepRole.corporateRelations => 'CORP',
      TGRepRole.platformOperations => 'OPS',
    };
    final year = '${TGClock.now().year}';
    var code = '$first-$tag$year';
    var n = 2;
    while (isCodeTaken(code)) {
      code = '$first-$tag$year$n';
      n++;
    }
    return code;
  }

  bool setRepStatus(String repId, TGRepStatus status) {
    final i = _reps.indexWhere((r) => r.id == repId);
    if (i < 0) return false;
    if (_hideMock && _reps[i].isMock) return false;
    _reps[i] = _reps[i].copyWith(status: status);
    notifyListeners();
    return true;
  }

  List<TGReferredAccount> rawAccountsFor(String repId) {
    ensureSeeded();
    return [
      for (final a in _accounts.values)
        if (a.referredByRepId == repId && !(_hideMock && a.isMock)) a,
    ];
  }

  List<TGRepWeeklyLog> logsFor(String repId) {
    ensureSeeded();
    if (byId(repId) == null) return const [];
    return [for (final l in _logs) if (l.repId == repId) l]..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  }

  int contactsInWeek(String repId, DateTime weekStart) {
    final log = weeklyLogFor(repId, at: weekStart);
    var n = 0;
    for (final v in log.contacts.values) {
      n += v;
    }
    return n;
  }

  int contactsInWeekCats(String repId, DateTime weekStart, Set<TGRepContactCategory> cats) {
    final log = weeklyLogFor(repId, at: weekStart);
    var n = 0;
    for (final c in cats) {
      n += log.contacts[c] ?? 0;
    }
    return n;
  }

  void noteSelfReferralAttempt() => selfReferralAttempts.add(TGClock.now());

  @visibleForTesting
  void debugSetCluster(String userId, String cluster) => _clusterByUser[userId] = cluster;

  List<GrowthAttrFlag> attributionFlags() {
    ensureSeeded();
    final now = TGClock.now();
    final flags = <GrowthAttrFlag>[];
    final byCluster = <String, int>{};
    for (final e in _clusterByUser.entries) {
      final acc = _accounts[e.key];
      if (acc == null || (_hideMock && acc.isMock)) continue;
      byCluster[e.value] = (byCluster[e.value] ?? 0) + 1;
    }
    for (final e in byCluster.entries) {
      if (e.value >= 3) flags.add(GrowthAttrFlag(kind: GrowthAttrFlagKind.sameCluster, detail: e.key));
    }
    for (final a in _accounts.values) {
      if (_hideMock && a.isMock) continue;
      if (a.listings.isEmpty && now.difference(a.referredAt) >= const Duration(days: 14)) {
        flags.add(GrowthAttrFlag(kind: GrowthAttrFlagKind.noListingAfter14d, detail: a.userId));
      }
    }
    if (selfReferralAttempts.where((t) => now.difference(t) < const Duration(hours: 24)).isNotEmpty) {
      flags.add(const GrowthAttrFlag(kind: GrowthAttrFlagKind.selfReferral, detail: 'self_referral'));
    }
    final hour = _accounts.values.where((a) => !(_hideMock && a.isMock) && now.difference(a.referredAt) < const Duration(hours: 1)).length;
    if (hour >= 5) flags.add(GrowthAttrFlag(kind: GrowthAttrFlagKind.burstSignups, detail: '$hour'));
    return flags;
  }

  // ---------------------------------------------------------------------------
  // Isolated queries — always take [repId]
  // ---------------------------------------------------------------------------

  /// Sellers this representative may see. Withdrawn rows are omitted.
  List<TGRepSellerRow> sellersFor(String repId) {
    ensureSeeded();
    if (byId(repId) == null) return const [];
    final out = <TGRepSellerRow>[];
    for (final acc in _accounts.values) {
      if (acc.referredByRepId != repId) continue;
      if (_hideMock && acc.isMock) continue;
      if (acc.referralVisibility != TGReferralVisibility.on) continue;
      out.add(_rowOf(acc));
    }
    out.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    return out;
  }

  int withdrawnCountFor(String repId) {
    ensureSeeded();
    if (byId(repId) == null) return 0;
    var n = 0;
    for (final acc in _accounts.values) {
      if (acc.referredByRepId != repId) continue;
      if (_hideMock && acc.isMock) continue;
      if (acc.referralVisibility == TGReferralVisibility.withdrawn) n++;
    }
    return n;
  }

  TGRepFunnelSummary funnelFor(String repId) {
    ensureSeeded();
    if (byId(repId) == null) return const TGRepFunnelSummary();
    final week = warsawWeekStart(TGClock.now());
    var registered = 0, phone = 0, qualified = 0, paid = 0, weekly = 0, withdrawn = 0;
    for (final acc in _accounts.values) {
      if (acc.referredByRepId != repId) continue;
      if (_hideMock && acc.isMock) continue;
      registered++;
      if (acc.referralVisibility == TGReferralVisibility.withdrawn) {
        withdrawn++;
        continue;
      }
      if (acc.phoneVerified) phone++;
      if (_hasQualified(acc)) qualified++;
      if (_isPaid(acc)) paid++;
      if (!acc.referredAt.isBefore(week)) weekly++;
    }
    return TGRepFunnelSummary(
      registered: registered,
      phoneVerified: phone,
      firstQualifiedListing: qualified,
      paid: paid,
      weeklySignups: weekly,
      withdrawnCount: withdrawn,
    );
  }

  int weeklySignupsFor(String repId) => funnelFor(repId).weeklySignups;

  TGRepSellerRow _rowOf(TGReferredAccount acc) {
    final stats = _stats(acc, days: 30);
    final coverage = _coverageDays(acc, days: 30);
    final events = stats.views + stats.callTaps + stats.messages + stats.favorites;
    return TGRepSellerRow(
      userId: acc.userId,
      publicName: publicDisplayName(acc.displayName, acc.segment),
      registeredAt: acc.referredAt,
      segment: acc.segment,
      planLabel: acc.hasPaidPlan ? 'Paid plan' : 'Free',
      status: _statusOf(acc),
      listingCount: acc.listings.length,
      qualifiedActiveCount: acc.listings.where((l) => l.qualifiedActive).length,
      views30: stats.views,
      callTaps30: stats.callTaps,
      messages30: stats.messages,
      favorites30: stats.favorites,
      attributedNetGrosz: attributedNetGrosz(acc.userId),
      enoughEngagement: coverage >= TGListingStatsService.minDays && events > 0,
    );
  }

  TGRepSellerStatus _statusOf(TGReferredAccount acc) {
    if (_isPaid(acc)) return TGRepSellerStatus.paid;
    if (_isWon(acc)) return TGRepSellerStatus.won;
    if (acc.phoneVerified) return TGRepSellerStatus.phoneVerified;
    return TGRepSellerStatus.registered;
  }

  bool _hasQualified(TGReferredAccount acc) => acc.listings.any((l) => l.qualifiedActive);
  bool _isWon(TGReferredAccount acc) => acc.phoneVerified && (_hasQualified(acc) || acc.hasPaidPlan);
  bool _isPaid(TGReferredAccount acc) => acc.hasPaidPlan || _hasCollectedPayment(acc.userId);

  bool _hasCollectedPayment(String userId) {
    for (final p in TGBillingService.instance.paymentsFor(userId)) {
      if (p.status == TGPaymentStatus.succeeded) return true;
    }
    return false;
  }

  ListingStatsTotals _stats(TGReferredAccount acc, {required int days}) {
    final keys = [for (final l in acc.listings) TGListingStatsService.productKey(l.id)];
    return TGListingStatsService.instance.totalsFor(keys, days: days);
  }

  int _coverageDays(TGReferredAccount acc, {required int days}) {
    var best = 0;
    for (final l in acc.listings) {
      final d = TGListingStatsService.instance.coverageDays(TGListingStatsService.productKey(l.id), days: days);
      if (d > best) best = d;
    }
    return best;
  }

  /// Collected, refunds deducted, VAT excluded, last [config.attributionRevenueMonths].
  /// Integer grosz only — never float.
  int? attributedNetGrosz(String sellerUserId) {
    final months = config.attributionRevenueMonths;
    final now = TGClock.now();
    final from = DateTime(now.year, now.month - months, now.day);
    var net = 0;
    var any = false;
    final billing = TGBillingService.instance;
    for (final p in billing.paymentsFor(sellerUserId)) {
      if (p.status != TGPaymentStatus.succeeded && p.status != TGPaymentStatus.refunded) continue;
      if (p.createdAt.isBefore(from)) continue;
      any = true;
      final refunded = billing.refundedGrosz(p.id);
      final remainGross = (p.amount.grossGr - refunded).clamp(0, p.amount.grossGr);
      net += GrowthMoney.remainNet(p.amount.netGr, remainGross, p.amount.grossGr);
    }
    if (!any) return null;
    return net;
  }

  static String publicDisplayName(String name, TGReferralSegment segment) {
    if (segment != TGReferralSegment.individual) return name;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name;
    final last = parts.last;
    final initial = last.isEmpty ? '' : '${last.substring(0, 1)}.';
    return '${parts.first} $initial'.trim();
  }

  // ---------------------------------------------------------------------------
  // Reports + share links
  // ---------------------------------------------------------------------------

  TGRepPerformanceReport? createReport({
    required String repId,
    required String sellerUserId,
    required int periodDays,
    required String actorId,
  }) {
    ensureSeeded();
    if (byId(repId) == null) return null;
    final acc = _accounts[sellerUserId];
    if (acc == null || acc.referredByRepId != repId) return null;
    if (acc.referralVisibility != TGReferralVisibility.on) return null;
    if (_hideMock && acc.isMock) return null;

    final days = periodDays == 90 ? 90 : 30;
    final now = TGClock.now();
    final from = DateTime(now.year, now.month, now.day - (days - 1));
    final stats = _stats(acc, days: days);
    final coverage = _coverageDays(acc, days: days);
    final events = stats.views + stats.callTaps + stats.messages + stats.favorites;
    final enough = coverage >= TGListingStatsService.minDays && events > 0;

    TGRefListingMeta? top;
    var topViews = -1;
    if (enough) {
      for (final l in acc.listings) {
        final v = TGListingStatsService.instance.totals(TGListingStatsService.productKey(l.id), days: days).views;
        if (v > topViews) {
          topViews = v;
          top = l;
        }
      }
    }

    TGRepMetric<int> metric(int n) => enough ? TGRepMetric.value(n) : const TGRepMetric.notEnough();

    final report = TGRepPerformanceReport(
      id: 'rpt-${_seq++}',
      repId: repId,
      sellerUserId: sellerUserId,
      periodDays: days,
      from: from,
      to: now,
      snapshotAt: now,
      listingCount: metric(acc.listings.length),
      views: metric(stats.views),
      callTaps: metric(stats.callTaps),
      messages: metric(stats.messages),
      favorites: metric(stats.favorites),
      topListingTitle: enough ? top?.title : null,
      topListingNo: enough ? top?.listingNo : null,
    );
    _reports.add(report);
    TGAnalytics.track('rep_report_created', {'repId': repId, 'sellerUserId': sellerUserId, 'period': days});
    _audit(actorId, 'rep_report_created', detail: report.id);
    notifyListeners();
    return report;
  }

  List<TGRepPerformanceReport> reportsFor(String repId) {
    if (byId(repId) == null) return const [];
    return [for (final r in _reports) if (r.repId == repId) r];
  }

  TGRepShareLink? createShareLink({required String reportId, required String actorId}) {
    final report = _reports.where((r) => r.id == reportId).firstOrNull;
    if (report == null || byId(report.repId) == null) return null;
    final now = TGClock.now();
    final link = TGRepShareLink(
      token: _token128(),
      reportId: report.id,
      repId: report.repId,
      sellerUserId: report.sellerUserId,
      createdAt: now,
      expiresAt: now.add(Duration(days: config.shareLinkDays)),
    );
    _links.add(link);
    _audit(actorId, 'rep_report_link_created', detail: link.token);
    notifyListeners();
    return link;
  }

  TGRepShareLink? openShareLink(String token) {
    final link = _links.where((l) => l.token == token).firstOrNull;
    if (link == null) return null;
    final now = TGClock.now();
    if (!link.isActive(now)) return null;
    _audit('public', 'rep_report_link_opened', detail: token);
    return link;
  }

  TGRepPerformanceReport? reportById(String id) => _reports.where((r) => r.id == id).firstOrNull;

  bool revokeShareLink({required String token, required String actorId}) {
    final i = _links.indexWhere((l) => l.token == token);
    if (i < 0) return false;
    final link = _links[i];
    if (link.revokedAt != null) return false;
    _links[i] = TGRepShareLink(
      token: link.token,
      reportId: link.reportId,
      repId: link.repId,
      sellerUserId: link.sellerUserId,
      createdAt: link.createdAt,
      expiresAt: link.expiresAt,
      revokedAt: TGClock.now(),
      revokedBy: actorId,
    );
    TGAnalytics.track('rep_report_link_revoked', {'token': token, 'actorId': actorId});
    _audit(actorId, 'rep_report_link_revoked', detail: token);
    notifyListeners();
    return true;
  }

  List<TGRepShareLink> activeLinksFor(String repId) {
    if (byId(repId) == null) return const [];
    final now = TGClock.now();
    return [for (final l in _links) if (l.repId == repId && l.isActive(now)) l];
  }

  bool canRevoke(String token, {required String actorId, required bool isAdmin, required bool isSeller}) {
    final link = _links.where((l) => l.token == token).firstOrNull;
    if (link == null) return false;
    if (isAdmin) return true;
    if (actorId == link.repId || profileForUser(actorId)?.id == link.repId) return true;
    if (isSeller && actorId == link.sellerUserId) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Weekly log
  // ---------------------------------------------------------------------------

  static DateTime warsawWeekStart(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  TGRepWeeklyLog weeklyLogFor(String repId, {DateTime? at}) {
    ensureSeeded();
    if (byId(repId) == null) {
      return TGRepWeeklyLog(repId: repId, weekStart: warsawWeekStart(at ?? TGClock.now()));
    }
    final start = warsawWeekStart(at ?? TGClock.now());
    for (final l in _logs) {
      if (l.repId == repId && l.weekStart == start) return l;
    }
    final empty = TGRepWeeklyLog(repId: repId, weekStart: start);
    _logs.add(empty);
    return empty;
  }

  void saveWeeklyLog(TGRepWeeklyLog log) {
    if (byId(log.repId) == null) return;
    final i = _logs.indexWhere((l) => l.repId == log.repId && l.weekStart == log.weekStart);
    if (i >= 0) {
      _logs[i] = log;
    } else {
      _logs.add(log);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  String _token128() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _audit(String actorId, String action, {String detail = '', String? reason}) {
    audit.insert(
      0,
      TGReferralAudit(
        id: 'RA-${TGClock.now().microsecondsSinceEpoch}',
        at: TGClock.now(),
        actorId: actorId,
        action: action,
        detail: detail,
        reason: reason,
      ),
    );
  }

  void _seedMocks() {
    final now = TGClock.now();
    _reps.addAll([
      TGRepresentative(
        id: 'rep_marek',
        userId: 'rep_marek',
        displayName: 'Marek Kowalski',
        role: TGRepRole.individualPortfolio,
        code: 'Marek-IND2026',
        status: TGRepStatus.active,
        createdAt: DateTime(now.year, 1, 8),
        email: 'marek.rep@example.com',
        phone: '+48100100100',
        isMock: true,
      ),
      TGRepresentative(
        id: 'rep_piotr',
        userId: 'rep_piotr',
        displayName: 'Piotr Nowak',
        role: TGRepRole.corporateRelations,
        code: 'Piotr-CORP2026',
        status: TGRepStatus.active,
        createdAt: DateTime(now.year, 1, 8),
        email: 'piotr.rep@example.com',
        phone: '+48100100101',
        isMock: true,
      ),
      TGRepresentative(
        id: 'rep_anna',
        userId: 'rep_anna',
        displayName: 'Anna Wiśniewska',
        role: TGRepRole.platformOperations,
        code: 'Anna-OPS2026',
        status: TGRepStatus.active,
        createdAt: DateTime(now.year, 1, 8),
        email: 'anna.rep@example.com',
        phone: '+48100100102',
        isMock: true,
      ),
    ]);

    void addSeller({
      required String id,
      required String name,
      required TGReferralSegment segment,
      required String repId,
      required String code,
      required Duration ago,
      bool phone = true,
      bool paid = false,
      TGReferralVisibility vis = TGReferralVisibility.on,
      List<TGRefListingMeta> listings = const [],
    }) {
      _accounts[id] = TGReferredAccount(
        userId: id,
        displayName: name,
        segment: segment,
        referredByCode: code,
        referredByRepId: repId,
        referredAt: now.subtract(ago),
        referralConsentAt: now.subtract(ago),
        phoneVerified: phone,
        hasPaidPlan: paid,
        referralVisibility: vis,
        listings: listings,
        isMock: true,
      );
      _signedUpUserIds.add(id);
    }

    const oven = TGRefListingMeta(
      id: 'ref_l_oven',
      title: 'Piec konwekcyjny 10x GN',
      listingNo: '51038475',
      photos: 4,
      completionPct: 90,
    );
    addSeller(
      id: 'ref_jan',
      name: 'Jan Nowak',
      segment: TGReferralSegment.individual,
      repId: 'rep_marek',
      code: 'Marek-IND2026',
      ago: const Duration(days: 20),
      listings: const [oven],
    );
    addSeller(
      id: 'ref_gastro',
      name: 'GastroLab',
      segment: TGReferralSegment.store,
      repId: 'rep_marek',
      code: 'Marek-IND2026',
      ago: const Duration(days: 40),
      paid: true,
      listings: const [
        TGRefListingMeta(id: 'ref_l_store', title: 'Zmywarka kapturowa', listingNo: '52149586', photos: 5, completionPct: 95),
      ],
    );
    addSeller(
      id: 'ref_hidden',
      name: 'Hidden Seller',
      segment: TGReferralSegment.individual,
      repId: 'rep_marek',
      code: 'Marek-IND2026',
      ago: const Duration(days: 10),
      vis: TGReferralVisibility.withdrawn,
    );
    addSeller(
      id: 'ref_new',
      name: 'Ewa Lis',
      segment: TGReferralSegment.individual,
      repId: 'rep_marek',
      code: 'Marek-IND2026',
      ago: const Duration(days: 2),
      phone: false,
    );

    final from = now.subtract(const Duration(days: 20));
    TGListingStatsService.instance.seedHistory(TGListingStatsService.productKey(oven.id), from: from, seed: 11, baseViews: 18);
    TGListingStatsService.instance.seedHistory(
      TGListingStatsService.productKey('ref_l_store'),
      from: now.subtract(const Duration(days: 25)),
      seed: 22,
      baseViews: 24,
    );
  }
}
