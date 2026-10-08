import 'package:intl/intl.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Off unless a later prompt turns saved-BLIK on.
const bool kTgSavedBlikEnabled = false;

enum TGPayMethod { blik, przelewy24, card }

enum TGBlikOutcome { success, incorrect, declined, noConfirmation }

enum TGCheckoutKind { listing, renew, renewBulk, store }

class TGCheckoutLine {
  const TGCheckoutLine(this.label, this.amountPln);
  final String label;
  final double amountPln;
}

class TGCheckoutCart {
  const TGCheckoutCart({
    required this.kind,
    required this.lines,
    this.listingId,
    this.listingIds = const [],
    this.promoteDays = 0,
    this.early = false,
    this.storePlanId,
    this.period,
  });

  final TGCheckoutKind kind;
  final List<TGCheckoutLine> lines;
  final String? listingId;
  final List<String> listingIds;
  final int promoteDays;
  final bool early;
  /// `basic` | `pro` | `enterprise`
  final String? storePlanId;
  final TGBillingPeriod? period;

  double get totalPln => lines.fold(0, (a, l) => a + l.amountPln);

  factory TGCheckoutCart.listing({
    required String listingId,
    required int listingFee,
    required int promoteFee,
    required int promoteDays,
    String? listingNo,
  }) {
    final feeLabel = listingNo == null || listingNo.isEmpty
        ? 'Standard listing'
        : 'Listing fee - No. $listingNo';
    final lines = <TGCheckoutLine>[
      if (listingFee > 0) TGCheckoutLine(feeLabel, listingFee.toDouble()),
      if (promoteFee > 0)
        TGCheckoutLine(
          promoteDays == 30 ? 'Promote 30 days' : 'Promote 14 days',
          promoteFee.toDouble(),
        ),
    ];
    return TGCheckoutCart(kind: TGCheckoutKind.listing, listingId: listingId, lines: lines, promoteDays: promoteDays);
  }

  factory TGCheckoutCart.renew({
    required String listingId,
    required int listingFee,
    required int promoteFee,
    required int promoteDays,
    required bool early,
  }) {
    final lines = <TGCheckoutLine>[
      TGCheckoutLine(early ? 'Renew early' : 'Renew', listingFee.toDouble()),
      if (promoteFee > 0)
        TGCheckoutLine(
          promoteDays == 30 ? 'Promote 30 days' : 'Promote 14 days',
          promoteFee.toDouble(),
        ),
    ];
    return TGCheckoutCart(
      kind: TGCheckoutKind.renew,
      listingId: listingId,
      lines: lines,
      promoteDays: promoteDays,
      early: early,
    );
  }

  factory TGCheckoutCart.renewBulk({required List<String> ids, required int unitFee}) {
    return TGCheckoutCart(
      kind: TGCheckoutKind.renewBulk,
      listingIds: ids,
      lines: [TGCheckoutLine('Renew ${ids.length} listings', (unitFee * ids.length).toDouble())],
    );
  }

  factory TGCheckoutCart.store({required String planId, required TGBillingPeriod period, required double amount}) {
    final name = switch (planId) {
      'pro' => 'Pro Store',
      'enterprise' => 'Enterprise Store',
      _ => 'Basic Store',
    };
    final span = switch (period) {
      TGBillingPeriod.monthly => 'monthly',
      TGBillingPeriod.sixMonths => '6 months',
      TGBillingPeriod.yearly => 'yearly',
    };
    return TGCheckoutCart(
      kind: TGCheckoutKind.store,
      storePlanId: planId,
      period: period,
      lines: [TGCheckoutLine('$name · $span', amount)],
    );
  }
}

TGBlikOutcome resolveBlik(String code) {
  if (code == '000000') return TGBlikOutcome.incorrect;
  if (code == '111111') return TGBlikOutcome.declined;
  if (code == '222222') return TGBlikOutcome.noConfirmation;
  if (code.startsWith('777') && code.length == 6) return TGBlikOutcome.success;
  return TGBlikOutcome.incorrect;
}

bool luhnValid(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 13 || d.length > 19) return false;
  var sum = 0;
  var alt = false;
  for (var i = d.length - 1; i >= 0; i--) {
    var n = int.parse(d[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

enum TGCardBrand { visa, mastercard, amex, unknown }

TGCardBrand cardBrand(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('4')) return TGCardBrand.visa;
  if (d.startsWith(RegExp(r'5[1-5]')) || d.startsWith(RegExp(r'2[2-7]'))) return TGCardBrand.mastercard;
  if (d.startsWith('34') || d.startsWith('37')) return TGCardBrand.amex;
  return TGCardBrand.unknown;
}

final _pln2 = NumberFormat('#,##0.00', 'pl_PL');
final _pln0 = NumberFormat('#,##0', 'pl_PL');

String formatMoneyPln(num value, {bool forceCents = false}) {
  final v = value.toDouble();
  if (!forceCents && v == v.roundToDouble()) {
    return '${_pln0.format(v.round())} PLN';
  }
  return '${_pln2.format(v)} PLN';
}

String payCtaLabel(num total) => 'Pay ${formatMoneyPln(total)}';
