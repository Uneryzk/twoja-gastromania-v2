import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/dashboard/listing_row.dart';
import 'package:twoja_gastromania/dashboard/promotions_panel.dart';
import 'package:twoja_gastromania/dashboard/renew_sheet.dart';
import 'package:twoja_gastromania/deals/sold_flow_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_listing_row.dart';
import 'package:twoja_gastromania/restaurants/restaurant_renew_sheet.dart';
import 'package:twoja_gastromania/tg_services/restaurant_inventory_sync_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_post_publish_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';

/// Expired first (most overdue at the top), then live listings by days left
/// (soonest expiry first). Drafts and other non-live rows sit at the end.
int compareDashboardListings(TGProduct a, TGProduct b) {
  int group(TGProduct p) {
    if (p.status == TGListingStatus.expired) return 0;
    if (p.status == TGListingStatus.removed) return 1;
    if (p.status == TGListingStatus.underReview) return 2;
    if (p.isActive) return 3;
    if (p.status == TGListingStatus.paymentPending) return 4;
    if (p.status == TGListingStatus.draft) return 5;
    return 6;
  }

  final g = group(a).compareTo(group(b));
  if (g != 0) return g;
  if (a.status == TGListingStatus.expired) {
    return b.daysSinceExpiry().compareTo(a.daysSinceExpiry());
  }
  if (a.isActive) {
    return a.daysUntilExpiry().compareTo(b.daysUntilExpiry());
  }
  return a.title.compareTo(b.title);
}

class ListingsDashboardPage extends StatefulWidget {
  const ListingsDashboardPage({super.key, this.filter, this.renewId, this.renewedId, this.soldId, this.type, this.query});

  static const routeName = 'ListingsDashboard';
  static const routePath = '/dashboard/listings';

  final String? filter;
  final String? renewId;
  final String? renewedId;
  final String? soldId;

  /// `equipment` | `restaurant`; null shows both.
  final String? type;

  /// `?q=` — title or listing No. contains.
  final String? query;

  static const tabs = ['all', 'active', 'expiring', 'expired', 'drafts', 'review', 'sold', 'promotions'];

  @override
  State<ListingsDashboardPage> createState() => _ListingsDashboardPageState();
}

class _ListingsDashboardPageState extends State<ListingsDashboardPage> {
  late final _search = TextEditingController(text: widget.query ?? '');
  Timer? _debounce;

  String get _tab {
    final f = widget.filter ?? '';
    return f.isEmpty ? 'all' : f;
  }

  String get _q => _search.text.trim();

  /// Rewrites the URL, keeping every other listings query param.
  void _go({String? tab, String? type, String? q}) {
    final t = tab ?? _tab;
    final ty = type ?? widget.type ?? '';
    final qq = q ?? _q;
    TGAnalytics.track('listings_filter', {'tab': t, 'type': ty.isEmpty ? 'all' : ty, 'q': qq.isNotEmpty});
    final parts = <String>[
      if (t != 'all') 'filter=$t',
      if (ty.isNotEmpty) 'type=$ty',
      if (qq.isNotEmpty) 'q=${Uri.encodeQueryComponent(qq)}',
    ];
    context.go('${ListingsDashboardPage.routePath}${parts.isEmpty ? '' : '?${parts.join('&')}'}');
  }

  void _onSearch(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _go(q: v.trim());
    });
  }

  bool _matches(String title, String? no) {
    final q = _q.toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) || (no ?? '').contains(q);
  }

  @override
  void initState() {
    super.initState();
    RestaurantService.instance.addListener(_onResto);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleQuery());
  }

  void _onResto() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RestaurantService.instance.removeListener(_onResto);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ListingsDashboardPage old) {
    super.didUpdateWidget(old);
    final q = widget.query ?? '';
    if (old.query != widget.query && q != _q) _search.text = q;
    if (old.renewId != widget.renewId || old.renewedId != widget.renewedId || old.soldId != widget.soldId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleQuery());
    }
  }

  void _handleQuery() {
    if (!mounted) return;
    final auth = context.read<FakeAuthState>();
    final renewed = widget.renewedId;
    if (renewed != null && renewed.isNotEmpty) {
      final p = auth.ownedListings.where((e) => e.id == renewed).firstOrNull;
      final resto = RestaurantService.instance.byId(renewed);
      final until = DateFormat('d MMM y').format(p?.expiresAt ?? resto?.expiresAt ?? DateTime.now());
      showTGToast(context, 'Live again until $until');
    }
    final sold = widget.soldId;
    if (sold != null && sold.isNotEmpty) {
      final listing = auth.ownedListings.where((p) => p.id == sold || p.listingNo == sold).firstOrNull;
      if (listing != null) {
        showSoldFlow(context, listing, mode: SoldFlowMode.markSold);
        return;
      }
    }
    final id = widget.renewId;
    if (id == null || id.isEmpty) return;
    final resto = RestaurantService.instance.byId(id) ?? RestaurantService.instance.byListingNo(id);
    if (resto != null) {
      showRestaurantRenewSheet(
        context,
        resto,
        early: RestaurantLifecycleService.instance.isRenewEarly(resto),
      );
      return;
    }
    final product = auth.ownedListings.where((p) => p.id == id).firstOrNull;
    if (product == null) return;
    showRenewSheet(context, product, early: product.isExpiringSoon && product.status != TGListingStatus.expired);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    context.watch<ModerationService>();
    ModerationService.instance.ensureSeeded();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final tab = _tab;
    final type = widget.type ?? '';
    var items = [...auth.ownedListings, ...ModerationService.instance.sellerListings];
    items.sort(compareDashboardListings);
    items = switch (tab) {
      'expired' => items.where((p) => p.status == TGListingStatus.expired).toList(),
      'expiring' => items.where((p) => p.isExpiringSoon).toList(),
      'active' => items.where((p) => p.isActive).toList(),
      'review' => items.where((p) => p.status == TGListingStatus.underReview).toList(),
      'drafts' => items.where((p) => p.status == TGListingStatus.draft || p.status == TGListingStatus.paymentPending).toList(),
      'sold' => items.where((p) => p.status == TGListingStatus.sold).toList(),
      _ => items,
    };
    var restos = RestaurantService.instance.ownedBy(auth.userId);
    restos = switch (tab) {
      'expired' => restos.where((r) => r.status == RestaurantListingStatus.expired).toList(),
      'expiring' => restos.where((r) => r.isExpiringSoon()).toList(),
      'active' => restos.where((r) => r.status == RestaurantListingStatus.active).toList(),
      'review' => restos.where((r) => r.status == RestaurantListingStatus.underReview || r.status == RestaurantListingStatus.pendingAuthorization).toList(),
      'drafts' => restos.where((r) => r.status == RestaurantListingStatus.draft || r.status == RestaurantListingStatus.paymentPending).toList(),
      'sold' => restos.where((r) => r.status == RestaurantListingStatus.sold).toList(),
      _ => restos,
    };
    if (type == 'restaurant') items = const [];
    if (type == 'equipment') restos = const [];
    items = items.where((p) => _matches(p.title, p.listingNo)).toList();
    restos = restos.where((r) => _matches(r.title, r.listingNo)).toList();
    final expiredN = auth.ownedExpired.length;
    final renewableN = auth.ownedListings
        .where((p) => p.source != TGListingSource.store && (p.isActive || p.status == TGListingStatus.expired))
        .length;

    return TGPageScaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(
                        items: [
                          TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                          TGBreadcrumbItem(label: context.t('ui_my_listings')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const TGDashboardNav(current: TGDashboardSection.listings),
                      const SizedBox(height: 12),
                      _DashboardHeading(phone: phone, filter: tab == 'all' ? null : _Tabs.label(context, tab)),
                      if (auth.storePlan == null) ...[
                        const SizedBox(height: 10),
                        _FreeSlotsDots(auth: auth),
                      ],
                      const SizedBox(height: 14),
                      _Tabs(current: tab, onSelect: (f) => _go(tab: f.isEmpty ? 'all' : f)),
                      const SizedBox(height: 10),
                      _TypeAndSearch(
                        type: type,
                        search: _search,
                        phone: phone,
                        onType: (t) => _go(type: t),
                        onSearch: _onSearch,
                        onSubmit: (v) {
                          _debounce?.cancel();
                          _go(q: v.trim());
                        },
                      ),
                      if (tab == 'promotions') ...[
                        const SizedBox(height: 14),
                        const TGPromotionsPanel(),
                      ] else ...[
                      if (expiredN > 0) ...[
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final fee = PricingConfigService.instance.config.defaultListingFeePln;
                          return TGButton(
                            key: const Key('dashboard-renew-all'),
                            onPressed: () {
                              auth.beginCheckout(
                                TGCheckoutCart.renewBulk(
                                  ids: auth.ownedExpired.map((p) => p.id).toList(),
                                  unitFee: fee,
                                  listingDays: PricingConfigService.instance.config.defaultListingDays,
                                ),
                              );
                              context.go('/add-product/checkout');
                            },
                            label: context.t('ui_renew_all_expired', {
                              'n': '$expiredN',
                              'fee': '${expiredN * fee}',
                            }),
                            height: 44,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          );
                        }),
                      ],
                      if (auth.storePlan == null &&
                          PricingConfigService.instance.config.shouldNudgeBasicStore(
                            paidBasket30dEqPln: expiredN * PricingConfigService.instance.config.defaultListingFeePln,
                            listingCount: renewableN,
                          )) ...[
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final cfg = PricingConfigService.instance.config;
                          final fee = cfg.defaultListingFeePln;
                          final n = cfg.storeNudgeMinListings;
                          return WizardCard(
                            key: const Key('dashboard-basic-store-card'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.t('ui_basic_store_nudge', {
                                      'n': '$n',
                                      'fee': '$fee',
                                      'sum': '${n * fee}',
                                      'store': '${cfg.basicStoreMonthlyPln}',
                                    }),
                                    style: theme.titleSmall.override(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                TGButton(
                                  onPressed: () {
                                    TGAnalytics.emit('basic_store_nudge_click');
                                    context.go('/plans');
                                  },
                                  label: context.t('uyum_see_basic_store'),
                                  variant: TGButtonVariant.outline,
                                  height: 40,
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 18),
                      ..._restoDashboardCards(context, auth, theme),
                      if (items.isEmpty && restos.isEmpty)
                        Text(context.t('ui_no_results'), style: theme.bodyMedium)
                      else ...[
                        for (final p in items) ...[
                          ListingRow(
                            product: p,
                            onRenew: p.status == TGListingStatus.expired
                                ? () {
                                    TGAnalytics.emit('renew_click', {'id': p.id});
                                    showRenewSheet(context, p);
                                  }
                                : null,
                            onRenewEarly: p.isExpiringSoon ? () => showRenewSheet(context, p, early: true) : null,
                            onResume: p.status == TGListingStatus.paymentPending
                                ? () {
                                    final fee = PricingConfigService.instance.config.defaultListingFeePln;
                                    auth.beginCheckout(
                                      TGCheckoutCart.listing(
                                        listingId: p.id,
                                        listingNo: p.listingNo,
                                        listingFee: fee,
                                        promoteFee: 0,
                                        promoteDays: 0,
                                        listingDays: PricingConfigService.instance.config.defaultListingDays,
                                      ),
                                    );
                                    context.go('/add-product/checkout');
                                  }
                                : null,
                          ),
                          if (tab == 'expired' && p.status == TGListingStatus.expired && auth.ownsListing(p)) RenewOffersCard(product: p),
                        ],
                        for (final r in restos) ...[
                          RestaurantListingRow(listing: r),
                          if (tab == 'expired' && r.status == RestaurantListingStatus.expired) RenewOffersCard(restaurant: r),
                        ],
                      ],
                      ], // end non-promotions tab
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 64),
            const TGFooter(),
          ],
        ),
      ),
    );
  }
}

class _FreeSlotsDots extends StatelessWidget {
  const _FreeSlotsDots({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Text(
          context.t('ui_dashboard_free_used', {
            'used': '${auth.freeSlotsUsed}',
            'total': '${auth.freeListingsTotal}',
          }),
          style: theme.bodySmall.override(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 10),
        for (var i = 0; i < auth.freeListingsTotal; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < auth.freeSlotsUsed ? theme.primary : theme.tertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.current, required this.onSelect});
  final String current;
  final ValueChanged<String> onSelect;

  static String label(BuildContext context, String id) => switch (id) {
        'all' => context.t('ui_all'),
        'active' => context.t('dash_tab_active'),
        'expiring' => context.t('ui_filter_expiring'),
        'expired' => context.t('ui_filter_expired'),
        'drafts' => context.t('dash_tab_drafts'),
        'review' => context.t('dash_tab_review'),
        'sold' => context.t('dash_tab_sold'),
        'promotions' => context.t('ui_promotions_tab'),
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    final selected = current.isEmpty ? 'all' : current;
    return Semantics(
      container: true,
      label: context.t('dash_listings_tabs_sem'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in ListingsDashboardPage.tabs)
            ChoiceChip(
              key: Key('listings-tab-$id'),
              label: Text(label(context, id)),
              selected: selected == id,
              onSelected: (_) => onSelect(id == 'all' ? '' : id),
            ),
        ],
      ),
    );
  }
}

class _TypeAndSearch extends StatelessWidget {
  const _TypeAndSearch({
    required this.type,
    required this.search,
    required this.phone,
    required this.onType,
    required this.onSearch,
    required this.onSubmit,
  });

  final String type;
  final TextEditingController search;
  final bool phone;
  final ValueChanged<String> onType;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in const ['equipment', 'restaurant'])
          FilterChip(
            key: Key('listings-type-$t'),
            label: Text(context.t(t == 'equipment' ? 'dash_type_equipment' : 'dash_type_restaurant')),
            selected: type == t,
            onSelected: (_) => onType(type == t ? '' : t),
          ),
      ],
    );
    final field = Semantics(
      textField: true,
      label: context.t('dash_listings_search'),
      child: TextField(
        key: const Key('listings-search'),
        controller: search,
        onChanged: onSearch,
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: context.t('dash_listings_search'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.pill)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TGRadius.pill),
            borderSide: const BorderSide(color: TGColors.cta, width: 2),
          ),
        ),
      ),
    );
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [chips, const SizedBox(height: 8), field]);
    }
    return Row(
      children: [
        chips,
        const SizedBox(width: 16),
        Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: field)),
      ],
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({required this.phone, required this.filter});
  final bool phone;
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = Text(context.t('ui_my_listings'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900));
    final subtitle = filter == null || filter!.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(filter!, style: theme.bodySmall.override(color: theme.secondaryText)),
          );
    final add = TGButton(
      key: const Key('dashboard-add-product'),
      onPressed: () => showAddListingChooser(context),
      label: context.t('ui_add_product_plus'),
      height: 44,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          if (subtitle != null) subtitle,
          const SizedBox(height: 12),
          add,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, if (subtitle != null) subtitle],
          ),
        ),
        const SizedBox(width: 16),
        add,
      ],
    );
  }
}

List<Widget> _restoDashboardCards(BuildContext context, FakeAuthState auth, FlutterFlowTheme theme) {
  final post = RestaurantPostPublishService.instance..ensureSeeded();
  final sync = RestaurantInventorySyncService.instance..ensureSeeded();
  final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
  final out = <Widget>[];

  for (final r in RestaurantService.instance.ownedBy(auth.userId)) {
    final cards = post.dashboardCards(r.id);
    if (cards.contains('details')) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WizardCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Listing details ${r.detailsFilledCount}/${RestaurantListing.detailsSectionTotal}', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('Filters use garden, alcohol permit and play area.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/restaurants/${r.listingNo}/details'),
            ),
          ),
        ),
      );
    }
    if (cards.contains('equipment')) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WizardCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Equipment ${r.inventory.length} items · ${r.separatelyListedCount} listed separately',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(post.equipmentCardCopy(r, freeLeft: auth.freeListingsLeft).resolveOf(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/dashboard/bulk-add'),
            ),
          ),
        ),
      );
    }
  }

  for (final card in sync.syncCardsFor(auth.userId)) {
    out.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WizardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Update ${card.item.name}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                'You marked this as sold. Is it still part of restaurant listing ${card.listing.listingNo}?',
                style: theme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (phone) ...[
                TGButton(
                  onPressed: () {
                    sync.removeFromTransfer(listingId: card.listing.id, itemId: card.item.id, actorId: auth.userId);
                    showTGToast(context, 'Removed from transfer list', duration: const Duration(seconds: 10), action: SnackBarAction(label: 'Undo', onPressed: () => sync.undo(card.listing.id, card.item.id)));
                  },
                  label: 'Remove from the transfer list',
                  height: 40,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                const SizedBox(height: 6),
                TGButton(
                  onPressed: () async {
                    int? qty = card.item.qty;
                    if (card.item.qty > 1) {
                      qty = await showDialog<int>(
                        context: context,
                        builder: (ctx) {
                          var left = card.item.qty - 1;
                          return AlertDialog(
                            title: const Text('How many are left?'),
                            content: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantity left'),
                              onChanged: (v) => left = int.tryParse(v) ?? left,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, left), child: const Text('Save')),
                            ],
                          );
                        },
                      );
                    }
                    if (!context.mounted) return;
                    sync.stillIncluded(listingId: card.listing.id, itemId: card.item.id, actorId: auth.userId, qtyLeft: qty);
                    showTGToast(context, 'Still included');
                  },
                  label: 'Still included · I have another unit',
                  variant: TGButtonVariant.outline,
                  height: 40,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                TextButton(
                  onPressed: () => context.go('/restaurants/${card.listing.listingNo}/details?section=otherInfo'),
                  child: const Text('Edit description'),
                ),
              ] else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TGButton(
                      onPressed: () {
                        sync.removeFromTransfer(listingId: card.listing.id, itemId: card.item.id, actorId: auth.userId);
                        showTGToast(context, 'Removed from transfer list');
                      },
                      label: 'Remove from the transfer list',
                      height: 40,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                    TGButton(
                      onPressed: () {
                        sync.stillIncluded(listingId: card.listing.id, itemId: card.item.id, actorId: auth.userId);
                        showTGToast(context, 'Still included');
                      },
                      label: 'Still included · I have another unit',
                      variant: TGButtonVariant.outline,
                      height: 40,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                    TextButton(
                      onPressed: () => context.go(card.listing.detailPath),
                      child: const Text('Edit description'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  if (out.isNotEmpty) out.add(const SizedBox(height: 8));
  return out;
}

Future<void> showAddListingChooser(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.t('ui_what_are_you_listing'), style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.kitchen_outlined),
              title: Text(ctx.t('ui_listing_kind_equipment'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ctx.t('ui_listing_kind_equipment_sub')),
              onTap: () {
                Navigator.pop(ctx);
                TGNav.addProduct(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: Text(ctx.t('ui_bulk_add_equipment'), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/dashboard/bulk-add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(ctx.t('ui_listing_kind_restaurant'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ctx.t('ui_listing_kind_restaurant_sub')),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/restaurants/new');
              },
            ),
          ],
        ),
      ),
    ),
  );
}
