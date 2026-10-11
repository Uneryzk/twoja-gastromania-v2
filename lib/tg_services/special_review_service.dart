import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

/// Special Order project reviews — DEAL-2 v2 state machine reused (same states/SLA).
class TGSpecialReviewService extends ChangeNotifier {
  TGSpecialReviewService._();
  static final TGSpecialReviewService instance = TGSpecialReviewService._();

  final List<TGSpecialReview> reviews = [];
  final List<TGSpecialObjection> objections = [];
  final List<TGEvidence> evidence = [];
  final List<TGPrivateBuyerReport> privateReports = [];
  final Set<String> _prompted = {};
  final Set<String> _silenceDone = {};
  bool _seeded = false;
  int _seq = 1;

  void reset() {
    reviews.clear();
    objections.clear();
    evidence.clear();
    privateReports.clear();
    _prompted.clear();
    _silenceDone.clear();
    _seeded = false;
    _seq = 1;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    TGSpecialOrderService.instance.ensureSeeded();
    _seedAll();
  }

  TGSpecialReview? byId(String id) {
    ensureSeeded();
    return reviews.where((r) => r.id == id).firstOrNull;
  }

  List<TGSpecialReview> forSeller(String sellerId) {
    ensureSeeded();
    return reviews.where((r) => r.sellerId == sellerId && r.isPublicVisible).toList();
  }

  List<TGSpecialReview> countedFor(String sellerId) {
    ensureSeeded();
    return reviews.where((r) => r.sellerId == sellerId && r.countsTowardRating).toList();
  }

  TGCustomProjectRatingSummary summaryFor(String sellerId) {
    final counted = countedFor(sellerId);
    final completed = reviews.where((r) => r.sellerId == sellerId && r.completionStatus == TGProjectCompletionStatus.completed).length;
    double? avg;
    if (counted.length >= 3) {
      avg = counted.map((r) => r.rating).reduce((a, b) => a + b) / counted.length;
    }
    return TGCustomProjectRatingSummary(completedCount: completed, countedCount: counted.length, average: avg);
  }

  TGSpecialSubScores? subScoreAverages(String sellerId) {
    final counted = countedFor(sellerId);
    if (counted.isEmpty) return null;
    double avg(int Function(TGSpecialReview) f) => counted.map(f).reduce((a, b) => a + b) / counted.length;
    final hasInstall = counted.any((r) => r.subScores.installation != null);
    return TGSpecialSubScores(
      quality: avg((r) => r.subScores.quality).round(),
      communication: avg((r) => r.subScores.communication).round(),
      deadline: avg((r) => r.subScores.deadline).round(),
      quoteAccuracy: avg((r) => r.subScores.quoteAccuracy).round(),
      installation: hasInstall
          ? avg((r) => r.subScores.installation ?? r.subScores.quality).round()
          : null,
    );
  }

  int reviewsSubmittedToday(String authorId) {
    final day = TGClock.now();
    return reviews.where((r) => r.authorId == authorId && r.createdAt.year == day.year && r.createdAt.month == day.month && r.createdAt.day == day.day).length;
  }

  void onAwarded(TGSpecialRequest request) {
    ensureSeeded();
    // Day-30 prompt is driven by onClockAdvanced from awardedAt/closedAt.
    TGAnalytics.track('project_review_prompt', {'requestNo': request.requestNo, 'phase': 'scheduled'});
  }

  void markCompleted(String requestId, {required String buyerId}) {
    ensureSeeded();
    final so = TGSpecialOrderService.instance;
    final r = so.byId(requestId);
    if (r == null || r.buyerId != buyerId || r.awardedSellerId == null) return;
    so.patchCompletion(requestId, TGProjectCompletionStatus.completed);
    TGAnalytics.track('project_completed_mark', {'requestNo': r.requestNo});
    notifyListeners();
  }

  void markStillInProgress(String requestId, {required String buyerId}) {
    ensureSeeded();
    final so = TGSpecialOrderService.instance;
    final r = so.byId(requestId);
    if (r == null || r.buyerId != buyerId) return;
    so.patchCompletion(requestId, TGProjectCompletionStatus.inProgress, askAgainInDays: 14);
    notifyListeners();
  }

  void markNotCompleted(String requestId, {required String buyerId}) {
    ensureSeeded();
    final so = TGSpecialOrderService.instance;
    final r = so.byId(requestId);
    if (r == null || r.buyerId != buyerId) return;
    so.patchCompletion(requestId, TGProjectCompletionStatus.notCompleted);
    notifyListeners();
  }

  String? canSubmit({required String authorId, required String requestId}) {
    final r = TGSpecialOrderService.instance.byId(requestId);
    if (r == null) return 'Request not found';
    if (r.buyerId != authorId) return 'Only the buyer can review';
    if (r.awardedSellerId == null) return 'No awarded manufacturer';
    if (r.completionStatus != TGProjectCompletionStatus.completed) return 'Mark the project completed first';
    if (r.completedAt != null && TGClock.now().difference(r.completedAt!).inDays > 60) return 'Review window closed (60 days)';
    if (reviews.any((e) => e.requestId == requestId && e.authorId == authorId)) return 'Already reviewed';
    if (reviewsSubmittedToday(authorId) >= 3) return 'Daily limit of 3 reviews reached';
    return null;
  }

  TGSpecialReview submit({
    required String requestId,
    required String authorId,
    required String authorName,
    required int rating,
    required TGSpecialSubScores subScores,
    required String text,
  }) {
    ensureSeeded();
    final err = canSubmit(authorId: authorId, requestId: requestId);
    if (err != null) throw StateError(err);
    if (text.trim().length < 20 || text.trim().length > 1000) throw StateError('Text must be 20–1000 characters');
    final r = TGSpecialOrderService.instance.byId(requestId)!;
    final flags = _riskFlags(r);
    var state = TGPurchaseReviewState.awaitingSeller;
    if (flags.where((f) => f.startsWith('hold')).length >= 2) state = TGPurchaseReviewState.pendingCheck;
    final review = TGSpecialReview(
      id: 'SR-${_seq++}',
      requestId: requestId,
      requestNo: r.requestNo,
      sellerId: r.awardedSellerId!,
      authorId: authorId,
      authorName: authorName,
      projectTitleSnapshot: r.title,
      awardedAt: r.awardedAt ?? r.closedAt ?? r.createdAt,
      completionStatus: TGProjectCompletionStatus.completed,
      completedAt: r.completedAt ?? TGClock.now(),
      rating: rating.clamp(1, 5),
      subScores: subScores,
      text: text.trim(),
      state: state,
      riskFlags: flags,
    );
    reviews.insert(0, review);
    NotificationService.instance.add(
      userId: review.sellerId,
      type: 'project_review_confirm',
      dealId: review.requestNo,
      title: 'Confirm project completion',
      body: '$authorName says the project ${r.title} (${r.requestNo}) was completed for them. Confirm?',
      deepLink: '/dashboard/leads?id=${r.requestNo}',
    );
    TGAnalytics.track('project_review_submit', {'id': review.id, 'sellerId': review.sellerId, 'rating': rating});
    notifyListeners();
    return review;
  }

  void manufacturerConfirm(String reviewId) {
    ensureSeeded();
    final r = byId(reviewId);
    if (r == null) return;
    r.state = TGPurchaseReviewState.confirmed;
    TGAnalytics.track('manufacturer_answer', {'id': reviewId, 'answer': 'yes'});
    notifyListeners();
  }

  void manufacturerDispute({
    required String reviewId,
    required TGSpecialObjectionReason reason,
    required String note,
  }) {
    ensureSeeded();
    final r = byId(reviewId);
    if (r == null) return;
    r.state = TGPurchaseReviewState.suspendedObjection;
    final now = TGClock.now();
    objections.add(TGSpecialObjection(
      id: 'SOBJ-${_seq++}',
      reviewId: reviewId,
      requestId: r.requestId,
      reason: reason,
      note: note,
      createdAt: now,
      evidenceDueAt: now.add(const Duration(hours: 48)),
    ));
    TGAnalytics.track('manufacturer_answer', {'id': reviewId, 'answer': 'dispute', 'reason': reason.name});
    notifyListeners();
  }

  void addEvidence({
    required String reviewId,
    required TGEvidenceRole role,
    required TGEvidenceType type,
    required String fileUrl,
  }) {
    ensureSeeded();
    evidence.add(TGEvidence(
      id: 'SEV-${_seq++}',
      dealId: reviewId,
      uploaderRole: role,
      type: type,
      fileUrl: fileUrl,
      createdAt: TGClock.now(),
    ));
    notifyListeners();
  }

  void moderatorDecide({
    required String reviewId,
    required TGObjectionDecision decision,
    required String actorId,
    required String note,
  }) {
    ensureSeeded();
    final r = byId(reviewId);
    if (r == null) return;
    r.state = switch (decision) {
      TGObjectionDecision.confirmed => TGPurchaseReviewState.confirmedModerator,
      TGObjectionDecision.removed => TGPurchaseReviewState.removed,
      TGObjectionDecision.notVerified => TGPurchaseReviewState.notVerified,
    };
    final oi = objections.indexWhere((o) => o.reviewId == reviewId);
    if (oi >= 0) {
      final o = objections[oi];
      objections[oi] = TGSpecialObjection(
        id: o.id,
        reviewId: o.reviewId,
        requestId: o.requestId,
        reason: o.reason,
        note: note,
        createdAt: o.createdAt,
        evidenceDueAt: o.evidenceDueAt,
        status: TGObjectionStatus.decided,
        decision: decision,
        evidenceIds: o.evidenceIds,
      );
    }
    notifyListeners();
  }

  void reportBuyerPrivately({
    required String requestId,
    required String sellerId,
    required TGPrivateBuyerReportReason reason,
    required String note,
  }) {
    ensureSeeded();
    final r = TGSpecialOrderService.instance.byId(requestId);
    if (r == null) return;
    privateReports.insert(
      0,
      TGPrivateBuyerReport(
        id: 'PBR-${_seq++}',
        requestId: requestId,
        sellerId: sellerId,
        buyerId: r.buyerId,
        reason: reason,
        note: note,
        createdAt: TGClock.now(),
      ),
    );
    TGAnalytics.track('private_buyer_report', {'requestNo': r.requestNo, 'reason': reason.name});
    notifyListeners();
  }

  void onClockAdvanced() {
    ensureSeeded();
    final now = TGClock.now();
    final so = TGSpecialOrderService.instance;
    for (final r in so.requests) {
      if (r.status != TGSpecialRequestStatus.awarded || r.awardedSellerId == null) continue;
      final awardedAt = r.awardedAt ?? r.closedAt ?? r.createdAt;
      final days = now.difference(awardedAt).inDays;
      if (days >= 30 &&
          r.completionStatus == TGProjectCompletionStatus.inProgress &&
          _prompted.add(r.id)) {
        NotificationService.instance.add(
          userId: r.buyerId,
          type: 'project_completion_prompt',
          dealId: r.requestNo,
          title: 'Is the project completed?',
          body: 'Tell us about ${r.title} (${r.requestNo}).',
          deepLink: '/account/requests/${r.requestNo}',
        );
        TGAnalytics.track('project_review_prompt', {'requestNo': r.requestNo});
      }
      // Remind manufacturer on day 2 and 4 of awaiting response
    }
    for (final rev in reviews) {
      if (rev.state != TGPurchaseReviewState.awaitingSeller) continue;
      if (!now.isBefore(rev.sellerAnswerDueAt) && _silenceDone.add(rev.id)) {
        rev.state = TGPurchaseReviewState.notDisputed;
      }
      final day = now.difference(rev.createdAt).inDays;
      if (rev.state == TGPurchaseReviewState.awaitingSeller && (day == 2 || day == 4)) {
        NotificationService.instance.add(
          userId: rev.sellerId,
          type: 'project_review_remind',
          dealId: rev.requestNo,
          title: 'Confirm project completion',
          body: '${rev.authorName} says ${rev.projectTitleSnapshot} (${rev.requestNo}) was completed. Confirm?',
          deepLink: '/dashboard/leads?id=${rev.requestNo}',
        );
      }
    }
    notifyListeners();
  }

  List<String> _riskFlags(TGSpecialRequest r) {
    final flags = <String>[];
    final awardedAt = r.awardedAt ?? r.closedAt ?? r.createdAt;
    if (awardedAt.difference(r.createdAt).inMinutes < 60) flags.add('hold_fast_award');
    final created = r.buyerAccountCreatedAt;
    if (created != null && TGClock.now().difference(created).inDays < 7) flags.add('hold_new_buyer');
    if (r.flags.contains('shared_device')) flags.add('hold_shared_device');
    if (r.flags.contains('shared_nip')) flags.add('hold_shared_nip');
    return flags;
  }

  void _seedAll() {
    final now = TGClock.now();
    final so = TGSpecialOrderService.instance;
    final awarded = so.requests.where((r) => r.awardedSellerId != null).toList();
    TGSpecialRequest pick(int i) => awarded.isEmpty
        ? so.requests.first
        : awarded[i % awarded.length];

    TGSpecialReview make({
      required TGPurchaseReviewState state,
      required String sellerId,
      required int rating,
      int daysAgo = 10,
      TGProjectCompletionStatus completion = TGProjectCompletionStatus.completed,
      List<String> flags = const [],
    }) {
      final req = pick(reviews.length);
      return TGSpecialReview(
        id: 'SR-seed-${reviews.length + 1}',
        requestId: req.id,
        requestNo: req.requestNo,
        sellerId: sellerId,
        authorId: req.buyerId,
        authorName: req.buyerName,
        projectTitleSnapshot: req.title,
        awardedAt: now.subtract(Duration(days: daysAgo + 40)),
        completionStatus: completion,
        completedAt: now.subtract(Duration(days: daysAgo)),
        rating: rating,
        subScores: TGSpecialSubScores(
          quality: rating,
          communication: (rating - 1).clamp(1, 5),
          deadline: rating,
          quoteAccuracy: rating,
          installation: req.installationNeeded ? rating : null,
        ),
        text: 'Solid custom work on ${req.title}. Communication was clear and the quote matched the delivery.',
        state: state,
        createdAt: now.subtract(Duration(days: daysAgo)),
        riskFlags: flags,
      );
    }

    // 6 reviews covering states; 3 sellers with ≥3 counted
    reviews.addAll([
      make(state: TGPurchaseReviewState.awaitingSeller, sellerId: 'seller_gastropl', rating: 5, daysAgo: 2),
      make(state: TGPurchaseReviewState.confirmed, sellerId: 'seller_gastropl', rating: 5, daysAgo: 20),
      make(state: TGPurchaseReviewState.notDisputed, sellerId: 'seller_gastropl', rating: 4, daysAgo: 30),
      make(state: TGPurchaseReviewState.confirmedModerator, sellerId: 'seller_gastropl', rating: 5, daysAgo: 35),
      make(state: TGPurchaseReviewState.confirmedModerator, sellerId: 'seller_inoxline', rating: 5, daysAgo: 25),
      make(state: TGPurchaseReviewState.notVerified, sellerId: 'seller_inoxline', rating: 3, daysAgo: 40),
      make(state: TGPurchaseReviewState.suspendedObjection, sellerId: 'seller_stalbar', rating: 2, daysAgo: 5, flags: const ['hold_fast_award']),
      make(state: TGPurchaseReviewState.confirmed, sellerId: 'seller_inoxline', rating: 4, daysAgo: 18),
      make(state: TGPurchaseReviewState.notDisputed, sellerId: 'seller_stalbar', rating: 5, daysAgo: 22),
      make(state: TGPurchaseReviewState.confirmed, sellerId: 'seller_stalbar', rating: 4, daysAgo: 28),
      make(state: TGPurchaseReviewState.pendingCheck, sellerId: 'seller_metalgast', rating: 5, daysAgo: 3, flags: const ['hold_fast_award', 'hold_new_buyer']),
    ]);

    final disputed = reviews.firstWhere((r) => r.state == TGPurchaseReviewState.suspendedObjection);
    objections.add(TGSpecialObjection(
      id: 'SOBJ-seed-1',
      reviewId: disputed.id,
      requestId: disputed.requestId,
      reason: TGSpecialObjectionReason.projectNotCompleted,
      note: 'Project still in fabrication',
      createdAt: now.subtract(const Duration(days: 4)),
      evidenceDueAt: now.add(const Duration(hours: 20)),
    ));
    evidence.add(TGEvidence(
      id: 'SEV-seed-1',
      dealId: disputed.id,
      uploaderRole: TGEvidenceRole.seller,
      type: TGEvidenceType.document,
      fileUrl: 'mock://handover-protocol.pdf',
      createdAt: now.subtract(const Duration(days: 3)),
    ));
  }
}
