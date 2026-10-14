import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Context for the bottom “can't find it?” lead-gen band.
enum TGNeedMoreBandKind { sale, rent, restaurants }

/// Pink-accent lead-gen band used on catalogue, PDP and restaurant pages.
class TGSpecialOrderBand extends StatelessWidget {
  const TGSpecialOrderBand({super.key, this.kind = TGNeedMoreBandKind.sale});

  final TGNeedMoreBandKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 640;

    final (titleKey, subKey, buttons) = switch (kind) {
      TGNeedMoreBandKind.sale => (
          'ui_cta_need_product',
          'ui_cta_sale_sub',
          [
            (label: context.t('ui_special_order'), icon: Icons.send, onTap: () => TGNav.specialOrder(context)),
            (label: context.t('ui_rent'), icon: Icons.key_outlined, onTap: () => TGNav.rent(context)),
          ],
        ),
      TGNeedMoreBandKind.rent => (
          'ui_cta_need_product',
          'ui_cta_rent_sub',
          [
            (label: context.t('ui_special_order'), icon: Icons.send, onTap: () => TGNav.specialOrder(context)),
            (label: context.t('ui_buy'), icon: Icons.storefront_outlined, onTap: () => TGNav.buy(context)),
          ],
        ),
      TGNeedMoreBandKind.restaurants => (
          'ui_cta_need_restaurant',
          'ui_cta_resto_sub',
          [
            (label: context.t('ui_buy'), icon: Icons.storefront_outlined, onTap: () => TGNav.buy(context)),
            (label: context.t('ui_rent'), icon: Icons.key_outlined, onTap: () => TGNav.rent(context)),
          ],
        ),
    };

    final text = Row(
      children: [
        Icon(Icons.auto_awesome, color: theme.secondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(titleKey),
                style: theme.titleSmall.override(fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                context.t(subKey),
                style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          TGButton(
            onPressed: buttons[i].onTap,
            label: buttons[i].label,
            icon: buttons[i].icon,
            variant: TGButtonVariant.outline,
            height: 44,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: TGButton(
                          onPressed: buttons[i].onTap,
                          label: buttons[i].label,
                          icon: buttons[i].icon,
                          variant: TGButtonVariant.outline,
                          height: 44,
                          expand: true,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                actions,
              ],
            ),
    );
  }
}
