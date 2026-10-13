import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart';
import 'package:twoja_gastromania/tg_components/founder_price_row.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';

/// "Promote your manufacturer card" — VITRIN-1 Bold / Glow / Spotlight packages
/// applied to the /special-order manufacturer list (Promotion.targetKind = manufacturer).
class TGManufacturerPromotePanel extends StatefulWidget {
  const TGManufacturerPromotePanel({super.key, required this.sellerId});
  final String sellerId;

  @override
  State<TGManufacturerPromotePanel> createState() => _TGManufacturerPromotePanelState();
}

class _TGManufacturerPromotePanelState extends State<TGManufacturerPromotePanel> {
  PromotionTier? _tier;
  int _duration = PricingConfigService.instance.config.promotions.defaultDays;

  PricingConfig get _cfg => PricingConfigService.instance.config;
  PromotionService get _promos => PromotionService.instance;

  int get _listPrice => _tier == null ? 0 : _cfg.promoFeePln(_tier!, _duration);
  int get _paid => _listPrice <= 0 ? 0 : TGFounderService.instance.discountedPrice(widget.sellerId, _listPrice);

  void _buy() {
    final tier = _tier;
    if (tier == null) return;
    final list = _listPrice;
    final paid = _paid;
    final rate = TGFounderService.instance.activeDiscountRate(widget.sellerId);
    if (rate > 0 && list > paid) {
      TGFounderService.instance.recordSavings(
        sellerId: widget.sellerId,
        item: TGFounderDiscountItem.promote30,
        listPrice: list,
        paidPrice: paid,
        discountPct: rate,
      );
    }
    _promos.purchase(
      ownerId: widget.sellerId,
      kind: PromotionTargetKind.manufacturer,
      targetRef: widget.sellerId,
      tier: tier,
      durationDays: _duration,
      pricePln: paid,
      source: PromotionSource.paid,
      startsAt: _promos.isAtCapacity(tier) ? _promos.nextAvailableStart(tier) : null,
    );
    TGAnalytics.track('mfr_promote_purchase', {'sellerId': widget.sellerId, 'tier': tier.name, 'paid': paid});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_mfr_promote_done'))));
    setState(() => _tier = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final profile = TGSellerProfileService.instance.bySellerKey(widget.sellerId);
    final locale = Localizations.localeOf(context).languageCode;
    final dateFmt = DateFormat('d MMM', locale);
    final live = _promos.activeFor(kind: PromotionTargetKind.manufacturer, targetRef: widget.sellerId);
    final scheduled = _promos
        .forOwner(widget.sellerId)
        .where((p) =>
            p.targetKind == PromotionTargetKind.manufacturer &&
            p.targetRef == widget.sellerId &&
            p.status == PromotionStatus.scheduled)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(context.t('ui_mfr_promote_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        Text(context.t('ui_mfr_promote_sub'), style: theme.bodySmall),
        const SizedBox(height: 12),
        if (live != null)
          _StatusRow(
            icon: Icons.verified_outlined,
            text: context.t('ui_mfr_promote_live', {'tier': _tierName(live.tier), 'd': dateFmt.format(live.endsAt)}),
          ),
        if (scheduled != null)
          _StatusRow(
            icon: Icons.schedule,
            text: context.t('ui_mfr_promote_scheduled', {'tier': _tierName(scheduled.tier), 'd': dateFmt.format(scheduled.startsAt)}),
          ),
        if (live != null || scheduled != null) const SizedBox(height: 12),
        for (final tier in const [PromotionTier.spotlight, PromotionTier.glow, PromotionTier.bold]) ...[
          _TierOption(
            tier: tier,
            name: _tierName(tier),
            where: context.t('ui_mfr_promote_where_${tier.name}'),
            fromPrice: _cfg.promoFeePln(tier, _cfg.promotions.defaultDays),
            fromDays: _cfg.promotions.defaultDays,
            selected: _tier == tier,
            onTap: () {
              setState(() => _tier = tier);
              TGAnalytics.track('promo_select', {'tier': tier.name, 'kind': 'manufacturer'});
            },
          ),
          const SizedBox(height: 10),
        ],
        if (_tier != null) ...[
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [
              for (final d in PricingConfigService.instance.config.promotions.durations)
                ButtonSegment(value: d, label: Text(DurationFormatter.daysOf(context, d))),
            ],
            selected: {_duration},
            onSelectionChanged: (s) => setState(() => _duration = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            '$_paid PLN · ${_cfg.perDayLabel(_listPrice, _duration, unit: context.t('ui_pln_per_day'))}',
            style: theme.titleMedium.override(fontWeight: FontWeight.w900),
          ),
          FounderPriceRow(sellerId: widget.sellerId, listPrice: _listPrice),
          if (_promos.isAtCapacity(_tier!))
            Text(
              context.t('ui_next_available', {'date': dateFmt.format(_promos.nextAvailableStart(_tier!))}),
              style: theme.bodySmall,
            ),
          if (profile != null) ...[
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(context.t('ui_mfr_promote_preview'), style: theme.labelMedium.override(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: 280,
                height: 340,
                child: IgnorePointer(
                  child: _PreviewTier(
                    tier: _tier!,
                    child: SoManufacturerCard.compact(profile: profile),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          PaymentForm(
            amountPln: _paid.toDouble(),
            billingKind: TGPaymentKind.promotion,
            billingDescription: 'Manufacturer ${tgPromoBillingLabel(_tier!, _duration)}',
            onPaid: _buy,
          ),
        ],
      ],
    );
  }

  String _tierName(PromotionTier t) => t.brand;
}

/// Shows the card as it would look with [tier] before the promotion exists.
class _PreviewTier extends StatelessWidget {
  const _PreviewTier({required this.tier, required this.child});
  final PromotionTier tier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neon = tier != PromotionTier.bold;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: neon ? 2 : 1,
                color: neon ? const Color(0xFFE91E8C) : Colors.transparent,
              ),
            ),
          ),
        ),
        Positioned(left: 8, top: 8, child: SoPromoLabel(tier: tier, compact: true)),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: TGColors.cta)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.bodyMedium.override(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _TierOption extends StatelessWidget {
  const _TierOption({
    required this.tier,
    required this.name,
    required this.where,
    required this.fromPrice,
    required this.fromDays,
    required this.selected,
    required this.onTap,
  });

  final PromotionTier tier;
  final String name;
  final String where;
  final int fromPrice;
  final int fromDays;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final price = context.t('ui_mfr_promote_from', {'price': '$fromPrice', 'days': '$fromDays'});
    return Semantics(
      button: true,
      selected: selected,
      label: '$name. $where. $price',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: tgAnim(context, const Duration(milliseconds: 150)),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? theme.primary : theme.alternate, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                        SoPromoLabel(tier: tier, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(where, style: theme.bodySmall),
                    const SizedBox(height: 4),
                    Text(price, style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: theme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
