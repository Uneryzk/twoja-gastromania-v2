import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';

/// Post-publish Showcase (VITRIN-2): Bold / Glow / Spotlight cards for the user's listing.
class TGShowcaseSection extends StatefulWidget {
  const TGShowcaseSection({
    super.key,
    required this.product,
    this.onDismissed,
    this.onPurchased,
  });

  final TGProduct product;
  final VoidCallback? onDismissed;
  final ValueChanged<Promotion>? onPurchased;

  @override
  State<TGShowcaseSection> createState() => _TGShowcaseSectionState();
}

class _TGShowcaseSectionState extends State<TGShowcaseSection> {
  PromotionTier? _tier;
  int _duration = PricingConfigService.instance.config.promotions.defaultDays;
  bool _paying = false;
  bool _dismissed = false;
  final _formKey = GlobalKey<PaymentFormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TGAnalytics.track('showcase_view', {'listingId': widget.product.id});
    });
  }

  PricingConfig get _cfg => PricingConfigService.instance.config;

  int get _listPrice {
    final t = _tier;
    if (t == null) return 0;
    return _cfg.promoFeePln(t, _duration);
  }

  int _paidPrice(String sellerId) {
    final list = _listPrice;
    if (list <= 0) return 0;
    // Founder applies to Bold/Glow/Spotlight; not combined with credit.
    return TGFounderService.instance.discountedPrice(sellerId, list);
  }

  bool _fitsListing() {
    final ends = widget.product.expiresAt;
    if (ends == null) return true;
    final start = PromotionService.instance.isAtCapacity(_tier!)
        ? PromotionService.instance.nextAvailableStart(_tier!)
        : TGClock.now();
    return PromotionService.instance.promoFitsListing(
      listingEndsAt: ends,
      promoDays: _duration,
      startAt: start,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < 400;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final svc = PromotionService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_showcase_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_showcase_sub'), style: theme.bodyMedium.override(color: theme.secondaryText)),
        const SizedBox(height: 18),
        Semantics(
          label: context.t('ui_showcase_tier_group'),
          child: phone
              ? Column(children: [for (final t in PromotionTier.values) ...[_tierCard(t, reduce), const SizedBox(height: 12)]])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < PromotionTier.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _tierCard(PromotionTier.values[i], reduce)),
                    ],
                  ],
                ),
        ),
        if (_tier != null) ...[
          const SizedBox(height: 16),
          Text(context.t('ui_promo_duration'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Semantics(
            label: context.t('ui_promo_duration'),
            child: SegmentedButton<int>(
              segments: [
                for (final d in PricingConfigService.instance.config.promotions.durations)
                  ButtonSegment(value: d, label: Text(DurationFormatter.daysOf(context, d))),
              ],
              selected: {_duration},
              onSelectionChanged: (s) => setState(() => _duration = s.first),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduce ? 0 : 150),
            child: Text(
              key: ValueKey('$_tier-$_duration-${_paidPrice(auth.userId)}'),
              '${_paidPrice(auth.userId)} PLN · ${_cfg.perDayLabel(_listPrice, _duration)}',
              style: theme.titleMedium.override(fontWeight: FontWeight.w900),
            ),
          ),
          if (svc.isAtCapacity(_tier!)) ...[
            const SizedBox(height: 8),
            Text(
              context.t('ui_next_available', {
                'date': DateFormat('d MMM').format(svc.nextAvailableStart(_tier!)),
              }),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          ],
          if (!_fitsListing()) ...[
            const SizedBox(height: 8),
            Text(context.t('ui_promo_needs_renew'), style: theme.bodySmall.override(color: TGColors.rating, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 14),
          if (_fitsListing())
            PaymentForm(
              key: _formKey,
              amountPln: _paidPrice(auth.userId).toDouble(),
              billingKind: TGPaymentKind.promotion,
              billingDescription: tgPromoBillingLabel(_tier!, _duration),
              billingListingId: widget.product.id,
              billingListingNo: widget.product.listingNo,
              autofocusBlik: false,
              onWaitingChanged: (v) => setState(() => _paying = v),
              onPaid: () => _buy(auth),
            ),
          if (phone && _fitsListing()) ...[
            const SizedBox(height: 8),
            TGButton(
              onPressed: _paying ? null : () => _formKey.currentState?.tryPay(),
              label: context.t('ui_continue_payment'),
              height: 48,
            ),
          ],
        ],
        const SizedBox(height: 12),
        TGButton(
          onPressed: () {
            TGAnalytics.track('showcase_dismiss', {'listingId': widget.product.id});
            setState(() => _dismissed = true);
            widget.onDismissed?.call();
          },
          label: context.t('ui_not_now'),
          variant: TGButtonVariant.outline,
          height: 48,
        ),
        if (_bannerAllowed) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/dashboard/advertising?tab=banners'),
            child: Text(context.t('ui_want_banner_spot')),
          ),
        ],
      ],
    );
  }

  bool get _bannerAllowed {
    final rev = TGRevenueConfigService.instance.config;
    return rev.flags.bannerAds && rev.phase >= 2;
  }

  Widget _tierCard(PromotionTier tier, bool reduce) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _tier == tier;
    final where = switch (tier) {
      PromotionTier.bold => context.t('ui_showcase_where_bold'),
      PromotionTier.glow => context.t('ui_showcase_where_glow'),
      PromotionTier.spotlight => context.t('ui_showcase_where_spotlight'),
    };
    final name = switch (tier) {
      PromotionTier.bold => 'Bold',
      PromotionTier.glow => 'Glow',
      PromotionTier.spotlight => 'Spotlight',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(TGRadius.card),
        onTap: () {
          setState(() => _tier = tier);
          TGAnalytics.track('promo_select', {'tier': tier.name, 'listingId': widget.product.id});
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduce ? 0 : 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TGRadius.card),
            border: Border.all(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
            color: theme.secondaryBackground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: Duration(milliseconds: reduce ? 0 : 150),
                    child: Icon(Icons.check_circle, color: theme.primary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: IgnorePointer(
                  child: FittedBox(
                    child: SizedBox(
                      width: 220,
                      child: TGProductCard(
                        product: widget.product,
                        promotionTier: tier,
                        forceFeaturedBadge: tier != PromotionTier.bold,
                        showSeller: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(where, style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 6),
              Text(
                '${_cfg.promoFeePln(tier, _duration)} PLN',
                style: theme.labelLarge.override(fontWeight: FontWeight.w800),
              ),
              Text(context.t('ui_select'), style: theme.bodySmall.override(color: theme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buy(FakeAuthState auth) async {
    final tier = _tier;
    if (tier == null) return;
    final list = _listPrice;
    final paid = _paidPrice(auth.userId);
    final rate = TGFounderService.instance.activeDiscountRate(auth.userId);
    if (rate > 0 && list > paid) {
      TGFounderService.instance.recordSavings(
        sellerId: auth.userId,
        item: TGFounderDiscountItem.promote30,
        listPrice: list,
        paidPrice: paid,
        discountPct: rate,
      );
    }
    final start = PromotionService.instance.isAtCapacity(tier)
        ? PromotionService.instance.nextAvailableStart(tier)
        : null;
    final promo = PromotionService.instance.purchase(
      ownerId: auth.userId,
      kind: PromotionTargetKind.listing,
      targetRef: widget.product.id,
      tier: tier,
      durationDays: _duration,
      pricePln: paid,
      source: PromotionSource.paid,
      listingEndsAt: widget.product.expiresAt,
      startsAt: start,
      paymentId: 'pay_showcase_${DateTime.now().millisecondsSinceEpoch}',
    );
    // Mirror legacy flags for cards that still read isPromoted.
    auth.upsertOwned(widget.product.copyWith(
      isPromoted: promo.status == PromotionStatus.active,
      promotedUntil: promo.endsAt,
    ));
    widget.onPurchased?.call(promo);
    if (!mounted) return;
    setState(() => _dismissed = true);
  }
}
