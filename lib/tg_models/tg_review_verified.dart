import 'package:flutter/foundation.dart';

/// Why a seller carries the green shield. Never purchasable.
enum TGVerifiedBasis { companyRegistry, buyerReviews }

extension TGVerifiedBasisWire on TGVerifiedBasis {
  String get wire => switch (this) {
        TGVerifiedBasis.companyRegistry => 'company_registry',
        TGVerifiedBasis.buyerReviews => 'buyer_reviews',
      };

  static TGVerifiedBasis? fromWire(Object? raw) => switch (raw) {
        'company_registry' => TGVerifiedBasis.companyRegistry,
        'buyer_reviews' => TGVerifiedBasis.buyerReviews,
        _ => null,
      };
}

@immutable
class TGReviewStats {
  const TGReviewStats({
    required this.counted,
    required this.negatives,
    required this.distinctBuyers,
    required this.computedAt,
  });

  final int counted;
  final int negatives;
  final int distinctBuyers;
  final DateTime computedAt;

  double get negativeShare => counted == 0 ? 0 : negatives / counted;

  /// Whole percent for display ("1 negative (7%)").
  int get negativePercent => (negativeShare * 100).round();

  Map<String, dynamic> toJson() => {
        'counted': counted,
        'negatives': negatives,
        'negativeShare': negativeShare,
        'distinctBuyers': distinctBuyers,
        'computedAt': computedAt.toIso8601String(),
      };

  static TGReviewStats? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return TGReviewStats(
      counted: (raw['counted'] as num?)?.toInt() ?? 0,
      negatives: (raw['negatives'] as num?)?.toInt() ?? 0,
      distinctBuyers: (raw['distinctBuyers'] as num?)?.toInt() ?? 0,
      computedAt: DateTime.tryParse('${raw['computedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Admin-editable rules for the review-based shield (individual sellers).
@immutable
class ReviewVerifiedConfig {
  const ReviewVerifiedConfig({
    this.enabled = true,
    this.appliesTo = const ['individual'],
    this.minCountedReviews = 5,
    this.minDistinctBuyers = 5,
    this.maxNegativeShare = 0.10,
    this.negativeStarsMax = 2,
    this.windowMonths = 12,
    this.minAccountAgeDays = 30,
    this.requirePhoneVerified = true,
    this.blockedAfterUpheldReportDays = 90,
  });

  final bool enabled;
  final List<String> appliesTo;
  final int minCountedReviews;
  final int minDistinctBuyers;
  final double maxNegativeShare;
  final int negativeStarsMax;
  final int windowMonths;
  final int minAccountAgeDays;
  final bool requirePhoneVerified;
  final int blockedAfterUpheldReportDays;

  bool get appliesToIndividuals => enabled && appliesTo.contains('individual');

  ReviewVerifiedConfig copyWith({
    bool? enabled,
    List<String>? appliesTo,
    int? minCountedReviews,
    int? minDistinctBuyers,
    double? maxNegativeShare,
    int? negativeStarsMax,
    int? windowMonths,
    int? minAccountAgeDays,
    bool? requirePhoneVerified,
    int? blockedAfterUpheldReportDays,
  }) =>
      ReviewVerifiedConfig(
        enabled: enabled ?? this.enabled,
        appliesTo: appliesTo ?? this.appliesTo,
        minCountedReviews: minCountedReviews ?? this.minCountedReviews,
        minDistinctBuyers: minDistinctBuyers ?? this.minDistinctBuyers,
        maxNegativeShare: maxNegativeShare ?? this.maxNegativeShare,
        negativeStarsMax: negativeStarsMax ?? this.negativeStarsMax,
        windowMonths: windowMonths ?? this.windowMonths,
        minAccountAgeDays: minAccountAgeDays ?? this.minAccountAgeDays,
        requirePhoneVerified: requirePhoneVerified ?? this.requirePhoneVerified,
        blockedAfterUpheldReportDays: blockedAfterUpheldReportDays ?? this.blockedAfterUpheldReportDays,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'appliesTo': appliesTo,
        'minCountedReviews': minCountedReviews,
        'minDistinctBuyers': minDistinctBuyers,
        'maxNegativeShare': maxNegativeShare,
        'negativeStarsMax': negativeStarsMax,
        'windowMonths': windowMonths,
        'minAccountAgeDays': minAccountAgeDays,
        'requirePhoneVerified': requirePhoneVerified,
        'blockedAfterUpheldReportDays': blockedAfterUpheldReportDays,
      };

  static ReviewVerifiedConfig fromJson(Map<String, dynamic> j) {
    const d = ReviewVerifiedConfig();
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return ReviewVerifiedConfig(
      enabled: j['enabled'] is bool ? j['enabled'] as bool : d.enabled,
      appliesTo: j['appliesTo'] is List ? [for (final v in j['appliesTo'] as List) '$v'] : d.appliesTo,
      minCountedReviews: i('minCountedReviews', d.minCountedReviews),
      minDistinctBuyers: i('minDistinctBuyers', d.minDistinctBuyers),
      maxNegativeShare: (j['maxNegativeShare'] as num?)?.toDouble() ?? d.maxNegativeShare,
      negativeStarsMax: i('negativeStarsMax', d.negativeStarsMax),
      windowMonths: i('windowMonths', d.windowMonths),
      minAccountAgeDays: i('minAccountAgeDays', d.minAccountAgeDays),
      requirePhoneVerified: j['requirePhoneVerified'] is bool ? j['requirePhoneVerified'] as bool : d.requirePhoneVerified,
      blockedAfterUpheldReportDays: i('blockedAfterUpheldReportDays', d.blockedAfterUpheldReportDays),
    );
  }
}

/// Account facts the review rule needs besides reviews.
@immutable
class TGIndividualSellerFacts {
  const TGIndividualSellerFacts({this.accountCreatedAt, this.phoneVerified = false, this.lastUpheldReportAt});

  final DateTime? accountCreatedAt;
  final bool phoneVerified;
  final DateTime? lastUpheldReportAt;
}

/// One row of the ✓/— checklist.
@immutable
class TGVerifiedRequirement {
  const TGVerifiedRequirement({required this.id, required this.met, required this.labelKey, this.params = const {}});

  final String id;
  final bool met;
  final String labelKey;
  final Map<String, String> params;
}

/// Admin decision that wins over the automatic rule until cleared.
@immutable
class TGVerifiedOverride {
  const TGVerifiedOverride({required this.sellerId, required this.verified, required this.reason, required this.actorId, required this.at});

  final String sellerId;
  final bool verified;
  final String reason;
  final String actorId;
  final DateTime at;
}
