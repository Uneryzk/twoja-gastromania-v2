import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';

enum TGDealType { sale, rental }

enum TGDealSource { sellerMarked, buyerClaim, reviewFirst }

enum TGDealStatus {
  pendingBuyer,
  pendingSeller,
  confirmed,
  declinedByBuyer,
  declinedBySeller,
  expired,
  inModeration,
  approvedByModerator,
  rejectedByModerator,
  cancelled,
  notDisputed,
  notVerified,
}

enum TGDealVerification { bothParties, moderator, notDisputed, none }

enum TGDealIdentifierType { conversation, account, phone, email }

enum TGDealActor { buyer, seller, system, moderator }

enum TGSoldReason { sold, rented, noLongerSelling, other }

enum TGOffPlatformReason { alreadyKnew, anotherWebsite, other }

enum TGDealEventType {
  created,
  reminder,
  confirmed,
  declined,
  expired,
  cancelled,
  reviewRequested,
  reminderResent,
}

@immutable
class TGDealSnapshot {
  const TGDealSnapshot({
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.city,
    this.listingType,
    this.sellerName,
    this.sellerVerified = false,
  });
  final String title;
  final String imageUrl;
  final int? price;
  final String city;
  final String? listingType;
  final String? sellerName;
  final bool sellerVerified;
}

@immutable
class TGDealEvent {
  const TGDealEvent({required this.at, required this.actor, required this.type, this.meta = const {}});
  final DateTime at;
  final TGDealActor actor;
  final TGDealEventType type;
  final Map<String, Object?> meta;
}

@immutable
class TGDealConversation {
  const TGDealConversation({
    required this.id,
    required this.listingNo,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.lastMessageAt,
  });
  final String id;
  final String listingNo;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final DateTime lastMessageAt;
}

@immutable
class TGDealAccount {
  const TGDealAccount({
    required this.userId,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.phoneVerified,
    this.sellerVerified = false,
  });
  final String userId;
  final String displayName;
  final String phone;
  final String email;
  final bool phoneVerified;
  final bool sellerVerified;
}

class TGDeal {
  TGDeal({
    required this.id,
    required this.type,
    required this.source,
    required this.status,
    required this.listingNo,
    required this.listingSnapshot,
    required this.sellerId,
    this.buyerId,
    this.verification,
    this.identifierType,
    this.identifierMasked,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.sellerConfirmedAt,
    this.buyerConfirmedAt,
    this.declineReason,
    this.riskFlags = const [],
    this.reviewRequestedAt,
    this.reviewWindowEndsAt,
    this.reviewId,
    DateTime? sellerAnswerDueAt,
    List<TGDealEvent>? events,
  })  : createdAt = createdAt ?? TGClock.now(),
        expiresAt = expiresAt ?? (createdAt ?? TGClock.now()).add(const Duration(days: 14)),
        sellerAnswerDueAt = sellerAnswerDueAt ??
            ((source == TGDealSource.reviewFirst)
                ? (createdAt ?? TGClock.now()).add(const Duration(days: 5))
                : null),
        events = events ?? const [];

  final String id;
  final TGDealType type;
  final TGDealSource source;
  TGDealStatus status;
  TGDealVerification? verification;
  final String listingNo;
  final TGDealSnapshot listingSnapshot;
  final String sellerId;
  String? buyerId;
  TGDealIdentifierType? identifierType;
  String? identifierMasked;
  final DateTime createdAt;
  DateTime expiresAt;
  DateTime? sellerConfirmedAt;
  DateTime? buyerConfirmedAt;
  String? declineReason;
  List<String> riskFlags;
  DateTime? reviewRequestedAt;
  DateTime? reviewWindowEndsAt;
  String? reviewId;
  DateTime? sellerAnswerDueAt;
  List<TGDealEvent> events;
  DateTime? lastReminderAt;
  DateTime? unitRestoreUntil;

  bool get isPending => status == TGDealStatus.pendingBuyer || status == TGDealStatus.pendingSeller;
  bool get isConfirmed => status == TGDealStatus.confirmed || status == TGDealStatus.approvedByModerator;
  bool get waitingForBuyer => status == TGDealStatus.pendingBuyer;
  bool get waitingForSeller => status == TGDealStatus.pendingSeller;

  TGDeal copy() => TGDeal(
        id: id,
        type: type,
        source: source,
        status: status,
        verification: verification,
        listingNo: listingNo,
        listingSnapshot: listingSnapshot,
        sellerId: sellerId,
        buyerId: buyerId,
        identifierType: identifierType,
        identifierMasked: identifierMasked,
        createdAt: createdAt,
        expiresAt: expiresAt,
        sellerConfirmedAt: sellerConfirmedAt,
        buyerConfirmedAt: buyerConfirmedAt,
        declineReason: declineReason,
        riskFlags: [...riskFlags],
        reviewRequestedAt: reviewRequestedAt,
        reviewWindowEndsAt: reviewWindowEndsAt,
        reviewId: reviewId,
        sellerAnswerDueAt: sellerAnswerDueAt,
        events: [...events],
      )
        ..lastReminderAt = lastReminderAt
        ..unitRestoreUntil = unitRestoreUntil;
}

class TGAppNotification {
  TGAppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.dealId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.deepLink,
    this.params = const {},
  });
  final String id;
  final String userId;
  final String type;
  final String dealId;
  final String title;
  final String body;
  final DateTime createdAt;
  DateTime? readAt;
  final String? deepLink;
  final Map<String, String> params;
  bool get unread => readAt == null;
}

String maskPhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 8) return '***';
  final cc = d.length > 9 ? d.substring(0, d.length - 9) : '';
  final rest = d.substring(d.length - 9);
  return '+$cc ${rest[0]}** *** ${rest.substring(rest.length - 3)}'.replaceAll('+ ', '+');
}

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return '***';
  return '${email[0]}***${email.substring(at)}';
}
