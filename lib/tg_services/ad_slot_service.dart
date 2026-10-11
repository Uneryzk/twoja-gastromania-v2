import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart' show TGStorePlanKind;
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class AdSlotService extends ChangeNotifier {
  AdSlotService._();
  static final AdSlotService instance = AdSlotService._();

  final List<TGAdSlot> slots = [];
  final Map<String, _AdUndo> _undos = {};
  final Map<String, int> _enterpriseUsedThisMonth = {};
  bool _seeded = false;
  int _seq = 1;

  bool get purchaseVisible {
    final cfg = TGRevenueConfigService.instance.config;
    return cfg.flags.bannerAds && cfg.phase >= 2;
  }

  int get pricePln => TGRevenueConfigService.instance.config.bannerAds.adSlotPln14;
  int get maxLive => TGRevenueConfigService.instance.config.bannerAds.maxLiveHeroSlides;

  void reset() {
    slots.clear();
    _undos.clear();
    _enterpriseUsedThisMonth.clear();
    _seeded = false;
    _seq = 1;
    notifyListeners();
  }

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    final now = TGClock.now();
    slots.addAll([
      TGAdSlot(
        id: 'ad_live_1',
        ownerId: 'seller_tg',
        kind: TGAdSlotKind.restaurantListing,
        targetUrl: '/restaurants/51010001-restaurant-with-terrace-mariacka-katowice',
        title: 'Restaurant with terrace – Katowice',
        imageUrl: TGListingImages.heroSlide(0),
        startsAt: now.subtract(const Duration(days: 2)),
        endsAt: now.add(const Duration(days: 12)),
        status: TGAdSlotStatus.live,
        impressions: 1840,
        clicks: 62,
        pricePln: pricePln,
        isMock: true,
      ),
      TGAdSlot(
        id: 'ad_pending_1',
        ownerId: 'seller_gastropl',
        kind: TGAdSlotKind.store,
        targetUrl: '/seller/1847-gastrosilesia',
        title: 'GastroPL Outlet – kitchen equipment',
        imageUrl: TGListingImages.heroSlide(1),
        startsAt: now,
        endsAt: now.add(const Duration(days: 14)),
        status: TGAdSlotStatus.pendingReview,
        pricePln: pricePln,
        isMock: true,
      ),
    ]);
  }

  List<TGAdSlot> get pendingReview =>
      slots.where((s) => s.status == TGAdSlotStatus.pendingReview && _visible(s)).toList();

  List<TGAdSlot> get liveSlides {
    ensureSeeded();
    final now = TGClock.now();
    final live = slots
        .where(
          (s) =>
              _visible(s) &&
              s.status == TGAdSlotStatus.live &&
              !now.isBefore(s.startsAt) &&
              now.isBefore(s.endsAt),
        )
        .toList();
    live.sort((a, b) => a.id.compareTo(b.id));
    // Fair rotation seed from clock day.
    live.shuffle(Random(now.day * 31 + now.month));
    return live.take(maxLive).toList(growable: false);
  }

  bool _visible(TGAdSlot s) {
    if (TGRevenueConfigService.instance.productionMode && s.isMock) return false;
    return true;
  }

  List<TGAdSlot> ownedBy(String ownerId) {
    ensureSeeded();
    return slots.where((s) => s.ownerId == ownerId && _visible(s)).toList();
  }

  bool canUseEnterpriseEntitlement(String ownerId) {
    final p = TGSellerProfileService.instance.bySellerKey(ownerId);
    if (p?.plan != TGStorePlanKind.enterprise) return false;
    final key = _monthKey(ownerId);
    final used = _enterpriseUsedThisMonth[key] ?? 0;
    return used < TGRevenueConfigService.instance.config.bannerAds.enterpriseIncludedSlidesPerMonth;
  }

  int enterpriseRemaining(String ownerId) {
    if (!canUseEnterpriseEntitlement(ownerId) &&
        TGSellerProfileService.instance.bySellerKey(ownerId)?.plan != TGStorePlanKind.enterprise) {
      return 0;
    }
    final cap = TGRevenueConfigService.instance.config.bannerAds.enterpriseIncludedSlidesPerMonth;
    final used = _enterpriseUsedThisMonth[_monthKey(ownerId)] ?? 0;
    return (cap - used).clamp(0, cap);
  }

  String _monthKey(String ownerId) {
    final n = TGClock.now();
    return '$ownerId-${n.year}-${n.month}';
  }

  /// Platform-internal paths only.
  static String? validateTargetUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Target URL is required';
    if (t.startsWith('http://') || t.startsWith('https://')) {
      if (!t.contains('twojagastromania.pl')) return 'Platform-internal links only';
    }
    if (!t.startsWith('/')) return 'Use an internal path starting with /';
    return null;
  }

  TGAdSlot purchaseAndSubmit({
    required String ownerId,
    required TGAdSlotKind kind,
    required String targetUrl,
    required String title,
    required String imageUrl,
    required DateTime startsAt,
    bool useEnterpriseEntitlement = false,
  }) {
    if (!purchaseVisible) throw StateError('Banner ads unavailable');
    final err = validateTargetUrl(targetUrl);
    if (err != null) throw StateError(err);
    if (title.trim().isEmpty || title.trim().length > 60) throw StateError('Title must be 1–60 characters');
    final entitlement = useEnterpriseEntitlement && canUseEnterpriseEntitlement(ownerId);
    final price = entitlement ? 0 : pricePln;
    if (entitlement) {
      final key = _monthKey(ownerId);
      _enterpriseUsedThisMonth[key] = (_enterpriseUsedThisMonth[key] ?? 0) + 1;
    }
    final slot = TGAdSlot(
      id: 'ad_${_seq++}_${TGClock.now().millisecondsSinceEpoch}',
      ownerId: ownerId,
      kind: kind,
      targetUrl: targetUrl.trim(),
      title: title.trim(),
      imageUrl: imageUrl,
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(days: 14)),
      status: TGAdSlotStatus.pendingReview,
      pricePln: price,
      enterpriseEntitlement: entitlement,
    );
    slots.insert(0, slot);
    TGAnalytics.track('ad_purchase', {
      'id': slot.id,
      'price': price,
      'entitlement': entitlement,
      'kind': kind.name,
    });
    notifyListeners();
    return slot;
  }

  String? approve(String id, {required String actorId, required String actorRole}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.status != TGAdSlotStatus.pendingReview && prev.status != TGAdSlotStatus.approved) {
      return 'Not pending';
    }
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    final now = TGClock.now();
    final liveCount = liveSlides.length;
    final nextStatus = liveCount >= maxLive ? TGAdSlotStatus.approved : TGAdSlotStatus.live;
    slots[i] = prev.copyWith(
      status: nextStatus,
      startsAt: now.isAfter(prev.startsAt) ? now : prev.startsAt,
      clearReject: true,
    );
    _audit(actorId, actorRole, id, 'Approved ad ${prev.title}');
    TGAnalytics.track('ad_content_decision', {'id': id, 'decision': 'approve', 'status': nextStatus.name});
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_approved',
      dealId: id,
      title: 'Banner ad approved',
      body: nextStatus == TGAdSlotStatus.live
          ? 'Your banner is live on the homepage.'
          : 'Approved. It will go live when a hero slot is free.',
      deepLink: '/dashboard/advertising',
    );
    notifyListeners();
    return null;
  }

  String? reject(String id, {required String actorId, required String actorRole, required String reason}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    slots[i] = prev.copyWith(status: TGAdSlotStatus.rejected, rejectReason: reason, refundPln: prev.pricePln);
    _audit(actorId, actorRole, id, 'Rejected ad · refund ${prev.pricePln} PLN', reason: reason);
    TGAnalytics.track('ad_content_decision', {'id': id, 'decision': 'reject'});
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_rejected',
      dealId: id,
      title: 'Banner ad not published',
      body: prev.pricePln > 0
          ? 'Your content was not approved. A full refund of ${prev.pricePln} PLN was issued.'
          : 'Your content was not approved. Your Enterprise entitlement was restored.',
      deepLink: '/dashboard/advertising',
    );
    if (prev.enterpriseEntitlement) {
      final key = _monthKey(prev.ownerId);
      _enterpriseUsedThisMonth[key] = ((_enterpriseUsedThisMonth[key] ?? 1) - 1).clamp(0, 99);
    }
    notifyListeners();
    return null;
  }

  bool undo(String id) {
    final u = _undos.remove(id);
    if (u == null || !u.until.isAfter(DateTime.now())) return false;
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) {
      slots.insert(0, u.snapshot);
    } else {
      slots[i] = u.snapshot;
    }
    notifyListeners();
    return true;
  }

  String? terminateEarly(String id, {required String actorId, required String actorRole, required String reason}) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return 'Not found';
    final prev = slots[i];
    if (prev.status != TGAdSlotStatus.live && prev.status != TGAdSlotStatus.approved) return 'Not live';
    final now = TGClock.now();
    final total = prev.endsAt.difference(prev.startsAt).inDays.clamp(1, 14);
    final left = prev.endsAt.difference(now).inDays.clamp(0, total);
    final refund = prev.pricePln <= 0 ? 0 : ((prev.pricePln * left) / total).round();
    _undos[id] = _AdUndo(snapshot: prev, until: DateTime.now().add(const Duration(seconds: 10)));
    slots[i] = prev.copyWith(
      status: TGAdSlotStatus.ended,
      endsAt: now,
      endedEarlyReason: reason,
      refundPln: refund,
    );
    _audit(actorId, actorRole, id, 'Early termination · prorated refund $refund PLN', reason: reason);
    NotificationService.instance.add(
      userId: prev.ownerId,
      type: 'ad_ended_early',
      dealId: id,
      title: 'Banner ad ended',
      body: refund > 0 ? 'Prorated refund: $refund PLN.' : 'Your banner was ended by moderation.',
      deepLink: '/dashboard/advertising',
    );
    notifyListeners();
    return null;
  }

  void recordImpression(String id) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    slots[i] = slots[i].copyWith(impressions: slots[i].impressions + 1);
    // soft notify — no notifyListeners flood
  }

  void recordClick(String id) {
    final i = slots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    slots[i] = slots[i].copyWith(clicks: slots[i].clicks + 1);
    notifyListeners();
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    var changed = false;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if ((s.status == TGAdSlotStatus.live || s.status == TGAdSlotStatus.approved) && !s.endsAt.isAfter(now)) {
        slots[i] = s.copyWith(status: TGAdSlotStatus.ended);
        changed = true;
        NotificationService.instance.add(
          userId: s.ownerId,
          type: 'ad_impression_report',
          dealId: s.id,
          title: 'Banner ad ended · report',
          body: '${s.impressions} impressions · ${s.clicks} clicks. Reach depends on homepage traffic.',
          deepLink: '/dashboard/advertising',
        );
        TGAnalytics.track('ad_impression_report', {
          'id': s.id,
          'impressions': s.impressions,
          'clicks': s.clicks,
        });
      }
      // Promote approved → live when capacity frees.
      if (s.status == TGAdSlotStatus.approved && liveSlides.length < maxLive && !now.isBefore(s.startsAt)) {
        slots[i] = s.copyWith(status: TGAdSlotStatus.live);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  List<({TGAdSlot a, TGAdSlot b})> slotConflicts() {
    ensureSeeded();
    final live = slots.where((s) => s.status == TGAdSlotStatus.live || s.status == TGAdSlotStatus.approved).toList();
    final out = <({TGAdSlot a, TGAdSlot b})>[];
    for (var i = 0; i < live.length; i++) {
      for (var j = i + 1; j < live.length; j++) {
        final a = live[i];
        final b = live[j];
        if (a.startsAt.isBefore(b.endsAt) && b.startsAt.isBefore(a.endsAt)) {
          out.add((a: a, b: b));
        }
      }
    }
    return out;
  }

  void _audit(String actorId, String actorRole, String id, String summary, {String? reason}) {
    ModerationService.instance.recordRestoDescriptionAudit(
      listingNo: id,
      actorId: actorId,
      actorRole: actorRole,
      summary: summary,
      reason: reason,
    );
  }
}

class _AdUndo {
  _AdUndo({required this.snapshot, required this.until});
  final TGAdSlot snapshot;
  final DateTime until;
}
