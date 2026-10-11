import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';

/// Shows list price struck through + founder discounted price when applicable.
class FounderPriceRow extends StatelessWidget {
  const FounderPriceRow({
    super.key,
    required this.sellerId,
    required this.listPrice,
    this.label,
  });

  final String sellerId;
  final int listPrice;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final b = TGFounderService.instance.priceBreakdown(sellerId, listPrice);
    if (b.rate <= 0) {
      return Text(formatMoneyPln(listPrice.toDouble()), style: theme.titleMedium.override(fontWeight: FontWeight.w900));
    }
    final pct = (b.rate * 100).round();
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 0 : 150),
      child: Column(
        key: ValueKey('founder-$pct-${b.paid}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatMoneyPln(b.list.toDouble()), style: theme.bodySmall.override(decoration: TextDecoration.lineThrough, color: theme.secondaryText)),
          Text(formatMoneyPln(b.paid.toDouble()), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          Text('Founder discount −$pct%', style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: theme.primary)),
        ],
      ),
    );
  }
}
