import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Free-start eligibility + day-30 extension + renew/promote + lifecycle ticks.
class RestaurantLifecycleService extends ChangeNotifier {
  RestaurantLifecycleService._();
  static final RestaurantLifecycleService instance = RestaurantLifecycleService._();

  RestaurantConfig get cfg => RestaurantConfigService.instance.config;

  final Map<String, DateTime> _freeStartByPremisesPhone = {};
  final Map<String, List<DateTime>> _freeStartsByOwner = {};
  final Map<String, Set<String>> _notified = {};

  int freeStartsIn12m(String ownerId) {
    final now = TGClock.now();
    final cutoff = now.subtract(const Duration(days: 365));
    final list = (_freeStartsByOwner[ownerId] ?? const []).where((d) => d.isAfter(cutoff)).toList();
    _freeStartsByOwner[ownerId] = list;
    return list.length;
  }

  bool freeStartUsedForPremises({required String premisesKey, required String phone}) {
    return _freeStartByPremisesPhone.containsKey('$premisesKey|${_normPhone(phone)}');
  }

  bool canUseFreeStart({
    required String ownerId,
    required String premisesKey,
    required String phone,
  }) {
    if (freeStartUsedForPremises(premisesKey: premisesKey, phone: phone)) return false;
    if (freeStartsIn12m(ownerId) >= cfg.freeStartCapPer12m) return false;
    return true;
  }

  String freeStartBlockReason({
    required String ownerId,
    required String premisesKey,
    required String phone,
  }) {
    if (freeStartUsedForPremises(premisesKey: premisesKey, phone: phone)) {
      return 'The free start was already used for these premises.';
    }
    if (freeStartsIn12m(ownerId) >= cfg.freeStartCapPer12m) {
      return 'Free start limit reached for this account (max ${cfg.freeStartCapPer12m} / 12 months).';
    }
    return 'Paid listing applies.';
  }

  void _consumeFreeStart({required String ownerId, required String premisesKey, required String phone}) {
    final now = TGClock.now();
    _freeStartByPremisesPhone['$premisesKey|${_normPhone(phone)}'] = now;
    _freeStartsByOwner.putIfAbsent(ownerId, () => []).add(now);
  }

  String _normPhone(String p) => p.replaceAll(RegExp(r'\D'), '');

  PremisesGateResult checkPremisesGate({
    required String ownerId,
    required String premisesKey,
    String? excludeId,
  }) {
    final all = RestaurantService.instance.all;
    final sameAccount = all.where(
      (r) =>
          r.id != excludeId &&
          r.ownerId == ownerId &&
          r.premisesKey == premisesKey &&
          (r.status == RestaurantListingStatus.active ||
              r.status == RestaurantListingStatus.pendingAuthorization ||
              r.status == RestaurantListingStatus.paymentPending ||
              r.status == RestaurantListingStatus.underReview),
    );
    if (sameAccount.isNotEmpty) {
      return PremisesGateResult.blockSameAccount(sameAccount.first);
    }
    final otherActive = all.where(
      (r) =>
          r.id != excludeId &&
          r.ownerId != ownerId &&
          r.premisesKey == premisesKey &&
          r.status == RestaurantListingStatus.active &&
          !r.isHidden,
    );
    if (otherActive.isNotEmpty) {
      return PremisesGateResult.pendingAuthorization(otherActive.first);
    }
    return PremisesGateResult.ok();
  }

  int publishedToday(String ownerId) {
    final now = TGClock.now();
    final day = DateTime(now.year, now.month, now.day);
    return RestaurantService.instance.ownedBy(ownerId).where((r) {
      final p = r.publishedAt;
      if (p == null) return false;
      return !p.isBefore(day) && r.status != RestaurantListingStatus.draft && r.status != RestaurantListingStatus.paymentPending;
    }).length;
  }

  bool underDailyCap(String ownerId) => publishedToday(ownerId) < cfg.dailyListingCap;

  RestaurantListing activate({
    required RestaurantListing listing,
    required bool useFreeIntro,
    int promoteDays = 0,
    bool pendingAuthorization = false,
  }) {
    final now = TGClock.now();
    final no = TGListingNo.isListingNo(listing.listingNo) ? listing.listingNo : TGListingNo.allocate();

    if (pendingAuthorization) {
      final next = listing.copyWith(
        listingNo: no,
        status: RestaurantListingStatus.pendingAuthorization,
        isHidden: true,
        publishedAt: now,
      );
      RestaurantService.instance.replace(next);
      TGAnalytics.track('resto_publish', {'mode': 'pending_authorization', 'listingNo': no});
      TGAnalytics.track('resto_premises_conflict', {'listingNo': no, 'result': 'pending_authorization'});
      notifyListeners();
      return next;
    }

    final source = useFreeIntro ? RestaurantListingSource.freeIntro : RestaurantListingSource.paid;
    final days = useFreeIntro ? cfg.freeDays : cfg.paidDays;
    if (useFreeIntro) {
      _consumeFreeStart(ownerId: listing.ownerId, premisesKey: listing.premisesKey, phone: listing.phone);
    }

    final next = listing.copyWith(
      listingNo: no,
      status: RestaurantListingStatus.active,
      isHidden: false,
      publishedAt: now,
      expiresAt: now.add(Duration(days: days)),
      source: source,
      promotedUntil: promoteDays > 0 ? now.add(Duration(days: promoteDays)) : listing.promotedUntil,
    );
    RestaurantService.instance.replace(next);
    TGAnalytics.track('resto_publish', {
      'mode': useFreeIntro ? 'free_intro' : 'paid',
      'listingNo': no,
      'promoteDays': promoteDays,
    });
    if (promoteDays > 0) {
      TGAnalytics.track('resto_promote_selected', {'listingNo': no, 'days': promoteDays});
    }
    notifyListeners();
    return next;
  }

  RestaurantListing renew({
    required String listingId,
    int promoteDays = 0,
    bool early = false,
  }) {
    final cur = RestaurantService.instance.byId(listingId);
    if (cur == null) throw StateError('listing missing');
    final now = TGClock.now();
    final base = early && cur.expiresAt != null && cur.expiresAt!.isAfter(now) ? cur.expiresAt! : now;
    final next = cur.copyWith(
      status: RestaurantListingStatus.active,
      isHidden: false,
      expiresAt: base.add(Duration(days: cfg.paidDays)),
      source: RestaurantListingSource.paid,
      promotedUntil: promoteDays > 0 ? now.add(Duration(days: promoteDays)) : cur.promotedUntil,
    );
    RestaurantService.instance.replace(next);
    TGAnalytics.track('renew_success', {
      'listingNo': next.listingNo,
      'kind': 'restaurant',
      'early': early,
      'promoteDays': promoteDays,
    });
    notifyListeners();
    return next;
  }

  RestaurantListing? promoteOnly({required String listingId, required int promoteDays}) {
    final cur = RestaurantService.instance.byId(listingId);
    if (cur == null || promoteDays <= 0) return null;
    if (promoteDays > cur.daysUntilExpiry(TGClock.now())) return null;
    final next = cur.copyWith(promotedUntil: TGClock.now().add(Duration(days: promoteDays)));
    RestaurantService.instance.replace(next);
    TGAnalytics.track('resto_promote_selected', {'listingNo': next.listingNo, 'days': promoteDays, 'mode': 'standalone'});
    notifyListeners();
    return next;
  }

  bool canPromote(RestaurantListing r, int days) {
    if (r.status != RestaurantListingStatus.active) return false;
    return days <= r.daysUntilExpiry(TGClock.now());
  }

  /// Renew when expired, ≤[renewEarlyDays] left, or free period from day 16.
  bool canOfferRenew(RestaurantListing r, [DateTime? now]) {
    final n = now ?? TGClock.now();
    if (r.status == RestaurantListingStatus.expired) return true;
    if (r.status != RestaurantListingStatus.active) return false;
    final daysLeft = r.daysUntilExpiry(n);
    if (daysLeft <= cfg.renewEarlyDays) return true;
    if (r.source == RestaurantListingSource.freeIntro && r.publishedAt != null) {
      return n.difference(r.publishedAt!).inDays >= 16;
    }
    return false;
  }

  bool isRenewEarly(RestaurantListing r, [DateTime? now]) {
    final n = now ?? TGClock.now();
    return r.status == RestaurantListingStatus.active && canOfferRenew(r, n);
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    for (final r in [...RestaurantService.instance.all]) {
      _tickListing(r, now);
    }
    notifyListeners();
  }

  void _tickListing(RestaurantListing r, DateTime now) {
    if (r.status == RestaurantListingStatus.active && r.expiresAt != null && !r.expiresAt!.isAfter(now)) {
      // Day-30 free extension runs before hard expiry when still on free_intro.
      if (r.source == RestaurantListingSource.freeIntro && !r.freeExtensionGranted) {
        final e = r.engagement;
        if (e.uniqueContacts == 0 && e.uniqueFavorites == 0) {
          final extended = r.copyWith(
            expiresAt: now.add(Duration(days: cfg.freeExtensionDays)),
            freeExtensionGranted: true,
          );
          RestaurantService.instance.replace(extended);
          TGAnalytics.track('resto_free_extension', {'listingNo': r.listingNo});
          _notifyExtension(extended);
          return;
        }
      }
      RestaurantService.instance.replace(r.copyWith(status: RestaurantListingStatus.expired));
      _notify(r, 'expired', 'Expired. Renew for ${cfg.paidPricePln} PLN', 'Your restaurant listing has expired.', deep: true);
      return;
    }

    if (r.status == RestaurantListingStatus.expired && r.expiresAt != null) {
      final since = now.difference(r.expiresAt!).inDays;
      if (since == 7) {
        _notify(r, 'still_selling', 'Still selling?', 'Renew your restaurant listing for ${cfg.paidPricePln} PLN.', deep: true);
      }
      return;
    }

    if (r.status != RestaurantListingStatus.active || r.publishedAt == null) return;

    final ageDays = now.difference(r.publishedAt!).inDays;
    final daysLeft = r.daysUntilExpiry(now);

    if (r.source == RestaurantListingSource.freeIntro) {
      if (ageDays == 10 || ageDays == 20) {
        _notify(
          r,
          'perf_$ageDays',
          'Listing performance · day $ageDays',
          '${r.engagement.views} views, ${r.engagement.uniqueContacts} contacts, ${r.engagement.uniqueFavorites} favorites',
          deep: true,
        );
      }
      // Day 23 / 27 / 29 of the free period (N days left).
      if (ageDays == 23 || ageDays == 27 || ageDays == 29) {
        final nLeft = (cfg.freeDays - ageDays).clamp(1, cfg.freeDays);
        _notify(
          r,
          'ends_day_$ageDays',
          'Your free period ends in $nLeft days',
          'Check performance and renew options.',
          deep: true,
        );
      }
      if (ageDays == 30 && daysLeft >= 0) {
        _notify(
          r,
          'decision_30',
          'Day 30 decision',
          'Your free period ends today. Renew for ${cfg.paidPricePln} PLN / ${cfg.paidDays} days, or wait for the automatic extension check.',
          deep: true,
        );
      }
    } else if (r.source == RestaurantListingSource.paid) {
      for (final d in [14, 7, 3, 1]) {
        if (daysLeft == d) {
          _notify(
            r,
            'paid_ends_$d',
            'Listing ends in $d days',
            'Renew for ${cfg.paidPricePln} PLN / ${cfg.paidDays} days.',
            deep: true,
          );
        }
      }
      if (ageDays == 30 || ageDays == 60) {
        _notify(
          r,
          'paid_perf_$ageDays',
          'Listing summary · day $ageDays',
          '${r.engagement.views} views, ${r.engagement.uniqueContacts} contacts, ${r.engagement.uniqueFavorites} favorites',
          deep: true,
        );
      }
    }
  }

  void _notifyExtension(RestaurantListing r) {
    final e = r.engagement;
    final lowViews = e.views < cfg.lowViewsHint;
    final tips = lowViews
        ? 'Suggestions: 1) Promote (+${cfg.promote.pln14} / +${cfg.promote.pln30} PLN, one tap). 2) Add photos and additional information.'
        : 'Suggestions: 1) Review the price, transfer fee and photos. 2) Fill in additional information. 3) Promote.';
    final median = _medianSimilarRentHint(r);
    _notify(
      r,
      'extension',
      'We\'ve added ${cfg.freeExtensionDays} more free days.',
      '${e.views} views, ${e.uniqueContacts} contacts, ${e.uniqueFavorites} favorites in ${cfg.freeDays} days. $tips$median '
      'Advisory only — the platform makes no valuation and promises no result.',
      deep: true,
    );
  }

  String _medianSimilarRentHint(RestaurantListing r) {
    final peers = RestaurantService.instance.all
        .where(
          (x) =>
              x.id != r.id &&
              x.status == RestaurantListingStatus.active &&
              !x.isHidden &&
              x.businessType == r.businessType &&
              x.city.toLowerCase() == r.city.toLowerCase(),
        )
        .map((x) => x.rentMonthly)
        .toList()
      ..sort();
    if (peers.length < 5) return '';
    final median = peers[peers.length ~/ 2];
    return ' Median rent of similar listings: $median PLN/mo.';
  }

  void _notify(RestaurantListing r, String key, String title, String body, {bool deep = false}) {
    final seen = _notified.putIfAbsent(r.id, () => {});
    if (!seen.add(key)) return;
    NotificationService.instance.add(
      userId: r.ownerId,
      type: 'resto_$key',
      dealId: r.id,
      title: title,
      body: body,
      deepLink: deep ? '/dashboard/listings?renew=${r.id}' : r.detailPath,
    );
  }

  void compensateHiddenDays(String listingId, int days) {
    if (days <= 0) return;
    final cur = RestaurantService.instance.byId(listingId);
    if (cur?.expiresAt == null) return;
    RestaurantService.instance.replace(cur!.copyWith(expiresAt: cur.expiresAt!.add(Duration(days: days))));
  }

  int renewPlusPromoteTotal(int promoteDays) {
    if (promoteDays == 14) return cfg.paidPricePln + cfg.promote.pln14;
    if (promoteDays == 30) return cfg.paidPricePln + cfg.promote.pln30;
    return cfg.paidPricePln;
  }

  RestaurantRevenueStats revenueStats() {
    final all = RestaurantService.instance.all;
    final freeStarts = _freeStartsByOwner.values.fold<int>(0, (a, b) => a + b.length);
    final extensions = all.where((r) => r.freeExtensionGranted).length;
    final paidAfterFree = all.where((r) => r.source == RestaurantListingSource.paid && r.freeExtensionGranted).length;
    final paidListings =
        all.where((r) => r.source == RestaurantListingSource.paid && r.status != RestaurantListingStatus.draft).length;
    final renews = paidListings;
    final conversion = freeStarts == 0 ? 0.0 : paidAfterFree / freeStarts;
    return RestaurantRevenueStats(
      listingRevenuePln: paidListings * cfg.paidPricePln,
      renewCount: renews,
      freeStartCount: freeStarts,
      extensionCount: extensions,
      freeToPaidConversion: conversion,
    );
  }

  void reset() {
    _freeStartByPremisesPhone.clear();
    _freeStartsByOwner.clear();
    _notified.clear();
    final r001 = RestaurantService.instance.byId('r001');
    if (r001 != null) {
      _consumeFreeStart(ownerId: r001.ownerId, premisesKey: r001.premisesKey, phone: r001.phone);
    }
    notifyListeners();
  }

  void ensureSeeded() {
    if (_freeStartsByOwner.isNotEmpty || _freeStartByPremisesPhone.isNotEmpty) return;
    reset();
  }

  /// Mark free start as used for a mock owner scenario.
  void markFreeStartUsed({required String ownerId, required String premisesKey, required String phone}) {
    _consumeFreeStart(ownerId: ownerId, premisesKey: premisesKey, phone: phone);
    notifyListeners();
  }
}

class PremisesGateResult {
  PremisesGateResult._({required this.ok, this.blockListing, this.pendingAgainst});
  factory PremisesGateResult.ok() => PremisesGateResult._(ok: true);
  factory PremisesGateResult.blockSameAccount(RestaurantListing existing) =>
      PremisesGateResult._(ok: false, blockListing: existing);
  factory PremisesGateResult.pendingAuthorization(RestaurantListing existing) =>
      PremisesGateResult._(ok: true, pendingAgainst: existing);

  final bool ok;
  final RestaurantListing? blockListing;
  final RestaurantListing? pendingAgainst;

  bool get requiresPendingAuth => pendingAgainst != null;
  bool get isBlocked => blockListing != null;
}

@immutable
class RestaurantRevenueStats {
  const RestaurantRevenueStats({
    required this.listingRevenuePln,
    required this.renewCount,
    required this.freeStartCount,
    required this.extensionCount,
    required this.freeToPaidConversion,
  });
  final int listingRevenuePln;
  final int renewCount;
  final int freeStartCount;
  final int extensionCount;
  final double freeToPaidConversion;
}

class RestaurantAdminActions {
  static final Map<String, _RestoAuthUndo> _undos = {};

  static String? approveAuthorization(String listingNo, {required String actorId}) {
    final svc = RestaurantService.instance;
    final r = svc.byListingNo(listingNo);
    if (r == null) return 'Listing not found';
    final cfg = RestaurantConfigService.instance.config;
    final live = svc.all
        .where((x) => x.premisesKey == r.premisesKey && x.status == RestaurantListingStatus.active && !x.isHidden)
        .length;
    if (live >= cfg.perPremisesMax) {
      TGAnalytics.track('resto_admin_action', {'type': 'approve_blocked_cap', 'listingNo': listingNo});
      return 'Premises already at max live listings (${cfg.perPremisesMax}).';
    }
    _undos[listingNo] = _RestoAuthUndo(snapshot: r, until: DateTime.now().add(const Duration(seconds: 10)));
    final life = RestaurantLifecycleService.instance;
    final useFree = life.canUseFreeStart(ownerId: r.ownerId, premisesKey: r.premisesKey, phone: r.phone);
    life.activate(listing: r, useFreeIntro: useFree);
    TGAnalytics.track('resto_admin_action', {'type': 'approve', 'listingNo': listingNo, 'actor': actorId});
    return null;
  }

  static void rejectAuthorization(String listingNo, {required String actorId}) {
    final r = RestaurantService.instance.byListingNo(listingNo);
    if (r == null) return;
    _undos[listingNo] = _RestoAuthUndo(snapshot: r, until: DateTime.now().add(const Duration(seconds: 10)));
    RestaurantService.instance.replace(r.copyWith(status: RestaurantListingStatus.removed));
    TGAnalytics.track('resto_admin_action', {'type': 'reject', 'listingNo': listingNo, 'actor': actorId});
  }

  static bool canUndo(String listingNo) {
    final u = _undos[listingNo];
    return u != null && u.until.isAfter(DateTime.now());
  }

  static bool undo(String listingNo, {required String actorId}) {
    final u = _undos.remove(listingNo);
    if (u == null || !u.until.isAfter(DateTime.now())) return false;
    RestaurantService.instance.replace(u.snapshot);
    TGAnalytics.track('resto_admin_action', {'type': 'undo', 'listingNo': listingNo, 'actor': actorId});
    return true;
  }
}

class _RestoAuthUndo {
  _RestoAuthUndo({required this.snapshot, required this.until});
  final RestaurantListing snapshot;
  final DateTime until;
}
