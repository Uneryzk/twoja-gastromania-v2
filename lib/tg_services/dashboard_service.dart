import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

enum ActionPriority { critical, high, medium, low }

enum ActionItemType {
  moderatorInfo,
  sendEvidence,
  paymentPending,
  confirmPurchase,
  sellerDealCheck,
  specialConsent,
  quotesReceived,
  listingExpired,
  listingExpiring,
  listingUnderReview,
  unreadMessages,
  subscriptionPastDue,
  promotionEnding,
}

/// One thing the account owner should do, with a deep link that keeps the
/// existing query contracts (`?renew=`, `?filter=`, `?confirm=1`, `?evidence=1`).
@immutable
class ActionItem {
  const ActionItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.titleKey,
    required this.route,
    this.params = const {},
    this.dueAt,
    this.dismissible = false,
  });

  final String id;
  final ActionItemType type;
  final ActionPriority priority;
  final String titleKey;
  final Map<String, String> params;
  final DateTime? dueAt;
  final String route;

  /// Suggestions (not obligations) can be closed by the owner.
  final bool dismissible;

  String get ctaKey => switch (type) {
        ActionItemType.moderatorInfo => 'dash_cta_reply',
        ActionItemType.sendEvidence => 'dash_cta_evidence',
        ActionItemType.paymentPending || ActionItemType.subscriptionPastDue => 'dash_cta_pay',
        ActionItemType.confirmPurchase || ActionItemType.sellerDealCheck || ActionItemType.specialConsent => 'dash_cta_confirm',
        ActionItemType.listingExpired || ActionItemType.listingExpiring => 'dash_cta_renew',
        ActionItemType.quotesReceived || ActionItemType.listingUnderReview || ActionItemType.unreadMessages => 'dash_cta_open',
        ActionItemType.promotionEnding => 'ui_promo_extend',
      };

  /// Priority first, then the earliest deadline (items without one last).
  static int compare(ActionItem a, ActionItem b) {
    final p = a.priority.index.compareTo(b.priority.index);
    if (p != 0) return p;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad != null && bd != null) {
      final d = ad.compareTo(bd);
      if (d != 0) return d;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }
}

enum DashKpiKind { views, contacts, favorites, deals }

@immutable
class DashKpi {
  const DashKpi(this.kind, this.value);

  final DashKpiKind kind;

  /// `null` → not enough data for this period.
  final int? value;

  bool get enoughData => value != null;
}

@immutable
class DashListingsSnapshot {
  const DashListingsSnapshot({
    this.active = 0,
    this.expiring = 0,
    this.expired = 0,
    this.review = 0,
    this.drafts = 0,
  });

  final int active;
  final int expiring;
  final int expired;
  final int review;
  final int drafts;

  int get total => active + expired + review + drafts;
}

@immutable
class DashCharge {
  const DashCharge({required this.labelKey, required this.amountPln, required this.dueAt, this.params = const {}});

  final String labelKey;
  final Map<String, String> params;
  final int amountPln;
  final DateTime dueAt;
}

/// Per-account record of closed suggestion cards (only [ActionItem.dismissible]).
class ActionDismissals extends ChangeNotifier {
  ActionDismissals._();
  static final ActionDismissals instance = ActionDismissals._();

  final Set<String> _closed = {};

  bool isDismissed(String userId, String itemId) => _closed.contains('$userId|$itemId');

  void dismiss(String userId, ActionItem item) {
    if (!item.dismissible || !_closed.add('$userId|${item.id}')) return;
    notifyListeners();
  }

  void reset() => _closed.clear();
}

/// Read-only dashboard derivations. Never notifies, so it is safe in build().
abstract final class TGDashboard {
  static const List<int> kpiPeriods = [7, 30, 90];
  static const int defaultKpiPeriod = 30;

  /// A live promotion surfaces a "ends in N days" suggestion this close to its end.
  static const int promoEndingNoticeDays = 2;

  static bool get _mocksOff => TGRevenueConfigService.instance.productionMode;

  static List<ActionItem> actionItems(FakeAuthState auth, {DateTime? now}) {
    if (!auth.isLoggedIn || _mocksOff) return const [];
    final at = now ?? TGClock.now();
    final id = auth.userId;
    final items = <ActionItem>[];
    final mod = ModerationService.instance;

    for (final p in auth.ownedListings) {
      final params = {'title': p.title};
      switch (p.status) {
        case TGListingStatus.underReview:
          final no = p.listingNo ?? '';
          final waiting = mod.infoDueAt.containsKey(no) || mod.cases[no]?.status == TGReportStatus.waitingSeller;
          items.add(ActionItem(
            id: '${waiting ? 'mod' : 'review'}-${p.id}',
            type: waiting ? ActionItemType.moderatorInfo : ActionItemType.listingUnderReview,
            priority: waiting ? ActionPriority.critical : ActionPriority.medium,
            titleKey: waiting ? 'dash_ai_mod_info' : 'dash_ai_review',
            params: params,
            dueAt: waiting ? (mod.infoDueAt[no] ?? mod.cases[no]?.slaDeadline) : null,
            route: '/dashboard/listings?filter=review',
          ));
        case TGListingStatus.expired:
          items.add(ActionItem(
            id: 'expired-${p.id}',
            type: ActionItemType.listingExpired,
            priority: ActionPriority.medium,
            titleKey: 'dash_ai_expired',
            params: params,
            dueAt: p.expiresAt,
            route: '/dashboard/listings?renew=${p.id}',
          ));
        case TGListingStatus.paymentPending:
          items.add(ActionItem(
            id: 'pay-${p.id}',
            type: ActionItemType.paymentPending,
            priority: ActionPriority.high,
            titleKey: 'dash_ai_payment',
            params: params,
            route: '/add-product/checkout',
          ));
        default:
          if (p.isExpiringSoon) {
            final d = p.daysUntilExpiry(at);
            items.add(ActionItem(
              id: 'expiring-${p.id}',
              type: ActionItemType.listingExpiring,
              priority: d <= 2 ? ActionPriority.high : ActionPriority.medium,
              titleKey: 'dash_ai_expiring',
              params: {...params, 'n': '$d'},
              dueAt: p.expiresAt,
              route: '/dashboard/listings?renew=${p.id}',
            ));
          }
      }
    }
    if (auth.checkoutCart != null && !items.any((i) => i.type == ActionItemType.paymentPending)) {
      items.add(const ActionItem(
        id: 'pay-cart',
        type: ActionItemType.paymentPending,
        priority: ActionPriority.high,
        titleKey: 'dash_ai_payment_cart',
        route: '/add-product/checkout',
      ));
    }

    for (final r in RestaurantService.instance.ownedBy(id)) {
      final params = {'title': r.title};
      switch (r.status) {
        case RestaurantListingStatus.expired:
          items.add(ActionItem(
            id: 'expired-${r.id}',
            type: ActionItemType.listingExpired,
            priority: ActionPriority.medium,
            titleKey: 'dash_ai_expired',
            params: params,
            dueAt: r.expiresAt,
            route: '/dashboard/listings?renew=${r.id}',
          ));
        case RestaurantListingStatus.paymentPending:
          items.add(ActionItem(
            id: 'pay-${r.id}',
            type: ActionItemType.paymentPending,
            priority: ActionPriority.high,
            titleKey: 'dash_ai_payment',
            params: params,
            route: '/dashboard/listings?filter=drafts',
          ));
        case RestaurantListingStatus.underReview:
        case RestaurantListingStatus.pendingAuthorization:
          items.add(ActionItem(
            id: 'review-${r.id}',
            type: ActionItemType.listingUnderReview,
            priority: ActionPriority.medium,
            titleKey: 'dash_ai_review',
            params: params,
            route: '/dashboard/listings?filter=review',
          ));
        default:
          if (r.status == RestaurantListingStatus.active && r.isExpiringSoon(at)) {
            final d = r.daysUntilExpiry(at);
            items.add(ActionItem(
              id: 'expiring-${r.id}',
              type: ActionItemType.listingExpiring,
              priority: d <= 2 ? ActionPriority.high : ActionPriority.medium,
              titleKey: 'dash_ai_expiring',
              params: {...params, 'n': '$d'},
              dueAt: r.expiresAt,
              route: '/dashboard/listings?renew=${r.id}',
            ));
          }
      }
    }

    final deals = DealService.instance..ensureSeeded();
    for (final d in deals.forBuyer(id)) {
      if (d.waitingForBuyer) {
        items.add(ActionItem(
          id: 'confirm-${d.id}',
          type: ActionItemType.confirmPurchase,
          priority: ActionPriority.high,
          titleKey: 'dash_ai_confirm',
          params: {'title': d.listingSnapshot.title},
          dueAt: d.expiresAt,
          route: '/account/deals/${d.id}?confirm=1',
        ));
      }
    }
    for (final o in deals.objections) {
      if (o.status != TGObjectionStatus.awaitingEvidence) continue;
      final deal = deals.byId(o.dealId);
      if (deal == null || deal.buyerId != id) continue;
      items.add(ActionItem(
        id: 'evidence-${o.id}',
        type: ActionItemType.sendEvidence,
        priority: ActionPriority.critical,
        titleKey: 'dash_ai_evidence',
        params: {'title': deal.listingSnapshot.title},
        dueAt: o.evidenceDueAt,
        route: '/account/reviews/${o.reviewId}?evidence=1',
      ));
    }
    for (final d in deals.forSeller(id)) {
      if (d.status != TGDealStatus.pendingSeller) continue;
      items.add(ActionItem(
        id: 'seller-deal-${d.id}',
        type: ActionItemType.sellerDealCheck,
        priority: ActionPriority.high,
        titleKey: 'dash_ai_seller_deal',
        params: {'title': d.listingSnapshot.title},
        dueAt: d.sellerAnswerDueAt ?? d.expiresAt,
        route: '/dashboard/deals?tab=requests',
      ));
    }

    for (final r in TGSpecialOrderService.instance.forBuyer(id)) {
      if (r.status == TGSpecialRequestStatus.awaitingConsent) {
        items.add(ActionItem(
          id: 'consent-${r.requestNo}',
          type: ActionItemType.specialConsent,
          priority: ActionPriority.high,
          titleKey: 'dash_ai_consent',
          params: {'title': r.title},
          dueAt: r.expiresAt,
          route: '/account/requests/${r.requestNo}/consent',
        ));
      } else if (r.status == TGSpecialRequestStatus.quoted) {
        items.add(ActionItem(
          id: 'quotes-${r.requestNo}',
          type: ActionItemType.quotesReceived,
          priority: ActionPriority.medium,
          titleKey: 'dash_ai_quotes',
          params: {'title': r.title},
          dueAt: r.expiresAt,
          route: '/account/requests/${r.requestNo}',
        ));
      }
    }

    final billing = TGBillingService.instance;
    for (final s in billing.pastDueFor(id)) {
      items.add(ActionItem(
        id: 'pastdue-${s.id}',
        type: ActionItemType.subscriptionPastDue,
        priority: ActionPriority.critical,
        titleKey: 'dash_ai_past_due',
        params: {'title': s.label},
        dueAt: billing.nextRetryAt(s),
        route: '/dashboard/billing?tab=subscriptions',
      ));
    }

    for (final p in PromotionService.instance.forOwner(id, now: at)) {
      if (p.status != PromotionStatus.active || !p.isActiveAt(at)) continue;
      final left = p.endsAt.difference(at);
      // +1 h absorbs a DST shift in the wall-clock end date.
      if (left.inMinutes <= 0 || left > const Duration(days: promoEndingNoticeDays, hours: 1)) continue;
      items.add(ActionItem(
        id: 'promo-ending-${p.id}',
        type: ActionItemType.promotionEnding,
        priority: ActionPriority.high,
        titleKey: 'dash_ai_promo_ending',
        params: {'tier': p.tier.brand, 'n': '${(left.inHours / 24).round().clamp(1, promoEndingNoticeDays)}'},
        dueAt: p.endsAt,
        route: '/dashboard/advertising?tab=promotions',
        dismissible: true,
      ));
    }

    final unread = MessagingService.instance.unreadTotal(id);
    if (unread > 0) {
      items.add(ActionItem(
        id: 'unread',
        type: ActionItemType.unreadMessages,
        priority: ActionPriority.low,
        titleKey: unread == 1 ? 'dash_ai_unread_one' : 'dash_ai_unread',
        params: {'n': '$unread'},
        route: '/dashboard/messages',
      ));
    }

    final dismissed = ActionDismissals.instance;
    items.removeWhere((i) => i.dismissible && dismissed.isDismissed(id, i.id));
    items.sort(ActionItem.compare);
    return items;
  }

  /// KPI rules (RESTO-2 engagement): views / contacts / favorites are unique per
  /// visitor and exclude the owner's own visits. Those counters carry no
  /// timestamps, so a listing only counts towards a period when it was published
  /// inside it. Chat threads and confirmed deals carry their own timestamps.
  /// A KPI without any qualifying source in the period is "not enough data".
  static List<DashKpi> kpis(FakeAuthState auth, int periodDays, {DateTime? now}) {
    if (!auth.isLoggedIn || _mocksOff) {
      return [for (final k in DashKpiKind.values) DashKpi(k, null)];
    }
    final at = now ?? TGClock.now();
    final from = at.subtract(Duration(days: periodDays));
    final id = auth.userId;
    bool inPeriod(DateTime? t) => t != null && !t.isBefore(from) && !t.isAfter(at);

    final restos = RestaurantService.instance.ownedBy(id).where((r) => inPeriod(r.publishedAt)).toList();
    final liveProducts = auth.ownedListings.where((p) {
      final pub = p.publishedAt;
      if (pub == null || pub.isAfter(at)) return false;
      final end = p.expiresAt;
      return end == null || !end.isBefore(from);
    }).toList();

    int? sumResto(int Function(RestaurantEngagement e) pick) =>
        restos.isEmpty ? null : restos.fold<int>(0, (n, r) => n + pick(r.engagement));

    final threads = MessagingService.instance.threads.where((t) => t.sellerId == id && inPeriod(_startedAt(t))).length;
    final hasContactSource = restos.isNotEmpty || liveProducts.isNotEmpty;
    final restoContacts = sumResto((e) => e.uniqueContacts) ?? 0;

    final deals = DealService.instance..ensureSeeded();
    final confirmed = deals
        .forSeller(id)
        .where((d) => d.isConfirmed && inPeriod(d.buyerConfirmedAt ?? d.sellerConfirmedAt))
        .length;
    final hasDealSource = liveProducts.isNotEmpty || confirmed > 0;

    return [
      DashKpi(DashKpiKind.views, sumResto((e) => e.views)),
      DashKpi(DashKpiKind.contacts, hasContactSource || threads > 0 ? restoContacts + threads : null),
      DashKpi(DashKpiKind.favorites, sumResto((e) => e.uniqueFavorites)),
      DashKpi(DashKpiKind.deals, hasDealSource ? confirmed : null),
    ];
  }

  static DateTime? _startedAt(TGChatThread t) => t.messages.isEmpty ? null : t.messages.first.timestamp;

  static DashListingsSnapshot listings(FakeAuthState auth) {
    if (!auth.isLoggedIn || _mocksOff) return const DashListingsSnapshot();
    final products = auth.ownedListings;
    final restos = RestaurantService.instance.ownedBy(auth.userId);
    int p(bool Function(TGProduct) f) => products.where(f).length;
    int r(bool Function(RestaurantListing) f) => restos.where(f).length;
    return DashListingsSnapshot(
      active: p((e) => e.isActive) + r((e) => e.status == RestaurantListingStatus.active),
      expiring: p((e) => e.isExpiringSoon) + r((e) => e.status == RestaurantListingStatus.active && e.isExpiringSoon()),
      expired: p((e) => e.status == TGListingStatus.expired) + r((e) => e.status == RestaurantListingStatus.expired),
      review: p((e) => e.status == TGListingStatus.underReview) +
          r((e) => e.status == RestaurantListingStatus.underReview || e.status == RestaurantListingStatus.pendingAuthorization),
      drafts: p((e) => e.status == TGListingStatus.draft || e.status == TGListingStatus.paymentPending) +
          r((e) => e.status == RestaurantListingStatus.draft || e.status == RestaurantListingStatus.paymentPending),
    );
  }

  /// Only charges that really recur: the store plan renewal and an active
  /// Priority seat. One-off listing fees are paid up-front, so none appear here.
  static List<DashCharge> upcomingCharges(FakeAuthState auth, {DateTime? now}) {
    if (!auth.isLoggedIn || _mocksOff) return const [];
    final at = now ?? TGClock.now();
    final out = <DashCharge>[];
    if (auth.storePlan != null && auth.storeRenewsOn.isAfter(at)) {
      final price = PricingConfigService.instance.config.storeMonthlyPln(auth.storePlan!.name);
      if (price != null) {
        out.add(DashCharge(
          labelKey: 'dash_charge_store',
          params: {'plan': auth.storePlanLabel},
          amountPln: price,
          dueAt: auth.storeRenewsOn,
        ));
      }
    }
    if (auth.storePlan != null) {
      final pr = TGPriorityService.instance.priorityFor(auth.userId);
      final next = pr.nextBillingAt;
      if (pr.isActive && !pr.cancelAtPeriodEnd && next != null && next.isAfter(at)) {
        out.add(DashCharge(
          labelKey: 'dash_charge_priority',
          amountPln: TGRevenueConfigService.instance.config.priority.priceMonthly,
          dueAt: next,
        ));
      }
    }
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return out;
  }

  static List<TGChatThread> recentThreads(FakeAuthState auth, {int limit = 3}) {
    if (!auth.isLoggedIn || _mocksOff) return const [];
    return MessagingService.instance.inboxFor(auth.userId).take(limit).toList();
  }

  static int unread(FakeAuthState auth) =>
      !auth.isLoggedIn || _mocksOff ? 0 : MessagingService.instance.unreadTotal(auth.userId);
}
