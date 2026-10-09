import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/dashboard/listing_row.dart';
import 'package:twoja_gastromania/dashboard/renew_sheet.dart';
import 'package:twoja_gastromania/deals/sold_flow_sheet.dart';
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
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

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
  const ListingsDashboardPage({super.key, this.filter, this.renewId, this.renewedId, this.soldId});

  static const routeName = 'ListingsDashboard';
  static const routePath = '/dashboard/listings';

  final String? filter;
  final String? renewId;
  final String? renewedId;
  final String? soldId;

  @override
  State<ListingsDashboardPage> createState() => _ListingsDashboardPageState();
}

class _ListingsDashboardPageState extends State<ListingsDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleQuery());
  }

  @override
  void didUpdateWidget(covariant ListingsDashboardPage old) {
    super.didUpdateWidget(old);
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
      final until = DateFormat('d MMM y').format(p?.expiresAt ?? DateTime.now());
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
    final tab = widget.filter ?? 'all';
    var items = [...auth.ownedListings, ...ModerationService.instance.sellerListings];
    items.sort(compareDashboardListings);
    items = switch (tab) {
      'expired' => items.where((p) => p.status == TGListingStatus.expired).toList(),
      'expiring' => items.where((p) => p.isExpiringSoon).toList(),
      'active' => items.where((p) => p.isActive).toList(),
      'review' => items.where((p) => p.status == TGListingStatus.underReview).toList(),
      'drafts' => items.where((p) => p.status == TGListingStatus.draft).toList(),
      _ => items,
    };
    final expiredN = auth.ownedExpired.length;

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
                      _DashboardHeading(phone: phone, filter: widget.filter),
                      if (auth.storePlan == null) ...[
                        const SizedBox(height: 10),
                        _FreeSlotsDots(auth: auth),
                      ],
                      const SizedBox(height: 14),
                      _Tabs(current: tab, attention: auth.ownedNeedsAttention.isNotEmpty, onSelect: (f) => TGNav.dashboardListings(context, filter: f)),
                      if (expiredN > 0) ...[
                        const SizedBox(height: 12),
                        TGButton(
                          key: const Key('dashboard-renew-all'),
                          onPressed: () {
                            auth.beginCheckout(
                              TGCheckoutCart.renewBulk(ids: auth.ownedExpired.map((p) => p.id).toList(), unitFee: TGPricing.listingFeePln),
                            );
                            context.go('/add-product/checkout');
                          },
                          label: context.t('ui_renew_all_expired', {
                            'n': '$expiredN',
                            'fee': '${expiredN * TGPricing.listingFeePln}',
                          }),
                          height: 44,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      ],
                      if (expiredN >= 4) ...[
                        const SizedBox(height: 12),
                        WizardCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '4 × ${TGPricing.listingFeePln} = ${4 * TGPricing.listingFeePln} PLN vs Basic Store 199 PLN',
                                  style: theme.titleSmall.override(fontWeight: FontWeight.w800),
                                ),
                              ),
                              TGButton(
                                onPressed: () {
                                  TGAnalytics.emit('basic_store_nudge_click');
                                  context.go('/plans');
                                },
                                label: 'See Basic Store',
                                variant: TGButtonVariant.outline,
                                height: 40,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (items.isEmpty)
                        Text(context.t('ui_no_results'), style: theme.bodyMedium)
                      else
                        for (final p in items)
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
                                    auth.beginCheckout(
                                      TGCheckoutCart.listing(listingId: p.id, listingNo: p.listingNo, listingFee: TGPricing.listingFeePln, promoteFee: 0, promoteDays: 0),
                                    );
                                    context.go('/add-product/checkout');
                                  }
                                : null,
                          ),
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
  const _Tabs({required this.current, required this.onSelect, this.attention = false});
  final String current;
  final ValueChanged<String> onSelect;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('all', context.t('ui_all')),
      ('active', 'Active'),
      ('expired', context.t('ui_filter_expired')),
      if (attention) ('review', context.t('ui_filter_review')),
      ('drafts', 'Drafts'),
    ];
    final selected = current == 'expiring' ? 'active' : (current.isEmpty ? 'all' : current);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in items)
          ChoiceChip(
            label: Text(e.$2),
            selected: selected == e.$1,
            onSelected: (_) => onSelect(e.$1 == 'all' ? '' : e.$1),
          ),
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
            child: Text(
              filter == 'expired'
                  ? context.t('ui_filter_expired')
                  : filter == 'review'
                      ? context.t('ui_filter_review')
                      : context.t('ui_filter_expiring'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          );
    final add = TGButton(
      key: const Key('dashboard-add-product'),
      onPressed: () => TGNav.addProduct(context),
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
