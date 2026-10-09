import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/deals/confirm_deal_sheet.dart';
import 'package:twoja_gastromania/deals/deal_row.dart';
import 'package:twoja_gastromania/deals/review_composer.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_filter_menu.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

class BuyerDealsPage extends StatefulWidget {
  const BuyerDealsPage({super.key, this.tab, this.dealId, this.confirm = false});

  static const routeName = 'BuyerDeals';
  static const routePath = '/account/deals';

  final String? tab;
  final String? dealId;
  final bool confirm;

  @override
  State<BuyerDealsPage> createState() => _BuyerDealsPageState();
}

class _BuyerDealsPageState extends State<BuyerDealsPage> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink());
  }

  @override
  void didUpdateWidget(covariant BuyerDealsPage old) {
    super.didUpdateWidget(old);
    if (old.dealId != widget.dealId || old.confirm != widget.confirm) {
      _opened = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink());
    }
  }

  void _openDeepLink() {
    if (!mounted || _opened) return;
    final id = widget.dealId;
    if (id == null || id.isEmpty) return;
    _opened = true;
    final auth = context.read<FakeAuthState>();
    DealService.instance.ensureSeeded();
    final deal = DealService.instance.byId(id);
    if (deal == null || deal.buyerId != auth.userId) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('ui_deal_access_denied')),
          content: Text(context.t('ui_deal_wrong_account')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close')))],
        ),
      );
      return;
    }
    if (widget.confirm && deal.status == TGDealStatus.pendingBuyer) {
      showConfirmDealSheet(context, deal);
    }
  }

  @override
  Widget build(BuildContext context) {
    DealService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final current = widget.tab ?? 'needs';
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: DealService.instance,
        builder: (context, _) {
          final all = DealService.instance.forBuyer(auth.userId);
          final items = switch (current) {
            'confirmed' => all.where((d) => d.isConfirmed).toList(),
            'declined' => all.where((d) => d.status == TGDealStatus.declinedByBuyer || d.status == TGDealStatus.declinedBySeller || d.status == TGDealStatus.expired).toList(),
            'all' => all,
            _ => all.where((d) => d.status == TGDealStatus.pendingBuyer).toList(),
          };
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_your_deals')),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text(context.t('ui_your_deals'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900))),
                          TGButton(
                            key: const Key('review-a-purchase'),
                            onPressed: () => showReviewComposer(context),
                            label: context.t('ui_review_a_purchase'),
                            variant: TGButtonVariant.outline,
                            height: 40,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TGFilterMenu(
                        title: context.t('ui_deals_filter'),
                        currentId: current,
                        onSelect: (t) => TGNav.accountDeals(context, tab: t),
                        options: [
                          for (final t in const ['needs', 'confirmed', 'declined', 'all'])
                            TGFilterOption(id: t, label: context.t('ui_buyer_tab_$t')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(context.t('ui_no_deals'), style: theme.bodyMedium.override(color: theme.secondaryText)),
                        )
                      else
                        for (final d in items)
                          DealRow(
                            deal: d,
                            sellerView: false,
                            onConfirm: () => showConfirmDealSheet(context, d),
                            onOpen: d.status == TGDealStatus.pendingBuyer ? () => showConfirmDealSheet(context, d) : null,
                          ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
