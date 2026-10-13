import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/dashboard_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

@immutable
class DashNavItem {
  const DashNavItem({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.route,
    this.placeholder = false,
  });

  final String id;
  final String labelKey;
  final IconData icon;
  final String route;

  /// Section without content yet → "Coming in the next step".
  final bool placeholder;
}

@immutable
class DashNavGroup {
  const DashNavGroup(this.labelKey, this.items);

  final String labelKey;
  final List<DashNavItem> items;
}

/// Sections that exist only as "Coming in the next step" pages for now.
abstract final class DashPlaceholders {
  static const storeSettings = DashNavItem(
    id: 'store-settings',
    labelKey: 'dash_nav_store_settings',
    icon: Icons.tune_outlined,
    route: '/dashboard/store-settings',
    placeholder: true,
  );
  static const saved = DashNavItem(
    id: 'saved',
    labelKey: 'dash_nav_saved',
    icon: Icons.bookmark_border,
    route: '/dashboard/saved',
    placeholder: true,
  );
  static const all = [storeSettings, saved];
}

const _overviewItem = DashNavItem(id: 'overview', labelKey: 'dash_overview', icon: Icons.space_dashboard_outlined, route: '/dashboard');
const _actionsItem = DashNavItem(id: 'actions', labelKey: 'dash_actions', icon: Icons.task_alt, route: '/dashboard/actions');
const _listingsItem = DashNavItem(id: 'listings', labelKey: 'dash_nav_listings', icon: Icons.inventory_2_outlined, route: '/dashboard/listings');
const _messagesItem = DashNavItem(id: 'messages', labelKey: 'dash_nav_messages', icon: Icons.chat_bubble_outline, route: '/dashboard/messages');
const dashInsightsItem = DashNavItem(id: 'insights', labelKey: 'dash_nav_insights', icon: Icons.insights_outlined, route: '/dashboard/insights');
const dashBillingItem = DashNavItem(id: 'billing', labelKey: 'dash_nav_billing', icon: Icons.receipt_long_outlined, route: '/dashboard/billing');
const dashSettingsItem = DashNavItem(id: 'settings', labelKey: 'dash_nav_settings', icon: Icons.settings_outlined, route: '/dashboard/settings');
const dashVerificationItem = DashNavItem(id: 'verification', labelKey: 'dash_nav_verification', icon: Icons.verified_outlined, route: '/dashboard/verification');
const dashFavoritesItem = DashNavItem(id: 'favorites', labelKey: 'dash_nav_favorites', icon: Icons.favorite_border, route: '/dashboard/favorites');

/// Sidebar / "More" groups for an account. Existing routes are linked as-is.
List<DashNavGroup> dashNavGroups(AccountCapabilities caps, FakeAuthState auth) {
  const plans = DashNavItem(id: 'plans', labelKey: 'dash_nav_plans', icon: Icons.workspace_premium_outlined, route: '/plans');
  return [
    const DashNavGroup('dash_grp_overview', [_overviewItem, _actionsItem]),
    DashNavGroup('dash_grp_sell', [
      _listingsItem,
      dashInsightsItem,
      const DashNavItem(id: 'deals', labelKey: 'dash_nav_deals', icon: Icons.handshake_outlined, route: '/dashboard/deals'),
      _messagesItem,
      if (caps.store) ...const [
        DashNavItem(id: 'advertising', labelKey: 'dash_nav_advertising', icon: Icons.campaign_outlined, route: '/dashboard/advertising'),
        DashNavItem(id: 'bulk-add', labelKey: 'dash_nav_bulk', icon: Icons.playlist_add, route: '/dashboard/bulk-add'),
        dashVerificationItem,
      ],
      if (!caps.store) plans,
    ]),
    if (caps.store)
      DashNavGroup('dash_grp_store', [
        DashNavItem(
          id: 'store-page',
          labelKey: 'dash_nav_store_page',
          icon: Icons.storefront_outlined,
          route: TGSellerProfileService.instance.pathForSellerId(auth.userId),
        ),
        plans,
        DashPlaceholders.storeSettings,
      ]),
    if (caps.store)
      DashNavGroup('dash_grp_special', [
        const DashNavItem(id: 'leads', labelKey: 'dash_nav_leads', icon: Icons.request_quote_outlined, route: '/dashboard/leads'),
        if (caps.manufacturerEligible)
          const DashNavItem(id: 'manufacturer', labelKey: 'dash_nav_manufacturer', icon: Icons.precision_manufacturing_outlined, route: '/dashboard/manufacturer'),
        const DashNavItem(id: 'founders', labelKey: 'dash_nav_founders', icon: Icons.star_outline, route: '/founders'),
      ]),
    const DashNavGroup('dash_grp_buy', [
      DashNavItem(id: 'purchases', labelKey: 'dash_nav_purchases', icon: Icons.shopping_bag_outlined, route: '/account/deals'),
      DashNavItem(id: 'reviews', labelKey: 'dash_nav_reviews', icon: Icons.rate_review_outlined, route: '/account/reviews'),
      DashNavItem(id: 'requests', labelKey: 'dash_nav_requests', icon: Icons.design_services_outlined, route: '/account/requests'),
      dashFavoritesItem,
      DashPlaceholders.saved,
    ]),
    DashNavGroup('dash_grp_account', [
      const DashNavItem(id: 'notifications', labelKey: 'dash_nav_notifications', icon: Icons.notifications_none, route: '/account/notifications'),
      dashBillingItem,
      if (!caps.store) dashVerificationItem,
      dashSettingsItem,
      if (caps.isStaff)
        const DashNavItem(id: 'admin', labelKey: 'ui_moderation_console', icon: Icons.shield_outlined, route: '/admin'),
    ]),
  ];
}

void _openItem(BuildContext context, DashNavItem item) {
  if (item.id == 'messages') {
    TGNav.messages(context);
    return;
  }
  context.go(item.route);
}

/// Dashboard chrome: sticky 248 px sidebar on desktop (top 88 = header 64 + 24),
/// ~1008 px content inside a 1280 px container; bottom nav + "More" on phones.
class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.current, required this.child});

  /// [DashNavItem.id] of the open section.
  final String current;
  final Widget child;

  static const double sidebarWidth = 248;
  static const double gutter = 24;
  static const double containerWidth = 1280;
  static const double bottomNavHeight = 64;

  static const _noBottomNavPrefixes = [
    '/add-product',
    '/restaurants/new',
    '/checkout',
    '/dashboard/bulk-add',
    '/special-order/new',
  ];

  /// Wizards and payment screens keep the full height for their own footer CTA.
  static bool hidesBottomNav(String path) =>
      _noBottomNavPrefixes.any(path.startsWith) || path.endsWith('/consent');

  static Listenable listenables() => Listenable.merge([
        MessagingService.instance,
        DealService.instance,
        RestaurantService.instance,
        ModerationService.instance,
        TGSpecialOrderService.instance,
        TGRevenueConfigService.instance,
      ]);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.desktop;
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: listenables(),
        builder: (context, _) {
          final auth = context.watch<FakeAuthState>();
          final caps = AccountCapabilities.of(auth);
          final groups = dashNavGroups(caps, auth);
          final badges = {
            'actions': TGDashboard.actionItems(auth).length,
            'messages': TGDashboard.unread(auth),
          };
          if (wide) return _desktop(context, groups, badges);
          return _mobile(context, groups, badges);
        },
      ),
    );
  }

  Widget _desktop(BuildContext context, List<DashNavGroup> groups, Map<String, int> badges) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: containerWidth + gutter * 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: gutter),
                child: SizedBox(
                  key: const Key('dash-sidebar'),
                  width: sidebarWidth,
                  child: _Sidebar(groups: groups, current: current, badges: badges),
                ),
              ),
              const SizedBox(width: gutter),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('dash-content'),
                  padding: const EdgeInsets.only(top: gutter, bottom: 48),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobile(BuildContext context, List<DashNavGroup> groups, Map<String, int> badges) {
    final path = GoRouterState.of(context).uri.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('dash-content'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: child,
          ),
        ),
        if (!hidesBottomNav(path)) _BottomNav(groups: groups, current: current, badges: badges),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.groups, required this.current, required this.badges});

  final List<DashNavGroup> groups;
  final String current;
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in groups) ...[
              _GroupHeader(g.labelKey),
              for (final item in g.items)
                _NavTile(item: item, active: item.id == current, badge: badges[item.id] ?? 0),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.labelKey);

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: Text(
          context.t(labelKey),
          style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 11),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.badge, this.onTap});

  final DashNavItem item;
  final bool active;
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final label = context.t(item.labelKey);
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: Material(
        color: active ? TGColors.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('dash-nav-${item.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap ?? () => _openItem(context, item),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active ? const Border(left: BorderSide(color: TGColors.cta, width: 3)) : null,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: active ? TGColors.cta : theme.secondaryText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.override(fontWeight: active ? FontWeight.w800 : FontWeight.w600),
                  ),
                ),
                if (badge > 0) _Badge(badge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(TGRadius.pill)),
      child: Text(
        n > 99 ? '99+' : '$n',
        textAlign: TextAlign.center,
        style: FlutterFlowTheme.of(context).labelSmall.override(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.groups, required this.current, required this.badges});

  final List<DashNavGroup> groups;
  final String current;
  final Map<String, int> badges;

  static const _primary = [_overviewItem, _actionsItem, _listingsItem, _messagesItem];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final inPrimary = _primary.any((i) => i.id == current);
    return Material(
      key: const Key('dash-bottom-nav'),
      color: TGColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: TGColors.border))),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: DashboardShell.bottomNavHeight,
            child: Row(
              children: [
                for (final item in _primary)
                  Expanded(
                    child: _BottomItem(
                      id: item.id,
                      icon: item.icon,
                      label: context.t(item.labelKey),
                      active: item.id == current,
                      badge: badges[item.id] ?? 0,
                      onTap: () => _openItem(context, item),
                    ),
                  ),
                Expanded(
                  child: _BottomItem(
                    id: 'more',
                    icon: Icons.menu,
                    label: context.t('dash_nav_more'),
                    active: !inPrimary,
                    badge: 0,
                    onTap: () => showDashMoreMenu(context, groups: groups, current: current, badges: badges),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = active ? TGColors.cta : theme.secondaryText;
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('dash-bottom-$id'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (badge > 0) Positioned(right: -12, top: -6, child: _Badge(badge)),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.labelSmall.override(color: color, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen "More" menu with every dashboard group (phones).
Future<void> showDashMoreMenu(
  BuildContext context, {
  required List<DashNavGroup> groups,
  required String current,
  required Map<String, int> badges,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (dialogContext) {
      final theme = FlutterFlowTheme.of(dialogContext);
      return Dialog.fullscreen(
        key: const Key('dash-more-menu'),
        backgroundColor: TGColors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(dialogContext.t('dash_more_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    IconButton(
                      key: const Key('dash-more-close'),
                      tooltip: dialogContext.t('dash_close'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    for (final g in groups) ...[
                      _GroupHeader(g.labelKey),
                      for (final item in g.items)
                        _NavTile(
                          item: item,
                          active: item.id == current,
                          badge: badges[item.id] ?? 0,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openItem(context, item);
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
