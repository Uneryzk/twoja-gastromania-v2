import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';

/// What the banner points at — always the buyer's own active content.
/// [listing] = individual or store equipment listing; [restaurantListing] =
/// restaurant transfer (devren); [store] = store page; [manufacturer] = maker profile.
enum TGAdSlotKind { restaurantListing, store, manufacturer, listing, custom }

enum TGAdSlotStatus { draft, paid, pendingReview, changesRequested, approved, rejected, live, ended, cancelled }

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
    this.durationDays = 14,
    this.impressions = 0,
    this.clicks = 0,
    this.pricePln = 0,
    this.rejectReason,
    this.changesNote,
    this.correctionsUsed = 0,
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
  /// Paid period length in days.
  final int durationDays;
  final int impressions;
  final int clicks;
  final int pricePln;
  final String? rejectReason;
  final String? changesNote;
  final int correctionsUsed;
  final bool enterpriseEntitlement;
  final bool isMock;
  final String? endedEarlyReason;
  final int? refundPln;

  bool get isLive => status == TGAdSlotStatus.live;
  bool get isPendingReview => status == TGAdSlotStatus.pendingReview;

  /// Holds a seat on the day calendar (paid and not refunded / finished).
  bool get occupiesSeat => switch (status) {
        TGAdSlotStatus.paid ||
        TGAdSlotStatus.pendingReview ||
        TGAdSlotStatus.changesRequested ||
        TGAdSlotStatus.approved ||
        TGAdSlotStatus.live =>
          true,
        _ => false,
      };

  TGAdSlot copyWith({
    TGAdSlotStatus? status,
    int? impressions,
    int? clicks,
    String? rejectReason,
    String? changesNote,
    int? correctionsUsed,
    String? title,
    String? imageUrl,
    String? targetUrl,
    DateTime? startsAt,
    DateTime? endsAt,
    String? endedEarlyReason,
    int? refundPln,
    bool clearReject = false,
    bool clearChangesNote = false,
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
        durationDays: durationDays,
        impressions: impressions ?? this.impressions,
        clicks: clicks ?? this.clicks,
        pricePln: pricePln,
        rejectReason: clearReject ? null : (rejectReason ?? this.rejectReason),
        changesNote: clearChangesNote ? null : (changesNote ?? this.changesNote),
        correctionsUsed: correctionsUsed ?? this.correctionsUsed,
        enterpriseEntitlement: enterpriseEntitlement,
        isMock: isMock,
        endedEarlyReason: endedEarlyReason ?? this.endedEarlyReason,
        refundPln: refundPln ?? this.refundPln,
      );
}

/// 24 h lock on a calendar window between "Continue to payment" and payment.
@immutable
class TGAdHold {
  const TGAdHold({
    required this.id,
    required this.ownerId,
    required this.startsAt,
    required this.durationDays,
    required this.expiresAt,
  });

  final String id;
  final String ownerId;
  final DateTime startsAt;
  /// Paid period length in days.
  final int durationDays;
  final DateTime expiresAt;

  DateTime get endsAt => DurationService.endOf(startsAt, durationDays);
}

@immutable
class TGAdWaitlistEntry {
  const TGAdWaitlistEntry({required this.ownerId, required this.durationDays, required this.createdAt});
  final String ownerId;
  /// Paid period length in days.
  final int durationDays;
  final DateTime createdAt;
}
