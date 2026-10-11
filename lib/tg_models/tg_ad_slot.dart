import 'package:flutter/foundation.dart';

enum TGAdSlotKind { restaurantListing, store, manufacturer, custom }

enum TGAdSlotStatus { draft, paid, pendingReview, approved, rejected, live, ended }

@immutable
class TGAdSlot {
  const TGAdSlot({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.targetUrl,
    required this.title,
    required this.imageUrl,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.impressions = 0,
    this.clicks = 0,
    this.pricePln = 0,
    this.rejectReason,
    this.enterpriseEntitlement = false,
    this.isMock = false,
    this.endedEarlyReason,
    this.refundPln,
  });

  final String id;
  final String ownerId;
  final TGAdSlotKind kind;
  final String targetUrl;
  final String title;
  final String imageUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final TGAdSlotStatus status;
  final int impressions;
  final int clicks;
  final int pricePln;
  final String? rejectReason;
  final bool enterpriseEntitlement;
  final bool isMock;
  final String? endedEarlyReason;
  final int? refundPln;

  bool get isLive => status == TGAdSlotStatus.live;
  bool get isPendingReview => status == TGAdSlotStatus.pendingReview;

  TGAdSlot copyWith({
    TGAdSlotStatus? status,
    int? impressions,
    int? clicks,
    String? rejectReason,
    String? title,
    String? imageUrl,
    String? targetUrl,
    DateTime? startsAt,
    DateTime? endsAt,
    String? endedEarlyReason,
    int? refundPln,
    bool clearReject = false,
  }) =>
      TGAdSlot(
        id: id,
        ownerId: ownerId,
        kind: kind,
        targetUrl: targetUrl ?? this.targetUrl,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        status: status ?? this.status,
        impressions: impressions ?? this.impressions,
        clicks: clicks ?? this.clicks,
        pricePln: pricePln,
        rejectReason: clearReject ? null : (rejectReason ?? this.rejectReason),
        enterpriseEntitlement: enterpriseEntitlement,
        isMock: isMock,
        endedEarlyReason: endedEarlyReason ?? this.endedEarlyReason,
        refundPln: refundPln ?? this.refundPln,
      );
}
