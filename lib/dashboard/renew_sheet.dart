import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

Future<void> showRenewSheet(BuildContext context, TGProduct product, {bool early = false}) {
  final body = _RenewSheetBody(product: product, early: early);
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
  const _RenewSheetBody({required this.product, required this.early});
  final TGProduct product;
  final bool early;

  @override
  State<_RenewSheetBody> createState() => _RenewSheetBodyState();
}

class _RenewSheetBodyState extends State<_RenewSheetBody> {
  ListingDurationKey _duration = ListingDurationKey.d30;
  PromotionTier? _tier; // null = None
  PromotionDurationKey _promoDur = PromotionDurationKey.week2;
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();

  PricingConfig get _cfg => PricingConfigService.instance.config;

  int get _listingFee => _cfg.listingFeePln(_duration);

  int _promoList() {
    final t = _tier;
    if (t == null) return 0;
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
    final listingEnd = base.add(Duration(days: _duration.days));
    return PromotionService.instance.promoFitsListing(
      listingEndsAt: listingEnd,
      promoDays: _promoDur.days,
      startAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final sellerId = auth.userId;
    final p = widget.product;
    final ago = p.daysSinceExpiry();
    final early = widget.early || (p.status != TGListingStatus.expired && p.daysUntilExpiry() <= _cfg.renewEarlyDays);
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
            for (final key in ListingDurationKey.values) ...[
              const SizedBox(height: 8),
              WizardRadioCard(
                selected: _duration == key,
                title: context.t('ui_duration_days_price', {'days': '${key.days}', 'fee': '${_cfg.listingFeePln(key)}'}),
                subtitle: '${_cfg.perDayLabel(_cfg.listingFeePln(key), key.days)} · ${context.t('ui_longer_cheaper')}',
                onTap: () => setState(() => _duration = key),
              ),
            ],
            const SizedBox(height: 16),
            WizardLabel(context.t('ui_promote')),
            WizardRadioCard(
              selected: _tier == null,
              title: context.t('ui_promo_none'),
              onTap: () => setState(() => _tier = null),
            ),
            for (final tier in PromotionTier.values) ...[
              const SizedBox(height: 8),
              WizardRadioCard(
                selected: _tier == tier,
                title: '${tier.name[0].toUpperCase()}${tier.name.substring(1)} · ${_cfg.promoFeePln(tier, _promoDur)} PLN',
                subtitle: _cfg.perDayLabel(_cfg.promoFeePln(tier, _promoDur), _promoDur.days),
                onTap: () => setState(() => _tier = tier),
              ),
            ],
            if (_tier != null) ...[
              const SizedBox(height: 10),
              SegmentedButton<PromotionDurationKey>(
                segments: [
                  ButtonSegment(value: PromotionDurationKey.week2, label: Text(context.t('ui_duration_2w'))),
                  ButtonSegment(value: PromotionDurationKey.month1, label: Text(context.t('ui_duration_1m'))),
                ],
                selected: {_promoDur},
                onSelectionChanged: (s) => setState(() => _promoDur = s.first),
              ),
              if (_promoList() > 0) ...[
                const SizedBox(height: 6),
                FounderPriceRow(sellerId: sellerId, listPrice: _promoList(), label: 'Promote add-on'),
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
      periodDays: _duration.days,
    );
    if (_tier != null && _promoFits()) {
      final promo = PromotionService.instance.purchase(
        ownerId: sellerId,
        kind: PromotionTargetKind.listing,
        targetRef: published.id,
        tier: _tier!,
        durationKey: _promoDur,
        pricePln: paid,
        source: PromotionSource.paid,
        listingEndsAt: published.expiresAt,
        paymentId: 'pay_renew_${DateTime.now().millisecondsSinceEpoch}',
      );
      await TGProductService.instance.upsert(published.copyWith(
        isPromoted: promo.status == PromotionStatus.active,
        promotedUntil: promo.endsAt,
      ));
    } else {
      await TGProductService.instance.upsert(published);
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    TGAnalytics.emit('renew_success', {'id': widget.product.id, 'days': _duration.days});
    final until = DateFormat('d MMM y').format(published.expiresAt ?? DateTime.now());
    showTGToast(context, 'Live again until $until');
  }
}
