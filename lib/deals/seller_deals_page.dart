import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/deals/deal_row.dart';
import 'package:twoja_gastromania/deals/review_check_card.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_filter_menu.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

class SellerDealsPage extends StatelessWidget {
  const SellerDealsPage({super.key, this.tab});

  static const routeName = 'SellerDeals';
  static const routePath = '/dashboard/deals';

  final String? tab;

  @override
  Widget build(BuildContext context) {
    DealService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final current = tab ?? 'all';
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: DealService.instance,
        builder: (context, _) {
          final items = _filter(DealService.instance.forSeller(auth.userId), current);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_deals')),
                      ]),
                      const SizedBox(height: 16),
                      const TGDashboardNav(current: TGDashboardSection.deals),
                      const SizedBox(height: 16),
                      Text(context.t('ui_deals'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      TGFilterMenu(
                        title: context.t('ui_deals_filter'),
                        currentId: current,
                        onSelect: (t) => TGNav.dashboardDeals(context, tab: t),
                        options: [
                          for (final t in const ['all', 'waiting', 'requests', 'confirmed', 'declined', 'moderation'])
                            TGFilterOption(id: t, label: context.t('ui_deals_tab_$t')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(context.t('ui_no_deals'), style: theme.bodyMedium.override(color: theme.secondaryText)),
                        )
                      else
                        for (final d in items) _sellerRow(d, current),
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

  List<TGDeal> _filter(List<TGDeal> all, String tab) => switch (tab) {
        'waiting' => all.where((d) => d.status == TGDealStatus.pendingBuyer).toList(),
        'requests' => all.where(_isReviewCheck).toList(),
        'confirmed' => all.where((d) => d.isConfirmed).toList(),
        'declined' => all.where((d) => d.status == TGDealStatus.declinedByBuyer || d.status == TGDealStatus.declinedBySeller || d.status == TGDealStatus.expired || d.status == TGDealStatus.cancelled).toList(),
        'moderation' => all.where((d) => d.status == TGDealStatus.inModeration).toList(),
        _ => all,
      };

  bool _isReviewCheck(TGDeal d) {
    if (d.source != TGDealSource.reviewFirst) return d.status == TGDealStatus.pendingSeller;
    if (d.status == TGDealStatus.pendingSeller || d.status == TGDealStatus.inModeration) return true;
    final until = d.unitRestoreUntil;
    return until != null && TGClock.now().isBefore(until);
  }

  Widget _sellerRow(TGDeal d, String current) {
    final review = DealService.instance.reviewForDeal(d.id);
    if (review != null &&
        (current == 'requests' ||
            review.state == TGPurchaseReviewState.awaitingSeller ||
            review.state == TGPurchaseReviewState.pendingCheck ||
            review.state == TGPurchaseReviewState.suspendedObjection ||
            (d.unitRestoreUntil != null && TGClock.now().isBefore(d.unitRestoreUntil!)))) {
      return ReviewCheckCard(deal: d, review: review);
    }
    return DealRow(deal: d, sellerView: true);
  }
}
