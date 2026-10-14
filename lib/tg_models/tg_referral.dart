import 'package:flutter/foundation.dart';

/// Role label — not a referral code. Codes are person-specific (e.g. Marek-IND2026).
enum TGRepRole { individualPortfolio, corporateRelations, platformOperations }

enum TGRepStatus { active, inactive }

enum TGReferralVisibility { on, withdrawn }

enum TGReferralFunnel { registered, phoneVerified, firstQualifiedListing, paid }

enum TGReferralSegment { individual, store, restaurant, manufacturer }

enum TGRepContactCategory { individual, corporate, restaurant, manufacturer }

enum TGRepSellerStatus { registered, phoneVerified, won, paid }

/// Person-specific representative. Isolation of every query happens in
/// [ReferralRepository] — this is a UI filter, not real security; production
/// requires server-side authorization.
@immutable
class TGRepresentative {
  const TGRepresentative({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.code,
    required this.status,
    required this.createdAt,
    this.email = '',
    this.phone = '',
    this.isMock = false,
  });

  final String id;
  final String userId;
  final String displayName;
  final TGRepRole role;
  final String code;
  final TGRepStatus status;
  final DateTime createdAt;
  final String email;
  final String phone;
  final bool isMock;

  String get firstName {
    final part = displayName.trim().split(RegExp(r'\s+')).first;
    return part.isEmpty ? displayName : part;
  }

  String get roleLabel => switch (role) {
        TGRepRole.individualPortfolio => 'IND-PORTFOLIO',
        TGRepRole.corporateRelations => 'CORP-PORTFOLIO',
        TGRepRole.platformOperations => 'OPS-PORTFOLIO',
      };

  TGRepresentative copyWith({
    String? displayName,
    TGRepRole? role,
    String? code,
    TGRepStatus? status,
    String? email,
    String? phone,
  }) =>
      TGRepresentative(
        id: id,
        userId: userId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        code: code ?? this.code,
        status: status ?? this.status,
        createdAt: createdAt,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        isMock: isMock,
      );
}

/// Source of truth for a referred account. Phone/email stay inside the
/// repository and never appear on representative DTOs.
@immutable
class TGReferredAccount {
  const TGReferredAccount({
    required this.userId,
    required this.displayName,
    required this.segment,
    required this.referredByCode,
    required this.referredByRepId,
    required this.referredAt,
    required this.referralConsentAt,
    this.referralVisibility = TGReferralVisibility.on,
    this.phoneVerified = false,
    this.hasPaidPlan = false,
    this.email = '',
    this.phone = '',
    this.listings = const [],
    this.isMock = false,
  });

  final String userId;
  final String displayName;
  final TGReferralSegment segment;
  final String referredByCode;
  final String referredByRepId;
  final DateTime referredAt;
  final DateTime referralConsentAt;
  final TGReferralVisibility referralVisibility;
  final bool phoneVerified;
  final bool hasPaidPlan;
  final String email;
  final String phone;
  final List<TGRefListingMeta> listings;
  final bool isMock;

  TGReferredAccount copyWith({
    String? displayName,
    TGReferralSegment? segment,
    String? referredByCode,
    String? referredByRepId,
    DateTime? referredAt,
    DateTime? referralConsentAt,
    TGReferralVisibility? referralVisibility,
    bool? phoneVerified,
    bool? hasPaidPlan,
    String? email,
    String? phone,
    List<TGRefListingMeta>? listings,
  }) =>
      TGReferredAccount(
        userId: userId,
        displayName: displayName ?? this.displayName,
        segment: segment ?? this.segment,
        referredByCode: referredByCode ?? this.referredByCode,
        referredByRepId: referredByRepId ?? this.referredByRepId,
        referredAt: referredAt ?? this.referredAt,
        referralConsentAt: referralConsentAt ?? this.referralConsentAt,
        referralVisibility: referralVisibility ?? this.referralVisibility,
        phoneVerified: phoneVerified ?? this.phoneVerified,
        hasPaidPlan: hasPaidPlan ?? this.hasPaidPlan,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        listings: listings ?? this.listings,
        isMock: isMock,
      );
}

@immutable
class TGRefListingMeta {
  const TGRefListingMeta({
    required this.id,
    required this.title,
    required this.listingNo,
    this.active = true,
    this.copy = false,
    this.photos = 0,
    this.completionPct = 0,
  });

  final String id;
  final String title;
  final String listingNo;
  final bool active;
  final bool copy;
  final int photos;
  final int completionPct;

  /// SPECIAL-4B: completion ≥80, ≥3 photos, not a copy, active.
  bool get qualifiedActive => active && !copy && photos >= 3 && completionPct >= 80;
}

/// Sanitized seller row. Must not carry phone, email, address, messages,
/// payment method or invoice fields.
@immutable
class TGRepSellerRow {
  const TGRepSellerRow({
    required this.userId,
    required this.publicName,
    required this.registeredAt,
    required this.segment,
    required this.planLabel,
    required this.status,
    required this.listingCount,
    required this.qualifiedActiveCount,
    required this.views30,
    required this.callTaps30,
    required this.messages30,
    required this.favorites30,
    this.attributedNetGrosz,
    this.enoughEngagement = false,
  });

  final String userId;
  final String publicName;
  final DateTime registeredAt;
  final TGReferralSegment segment;
  final String planLabel;
  final TGRepSellerStatus status;
  final int listingCount;
  final int qualifiedActiveCount;
  final int views30;
  final int callTaps30;
  final int messages30;
  final int favorites30;
  /// Attributed net, VAT excluded, integer grosz. Never float.
  final int? attributedNetGrosz;
  final bool enoughEngagement;

  Map<String, Object?> toJson() => {
        'userId': userId,
        'publicName': publicName,
        'registeredAt': registeredAt.toIso8601String(),
        'segment': segment.name,
        'planLabel': planLabel,
        'status': status.name,
        'listingCount': listingCount,
        'qualifiedActiveCount': qualifiedActiveCount,
        'views30': views30,
        'callTaps30': callTaps30,
        'messages30': messages30,
        'favorites30': favorites30,
        'attributedNetGrosz': attributedNetGrosz,
        'enoughEngagement': enoughEngagement,
      };
}

@immutable
class TGRepFunnelSummary {
  const TGRepFunnelSummary({
    this.registered = 0,
    this.phoneVerified = 0,
    this.firstQualifiedListing = 0,
    this.paid = 0,
    this.weeklySignups = 0,
    this.withdrawnCount = 0,
  });

  final int registered;
  final int phoneVerified;
  final int firstQualifiedListing;
  final int paid;
  final int weeklySignups;
  final int withdrawnCount;
}

enum TGRepMetricState { value, notEnough }

@immutable
class TGRepMetric<T> {
  const TGRepMetric.value(this.value) : state = TGRepMetricState.value;
  const TGRepMetric.notEnough()
      : value = null,
        state = TGRepMetricState.notEnough;

  final T? value;
  final TGRepMetricState state;
  bool get hasValue => state == TGRepMetricState.value && value != null;
}

@immutable
class TGRepPerformanceReport {
  const TGRepPerformanceReport({
    required this.id,
    required this.repId,
    required this.sellerUserId,
    required this.periodDays,
    required this.from,
    required this.to,
    required this.snapshotAt,
    required this.listingCount,
    required this.views,
    required this.callTaps,
    required this.messages,
    required this.favorites,
    this.topListingTitle,
    this.topListingNo,
  });

  final String id;
  final String repId;
  final String sellerUserId;
  final int periodDays;
  final DateTime from;
  final DateTime to;
  final DateTime snapshotAt;
  final TGRepMetric<int> listingCount;
  final TGRepMetric<int> views;
  final TGRepMetric<int> callTaps;
  final TGRepMetric<int> messages;
  final TGRepMetric<int> favorites;
  final String? topListingTitle;
  final String? topListingNo;
}

@immutable
class TGRepShareLink {
  const TGRepShareLink({
    required this.token,
    required this.reportId,
    required this.repId,
    required this.sellerUserId,
    required this.createdAt,
    required this.expiresAt,
    this.revokedAt,
    this.revokedBy,
  });

  final String token;
  final String reportId;
  final String repId;
  final String sellerUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? revokedBy;

  bool isActive(DateTime now) => revokedAt == null && now.isBefore(expiresAt);
}

@immutable
class TGRepWeeklyLog {
  const TGRepWeeklyLog({
    required this.repId,
    required this.weekStart,
    this.contacts = const {},
    this.meetings = const {},
    this.note = '',
  });

  final String repId;
  final DateTime weekStart;
  final Map<TGRepContactCategory, int> contacts;
  final Map<TGRepContactCategory, int> meetings;
  final String note;

  TGRepWeeklyLog copyWith({
    Map<TGRepContactCategory, int>? contacts,
    Map<TGRepContactCategory, int>? meetings,
    String? note,
  }) =>
      TGRepWeeklyLog(
        repId: repId,
        weekStart: weekStart,
        contacts: contacts ?? this.contacts,
        meetings: meetings ?? this.meetings,
        note: note ?? this.note,
      );
}

@immutable
class TGReferralAudit {
  const TGReferralAudit({
    required this.id,
    required this.at,
    required this.actorId,
    required this.action,
    this.detail = '',
    this.reason,
  });

  final String id;
  final DateTime at;
  final String actorId;
  final String action;
  final String detail;
  final String? reason;
}

enum TGReferralCodeResult { valid, unrecognized, rateLimited, signupOnly }

@immutable
class TGReferralCodeCheck {
  const TGReferralCodeCheck({required this.result, this.firstName, this.rep});

  final TGReferralCodeResult result;
  final String? firstName;
  final TGRepresentative? rep;
}

/// Config for attribution window and share-link lifetime.
@immutable
class TGReferralConfig {
  const TGReferralConfig({
    this.attributionRevenueMonths = 12,
    this.shareLinkDays = 14,
    this.maxFailedChecksPerHour = 5,
  });

  final int attributionRevenueMonths;
  final int shareLinkDays;
  final int maxFailedChecksPerHour;
}
