import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum TGReportTarget { listing, seller, review, request }

enum TGReportReason {
  fraud,
  prohibited,
  duplicate,
  copied,
  wrongCategory,
  sold,
  stolenContent,
  misleading,
  fakePhotos,
  offensive,
  fakeStore,
  fakeReviews,
  harassment,
  fakeReview,
  sellerOrCompetitor,
  personalData,
  spamRequest,
  othersPersonalData,
  outOfScope,
  other,
}

enum TGMisleadingPart { price, condition, specs, photos }

enum TGFraudSignal { advancePayment, sellerUnreachable, fakePhotos, tooGood }

enum TGReportStatus {
  new_,
  inReview,
  waitingSeller,
  resolvedRemoved,
  resolvedNoViolation,
  resolvedOther,
}

enum TGModerationPriority { high, medium, low }

enum TGModerationActionType {
  dismiss,
  requestInfo,
  hide,
  remove,
  requestProof,
  contactSeller,
  contactReporter,
  warn,
  suspend,
  restore,
  undo,
  assign,
  appealDecision,
  other,
}

enum TGRemoveReason { duplicate, stolenContent, fraud, prohibited, misleading, other }

enum TGSlaTone { ok, warning, overdue }

@immutable
class TGModerationReport {
  const TGModerationReport({
    required this.reportNo,
    required this.listingNo,
    required this.reason,
    required this.reporterEmail,
    required this.reporterId,
    required this.text,
    required this.createdAt,
    this.target = TGReportTarget.listing,
    this.sellerId,
    this.reviewId,
    this.reporterName,
    this.evidenceUrls = const [],
    this.status = TGReportStatus.new_,
    this.otherListingRef,
    this.originalListingRef,
    this.isOriginalOwner = false,
    this.misleadingPart,
    this.fraudSignals = const [],
    this.confirmed = false,
  });

  final String reportNo;
  final String listingNo;
  final TGReportTarget target;
  final String? sellerId;
  final String? reviewId;
  final TGReportReason reason;
  final String reporterEmail;
  final String reporterId;
  final String? reporterName;
  final String text;
  final DateTime createdAt;
  final List<String> evidenceUrls;
  final TGReportStatus status;
  final String? otherListingRef;
  final String? originalListingRef;
  final bool isOriginalOwner;
  final TGMisleadingPart? misleadingPart;
  final List<TGFraudSignal> fraudSignals;
  final bool confirmed;

  TGModerationReport copyWith({TGReportStatus? status}) => TGModerationReport(
        reportNo: reportNo,
        listingNo: listingNo,
        target: target,
        sellerId: sellerId,
        reviewId: reviewId,
        reason: reason,
        reporterEmail: reporterEmail,
        reporterId: reporterId,
        reporterName: reporterName,
        text: text,
        createdAt: createdAt,
        evidenceUrls: evidenceUrls,
        status: status ?? this.status,
        otherListingRef: otherListingRef,
        originalListingRef: originalListingRef,
        isOriginalOwner: isOriginalOwner,
        misleadingPart: misleadingPart,
        fraudSignals: fraudSignals,
        confirmed: confirmed,
      );
}

class TGSellerModerationCase {
  TGSellerModerationCase({
    required this.listing,
    required this.moderatorMessage,
    this.replyBy,
    this.shortReason,
    this.removalRule,
    this.removalExplanation,
    this.appealed = false,
    this.finalRemoval = false,
    this.soldNudge = false,
    this.soldResolved = false,
    this.decidedAt,
    this.decidedByHuman = true,
    List<String>? responses,
  }) : responses = responses ?? [];

  TGProduct listing;
  DateTime? replyBy;
  String moderatorMessage;
  String? shortReason;
  String? removalRule;
  String? removalExplanation;
  bool appealed;
  bool finalRemoval;
  bool soldNudge;
  bool soldResolved;
  DateTime? decidedAt;
  bool decidedByHuman;
  final List<String> responses;
}

class TGSoldHold {
  TGSoldHold({
    required this.listingNo,
    required this.askedAt,
    Set<String>? reporterIds,
  }) : reporterIds = reporterIds ?? {};

  final String listingNo;
  DateTime askedAt;
  final Set<String> reporterIds;
  bool resolved = false;

  bool shouldEscalate(DateTime now) =>
      resolved == false && (reporterIds.length >= 2 || now.difference(askedAt) >= const Duration(days: 5));
}

class TGPublicReportResult {
  const TGPublicReportResult({this.report, this.duplicateOf, this.rateLimited = false});

  final TGModerationReport? report;
  final TGModerationReport? duplicateOf;
  final bool rateLimited;

  bool get ok => report != null;
}

@immutable
class TGPhotoMatch {
  const TGPhotoMatch({
    required this.listingNoA,
    required this.listingNoB,
    required this.similarityPercent,
    required this.imageA,
    required this.imageB,
  });

  final String listingNoA;
  final String listingNoB;
  final int similarityPercent;
  final String imageA;
  final String imageB;

  String otherListing(String listingNo) => listingNo == listingNoA ? listingNoB : listingNoA;
}

@immutable
class TGModerationSeller {
  const TGModerationSeller({
    required this.seller,
    required this.phone,
    required this.accountCreatedAt,
    this.nip,
    this.email,
    this.pastReports = 0,
    this.pastRemovals = 0,
    this.suspended = false,
  });

  final TGSeller seller;
  final String phone;
  final String? nip;
  final String? email;
  final DateTime accountCreatedAt;
  final int pastReports;
  final int pastRemovals;
  final bool suspended;

  int accountAgeDays([DateTime? now]) => (now ?? DateTime.now()).difference(accountCreatedAt).inDays;

  TGModerationSeller copyWith({
    int? pastReports,
    int? pastRemovals,
    bool? suspended,
  }) =>
      TGModerationSeller(
        seller: seller,
        phone: phone,
        accountCreatedAt: accountCreatedAt,
        nip: nip,
        email: email,
        pastReports: pastReports ?? this.pastReports,
        pastRemovals: pastRemovals ?? this.pastRemovals,
        suspended: suspended ?? this.suspended,
      );
}

@immutable
class TGModerationAppeal {
  const TGModerationAppeal({
    required this.id,
    required this.listingNo,
    required this.sellerId,
    required this.createdAt,
    required this.statement,
    this.resolved = false,
    this.upheld = false,
    this.evidenceUrls = const [],
  });

  final String id;
  final String listingNo;
  final String sellerId;
  final DateTime createdAt;
  final String statement;
  final bool resolved;
  final bool upheld;
  final List<String> evidenceUrls;

  TGModerationAppeal copyWith({bool? resolved, bool? upheld}) => TGModerationAppeal(
        id: id,
        listingNo: listingNo,
        sellerId: sellerId,
        createdAt: createdAt,
        statement: statement,
        resolved: resolved ?? this.resolved,
        upheld: upheld ?? this.upheld,
        evidenceUrls: evidenceUrls,
      );
}

@immutable
class TGEmailTemplate {
  const TGEmailTemplate({
    required this.id,
    required this.name,
    required this.lang,
    required this.subject,
    required this.body,
  });

  final String id;
  final String name;
  final String lang;
  final String subject;
  final String body;

  TGEmailTemplate copyWith({String? name, String? lang, String? subject, String? body}) => TGEmailTemplate(
        id: id,
        name: name ?? this.name,
        lang: lang ?? this.lang,
        subject: subject ?? this.subject,
        body: body ?? this.body,
      );
}

@immutable
class TGAuditEntry {
  const TGAuditEntry({
    required this.id,
    required this.at,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.summary,
    this.listingNo,
    this.reportNo,
    this.reason,
    this.details = const {},
  });

  final String id;
  final DateTime at;
  final String actorId;
  final String actorRole;
  final TGModerationActionType action;
  final String summary;
  final String? listingNo;
  final String? reportNo;
  final String? reason;
  final Map<String, String> details;
}

@immutable
class TGQueuedEmail {
  const TGQueuedEmail({
    required this.id,
    required this.to,
    required this.subject,
    required this.body,
    required this.templateId,
    required this.createdAt,
    this.listingNo,
    this.sent = false,
  });

  final String id;
  final String to;
  final String subject;
  final String body;
  final String templateId;
  final DateTime createdAt;
  final String? listingNo;
  final bool sent;

  TGQueuedEmail copyWith({bool? sent}) => TGQueuedEmail(
        id: id,
        to: to,
        subject: subject,
        body: body,
        templateId: templateId,
        createdAt: createdAt,
        listingNo: listingNo,
        sent: sent ?? this.sent,
      );
}

@immutable
class TGCaseEvent {
  const TGCaseEvent({
    required this.at,
    required this.label,
    this.detail,
  });

  final DateTime at;
  final String label;
  final String? detail;
}

class TGQueueCase {
  TGQueueCase({
    required this.listingNo,
    required this.reports,
    required this.priority,
    required this.status,
    required this.firstReportedAt,
    required this.slaDeadline,
    this.sellerId,
    this.assignedTo,
  });

  final String listingNo;
  final String? sellerId;
  final List<TGModerationReport> reports;
  TGModerationPriority priority;
  TGReportStatus status;
  final DateTime firstReportedAt;
  DateTime slaDeadline;
  String? assignedTo;

  TGModerationReport get primary => reports.first;
  int get reportCount => reports.length;
  Set<String> get reporterIds => reports.map((r) => r.reporterId).toSet();
  TGReportTarget get target => reports.isEmpty ? TGReportTarget.listing : reports.first.target;

  Duration age([DateTime? now]) => (now ?? DateTime.now()).difference(firstReportedAt);

  double slaProgress([DateTime? now]) {
    final start = firstReportedAt;
    final end = slaDeadline;
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return 1;
    return ((now ?? DateTime.now()).difference(start).inMilliseconds / total).clamp(0, 2);
  }

  TGSlaTone slaTone([DateTime? now]) {
    final p = slaProgress(now);
    if (p >= 1) return TGSlaTone.overdue;
    if (p >= 0.8) return TGSlaTone.warning;
    return TGSlaTone.ok;
  }
}

extension TGReportReasonLabel on TGReportReason {
  String get label => switch (this) {
        TGReportReason.fraud => 'Fraud',
        TGReportReason.prohibited => 'Prohibited',
        TGReportReason.duplicate => 'Duplicate',
        TGReportReason.copied => 'Copied',
        TGReportReason.wrongCategory => 'Wrong category',
        TGReportReason.sold => 'Sold',
        TGReportReason.stolenContent => 'Stolen content',
        TGReportReason.misleading => 'Misleading',
        TGReportReason.fakePhotos => 'Fake photos',
        TGReportReason.offensive => 'Offensive',
        TGReportReason.fakeStore => 'Fake store',
        TGReportReason.fakeReviews => 'Fake reviews',
        TGReportReason.harassment => 'Harassment',
        TGReportReason.fakeReview => 'Fake review',
        TGReportReason.sellerOrCompetitor => 'Seller or competitor',
        TGReportReason.personalData => 'Personal data',
        TGReportReason.spamRequest => 'Spam or not a real project',
        TGReportReason.othersPersonalData => 'Contains personal data of others',
        TGReportReason.outOfScope => 'Out of scope or prohibited',
        TGReportReason.other => 'Other',
      };

  String get key => name;
}

extension TGReportStatusLabel on TGReportStatus {
  String get label => switch (this) {
        TGReportStatus.new_ => 'New',
        TGReportStatus.inReview => 'In review',
        TGReportStatus.waitingSeller => 'Waiting for seller',
        TGReportStatus.resolvedRemoved => 'Removed',
        TGReportStatus.resolvedNoViolation => 'No violation',
        TGReportStatus.resolvedOther => 'Resolved',
      };

  bool get isOpen =>
      this == TGReportStatus.new_ || this == TGReportStatus.inReview || this == TGReportStatus.waitingSeller;
}

extension TGPriorityLabel on TGModerationPriority {
  String get label => switch (this) {
        TGModerationPriority.high => 'High',
        TGModerationPriority.medium => 'Medium',
        TGModerationPriority.low => 'Low',
      };
}

extension TGRemoveReasonLabel on TGRemoveReason {
  String get label => switch (this) {
        TGRemoveReason.duplicate => 'Duplicate',
        TGRemoveReason.stolenContent => 'Stolen content',
        TGRemoveReason.fraud => 'Fraud',
        TGRemoveReason.prohibited => 'Prohibited',
        TGRemoveReason.misleading => 'Misleading',
        TGRemoveReason.other => 'Other',
      };
}
