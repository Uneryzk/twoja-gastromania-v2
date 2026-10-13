import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_review_verified.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Review-based shield for individual sellers (VERIFY-1).
///
/// Stores keep `company_registry` (NIP + active plan, see `tgVerifiedBasis`).
/// Nothing here is sold: the badge is earned from counted buyer reviews only.
class TGReviewVerifiedService extends ChangeNotifier {
  TGReviewVerifiedService._();
  static final TGReviewVerifiedService instance = TGReviewVerifiedService._();

  ReviewVerifiedConfig _config = const ReviewVerifiedConfig();
  ReviewVerifiedConfig get config => _config;

  final Map<String, TGIndividualSellerFacts> _facts = {};
  final Map<String, TGVerifiedOverride> _overrides = {};
  final Map<String, ({bool verified, DateTime? since, TGReviewStats stats})> _state = {};
  final Map<String, List<TGPurchaseReview>> _mockReviews = {};
  bool _seeded = false;
  bool _listening = false;
  DateTime? _lastDailyRun;

  /// Mock individual sellers (hidden in production mode).
  static const mockSellers = [
    TGSeller(id: 'seller_ind_ola', name: 'Ola S.', type: TGSellerType.private, verified: false, rating: 4.9),
    TGSeller(id: 'seller_ind_bartek', name: 'Bartek W.', type: TGSellerType.private, verified: false, rating: 4.7),
    TGSeller(id: 'seller_ind_kasia', name: 'Kasia L.', type: TGSellerType.private, verified: false, rating: 4.5),
    TGSeller(id: 'seller_ind_tomek', name: 'Tomek R.', type: TGSellerType.private, verified: false, rating: 4.8),
    TGSeller(id: 'seller_ind_marta', name: 'Marta Z.', type: TGSellerType.private, verified: false, rating: 4.1),
  ];
  static final Set<String> _mockIds = {for (final s in mockSellers) s.id};

  bool get _mocksOn => !TGRevenueConfigService.instance.productionMode;

  void reset() {
    _config = const ReviewVerifiedConfig();
    _facts.clear();
    _overrides.clear();
    _state.clear();
    _mockReviews.clear();
    _seeded = false;
    _lastDailyRun = null;
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    if (!_listening) {
      _listening = true;
      DealService.instance.addListener(_onReviewsChanged);
      TGRevenueConfigService.instance.addListener(_onReviewsChanged);
    }
    _seed();
    evaluateAll(trigger: 'seed');
    _lastDailyRun = TGClock.now();
  }

  // ---- config ----

  void setConfig(ReviewVerifiedConfig next, {required String actorId, String actorRole = 'admin'}) {
    ensureSeeded();
    final before = _config.toJson();
    _config = next;
    ModerationService.instance.recordAdminAudit(
      actorId: actorId,
      actorRole: actorRole,
      summary: 'Review-verified config updated',
      details: {
        for (final e in next.toJson().entries)
          if ('${before[e.key]}' != '${e.value}') e.key: '${before[e.key]} → ${e.value}',
      },
    );
    evaluateAll(trigger: 'config');
  }

  // ---- facts ----

  void setFacts(String sellerId, TGIndividualSellerFacts facts) {
    ensureSeeded();
    _facts[sellerId] = facts;
    evaluate(sellerId, trigger: 'facts');
  }

  TGIndividualSellerFacts? factsFor(String sellerId) => _facts[sellerId];

  bool isIndividual(String sellerId) => _facts.containsKey(sellerId) && (_mocksOn || !_mockIds.contains(sellerId));

  // ---- reviews & stats ----

  /// `confirmed`, `confirmed_moderator` and `not_disputed` inside the window.
  List<TGPurchaseReview> countedReviews(String sellerId) {
    final from = DateTime(TGClock.now().year, TGClock.now().month - _config.windowMonths, TGClock.now().day);
    return [
      ...DealService.instance.reviewsForSeller(sellerId),
      if (_mocksOn) ...?_mockReviews[sellerId],
    ].where((r) => r.countsTowardRating && !r.createdAt.isBefore(from)).toList();
  }

  TGReviewStats statsFor(String sellerId) {
    final counted = countedReviews(sellerId);
    return TGReviewStats(
      counted: counted.length,
      negatives: counted.where((r) => r.rating <= _config.negativeStarsMax).length,
      distinctBuyers: counted.map((r) => r.authorId).toSet().length,
      computedAt: TGClock.now(),
    );
  }

  List<TGVerifiedRequirement> requirements(String sellerId) {
    final c = _config;
    final s = statsFor(sellerId);
    final f = _facts[sellerId] ?? const TGIndividualSellerFacts();
    final now = TGClock.now();
    final ageDays = f.accountCreatedAt == null ? 0 : now.difference(f.accountCreatedAt!).inDays;
    final upheld = f.lastUpheldReportAt;
    final pct = (c.maxNegativeShare * 100).round();
    return [
      TGVerifiedRequirement(id: 'counted', met: s.counted >= c.minCountedReviews, labelKey: 'ver_req_counted', params: {'n': '${c.minCountedReviews}', 'have': '${s.counted}', 'months': '${c.windowMonths}'}),
      TGVerifiedRequirement(id: 'distinct', met: s.distinctBuyers >= c.minDistinctBuyers, labelKey: 'ver_req_distinct', params: {'n': '${c.minDistinctBuyers}', 'have': '${s.distinctBuyers}'}),
      TGVerifiedRequirement(id: 'negatives', met: s.counted > 0 && s.negativeShare <= c.maxNegativeShare + 1e-9, labelKey: 'ver_req_negatives', params: {'pct': '$pct', 'stars': '${c.negativeStarsMax}', 'have': '${s.negativePercent}'}),
      TGVerifiedRequirement(id: 'account_age', met: ageDays >= c.minAccountAgeDays, labelKey: 'ver_req_account_age', params: {'n': '${c.minAccountAgeDays}', 'have': '$ageDays'}),
      if (c.requirePhoneVerified) TGVerifiedRequirement(id: 'phone', met: f.phoneVerified, labelKey: 'ver_req_phone'),
      TGVerifiedRequirement(
        id: 'no_upheld_report',
        met: upheld == null || now.difference(upheld).inDays >= c.blockedAfterUpheldReportDays,
        labelKey: 'ver_req_no_report',
        params: {'n': '${c.blockedAfterUpheldReportDays}'},
      ),
    ];
  }

  bool criteriaMet(String sellerId) => _config.appliesToIndividuals && requirements(sellerId).every((r) => r.met);

  // ---- state ----

  bool isVerified(String sellerId) {
    ensureSeeded();
    if (!isIndividual(sellerId)) return false;
    return _state[sellerId]?.verified ?? false;
  }

  DateTime? verifiedSince(String sellerId) => isVerified(sellerId) ? _state[sellerId]?.since : null;

  TGReviewStats? cachedStats(String sellerId) => _state[sellerId]?.stats;

  TGVerifiedOverride? overrideFor(String sellerId) => _overrides[sellerId];

  Iterable<String> get trackedSellerIds => _facts.keys.where(isIndividual);

  /// Runs the rule; removes or restores the shield immediately on change.
  void evaluate(String sellerId, {required String trigger, bool notify = true}) {
    if (!isIndividual(sellerId)) return;
    final stats = statsFor(sellerId);
    final ov = _overrides[sellerId];
    final next = ov?.verified ?? criteriaMet(sellerId);
    final prev = _state[sellerId];
    final was = prev?.verified ?? false;
    final since = next ? (was ? prev?.since : TGClock.now()) : null;
    _state[sellerId] = (verified: next, since: since, stats: stats);
    if (next && !was) {
      TGAnalytics.track('verified_earned', {'sellerId': sellerId, 'basis': TGVerifiedBasis.buyerReviews.wire, 'trigger': trigger, if (ov != null) 'override': true});
      _notifySeller(sellerId, 'verified_earned');
    } else if (!next && was) {
      final failed = ov != null ? 'admin_override' : requirements(sellerId).firstWhere((r) => !r.met, orElse: () => const TGVerifiedRequirement(id: 'disabled', met: false, labelKey: '')).id;
      TGAnalytics.track('verified_revoked', {'sellerId': sellerId, 'basis': TGVerifiedBasis.buyerReviews.wire, 'trigger': trigger, 'reason': failed});
      _notifySeller(sellerId, 'verified_revoked');
    }
    if (notify) _safe(notifyListeners);
  }

  void evaluateAll({required String trigger}) {
    for (final id in trackedSellerIds.toList()) {
      evaluate(id, trigger: trigger, notify: false);
    }
    _safe(notifyListeners);
  }

  /// The badge is read during build (which may seed); defer listener calls
  /// out of the build phase.
  static void _safe(VoidCallback fn) {
    SchedulerPhase phase;
    try {
      phase = SchedulerBinding.instance.schedulerPhase;
    } catch (_) {
      phase = SchedulerPhase.idle;
    }
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => fn());
    } else {
      fn();
    }
  }

  /// Daily job (also wired to the Dev clock).
  void onClockAdvanced() {
    ensureSeeded();
    final now = TGClock.now();
    final last = _lastDailyRun;
    if (last != null && now.difference(last).inHours < 24 && now.day == last.day) return;
    _lastDailyRun = now;
    evaluateAll(trigger: 'daily');
  }

  void _onReviewsChanged() {
    if (!_seeded) return;
    evaluateAll(trigger: 'review_change');
  }

  void _notifySeller(String sellerId, String type) {
    _safe(() => NotificationService.instance.add(
          userId: sellerId,
          type: type,
          dealId: '',
          title: type,
          body: '',
          deepLink: '/dashboard/verification',
        ));
  }

  // ---- admin override ----

  /// Forces the shield on/off (`verified`) or clears it (`null`). Reason is mandatory.
  void setOverride(String sellerId, {required bool? verified, required String reason, required String actorId, String actorRole = 'admin'}) {
    ensureSeeded();
    final why = reason.trim();
    if (why.isEmpty) throw ArgumentError.value(reason, 'reason', 'Override reason is required');
    if (verified == null) {
      _overrides.remove(sellerId);
    } else {
      _overrides[sellerId] = TGVerifiedOverride(sellerId: sellerId, verified: verified, reason: why, actorId: actorId, at: TGClock.now());
    }
    final action = verified == null ? 'cleared' : (verified ? 'grant' : 'revoke');
    ModerationService.instance.recordAdminAudit(
      actorId: actorId,
      actorRole: actorRole,
      summary: 'Verified override ($action) · $sellerId',
      reason: why,
      details: {'sellerId': sellerId, 'override': action},
    );
    TGAnalytics.track('verified_admin_override', {'sellerId': sellerId, 'action': action, 'actorId': actorId});
    evaluate(sellerId, trigger: 'admin_override');
  }

  /// A report against the seller was upheld (blocks the shield for N days).
  void recordUpheldReport(String sellerId) {
    final f = _facts[sellerId] ?? const TGIndividualSellerFacts();
    setFacts(sellerId, TGIndividualSellerFacts(accountCreatedAt: f.accountCreatedAt, phoneVerified: f.phoneVerified, lastUpheldReportAt: TGClock.now()));
  }

  /// Adds a counted/uncounted mock review and re-runs the rule (tests, Dev).
  void addMockReview(String sellerId, {required int rating, String? authorId, TGPurchaseReviewState state = TGPurchaseReviewState.confirmed}) {
    ensureSeeded();
    final list = _mockReviews.putIfAbsent(sellerId, () => []);
    list.add(_review(sellerId, list.length, rating: rating, authorId: authorId, state: state));
    evaluate(sellerId, trigger: 'review_change');
  }

  // ---- seed ----

  void _seed() {
    final now = TGClock.now();
    final old = now.subtract(const Duration(days: 400));
    for (final id in const ['seller_mateusz', 'seller_anna', 'seller_karol', 'seller_ewa', 'seller_agnieszka', 'seller_tg']) {
      _facts[id] = TGIndividualSellerFacts(accountCreatedAt: old, phoneVerified: true);
    }
    void mock(String id, List<int> ratings, {List<TGPurchaseReview> extra = const []}) {
      _facts[id] = TGIndividualSellerFacts(accountCreatedAt: now.subtract(const Duration(days: 240)), phoneVerified: true);
      _mockReviews[id] = [for (var i = 0; i < ratings.length; i++) _review(id, i, rating: ratings[i]), ...extra];
    }

    // 2 earned.
    mock('seller_ind_ola', [5, 5, 4, 5, 5, 4, 5, 5]);
    mock('seller_ind_bartek', [5, 5, 4, 5, 5, 4, 5, 5, 5, 4, 5, 5, 4, 2], extra: [
      _review('seller_ind_bartek', 90, rating: 1, state: TGPurchaseReviewState.suspendedObjection),
      _review('seller_ind_bartek', 91, rating: 1, state: TGPurchaseReviewState.removed),
    ]);
    // 2 borderline: exactly 10 % negatives; exactly the 5-review minimum.
    mock('seller_ind_kasia', [5, 4, 5, 5, 4, 5, 5, 4, 5, 1]);
    mock('seller_ind_tomek', [5, 5, 5, 4, 5], extra: [
      _review('seller_ind_tomek', 90, rating: 5, state: TGPurchaseReviewState.awaitingSeller),
      _review('seller_ind_tomek', 91, rating: 5, ageDays: 500),
    ]);
    // 1 lost the shield: was verified, negatives rose to 17 %.
    mock('seller_ind_marta', [5, 4, 5, 5, 4, 5, 4, 5, 5, 4, 2, 1]);
    _state['seller_ind_marta'] = (
      verified: true,
      since: now.subtract(const Duration(days: 120)),
      stats: TGReviewStats(counted: 10, negatives: 0, distinctBuyers: 10, computedAt: now.subtract(const Duration(days: 1))),
    );
  }

  TGPurchaseReview _review(String sellerId, int i, {required int rating, String? authorId, TGPurchaseReviewState state = TGPurchaseReviewState.confirmed, int? ageDays}) {
    final at = TGClock.now().subtract(Duration(days: ageDays ?? (5 + i * 9)));
    return TGPurchaseReview(
      id: 'R-VER-$sellerId-$i',
      sellerId: sellerId,
      authorId: authorId ?? 'buyer_ver_${sellerId}_$i',
      authorName: 'Buyer ${i + 1}',
      dealId: 'D-VER-$sellerId-$i',
      listingNo: '0000000$i',
      listingTitleSnapshot: 'Mock listing',
      dealType: TGDealType.sale,
      dealMonth: DateTime(at.year, at.month),
      rating: rating,
      text: '',
      state: state,
      createdAt: at,
    );
  }
}
