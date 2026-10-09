import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';

enum TGDealQueueKind { objection, flagged, dispute, appeal, all }

enum TGDealRiskFlag {
  buyerAccountNew,
  sharedDevice,
  sellerAnsweredFast,
  sellerNewBuyerDeals,
  reciprocal,
  sameBuyerManyReviews,
  listingSoldOtherBuyer,
  sellerDisputedMany,
}

enum TGScoreRow { platformSignals, liveVideo, paymentTrace, documents, sellerCrossCheck, photos }

enum TGScoreMark { strong, weak, missing, contradicts }

enum TGCodeMatch { matches, doesNotMatch, cantTell }

enum TGPlatformSignalKind { messages, callClicks, listingPublished, listingSold }

@immutable
class TGDealTimelineEvent {
  const TGDealTimelineEvent({required this.at, required this.actor, required this.label});
  final DateTime at;
  final String actor;
  final String label;
}

@immutable
class TGPlatformSignal {
  const TGPlatformSignal({required this.kind, required this.present, required this.text});
  final TGPlatformSignalKind kind;
  final bool present;
  final String text;
}

class TGScoreLine {
  TGScoreLine({required this.row, this.mark = TGScoreMark.missing, this.note = ''});
  final TGScoreRow row;
  TGScoreMark mark;
  String note;
}

@immutable
class TGDealThreadMsg {
  const TGDealThreadMsg({required this.at, required this.from, required this.body});
  final DateTime at;
  final String from;
  final String body;
}

@immutable
class TGDealPartyCard {
  const TGDealPartyCard({
    required this.userId,
    required this.name,
    required this.role,
    required this.accountAgeDays,
    required this.phoneVerified,
    required this.totalDeals,
    required this.confirmed,
    required this.declined,
    this.sellerType,
    this.unjustObjections90d,
  });
  final String userId;
  final String name;
  final String role;
  final int accountAgeDays;
  final bool phoneVerified;
  final int totalDeals;
  final int confirmed;
  final int declined;
  final TGSellerType? sellerType;
  final int? unjustObjections90d;
}

class TGAdminDealCase {
  TGAdminDealCase({
    required this.dealNo,
    required this.queue,
    required this.listingNo,
    required this.listingTitle,
    required this.seller,
    required this.buyer,
    required this.createdAt,
    required this.slaStart,
    required this.decisionDueAt,
    this.evidenceDueAt,
    this.hardCapAt,
    this.priority = TGModerationPriority.medium,
    this.statusLabel = 'Open',
    this.assignedTo,
    this.removedBy,
    this.promoted = false,
    this.noEvidence = false,
    this.hardCapBreached = false,
    this.photoOnlyRejected = false,
    this.privateSeller = false,
    this.captureCode,
    this.reviewPreview = '',
    this.reviewState = TGPurchaseReviewState.suspendedObjection,
    this.sellerReason,
    this.sellerNote,
    this.buyerNote,
    this.imageUrl = 'assets/images/bartscher_2002170.webp',
    this.linkedDealId,
    this.linkedReviewId,
    this.linkedObjectionId,
    this.evidenceExtended = false,
    List<TGDealRiskFlag>? flags,
    List<TGDealTimelineEvent>? timeline,
    List<TGPlatformSignal>? signals,
    List<TGEvidence>? evidence,
    List<TGScoreLine>? scorecard,
    List<String>? pastDeals,
    List<TGDealThreadMsg>? buyerThread,
    List<TGDealThreadMsg>? sellerThread,
  })  : flags = flags ?? const [],
        timeline = timeline ?? const [],
        signals = signals ?? const [],
        evidence = evidence ?? const [],
        scorecard = scorecard ?? [for (final r in TGScoreRow.values) TGScoreLine(row: r)],
        pastDeals = pastDeals ?? const ['D-2026-000088 · confirmed', 'D-2026-000041 · declined'],
        buyerThread = buyerThread ?? [],
        sellerThread = sellerThread ?? [];

  final String dealNo;
  TGDealQueueKind queue;
  final String listingNo;
  final String listingTitle;
  final TGDealPartyCard seller;
  final TGDealPartyCard buyer;
  final DateTime createdAt;
  DateTime slaStart;
  DateTime decisionDueAt;
  DateTime? evidenceDueAt;
  DateTime? hardCapAt;
  TGModerationPriority priority;
  String statusLabel;
  String? assignedTo;
  String? removedBy;
  bool promoted;
  bool noEvidence;
  bool hardCapBreached;
  bool photoOnlyRejected;
  bool privateSeller;
  String? captureCode;
  String reviewPreview;
  TGPurchaseReviewState reviewState;
  String? sellerReason;
  String? sellerNote;
  String? buyerNote;
  final String imageUrl;
  String? linkedDealId;
  String? linkedReviewId;
  String? linkedObjectionId;
  bool evidenceExtended;
  List<TGDealRiskFlag> flags;
  List<String> pastDeals;
  List<TGDealThreadMsg> buyerThread;
  List<TGDealThreadMsg> sellerThread;
  List<TGDealTimelineEvent> timeline;
  List<TGPlatformSignal> signals;
  List<TGEvidence> evidence;
  List<TGScoreLine> scorecard;
  TGCodeMatch? codeMatch;
  String? lastViewed;
  DateTime? evidenceDeleteAt;
  bool flagsReviewed = false;
  String? snapshotStatus;

  int get holdFlagCount => flags.where((f) => f != TGDealRiskFlag.sellerDisputedMany).length;

  bool get isHold => holdFlagCount >= 2;

  TGSlaTone toneFor(DateTime start, DateTime end, [DateTime? now]) {
    final t = now ?? TGClock.now();
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return t.isAfter(end) ? TGSlaTone.overdue : TGSlaTone.ok;
    final p = t.difference(start).inMilliseconds / total;
    if (p >= 1) return TGSlaTone.overdue;
    if (p >= 0.8) return TGSlaTone.warning;
    return TGSlaTone.ok;
  }
}

bool tgDealRiskIsHold(TGDealRiskFlag f) => f != TGDealRiskFlag.sellerDisputedMany;

DateTime tgAddBusinessDays(DateTime from, int days) {
  var d = from;
  var left = days;
  while (left > 0) {
    d = d.add(const Duration(days: 1));
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) left--;
  }
  return d;
}
