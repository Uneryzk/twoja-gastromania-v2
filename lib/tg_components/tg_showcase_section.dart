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
    if (_tier == null) return true;
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
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final svc = PromotionService.instance;
    final scaler = MediaQuery.textScalerOf(context);
    final paid = _tier == null ? 0 : _paidPrice(auth.userId);
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
                height: TGProductCard.gridExtent(240, scaler, showSeller: false),
                child: IgnorePointer(
                  child: TGProductCard(
                    product: widget.product,
                    layout: TGProductCardLayout.grid,
                    showSeller: false,
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
              final cards = [
                for (final t in PromotionTier.values) Expanded(child: _tierCard(t, reduce, compact: true)),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < PromotionTier.values.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _tierCard(PromotionTier.values[i], reduce, compact: true),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    cards[i],
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: context.t('ui_promo_duration'),
          child: SegmentedButton<int>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            segments: [
              for (final d in PricingConfigService.instance.config.promotions.durations)
                ButtonSegment(value: d, label: Text(DurationFormatter.daysOf(context, d))),
            ],
            selected: {_duration},
            onSelectionChanged: (s) => setState(() => _duration = s.first),
          ),
        ),
        if (_tier != null) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduce ? 0 : 150),
            child: Text(
              key: ValueKey('$_tier-$_duration-$paid'),
              '$paid PLN · ${_cfg.perDayLabel(list, _duration)}',
              style: theme.titleSmall.override(fontWeight: FontWeight.w700),
            ),
          ),
          if (svc.isAtCapacity(_tier!))
            Text(
              context.t('ui_next_available', {'date': DateFormat('d MMM').format(svc.nextAvailableStart(_tier!))}),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          if (!_fitsListing())
            Text(context.t('ui_promo_needs_renew'), style: theme.bodySmall.override(color: TGColors.rating, fontWeight: FontWeight.w700)),
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
              billingListingId: widget.product.id,
              billingListingNo: widget.product.listingNo,
              autofocusBlik: false,
              dense: true,
              showPayButton: _tier != null && _fitsListing(),
              onWaitingChanged: (v) => setState(() => _paying = v),
              onPaid: () => _buy(auth),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TGButton(
          onPressed: _paying
              ? null
              : () {
                  TGAnalytics.track('showcase_dismiss', {'listingId': widget.product.id});
                  setState(() => _dismissed = true);
                  widget.onDismissed?.call();
                },
          label: context.t('ui_not_now'),
          variant: TGButtonVariant.outline,
          height: 40,
        ),
        if (_bannerAllowed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.go('/dashboard/advertising?tab=banners'),
              child: Text(context.t('ui_want_banner_spot')),
            ),
          ),
      ],
    );

    return TGShowcaseSinglePage(header: header, preview: preview, paid: paidPane);
  }

  bool get _bannerAllowed {
    final rev = TGRevenueConfigService.instance.config;
    return rev.flags.bannerAds && rev.phase >= 2;
  }

  Widget _tierCard(PromotionTier tier, bool reduce, {required bool compact}) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _tier == tier;
    final where = switch (tier) {
      PromotionTier.bold => context.t('ui_showcase_where_bold'),
      PromotionTier.glow => context.t('ui_showcase_where_glow'),
      PromotionTier.spotlight => context.t('ui_showcase_where_spotlight'),
    };
    final name = tier.brand;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        key: Key('showcase-tier-${tier.name}'),
        borderRadius: BorderRadius.circular(TGRadius.card),
        onTap: () {
          setState(() => _tier = tier);
          TGAnalytics.track('promo_select', {'tier': tier.name, 'listingId': widget.product.id});
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduce ? 0 : 150),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TGRadius.card),
            border: Border.all(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
            color: theme.secondaryBackground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: theme.titleSmall.override(fontWeight: FontWeight.w700, letterSpacing: 0.40))),
                  if (selected) Icon(Icons.check_circle, color: theme.primary, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(where, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 11, lineHeight: 1.25)),
              const SizedBox(height: 4),
              Text('${_cfg.promoFeePln(tier, _duration)} PLN', style: theme.labelMedium.override(fontWeight: FontWeight.w700)),
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

/// Viewport-filling split: standard listing preview | paid packs + duration + pay.
class TGShowcaseSinglePage extends StatelessWidget {
  const TGShowcaseSinglePage({
    super.key,
    required this.header,
    required this.preview,
    required this.paid,
  });

  final Widget header;
  final Widget preview;
  final Widget paid;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bounded = c.maxHeight.isFinite;
        final leftW = (c.maxWidth * 0.34).clamp(168.0, 280.0);
        final split = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftW, child: preview),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: VerticalDivider(width: 1, thickness: 1, color: TGColors.border),
            ),
            Expanded(child: paid),
          ],
        );
        return KeyedSubtree(
          key: const Key('showcase-single-page'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 10),
              if (bounded) Expanded(child: split) else SizedBox(height: 520, child: split),
            ],
          ),
        );
      },
    );
  }
}
