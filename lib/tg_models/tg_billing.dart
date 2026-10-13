import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart' show isValidNip;

/// Gross (VAT-inclusive) amount split at 23% VAT, in grosze so the parts
/// always add up: `net + vat == gross`.
@immutable
class TGVatSplit {
  const TGVatSplit({required this.grossGr, required this.netGr, required this.vatGr});

  factory TGVatSplit.fromGross(num grossPln) {
    final gross = (grossPln * 100).round();
    final net = (gross / (1 + TGPricing.vatRate)).round();
    return TGVatSplit(grossGr: gross, netGr: net, vatGr: gross - net);
  }

  final int grossGr;
  final int netGr;
  final int vatGr;

  double get grossPln => grossGr / 100;
  double get netPln => netGr / 100;
  double get vatPln => vatGr / 100;

  TGVatSplit operator +(TGVatSplit o) => TGVatSplit(grossGr: grossGr + o.grossGr, netGr: netGr + o.netGr, vatGr: vatGr + o.vatGr);

  static const zero = TGVatSplit(grossGr: 0, netGr: 0, vatGr: 0);
}

/// Ledger label for a promotion line, e.g. "Glow · 14 days".
String tgPromoBillingLabel(PromotionTier tier, int days) => '${tier.brand} · $days days';

enum TGPaymentStatus { succeeded, failed, refunded }

/// One charge of a platform service fee. The platform never collects money
/// between users, so every payment is a fee for our own service.
@immutable
class TGPayment {
  const TGPayment({
    required this.id,
    required this.userId,
    required this.kind,
    required this.description,
    required this.amount,
    required this.createdAt,
    this.method,
    this.methodLabel,
    this.status = TGPaymentStatus.succeeded,
    this.invoiceId,
    this.listingId,
    this.listingNo,
    this.subscriptionId,
    this.isMock = false,
  });

  final String id;
  final String userId;
  final TGPaymentKind kind;
  final String description;
  final TGVatSplit amount;
  final DateTime createdAt;
  final TGPayMethod? method;

  /// e.g. "Visa •••• 4242" or "BLIK".
  final String? methodLabel;
  final TGPaymentStatus status;
  final String? invoiceId;
  final String? listingId;
  final String? listingNo;
  final String? subscriptionId;
  final bool isMock;

  double get grossPln => amount.grossPln;
  double get netPln => amount.netPln;
  double get vatPln => amount.vatPln;
  double get vatRate => TGPricing.vatRate;

  TGPayment copyWith({String? invoiceId, TGPaymentStatus? status}) => TGPayment(
        id: id,
        userId: userId,
        kind: kind,
        description: description,
        amount: amount,
        createdAt: createdAt,
        method: method,
        methodLabel: methodLabel,
        status: status ?? this.status,
        invoiceId: invoiceId ?? this.invoiceId,
        listingId: listingId,
        listingNo: listingNo,
        subscriptionId: subscriptionId,
        isMock: isMock,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'userId': userId,
        'kind': kind.name,
        'description': description,
        'grossPln': grossPln,
        'netPln': netPln,
        'vatPln': vatPln,
        'vatRate': vatRate,
        'createdAt': createdAt.toIso8601String(),
        'method': method?.name,
        'status': status.name,
        'invoiceId': invoiceId,
        'listingId': listingId,
        'listingNo': listingNo,
      };
}

/// Buyer data printed on invoices (B2B: company + valid NIP).
@immutable
class TGInvoiceProfile {
  const TGInvoiceProfile({
    required this.userId,
    required this.companyName,
    required this.nip,
    required this.street,
    required this.postalCode,
    required this.city,
    this.email = '',
    this.updatedAt,
  });

  final String userId;
  final String companyName;
  final String nip;
  final String street;
  final String postalCode;
  final String city;
  final String email;
  final DateTime? updatedAt;

  static final _postal = RegExp(r'^\d{2}-\d{3}$');

  String get nipDigits => nip.replaceAll(RegExp(r'\D'), '');
  String get address => '$street, $postalCode $city';

  /// i18n error key per field; empty when the profile can be saved.
  Map<String, String> validate() => {
        if (companyName.trim().isEmpty) 'company': 'bill_err_company',
        if (!isValidNip(nip)) 'nip': 'bill_err_nip',
        if (street.trim().isEmpty) 'street': 'bill_err_street',
        if (!_postal.hasMatch(postalCode.trim())) 'postal': 'bill_err_postal',
        if (city.trim().isEmpty) 'city': 'bill_err_city',
        if (email.trim().isNotEmpty && !email.contains('@')) 'email': 'bill_err_email',
      };

  bool get isValid => validate().isEmpty;
}

enum TGInvoiceStatus { issued, requested }

@immutable
class TGInvoice {
  const TGInvoice({
    required this.id,
    required this.number,
    required this.userId,
    required this.paymentIds,
    required this.issuedAt,
    required this.amount,
    required this.buyer,
    this.status = TGInvoiceStatus.issued,
    this.isMock = false,
  });

  final String id;

  /// e.g. `FV/2026/10/0003`.
  final String number;
  final String userId;
  final List<String> paymentIds;
  final DateTime issuedAt;
  final TGVatSplit amount;
  final TGInvoiceProfile buyer;
  final TGInvoiceStatus status;
  final bool isMock;
}

enum TGSubscriptionKind { store, priority }

/// Stripe-style states; [pastDue] is shown as `past_due`.
enum TGSubscriptionStatus { active, pastDue, cancelled }

extension TGSubscriptionStatusName on TGSubscriptionStatus {
  String get apiName => switch (this) {
        TGSubscriptionStatus.active => 'active',
        TGSubscriptionStatus.pastDue => 'past_due',
        TGSubscriptionStatus.cancelled => 'cancelled',
      };
}

@immutable
class TGDunningAttempt {
  const TGDunningAttempt({required this.dayOffset, required this.at, required this.ok, this.methodLabel});
  final int dayOffset;
  final DateTime at;
  final bool ok;
  final String? methodLabel;
}

class TGSubscription {
  TGSubscription({
    required this.id,
    required this.userId,
    required this.kind,
    required this.planId,
    required this.label,
    required this.period,
    required this.pricePln,
    required this.startedAt,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.status = TGSubscriptionStatus.active,
    this.cancelAtPeriodEnd = false,
    this.cancelReason,
    this.nextPlanId,
    this.failedAt,
    List<TGDunningAttempt>? attempts,
    this.isMock = false,
  }) : attempts = attempts ?? [];

  final String id;
  final String userId;
  final TGSubscriptionKind kind;
  String planId;
  String label;
  TGBillingPeriod period;

  /// Gross per billing period.
  int pricePln;
  final DateTime startedAt;
  DateTime currentPeriodStart;
  DateTime currentPeriodEnd;
  TGSubscriptionStatus status;
  bool cancelAtPeriodEnd;
  String? cancelReason;

  /// Plan change that applies from the next period.
  String? nextPlanId;
  DateTime? failedAt;
  final List<TGDunningAttempt> attempts;
  final bool isMock;

  bool get isPastDue => status == TGSubscriptionStatus.pastDue;
  bool get isLive => status != TGSubscriptionStatus.cancelled;
}

@immutable
class TGPaymentMethod {
  const TGPaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.createdAt,
    this.brand = TGCardBrand.unknown,
    this.last4 = '',
    this.expMonth = 0,
    this.expYear = 0,
    this.holder = '',
    this.isDefault = false,
    this.isMock = false,
  });

  final String id;
  final String userId;
  final TGPayMethod type;
  final DateTime createdAt;
  final TGCardBrand brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holder;
  final bool isDefault;
  final bool isMock;

  /// Valid through the last day of the expiry month.
  bool isExpired(DateTime now) => type == TGPayMethod.card && !DateTime(expYear, expMonth + 1).isAfter(now);

  String get label => switch (type) {
        TGPayMethod.card => '${switch (brand) {
            TGCardBrand.visa => 'Visa',
            TGCardBrand.mastercard => 'Mastercard',
            TGCardBrand.amex => 'Amex',
            TGCardBrand.unknown => 'Card',
          }} •••• $last4',
        TGPayMethod.blik => 'BLIK',
        TGPayMethod.przelewy24 => 'Przelewy24',
      };

  String get expiry => '${expMonth.toString().padLeft(2, '0')}/${(expYear % 100).toString().padLeft(2, '0')}';

  TGPaymentMethod copyWith({bool? isDefault}) => TGPaymentMethod(
        id: id,
        userId: userId,
        type: type,
        createdAt: createdAt,
        brand: brand,
        last4: last4,
        expMonth: expMonth,
        expYear: expYear,
        holder: holder,
        isDefault: isDefault ?? this.isDefault,
        isMock: isMock,
      );
}

enum TGCreditKind { promotion, discount, goodwill }

/// Account credit or discount. Promotion credits from store plans and the
/// Founder discount live in their own services and are merged in the UI.
@immutable
class TGCredit {
  const TGCredit({
    required this.id,
    required this.userId,
    required this.kind,
    required this.titleKey,
    required this.createdAt,
    this.amountPln = 0,
    this.percent = 0,
    this.expiresAt,
    this.usedAt,
    this.isMock = false,
  });

  final String id;
  final String userId;
  final TGCreditKind kind;
  final String titleKey;
  final DateTime createdAt;
  final int amountPln;
  final int percent;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final bool isMock;

  bool isUsable(DateTime now) => usedAt == null && (expiresAt == null || expiresAt!.isAfter(now));
}
