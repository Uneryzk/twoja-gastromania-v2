import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Pink-accent lead-gen band used on /products and /product-detail.
class TGSpecialOrderBand extends StatelessWidget {
  const TGSpecialOrderBand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;

    final text = Row(
      children: [
        Icon(Icons.auto_awesome, color: theme.secondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_special_order_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                context.t('ui_special_order_sub'),
                style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
    final button = TGButton(
      onPressed: () => TGNav.specialOrder(context),
      label: context.t('ui_special_order'),
      icon: Icons.send,
      variant: TGButtonVariant.outline,
      height: 44,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 14), button])
          : Row(children: [Expanded(child: text), const SizedBox(width: 16), button]),
    );
  }
}
