import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_invoice.dart';

/// Mock / stub e-invoice layer.
///
/// On `payment_success` it splits the gross amount at 23% VAT and queues a
/// webhook-ready payload. Swap [dispatchWebhook] later for FakturaXL /
/// Fakturownia / wfirma.
class InvoicingService {
  InvoicingService._();
  static final InvoicingService instance = InvoicingService._();

  final List<TGInvoiceData> issued = [];
  final List<Map<String, Object?>> webhookQueue = [];

  void reset() {
    issued.clear();
    webhookQueue.clear();
  }

  TGInvoiceData onPaymentSuccess({
    required double grossAmount,
    required String transactionId,
    TGInvoiceBuyer? buyer,
    String? listingId,
    String? listingNo,
  }) {
    final net = TGPricing.netFromGross(grossAmount);
    final vat = TGPricing.vatFromGross(grossAmount);
    final invoice = TGInvoiceData(
      grossAmount: grossAmount,
      netAmount: double.parse(net.toStringAsFixed(2)),
      vatAmount: double.parse(vat.toStringAsFixed(2)),
      vatRate: TGPricing.vatRate,
      transactionId: transactionId,
      issuedAt: DateTime.now(),
      buyer: buyer,
      listingId: listingId,
      listingNo: listingNo,
    );
    issued.add(invoice);
    dispatchWebhook(invoice);
    TGAnalytics.emit('invoice_queued', {
      'transactionId': transactionId,
      'grossAmount': invoice.grossAmount,
      'netAmount': invoice.netAmount,
      'vatAmount': invoice.vatAmount,
      'nip': invoice.nip,
    });
    return invoice;
  }

  /// Stub webhook / API hop. Replace with a real HTTP POST later.
  void dispatchWebhook(TGInvoiceData invoice) {
    final payload = invoice.toJson();
    webhookQueue.add(payload);
    debugPrint('InvoicingService webhook stub ${payload['invoiceData']}');
  }
}
