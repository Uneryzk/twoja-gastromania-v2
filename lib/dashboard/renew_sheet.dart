import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/founder_price_row.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/invoicing_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';

/// [initialTier] / [initialPromoDays] preselect a promotion (renew offer cards).
Future<void> showRenewSheet(
  BuildContext context,
  TGProduct product, {
  bool early = false,
  PromotionTier? initialTier,
  int? initialPromoDays,
}) {
  final body = _RenewSheetBody(product: product, early: early, initialTier: initialTier, initialPromoDays: initialPromoDays);
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: FlutterFlowTheme.of(ctx).secondaryBackground,
            borderRadius: BorderRadius.circular(TGRadius.modal),
            child: body,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: TGColors.border, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: body,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RenewSheetBody extends StatefulWidget {
  const _RenewSheetBody({required this.product, required this.early, this.initialTier, this.initialPromoDays});
  final TGProduct product;
  final bool early;
  final PromotionTier? initialTier;
  final int? initialPromoDays;

  @override
  State<_RenewSheetBody> createState() => _RenewSheetBodyState();
}

class _RenewSheetBodyState extends State<_RenewSheetBody> {
  int _duration = PricingConfigService.instance.config.defaultListingDays;
  late PromotionTier? _tier = widget.initialTier; // null = None
  late int _promoDur = widget.initialPromoDays ?? PricingConfigService.instance.config.promotions.defaultDays;
  bool _useCredit = false;
  String _owner = '';
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();

  PricingConfig get _cfg => PricingConfigService.instance.config;

  int get _listingFee => _cfg.listingFeePln(_duration);

  /// A Glow credit (Pro / Founder) covers the Glow add-on; never combined with Founder discount.
  bool get _creditApplies => _useCredit && _tier == PromotionTier.glow;

  int get _effectivePromoDur {
    if (!_creditApplies) return _promoDur;
    final c = PromotionService.instance.unusedCreditList(_owner).where((c) => c.tier == PromotionTier.glow).firstOrNull;
    return c?.durationDays ?? _promoDur;
  }

  int _promoList() {
    final t = _tier;
    if (t == null || _creditApplies) return 0;
    return _cfg.promoFeePln(t, _promoDur);
  }

  int _promoPaid(String sellerId) {
    final list = _promoList();
    if (list <= 0) return 0;
    return TGFounderService.instance.discountedPrice(sellerId, list);
  }

  int _total(String sellerId) => _listingFee + _promoPaid(sellerId);

  bool _promoFits() {
    final t = _tier;
    if (t == null) return true;
    // After renew, listing end = base + duration days.
    final now = DateTime.now();
    final base = widget.early && widget.product.expiresAt != null && widget.product.expiresAt!.isAfter(now)
        ? widget.product.expiresAt!
        : now;
    final listingEnd = DurationService.addDays(base, _duration);
    final svc = PromotionService.instance;
    return svc.promoFitsListing(
      listingEndsAt: listingEnd,
      promoDays: _effectivePromoDur,
      startAt: svc.isAtCapacity(t) ? svc.nextAvailableStart(t) : now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final sellerId = auth.userId;
    _owner = sellerId;
    final p = widget.product;
    final ago = p.daysSinceExpiry();
    final early = widget.early || (p.status != TGListingStatus.expired && p.daysUntilExpiry() <= _cfg.renewEarlyDays);
    final glowCredits = PromotionService.instance.unusedCreditsOf(sellerId, PromotionTier.glow);
    return PopScope(
      canPop: !_paying,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            if (p.status == TGListingStatus.expired)
              Text(context.t('ui_expired_ago', {'n': '$ago'}), style: theme.bodySmall.override(color: TGColors.rating))
            else
              Text(
                early ? context.t('ui_renew_early') : context.t('ui_days_left_n', {'n': '${p.daysUntilExpiry()}'}),
                style: theme.bodySmall.override(color: TGColors.rating),
              ),
            const SizedBox(height: 14),
            WizardLabel(context.t('ui_listing_duration')),
            Semantics(
              container: true,
              label: context.t('ui_listing_duration'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final key in _cfg.listingDurations) ...[
                    const SizedBox(height: 8),
                    WizardRadioCard(
                      key: Key('renew-dur-$key'),
                      selected: _duration == key,
                      title: context.t('ui_duration_days_price', {'days': '$key', 'fee': '${_cfg.listingFeePln(key)}'}),
                      subtitle: '${_cfg.perDayLabel(_cfg.listingFeePln(key), key)} · ${context.t('ui_longer_cheaper')}',
                      onTap: () => setState(() => _duration = key),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            WizardLabel(context.t('ui_promote')),
            Semantics(
              container: true,
              label: context.t('ui_showcase_tier_group'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WizardRadioCard(
                    key: const Key('renew-tier-none'),
                    selected: _tier == null,
                    title: context.t('ui_promo_none'),
                    onTap: () => setState(() => _tier = null),
                  ),
                  for (final tier in PromotionTier.values) ...[
                    const SizedBox(height: 8),
                    WizardRadioCard(
                      key: Key('renew-tier-${tier.name}'),
                      selected: _tier == tier,
                      title: '${tier.brand} · ${_cfg.promoFeePln(tier, _promoDur)} PLN',
                      subtitle: '${_whereLabel(context, tier)} · ${_cfg.perDayLabel(_cfg.promoFeePln(tier, _promoDur), _promoDur)}',
                      onTap: () => setState(() => _tier = tier),
                    ),
                  ],
                ],
              ),
            ),
            if (_tier != null) ...[
              if (_tier == PromotionTier.glow && glowCredits > 0) ...[
                const SizedBox(height: 10),
                Semantics(
                  toggled: _useCredit,
                  label: context.t('uyum_use_glow_credit', {'n': '$glowCredits'}),
                  excludeSemantics: true,
                  child: SwitchListTile(
                    key: const Key('renew-use-credit'),
                    contentPadding: EdgeInsets.zero,
                    value: _useCredit,
                    onChanged: (v) => setState(() => _useCredit = v),
                    title: Text(context.t('uyum_use_glow_credit', {'n': '$glowCredits'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              if (!_creditApplies) ...[
                const SizedBox(height: 10),
                WizardLabel(context.t('ui_promo_duration')),
                const SizedBox(height: 6),
                Semantics(
                  label: context.t('ui_promo_duration'),
                  child: SegmentedButton<int>(
                    segments: [
                      for (final d in _cfg.promotions.durations)
                        ButtonSegment(value: d, label: Text(DurationFormatter.daysOf(context, d))),
                    ],
                    selected: {_promoDur},
                    onSelectionChanged: (s) => setState(() => _promoDur = s.first),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  context.t('uyum_credit_covers', {'tier': PromotionTier.glow.brand, 'days': DurationFormatter.daysOf(context, _effectivePromoDur)}),
                  key: const Key('renew-credit-covers'),
                  style: theme.bodySmall.override(color: theme.secondaryText),
                ),
              ],
              if (_promoList() > 0) ...[
                const SizedBox(height: 6),
                FounderPriceRow(sellerId: sellerId, listPrice: _promoList(), label: context.t('uyum_promote_addon')),
              ],
              if (PromotionService.instance.isAtCapacity(_tier!)) ...[
                const SizedBox(height: 8),
                Text(
                  context.t('ui_next_available', {
                    'date': DateFormat('d MMM').format(PromotionService.instance.nextAvailableStart(_tier!)),
                  }),
                  style: theme.bodySmall.override(color: theme.secondaryText),
                ),
              ],
              if (!_promoFits()) ...[
                const SizedBox(height: 8),
                Text(context.t('ui_promo_needs_renew'), style: theme.bodySmall.override(color: TGColors.rating)),
              ],
            ],
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: Duration(milliseconds: (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ? 0 : 150),
              child: Text(
                key: ValueKey(_total(sellerId)),
                context.t('ui_total_brutto_vat', {'n': '${_total(sellerId)}'}),
                style: theme.titleSmall.override(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 16),
            PaymentForm(
              key: _formKey,
              amountPln: _total(sellerId).toDouble(),
              billingKind: TGPaymentKind.renew,
              billingDescription: 'Renew · $_duration days${_tier != null && _promoFits() && !_creditApplies ? ' + ${tgPromoBillingLabel(_tier!, _promoDur)}' : ''}',
              billingListingId: widget.product.id,
              billingListingNo: widget.product.listingNo,
              autofocusBlik: true,
              onWaitingChanged: (v) => setState(() => _paying = v),
              onPaid: () => _finish(context, sellerId, early),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, String sellerId, bool early) async {
    final list = _promoList();
    final paid = _promoPaid(sellerId);
    final rate = TGFounderService.instance.activeDiscountRate(sellerId);
    if (rate > 0 && list > paid) {
      TGFounderService.instance.recordSavings(
        sellerId: sellerId,
        item: TGFounderDiscountItem.promote30,
        listPrice: list,
        paidPrice: paid,
        discountPct: rate,
      );
    }
    InvoicingService.instance.onPaymentSuccess(
      grossAmount: _total(sellerId).toDouble(),
      transactionId: 'txn_renew_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}',
      buyer: _formKey.currentState?.invoiceBuyer,
      listingId: widget.product.id,
      listingNo: widget.product.listingNo,
    );
    final auth = context.read<FakeAuthState>();
    final published = auth.renewOwned(
      widget.product.id,
      promoteDays: 0,
      early: early,
      periodDays: _duration,
    );
    final svc = PromotionService.instance;
    final promo = _tier == null || !_promoFits()
        ? null
        : _creditApplies
            ? svc.redeemCredit(
                ownerId: sellerId,
                kind: PromotionTargetKind.listing,
                targetRef: published.id,
                listingEndsAt: published.expiresAt,
              )
            : svc.purchase(
                ownerId: sellerId,
                kind: PromotionTargetKind.listing,
                targetRef: published.id,
                tier: _tier!,
                durationDays: _promoDur,
                pricePln: paid,
                source: PromotionSource.paid,
                listingEndsAt: published.expiresAt,
                paymentId: 'pay_renew_${DateTime.now().millisecondsSinceEpoch}',
              );
    if (promo != null) {
      await TGProductService.instance.upsert(published.copyWith(
        isPromoted: promo.status == PromotionStatus.active,
        promotedUntil: promo.endsAt,
      ));
    } else {
      await TGProductService.instance.upsert(published);
    }
    if (!context.mounted) return;
    final until = DateFormat('d MMM y', Localizations.localeOf(context).languageCode).format(published.expiresAt ?? DateTime.now());
    final toast = context.t('uyum_live_again_until', {'date': until});
    Navigator.pop(context);
    TGAnalytics.emit('renew_success', {'id': widget.product.id, 'days': _duration, if (promo != null) 'promoSource': promo.source.name});
    showTGToast(context, toast);
  }
}

String _whereLabel(BuildContext context, PromotionTier tier) => switch (tier) {
      PromotionTier.bold => context.t('ui_showcase_where_bold'),
      PromotionTier.glow => context.t('ui_showcase_where_glow'),
      PromotionTier.spotlight => context.t('ui_showcase_where_spotlight'),
    };
