import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

export 'package:twoja_gastromania/tg_models/tg_special_order.dart' show TGProjectCompletionStatus;

enum TGSpecialObjectionReason { projectNotCompleted, buyerDidntChooseMe, differentProject, other }

enum TGPrivateBuyerReportReason { noShow, unresponsive, abusive, other }

enum TGSponsorSlotStatus { available, reserved, contentPending, active, expired, cancelled }

@immutable
class TGSpecialSubScores {
  const TGSpecialSubScores({
    required this.quality,
    required this.communication,
    required this.deadline,
    required this.quoteAccuracy,
    this.installation,
  });
  final int quality;
  final int communication;
  final int deadline;
  final int quoteAccuracy;
  final int? installation;

  double get average {
    final vals = [quality, communication, deadline, quoteAccuracy, if (installation != null) installation!];
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

/// Special Order project review — reuses [TGPurchaseReviewState] from DEAL-2 v2.
class TGSpecialReview {
  TGSpecialReview({
    required this.id,
    required this.requestId,
    required this.requestNo,
    required this.sellerId,
    required this.authorId,
    required this.authorName,
    required this.projectTitleSnapshot,
    required this.awardedAt,
    required this.completionStatus,
    required this.rating,
    required this.subScores,
    required this.text,
    required this.state,
    DateTime? createdAt,
    DateTime? editableUntil,
    DateTime? sellerAnswerDueAt,
    this.completedAt,
    this.helpfulCount = 0,
    this.reply,
    this.riskFlags = const [],
    this.hidden = false,
  })  : createdAt = createdAt ?? TGClock.now(),
        editableUntil = editableUntil ?? (createdAt ?? TGClock.now()).add(const Duration(days: 14)),
        sellerAnswerDueAt = sellerAnswerDueAt ?? (createdAt ?? TGClock.now()).add(const Duration(days: 5));

  final String id;
  final String requestId;
  final String requestNo;
  final String sellerId;
  final String authorId;
  final String authorName;
  final String projectTitleSnapshot;
  final DateTime awardedAt;
  final TGProjectCompletionStatus completionStatus;
  final DateTime? completedAt;
  int rating;
  TGSpecialSubScores subScores;
  String text;
  TGPurchaseReviewState state;
  final DateTime createdAt;
  DateTime editableUntil;
  int helpfulCount;
  TGPurchaseReply? reply;
  List<String> riskFlags;
  bool hidden;
  DateTime sellerAnswerDueAt;

  int get awaitingDaysLeft => sellerAnswerDueAt.difference(TGClock.now()).inHours.clamp(0, 200) ~/ 24;

  bool get countsTowardRating =>
      state == TGPurchaseReviewState.confirmed ||
      state == TGPurchaseReviewState.confirmedModerator ||
      state == TGPurchaseReviewState.notDisputed;

  bool get isPublicVisible => switch (state) {
        TGPurchaseReviewState.suspendedObjection || TGPurchaseReviewState.pendingCheck => false,
        TGPurchaseReviewState.removed => false,
        _ => !hidden,
      };
}

@immutable
class TGSpecialObjection {
  const TGSpecialObjection({
    required this.id,
    required this.reviewId,
    required this.requestId,
    required this.reason,
    required this.note,
    required this.createdAt,
    required this.evidenceDueAt,
    this.status = TGObjectionStatus.awaitingEvidence,
    this.decision,
    this.evidenceIds = const [],
  });
  final String id;
  final String reviewId;
  final String requestId;
  final TGSpecialObjectionReason reason;
  final String note;
  final DateTime createdAt;
  final DateTime evidenceDueAt;
  final TGObjectionStatus status;
  final TGObjectionDecision? decision;
  final List<String> evidenceIds;
}

@immutable
class TGPrivateBuyerReport {
  const TGPrivateBuyerReport({
    required this.id,
    required this.requestId,
    required this.sellerId,
    required this.buyerId,
    required this.reason,
    required this.note,
    required this.createdAt,
  });
  final String id;
  final String requestId;
  final String sellerId;
  final String buyerId;
  final TGPrivateBuyerReportReason reason;
  final String note;
  final DateTime createdAt;
}

@immutable
class TGSponsorSlot {
  const TGSponsorSlot({
    required this.id,
    required this.specialty,
    required this.region,
    required this.status,
    this.sellerId,
    this.title,
    this.imageUrl,
    this.projectLink,
    this.startsAt,
    this.endsAt,
    this.paidAmount,
    this.decisionNote,
    this.durationDays,
    this.refundPln,
  });

  final String id;
  final TGStoreSpecialty specialty;
  final String region;
  final TGSponsorSlotStatus status;
  final String? sellerId;
  final String? title;
  final String? imageUrl;
  final String? projectLink;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? paidAmount;
  final String? decisionNote;
  final int? durationDays;
  final int? refundPln;

  String get segmentKey => '${specialty.name}|$region';

  TGSponsorSlot copyWith({
    TGSponsorSlotStatus? status,
    String? sellerId,
    String? title,
    String? imageUrl,
    String? projectLink,
    DateTime? startsAt,
    DateTime? endsAt,
    int? paidAmount,
    String? decisionNote,
    int? refundPln,
  }) =>
      TGSponsorSlot(
        id: id,
        specialty: specialty,
        region: region,
        status: status ?? this.status,
        sellerId: sellerId ?? this.sellerId,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        projectLink: projectLink ?? this.projectLink,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        paidAmount: paidAmount ?? this.paidAmount,
        decisionNote: decisionNote ?? this.decisionNote,
        durationDays: durationDays,
        refundPln: refundPln ?? this.refundPln,
      );
}

@immutable
class TGCustomProjectRatingSummary {
  const TGCustomProjectRatingSummary({required this.completedCount, required this.countedCount, this.average});
  final int completedCount;
  final int countedCount;
  final double? average;

  /// Display line for cards; null = hide row.
  String? get displayLine {
    if (completedCount <= 0) return null;
    if (countedCount >= 3 && average != null) {
      return 'Custom projects ★${average!.toStringAsFixed(1)} · $completedCount completed via Twoja Gastromania';
    }
    return '$completedCount completed via Twoja Gastromania';
  }
}
