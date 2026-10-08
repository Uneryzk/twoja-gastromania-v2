import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// PDP / success "Listing No. 10482137" with copy-to-clipboard.
class TGListingNoLine extends StatefulWidget {
  const TGListingNoLine({super.key, required this.product, this.compact = false});

  final TGProduct product;
  final bool compact;

  @override
  State<TGListingNoLine> createState() => _TGListingNoLineState();
}

class _TGListingNoLineState extends State<TGListingNoLine> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final no = widget.product.listingNo;
    if (no == null || no.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    final label = widget.compact
        ? context.t('ui_listing_no_short', {'n': no})
        : context.t('ui_listing_no', {'n': no});
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: theme.bodySmall.override(
              color: theme.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: widget.compact ? 12 : 13,
            ),
          ),
        ),
        IconButton(
          tooltip: context.t('ui_listing_no', {'n': no}),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: no));
            TGAnalytics.track('listing_number_copied', {'listingNo': no});
            if (!mounted) return;
            setState(() => _copied = true);
            showTGToast(context, context.t('ui_listing_no_copied'));
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            if (mounted) setState(() => _copied = false);
          },
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, color: theme.secondaryText),
        ),
      ],
    );
  }
}

class TGListingNoPlain extends StatelessWidget {
  const TGListingNoPlain({super.key, required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final no = product.listingNo;
    if (no == null || no.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    return Text(
      context.t('ui_listing_no_short', {'n': no}),
      style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}
