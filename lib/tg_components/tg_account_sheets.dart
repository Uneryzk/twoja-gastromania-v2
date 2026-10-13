import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/dash2_mock_data.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_inventory_sync_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_post_publish_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';

/// Mock personas / clock controls exist only outside production mode.
bool get tgDevSwitchEnabled => !TGRevenueConfigService.instance.productionMode;

Future<void> _showTGSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
}

/// Seller pricing: free tier, per-listing fee and B2B store plans.
///
/// With [publishing] = true (the "+ Add Product" entry point) the sheet leads
/// with the signed-in user's free-listing quota and offers a "Start listing"
/// action.
Future<void> showTGPricingSheet(BuildContext context, {bool publishing = false}) =>
    _showTGSheet(context, (_) => _PricingSheet(publishing: publishing));

/// Header pill menu: quota status, quick actions, demo state switch, log out.
Future<void> showTGAccountSheet(BuildContext context) => _showTGSheet(context, (_) => const _AccountSheet());

TextStyle _devSectionStyle(BuildContext context) =>
    FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w800, fontSize: 11);

TextStyle _devItemStyle(BuildContext context) =>
    FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w600);

PopupMenuItem<Object> _devSection(BuildContext context, String title) => PopupMenuItem(
      enabled: false,
      height: 32,
      child: Text(title, style: _devSectionStyle(context)),
    );

void _devAdvanceClock(int days) {
  DealService.instance.ensureSeeded();
  DealModerationService.instance.ensureSeeded();
  TGSpecialOrderService.instance.ensureSeeded();
  RestaurantLifecycleService.instance.ensureSeeded();
  TGClock.advance(Duration(days: days));
  DealService.instance.onClockAdvanced();
  DealModerationService.instance.onClockAdvanced();
  TGSpecialOrderService.instance.onClockAdvanced();
  RestaurantLifecycleService.instance.onClockAdvanced();
  RestaurantPostPublishService.instance.onClockAdvanced();
  RestaurantInventorySyncService.instance.onClockAdvanced();
  AdSlotService.instance.onClockAdvanced();
  TGReviewVerifiedService.instance.onClockAdvanced();
}

void _devAdvanceBusinessDays(int days) {
  var advanced = 0;
  var guard = 0;
  while (advanced < days && guard < 400) {
    TGClock.advance(const Duration(days: 1));
    guard++;
    final t = TGClock.now();
    if (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday) continue;
    advanced++;
  }
  DealService.instance.onClockAdvanced();
  DealModerationService.instance.onClockAdvanced();
  TGSpecialOrderService.instance.onClockAdvanced();
  RestaurantLifecycleService.instance.onClockAdvanced();
  RestaurantPostPublishService.instance.onClockAdvanced();
  RestaurantInventorySyncService.instance.onClockAdvanced();
  AdSlotService.instance.onClockAdvanced();
  TGReviewVerifiedService.instance.onClockAdvanced();
}

/// Applies a Dev Switcher pick: updates [FakeAuthState], then navigates via [router].
///
/// Uses [GoRouter] (not [BuildContext.go]) because selecting Admin/login roles
/// rebuilds the header and can dispose the widget that opened the menu — so
/// `context.mounted` was false and `/admin` never ran.
void applyTGDevSwitchPick(GoRouter router, FakeAuthState auth, Object picked) {
  if (!tgDevSwitchEnabled) return;
  if (picked is DashboardDevPick) {
    switch (picked) {
      case DashboardDevPick.newUser:
        auth.actAsNewUser();
      case DashboardDevPick.sellerBuyer:
        DealService.instance.ensureSeeded();
        auth.actAsSellerBuyer();
      case DashboardDevPick.busySeller:
        auth.actAsBusySeller();
        Dash2Mocks.seedBusySeller(auth);
      case DashboardDevPick.favoritesBuyer:
        auth.actAsFavoritesBuyer();
        Dash2Mocks.seedFavoritesBuyer(auth.userId);
      case DashboardDevPick.historySeller:
        auth.actAsHistorySeller();
        Dash2Mocks.seedHistorySeller(auth);
      case DashboardDevPick.billingStore:
        auth.actAsStoreOwner(StoreOwnerDevPick.gastroPro);
        TGBillingService.instance.seedMocks(auth);
    }
    router.go(switch (picked) {
      DashboardDevPick.busySeller => '/dashboard/messages',
      DashboardDevPick.favoritesBuyer => '/dashboard/favorites',
      DashboardDevPick.historySeller => '/dashboard/insights',
      DashboardDevPick.billingStore => '/dashboard/billing',
      _ => '/dashboard',
    });
    return;
  }
  if (picked is TGUserRole) {
    auth.setRole(picked); // notifyListeners → UI refresh
    if (picked == TGUserRole.admin || picked == TGUserRole.moderator) {
      router.go('/admin');
    } else if (picked == TGUserRole.visitor) {
      router.go('/');
    }
    return;
  }
  if (picked is TGEntitlementScenario) {
    auth.setRole(TGUserRole.seller, notify: false);
    auth.setScenario(picked); // notifyListeners
    router.go('/dashboard/listings');
    return;
  }
  if (picked is StoreOwnerDevPick) {
    auth.actAsStoreOwner(picked);
    router.go(TGSellerProfileService.instance.pathForSellerId(picked.sellerKey));
    return;
  }
  if (picked is ManufacturerDevPick) {
    auth.actAsManufacturer(picked);
    if (picked.forceInactive) {
      final profile = TGSellerProfileService.instance.bySellerKey(picked.sellerKey);
      if (profile != null) {
        TGSellerProfileService.instance.patch(
          profile.publicId,
          (p) => p.copyWith(status: TGStoreStatus.inactive),
        );
      }
    }
    // Land on public store-like page (logo, projects, reviews); tools stay at /dashboard/manufacturer.
    router.go(TGSellerProfileService.instance.pathForSellerId(picked.sellerKey));
    return;
  }
  if (picked is BuyerDevPick) {
    auth.actAsBuyer(picked);
    router.go('/account/deals');
    return;
  }
  if (picked is SpecialOrderBuyerDevPick) {
    TGSpecialOrderService.instance.ensureSeeded();
    auth.actAsSpecialOrderBuyer(picked);
    router.go('/account/requests');
    return;
  }
  if (picked == DevrenSellerDevPick.listingOwner) {
    auth.actAsDevrenSeller();
    router.go('/dashboard/listings');
    return;
  }
  if (picked is RestoSellerDevPick) {
    auth.actAsRestoSeller(picked);
    router.go('/dashboard/listings');
    return;
  }
  if (picked is RepresentativeDevPick) {
    auth.actAsRepresentative(picked);
    router.go('/dashboard/representative');
    return;
  }
  if (picked is _DevBusinessDays) {
    _devAdvanceBusinessDays(picked.days);
    return;
  }
  if (picked is int) _devAdvanceClock(picked);
}

class _DevBusinessDays {
  const _DevBusinessDays(this.days);
  final int days;
}

String _devClockLabel(BuildContext context, int days) {
  final key = days == 1 ? 'ui_dev_clock_days' : 'ui_dev_clock_days_many';
  return context.t(key, {'n': '$days'});
}

/// Debug long-press Dev Switcher — labels follow the selected app language.
Future<void> showTGDevSwitch(BuildContext context, FakeAuthState auth) async {
  if (!tgDevSwitchEnabled) return;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return;
  // Capture router before the menu — header may rebuild/dispose [context] on pick.
  final router = GoRouter.of(context);
  final origin = box.localToGlobal(Offset.zero);
  final itemStyle = _devItemStyle(context);
  String t(String key) => context.t(key);
  final picked = await showMenu<Object>(
    context: context,
    color: FlutterFlowTheme.of(context).secondaryBackground,
    position: RelativeRect.fromLTRB(origin.dx, origin.dy + box.size.height + 6, origin.dx + 1, 0),
    constraints: const BoxConstraints(maxHeight: 560, minWidth: 300),
    items: [
      _devSection(context, t('ui_dev_sec_visitor')),
      PopupMenuItem(value: TGUserRole.visitor, child: Text(t('ui_dev_visitor_anon'), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_dash')),
      PopupMenuItem(value: DashboardDevPick.newUser, child: Text(t('ui_dev_new_user'), style: itemStyle)),
      PopupMenuItem(value: DashboardDevPick.sellerBuyer, child: Text(t('ui_dev_seller_buyer'), style: itemStyle)),
      PopupMenuItem(value: DashboardDevPick.busySeller, child: Text(t('ui_dev_busy_seller'), style: itemStyle)),
      PopupMenuItem(value: DashboardDevPick.favoritesBuyer, child: Text(t('ui_dev_fav_buyer'), style: itemStyle)),
      PopupMenuItem(value: DashboardDevPick.historySeller, child: Text(t('ui_dev_history_seller'), style: itemStyle)),
      PopupMenuItem(value: DashboardDevPick.billingStore, child: Text(t('ui_dev_billing_store'), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_staff')),
      PopupMenuItem(value: TGUserRole.admin, child: Text(t('ui_dev_admin'), style: itemStyle)),
      PopupMenuItem(value: TGUserRole.moderator, child: Text(t('ui_dev_moderator'), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_reps')),
      for (final p in RepresentativeDevPick.all) PopupMenuItem(value: p, child: Text(t(p.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_private_seller')),
      PopupMenuItem(value: TGEntitlementScenario.noListings, child: Text(t('ui_dev_sc_no_listings'), style: itemStyle)),
      PopupMenuItem(value: TGEntitlementScenario.freeActive, child: Text(t('ui_dev_sc_free_active'), style: itemStyle)),
      PopupMenuItem(value: TGEntitlementScenario.freeNoListingsLeft, child: Text(t('ui_dev_sc_free_used'), style: itemStyle)),
      PopupMenuItem(value: TGEntitlementScenario.needsAttention, child: Text(t('ui_dev_sc_needs_attention'), style: itemStyle)),
      PopupMenuItem(value: TGEntitlementScenario.listingExpiringSoon, child: Text(t('ui_dev_sc_expiring'), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_stores')),
      for (final p in StoreOwnerDevPick.all) PopupMenuItem(value: p, child: Text(t(p.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_makers')),
      for (final p in ManufacturerDevPick.all) PopupMenuItem(value: p, child: Text(t(p.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_buyers_private')),
      PopupMenuItem(value: BuyerDevPick.marek, child: Text(t(BuyerDevPick.marek.labelKey), style: itemStyle)),
      PopupMenuItem(value: BuyerDevPick.anna, child: Text(t(BuyerDevPick.anna.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_buyers_corp')),
      PopupMenuItem(value: BuyerDevPick.corporate, child: Text(t(BuyerDevPick.corporate.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_so_buyers')),
      for (final p in SpecialOrderBuyerDevPick.all) PopupMenuItem(value: p, child: Text(t(p.labelKey), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_transfer')),
      PopupMenuItem(value: DevrenSellerDevPick.listingOwner, child: Text(t('ui_dev_transfer_owner'), style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, 'Restaurant Seller'),
      PopupMenuItem(value: RestoSellerDevPick.ownerFreeAvailable, child: Text('Owner (individual, free start available)', style: itemStyle)),
      PopupMenuItem(value: RestoSellerDevPick.ownerFreeUsed, child: Text('Owner (free start used)', style: itemStyle)),
      PopupMenuItem(value: RestoSellerDevPick.agentBasicStore, child: Text('Agent (Basic store)', style: itemStyle)),
      PopupMenuItem(value: RestoSellerDevPick.withExpired, child: Text('With expired listing', style: itemStyle)),
      PopupMenuItem(value: RestoSellerDevPick.underReview, child: Text('With listing under review', style: itemStyle)),
      const PopupMenuDivider(),
      _devSection(context, t('ui_dev_sec_clock')),
      for (final d in const [1, 2, 3, 5, 10, 14, 25])
        PopupMenuItem(value: d, child: Text(_devClockLabel(context, d), style: itemStyle)),
      for (final d in const [1, 3, 5, 10])
        PopupMenuItem(value: _DevBusinessDays(d), child: Text('Advance $d business days', style: itemStyle)),
    ],
  );
  if (picked == null) return;
  applyTGDevSwitchPick(router, auth, picked);
}

/// Navigates to the Special Order hub (full page). Kept for any legacy callers.
Future<void> showTGSpecialOrderSheet(BuildContext context) async {
  context.go('/special-order');
}

// ---------------------------------------------------------------------------

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
        side: BorderSide(color: theme.tertiary),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: theme.secondaryText),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.paddingOf(context).bottom),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body, this.accent});

  final IconData icon;
  final String title;
  final String body;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = accent ?? theme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(TGRadius.input),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.bodyLarge.override(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing
// ---------------------------------------------------------------------------

class _PricingSheet extends StatelessWidget {
  const _PricingSheet({required this.publishing});
  final bool publishing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();

    String primaryLabel;
    VoidCallback primaryAction;
    if (!publishing) {
      primaryLabel = context.t('ui_got_it');
      primaryAction = () => Navigator.of(context).pop();
    } else if (!auth.isLoggedIn) {
      primaryLabel = context.t('ui_log_in_to_start');
      primaryAction = () {
        Navigator.of(context).pop();
        context.goNamed(LoginPageWidget.routeName);
      };
    } else {
      primaryLabel = context.t('ui_start_a_listing');
      primaryAction = () {
        Navigator.of(context).pop();
        context.go('/add-product');
      };
    }

    return _SheetFrame(
      title: publishing ? context.t('ui_sell_your_equipment') : context.t('ui_pricing_for_sellers'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (publishing && auth.isLoggedIn) ...[
            _QuotaCard(auth: auth),
            const SizedBox(height: 12),
          ],
          _InfoCard(
            icon: Icons.card_giftcard_rounded,
            title: context.t('ui_first_n_listings_free', {'n': '${PricingConfigService.instance.config.freeListingQuota}'}),
            body: context.t('ui_free_listings_body', {'days': '${PricingConfigService.instance.config.freeListingDays}'}),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.receipt_long_rounded,
            title: context.t('ui_listing_fee_title', {
              'fee': '${PricingConfigService.instance.config.defaultListingFeePln}',
              'days': '${PricingConfigService.instance.config.defaultListingDays}',
            }),
            body: context.t('ui_listing_fee_body', {
              'fee': '${PricingConfigService.instance.config.defaultListingFeePln}',
              'days': '${PricingConfigService.instance.config.defaultListingDays}',
            }),
            accent: theme.secondary,
          ),
          const SizedBox(height: 18),
          Text(context.t('ui_b2b_stores'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            context.t('ui_b2b_stores_sub'),
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
          const SizedBox(height: 10),
          for (final plan in [
            TGStorePlan(name: 'Basic', monthlyPricePln: PricingConfigService.instance.config.basicStoreMonthlyPln),
            TGStorePlan(name: 'Pro', monthlyPricePln: PricingConfigService.instance.config.proStoreMonthlyPln),
            TGStorePlan(name: 'Enterprise', monthlyPricePln: PricingConfigService.instance.config.enterpriseStoreMonthlyPln),
          ]) ...[
            _PlanRow(plan: plan),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: theme.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('ui_prices_vat_note', {'vat': '${(TGPricing.vatRate * 100).round()}'}),
                  style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TGButton(onPressed: primaryAction, label: primaryLabel, height: 48),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});
  final TGStorePlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.input),
        border: Border.all(color: theme.tertiary),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: theme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(_storePlanShortName(context, plan.name), style: theme.bodyLarge.override(fontWeight: FontWeight.w800))),
          Text(
            '${plan.monthlyPricePln} PLN',
            style: theme.titleSmall.override(fontWeight: FontWeight.w900, color: theme.primary),
          ),
          const SizedBox(width: 4),
          Text(context.t('ui_slash_mo'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final kind = auth.pillKind;
    final isStore = kind == TGHeaderPillKind.store;
    final warn = auth.pillIsProblem;
    final color = isStore ? theme.success : (warn ? theme.warning : theme.primary);

    final String headline;
    final String detail;
    final double progress;
    switch (kind) {
      case TGHeaderPillKind.store:
        headline = context.t('ui_store_listings_active', {
          'plan': _storePlanFullName(context, auth.storePlanLabel),
          'used': '${auth.storeActiveUsed}',
          'limit': '${auth.storeActiveLimit}',
        });
        detail = context.t('ui_subscription_renews_monthly');
        progress = auth.storeActiveUsed / auth.storeActiveLimit;
      case TGHeaderPillKind.needsAttention:
        headline = context.t('ui_listings_need_attention', {'n': '${auth.ownedNeedsAttention.length}'});
        detail = context.t('ui_moderator_asked_info');
        progress = 0.5;
      case TGHeaderPillKind.expiredListings:
        headline = context.t('ui_n_expired_listings', {'n': '${auth.ownedExpired.length}'});
        detail = context.t('ui_renew_to_put_back');
        progress = 1;
      case TGHeaderPillKind.expiringListings:
        headline = context.t('ui_n_ending_soon', {'n': '${auth.ownedExpiringSoon.length}'});
        detail = context.t('ui_renew_early_keep');
        progress = 0.85;
      case TGHeaderPillKind.noQuota:
        headline = context.t('ui_no_free_listings_left');
        detail = context.t('ui_next_listing_fee', {
          'fee': '${PricingConfigService.instance.config.defaultListingFeePln}',
          'days': '${PricingConfigService.instance.config.defaultListingDays}',
        });
        progress = 1;
      case TGHeaderPillKind.noListings:
        headline = context.t('ui_three_free_listings');
        detail = context.t('ui_first_three_free_detail', {
          'quota': '${PricingConfigService.instance.config.freeListingQuota}',
          'period': DurationFormatter.daysOf(context, PricingConfigService.instance.config.freeListingDays),
        });
        progress = 0;
      case TGHeaderPillKind.freeQuota:
        headline = context.t('ui_free_listings_left_of', {'left': '${auth.freeListingsLeft}', 'total': '${auth.freeListingsTotal}'});
        detail = context.t('ui_free_listings_left_detail', {'left': '${auth.freeListingsLeft}', 'total': '${auth.freeListingsTotal}'});
        progress = (auth.freeListingsTotal - auth.freeListingsLeft) / auth.freeListingsTotal;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: theme.bodyLarge.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(detail, style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.tertiary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

String _storePlanShortName(BuildContext context, String name) => switch (name) {
      'Pro' => context.t('ui_plan_pro'),
      'Enterprise' => context.t('ui_plan_enterprise'),
      _ => context.t('ui_plan_basic'),
    };

String _storePlanFullName(BuildContext context, String label) => switch (label) {
      'Pro Store' => context.t('ui_plan_pro_store'),
      'Enterprise Store' => context.t('ui_plan_enterprise_store'),
      _ => context.t('ui_plan_basic_store'),
    };

String _roleLabel(BuildContext context, TGUserRole role) => switch (role) {
      TGUserRole.visitor => context.t('ui_role_visitor'),
      TGUserRole.seller => context.t('ui_role_seller'),
      TGUserRole.storeSeller => context.t('ui_role_store_seller'),
      TGUserRole.moderator => context.t('ui_role_moderator'),
      TGUserRole.admin => context.t('ui_role_admin'),
      TGUserRole.buyer => context.t('ui_role_buyer'),
    };

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  static String scenarioLabel(BuildContext context, TGEntitlementScenario s) => switch (s) {
        TGEntitlementScenario.noListings => context.t('ui_dev_sc_no_listings'),
        TGEntitlementScenario.freeActive => context.t('ui_dev_sc_free_active'),
        TGEntitlementScenario.freeNoListingsLeft => context.t('ui_dev_sc_free_used'),
        TGEntitlementScenario.needsAttention => context.t('ui_dev_sc_needs_attention'),
        TGEntitlementScenario.listingExpiringSoon => context.t('ui_dev_sc_expiring'),
        TGEntitlementScenario.hasExpired => context.t('ui_dev_sc_expired'),
        TGEntitlementScenario.storeSubscriber => context.t('ui_dev_sc_store_sub'),
      };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final caps = AccountCapabilities.of(auth);
    final dev = tgDevSwitchEnabled;

    return _SheetFrame(
      title: context.t('ui_your_account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TGButton(
                  key: const Key('account-open-dashboard'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/dashboard');
                  },
                  label: context.t('dash_open_dashboard'),
                  icon: Icons.space_dashboard_outlined,
                  variant: TGButtonVariant.outline,
                  height: 46,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TGButton(
                  key: const Key('account-open-actions'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/dashboard/actions');
                  },
                  label: context.t('dash_actions'),
                  icon: Icons.task_alt,
                  variant: TGButtonVariant.outline,
                  height: 46,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _QuotaCard(auth: auth),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TGButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showTGPricingSheet(context, publishing: true);
                  },
                  label: context.t('ui_add_listing'),
                  icon: Icons.add,
                  height: 46,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TGButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showTGPricingSheet(context);
                  },
                  label: context.t('ui_pricing'),
                  icon: Icons.sell_outlined,
                  variant: TGButtonVariant.outline,
                  height: 46,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TGButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (MediaQuery.sizeOf(context).width >= TGBreakpoints.phone) {
                MessagingService.instance.openDock(inbox: true);
              } else {
                context.go('/dashboard/messages');
              }
            },
            label: context.t('ui_messages'),
            icon: Icons.chat_bubble_outline,
            variant: TGButtonVariant.outline,
            height: 46,
          ),
          const SizedBox(height: 10),
          TGButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (auth.role == TGUserRole.buyer) {
                TGNav.accountDeals(context);
              } else {
                TGNav.dashboardDeals(context);
              }
            },
            label: context.t('ui_deals'),
            icon: Icons.handshake_outlined,
            variant: TGButtonVariant.outline,
            height: 46,
          ),
          if (auth.role == TGUserRole.buyer || caps.isBuyerActive) ...[
            const SizedBox(height: 10),
            TGButton(
              onPressed: () {
                Navigator.of(context).pop();
                TGNav.accountReviews(context);
              },
              label: context.t('ui_your_reviews'),
              icon: Icons.rate_review_outlined,
              variant: TGButtonVariant.outline,
              height: 46,
            ),
          ],
          if (auth.canModerate) ...[
            const SizedBox(height: 10),
            TGButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/admin');
              },
              label: context.t('ui_moderation_console'),
              icon: Icons.shield_outlined,
              variant: TGButtonVariant.outline,
              height: 46,
            ),
          ],
          if (dev) ...[
          const SizedBox(height: 18),
          Text(
            context.t('ui_demo_role'),
            style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          RadioGroup<TGUserRole>(
            groupValue: auth.role,
            onChanged: (next) {
              if (next != null) auth.setRole(next);
            },
            child: Column(
              children: [
                for (final v in TGUserRole.values)
                  RadioListTile<TGUserRole>(
                    value: v,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.primary,
                    title: Text(_roleLabel(context, v), style: theme.bodyMedium.override(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'DEMO · switch account state',
            style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          RadioGroup<TGEntitlementScenario>(
            groupValue: auth.scenario,
            onChanged: (next) {
              if (next != null) auth.setScenario(next);
            },
            child: Column(
              children: [
                for (final v in TGEntitlementScenario.values)
                  RadioListTile<TGEntitlementScenario>(
                    value: v,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.primary,
                    title: Text(scenarioLabel(context, v), style: theme.bodyMedium.override(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          ],
          const SizedBox(height: 10),
          TGButton(
            onPressed: () {
              auth.logOut();
              Navigator.of(context).pop();
            },
            label: context.t('ui_log_out'),
            icon: Icons.logout,
            variant: TGButtonVariant.outline,
            height: 46,
          ),
        ],
      ),
    );
  }
}
