import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

class DealModerationService extends ChangeNotifier {
  DealModerationService._();
  static final DealModerationService instance = DealModerationService._();

  final List<TGAdminDealCase> cases = [];
  final List<TGQueuedEmail> emails = [];
  TGAdminDealCase? lastUndo;
  Map<String, Object?>? _undoSnapshot;
  List<String> _undoEmailIds = [];
  bool _seeded = false;

  static const moderatorId = 'staff_moderator';
  static const adminId = 'staff_admin';

  void reset() {
    cases.clear();
    emails.clear();
    lastUndo = null;
    _undoSnapshot = null;
    _undoEmailIds = [];
    _seeded = false;
    ensureSeeded();
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    DealService.instance.ensureSeeded();
    _seed();
  }

  int count(TGDealQueueKind k) => k == TGDealQueueKind.all ? cases.length : cases.where((c) => c.queue == k).length;

  List<TGAdminDealCase> filtered(TGDealQueueKind queue) {
    final list = queue == TGDealQueueKind.all ? [...cases] : cases.where((c) => c.queue == queue).toList();
    list.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return a.decisionDueAt.compareTo(b.decisionDueAt);
    });
    return list;
  }

  TGAdminDealCase? byDealNo(String no) {
    final q = no.trim().toUpperCase();
    return cases.where((c) => c.dealNo.toUpperCase() == q).firstOrNull;
  }

  String? resolveSearch(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return null;
    final up = q.toUpperCase().replaceAll(' ', '');
    final m = RegExp(r'D-?\d{4}-?\d+').firstMatch(up);
    if (m != null) {
      var id = m.group(0)!;
      if (!id.startsWith('D-')) id = 'D-$id';
      if (RegExp(r'^D\d').hasMatch(id)) id = 'D-${id.substring(1)}';
      final hit = byDealNo(id) ?? cases.where((c) => c.dealNo.replaceAll('-', '') == id.replaceAll('-', '')).firstOrNull;
      return hit?.dealNo;
    }
    if (up.startsWith('D-') || up.startsWith('D2026')) {
      return byDealNo(up)?.dealNo;
    }
    return null;
  }

  bool canAssign(TGAdminDealCase c, String userId) {
    if (c.queue == TGDealQueueKind.appeal && c.removedBy == userId) return false;
    return true;
  }

  void assign(TGAdminDealCase c, String userId, {required String actorId, required String actorRole}) {
    if (!canAssign(c, userId)) return;
    c.assignedTo = userId;
    _audit(actorId, actorRole, 'assign', c.dealNo, 'Assigned ${c.dealNo}');
    notifyListeners();
  }

  void openTracked(String dealNo) {
    TGAnalytics.track('admin_deal_open', {'dealNo': dealNo});
  }

  void logView(TGAdminDealCase c, {required String actorName, required String kind}) {
    c.lastViewed = 'Viewed by $actorName · ${_hhmm(TGClock.now())}';
    TGAnalytics.track('admin_evidence_view', {'dealNo': c.dealNo, 'type': kind});
    notifyListeners();
  }

  void setCodeMatch(TGAdminDealCase c, TGCodeMatch v) {
    c.codeMatch = v;
    notifyListeners();
  }

  void setScore(TGAdminDealCase c, TGScoreRow row, TGScoreMark mark, {String? note}) {
    final line = c.scorecard.where((s) => s.row == row).firstOrNull;
    if (line == null) return;
    line.mark = mark;
    if (note != null) line.note = note;
    notifyListeners();
  }

  void markFlagsReviewed(TGAdminDealCase c, {required String actorId, required String actorRole}) {
    c.flagsReviewed = true;
    _audit(actorId, actorRole, 'flags_reviewed', c.dealNo, 'Marked flags reviewed');
    TGAnalytics.track('admin_deal_action', {'type': 'flags_reviewed', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void requestMoreEvidence(TGAdminDealCase c, {required String actorId, required String actorRole, String lang = 'en'}) {
    if (c.evidenceDueAt == null || c.evidenceExtended) return;
    final obj = c.linkedObjectionId == null ? null : DealService.instance.objections.where((o) => o.id == c.linkedObjectionId).firstOrNull;
    if (obj != null) DealService.instance.extendEvidenceOnce(obj);
    c.evidenceExtended = true;
    c.evidenceDueAt = c.evidenceDueAt!.add(const Duration(hours: 48));
    c.timeline = [
      ...c.timeline,
      TGDealTimelineEvent(at: TGClock.now(), actor: 'Moderator', label: 'Requested more evidence from buyer (+48 h)'),
    ];
    _queueMail(c, to: '${c.buyer.name} <buyer@mail.com>', templateId: 'deal_more_evidence', lang: lang, subject: 'More evidence needed', body: 'Please send additional evidence for ${c.dealNo}.');
    _audit(actorId, actorRole, 'request_evidence', c.dealNo, 'Requested more evidence');
    TGAnalytics.track('admin_deal_action', {'type': 'request_evidence', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void requestCrossCheck(TGAdminDealCase c, {required String actorId, required String actorRole, required String amount, required String date, String lang = 'en'}) {
    c.timeline = [
      ...c.timeline,
      TGDealTimelineEvent(at: TGClock.now(), actor: 'Moderator', label: 'Cross-check sent to seller: payment of about $amount around $date for No. ${c.listingNo}?'),
    ];
    _queueMail(c, to: '${c.seller.name} <seller@mail.com>', templateId: 'deal_crosscheck', lang: lang, subject: 'Quick check on a listing', body: 'Did you receive a payment of about $amount around $date for Listing No. ${c.listingNo}? Yes / No / Not sure.');
    _audit(actorId, actorRole, 'crosscheck', c.dealNo, 'Requested seller cross-check');
    TGAnalytics.track('admin_crosscheck_sent', {'dealNo': c.dealNo});
    notifyListeners();
  }

  void contactParty(TGAdminDealCase c, {required bool seller, required String actorId, required String actorRole, required String body, String lang = 'en'}) {
    final name = seller ? c.seller.name : c.buyer.name;
    _queueMail(c, to: '$name <party@mail.com>', templateId: seller ? 'deal_contact_seller' : 'deal_contact_buyer', lang: lang, subject: 'Message about ${c.dealNo}', body: body);
    c.timeline = [...c.timeline, TGDealTimelineEvent(at: TGClock.now(), actor: 'Moderator', label: seller ? 'Contacted seller' : 'Contacted buyer')];
    _audit(actorId, actorRole, seller ? 'contact_seller' : 'contact_buyer', c.dealNo, seller ? 'Contacted seller' : 'Contacted buyer');
    TGAnalytics.track('admin_deal_action', {'type': seller ? 'contact_seller' : 'contact_buyer', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void postThread(TGAdminDealCase c, {required bool seller, required String body, required String actorId, required String actorRole}) {
    final msg = TGDealThreadMsg(at: TGClock.now(), from: 'Moderator', body: body);
    if (seller) {
      c.sellerThread = [...c.sellerThread, msg];
    } else {
      c.buyerThread = [...c.buyerThread, msg];
    }
    _audit(actorId, actorRole, seller ? 'seller_thread' : 'buyer_thread', c.dealNo, seller ? 'Messaged seller' : 'Messaged buyer');
    TGAnalytics.track('admin_deal_action', {'type': seller ? 'seller_thread' : 'buyer_thread', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void openPrivateConversation(TGAdminDealCase c, {required String reason, required String actorId, required String actorRole}) {
    _audit(actorId, actorRole, 'private_conversation', c.dealNo, 'Opened private conversation', reason: reason);
    TGAnalytics.track('admin_private_conversation_open', {'dealNo': c.dealNo, 'reason': reason});
    notifyListeners();
  }

  void decide(
    TGAdminDealCase c, {
    required TGObjectionDecision decision,
    required String rationale,
    required bool markSold,
    required String actorId,
    required String actorRole,
  }) {
    _undoSnapshot = {
      'dealNo': c.dealNo,
      'status': c.statusLabel,
      'reviewState': c.reviewState,
      'queue': c.queue,
      'hardCapBreached': c.hardCapBreached,
    };
    lastUndo = c;
    _undoEmailIds = [];
    final obj = c.linkedObjectionId == null ? null : DealService.instance.objections.where((o) => o.id == c.linkedObjectionId).firstOrNull;
    if (obj != null) {
      DealService.instance.moderatorDecide(obj, decision, markListingSold: markSold);
    } else if (c.linkedReviewId != null) {
      final review = DealService.instance.reviewById(c.linkedReviewId!);
      final deal = c.linkedDealId == null ? null : DealService.instance.byId(c.linkedDealId!);
      if (review != null) {
        review.state = switch (decision) {
          TGObjectionDecision.confirmed => TGPurchaseReviewState.confirmedModerator,
          TGObjectionDecision.removed => TGPurchaseReviewState.removed,
          TGObjectionDecision.notVerified => TGPurchaseReviewState.notVerified,
        };
      }
      if (deal != null) {
        deal.status = switch (decision) {
          TGObjectionDecision.confirmed => TGDealStatus.confirmed,
          TGObjectionDecision.removed => TGDealStatus.rejectedByModerator,
          TGObjectionDecision.notVerified => TGDealStatus.notVerified,
        };
      }
    }
    c.reviewState = switch (decision) {
      TGObjectionDecision.confirmed => TGPurchaseReviewState.confirmedModerator,
      TGObjectionDecision.removed => TGPurchaseReviewState.removed,
      TGObjectionDecision.notVerified => TGPurchaseReviewState.notVerified,
    };
    c.statusLabel = switch (decision) {
      TGObjectionDecision.confirmed => 'Confirmed',
      TGObjectionDecision.removed => 'Removed',
      TGObjectionDecision.notVerified => 'Not verified',
    };
    c.evidenceDeleteAt = TGClock.now().add(const Duration(days: 30));
    if (decision == TGObjectionDecision.confirmed) {
      DealService.instance.unjustObjections90d[c.seller.userId] = (DealService.instance.unjustObjections90d[c.seller.userId] ?? 0) + 1;
      if (markSold) c.snapshotStatus = 'sold';
    }
    final buyerBody = switch (decision) {
      TGObjectionDecision.confirmed => 'Your review is live and counts toward the rating.',
      TGObjectionDecision.removed => 'This review was removed. A human moderator decided it did not meet our rules. You may appeal once.',
      TGObjectionDecision.notVerified => "We couldn't verify this deal. Your review stays visible but is not included in the rating.",
    };
    _queueMail(c, to: '${c.buyer.name} <buyer@mail.com>', templateId: 'deal_decision_buyer', lang: 'en', subject: 'Update on your review', body: buyerBody);
    _queueMail(c, to: '${c.seller.name} <seller@mail.com>', templateId: 'deal_decision_seller', lang: 'en', subject: 'Update on a review', body: 'A moderator reviewed the case for ${c.listingTitle}.');
    c.timeline = [...c.timeline, TGDealTimelineEvent(at: TGClock.now(), actor: 'Moderator', label: 'Decision: ${c.statusLabel}')];
    _audit(actorId, actorRole, 'decision', c.dealNo, 'Decision ${decision.name}', reason: rationale);
    TGAnalytics.track('admin_deal_decision', {'dealNo': c.dealNo, 'result': decision.name});
    notifyListeners();
  }

  void flaggedApprove(TGAdminDealCase c, {required String actorId, required String actorRole, required String rationale}) {
    c.reviewState = TGPurchaseReviewState.awaitingSeller;
    c.statusLabel = 'Released to seller check';
    c.timeline = [...c.timeline, TGDealTimelineEvent(at: TGClock.now(), actor: 'Moderator', label: 'Flagged review approved into the normal flow')];
    _audit(actorId, actorRole, 'flagged_approve', c.dealNo, 'Approved flagged review', reason: rationale);
    TGAnalytics.track('admin_deal_decision', {'dealNo': c.dealNo, 'result': 'approve'});
    notifyListeners();
  }

  void flaggedRemove(TGAdminDealCase c, {required String actorId, required String actorRole, required String rationale}) {
    c.reviewState = TGPurchaseReviewState.removed;
    c.statusLabel = 'Removed';
    c.removedBy = actorId;
    _audit(actorId, actorRole, 'flagged_remove', c.dealNo, 'Removed flagged review', reason: rationale);
    TGAnalytics.track('admin_deal_decision', {'dealNo': c.dealNo, 'result': 'remove'});
    notifyListeners();
  }

  void appealUphold(TGAdminDealCase c, {required String actorId, required String actorRole, required String rationale}) {
    if (!canAssign(c, actorId) && c.removedBy == actorId) return;
    c.statusLabel = 'Removal upheld';
    _audit(actorId, actorRole, 'appeal_uphold', c.dealNo, 'Upheld removal', reason: rationale);
    TGAnalytics.track('admin_deal_decision', {'dealNo': c.dealNo, 'result': 'uphold'});
    notifyListeners();
  }

  void appealOverturn(TGAdminDealCase c, {required TGObjectionDecision decision, required String actorId, required String actorRole, required String rationale, required bool markSold}) {
    if (c.removedBy == actorId) return;
    decide(c, decision: decision, rationale: rationale, markSold: markSold, actorId: actorId, actorRole: actorRole);
  }

  void removeNoEvidence(TGAdminDealCase c, {required String actorId, required String actorRole}) {
    decide(c, decision: TGObjectionDecision.removed, rationale: 'No evidence submitted in the window.', markSold: false, actorId: actorId, actorRole: actorRole);
  }

  void annul(TGAdminDealCase c, {required String actorId, required String actorRole, required String rationale}) {
    final prev = _undoSnapshot;
    if (prev != null && prev['dealNo'] == c.dealNo) {
      undo(actorId: actorId, actorRole: actorRole);
      return;
    }
    c.statusLabel = 'Open';
    c.reviewState = TGPurchaseReviewState.suspendedObjection;
    _audit(actorId, actorRole, 'annul', c.dealNo, 'Annulled decision', reason: rationale);
    TGAnalytics.track('admin_deal_action', {'type': 'annul', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void warnOrSuspend(TGAdminDealCase c, {required bool suspend, required String actorId, required String actorRole, required String rationale}) {
    _audit(actorId, actorRole, suspend ? 'suspend' : 'warn', c.dealNo, suspend ? 'Suspended seller' : 'Warned seller', reason: rationale);
    TGAnalytics.track('admin_deal_action', {'type': suspend ? 'suspend' : 'warn', 'dealNo': c.dealNo});
    notifyListeners();
  }

  void undo({required String actorId, required String actorRole}) {
    final c = lastUndo;
    final snap = _undoSnapshot;
    if (c == null || snap == null) return;
    c.statusLabel = snap['status'] as String;
    c.reviewState = snap['reviewState'] as TGPurchaseReviewState;
    lastUndo = null;
    _undoSnapshot = null;
    emails.removeWhere((e) => _undoEmailIds.contains(e.id));
    _undoEmailIds = [];
    _audit(actorId, actorRole, 'undo', c.dealNo, 'Undo decision');
    TGAnalytics.track('admin_undo', {'dealNo': c.dealNo});
    notifyListeners();
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    for (final c in cases.where((e) => e.queue == TGDealQueueKind.objection && !e.hardCapBreached)) {
      final files = c.evidence.where((e) => e.type != TGEvidenceType.photo);
      final hasStrong = files.isNotEmpty;
      if (c.hardCapAt != null && now.isAfter(c.hardCapAt!) && hasStrong) {
        c.hardCapBreached = true;
        c.reviewState = TGPurchaseReviewState.notVerified;
        c.statusLabel = 'Hard cap breached';
        c.priority = TGModerationPriority.high;
        if (c.linkedReviewId != null) {
          DealService.instance.reviewById(c.linkedReviewId!)?.state = TGPurchaseReviewState.notVerified;
        }
      } else if (c.evidenceDueAt != null && now.isAfter(c.evidenceDueAt!) && !hasStrong) {
        c.noEvidence = true;
        c.statusLabel = 'No evidence';
      }
      if (c.hardCapAt != null && c.hardCapAt!.difference(now) <= const Duration(hours: 24) && hasStrong) {
        c.priority = TGModerationPriority.high;
      }
    }
    notifyListeners();
  }

  TGQueuedEmail preview({required String templateId, required String lang, required String to, required String subject, required String body}) {
    return TGQueuedEmail(id: 'preview', to: to, subject: subject, body: body, templateId: templateId, createdAt: TGClock.now());
  }

  void _queueMail(TGAdminDealCase c, {required String to, required String templateId, required String lang, required String subject, required String body}) {
    final mail = TGQueuedEmail(id: 'E-${emails.length + 1}-${DateTime.now().microsecondsSinceEpoch}', to: to, subject: subject, body: body, templateId: templateId, createdAt: TGClock.now(), listingNo: c.dealNo);
    emails.insert(0, mail);
    if (lastUndo?.dealNo == c.dealNo) _undoEmailIds.add(mail.id);
  }

  void _audit(String actorId, String actorRole, String action, String dealNo, String summary, {String? reason}) {
    ModerationService.instance.ensureSeeded();
    ModerationService.instance.audit.insert(
      0,
      TGAuditEntry(id: 'DA-${DateTime.now().microsecondsSinceEpoch}', at: TGClock.now(), actorId: actorId, actorRole: actorRole, action: TGModerationActionType.other, listingNo: dealNo, reason: reason, summary: summary),
    );
  }

  String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _seed() {
    final now = TGClock.now();
    const img = 'assets/images/bartscher_2002170.webp';
    TGDealPartyCard seller({String name = 'Technica', TGSellerType type = TGSellerType.store, int unjust = 2, int age = 400}) => TGDealPartyCard(
          userId: FakeAuthState.mockOwnerId,
          name: name,
          role: 'seller',
          accountAgeDays: age,
          phoneVerified: true,
          totalDeals: 18,
          confirmed: 11,
          declined: 2,
          sellerType: type,
          unjustObjections90d: unjust,
        );
    TGDealPartyCard buyer({String id = 'buyer_marek', String name = 'Marek K.', int age = 40}) => TGDealPartyCard(
          userId: id,
          name: name,
          role: 'buyer',
          accountAgeDays: age,
          phoneVerified: true,
          totalDeals: 4,
          confirmed: 2,
          declined: 0,
        );

    List<TGPlatformSignal> signals({int messages = 4, bool calls = true, bool sold = false}) => [
          TGPlatformSignal(kind: TGPlatformSignalKind.messages, present: messages > 0, text: messages > 0 ? '$messages messages between the parties (last 8 Oct)' : 'No messages on this listing'),
          TGPlatformSignal(kind: TGPlatformSignalKind.callClicks, present: calls, text: calls ? 'Buyer tapped Call on 7 Oct (signed in)' : 'No Call clicks while signed in'),
          TGPlatformSignal(kind: TGPlatformSignalKind.listingPublished, present: true, text: 'Listing published 2 Oct'),
          TGPlatformSignal(kind: TGPlatformSignalKind.listingSold, present: sold, text: sold ? 'Listing marked sold 8 Oct' : 'Listing still active'),
        ];

    cases.addAll([
      TGAdminDealCase(
        dealNo: 'D-2026-000210',
        queue: TGDealQueueKind.objection,
        listingNo: '38705142',
        listingTitle: 'Piec pizza 4 pizze – 3 dni do końca',
        seller: seller(),
        buyer: buyer(),
        createdAt: now.subtract(const Duration(days: 2)),
        slaStart: now.subtract(const Duration(days: 2)),
        evidenceDueAt: now.add(const Duration(hours: 4)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        hardCapAt: now.add(const Duration(days: 3)),
        captureCode: '4827',
        reviewPreview: 'Bought this unit after viewing it in person.',
        linkedDealId: 'D-2026-000210',
        linkedReviewId: 'R-2026-0010',
        linkedObjectionId: 'O-2026-0002',
        promoted: true,
        priority: TGModerationPriority.high,
        sellerReason: 'Still for sale',
        sellerNote: 'I still have the unit.',
        buyerNote: 'Picked it up from the warehouse.',
        evidence: [
          TGEvidence(id: 'E-0001', dealId: 'D-2026-000210', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.liveVideo, fileUrl: 'mock://live/4827', durationSec: 12, captureCode: '4827'),
        ],
        flags: const [TGDealRiskFlag.sellerAnsweredFast],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2)), actor: 'Buyer', label: 'Buyer posted review for No. 38705142'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2, hours: -1)), actor: 'System', label: 'Seller question sent (app + email)'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2)), actor: 'Seller', label: 'Seller disputed: Still for sale'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2)), actor: 'System', label: 'Evidence window opened (48 h)'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 1, hours: 4)), actor: 'Buyer', label: 'Buyer uploaded live video'),
        ],
        signals: signals(messages: 6, calls: true),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000206',
        queue: TGDealQueueKind.objection,
        listingNo: '40927364',
        listingTitle: 'Zmywarka podszafkowa',
        seller: seller(),
        buyer: buyer(),
        createdAt: now.subtract(const Duration(hours: 20)),
        slaStart: now.subtract(const Duration(hours: 20)),
        evidenceDueAt: now.subtract(const Duration(hours: 1)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        hardCapAt: now.add(const Duration(days: 4)),
        noEvidence: true,
        statusLabel: 'No evidence',
        reviewPreview: 'Bought this unit after viewing it in person.',
        linkedDealId: 'D-2026-000206',
        linkedReviewId: 'R-2026-0006',
        linkedObjectionId: 'O-2026-0001',
        sellerReason: 'Sold to someone else',
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 20)), actor: 'Buyer', label: 'Buyer posted review for No. 40927364'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 19)), actor: 'Seller', label: 'Seller disputed: Sold to someone else'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 1)), actor: 'System', label: 'Evidence window closed — no files'),
        ],
        signals: signals(messages: 2, sold: true),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000301',
        queue: TGDealQueueKind.objection,
        listingNo: '39816253',
        listingTitle: 'Stół chłodniczy 2-drzwiowy',
        seller: seller(),
        buyer: buyer(id: 'buyer_piotr', name: 'Piotr B.'),
        createdAt: now.subtract(const Duration(days: 4, hours: 12)),
        slaStart: now.subtract(const Duration(days: 4, hours: 12)),
        evidenceDueAt: now.subtract(const Duration(days: 2)),
        decisionDueAt: now.add(const Duration(hours: 10)),
        hardCapAt: now.add(const Duration(hours: 18)),
        priority: TGModerationPriority.high,
        statusLabel: 'Hard cap soon',
        captureCode: '1904',
        reviewPreview: 'Paid by transfer and collected the same day.',
        evidence: [
          TGEvidence(id: 'E-a', dealId: 'D-2026-000301', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.liveVideo, fileUrl: 'mock://live/1904', captureCode: '1904', durationSec: 14),
        ],
        flags: const [TGDealRiskFlag.listingSoldOtherBuyer],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 4)), actor: 'Buyer', label: 'Buyer posted review for No. 39816253'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 4)), actor: 'Seller', label: 'Seller disputed: Sold to someone else'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 3)), actor: 'Buyer', label: 'Buyer uploaded live video'),
        ],
        signals: signals(messages: 3, sold: true),
        promoted: true,
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000302',
        queue: TGDealQueueKind.objection,
        listingNo: '38705142',
        listingTitle: 'Piec pizza 4 pizze – 3 dni do końca',
        seller: seller(),
        buyer: buyer(id: 'buyer_anna', name: 'Anna W.', age: 20),
        createdAt: now.subtract(const Duration(days: 1)),
        slaStart: now.subtract(const Duration(days: 1)),
        evidenceDueAt: now.add(const Duration(hours: 20)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        hardCapAt: now.add(const Duration(days: 4)),
        reviewPreview: 'Invoice and bank confirmation attached.',
        buyerNote: 'Transfer on 3 Oct, pickup next morning.',
        sellerReason: 'This person never contacted me',
        evidence: [
          TGEvidence(id: 'E-p', dealId: 'D-2026-000302', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.paymentTrace, fileUrl: 'mock://trace'),
          TGEvidence(id: 'E-d', dealId: 'D-2026-000302', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.document, fileUrl: 'mock://doc'),
        ],
        flags: const [TGDealRiskFlag.buyerAccountNew],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 1)), actor: 'Buyer', label: 'Buyer posted review for No. 38705142'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 20)), actor: 'Seller', label: 'Seller disputed: This person never contacted me'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 12)), actor: 'Buyer', label: 'Buyer uploaded payment trace and documents'),
        ],
        signals: signals(messages: 0, calls: false),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000303',
        queue: TGDealQueueKind.objection,
        listingNo: '35472819',
        listingTitle: 'Listing 35472819',
        seller: seller(name: 'Mateusz K.', type: TGSellerType.private, age: 90),
        buyer: buyer(),
        createdAt: now.subtract(const Duration(hours: 30)),
        slaStart: now.subtract(const Duration(hours: 30)),
        evidenceDueAt: now.add(const Duration(hours: 18)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        hardCapAt: now.add(const Duration(days: 4)),
        photoOnlyRejected: true,
        privateSeller: true,
        statusLabel: 'Photos only — not accepted',
        reviewPreview: 'Looks like the unit I collected.',
        evidence: [
          TGEvidence(id: 'E-ph1', dealId: 'D-2026-000303', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.photo, fileUrl: img),
          TGEvidence(id: 'E-ph2', dealId: 'D-2026-000303', uploaderRole: TGEvidenceRole.buyer, type: TGEvidenceType.photo, fileUrl: img),
        ],
        flags: const [TGDealRiskFlag.sharedDevice],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 30)), actor: 'Buyer', label: 'Buyer posted review for No. 35472819'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 28)), actor: 'Seller', label: 'Seller disputed: Still for sale'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 26)), actor: 'System', label: 'Photo-only upload rejected — video, payment trace or document required'),
        ],
        signals: signals(messages: 1, calls: false),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000207',
        queue: TGDealQueueKind.flagged,
        listingNo: '38705142',
        listingTitle: 'Piec pizza 4 pizze – 3 dni do końca',
        seller: seller(),
        buyer: buyer(id: 'buyer_anna', name: 'Anna W.', age: 4),
        createdAt: now.subtract(const Duration(days: 2)),
        slaStart: now.subtract(const Duration(days: 2)),
        decisionDueAt: tgAddBusinessDays(now.subtract(const Duration(days: 2)), 3),
        reviewState: TGPurchaseReviewState.pendingCheck,
        statusLabel: 'Pending check',
        reviewPreview: 'Bought this unit after viewing it in person.',
        linkedDealId: 'D-2026-000207',
        linkedReviewId: 'R-2026-0007',
        flags: const [TGDealRiskFlag.buyerAccountNew, TGDealRiskFlag.sameBuyerManyReviews],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2)), actor: 'Buyer', label: 'Buyer posted review for No. 38705142'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 2)), actor: 'System', label: 'Held for check (≥2 hold flags)'),
        ],
        signals: signals(),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000304',
        queue: TGDealQueueKind.flagged,
        listingNo: '39816253',
        listingTitle: 'Stół chłodniczy 2-drzwiowy',
        seller: seller(),
        buyer: buyer(age: 3),
        createdAt: now.subtract(const Duration(hours: 10)),
        slaStart: now.subtract(const Duration(hours: 10)),
        decisionDueAt: tgAddBusinessDays(now, 3),
        reviewState: TGPurchaseReviewState.pendingCheck,
        statusLabel: 'Pending check',
        reviewPreview: 'Quick pickup, all good.',
        flags: const [TGDealRiskFlag.sharedDevice, TGDealRiskFlag.sellerAnsweredFast],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 10)), actor: 'Buyer', label: 'Buyer posted review for No. 39816253'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 9, minutes: 50)), actor: 'Seller', label: 'Seller answered in under 10 minutes'),
        ],
        signals: signals(messages: 1),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000305',
        queue: TGDealQueueKind.flagged,
        listingNo: '40927364',
        listingTitle: 'Zmywarka podszafkowa',
        seller: seller(),
        buyer: buyer(id: 'buyer_piotr', name: 'Piotr B.'),
        createdAt: now.subtract(const Duration(days: 1)),
        slaStart: now.subtract(const Duration(days: 1)),
        decisionDueAt: tgAddBusinessDays(now.subtract(const Duration(days: 1)), 3),
        reviewState: TGPurchaseReviewState.pendingCheck,
        statusLabel: 'Pending check',
        promoted: true,
        priority: TGModerationPriority.high,
        reviewPreview: 'Second unit from this seller this month.',
        flags: const [TGDealRiskFlag.listingSoldOtherBuyer, TGDealRiskFlag.sellerNewBuyerDeals],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 1)), actor: 'Buyer', label: 'Buyer posted review for No. 40927364'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 1)), actor: 'System', label: 'Listing already has a different confirmed buyer'),
        ],
        signals: signals(sold: true),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000123',
        queue: TGDealQueueKind.dispute,
        listingNo: '38705142',
        listingTitle: 'Piec pizza 4 pizze – 3 dni do końca',
        seller: seller(),
        buyer: buyer(),
        createdAt: now.subtract(const Duration(hours: 8)),
        slaStart: now.subtract(const Duration(hours: 8)),
        decisionDueAt: now.add(const Duration(hours: 16)),
        priority: TGModerationPriority.high,
        statusLabel: 'Buyer declined',
        reviewState: TGPurchaseReviewState.awaitingSeller,
        reviewPreview: 'Seller marked this sold to me — I did not buy it.',
        linkedDealId: 'D-2026-000123',
        flags: const [TGDealRiskFlag.sellerDisputedMany],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 6)), actor: 'Buyer', label: 'A different buyer disputed this seller within 30 days'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 10)), actor: 'Seller', label: 'Seller marked listing as sold to this buyer'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 8)), actor: 'Buyer', label: "Buyer answered: No, this wasn't me"),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 8)), actor: 'System', label: 'Priority High · decision due in 24 h'),
        ],
        signals: signals(messages: 3),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000208',
        queue: TGDealQueueKind.appeal,
        listingNo: '39816253',
        listingTitle: 'Stół chłodniczy 2-drzwiowy',
        seller: seller(),
        buyer: buyer(),
        createdAt: now.subtract(const Duration(days: 1)),
        slaStart: now.subtract(const Duration(days: 1)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        reviewState: TGPurchaseReviewState.removed,
        statusLabel: 'Appeal open',
        removedBy: moderatorId,
        assignedTo: adminId,
        reviewPreview: 'Bought this unit after viewing it in person.',
        linkedDealId: 'D-2026-000208',
        linkedReviewId: 'R-2026-0008',
        buyerNote: 'I still have the serial plate photo.',
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 12)), actor: 'Buyer', label: 'Buyer posted review for No. 39816253'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 11)), actor: 'Moderator', label: 'Review removed'),
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 1)), actor: 'Buyer', label: 'Buyer appealed the removal'),
        ],
        signals: signals(),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000306',
        queue: TGDealQueueKind.appeal,
        listingNo: '40927364',
        listingTitle: 'Zmywarka podszafkowa',
        seller: seller(),
        buyer: buyer(id: 'buyer_anna', name: 'Anna W.'),
        createdAt: now.subtract(const Duration(hours: 6)),
        slaStart: now.subtract(const Duration(hours: 6)),
        decisionDueAt: tgAddBusinessDays(now, 2),
        reviewState: TGPurchaseReviewState.removed,
        statusLabel: 'Appeal open',
        removedBy: adminId,
        reviewPreview: 'Collected with a friend. Honest review.',
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(days: 3)), actor: 'Moderator', label: 'Review removed'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 6)), actor: 'Buyer', label: 'Buyer appealed the removal'),
        ],
        signals: signals(messages: 2),
      ),
      TGAdminDealCase(
        dealNo: 'D-2026-000307',
        queue: TGDealQueueKind.flagged,
        listingNo: '38705142',
        listingTitle: 'Piec pizza 4 pizze – 3 dni do końca',
        seller: seller(),
        buyer: buyer(id: 'buyer_piotr', name: 'Piotr B.', age: 12),
        createdAt: now.subtract(const Duration(hours: 14)),
        slaStart: now.subtract(const Duration(hours: 14)),
        decisionDueAt: tgAddBusinessDays(now, 3),
        reviewState: TGPurchaseReviewState.pendingCheck,
        statusLabel: 'Reciprocal pattern',
        reviewPreview: 'Also sold this seller a mixer last month.',
        flags: const [TGDealRiskFlag.reciprocal, TGDealRiskFlag.sameBuyerManyReviews, TGDealRiskFlag.sellerDisputedMany],
        timeline: [
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 14)), actor: 'Buyer', label: 'Buyer posted review for No. 38705142'),
          TGDealTimelineEvent(at: now.subtract(const Duration(hours: 14)), actor: 'System', label: 'Reciprocal reviews A→B and B→A within 60 days'),
        ],
        signals: signals(messages: 5),
      ),
    ]);
  }
}
