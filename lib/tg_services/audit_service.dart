import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';

/// Audited Manufacturer — we sell the audit, not the badge.
class TGAuditService extends ChangeNotifier {
  TGAuditService._();
  static final TGAuditService instance = TGAuditService._();

  static const int feePln = 399;
  static const int renewalPln = 199;
  static const int validityMonths = 12;
  static final _rand = Random(42);

  final List<TGAuditApplication> applications = [];
  final List<({String actorId, String action, String? detail, DateTime at})> auditLog = [];
  final Set<String> _renewReminded = {};
  final Set<String> _sampleSuggested = {};
  bool _seeded = false;
  int _seq = 1;

  void reset() {
    applications.clear();
    auditLog.clear();
    _renewReminded.clear();
    _sampleSuggested.clear();
    _seeded = false;
    _seq = 1;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedAll();
  }

  bool get enabled => TGRevenueConfigService.instance.flags.auditProgram;
  double get liveVisitSampleRate => TGRevenueConfigService.instance.config.audit.liveVisitSampleRate;

  TGAuditApplication? activeFor(String sellerId) {
    ensureSeeded();
    return applications.where((a) => a.sellerId == sellerId && a.badgeActive).firstOrNull;
  }

  TGAuditApplication? latestFor(String sellerId) {
    ensureSeeded();
    return applications.where((a) => a.sellerId == sellerId).firstOrNull;
  }

  bool isAudited(String sellerId) => activeFor(sellerId) != null;

  String? eligibilityError(String sellerId) {
    final p = TGSellerProfileService.instance.bySellerKey(sellerId);
    if (p == null) return 'Manufacturer profile required';
    if (!p.verified) return 'Verified status required';
    if (p.plan != TGStorePlanKind.pro && p.plan != TGStorePlanKind.enterprise) {
      return 'Active Pro or Enterprise plan required';
    }
    return null;
  }

  static String newChallengeCode() => (_rand.nextInt(9000) + 1000).toString();

  static String? validateVideoLink(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return 'Please add your workshop video.';
    final ok = u.contains('youtube.com') || u.contains('youtu.be') || u.contains('vimeo.com');
    if (!ok) return 'Only YouTube or Vimeo unlisted/private links are accepted.';
    return null;
  }

  static String? hostFromLink(String url) {
    final u = url.toLowerCase();
    if (u.contains('vimeo')) return 'vimeo';
    if (u.contains('youtube') || u.contains('youtu.be')) return 'youtube';
    return null;
  }

  TGAuditApplication apply({required String sellerId, bool freeReapply = false}) {
    ensureSeeded();
    final err = eligibilityError(sellerId);
    if (err != null) throw StateError(err);
    final prev = latestFor(sellerId);
    if (freeReapply) {
      if (prev == null || prev.status != TGAuditApplicationStatus.rejected || prev.reapplyUsed) {
        throw StateError('Free re-apply not available');
      }
      prev.reapplyUsed = true;
    }
    final now = TGClock.now();
    final app = TGAuditApplication(
      id: 'AUD-${_seq++}',
      sellerId: sellerId,
      status: TGAuditApplicationStatus.applied,
      createdAt: now,
      reapplyUsed: freeReapply,
      workshopVideo: TGAuditWorkshopVideo(
        kind: TGAuditVideoKind.file,
        challengeCode: newChallengeCode(),
        challengeIssuedAt: now,
      ),
    );
    applications.insert(0, app);
    TGAnalytics.track('audit_apply', {'sellerId': sellerId, 'id': app.id, 'freeReapply': freeReapply});
    notifyListeners();
    return app;
  }

  void markPaid(String applicationId) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.status = TGAuditApplicationStatus.paid;
    a.paidAt = TGClock.now();
    a.workshopVideo ??= TGAuditWorkshopVideo(
      kind: TGAuditVideoKind.file,
      challengeCode: newChallengeCode(),
      challengeIssuedAt: TGClock.now(),
    );
    _log('system', 'paid', a.id);
    TGAnalytics.track('audit_step_complete', {'id': a.id, 'step': 'paid'});
    notifyListeners();
  }

  void regenerateCode(String applicationId) {
    final a = _byId(applicationId);
    if (a == null) return;
    final prev = a.workshopVideo;
    a.workshopVideo = TGAuditWorkshopVideo(
      kind: prev?.kind ?? TGAuditVideoKind.file,
      fileUrl: prev?.fileUrl,
      linkUrl: prev?.linkUrl,
      host: prev?.host,
      durationSec: prev?.durationSec,
      challengeCode: newChallengeCode(),
      challengeIssuedAt: TGClock.now(),
      submittedAt: prev?.submittedAt,
    );
    TGAnalytics.track('audit_code_regenerate', {'id': a.id});
    notifyListeners();
  }

  void submitDocumentsAndVideo(
    String applicationId, {
    required String workshopAddress,
    required List<String> docs,
    required TGAuditWorkshopVideo video,
  }) {
    final a = _byId(applicationId);
    if (a == null) return;
    if (!video.isComplete) throw StateError('Please add your workshop video.');
    a.workshopAddress = workshopAddress;
    a.docPaths = docs;
    a.workshopVideo = video.copyWith(submittedAt: TGClock.now());
    a.status = TGAuditApplicationStatus.docs;
    TGAnalytics.track('audit_video_submit', {'id': a.id, 'kind': video.kind.name});
    TGAnalytics.track('audit_step_complete', {'id': a.id, 'step': 'docs'});
    notifyListeners();
  }

  void submitForReview(String applicationId) {
    final a = _byId(applicationId);
    if (a == null) return;
    if (a.workshopVideo == null || !a.workshopVideo!.isComplete) {
      throw StateError('Please add your workshop video.');
    }
    a.status = TGAuditApplicationStatus.inReview;
    TGAnalytics.track('audit_step_complete', {'id': a.id, 'step': 'in_review'});
    // Optional random live-visit suggestion when sample rate > 0
    if (liveVisitSampleRate > 0 && _rand.nextDouble() < liveVisitSampleRate && _sampleSuggested.add(a.id)) {
      _log('system', 'live_visit_sample_suggest', a.id);
    }
    notifyListeners();
  }

  void logView(String applicationId, String viewerName) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.viewLog.insert(0, (viewer: viewerName, at: TGClock.now()));
    _log(viewerName, 'viewed', a.id);
    notifyListeners();
  }

  void setCodeMatch(String applicationId, TGAuditCodeMatch match) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.codeMatch = match;
    notifyListeners();
  }

  void setLinkAck(String applicationId, bool value) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.linkAckChecked = value;
    notifyListeners();
  }

  void requestLiveVisit({
    required String applicationId,
    required String actorId,
    required String reason,
  }) {
    final a = _byId(applicationId);
    if (a == null) return;
    final now = TGClock.now();
    a.liveVisit = TGAuditLiveVisit(
      requestedAt: now,
      requestedBy: actorId,
      reason: reason,
      scheduleDueAt: now.add(const Duration(days: 7)),
    );
    a.status = TGAuditApplicationStatus.liveVisitRequested;
    _log(actorId, 'live_visit_request', reason);
    TGAnalytics.track('audit_live_visit_request', {'id': a.id, 'reason': reason});
    NotificationService.instance.add(
      userId: a.sellerId,
      type: 'audit_live_visit',
      dealId: a.id,
      title: 'Verification call',
      body: 'We\'d like to verify a few details in a short video call.',
      deepLink: '/dashboard/manufacturer?tab=audit',
    );
    notifyListeners();
  }

  void scheduleLiveVisit(String applicationId, DateTime at) {
    final a = _byId(applicationId);
    if (a == null || a.liveVisit == null) return;
    a.liveVisit = a.liveVisit!.copyWith(scheduledAt: at);
    a.status = TGAuditApplicationStatus.visitScheduled;
    TGAnalytics.track('audit_live_visit_schedule', {'id': a.id});
    notifyListeners();
  }

  void markVisitDone(String applicationId, {required String notes}) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.visitNote = notes;
    a.liveVisit = a.liveVisit?.copyWith(notes: notes);
    a.status = TGAuditApplicationStatus.visitDone;
    notifyListeners();
  }

  void decide({
    required String applicationId,
    required TGAuditApplicationStatus status,
    required String actorId,
    required String note,
  }) {
    final a = _byId(applicationId);
    if (a == null) return;
    if (status == TGAuditApplicationStatus.approved && !a.canApprove) {
      throw StateError('Checklist incomplete or video not passed');
    }
    final afterVisit = a.status == TGAuditApplicationStatus.visitDone || a.liveVisit?.scheduledAt != null;
    a.status = status;
    a.decidedAt = TGClock.now();
    a.decisionNote = note;
    if (status == TGAuditApplicationStatus.approved) {
      final now = TGClock.now();
      a.validUntil = DateTime(now.year, now.month + validityMonths, now.day);
      a.decisionPath = afterVisit ? 'after_live_visit' : 'direct';
      a.videoDeleteAt = now.add(const Duration(days: 30));
    } else if (status == TGAuditApplicationStatus.rejected) {
      a.decisionPath = afterVisit ? 'after_live_visit' : 'direct';
      a.videoDeleteAt = TGClock.now().add(const Duration(days: 30));
    }
    _log(actorId, 'decision_${status.name}', note);
    TGAnalytics.track('audit_decision', {
      'id': a.id,
      'status': status.name,
      'actor': actorId,
      'path': a.decisionPath ?? 'direct',
    });
    NotificationService.instance.add(
      userId: a.sellerId,
      type: 'audit_decision',
      dealId: a.id,
      title: 'Audit update',
      body: status == TGAuditApplicationStatus.approved
          ? 'Your Audited Manufacturer status is active.'
          : 'Your audit application was not approved. ${a.reapplyUsed ? "" : "You may fix and re-apply once for free."}',
      deepLink: '/dashboard/manufacturer?tab=audit',
    );
    notifyListeners();
  }

  void requestMoreDocuments({
    required String applicationId,
    required String actorId,
    required String note,
    required int days,
  }) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.status = TGAuditApplicationStatus.docs;
    a.decisionNote = note;
    _log(actorId, 'request_more_docs', '$days days: $note');
    NotificationService.instance.add(
      userId: a.sellerId,
      type: 'audit_more_docs',
      dealId: a.id,
      title: 'More documents needed',
      body: note,
      deepLink: '/dashboard/manufacturer?tab=audit',
    );
    notifyListeners();
  }

  void revoke({required String applicationId, required String actorId, required String reason}) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.status = TGAuditApplicationStatus.revoked;
    a.decisionNote = reason;
    a.decidedAt = TGClock.now();
    _log(actorId, 'revoke', reason);
    TGAnalytics.track('audit_revoke', {'id': a.id, 'actor': actorId});
    NotificationService.instance.add(
      userId: a.sellerId,
      type: 'audit_revoked',
      dealId: a.id,
      title: 'Audit status update',
      body: 'Your Audited Manufacturer status was revoked. You may appeal.',
      deepLink: '/dashboard/manufacturer?tab=audit',
    );
    notifyListeners();
  }

  void setChecklistItem(String applicationId, String itemId, TGAuditCheckResult result, {String? note}) {
    final a = _byId(applicationId);
    if (a == null) return;
    a.checklist = [
      for (final c in a.checklist)
        if (c.id == itemId) c.copyWith(result: result, note: note) else c,
    ];
    notifyListeners();
  }

  List<String> liveVisitHints(TGAuditApplication a) {
    final hints = <String>[];
    if (a.codeMatch == TGAuditCodeMatch.doesntMatch) hints.add('Code doesn\'t match');
    if (a.workshopVideo?.kind == TGAuditVideoKind.link) hints.add('Link-only submission');
    final addr = a.checklist.where((c) => c.id == 'address').firstOrNull;
    if (addr?.result == TGAuditCheckResult.fail) hints.add('Address mismatch');
    return hints;
  }

  void onClockAdvanced() {
    ensureSeeded();
    final now = TGClock.now();
    for (final a in applications) {
      if (a.status == TGAuditApplicationStatus.approved && a.validUntil != null) {
        final days = a.validUntil!.difference(now).inDays;
        if (days == 30 && _renewReminded.add(a.id)) {
          NotificationService.instance.add(
            userId: a.sellerId,
            type: 'audit_renew',
            dealId: a.id,
            title: 'Audit renewal',
            body: 'Your Audited Manufacturer status ends in 30 days. Renewal is $renewalPln PLN. A new workshop video with a fresh code is required.',
            deepLink: '/dashboard/manufacturer?tab=audit',
          );
        }
      }
      // Live visit not scheduled within 7 days → reject, keep free reapply
      if (a.status == TGAuditApplicationStatus.liveVisitRequested && a.liveVisit != null) {
        if (!now.isBefore(a.liveVisit!.scheduleDueAt) && a.liveVisit!.scheduledAt == null) {
          a.status = TGAuditApplicationStatus.rejected;
          a.decisionNote = 'Verification incomplete';
          a.decidedAt = now;
          a.reapplyUsed = false; // free reapply preserved
          NotificationService.instance.add(
            userId: a.sellerId,
            type: 'audit_decision',
            dealId: a.id,
            title: 'Audit update',
            body: 'Verification incomplete. You may fix and re-apply once for free.',
            deepLink: '/dashboard/manufacturer?tab=audit',
          );
        }
      }
      // Purge video 30 days after decision
      if (a.videoDeleteAt != null && !now.isBefore(a.videoDeleteAt!) && a.workshopVideo != null) {
        a.workshopVideo = null;
        _log('system', 'video_purged', a.id);
      }
      final counted = TGSpecialReviewService.instance.countedFor(a.sellerId);
      if (a.badgeActive && counted.length >= 3) {
        final avg = counted.map((r) => r.rating).reduce((x, y) => x + y) / counted.length;
        if (avg < 3.5) _log('system', 'rating_below_threshold', '${a.sellerId} avg=$avg');
      }
    }
    notifyListeners();
  }

  TGAuditApplication? _byId(String id) {
    ensureSeeded();
    return applications.where((a) => a.id == id).firstOrNull;
  }

  void _log(String actorId, String action, String? detail) {
    auditLog.insert(0, (actorId: actorId, action: action, detail: detail, at: TGClock.now()));
  }

  TGAuditWorkshopVideo _seedVideo({
    required TGAuditVideoKind kind,
    required String code,
    String? fileUrl,
    String? linkUrl,
    int daysAgo = 10,
  }) {
    final issued = TGClock.now().subtract(Duration(days: daysAgo));
    return TGAuditWorkshopVideo(
      kind: kind,
      fileUrl: fileUrl,
      linkUrl: linkUrl,
      host: linkUrl != null ? hostFromLink(linkUrl) : null,
      durationSec: kind == TGAuditVideoKind.file ? 120 : null,
      challengeCode: code,
      challengeIssuedAt: issued,
      submittedAt: issued.add(const Duration(hours: 2)),
    );
  }

  void _seedAll() {
    final now = TGClock.now();
    final passAll = [
      for (final c in TGAuditApplication.defaultChecklist()) c.copyWith(result: TGAuditCheckResult.pass),
    ];

    // 1) Direct approve with file video
    applications.add(TGAuditApplication(
      id: 'AUD-seed-direct',
      sellerId: 'seller_gastropl',
      status: TGAuditApplicationStatus.approved,
      createdAt: now.subtract(const Duration(days: 200)),
      paidAt: now.subtract(const Duration(days: 198)),
      decidedAt: now.subtract(const Duration(days: 185)),
      validUntil: DateTime(now.year + 1, now.month, now.day),
      workshopAddress: 'Katowice, ul. Przemysłowa 12',
      docPaths: const ['mock://krs.pdf', 'mock://oc.pdf', 'mock://refs.pdf'],
      workshopVideo: _seedVideo(kind: TGAuditVideoKind.file, code: '4827', fileUrl: 'mock://workshop/4827.mp4', daysAgo: 190),
      codeMatch: TGAuditCodeMatch.matches,
      decisionPath: 'direct',
      checklist: passAll,
      linkAckChecked: true,
    ));

    // 2) Link-only in review
    applications.add(TGAuditApplication(
      id: 'AUD-seed-link',
      sellerId: 'seller_stalbar',
      status: TGAuditApplicationStatus.inReview,
      createdAt: now.subtract(const Duration(days: 4)),
      paidAt: now.subtract(const Duration(days: 3)),
      workshopAddress: 'Katowice, ul. Hutnicza 3',
      docPaths: const ['mock://krs.pdf', 'mock://oc.pdf'],
      workshopVideo: _seedVideo(
        kind: TGAuditVideoKind.link,
        code: '7193',
        linkUrl: 'https://vimeo.com/private/7193',
        daysAgo: 2,
      ),
    ));

    // 3) Code mismatch
    applications.add(TGAuditApplication(
      id: 'AUD-seed-mismatch',
      sellerId: 'seller_metalgast',
      status: TGAuditApplicationStatus.inReview,
      createdAt: now.subtract(const Duration(days: 6)),
      paidAt: now.subtract(const Duration(days: 5)),
      workshopAddress: 'Gliwice, ul. Hutnicza 8',
      docPaths: const ['mock://krs.pdf', 'mock://oc.pdf', 'mock://refs.pdf'],
      workshopVideo: _seedVideo(kind: TGAuditVideoKind.file, code: '3341', fileUrl: 'mock://workshop/3341.mp4', daysAgo: 4),
      codeMatch: TGAuditCodeMatch.doesntMatch,
      checklist: [
        for (final c in TGAuditApplication.defaultChecklist())
          c.id == 'video'
              ? c.copyWith(result: TGAuditCheckResult.fail, note: 'Code not visible')
              : c.copyWith(result: TGAuditCheckResult.pass),
      ],
    ));

    // 4) Live visit requested
    applications.add(TGAuditApplication(
      id: 'AUD-seed-live',
      sellerId: 'seller_rm',
      status: TGAuditApplicationStatus.liveVisitRequested,
      createdAt: now.subtract(const Duration(days: 8)),
      paidAt: now.subtract(const Duration(days: 7)),
      workshopAddress: 'Warszawa, ul. Przemysłowa 1',
      docPaths: const ['mock://krs.pdf', 'mock://oc.pdf', 'mock://refs.pdf'],
      workshopVideo: _seedVideo(kind: TGAuditVideoKind.link, code: '8802', linkUrl: 'https://youtu.be/private8802', daysAgo: 6),
      liveVisit: TGAuditLiveVisit(
        requestedAt: now.subtract(const Duration(days: 1)),
        requestedBy: 'staff_moderator',
        reason: 'Link-only + address unclear',
        scheduleDueAt: now.add(const Duration(days: 6)),
      ),
    ));

    // 5) Rejected for clear violation
    applications.add(TGAuditApplication(
      id: 'AUD-seed-reject',
      sellerId: 'seller_nordinox',
      status: TGAuditApplicationStatus.rejected,
      createdAt: now.subtract(const Duration(days: 20)),
      paidAt: now.subtract(const Duration(days: 19)),
      decidedAt: now.subtract(const Duration(days: 14)),
      decisionNote: 'Clear policy violation — workshop video showed another company\'s premises',
      workshopAddress: 'Warszawa',
      docPaths: const ['mock://krs.pdf'],
      workshopVideo: _seedVideo(kind: TGAuditVideoKind.file, code: '1111', fileUrl: 'mock://workshop/1111.mp4', daysAgo: 18),
      reapplyUsed: false,
      decisionPath: 'direct',
    ));

    // Revoke-pending approved (legacy seed companion)
    applications.add(TGAuditApplication(
      id: 'AUD-seed-revoke',
      sellerId: 'seller_inoxline',
      status: TGAuditApplicationStatus.approved,
      createdAt: now.subtract(const Duration(days: 100)),
      paidAt: now.subtract(const Duration(days: 98)),
      decidedAt: now.subtract(const Duration(days: 90)),
      validUntil: DateTime(now.year, now.month + 6, now.day),
      decisionNote: 'Revoke pending review',
      workshopAddress: 'Gliwice',
      workshopVideo: _seedVideo(kind: TGAuditVideoKind.file, code: '5520', fileUrl: 'mock://workshop/5520.mp4', daysAgo: 95),
      decisionPath: 'direct',
      checklist: passAll,
    ));
  }
}
