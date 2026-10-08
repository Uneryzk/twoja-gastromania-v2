import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/invoicing_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

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
  int _promote = 0;
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();

  int get _total => TGPricing.listingFeePln + (_promote == 14 ? TGPricing.promote14Pln : _promote == 30 ? TGPricing.promote30Pln : 0);

  bool _allow(int days) {
    final room = widget.early ? widget.product.daysUntilExpiry() + TGPricing.listingPeriodDays : TGPricing.listingPeriodDays;
    return days <= room;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = widget.product;
    final ago = p.daysSinceExpiry();
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
            Text(context.t('ui_days_left_n', {'n': '${p.daysUntilExpiry()}'}), style: theme.bodySmall.override(color: TGColors.rating)),
          const SizedBox(height: 14),
          WizardRadioCard(
            selected: _promote == 0,
            title: context.t('ui_renew_pln', {'fee': '${TGPricing.listingFeePln}'}),
            onTap: () => setState(() => _promote = 0),
          ),
          const SizedBox(height: 8),
          _offer(
            enabled: _allow(14),
            selected: _promote == 14,
            title: context.t('ui_renew_promote_14', {'fee': '${TGPricing.listingFeePln + TGPricing.promote14Pln}'}),
            onTap: () => setState(() => _promote = 14),
          ),
          const SizedBox(height: 8),
          _offer(
            enabled: _allow(30),
            selected: _promote == 30,
            title: context.t('ui_renew_promote_30', {'fee': '${TGPricing.listingFeePln + TGPricing.promote30Pln}'}),
            onTap: () => setState(() => _promote = 30),
          ),
          const SizedBox(height: 16),
          PaymentForm(
            key: _formKey,
            amountPln: _total.toDouble(),
            autofocusBlik: true,
            onWaitingChanged: (v) => setState(() => _paying = v),
            onPaid: () => _finish(context),
          ),
        ],
      ),
      ),
    );
  }

  Widget _offer({required bool enabled, required bool selected, required String title, required VoidCallback onTap}) {
    final card = WizardRadioCard(selected: selected, title: title, onTap: enabled ? onTap : () {});
    if (enabled) return card;
    return Tooltip(message: 'Promote cannot last longer than the listing.', child: Opacity(opacity: 0.45, child: IgnorePointer(child: card)));
  }

  Future<void> _finish(BuildContext context) async {
    InvoicingService.instance.onPaymentSuccess(
      grossAmount: _total.toDouble(),
      transactionId: 'txn_renew_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}',
      buyer: _formKey.currentState?.invoiceBuyer,
      listingId: widget.product.id,
      listingNo: widget.product.listingNo,
    );
    final auth = context.read<FakeAuthState>();
    final published = auth.renewOwned(widget.product.id, promoteDays: _promote, early: widget.early);
    await TGProductService.instance.upsert(published);
    if (!context.mounted) return;
    Navigator.pop(context);
    TGAnalytics.emit('renew_success', {'id': widget.product.id});
    final until = DateFormat('d MMM y').format(published.expiresAt ?? DateTime.now());
    showTGToast(context, 'Live again until $until');
  }
}
