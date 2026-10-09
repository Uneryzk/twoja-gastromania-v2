import 'package:flutter/foundation.dart';

enum TGReviewDeclaration { bought, contacted, visited }

enum TGReviewStatus { published, underReview, removed }

enum TGReviewSort { newest, highest, lowest, helpful }

enum TGReviewBlock { none, ownStore, alreadyReviewed, sameIdentity }

@immutable
class TGReviewReply {
  const TGReviewReply({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;
}

@immutable
class TGStoreReview {
  const TGStoreReview({
    required this.id,
    required this.sellerId,
    required this.authorName,
    required this.authorId,
    required this.rating,
    required this.text,
    required this.declaration,
    required this.createdAt,
    this.listingNo,
    this.listingTitle,
    this.helpfulCount = 0,
    this.reply,
    this.status = TGReviewStatus.published,
    this.authorIp = '83.11.10.4',
    this.authorPhone = '+48 600 100 200',
    this.authorEmail = 'reviewer@example.com',
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String authorName;
  final String authorId;
  final int rating;
  final String text;
  final TGReviewDeclaration declaration;
  final String? listingNo;
  final String? listingTitle;
  final DateTime createdAt;
  final int helpfulCount;
  final TGReviewReply? reply;
  final TGReviewStatus status;
  final String authorIp;
  final String authorPhone;
  final String authorEmail;
  final DateTime? updatedAt;

  bool get isPublic => status == TGReviewStatus.published;

  bool canEditAt(DateTime now) =>
      status != TGReviewStatus.removed && now.difference(createdAt) <= const Duration(days: 14);

  TGStoreReview copyWith({
    int? rating,
    String? text,
    TGReviewDeclaration? declaration,
    String? listingNo,
    String? listingTitle,
    int? helpfulCount,
    TGReviewReply? reply,
    bool clearReply = false,
    TGReviewStatus? status,
    DateTime? updatedAt,
  }) =>
      TGStoreReview(
        id: id,
        sellerId: sellerId,
        authorName: authorName,
        authorId: authorId,
        rating: rating ?? this.rating,
        text: text ?? this.text,
        declaration: declaration ?? this.declaration,
        listingNo: listingNo ?? this.listingNo,
        listingTitle: listingTitle ?? this.listingTitle,
        createdAt: createdAt,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        reply: clearReply ? null : (reply ?? this.reply),
        status: status ?? this.status,
        authorIp: authorIp,
        authorPhone: authorPhone,
        authorEmail: authorEmail,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class TGReviewSubmitResult {
  const TGReviewSubmitResult({this.review, this.block = TGReviewBlock.none, this.existing});
  final TGStoreReview? review;
  final TGReviewBlock block;
  final TGStoreReview? existing;
  bool get ok => review != null;
}
