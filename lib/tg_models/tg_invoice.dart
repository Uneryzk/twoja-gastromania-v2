/// B2B buyer snapshot collected at checkout / plans / renew.
class TGInvoiceBuyer {
  const TGInvoiceBuyer({
    required this.nip,
    required this.companyName,
    required this.address,
  });

  final String nip;
  final String companyName;
  final String address;

  bool get isComplete => nip.length == 10 && companyName.trim().isNotEmpty && address.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'nip': nip,
        'companyName': companyName,
        'address': address,
      };
}

/// Payload queued for Polish e-invoice providers (FakturaXL / Fakturownia / wfirma).
class TGInvoiceData {
  const TGInvoiceData({
    required this.grossAmount,
    required this.netAmount,
    required this.vatAmount,
    required this.vatRate,
    required this.transactionId,
    required this.issuedAt,
    this.buyer,
    this.listingId,
    this.listingNo,
  });

  final double grossAmount;
  final double netAmount;
  final double vatAmount;
  final double vatRate;
  final String transactionId;
  final DateTime issuedAt;
  final TGInvoiceBuyer? buyer;
  final String? listingId;
  final String? listingNo;

  String get nip => buyer?.nip ?? '';

  Map<String, Object?> toJson() => {
        'invoiceData': {
          'nip': nip,
          'companyName': buyer?.companyName,
          'address': buyer?.address,
          'grossAmount': grossAmount,
          'netAmount': netAmount,
          'vatAmount': vatAmount,
          'vatRate': vatRate,
          'transactionId': transactionId,
          'listingId': listingId,
          'listingNo': listingNo,
          'issuedAt': issuedAt.toIso8601String(),
        },
        'provider': 'stub',
        'providers': const ['FakturaXL', 'Fakturownia', 'wfirma'],
        'webhookReady': true,
      };
}
