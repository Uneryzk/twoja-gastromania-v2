import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_invoice.dart';
import 'package:twoja_gastromania/tg_services/invoicing_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  static const routeName = 'AddProductCheckout';
  static const routePath = '/add-product/checkout';

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<PaymentFormState>();
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => TGAnalytics.emit('checkout_view'));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final cart = auth.checkoutCart;
    final w = MediaQuery.sizeOf(context).width;
    final desktop = w >= 1024;
    final phone = w < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;
    final theme = FlutterFlowTheme.of(context);
    final form = PaymentForm(
      key: _formKey,
      amountPln: cart?.totalPln ?? 0,
      showPayButton: !phone,
      onWaitingChanged: (v) => setState(() => _waiting = v),
      onPaid: () => completeCheckout(context, buyer: _formKey.currentState?.invoiceBuyer),
    );

    return TGPageScaffold(
      body: cart == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.t('ui_nothing_to_pay'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => TGNav.home(context), child: Text(context.t('ui_home'))),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _waiting && phone
                      ? form
                      : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TGBreadcrumb(
                                items: [
                                  TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                                  TGBreadcrumbItem(label: context.t('ui_checkout')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.t('ui_listing_fees_only'),
                              style: theme.bodySmall.override(color: theme.secondaryText),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: desktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: WizardCard(child: form),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        SizedBox(width: 411, child: _OrderSummary(cart: cart)),
                                      ],
                                    )
                                  : ListView(
                                      children: [
                                        WizardCard(child: form),
                                        const SizedBox(height: 16),
                                        _OrderSummary(cart: cart),
                                        const SizedBox(height: 24),
                                        if (!phone) const TGFooter(),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (desktop) const TGFooter(),
                if (phone && !_waiting)
                  Material(
                    color: TGColors.surface,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(context.t('ui_total_pln', {'n': formatMoneyPln(cart.totalPln, forceCents: true).replaceAll(' PLN', '')}), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                          ),
                          TGButton(
                            key: const Key('payment-pay'),
                            onPressed: () => _formKey.currentState?.tryPay(),
                            label: context.t('ui_pay'),
                            height: 48,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> completeCheckout(BuildContext context, {TGInvoiceBuyer? buyer}) async {
  final auth = context.read<FakeAuthState>();
  final cart = auth.checkoutCart;
  if (cart == null) return;
  final listing = cart.listingId == null ? null : auth.ownedListings.where((p) => p.id == cart.listingId).firstOrNull;
  InvoicingService.instance.onPaymentSuccess(
    grossAmount: cart.totalPln,
    transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
    buyer: buyer,
    listingId: cart.listingId,
    listingNo: listing?.listingNo,
  );
  switch (cart.kind) {
    case TGCheckoutKind.listing:
      final pending = auth.ownedListings.where((p) => p.id == cart.listingId).firstOrNull;
      if (pending != null) {
        final published = auth.publishOwned(pending, promoteDays: cart.promoteDays);
        await TGProductService.instance.upsert(published);
        auth.clearCheckout();
        if (context.mounted) context.go('/add-product/success?id=${published.id}');
      }
    case TGCheckoutKind.renew:
      final id = cart.listingId;
      if (id != null) {
        final published = auth.renewOwned(id, promoteDays: cart.promoteDays, early: cart.early);
        await TGProductService.instance.upsert(published);
        auth.clearCheckout();
        if (context.mounted) context.go('/dashboard/listings?renewed=$id');
      }
    case TGCheckoutKind.renewBulk:
      for (final id in cart.listingIds) {
        final published = auth.renewOwned(id);
        await TGProductService.instance.upsert(published);
      }
      auth.clearCheckout();
      if (context.mounted) context.go('/dashboard/listings');
    case TGCheckoutKind.store:
      auth.subscribeStore(cart.storePlanId ?? 'basic');
      auth.clearCheckout();
      if (context.mounted) context.go('/dashboard/listings');
  }
}

class _OrderSummary extends StatefulWidget {
  const _OrderSummary({required this.cart});
  final TGCheckoutCart cart;

  @override
  State<_OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<_OrderSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final total = widget.cart.totalPln;
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_order_summary'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final line in widget.cart.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(_checkoutLineLabel(context, line.label))),
                  Text(formatMoneyPln(line.amountPln, forceCents: true), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const Divider(height: 24),
          Text(context.t('ui_total_pln', {'n': formatMoneyPln(total, forceCents: true).replaceAll(' PLN', '')}), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(context.t('ui_all_prices_vat')),
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? context.t('ui_hide_vat') : context.t('ui_show_vat')),
          ),
          if (_open)
            for (final line in widget.cart.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${formatMoneyPln(line.amountPln, forceCents: true)} = ${formatMoneyPln(TGPricing.netFromGross(line.amountPln), forceCents: true).replaceAll(' PLN', '')} ${context.t('ui_netto')} + ${formatMoneyPln(TGPricing.vatFromGross(line.amountPln), forceCents: true).replaceAll(' PLN', '')} VAT',
                  style: theme.bodySmall.override(color: theme.secondaryText),
                ),
              ),
        ],
      ),
    );
  }
}

String _checkoutLineLabel(BuildContext context, String label) {
  switch (label) {
    case 'Standard listing':
      return context.t('ui_standard_listing');
    case 'Promote 14 days':
      return context.t('ui_promote_n_days', {'n': '14'});
    case 'Promote 30 days':
      return context.t('ui_promote_n_days', {'n': '30'});
    case 'Renew':
      return context.t('ui_renew');
    case 'Renew early':
      return context.t('ui_renew_early');
    default:
      final feeNo = RegExp(r'^Listing fee - No\. (\d{8})$').firstMatch(label);
      if (feeNo != null) return context.t('ui_listing_fee_no', {'n': feeNo.group(1)!});
      final renewN = RegExp(r'^Renew (\d+) listings$').firstMatch(label);
      if (renewN != null) return context.t('ui_renew_n_listings', {'n': renewN.group(1)!});
      return label;
  }
}
