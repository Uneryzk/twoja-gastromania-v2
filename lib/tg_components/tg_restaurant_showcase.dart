import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_showcase_section.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';

/// Restaurant post-publish Showcase (Success → Showcase → RESTO-4 Next steps).
class TGRestaurantShowcaseSection extends StatefulWidget {
  const TGRestaurantShowcaseSection({
    super.key,
    required this.listing,
    this.onDismissed,
    this.onPurchased,
  });

  final RestaurantListing listing;
  final VoidCallback? onDismissed;
  final ValueChanged<Promotion>? onPurchased;

  @override
  State<TGRestaurantShowcaseSection> createState() => _TGRestaurantShowcaseSectionState();
}

class _TGRestaurantShowcaseSectionState extends State<TGRestaurantShowcaseSection> {
  PromotionTier? _tier;
  int _duration = PricingConfigService.instance.config.promotions.defaultDays;
  bool _dismissed = false;
  final _formKey = GlobalKey<PaymentFormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TGAnalytics.track('showcase_view', {'listingId': widget.listing.id, 'kind': 'restaurant'});
    });
  }

  PricingConfig get _cfg => PricingConfigService.instance.config;

  int get _listPrice {
    final t = _tier;
    if (t == null) return 0;
    return _cfg.promoFeePln(t, _duration);
  }

  int _paid(String sellerId) {
    final list = _listPrice;
    if (list <= 0) return 0;
    return TGFounderService.instance.discountedPrice(sellerId, list);
  }

  bool _fits() {
    final ends = widget.listing.expiresAt;
    if (ends == null || _tier == null) return true;
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
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final paid = _tier == null ? 0 : _paid(auth.userId);
    final list = _listPrice;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(context.t('ui_showcase_title'), style: theme.titleLarge.override(fontWeight: FontWeight.w700, letterSpacing: 0.40)),
        ),
        const SizedBox(height: 4),
        Text(context.t('ui_showcase_sub'), style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.35)),
      ],
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_standard_listing'), style: theme.labelMedium.override(fontWeight: FontWeight.w600, color: theme.secondaryText)),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: FittedBox(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const Key('showcase-standard-preview'),
                width: 240,
                height: 320,
                child: IgnorePointer(
                  child: RestaurantCard(
                    listing: widget.listing,
                    variant: RestaurantCardVariant.grid,
                    previewAsStandard: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final paidPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: context.t('ui_showcase_tier_group'),
          child: LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 420;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < PromotionTier.values.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _card(PromotionTier.values[i], reduce),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < PromotionTier.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _card(PromotionTier.values[i], reduce)),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: [
            for (final d in PricingConfigService.instance.config.promotions.durations)
              ButtonSegment(value: d, label: Text(DurationFormatter.daysOf(context, d))),
          ],
          selected: {_duration},
          onSelectionChanged: (s) => setState(() => _duration = s.first),
        ),
        if (_tier != null) ...[
          const SizedBox(height: 6),
          Text(
            '$paid PLN · ${_cfg.perDayLabel(list, _duration)}',
            style: theme.titleSmall.override(fontWeight: FontWeight.w700),
          ),
          if (PromotionService.instance.isAtCapacity(_tier!))
            Text(
              context.t('ui_next_available', {
                'date': DateFormat('d MMM').format(PromotionService.instance.nextAvailableStart(_tier!)),
              }),
            ),
          if (!_fits())
            Text(context.t('ui_promo_needs_renew'), style: theme.bodySmall.override(color: TGColors.rating)),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            primary: false,
            child: PaymentForm(
              key: _formKey,
              amountPln: paid.toDouble(),
              billingKind: TGPaymentKind.promotion,
              billingDescription: _tier == null ? '' : tgPromoBillingLabel(_tier!, _duration),
              billingListingId: widget.listing.id,
              billingListingNo: widget.listing.listingNo,
              autofocusBlik: false,
              dense: true,
              showPayButton: _tier != null && _fits(),
              onPaid: () => _buy(auth),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TGButton(
          onPressed: () {
            TGAnalytics.track('showcase_dismiss', {'listingId': widget.listing.id, 'kind': 'restaurant'});
            setState(() => _dismissed = true);
            widget.onDismissed?.call();
          },
          label: context.t('ui_not_now'),
          variant: TGButtonVariant.outline,
          height: 40,
        ),
      ],
    );

    return TGShowcaseSinglePage(header: header, preview: preview, paid: paidPane);
  }

  Widget _card(PromotionTier tier, bool reduce) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _tier == tier;
    return Semantics(
      button: true,
      selected: selected,
      label: tier.brand,
      child: InkWell(
        key: Key('showcase-tier-${tier.name}'),
        borderRadius: BorderRadius.circular(TGRadius.card),
        onTap: () {
          setState(() => _tier = tier);
          TGAnalytics.track('promo_select', {'tier': tier.name, 'kind': 'restaurant'});
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduce ? 0 : 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TGRadius.card),
            border: Border.all(color: selected ? theme.primary : theme.alternate, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(tier.brand, style: theme.titleSmall.override(fontWeight: FontWeight.w700, letterSpacing: 0.40))),
                  if (selected) Icon(Icons.check_circle, color: theme.primary, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                switch (tier) {
                  PromotionTier.bold => context.t('ui_showcase_where_bold'),
                  PromotionTier.glow => context.t('ui_showcase_where_glow'),
                  PromotionTier.spotlight => context.t('ui_showcase_where_spotlight'),
                },
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall.override(fontSize: 11, lineHeight: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _buy(FakeAuthState auth) {
    final tier = _tier;
    if (tier == null) return;
    final list = _listPrice;
    final paid = _paid(auth.userId);
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
    final promo = PromotionService.instance.purchase(
      ownerId: auth.userId,
      kind: PromotionTargetKind.restaurant,
      targetRef: widget.listing.id,
      tier: tier,
      durationDays: _duration,
      pricePln: paid,
      source: PromotionSource.paid,
      listingEndsAt: widget.listing.expiresAt,
      startsAt: PromotionService.instance.isAtCapacity(tier)
          ? PromotionService.instance.nextAvailableStart(tier)
          : null,
    );
    widget.onPurchased?.call(promo);
    setState(() => _dismissed = true);
  }
}
