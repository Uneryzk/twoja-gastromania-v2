import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
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
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  static const routeName = 'StorePlans';
  static const routePath = '/plans';

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  TGBillingPeriod _period = TGBillingPeriod.monthly;
  late final PageController _pages = PageController(viewportFraction: 0.88, initialPage: 1);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static const _plans = [
    (id: 'basic', nameKey: 'ui_plan_basic_store', chooseKey: 'ui_choose_basic', monthly: 199, featured: false, featureKeys: ['ui_feat_15_listings', 'ui_feat_verified_badge', 'ui_feat_store_page']),
    (id: 'pro', nameKey: 'ui_plan_pro_store', chooseKey: 'ui_choose_pro', monthly: 499, featured: true, featureKeys: ['ui_feat_50_listings', 'ui_feat_3_featured', 'ui_feat_quote_tools']),
    (id: 'enterprise', nameKey: 'ui_plan_enterprise_store', chooseKey: 'ui_choose_enterprise', monthly: 899, featured: false, featureKeys: ['ui_feat_unlimited', 'ui_feat_banner', 'ui_feat_special_order']),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 700 ? 16.0 : 24.0;

    return TGPageScaffold(
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TGBreadcrumb(
                        items: [
                          TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                          TGBreadcrumbItem(label: context.t('ui_store_plans')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.t('ui_store_plans'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(context.t('ui_invoice_at_checkout'), style: theme.bodySmall.override(color: theme.secondaryText)),
                    const SizedBox(height: 16),
                    WizardSegmented(
                      value: _period,
                      options: [
                        (TGBillingPeriod.monthly, context.t('ui_billing_monthly')),
                        (TGBillingPeriod.sixMonths, context.t('ui_billing_six_months')),
                        (TGBillingPeriod.yearly, context.t('ui_billing_yearly')),
                      ],
                      onChanged: (v) {
                        setState(() => _period = v);
                        TGAnalytics.emit('plan_billing_toggle', {'period': v.name});
                      },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, c) {
                        final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
                        final stack = c.maxWidth < 1024 && !phone;
                        final cards = [
                          for (final p in _plans) _PlanCard(plan: p, period: _period, onChoose: () => _choose(p.id, p.monthly)),
                        ];
                        if (phone) {
                          return SizedBox(
                            height: 420,
                            child: PageView.builder(
                              controller: _pages,
                              padEnds: true,
                              itemCount: cards.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                child: cards[i],
                              ),
                            ),
                          );
                        }
                        if (stack) {
                          return Column(children: [for (final c in cards) ...[c, const SizedBox(height: 12)]]);
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('ui_auto_renew_note'),
                      style: theme.bodySmall.override(color: theme.secondaryText),
                      textAlign: TextAlign.center,
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
    );
  }

  void _choose(String id, int monthly) {
    final amount = TGPricing.storePrice(monthly, _period);
    context.read<FakeAuthState>().beginCheckout(TGCheckoutCart.store(planId: id, period: _period, amount: amount));
    context.go('/add-product/checkout');
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.period, required this.onChoose});
  final ({String id, String nameKey, String chooseKey, int monthly, bool featured, List<String> featureKeys}) plan;
  final TGBillingPeriod period;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final price = TGPricing.storePrice(plan.monthly, period);
    final eq = switch (period) {
      TGBillingPeriod.monthly => null,
      TGBillingPeriod.sixMonths => TGPricing.storeSixMonthsMonthlyEq(plan.monthly),
      TGBillingPeriod.yearly => TGPricing.storeYearlyMonthlyEq(plan.monthly),
    };
    return WizardCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.featured)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(99)),
              child: Text(context.t('ui_most_popular'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          Text(context.t(plan.nameKey), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: price),
            duration: TGMotion.of(context, TGMotion.price),
            builder: (context, v, _) => Text(formatMoneyPln(v, forceCents: period != TGBillingPeriod.monthly), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
          ),
          if (period != TGBillingPeriod.monthly)
            Text(formatMoneyPln(plan.monthly), style: theme.bodySmall.override(color: theme.secondaryText, decoration: TextDecoration.lineThrough)),
          if (eq != null)
            Text(context.t('ui_per_month_eq', {'price': formatMoneyPln(eq, forceCents: true)}), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          for (final f in plan.featureKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: theme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.t(f))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TGButton(
            onPressed: onChoose,
            label: context.t(plan.chooseKey),
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
            variant: plan.featured ? TGButtonVariant.primary : TGButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}
