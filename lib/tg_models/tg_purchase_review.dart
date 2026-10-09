import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum TGPurchaseReviewState {
  awaitingSeller,
  confirmed,
  confirmedModerator,
  notDisputed,
  notVerified,
  suspendedObjection,
  pendingCheck,
  removed,
}

enum TGObjectionKind { soldToOther, notSold }

enum TGObjectionStatus { awaitingEvidence, evidenceReceived, noEvidence, decided }

enum TGObjectionDecision { confirmed, removed, notVerified }

enum TGEvidenceType { liveVideo, paymentTrace, document, photo }

enum TGEvidenceRole { buyer, seller }

enum TGNotSoldReason { stillForSale, soldOutside, neverContacted, other }

@immutable
class TGPurchaseReply {
  const TGPurchaseReply({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;
}

class TGPurchaseReview {
  TGPurchaseReview({
    required this.id,
    required this.sellerId,
    required this.authorId,
    required this.authorName,
    required this.dealId,
    required this.listingNo,
    required this.listingTitleSnapshot,
    required this.dealType,
    required this.dealMonth,
    required this.rating,
    required this.text,
    required this.state,
    DateTime? createdAt,
    DateTime? editableUntil,
    this.helpfulCount = 0,
    this.reply,
    this.riskFlags = const [],
    this.imageUrl = '',
    this.price,
    this.appealed = false,
    this.keepListingActive = false,
    this.hidden = false,
    DateTime? sellerAnswerDueAt,
  })  : createdAt = createdAt ?? TGClock.now(),
        editableUntil = editableUntil ?? (createdAt ?? TGClock.now()).add(const Duration(days: 14)),
        sellerAnswerDueAt = sellerAnswerDueAt ?? (createdAt ?? TGClock.now()).add(const Duration(days: 5));

  final String id;
  final String sellerId;
  final String authorId;
  final String authorName;
  final String dealId;
  final String listingNo;
  final String listingTitleSnapshot;
  final TGDealType dealType;
  final DateTime dealMonth;
  int rating;
  String text;
  TGPurchaseReviewState state;
  final DateTime createdAt;
  DateTime editableUntil;
  int helpfulCount;
  TGPurchaseReply? reply;
  List<String> riskFlags;
  final String imageUrl;
  final int? price;
  bool appealed;
  bool keepListingActive;
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

  bool get canEdit =>
      TGClock.now().isBefore(editableUntil) && state != TGPurchaseReviewState.suspendedObjection && state != TGPurchaseReviewState.removed;

  bool get holdRisk => riskFlags.where((f) => f.startsWith('hold') || f == 'hold').length >= 2;
}

class TGObjection {
  TGObjection({
    required this.id,
    required this.dealId,
    required this.reviewId,
    required this.kind,
    required this.reason,
    DateTime? createdAt,
    DateTime? evidenceDueAt,
    DateTime? hardCapAt,
    this.note,
    this.status = TGObjectionStatus.awaitingEvidence,
    this.decision,
    this.decidedAt,
    this.evidenceExtendedOnce = false,
  })  : createdAt = createdAt ?? TGClock.now(),
        evidenceDueAt = evidenceDueAt ?? (createdAt ?? TGClock.now()).add(const Duration(hours: 48)),
        hardCapAt = hardCapAt ?? (createdAt ?? TGClock.now()).add(const Duration(days: 5));

  final String id;
  final String dealId;
  final String reviewId;
  final TGObjectionKind kind;
  final String reason;
  String? note;
  final DateTime createdAt;
  DateTime evidenceDueAt;
  final DateTime hardCapAt;
  TGObjectionStatus status;
  TGObjectionDecision? decision;
  DateTime? decidedAt;
  bool evidenceExtendedOnce;
}

class TGEvidence {
  TGEvidence({
    required this.id,
    required this.dealId,
    required this.uploaderRole,
    required this.type,
    required this.fileUrl,
    DateTime? createdAt,
    this.durationSec,
    this.captureCode,
    this.deleteAt,
  }) : createdAt = createdAt ?? TGClock.now();

  final String id;
  final String dealId;
  final TGEvidenceRole uploaderRole;
  final TGEvidenceType type;
  final String fileUrl;
  final int? durationSec;
  final String? captureCode;
  final DateTime createdAt;
  DateTime? deleteAt;
}

enum ListingNoCheck { ok, notFound, wrongSeller, removed, ownListing, alreadyReviewed }

class TGListingHit {
  const TGListingHit({
    required this.listingNo,
    required this.title,
    required this.imageUrl,
    required this.sellerId,
    this.price,
    this.city = '',
    this.sellerName = '',
    this.sellerVerified = false,
    this.status = TGListingStatus.active,
    this.ownerId,
  });
  final String listingNo;
  final String title;
  final String imageUrl;
  final String sellerId;
  final int? price;
  final String city;
  final String sellerName;
  final bool sellerVerified;
  final TGListingStatus status;
  final String? ownerId;
}
