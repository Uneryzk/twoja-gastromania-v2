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
    (id: 'basic', name: 'Basic Store', monthly: 199, featured: false, features: ['15 active listings', 'Verified Seller badge', 'Store page']),
    (id: 'pro', name: 'Pro Store', monthly: 499, featured: true, features: ['50 active listings', '3 featured listings', 'Customer quote tools']),
    (id: 'enterprise', name: 'Enterprise Store', monthly: 899, featured: false, features: ['Unlimited listings', 'Banner ad slot', 'All Special Order leads']),
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
                          const TGBreadcrumbItem(label: 'Store plans'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Store plans', style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(context.t('ui_invoice_at_checkout'), style: theme.bodySmall.override(color: theme.secondaryText)),
                    const SizedBox(height: 16),
                    WizardSegmented(
                      value: _period,
                      options: const [
                        (TGBillingPeriod.monthly, 'Monthly'),
                        (TGBillingPeriod.sixMonths, '6 months −10%'),
                        (TGBillingPeriod.yearly, 'Yearly 2 months free'),
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
                      'Auto-renewal is available with card only. With BLIK or Przelewy24 we\'ll remind you before your plan ends.',
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
  final ({String id, String name, int monthly, bool featured, List<String> features}) plan;
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
              child: const Text('Most popular', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          Text(plan.name, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: price),
            duration: TGMotion.of(context, TGMotion.price),
            builder: (context, v, _) => Text(formatMoneyPln(v, forceCents: period != TGBillingPeriod.monthly), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
          ),
          if (period != TGBillingPeriod.monthly)
            Text(formatMoneyPln(plan.monthly), style: theme.bodySmall.override(color: theme.secondaryText, decoration: TextDecoration.lineThrough)),
          if (eq != null)
            Text('${formatMoneyPln(eq, forceCents: true)} / month', style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: theme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TGButton(
            onPressed: onChoose,
            label: 'Choose ${plan.name.split(' ').first}',
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
            variant: plan.featured ? TGButtonVariant.primary : TGButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}
