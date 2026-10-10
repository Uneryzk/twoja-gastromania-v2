import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

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

/// Debug long-press: switch mock role and entitlement scenario.
Future<void> showTGDevSwitch(BuildContext context, FakeAuthState auth) async {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return;
  final origin = box.localToGlobal(Offset.zero);
  final picked = await showMenu<Object>(
    context: context,
    color: FlutterFlowTheme.of(context).secondaryBackground,
    position: RelativeRect.fromLTRB(origin.dx, origin.dy + box.size.height + 6, origin.dx + 1, 0),
    items: [
      const PopupMenuItem(enabled: false, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
      for (final r in TGUserRole.values)
        PopupMenuItem(value: r, child: Text(r.label, style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w600))),
      const PopupMenuDivider(),
      const PopupMenuItem(enabled: false, child: Text('Listings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
      for (final s in TGEntitlementScenario.values)
        PopupMenuItem(value: s, child: Text(_AccountSheet.scenarioLabel(s), style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w600))),
      const PopupMenuDivider(),
      const PopupMenuItem(enabled: false, child: Text('Store owner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
      for (final p in StoreOwnerDevPick.all)
        PopupMenuItem(value: p, child: Text(p.label, style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w600))),
      const PopupMenuDivider(),
      const PopupMenuItem(enabled: false, child: Text('Buyers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
      for (final p in BuyerDevPick.all)
        PopupMenuItem(value: p, child: Text(p.label, style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w600))),
      const PopupMenuDivider(),
      const PopupMenuItem(enabled: false, child: Text('Clock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
      const PopupMenuItem(value: 1, child: Text('Advance time +1 days')),
      const PopupMenuItem(value: 2, child: Text('Advance time +2 days')),
      const PopupMenuItem(value: 3, child: Text('Advance time +3 days')),
      const PopupMenuItem(value: 5, child: Text('Advance time +5 days')),
      const PopupMenuItem(value: 10, child: Text('Advance time +10 days')),
      const PopupMenuItem(value: 14, child: Text('Advance time +14 days')),
      const PopupMenuItem(value: 25, child: Text('Advance time +25 days')),
    ],
  );
  if (picked is TGUserRole) auth.setRole(picked);
  if (picked is TGEntitlementScenario) auth.setScenario(picked);
  if (picked is StoreOwnerDevPick) auth.actAsStoreOwner(picked);
  if (picked is BuyerDevPick) auth.actAsBuyer(picked);
  if (picked is int) {
    DealService.instance.ensureSeeded();
    DealModerationService.instance.ensureSeeded();
    TGSpecialOrderService.instance.ensureSeeded();
    TGClock.advance(Duration(days: picked));
    DealService.instance.onClockAdvanced();
    DealModerationService.instance.onClockAdvanced();
    TGSpecialOrderService.instance.onClockAdvanced();
  }
}

/// B2B lead-gen: manufacturers receive the request with reference photos.
Future<void> showTGSpecialOrderSheet(BuildContext context) =>
    _showTGSheet(context, (_) => const _SpecialOrderSheet());

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
            title: context.t('ui_first_n_listings_free', {'n': '${TGPricing.freeListingQuota}'}),
            body: context.t('ui_free_listings_body', {'days': '${TGPricing.listingPeriodDays}'}),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.receipt_long_rounded,
            title: context.t('ui_listing_fee_title', {'fee': '${TGPricing.listingFeePln}', 'days': '${TGPricing.listingPeriodDays}'}),
            body: context.t('ui_listing_fee_body', {'fee': '${TGPricing.listingFeePln}', 'days': '${TGPricing.listingPeriodDays}'}),
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
          for (final plan in TGPricing.storePlans) ...[
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
        detail = context.t('ui_next_listing_fee', {'fee': '${TGPricing.listingFeePln}', 'days': '${TGPricing.listingPeriodDays}'});
        progress = 1;
      case TGHeaderPillKind.noListings:
        headline = context.t('ui_three_free_listings');
        detail = context.t('ui_first_three_free_detail');
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

  static String scenarioLabel(TGEntitlementScenario s) => switch (s) {
        TGEntitlementScenario.noListings => 'No listings yet – 3 free',
        TGEntitlementScenario.freeActive => '2 free left',
        TGEntitlementScenario.freeNoListingsLeft => '3 free slots used',
        TGEntitlementScenario.needsAttention => '1 listing needs attention',
        TGEntitlementScenario.listingExpiringSoon => '1 listing ends in 3d',
        TGEntitlementScenario.hasExpired => '2 expired · Renew',
        TGEntitlementScenario.storeSubscriber => 'B2B store subscriber',
      };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();

    return _SheetFrame(
      title: context.t('ui_your_account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (auth.role == TGUserRole.buyer) ...[
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
                    title: Text(scenarioLabel(v), style: theme.bodyMedium.override(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
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

// ---------------------------------------------------------------------------
// Special Order Hub
// ---------------------------------------------------------------------------

const _kSpecialOrderGallery = <String>[
  'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
  'assets/images/IMG_20200120_131650.jpg',
  'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp',
  'assets/images/Food_Prepering_table.jpg',
  'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg',
  'assets/images/Bar_&_Beverage_Equipment.jpg',
];

class _SpecialOrderSheet extends StatefulWidget {
  const _SpecialOrderSheet();

  @override
  State<_SpecialOrderSheet> createState() => _SpecialOrderSheetState();
}

class _SpecialOrderSheetState extends State<_SpecialOrderSheet> {
  final _need = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  int _photo = 0;

  @override
  void dispose() {
    _need.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final need = _need.text.trim();
    if (need.isEmpty) {
      showTGToast(context, context.t('ui_describe_equipment'), icon: Icons.info_outline);
      return;
    }
    Navigator.of(context).pop();
    showTGToast(context, context.t('ui_request_sent_mfr'), icon: Icons.send_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _SheetFrame(
      title: context.t('ui_special_order_hub'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('ui_special_order_intro'),
            style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.45),
          ),
          const SizedBox(height: 14),
          Text(context.t('ui_reference_gallery'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kSpecialOrderGallery.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final selected = i == _photo;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: context.t('ui_reference_photo_n', {'n': '${i + 1}'}),
                  child: GestureDetector(
                    onTap: () => setState(() => _photo = i),
                    child: AnimatedContainer(
                      duration: TGMotion.quick,
                      width: 148,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(TGRadius.input),
                        border: Border.all(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(TGRadius.input - 1),
                        child: Image.asset(
                          _kSpecialOrderGallery[i],
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _need,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.t('ui_what_do_you_need'),
              hintText: context.t('ui_special_order_hint'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            decoration: InputDecoration(labelText: context.t('ui_city'), hintText: 'Katowice'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: context.t('ui_phone'), hintText: '+48 …'),
          ),
          const SizedBox(height: 16),
          TGButton(onPressed: _submit, label: context.t('ui_send_to_manufacturers'), icon: Icons.send_rounded, height: 48),
        ],
      ),
    );
  }
}
