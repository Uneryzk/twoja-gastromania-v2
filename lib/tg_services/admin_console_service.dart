import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/go_live_checks.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

/// DASH-4 admin console state: append-only audit log, PII masking with
/// logged reveals, conversation reports, refunds and the go-live switch.
///
/// There is deliberately no impersonation ("log in as user") API.
class TGAdminConsoleService extends ChangeNotifier {
  TGAdminConsoleService._();
  static final TGAdminConsoleService instance = TGAdminConsoleService._();

  static const minReasonLength = 10;

  final List<TGAdminAuditEntry> _audit = [];
  final List<TGAdminUser> _users = [];
  final Set<String> _revealed = {};
  final List<TGConversationReport> _convReports = [];
  final Map<String, List<TGConvMessage>> _threads = {};
  final Set<String> _openedThreads = {};
  final List<TGRefundRequest> _refunds = [];
  final Map<String, TGManualCheck> _manual = {};
  bool _seeded = false;
  int _seq = 1;

  static const manualCheckIds = ['legal_review', 'payment_provider_live', 'support_rota', 'backup_restore'];

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _audit.clear();
    _users.clear();
    _revealed.clear();
    _convReports.clear();
    _threads.clear();
    _openedThreads.clear();
    _refunds.clear();
    _manual.clear();
    _seeded = false;
    _seq = 1;
  }

  // ---------------------------------------------------------------------------
  // Audit log (append-only)
  // ---------------------------------------------------------------------------

  /// Newest first. The returned list is unmodifiable and there is no delete.
  List<TGAdminAuditEntry> get audit => List.unmodifiable(_audit.reversed);

  void log({
    required FakeAuthState actor,
    required String action,
    required String targetId,
    String? reason,
    Map<String, String> details = const {},
  }) {
    _audit.add(TGAdminAuditEntry(
      id: 'ADM-${_seq++}',
      at: TGClock.now(),
      actorId: actor.userId,
      actorRole: actor.role.name,
      action: action,
      targetId: targetId,
      reason: reason?.trim(),
      details: Map.unmodifiable(details),
    ));
    notifyListeners();
  }

  /// Unified audit rows: admin console + moderation decisions, newest first.
  List<({DateTime at, String actor, String role, String action, String target, String reason, String details})>
      unifiedAudit() {
    final rows = [
      for (final e in _audit)
        (
          at: e.at,
          actor: e.actorId,
          role: e.actorRole,
          action: e.action,
          target: e.targetId,
          reason: e.reason ?? '',
          details: e.details.entries.map((x) => '${x.key}=${x.value}').join('; '),
        ),
      for (final e in ModerationService.instance.auditFor())
        (
          at: e.at,
          actor: e.actorId,
          role: e.actorRole,
          action: 'moderation_${e.action.name}',
          target: e.listingNo ?? e.reportNo ?? '',
          reason: e.reason ?? '',
          details: e.summary,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return rows;
  }

  static String _csv(String v) => v.contains(RegExp(r'[",\n;]')) ? '"${v.replaceAll('"', '""')}"' : v;

  /// RFC 4180 CSV of [unifiedAudit]. Admin-only; the export itself is logged.
  String? exportAuditCsv(FakeAuthState actor) {
    if (!actor.isAdmin) return null;
    final rows = unifiedAudit();
    final b = StringBuffer('at,actor,role,action,target,reason,details\n');
    for (final r in rows) {
      b.writeln([r.at.toIso8601String(), r.actor, r.role, r.action, r.target, r.reason, r.details].map(_csv).join(','));
    }
    log(actor: actor, action: 'audit_export', targetId: 'audit', details: {'rows': '${rows.length}'});
    TGAnalytics.track('admin_audit_export', {'rows': rows.length});
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // Users 360° + masking
  // ---------------------------------------------------------------------------

  List<TGAdminUser> users() => [for (final u in _users) if (!(_hideMock && u.isMock)) u];

  TGAdminUser? userById(String id) => users().where((u) => u.id == id).firstOrNull;

  /// Name, id or NIP contains [q]; e-mail / phone only on an exact match so
  /// search cannot be used to enumerate contact data.
  List<TGAdminUser> searchUsers(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return users();
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return [
      for (final u in users())
        if (u.name.toLowerCase().contains(s) ||
            u.id.toLowerCase().contains(s) ||
            (u.nip != null && digits.length >= 4 && u.nip!.contains(digits)) ||
            u.email.toLowerCase() == s ||
            (digits.length >= 9 && u.phone.replaceAll(RegExp(r'\D'), '').endsWith(digits)))
          u,
    ];
  }

  String _revealKey(String actorId, String userId, TGPiiField f) => '$actorId|$userId|${f.name}';

  bool isRevealed(FakeAuthState actor, String userId, TGPiiField f) =>
      _revealed.contains(_revealKey(actor.userId, userId, f));

  /// Masked unless this staff member revealed it with a logged reason.
  String display(FakeAuthState actor, String userId, TGPiiField f, String value) {
    if (isRevealed(actor, userId, f)) return value;
    return f == TGPiiField.email ? tgMaskEmail(value) : tgMaskPhone(value);
  }

  /// Returns an i18n error key, or null when revealed.
  String? reveal({required FakeAuthState actor, required String userId, required TGPiiField field, required String reason}) {
    if (!actor.canModerate) return 'adm_err_staff';
    if (reason.trim().length < minReasonLength) return 'adm_err_reason';
    _revealed.add(_revealKey(actor.userId, userId, field));
    log(actor: actor, action: 'reveal', targetId: userId, reason: reason, details: {'field': field.name});
    TGAnalytics.track('admin_reveal', {'userId': userId, 'field': field.name, 'role': actor.role.name});
    return null;
  }

  ({int payments, double grossPln, int refunds, int reportsAgainst, String verification}) metricsFor(TGAdminUser u) {
    final pays = TGBillingService.instance.paymentsFor(u.id);
    final ver = TGVerificationService.instance.companyFor(u.id);
    return (
      payments: pays.where((p) => p.status != TGPaymentStatus.failed).length,
      grossPln: pays.where((p) => p.status == TGPaymentStatus.succeeded).fold<double>(0, (s, p) => s + p.grossPln),
      refunds: refunds().where((r) => r.userId == u.id).length,
      reportsAgainst: conversationReports().where((r) => r.reportedUserId == u.id).length,
      verification: TGVerificationService.instance.isNipVerified(u.id) ? 'verified' : (ver?.status.name ?? 'none'),
    );
  }

  // ---------------------------------------------------------------------------
  // Conversation reports
  // ---------------------------------------------------------------------------

  List<TGConversationReport> conversationReports({bool openOnly = false}) => [
        for (final r in _convReports)
          if (!(_hideMock && r.isMock) && (!openOnly || r.status == TGConvReportStatus.open)) r,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  TGConversationReport? convReportById(String id) => _convReports.where((r) => r.id == id).firstOrNull;

  /// The full thread, only after [openFullConversation] by this staff member.
  List<TGConvMessage>? openedThread(FakeAuthState actor, String reportId) {
    final r = convReportById(reportId);
    if (r == null || !_openedThreads.contains('${actor.userId}|$reportId')) return null;
    return List.unmodifiable(_threads[r.conversationId] ?? const []);
  }

  String? openFullConversation({required FakeAuthState actor, required String reportId, required String reason}) {
    if (!actor.canModerate) return 'adm_err_staff';
    final r = convReportById(reportId);
    if (r == null) return 'adm_err_not_found';
    if (reason.trim().length < minReasonLength) return 'adm_err_reason';
    _openedThreads.add('${actor.userId}|$reportId');
    log(actor: actor, action: 'conversation_open', targetId: r.conversationId, reason: reason, details: {'report': r.id});
    TGAnalytics.track('admin_conversation_open', {'reportId': r.id, 'role': actor.role.name});
    return null;
  }

  String? decideConversation({required FakeAuthState actor, required String reportId, required bool actioned, required String note}) {
    if (!actor.canModerate) return 'adm_err_staff';
    final r = convReportById(reportId);
    if (r == null || r.status != TGConvReportStatus.open) return 'adm_err_not_found';
    if (note.trim().length < minReasonLength) return 'adm_err_reason';
    r.status = actioned ? TGConvReportStatus.actioned : TGConvReportStatus.dismissed;
    log(actor: actor, action: 'conversation_decision', targetId: r.reportedUserId, reason: note, details: {
      'report': r.id,
      'decision': r.status.name,
    });
    return null;
  }

  // ---------------------------------------------------------------------------
  // Refunds (admin only)
  // ---------------------------------------------------------------------------

  List<TGRefundRequest> refunds() => [
        for (final r in _refunds)
          if (!(_hideMock && r.isMock)) r,
      ]..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

  int get pendingRefunds => refunds().where((r) => r.status == TGRefundStatus.pending).length;

  /// Refunds part or all of a service fee. [requestId] links it to a request.
  String? refund({
    required FakeAuthState actor,
    required String paymentId,
    required num amountPln,
    required String reason,
    String? requestId,
  }) {
    if (!actor.isAdmin) return 'adm_err_admin_only';
    final p = TGBillingService.instance.paymentById(paymentId);
    if (p == null || p.status != TGPaymentStatus.succeeded) return 'adm_err_payment';
    final left = p.grossPln - TGBillingService.instance.refundedPln(paymentId);
    if (amountPln <= 0 || amountPln > left + 0.001) return 'adm_err_amount';
    if (reason.trim().length < minReasonLength) return 'adm_err_reason';
    TGBillingService.instance.markRefunded(paymentId, amountPln);
    final req = requestId == null ? null : _refunds.where((r) => r.id == requestId).firstOrNull;
    if (req != null) {
      req.status = TGRefundStatus.approved;
      req.decidedAt = TGClock.now();
      req.decidedBy = actor.userId;
      req.decisionNote = reason.trim();
    }
    log(actor: actor, action: 'refund', targetId: p.userId, reason: reason, details: {
      'payment': paymentId,
      'amountPln': amountPln.toStringAsFixed(2),
      if (req != null) 'request': req.id,
    });
    TGAnalytics.track('admin_refund', {
      'paymentId': paymentId,
      'amountPln': amountPln,
      'partial': amountPln < p.grossPln,
      if (req != null) 'requestId': req.id,
    });
    return null;
  }

  String? rejectRefund({required FakeAuthState actor, required String requestId, required String note}) {
    if (!actor.isAdmin) return 'adm_err_admin_only';
    final req = _refunds.where((r) => r.id == requestId).firstOrNull;
    if (req == null || req.status != TGRefundStatus.pending) return 'adm_err_not_found';
    if (note.trim().length < minReasonLength) return 'adm_err_reason';
    req.status = TGRefundStatus.rejected;
    req.decidedAt = TGClock.now();
    req.decidedBy = actor.userId;
    req.decisionNote = note.trim();
    log(actor: actor, action: 'refund_rejected', targetId: req.userId, reason: note, details: {'request': req.id});
    return null;
  }

  // ---------------------------------------------------------------------------
  // Go-live
  // ---------------------------------------------------------------------------

  List<TGManualCheck> manualChecks() => [
        for (final id in manualCheckIds) _manual[id] ?? TGManualCheck(id: id, labelKey: 'adm_golive_manual_$id'),
      ];

  String? setManual({required FakeAuthState actor, required String id, required bool done}) {
    if (!actor.isAdmin) return 'adm_err_admin_only';
    _manual[id] = done
        ? TGManualCheck(id: id, labelKey: 'adm_golive_manual_$id', doneBy: actor.userId, doneAt: TGClock.now())
        : TGManualCheck(id: id, labelKey: 'adm_golive_manual_$id');
    log(actor: actor, action: 'golive_manual', targetId: id, details: {'done': '$done'});
    return null;
  }

  /// Auto checks without the production flag itself (that is what we switch).
  List<TGGoLiveCheck> autoChecks([List<TGGoLiveCheck>? checks]) =>
      [for (final c in checks ?? tgGoLiveChecks()) if (c.id != 'production_mode') c];

  List<String> goLiveBlockers([List<TGGoLiveCheck>? checks]) => [
        for (final c in autoChecks(checks))
          if (c.blocking && !c.ok) c.id,
        for (final m in manualChecks())
          if (!m.done) 'manual_${m.id}',
      ];

  String? switchToProduction({required FakeAuthState actor, required String reason, List<TGGoLiveCheck>? checks}) {
    if (!actor.isAdmin) return 'adm_err_admin_only';
    if (TGRevenueConfigService.instance.productionMode) return 'adm_err_already_live';
    final blockers = goLiveBlockers(checks);
    if (blockers.isNotEmpty) return 'adm_err_blockers';
    if (reason.trim().length < minReasonLength) return 'adm_err_reason';
    TGRevenueConfigService.instance.setProductionMode(true, actorId: actor.userId, reason: reason.trim());
    log(actor: actor, action: 'golive_switch', targetId: 'platform', reason: reason);
    TGAnalytics.track('golive_switch', {'actorId': actor.userId});
    return null;
  }

  // ---------------------------------------------------------------------------
  // Mocks (never in production mode)
  // ---------------------------------------------------------------------------

  void ensureSeeded() {
    if (_seeded || _hideMock) return;
    _seeded = true;
    TGVerificationService.instance.seedMocks();
    final now = TGClock.now();
    DateTime ago(int days) => now.subtract(Duration(days: days));

    _users.addAll([
      TGAdminUser(id: 'usr_marek', name: 'Marek K.', email: 'marek.kowalski@example.pl', phone: '+48 601 222 111', kind: TGAdminUserKind.individual, createdAt: ago(210), nip: '6761005675', isMock: true),
      TGAdminUser(id: 'seller_gastropl', name: 'GastroPL', email: 'hello@gastropl.pl', phone: '+48 512 345 678', kind: TGAdminUserKind.store, createdAt: ago(480), nip: '5260250274', isMock: true),
      TGAdminUser(id: 'usr_anna', name: 'Anna W.', email: 'anna.w@example.pl', phone: '+48 698 450 312', kind: TGAdminUserKind.buyer, createdAt: ago(45), isMock: true),
      TGAdminUser(id: 'seller_inoxline', name: 'Inoxline', email: 'biuro@inoxline.pl', phone: '+48 32 444 12 90', kind: TGAdminUserKind.store, createdAt: ago(300), nip: '6340012347', isMock: true),
      TGAdminUser(id: 'usr_bistro', name: 'Bistro Nowak', email: 'kontakt@bistronowak.pl', phone: '+48 77 400 22 33', kind: TGAdminUserKind.restaurant, createdAt: ago(95), nip: '7771234567', isMock: true),
      TGAdminUser(id: 'usr_tomasz', name: 'Tomasz B.', email: 'tomasz.b@example.pl', phone: '+48 733 090 554', kind: TGAdminUserKind.individual, createdAt: ago(12), status: TGAdminUserStatus.suspended, isMock: true),
    ]);

    _threads['conv_mock_1'] = [
      TGConvMessage(fromId: 'usr_anna', text: 'Dzień dobry, czy piec jest nadal dostępny?', at: now.subtract(const Duration(hours: 30))),
      TGConvMessage(fromId: 'usr_tomasz', text: 'Tak. Proszę przelać zaliczkę 2000 zł na moje prywatne konto, wtedy zarezerwuję.', at: now.subtract(const Duration(hours: 29))),
      TGConvMessage(fromId: 'usr_anna', text: 'Wolę obejrzeć sprzęt osobiście przed płatnością.', at: now.subtract(const Duration(hours: 28))),
    ];
    _threads['conv_mock_2'] = [
      TGConvMessage(fromId: 'usr_marek', text: 'Ile kosztuje transport do Krakowa?', at: now.subtract(const Duration(hours: 8))),
      TGConvMessage(fromId: 'seller_inoxline', text: 'Napisz na WhatsApp, tu nie odpowiadam: +48 32 444 12 90', at: now.subtract(const Duration(hours: 7))),
    ];
    _convReports.addAll([
      TGConversationReport(id: 'CR-mock-1', conversationId: 'conv_mock_1', reporterId: 'usr_anna', reportedUserId: 'usr_tomasz', reason: 'scam', reported: _threads['conv_mock_1']![1], createdAt: now.subtract(const Duration(hours: 27)), isMock: true),
      TGConversationReport(id: 'CR-mock-2', conversationId: 'conv_mock_2', reporterId: 'usr_marek', reportedUserId: 'seller_inoxline', reason: 'off_platform', reported: _threads['conv_mock_2']![1], createdAt: now.subtract(const Duration(hours: 6)), isMock: true),
    ]);

    final billing = TGBillingService.instance;
    TGPayment pay(String user, TGPaymentKind k, String d, num gross, int daysAgo) =>
        billing.recordPayment(userId: user, kind: k, description: d, grossPln: gross, methodLabel: 'BLIK', at: ago(daysAgo), isMock: true, notify: false);
    final cfg = PricingConfigService.instance.config;
    final promoDays = cfg.promotions.durations.first;
    final listDays = cfg.defaultListingDays;
    final restoDays = cfg.defaultRestaurantDays;
    final bannerDays = cfg.banner.durations.first;
    final boldFee = cfg.promoFeePln(PromotionTier.bold, promoDays);
    final listFee = cfg.listingFeePln(listDays);
    final restoFee = cfg.restaurantFeePln(restoDays);
    final bannerFee = cfg.banner.pricePln(bannerDays);
    final p1 = pay('seller_gastropl', TGPaymentKind.promotion, tgPromoBillingLabel(PromotionTier.bold, promoDays), boldFee, 3);
    final p2 = pay('usr_marek', TGPaymentKind.listing, 'Listing fee · $listDays days', listFee, 2);
    final p3 = pay('usr_bistro', TGPaymentKind.restaurant, 'Restaurant listing · $restoDays days', restoFee, 9);
    final p4 = pay('seller_inoxline', TGPaymentKind.banner, 'Hero banner · $bannerDays days', bannerFee, 20);
    final p5 = pay('usr_anna', TGPaymentKind.listing, 'Listing fee · $listDays days', listFee, 15);
    TGRefundRequest req(String id, TGPayment p, num amount, String reason, int hoursAgo,
            {TGRefundStatus status = TGRefundStatus.pending, String? note}) =>
        TGRefundRequest(
          id: id,
          paymentId: p.id,
          userId: p.userId,
          amountPln: amount,
          reason: reason,
          requestedAt: now.subtract(Duration(hours: hoursAgo)),
          status: status,
          decidedAt: status == TGRefundStatus.pending ? null : now.subtract(Duration(hours: hoursAgo - 4)),
          decidedBy: status == TGRefundStatus.pending ? null : 'staff_admin',
          decisionNote: note,
          isMock: true,
        );
    _refunds.addAll([
      req('RF-mock-1', p1, boldFee, 'Double charge after a BLIK timeout', 20),
      req('RF-mock-2', p2, listFee, 'Listing removed by moderation within 24 h', 30),
      req('RF-mock-3', p3, restoFee / 2, 'Restaurant closed for renovation; asks for half', 50),
      req('RF-mock-4', p4, bannerFee, 'Banner slot was not shown (outage 2 days)', 400,
          status: TGRefundStatus.approved, note: 'Outage confirmed in the ad server log'),
      req('RF-mock-5', p5, listFee, 'Changed mind after publishing', 300,
          status: TGRefundStatus.rejected, note: 'Service already delivered; no fault on our side'),
    ]);
    billing.markRefunded(p4.id, bannerFee, notify: false);
  }
}
