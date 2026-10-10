import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/review_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class TGPendingRemove {
  TGPendingRemove({
    required this.listingNo,
    required this.previousStatus,
    required this.previousHidden,
    required this.previousExpiresAt,
    required this.emails,
    required this.timer,
  });

  final String listingNo;
  final TGListingStatus previousStatus;
  final bool previousHidden;
  final DateTime? previousExpiresAt;
  final List<TGQueuedEmail> emails;
  final Timer timer;
}

/// In-memory moderation console. Seeded with 14 reports, 3 copy matches,
/// 1 fraud High case and 2 appeals.
class ModerationService extends ChangeNotifier {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  static const String featuredListingNo = '10482137';

  Duration undoWindow = const Duration(seconds: 10);
  int highSlaHours = 24;
  int otherSlaBusinessDays = 2;

  final List<TGModerationReport> reports = [];
  final List<TGPhotoMatch> photoMatches = [];
  final List<TGModerationAppeal> appeals = [];
  final List<TGAuditEntry> audit = [];
  final List<TGEmailTemplate> templates = [];
  final List<TGQueuedEmail> emails = [];
  final Map<String, TGModerationSeller> sellers = {};
  final Map<String, TGQueueCase> cases = {};
  final Map<String, DateTime> hiddenAt = {};
  final Set<String> suspendedSellerIds = {};
  final Map<String, TGPendingRemove> pendingRemoves = {};
  final Map<String, List<TGCaseEvent>> events = {};
  final List<TGProduct> sellerListings = [];
  final Map<String, TGSellerModerationCase> sellerCases = {};
  final Map<String, TGSoldHold> soldHolds = {};
  int storeCreditsRefunded = 0;
  int _publicSeq = 417;

  int _seq = 0;
  bool _loaded = false;

  void reset() {
    for (final p in pendingRemoves.values) {
      p.timer.cancel();
    }
    pendingRemoves.clear();
    reports.clear();
    photoMatches.clear();
    appeals.clear();
    audit.clear();
    templates.clear();
    emails.clear();
    sellers.clear();
    cases.clear();
    hiddenAt.clear();
    suspendedSellerIds.clear();
    events.clear();
    sellerListings.clear();
    sellerCases.clear();
    soldHolds.clear();
    storeCreditsRefunded = 0;
    debugNow = null;
    _publicSeq = 417;
    undoWindow = const Duration(seconds: 10);
    highSlaHours = 24;
    otherSlaBusinessDays = 2;
    _seq = 0;
    _loaded = false;
    ensureSeeded();
  }

  void ensureSeeded() {
    if (_loaded) return;
    _loaded = true;
    _seed();
  }

  DateTime? debugNow;
  DateTime get now => debugNow ?? DateTime.now();

  int get newCount => cases.values.where((c) => c.status == TGReportStatus.new_).length;
  int get inReviewCount => cases.values.where((c) => c.status == TGReportStatus.inReview).length;
  int get waitingCount => cases.values.where((c) => c.status == TGReportStatus.waitingSeller).length;
  int get openAppealCount => appeals.where((a) => !a.resolved).length;

  List<TGQueueCase> get queueRows {
    _escalateDueSoldHolds();
    final rows = cases.values.where((c) => c.status.isOpen && !_isSoldHold(c.listingNo)).toList()
      ..sort((a, b) {
        final p = a.priority.index.compareTo(b.priority.index);
        if (p != 0) return p;
        return a.firstReportedAt.compareTo(b.firstReportedAt);
      });
    return rows;
  }

  TGQueueCase? caseFor(String listingNo) => cases[listingNo];

  List<TGPhotoMatch> matchesFor(String listingNo) =>
      photoMatches.where((m) => m.listingNoA == listingNo || m.listingNoB == listingNo).toList();

  List<TGModerationReport> reportsFor(String listingNo) =>
      reports.where((r) => r.listingNo == listingNo).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<TGAuditEntry> auditFor({String? listingNo}) {
    final list = listingNo == null ? [...audit] : audit.where((e) => e.listingNo == listingNo).toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  TGModerationSeller? sellerById(String id) => sellers[id];

  List<TGProduct> sameSellerListings(String sellerId, String exceptListingNo, List<TGProduct> catalogue) =>
      catalogue.where((p) => p.seller.id == sellerId && p.listingNo != exceptListingNo).toList();

  List<TGModerationSeller> samePhoneOrNip(TGModerationSeller profile) {
    return sellers.values.where((s) {
      if (s.seller.id == profile.seller.id) return false;
      final phone = s.phone.replaceAll(RegExp(r'\D'), '') == profile.phone.replaceAll(RegExp(r'\D'), '');
      final nip = profile.nip != null && profile.nip!.isNotEmpty && s.nip == profile.nip;
      return phone || nip;
    }).toList();
  }

  DateTime slaDeadlineFor(TGModerationPriority priority, DateTime from) {
    if (priority == TGModerationPriority.high) {
      return from.add(Duration(hours: highSlaHours));
    }
    return addBusinessDays(from, otherSlaBusinessDays);
  }

  static DateTime addBusinessDays(DateTime from, int days) {
    var cursor = from;
    var left = days;
    while (left > 0) {
      cursor = cursor.add(const Duration(days: 1));
      if (cursor.weekday != DateTime.saturday && cursor.weekday != DateTime.sunday) {
        left--;
      }
    }
    return cursor;
  }

  TGModerationPriority computePriority({
    required List<TGModerationReport> listingReports,
    required bool promoted,
    DateTime? at,
  }) {
    final t = at ?? now;
    final weekAgo = t.subtract(const Duration(days: 7));
    final recentReporters = listingReports.where((r) => !r.createdAt.isBefore(weekAgo)).map((r) => r.reporterId).toSet();
    final reasons = listingReports.map((r) => r.reason).toSet();
    if (reasons.contains(TGReportReason.fraud) ||
        reasons.contains(TGReportReason.prohibited) ||
        reasons.contains(TGReportReason.fakeStore) ||
        reasons.contains(TGReportReason.fakeReview) ||
        reasons.contains(TGReportReason.harassment) ||
        recentReporters.length >= 3 ||
        promoted) {
      return TGModerationPriority.high;
    }
    var result = TGModerationPriority.low;
    if (reasons.contains(TGReportReason.duplicate) || reasons.contains(TGReportReason.copied)) {
      result = TGModerationPriority.medium;
    }
    final listingNo = listingReports.isEmpty ? null : listingReports.first.listingNo;
    final hold = listingNo == null ? null : soldHolds[listingNo];
    if (hold != null && hold.shouldEscalate(t) && reasons.contains(TGReportReason.sold)) {
      result = TGModerationPriority.medium;
    }
    final allGuest = listingReports.isNotEmpty && listingReports.every((r) => r.reporterId.startsWith('guest:'));
    if (allGuest) {
      if (hold != null && hold.shouldEscalate(now) && reasons.contains(TGReportReason.sold)) {
        return TGModerationPriority.medium;
      }
      return TGModerationPriority.low;
    }
    return result;
  }

  String? resolveSearch(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return null;
    if (RegExp(r'^\d{8}$').hasMatch(q)) return q;
    final byReport = reports.where((r) => r.reportNo.toLowerCase() == q.toLowerCase()).firstOrNull;
    if (byReport != null) return byReport.listingNo;
    final lower = q.toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    for (final s in sellers.values) {
      bool match = (s.email ?? '').toLowerCase() == lower;
      if (!match && s.nip != null && s.nip == digits) match = true;
      if (!match && digits.length >= 9 && s.phone.replaceAll(RegExp(r'\D'), '') == digits) match = true;
      if (!match) continue;
      final hit = cases.values.where((c) => c.sellerId == s.seller.id).firstOrNull;
      if (hit != null) return hit.listingNo;
    }
    return null;
  }

  List<TGQueueCase> filterQueue({
    TGReportReason? reason,
    TGModerationPriority? priority,
    TGReportStatus? status,
    String? assignedTo,
    bool appealsOnly = false,
  }) {
    var rows = queueRows;
    if (appealsOnly) {
      final nos = appeals.where((a) => !a.resolved).map((a) => a.listingNo).toSet();
      rows = rows.where((c) => nos.contains(c.listingNo)).toList();
      final extra = [
        for (final a in appeals.where((x) => !x.resolved))
          if (cases[a.listingNo] != null && !rows.any((c) => c.listingNo == a.listingNo)) cases[a.listingNo]!,
      ];
      rows = [...rows, ...extra];
    }
    if (reason != null) rows = rows.where((c) => c.reports.any((r) => r.reason == reason)).toList();
    if (priority != null) rows = rows.where((c) => c.priority == priority).toList();
    if (status != null) rows = rows.where((c) => c.status == status).toList();
    if (assignedTo != null) {
      if (assignedTo == '__none__') {
        rows = rows.where((c) => c.assignedTo == null || c.assignedTo!.isEmpty).toList();
      } else {
        rows = rows.where((c) => c.assignedTo == assignedTo).toList();
      }
    }
    return rows;
  }

  void assignTo(String listingNo, String actorId, {required String actorRole}) {
    final c = cases[listingNo];
    if (c == null) return;
    c.assignedTo = actorId;
    if (c.status == TGReportStatus.new_) c.status = TGReportStatus.inReview;
    _touchReports(listingNo, c.status);
    _audit(
      actorId: actorId,
      actorRole: actorRole,
      action: TGModerationActionType.assign,
      listingNo: listingNo,
      summary: 'Assigned to $actorId',
    );
    _event(listingNo, 'Assigned to $actorId');
    notifyListeners();
  }

  TGQueuedEmail previewEmail({
    required String templateId,
    required String lang,
    required Map<String, String> vars,
  }) {
    final tpl = templates.firstWhere(
      (t) => t.id == templateId && t.lang == lang,
      orElse: () => templates.firstWhere((t) => t.id == templateId, orElse: () => templates.first),
    );
    String fill(String s) {
      var out = s;
      vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
      return out;
    }

    return TGQueuedEmail(
      id: 'preview',
      to: vars['to'] ?? '',
      subject: fill(tpl.subject),
      body: fill(tpl.body),
      templateId: tpl.id,
      createdAt: now,
      listingNo: vars['listingNo'],
    );
  }

  void dismiss({
    required String listingNo,
    required String actorId,
    required String actorRole,
    String note = 'No violation',
  }) {
    _resolve(listingNo, TGReportStatus.resolvedNoViolation);
    final mail = _enqueue(
      templateId: 'reporter_no_violation',
      lang: 'en',
      to: _reporterEmails(listingNo).join(', '),
      vars: _vars(listingNo),
      sendNow: true,
    );
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.dismiss, listingNo: listingNo, reason: note, summary: 'Dismissed — no violation');
    _event(listingNo, 'Dismissed (no violation)', mail.subject);
    TGAnalytics.track('admin_action', {'type': 'dismiss', 'listingNo': listingNo, 'target': _targetOf(listingNo).name});
    TGAnalytics.track('admin_template_sent', {'template': 'reporter_no_violation', 'listingNo': listingNo});
    notifyListeners();
  }

  TGReportTarget _targetOf(String listingNo) {
    if (listingNo.startsWith('s:')) return TGReportTarget.seller;
    if (listingNo.startsWith('r:')) return TGReportTarget.review;
    if (listingNo.startsWith('q:')) return TGReportTarget.request;
    return cases[listingNo]?.target ?? TGReportTarget.listing;
  }

  Future<void> hideReview({
    required String reviewId,
    required String actorId,
    required String actorRole,
  }) async {
    final key = caseKeyFor(TGReportTarget.review, reviewId);
    TGReviewService.instance.setStatus(reviewId, TGReviewStatus.underReview);
    DealService.instance.hideReviewTemporarily(reviewId);
    _resolve(key, TGReportStatus.inReview);
    final review = TGReviewService.instance.byId(reviewId);
    _enqueue(
      templateId: 'hide_review',
      lang: 'en',
      to: review?.authorEmail ?? 'author@example.com',
      vars: {'listingNo': reviewId, 'seller': review?.authorName ?? 'reviewer', 'to': review?.authorEmail ?? 'author@example.com'},
      sendNow: true,
    );
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.hide, listingNo: key, summary: 'Review hidden temporarily');
    _event(key, 'Review hidden');
    TGAnalytics.track('admin_action', {'type': 'hide', 'reviewId': reviewId, 'target': 'review'});
    notifyListeners();
  }

  Future<void> removeReview({
    required String reviewId,
    required String actorId,
    required String actorRole,
    required String reason,
    String description = '',
  }) async {
    final key = caseKeyFor(TGReportTarget.review, reviewId);
    TGReviewService.instance.setStatus(reviewId, TGReviewStatus.removed, recordUndo: true);
    DealService.instance.setReviewState(reviewId, TGPurchaseReviewState.removed, recordUndo: true);
    _resolve(key, TGReportStatus.resolvedRemoved);
    final review = TGReviewService.instance.byId(reviewId);
    _enqueue(
      templateId: 'remove_review',
      lang: 'en',
      to: review?.authorEmail ?? 'author@example.com',
      vars: {
        'listingNo': reviewId,
        'reason': reason,
        'description': description,
        'seller': review?.authorName ?? 'reviewer',
        'to': review?.authorEmail ?? 'author@example.com',
      },
      sendNow: true,
    );
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.remove, listingNo: key, reason: reason, summary: 'Review removed');
    _event(key, 'Review removed', reason);
    TGAnalytics.track('admin_action', {'type': 'remove', 'reviewId': reviewId, 'target': 'review', 'reason': reason});
    notifyListeners();
  }

  bool undoRemoveReview(String reviewId, {required String actorId, required String actorRole}) {
    final storeOk = TGReviewService.instance.undoStatus(reviewId);
    final dealOk = DealService.instance.undoReviewState(reviewId);
    if (!storeOk && !dealOk) return false;
    final key = caseKeyFor(TGReportTarget.review, reviewId);
    _resolve(key, TGReportStatus.inReview);
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.undo, listingNo: key, summary: 'Undo review removal');
    TGAnalytics.track('admin_action', {'type': 'undo', 'reviewId': reviewId, 'target': 'review'});
    notifyListeners();
    return true;
  }

  Future<void> approveReview({
    required String reviewId,
    required String actorId,
    required String actorRole,
  }) async {
    final key = caseKeyFor(TGReportTarget.review, reviewId);
    DealService.instance.setReviewState(reviewId, TGPurchaseReviewState.awaitingSeller);
    _resolve(key, TGReportStatus.resolvedNoViolation);
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.restore, listingNo: key, summary: 'Pending-check review approved');
    _event(key, 'Review approved into the normal state machine');
    TGAnalytics.track('admin_action', {'type': 'approve', 'reviewId': reviewId, 'target': 'review'});
    notifyListeners();
  }

  Future<void> requestInfo({
    required String listingNo,
    required String actorId,
    required String actorRole,
    required int days,
    required bool hideWhileWaiting,
    String lang = 'en',
  }) async {
    await _patchListing(listingNo, (p) {
      hiddenAt[listingNo] = now;
      return p.copyWith(status: TGListingStatus.underReview, isHidden: hideWhileWaiting);
    });
    final c = cases[listingNo];
    if (c != null) {
      c.status = TGReportStatus.waitingSeller;
      c.assignedTo ??= actorId;
    }
    _touchReports(listingNo, TGReportStatus.waitingSeller);
    final mail = _enqueue(
      templateId: 'request_info',
      lang: lang,
      to: _sellerEmail(listingNo),
      vars: {..._vars(listingNo), 'days': '$days'},
      sendNow: true,
    );
    _audit(
      actorId: actorId,
      actorRole: actorRole,
      action: TGModerationActionType.requestInfo,
      listingNo: listingNo,
      reason: 'Request info · ${days}d${hideWhileWaiting ? ' · hidden' : ''}',
      summary: 'Requested more information ($days days)',
    );
    _event(listingNo, 'Requested information ($days days)', mail.subject);
    TGAnalytics.track('admin_action', {'type': 'request_info', 'listingNo': listingNo, 'days': days, 'hide': hideWhileWaiting, 'target': _targetOf(listingNo).name});
    TGAnalytics.track('admin_template_sent', {'template': 'request_info', 'listingNo': listingNo});
    notifyListeners();
  }

  Future<void> hideTemporarily({
    required String listingNo,
    required String actorId,
    required String actorRole,
  }) async {
    await _patchListing(listingNo, (p) {
      hiddenAt[listingNo] = now;
      return p.copyWith(isHidden: true, status: p.status == TGListingStatus.active ? TGListingStatus.underReview : p.status);
    });
    final c = cases[listingNo];
    if (c != null && c.status == TGReportStatus.new_) c.status = TGReportStatus.inReview;
    _touchReports(listingNo, cases[listingNo]?.status ?? TGReportStatus.inReview);
    final mail = _enqueue(templateId: 'hide_notice', lang: 'en', to: _sellerEmail(listingNo), vars: _vars(listingNo), sendNow: true);
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.hide, listingNo: listingNo, summary: 'Hidden temporarily');
    _event(listingNo, 'Hidden temporarily', mail.subject);
    TGAnalytics.track('admin_action', {'type': 'hide', 'listingNo': listingNo, 'target': _targetOf(listingNo).name});
    notifyListeners();
  }

  Future<void> removeListing({
    required String listingNo,
    required String actorId,
    required String actorRole,
    required TGRemoveReason reason,
    String description = '',
    bool notifySeller = true,
    bool applyToOthers = false,
  }) async {
    final product = await TGProductService.instance.getById(listingNo);
    if (product == null) return;
    final previous = product;
    await _applyRemove(product);
    if (applyToOthers) {
      final all = await TGProductService.instance.getAll();
      for (final p in all.where((x) => x.seller.id == product.seller.id && x.listingNo != listingNo && x.status != TGListingStatus.removed)) {
        await _applyRemove(p);
      }
    }
    _resolve(listingNo, TGReportStatus.resolvedRemoved);
    final sellerMail = notifySeller
        ? _enqueue(
            templateId: 'remove_seller',
            lang: 'en',
            to: _sellerEmail(listingNo),
            vars: {..._vars(listingNo), 'reason': reason.label, 'description': description},
            sendNow: false,
          )
        : null;
    final reporterMail = _enqueue(
      templateId: 'reporter_action_taken',
      lang: 'en',
      to: _reporterEmails(listingNo).join(', '),
      vars: _vars(listingNo),
      sendNow: false,
    );
    final queued = <TGQueuedEmail>[if (sellerMail != null) sellerMail, reporterMail];
    pendingRemoves[listingNo]?.timer.cancel();
    pendingRemoves[listingNo] = TGPendingRemove(
      listingNo: listingNo,
      previousStatus: previous.status,
      previousHidden: previous.isHidden,
      previousExpiresAt: previous.expiresAt,
      emails: queued,
      timer: Timer(undoWindow, () => flushRemove(listingNo)),
    );
    _audit(
      actorId: actorId,
      actorRole: actorRole,
      action: TGModerationActionType.remove,
      listingNo: listingNo,
      reason: reason.label,
      summary: 'Removed · ${reason.label}',
      details: {'description': description, 'notifySeller': '$notifySeller', 'applyToOthers': '$applyToOthers'},
    );
    _event(listingNo, 'Removed (${reason.label})', description);
    final sc = sellerCases[listingNo];
    if (sc != null) {
      sc.decidedAt = now;
      sc.decidedByHuman = true;
      sc.removalRule ??= reason.label;
      sc.removalExplanation ??= description;
    }
    TGAnalytics.track('admin_action', {'type': 'remove', 'listingNo': listingNo, 'reason': reason.name, 'target': _targetOf(listingNo).name});
    notifyListeners();
  }

  Future<void> undoRemove(String listingNo, {required String actorId, required String actorRole}) async {
    final pending = pendingRemoves.remove(listingNo);
    if (pending == null) return;
    pending.timer.cancel();
    for (final e in pending.emails) {
      emails.removeWhere((x) => x.id == e.id);
    }
    await _patchListing(listingNo, (p) => p.copyWith(status: pending.previousStatus, isHidden: pending.previousHidden, expiresAt: pending.previousExpiresAt));
    final c = cases[listingNo];
    if (c != null) {
      c.status = TGReportStatus.inReview;
      _touchReports(listingNo, TGReportStatus.inReview);
    }
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.undo, listingNo: listingNo, summary: 'Undo remove');
    _event(listingNo, 'Remove undone');
    TGAnalytics.track('admin_undo', {'listingNo': listingNo});
    notifyListeners();
  }

  void flushRemove(String listingNo) {
    final pending = pendingRemoves.remove(listingNo);
    if (pending == null) return;
    for (final e in pending.emails) {
      final i = emails.indexWhere((x) => x.id == e.id);
      if (i >= 0) emails[i] = emails[i].copyWith(sent: true);
    }
    TGAnalytics.track('admin_template_sent', {'template': 'remove', 'listingNo': listingNo});
    notifyListeners();
  }

  Future<void> requestProof({
    required String listingNo,
    required String actorId,
    required String actorRole,
    String lang = 'en',
  }) async {
    await _patchListing(listingNo, (p) => p.copyWith(status: TGListingStatus.underReview));
    final c = cases[listingNo];
    if (c != null) c.status = TGReportStatus.waitingSeller;
    _touchReports(listingNo, TGReportStatus.waitingSeller);
    final mail = _enqueue(templateId: 'request_proof', lang: lang, to: _sellerEmail(listingNo), vars: _vars(listingNo), sendNow: true);
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.requestProof, listingNo: listingNo, summary: 'Requested verification photos/video');
    _event(listingNo, 'Requested proof (5–10s video or photos)', mail.subject);
    TGAnalytics.track('admin_action', {'type': 'request_proof', 'listingNo': listingNo});
    TGAnalytics.track('admin_template_sent', {'template': 'request_proof', 'listingNo': listingNo});
    notifyListeners();
  }

  void contactParty({
    required String listingNo,
    required bool seller,
    required String actorId,
    required String actorRole,
    required String lang,
    required String subject,
    required String body,
  }) {
    final to = seller ? _sellerEmail(listingNo) : _reporterEmails(listingNo).join(', ');
    emails.add(TGQueuedEmail(
      id: 'mail_${++_seq}',
      to: to,
      subject: subject,
      body: body,
      templateId: seller ? 'contact_seller' : 'contact_reporter',
      createdAt: now,
      listingNo: listingNo,
      sent: true,
    ));
    final type = seller ? TGModerationActionType.contactSeller : TGModerationActionType.contactReporter;
    _audit(actorId: actorId, actorRole: actorRole, action: type, listingNo: listingNo, summary: seller ? 'Contacted seller' : 'Contacted reporter');
    _event(listingNo, seller ? 'Seller contacted' : 'Reporter contacted', subject);
    TGAnalytics.track('admin_action', {'type': seller ? 'contact_seller' : 'contact_reporter', 'listingNo': listingNo, 'target': _targetOf(listingNo).name});
    TGAnalytics.track('admin_template_sent', {'template': seller ? 'contact_seller' : 'contact_reporter', 'listingNo': listingNo});
    notifyListeners();
  }

  Future<void> warnOrSuspend({
    required String sellerId,
    required String actorId,
    required String actorRole,
    required bool suspend,
    String listingNo = '',
  }) async {
    final profile = sellers[sellerId];
    if (profile != null) {
      sellers[sellerId] = profile.copyWith(suspended: suspend ? true : profile.suspended);
    }
    if (suspend) {
      suspendedSellerIds.add(sellerId);
      final all = await TGProductService.instance.getAll();
      for (final p in all.where((x) => x.seller.id == sellerId && x.isPubliclyVisible)) {
        await _patchListing(p.listingNo ?? p.id, (x) {
          hiddenAt[x.listingNo ?? x.id] = now;
          return x.copyWith(isHidden: true, status: TGListingStatus.underReview);
        });
      }
      final store = TGSellerProfileService.instance.bySellerKey(sellerId);
      if (store != null) {
        TGSellerProfileService.instance.patch(store.publicId, (p) => p.copyWith(status: TGStoreStatus.suspended));
      }
    }
    _enqueue(
      templateId: suspend ? 'suspend_notice' : 'warn_notice',
      lang: 'en',
      to: profile?.email ?? 'seller@example.com',
      vars: {'listingNo': listingNo, 'seller': profile?.seller.name ?? sellerId},
      sendNow: true,
    );
    _audit(
      actorId: actorId,
      actorRole: actorRole,
      action: suspend ? TGModerationActionType.suspend : TGModerationActionType.warn,
      listingNo: listingNo.isEmpty ? null : listingNo,
      summary: suspend ? 'Account suspended' : 'Account warned',
    );
    if (listingNo.isNotEmpty) _event(listingNo, suspend ? 'Seller account suspended' : 'Seller warned');
    TGAnalytics.track('admin_action', {'type': suspend ? 'suspend' : 'warn', 'sellerId': sellerId, 'target': 'seller'});
    notifyListeners();
  }

  Future<void> restore({
    required String listingNo,
    required String actorId,
    required String actorRole,
    FakeAuthState? auth,
  }) async {
    final hiddenSince = hiddenAt.remove(listingNo);
    TGListingSource? source;
    await _patchListing(listingNo, (p) {
      source = p.source;
      var expires = p.expiresAt;
      if (hiddenSince != null && expires != null) {
        expires = expires.add(now.difference(hiddenSince));
      }
      return p.copyWith(status: TGListingStatus.active, isHidden: false, expiresAt: expires);
    });
    if (source == TGListingSource.store) {
      storeCreditsRefunded += 1;
      auth?.refundStoreSlot();
    }
    final sc = sellerCases[listingNo];
    if (sc != null) {
      sc.finalRemoval = false;
      sc.appealed = false;
    }
    final c = cases[listingNo];
    if (c != null) {
      c.status = TGReportStatus.resolvedOther;
      _touchReports(listingNo, TGReportStatus.resolvedOther);
    }
    _enqueue(templateId: 'restore_notice', lang: 'en', to: _sellerEmail(listingNo), vars: _vars(listingNo), sendNow: true);
    _audit(actorId: actorId, actorRole: actorRole, action: TGModerationActionType.restore, listingNo: listingNo, summary: 'Restored listing');
    _event(listingNo, 'Listing restored (expiry extended by hidden time)');
    TGAnalytics.track('admin_action', {'type': 'restore', 'listingNo': listingNo});
    notifyListeners();
  }

  void decideAppeal({
    required String appealId,
    required bool uphold,
    required String actorId,
    required String actorRole,
  }) {
    final i = appeals.indexWhere((a) => a.id == appealId);
    if (i < 0) return;
    appeals[i] = appeals[i].copyWith(resolved: true, upheld: uphold);
    _audit(
      actorId: actorId,
      actorRole: actorRole,
      action: TGModerationActionType.appealDecision,
      listingNo: appeals[i].listingNo,
      summary: uphold ? 'Appeal upheld' : 'Appeal rejected',
    );
    _event(appeals[i].listingNo, uphold ? 'Appeal upheld' : 'Appeal rejected');
    if (!uphold) {
      final sc = sellerCases[appeals[i].listingNo];
      if (sc != null) sc.finalRemoval = true;
    }
    TGAnalytics.track('appeal_decision', {'appealId': appealId, 'upheld': uphold});
    notifyListeners();
  }

  void upsertTemplate(TGEmailTemplate template) {
    final i = templates.indexWhere((t) => t.id == template.id && t.lang == template.lang);
    if (i >= 0) {
      templates[i] = template;
    } else {
      templates.add(template);
    }
    notifyListeners();
  }

  void deleteTemplate(String id, String lang) {
    templates.removeWhere((t) => t.id == id && t.lang == lang);
    notifyListeners();
  }

  Future<void> _applyRemove(TGProduct product) async {
    final no = product.listingNo ?? product.id;
    hiddenAt[no] = now;
    await TGProductService.instance.upsert(product.copyWith(status: TGListingStatus.removed, isHidden: true));
    final profile = sellers[product.seller.id];
    if (profile != null) {
      sellers[product.seller.id] = profile.copyWith(pastRemovals: profile.pastRemovals + 1);
    }
  }

  Future<void> _patchListing(String listingNo, TGProduct Function(TGProduct) fn) async {
    final p = await TGProductService.instance.getById(listingNo);
    if (p == null) return;
    await TGProductService.instance.upsert(fn(p));
  }

  void _resolve(String listingNo, TGReportStatus status) {
    final c = cases[listingNo];
    if (c != null) c.status = status;
    _touchReports(listingNo, status);
  }

  void _touchReports(String listingNo, TGReportStatus status) {
    for (var i = 0; i < reports.length; i++) {
      if (reports[i].listingNo == listingNo && reports[i].status.isOpen) {
        reports[i] = reports[i].copyWith(status: status);
      }
    }
  }

  Map<String, String> _vars(String listingNo) => {
        'listingNo': listingNo,
        'to': _sellerEmail(listingNo),
        'seller': _sellerName(listingNo),
      };

  String _sellerEmail(String listingNo) {
    final id = cases[listingNo]?.sellerId;
    return sellers[id]?.email ?? 'seller@example.com';
  }

  String _sellerName(String listingNo) {
    final id = cases[listingNo]?.sellerId;
    return sellers[id]?.seller.name ?? 'seller';
  }

  List<String> _reporterEmails(String listingNo) =>
      reports.where((r) => r.listingNo == listingNo).map((r) => r.reporterEmail).toSet().toList();

  TGQueuedEmail _enqueue({
    required String templateId,
    required String lang,
    required String to,
    required Map<String, String> vars,
    required bool sendNow,
  }) {
    final preview = previewEmail(templateId: templateId, lang: lang, vars: {...vars, 'to': to});
    final mail = TGQueuedEmail(
      id: 'mail_${++_seq}',
      to: to,
      subject: preview.subject,
      body: preview.body,
      templateId: templateId,
      createdAt: now,
      listingNo: vars['listingNo'],
      sent: sendNow,
    );
    emails.add(mail);
    return mail;
  }

  void _audit({
    required String actorId,
    required String actorRole,
    required TGModerationActionType action,
    required String summary,
    String? listingNo,
    String? reportNo,
    String? reason,
    Map<String, String> details = const {},
  }) {
    audit.add(TGAuditEntry(
      id: 'aud_${++_seq}',
      at: now,
      actorId: actorId,
      actorRole: actorRole,
      action: action,
      summary: summary,
      listingNo: listingNo,
      reportNo: reportNo,
      reason: reason,
      details: details,
    ));
  }

  void _event(String listingNo, String label, [String? detail]) {
    events.putIfAbsent(listingNo, () => []);
    events[listingNo]!.add(TGCaseEvent(at: now, label: label, detail: detail));
  }

  void openCaseTracked(String listingNo) {
    TGAnalytics.track('admin_case_open', {'listingNo': listingNo});
  }

  TGSellerModerationCase? sellerCaseFor(String? listingNo) {
    if (listingNo == null) return null;
    return sellerCases[listingNo];
  }

  static String caseKeyFor(TGReportTarget target, String id) => switch (target) {
        TGReportTarget.listing => id,
        TGReportTarget.seller => 's:$id',
        TGReportTarget.review => 'r:$id',
        TGReportTarget.request => 'q:$id',
      };

  TGPublicReportResult submitListingReport({
    required TGProduct product,
    required TGReportReason reason,
    required String email,
    required String reporterId,
    String text = '',
    String? name,
    String? otherListingRef,
    String? originalListingRef,
    bool isOriginalOwner = false,
    TGMisleadingPart? misleadingPart,
    List<TGFraudSignal> fraudSignals = const [],
    List<String> evidenceUrls = const [],
  }) =>
      submitReport(
        target: TGReportTarget.listing,
        targetId: product.listingNo ?? product.id,
        reason: reason,
        email: email,
        reporterId: reporterId,
        text: text,
        name: name,
        otherListingRef: otherListingRef,
        originalListingRef: originalListingRef,
        isOriginalOwner: isOriginalOwner,
        misleadingPart: misleadingPart,
        fraudSignals: fraudSignals,
        evidenceUrls: evidenceUrls,
        product: product,
        sellerId: product.seller.id,
      );

  TGPublicReportResult submitReport({
    required TGReportTarget target,
    required String targetId,
    required TGReportReason reason,
    required String email,
    required String reporterId,
    String text = '',
    String? name,
    String? sellerId,
    String? reviewId,
    String? otherListingRef,
    String? originalListingRef,
    bool isOriginalOwner = false,
    TGMisleadingPart? misleadingPart,
    List<TGFraudSignal> fraudSignals = const [],
    List<String> evidenceUrls = const [],
    TGProduct? product,
  }) {
    ensureSeeded();
    final listingNo = caseKeyFor(target, targetId);
    final id = reporterId.startsWith('guest') ? 'guest:${email.trim().toLowerCase()}' : reporterId;
    final existing = reports
        .where((r) =>
            r.listingNo == listingNo && (r.reporterId == id || r.reporterEmail.toLowerCase() == email.trim().toLowerCase()))
        .firstOrNull;
    if (existing != null) {
      TGAnalytics.track('report_duplicate_attempt', {'listingNo': listingNo, 'reportNo': existing.reportNo, 'target': target.name});
      return TGPublicReportResult(duplicateOf: existing);
    }
    final hourAgo = now.subtract(const Duration(hours: 1));
    final recent = reports.where((r) => r.reporterId == id && r.createdAt.isAfter(hourAgo)).length;
    if (recent >= 5) {
      TGAnalytics.track('report_duplicate_attempt', {'listingNo': listingNo, 'reason': 'rate_limit', 'target': target.name});
      return const TGPublicReportResult(rateLimited: true);
    }
    final no = 'R-2026-${_publicSeq.toString().padLeft(6, '0')}';
    _publicSeq += 1;
    final report = TGModerationReport(
      reportNo: no,
      listingNo: listingNo,
      target: target,
      sellerId: sellerId,
      reviewId: reviewId ?? (target == TGReportTarget.review ? targetId : null),
      reason: reason,
      reporterEmail: email,
      reporterId: id,
      reporterName: name,
      text: text,
      createdAt: now,
      evidenceUrls: evidenceUrls,
      otherListingRef: otherListingRef,
      originalListingRef: originalListingRef,
      isOriginalOwner: isOriginalOwner,
      misleadingPart: misleadingPart,
      fraudSignals: fraudSignals,
      confirmed: true,
    );
    reports.add(report);
    if (target == TGReportTarget.listing && reason == TGReportReason.sold && product != null) {
      _openSoldHold(product: product, reporterId: id);
    }
    _rebuildCases(promoted: {'10482137'});
    _audit(
      actorId: id,
      actorRole: 'reporter',
      action: TGModerationActionType.assign,
      listingNo: report.listingNo,
      reportNo: no,
      summary: 'Public report $no (${reason.label})',
      details: {'target': target.name},
    );
    TGAnalytics.track('report_submit', {'listingNo': report.listingNo, 'reason': reason.name, 'reportNo': no, 'target': target.name});
    if (target == TGReportTarget.listing) {
      TGAnalytics.track('report_listing_submit', {'listingNo': report.listingNo, 'reason': reason.name, 'reportNo': no});
    } else if (target == TGReportTarget.review) {
      TGAnalytics.track('review_report', {'reviewId': report.reviewId, 'reportNo': no, 'reason': reason.name});
    }
    notifyListeners();
    return TGPublicReportResult(report: report);
  }

  void respondAsSeller({
    required String listingNo,
    required String message,
    List<String> evidence = const [],
    required String actorId,
  }) {
    final c = sellerCases[listingNo];
    if (c == null) return;
    c.responses.add(message);
    _event(listingNo, 'Seller response received', message);
    _audit(actorId: actorId, actorRole: 'seller', action: TGModerationActionType.requestInfo, listingNo: listingNo, summary: 'Seller responded');
    TGAnalytics.track('seller_response_submit', {'listingNo': listingNo});
    TGAnalytics.track('seller_moderation_respond', {'listingNo': listingNo});
    notifyListeners();
  }

  void appealAsSeller({
    required String listingNo,
    required String statement,
    required String actorId,
    List<String> evidence = const [],
  }) {
    final c = sellerCases[listingNo];
    if (c == null || c.appealed || c.finalRemoval) return;
    c.appealed = true;
    appeals.add(TGModerationAppeal(
      id: 'ap_${++_seq}',
      listingNo: listingNo,
      sellerId: c.listing.seller.id,
      createdAt: now,
      statement: statement,
      evidenceUrls: evidence,
    ));
    _audit(actorId: actorId, actorRole: 'seller', action: TGModerationActionType.appealDecision, listingNo: listingNo, summary: 'Seller appealed');
    TGAnalytics.track('appeal_submit', {'listingNo': listingNo});
    TGAnalytics.track('seller_moderation_appeal', {'listingNo': listingNo});
    notifyListeners();
  }

  bool _isSoldHold(String listingNo) {
    final hold = soldHolds[listingNo];
    if (hold == null || hold.resolved) return false;
    if (hold.shouldEscalate(now)) return false;
    final open = reports.where((r) => r.listingNo == listingNo && r.status.isOpen);
    return open.isNotEmpty && open.every((r) => r.reason == TGReportReason.sold);
  }

  void _escalateDueSoldHolds() {
    for (final hold in soldHolds.values) {
      if (!hold.shouldEscalate(now)) continue;
      final c = cases[hold.listingNo];
      if (c != null && c.priority == TGModerationPriority.low) {
        c.priority = TGModerationPriority.medium;
      }
    }
  }

  void _openSoldHold({required TGProduct product, required String reporterId}) {
    final listingNo = product.listingNo ?? product.id;
    final hold = soldHolds.putIfAbsent(listingNo, () => TGSoldHold(listingNo: listingNo, askedAt: now));
    hold.reporterIds.add(reporterId);
    final existing = sellerCases[listingNo];
    if (existing == null) {
      sellerCases[listingNo] = TGSellerModerationCase(
        listing: product,
        moderatorMessage: 'This listing is under content review.',
        soldNudge: true,
      );
    } else {
      existing.soldNudge = true;
    }
    _enqueue(
      templateId: 'sold_nudge',
      lang: 'en',
      to: sellers[product.seller.id]?.email ?? _sellerEmail(listingNo),
      vars: {..._vars(listingNo), 'seller': product.seller.name},
      sendNow: true,
    );
  }

  void keepListingLive(String listingNo, {required String actorId}) {
    final hold = soldHolds[listingNo];
    if (hold != null) hold.resolved = true;
    final sc = sellerCases[listingNo];
    if (sc != null) {
      sc.soldNudge = false;
      sc.soldResolved = true;
    }
    _event(listingNo, 'Seller confirmed listing still for sale');
    _audit(actorId: actorId, actorRole: 'seller', action: TGModerationActionType.requestInfo, listingNo: listingNo, summary: 'Seller kept listing live');
    notifyListeners();
  }

  Future<void> markListingSold(String listingNo, {required String actorId}) async {
    final hold = soldHolds[listingNo];
    if (hold != null) hold.resolved = true;
    final sc = sellerCases[listingNo];
    if (sc != null) {
      sc.soldNudge = false;
      sc.soldResolved = true;
    }
    await _patchListing(listingNo, (p) => p.copyWith(status: TGListingStatus.expired, isHidden: false));
    _touchReports(listingNo, TGReportStatus.resolvedOther);
    final c = cases[listingNo];
    if (c != null) c.status = TGReportStatus.resolvedOther;
    _event(listingNo, 'Seller marked listing sold');
    _audit(actorId: actorId, actorRole: 'seller', action: TGModerationActionType.remove, listingNo: listingNo, summary: 'Seller marked sold');
    notifyListeners();
  }

  void _seed() {
    final t = DateTime.now();
    templates.addAll(_seedTemplates());

    const prime = TGSeller(id: 'seller_primegastro', name: 'PrimeGastro', type: TGSellerType.store, verified: true, rating: 4.9);
    const gastro = TGSeller(id: 'seller_gastropl', name: 'GastroPL Outlet', type: TGSellerType.store, verified: true, rating: 4.7);
    const mateusz = TGSeller(id: 'seller_mateusz', name: 'Mateusz K.', type: TGSellerType.private, verified: false, rating: 4.4);
    const technica = TGSeller(id: 'seller_technica', name: 'Technica Pro', type: TGSellerType.store, verified: false, rating: 4.2);
    const anna = TGSeller(id: 'seller_anna', name: 'Anna P.', type: TGSellerType.private, verified: true, rating: 4.6);

    sellers.addAll({
      prime.id: TGModerationSeller(seller: prime, phone: '+48 532 784 074', nip: '5252341136', email: 'biuro@primegastro.pl', accountCreatedAt: t.subtract(const Duration(days: 1400)), pastReports: 2, pastRemovals: 0),
      gastro.id: TGModerationSeller(seller: gastro, phone: '+48 532 784 074', nip: '6345678901', email: 'hello@gastropl.pl', accountCreatedAt: t.subtract(const Duration(days: 900)), pastReports: 1, pastRemovals: 0),
      mateusz.id: TGModerationSeller(seller: mateusz, phone: '+48 601 222 111', email: 'mateusz.k@example.com', accountCreatedAt: t.subtract(const Duration(days: 220)), pastReports: 4, pastRemovals: 1),
      technica.id: TGModerationSeller(seller: technica, phone: '+48 698 111 222', nip: '9876543210', email: 'office@technica.pro', accountCreatedAt: t.subtract(const Duration(days: 510)), pastReports: 6, pastRemovals: 2),
      anna.id: TGModerationSeller(seller: anna, phone: '+48 601 222 111', email: 'anna.p@example.com', accountCreatedAt: t.subtract(const Duration(days: 640)), pastReports: 1, pastRemovals: 0),
    });

    photoMatches.addAll(const [
      TGPhotoMatch(
        listingNoA: '11820463',
        listingNoB: '12938570',
        similarityPercent: 94,
        imageA: 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg',
        imageB: 'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp',
      ),
      TGPhotoMatch(
        listingNoA: '13049281',
        listingNoB: '17102958',
        similarityPercent: 88,
        imageA: 'assets/images/pol_pm_Wanna-bemarowa-3X-GN-1-1-Komat-KCB-001-031-2808_2.png',
        imageB: 'assets/images/IMG_3696-scaled.webp',
      ),
      TGPhotoMatch(
        listingNoA: '19384720',
        listingNoB: '20491837',
        similarityPercent: 81,
        imageA: 'assets/images/Food_Prepering_table.jpg',
        imageB: 'assets/images/blog-26.jpg',
      ),
    ]);

    void add({
      required String no,
      required String listingNo,
      required TGReportReason reason,
      required String email,
      required String reporterId,
      required String text,
      required Duration ago,
      TGReportStatus status = TGReportStatus.new_,
      List<String> evidence = const [],
    }) {
      reports.add(TGModerationReport(
        reportNo: no,
        listingNo: listingNo,
        reason: reason,
        reporterEmail: email,
        reporterId: reporterId,
        text: text,
        createdAt: t.subtract(ago),
        status: status,
        evidenceUrls: evidence,
      ));
    }

    // Fraud High — 3 distinct reporters in 7 days on promoted listing 10482137.
    add(no: 'RP-24011', listingNo: '10482137', reason: TGReportReason.fraud, email: 'jan.k@example.com', reporterId: 'r_jan', text: 'Sprzedający poprosił o przelew na zagraniczne konto poza platformą. To wygląda na oszustwo.', ago: const Duration(hours: 6), evidence: ['assets/images/image.png']);
    add(no: 'RP-24012', listingNo: '10482137', reason: TGReportReason.fraud, email: 'ola.w@example.com', reporterId: 'r_ola', text: 'Sprzedający poprosił o przelew BLIK na prywatny numer.', ago: const Duration(hours: 4));
    add(no: 'RP-24013', listingNo: '10482137', reason: TGReportReason.prohibited, email: 'piotr.b@example.com', reporterId: 'r_piotr', text: 'Tabliczka z numerem seryjnym wygląda na spiłowaną na 3. zdjęciu.', ago: const Duration(hours: 2), evidence: ['assets/images/bartscher_2002170.webp']);

    // 3 copy cases.
    add(no: 'RP-24021', listingNo: '11820463', reason: TGReportReason.copied, email: 'studio@example.com', reporterId: 'r_studio', text: 'Te zdjęcia skopiowano z naszego katalogu.', ago: const Duration(hours: 10), evidence: ['assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg']);
    add(no: 'RP-24022', listingNo: '13049281', reason: TGReportReason.copied, email: 'brand@example.com', reporterId: 'r_brand', text: 'Stolen manufacturer photos — see side-by-side.', ago: const Duration(hours: 18));
    add(no: 'RP-24023', listingNo: '19384720', reason: TGReportReason.duplicate, email: 'kasia.m@example.com', reporterId: 'r_kasia', text: 'Same listing posted twice with a different title.', ago: const Duration(hours: 8));

    add(no: 'RP-24031', listingNo: '14120395', reason: TGReportReason.prohibited, email: 'legal@example.com', reporterId: 'r_legal', text: 'Item appears on the prohibited equipment list.', ago: const Duration(hours: 20), status: TGReportStatus.inReview);
    add(no: 'RP-24032', listingNo: '15293840', reason: TGReportReason.duplicate, email: 'marek.z@example.com', reporterId: 'r_marek', text: 'Copy of an older listing from last month.', ago: const Duration(hours: 30), status: TGReportStatus.inReview);
    add(no: 'RP-24033', listingNo: '18293046', reason: TGReportReason.wrongCategory, email: 'buyer1@example.com', reporterId: 'r_b1', text: 'This is bar equipment, not cooking.', ago: const Duration(hours: 12));
    add(no: 'RP-24034', listingNo: '22614059', reason: TGReportReason.sold, email: 'buyer2@example.com', reporterId: 'r_b2', text: 'To ogłoszenie wygląda na sprzedane.', ago: const Duration(hours: 3));
    add(no: 'RP-24035', listingNo: '23725160', reason: TGReportReason.other, email: 'buyer3@example.com', reporterId: 'r_b3', text: 'Description does not match the photos.', ago: const Duration(hours: 14));
    add(no: 'RP-24036', listingNo: '24836271', reason: TGReportReason.misleading, email: 'buyer4@example.com', reporterId: 'r_b4', text: 'Hours of use look much higher than claimed.', ago: const Duration(hours: 40), status: TGReportStatus.waitingSeller);
    add(no: 'RP-24037', listingNo: '25947382', reason: TGReportReason.fakePhotos, email: 'buyer5@example.com', reporterId: 'r_b5', text: 'Stock photos, not the actual unit.', ago: const Duration(hours: 22), status: TGReportStatus.waitingSeller, evidence: ['assets/images/images.jpeg']);
    add(no: 'RP-24038', listingNo: '26058493', reason: TGReportReason.prohibited, email: 'watch@example.com', reporterId: 'r_watch', text: 'Possible illegal import — no CE mark.', ago: const Duration(hours: 30));

    add(no: 'R-2026-000401', listingNo: '48019273', reason: TGReportReason.fraud, email: 'buyer.a@example.com', reporterId: 'r_pub1', text: 'Sprzedający poprosił o przelew BLIK przed odbiorem.', ago: const Duration(hours: 16), status: TGReportStatus.waitingSeller);
    add(no: 'R-2026-000402', listingNo: '49120384', reason: TGReportReason.copied, email: 'owner.b@example.com', reporterId: 'r_pub2', text: 'These photos are from my original listing.', ago: const Duration(hours: 20), status: TGReportStatus.inReview);
    add(no: 'R-2026-000403', listingNo: '50231495', reason: TGReportReason.prohibited, email: 'watch.c@example.com', reporterId: 'r_pub3', text: 'Serial plate filed off — not legal to sell.', ago: const Duration(days: 3), status: TGReportStatus.resolvedRemoved);
    add(no: 'R-2026-000404', listingNo: '27169504', reason: TGReportReason.duplicate, email: 'dup.d@example.com', reporterId: 'r_pub4', text: 'Same unit listed twice this week.', ago: const Duration(hours: 9));
    add(no: 'R-2026-000405', listingNo: '12938570', reason: TGReportReason.sold, email: 'sold.e@example.com', reporterId: 'r_pub5', text: 'Seller said it already sold.', ago: const Duration(hours: 5));
    add(no: 'R-2026-000406', listingNo: '17102958', reason: TGReportReason.misleading, email: 'price.f@example.com', reporterId: 'r_pub6', text: 'Price in the photos does not match the ad.', ago: const Duration(hours: 11));
    add(no: 'R-2026-000407', listingNo: '20491837', reason: TGReportReason.wrongCategory, email: 'cat.g@example.com', reporterId: 'r_pub7', text: 'This belongs in refrigeration, not cooking.', ago: const Duration(hours: 7));
    add(no: 'R-2026-000408', listingNo: '21503948', reason: TGReportReason.other, email: 'other.h@example.com', reporterId: 'r_pub8', text: 'The voltage listed looks impossible for this model.', ago: const Duration(hours: 13));

    void addTargeted({
      required String no,
      required TGReportTarget target,
      required String targetId,
      required TGReportReason reason,
      required String email,
      required String reporterId,
      required String text,
      required Duration ago,
      String? sellerId,
      String? reviewId,
      TGReportStatus status = TGReportStatus.new_,
    }) {
      reports.add(TGModerationReport(
        reportNo: no,
        listingNo: caseKeyFor(target, targetId),
        target: target,
        sellerId: sellerId,
        reviewId: reviewId,
        reason: reason,
        reporterEmail: email,
        reporterId: reporterId,
        text: text,
        createdAt: t.subtract(ago),
        status: status,
      ));
    }

    addTargeted(no: 'R-2026-000409', target: TGReportTarget.seller, targetId: 'seller_technica', sellerId: 'seller_technica', reason: TGReportReason.fakeStore, email: 'watch.store@example.com', reporterId: 'r_s1', text: 'This shop copies Technica branding from another company in Katowice.', ago: const Duration(hours: 9));
    addTargeted(no: 'R-2026-000410', target: TGReportTarget.seller, targetId: 'seller_primegastro', sellerId: 'seller_primegastro', reason: TGReportReason.fraud, email: 'buyer.s2@example.com', reporterId: 'r_s2', text: 'The store asked for a BLIK transfer before any visit to the showroom.', ago: const Duration(hours: 15));
    addTargeted(no: 'R-2026-000411', target: TGReportTarget.seller, targetId: 'seller_ek', sellerId: 'seller_ek', reason: TGReportReason.fakeReviews, email: 'mod.watch@example.com', reporterId: 'r_s3', text: 'Several five-star reviews appeared on the same afternoon from similar names.', ago: const Duration(hours: 28));
    addTargeted(no: 'R-2026-000412', target: TGReportTarget.review, targetId: 'R-2026-0002', sellerId: 'seller_technica', reviewId: 'R-2026-0002', reason: TGReportReason.fakeReview, email: 'seller.rival@example.com', reporterId: 'r_rv1', text: 'This reviewer never collected anything — we have no matching invoice or visit.', ago: const Duration(hours: 5));
    addTargeted(no: 'R-2026-000413', target: TGReportTarget.review, targetId: 'R-2026-0004', sellerId: 'seller_technica', reviewId: 'R-2026-0004', reason: TGReportReason.sellerOrCompetitor, email: 'buyer.rv@example.com', reporterId: 'r_rv2', text: 'The wording matches the store’s own catalogue copy. Looks written in-house.', ago: const Duration(hours: 11));
    addTargeted(no: 'R-2026-000414', target: TGReportTarget.review, targetId: 'R-2026-0005', sellerId: 'seller_technica', reviewId: 'R-2026-0005', reason: TGReportReason.offensive, email: 'reader.x@example.com', reporterId: 'r_rv3', text: 'The review uses abusive language about staff that should not stay public.', ago: const Duration(hours: 7));
    addTargeted(no: 'R-2026-000415', target: TGReportTarget.review, targetId: 'R-2026-0003', sellerId: 'seller_technica', reviewId: 'R-2026-0003', reason: TGReportReason.personalData, email: 'privacy@example.com', reporterId: 'r_rv4', text: 'The text includes a private mobile number and a home address.', ago: const Duration(hours: 19));

    appeals.addAll([
      TGModerationAppeal(id: 'ap-01', listingNo: '16038472', sellerId: mateusz.id, createdAt: t.subtract(const Duration(days: 2)), statement: 'The listing was marked sold by mistake. Please restore.'),
      TGModerationAppeal(id: 'ap-02', listingNo: '21503948', sellerId: technica.id, createdAt: t.subtract(const Duration(days: 1)), statement: 'We renewed the unit photos and ask for a second review.'),
    ]);

    events['10482137'] = [
      TGCaseEvent(at: t.subtract(const Duration(hours: 6)), label: 'Report RP-24011 received', detail: 'Fraud'),
      TGCaseEvent(at: t.subtract(const Duration(hours: 4)), label: 'Report RP-24012 received', detail: 'Fraud'),
      TGCaseEvent(at: t.subtract(const Duration(hours: 2)), label: 'Report RP-24013 received', detail: 'Prohibited'),
    ];

    _rebuildCases(promoted: {'10482137'});
    cases['14120395']?.assignedTo = 'staff_moderator';
    cases['15293840']?.assignedTo = 'staff_moderator';
    cases['24836271']?.assignedTo = 'staff_admin';
    _seedPublicReportsAndSellerCases(t);
  }

  void _seedPublicReportsAndSellerCases(DateTime t) {
    final owner = FakeAuthState.mockOwnerSeller;
    final reviewOpen = TGProduct(
      id: 'own_mod_review',
      title: 'Mikser planetarny 40L – under review',
      price: 4200,
      priceUnit: TGPriceUnit.oneTime,
      priceBasis: TGPriceBasis.netto,
      negotiable: false,
      oldPrice: null,
      condition: TGCondition.used,
      listingType: TGListingType.buy,
      category: TGCategory.foodPreparation,
      powerType: TGPowerType.electric,
      warrantyMonths: 3,
      delivery: false,
      pickup: true,
      seller: owner,
      city: 'Katowice',
      voivodeship: 'Śląskie',
      phone: '+48 (532) 784-074',
      imageUrl: 'assets/images/bartscher_2002170.webp',
      photoCount: 4,
      isPromoted: false,
      createdAt: t.subtract(const Duration(days: 8)),
      description: 'Mixer currently under review after a fraud report.',
      status: TGListingStatus.underReview,
      publishedAt: t.subtract(const Duration(days: 8)),
      expiresAt: t.add(const Duration(days: 22)),
      source: TGListingSource.free,
      ownerId: FakeAuthState.mockOwnerId,
      listingNo: '48019273',
      isHidden: false,
    );
    final reviewHidden = reviewOpen.copyWith(
      id: 'own_mod_hidden',
      title: 'Witryna chłodnicza 2-drzwiowa – hidden',
      listingNo: '49120384',
      imageUrl: 'assets/images/images.jpeg',
      isHidden: true,
      description: 'Hidden while we wait for seller proof.',
    );
    final removed = reviewOpen.copyWith(
      id: 'own_mod_removed',
      title: 'Krajalnica chleba – removed',
      listingNo: '50231495',
      status: TGListingStatus.removed,
      isHidden: true,
      imageUrl: 'assets/images/IMG_3696-scaled.webp',
      description: 'Removed for prohibited content.',
    );
    sellerListings.addAll([reviewOpen, reviewHidden, removed]);
    sellerCases[reviewOpen.listingNo!] = TGSellerModerationCase(
      listing: reviewOpen,
      replyBy: DateTime(2026, 10, 10, 18),
      moderatorMessage: 'A buyer reported suspected fraud. Please confirm the unit is still available and show it working in a short video.',
      shortReason: 'Fraud',
    );
    sellerCases[reviewHidden.listingNo!] = TGSellerModerationCase(
      listing: reviewHidden,
      replyBy: DateTime(2026, 10, 11, 12),
      moderatorMessage: 'Photos may be copied. Upload proof you own this unit. The listing is hidden until we hear from you.',
      shortReason: 'Copied photos',
    );
    sellerCases[removed.listingNo!] = TGSellerModerationCase(
      listing: removed,
      shortReason: 'Prohibited',
      removalRule: 'Prohibited or illegal item',
      removalExplanation: 'The listing showed equipment with a filed serial plate, which is not allowed on Twoja Gastromania.',
      moderatorMessage: 'This listing was removed because it offered a prohibited item.',
      decidedAt: t.subtract(const Duration(days: 1)),
      decidedByHuman: true,
    );
    TGListingNo.reserveAll(sellerListings.map((p) => p.listingNo));
    _rebuildCases(promoted: {'10482137'});
  }

  void _rebuildCases({Set<String> promoted = const {}}) {
    cases.clear();
    final grouped = <String, List<TGModerationReport>>{};
    for (final r in reports) {
      grouped.putIfAbsent(r.listingNo, () => []).add(r);
    }
    grouped.forEach((listingNo, list) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final open = list.where((r) => r.status.isOpen).toList();
      final use = open.isEmpty ? list : open;
      final status = use.map((r) => r.status).reduce((a, b) {
        const order = [
          TGReportStatus.waitingSeller,
          TGReportStatus.inReview,
          TGReportStatus.new_,
          TGReportStatus.resolvedRemoved,
          TGReportStatus.resolvedOther,
          TGReportStatus.resolvedNoViolation,
        ];
        return order.indexOf(a) <= order.indexOf(b) ? a : b;
      });
      final first = use.first.createdAt;
      final priority = computePriority(listingReports: list, promoted: promoted.contains(listingNo), at: first.add(const Duration(minutes: 1)));
      cases[listingNo] = TGQueueCase(
        listingNo: listingNo,
        reports: list,
        priority: priority,
        status: status,
        firstReportedAt: first,
        slaDeadline: slaDeadlineFor(priority, first),
        sellerId: list.first.sellerId ?? kListingSellers[listingNo],
      );
    });
    for (final a in appeals) {
      if (cases.containsKey(a.listingNo)) continue;
      cases[a.listingNo] = TGQueueCase(
        listingNo: a.listingNo,
        reports: const [],
        priority: TGModerationPriority.medium,
        status: TGReportStatus.resolvedOther,
        firstReportedAt: a.createdAt,
        slaDeadline: slaDeadlineFor(TGModerationPriority.medium, a.createdAt),
        sellerId: kListingSellers[a.listingNo],
      );
    }
  }
}

const kListingSellers = <String, String>{
  '10482137': 'seller_primegastro',
  '11820463': 'seller_gastropl',
  '12938570': 'seller_technica',
  '13049281': 'seller_mateusz',
  '14120395': 'seller_anna',
  '15293840': 'seller_primegastro',
  '16038472': 'seller_mateusz',
  '17102958': 'seller_gastropl',
  '18293046': 'seller_technica',
  '19384720': 'seller_primegastro',
  '20491837': 'seller_gastropl',
  '21503948': 'seller_mateusz',
  '22614059': 'seller_anna',
  '23725160': 'seller_technica',
  '24836271': 'seller_primegastro',
  '25947382': 'seller_gastropl',
  '26058493': 'seller_anna',
  '27169504': 'seller_technica',
  '48019273': 'seller_tg',
  '49120384': 'seller_tg',
  '50231495': 'seller_tg',
};

List<TGEmailTemplate> _seedTemplates() {
  const platform =
      'Twoja Gastromania is an independent listing venue. We do not guarantee listings or sales. This message is an automated moderation notice.';
  return const [
    TGEmailTemplate(id: 'reporter_no_violation', name: 'Reporter · no violation', lang: 'en', subject: 'Update on listing {listingNo}', body: 'Hello,\n\nWe reviewed listing {listingNo}. No violation was found.\n\n$platform'),
    TGEmailTemplate(id: 'reporter_no_violation', name: 'Zgłaszający · brak naruszenia', lang: 'pl', subject: 'Aktualizacja ogłoszenia {listingNo}', body: 'Dzień dobry,\n\nSprawdziliśmy ogłoszenie {listingNo}. Nie stwierdzono naruszenia.\n\n$platform'),
    TGEmailTemplate(id: 'reporter_action_taken', name: 'Reporter · action taken', lang: 'en', subject: 'Update on listing {listingNo}', body: 'Hello,\n\nAction was taken on listing {listingNo}. For privacy we cannot share the seller’s identity or the full outcome.\n\n$platform'),
    TGEmailTemplate(id: 'reporter_action_taken', name: 'Zgłaszający · podjęto działanie', lang: 'pl', subject: 'Aktualizacja ogłoszenia {listingNo}', body: 'Dzień dobry,\n\nW sprawie ogłoszenia {listingNo} podjęto działanie. Ze względów prywatności nie podajemy tożsamości sprzedającego.\n\n$platform'),
    TGEmailTemplate(id: 'request_info', name: 'Request info', lang: 'en', subject: 'We need more information · listing {listingNo}', body: 'Hello {seller},\n\nPlease reply within {days} days with the missing details for listing {listingNo}. The listing is under review.\n\n$platform'),
    TGEmailTemplate(id: 'request_info', name: 'Prośba o informacje', lang: 'pl', subject: 'Potrzebujemy informacji · ogłoszenie {listingNo}', body: 'Dzień dobry {seller},\n\nProsimy o uzupełnienie informacji do ogłoszenia {listingNo} w ciągu {days} dni. Ogłoszenie jest w weryfikacji.\n\n$platform'),
    TGEmailTemplate(id: 'request_proof', name: 'Request proof', lang: 'en', subject: 'Please verify listing {listingNo}', body: 'Hello {seller},\n\nA report flagged photos on listing {listingNo} as possibly fake. Please send a 5–10 second video or photos that show the unit beside you and in working condition. Individual sellers are not asked for invoices.\n\n$platform'),
    TGEmailTemplate(id: 'request_proof', name: 'Prośba o dowód', lang: 'pl', subject: 'Potwierdź ogłoszenie {listingNo}', body: 'Dzień dobry {seller},\n\nZgłoszono, że zdjęcia ogłoszenia {listingNo} mogą być nieautentyczne. Prosimy o 5–10-sekundowy film lub zdjęcia z urządzeniem obok Pani/Pana i w ruchu. Od sprzedawców prywatnych nie wymagamy faktury.\n\n$platform'),
    TGEmailTemplate(id: 'remove_seller', name: 'Remove · statement of reasons', lang: 'en', subject: 'Listing {listingNo} was removed', body: 'Hello {seller},\n\nListing {listingNo} was removed. Reason: {reason}.\n{description}\n\nYou may appeal from your dashboard.\n\n$platform'),
    TGEmailTemplate(id: 'remove_seller', name: 'Usunięcie · uzasadnienie', lang: 'pl', subject: 'Ogłoszenie {listingNo} zostało usunięte', body: 'Dzień dobry {seller},\n\nOgłoszenie {listingNo} zostało usunięte. Powód: {reason}.\n{description}\n\nOdwołanie można złożyć w panelu.\n\n$platform'),
    TGEmailTemplate(id: 'hide_notice', name: 'Hide notice', lang: 'en', subject: 'Listing {listingNo} is hidden', body: 'Hello {seller},\n\nListing {listingNo} is temporarily hidden while we review a report.\n\n$platform'),
    TGEmailTemplate(id: 'hide_notice', name: 'Ukrycie', lang: 'pl', subject: 'Ogłoszenie {listingNo} jest ukryte', body: 'Dzień dobry {seller},\n\nOgłoszenie {listingNo} jest tymczasowo ukryte na czas weryfikacji.\n\n$platform'),
    TGEmailTemplate(id: 'restore_notice', name: 'Restore notice', lang: 'en', subject: 'Listing {listingNo} was restored', body: 'Hello {seller},\n\nListing {listingNo} is live again. The live window was extended by the time it stayed hidden.\n\n$platform'),
    TGEmailTemplate(id: 'restore_notice', name: 'Przywrócenie', lang: 'pl', subject: 'Ogłoszenie {listingNo} przywrócone', body: 'Dzień dobry {seller},\n\nOgłoszenie {listingNo} jest ponownie widoczne. Czas ukrycia doliczyliśmy do daty wygaśnięcia.\n\n$platform'),
    TGEmailTemplate(id: 'contact_seller', name: 'Contact seller', lang: 'en', subject: 'Message about listing {listingNo}', body: 'Hello {seller},\n\n{body}\n\n$platform'),
    TGEmailTemplate(id: 'contact_seller', name: 'Kontakt ze sprzedającym', lang: 'pl', subject: 'Wiadomość o ogłoszeniu {listingNo}', body: 'Dzień dobry {seller},\n\n{body}\n\n$platform'),
    TGEmailTemplate(id: 'contact_reporter', name: 'Contact reporter', lang: 'en', subject: 'Your report on listing {listingNo}', body: 'Hello,\n\n{body}\n\n$platform'),
    TGEmailTemplate(id: 'contact_reporter', name: 'Kontakt ze zgłaszającym', lang: 'pl', subject: 'Twoje zgłoszenie ogłoszenia {listingNo}', body: 'Dzień dobry,\n\n{body}\n\n$platform'),
    TGEmailTemplate(id: 'warn_notice', name: 'Account warning', lang: 'en', subject: 'Warning — Twoja Gastromania', body: 'Hello {seller},\n\nThis is a formal warning about activity linked to your account. Further violations may lead to suspension.\n\n$platform'),
    TGEmailTemplate(id: 'warn_notice', name: 'Ostrzeżenie', lang: 'pl', subject: 'Ostrzeżenie — Twoja Gastromania', body: 'Dzień dobry {seller},\n\nTo formalne ostrzeżenie dotyczące aktywności konta. Kolejne naruszenia mogą skutkować blokadą.\n\n$platform'),
    TGEmailTemplate(id: 'suspend_notice', name: 'Account suspended', lang: 'en', subject: 'Account suspended — Twoja Gastromania', body: 'Hello {seller},\n\nYour account has been suspended. Live listings are hidden. You may appeal.\n\n$platform'),
    TGEmailTemplate(id: 'suspend_notice', name: 'Konto zawieszone', lang: 'pl', subject: 'Konto zawieszone — Twoja Gastromania', body: 'Dzień dobry {seller},\n\nKonto zostało zawieszone. Ogłoszenia są ukryte. Można złożyć odwołanie.\n\n$platform'),
    TGEmailTemplate(id: 'sold_nudge', name: 'Sold check', lang: 'en', subject: 'Is listing {listingNo} still for sale?', body: 'Hello {seller},\n\nA buyer asked whether listing {listingNo} is still for sale. Please confirm from your dashboard: keep it live, or mark it sold. We do not share who asked.\n\n$platform'),
    TGEmailTemplate(id: 'sold_nudge', name: 'Kontrola sprzedaży', lang: 'pl', subject: 'Czy ogłoszenie {listingNo} jest nadal na sprzedaż?', body: 'Dzień dobry {seller},\n\nKupujący zapytał, czy ogłoszenie {listingNo} jest nadal na sprzedaż. Potwierdź w panelu: zostaw aktywne albo oznacz jako sprzedane. Nie podajemy, kto zapytał.\n\n$platform'),
    TGEmailTemplate(id: 'remove_review', name: 'Remove review · statement of reasons', lang: 'en', subject: 'Your review was removed', body: 'Hello {seller},\n\nYour review was removed. Reason: {reason}.\n{description}\n\n$platform'),
    TGEmailTemplate(id: 'remove_review', name: 'Usunięcie opinii', lang: 'pl', subject: 'Twoja opinia została usunięta', body: 'Dzień dobry {seller},\n\nTwoja opinia została usunięta. Powód: {reason}.\n{description}\n\n$platform'),
    TGEmailTemplate(id: 'hide_review', name: 'Hide review', lang: 'en', subject: 'Your review is hidden while we review a report', body: 'Hello {seller},\n\nYour review is temporarily hidden while we review a report.\n\n$platform'),
    TGEmailTemplate(id: 'hide_review', name: 'Ukrycie opinii', lang: 'pl', subject: 'Twoja opinia jest ukryta', body: 'Dzień dobry {seller},\n\nTwoja opinia jest tymczasowo ukryta na czas weryfikacji.\n\n$platform'),
  ];
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
